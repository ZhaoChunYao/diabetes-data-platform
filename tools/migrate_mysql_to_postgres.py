"""Stream the complete MySQL project database into PostgreSQL.

The migration is intentionally source-driven: it discovers the tables, columns,
indexes, primary keys, and foreign keys from the running MySQL database, then
creates the PostgreSQL schema and loads rows with COPY in batches.
"""

from __future__ import annotations

import hashlib
import logging
import os
from collections import defaultdict

import mysql.connector
import psycopg
from psycopg import sql


logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger(__name__)


def env(name: str, default: str) -> str:
    return os.getenv(name, default)


SOURCE_CONFIG = {
    "host": env("SOURCE_DB_HOST", "host.docker.internal"),
    "port": int(env("SOURCE_DB_PORT", "3307")),
    "user": env("SOURCE_DB_USER", "app"),
    "password": env("SOURCE_DB_PASS", "app_password"),
    "database": env("SOURCE_DB_NAME", "project_554"),
}

TARGET_CONFIG = {
    "host": env("TARGET_DB_HOST", "db"),
    "port": int(env("TARGET_DB_PORT", "5432")),
    "user": env("TARGET_DB_USER", "app"),
    "password": env("TARGET_DB_PASS", "app_password"),
    "dbname": env("TARGET_DB_NAME", "project_554"),
}


def short_name(*parts: str) -> str:
    """Make a deterministic PostgreSQL name within its 63-byte limit."""
    raw = "_".join(part.lower() for part in parts)
    if len(raw) <= 58:
        return raw
    digest = hashlib.sha1(raw.encode("utf-8")).hexdigest()[:8]
    return f"{raw[:49]}_{digest}"


def pg_type(column: dict) -> str:
    data_type = column["data_type"] or ""
    column_type = column["column_type"] or ""
    if isinstance(data_type, bytes):
        data_type = data_type.decode("utf-8")
    if isinstance(column_type, bytes):
        column_type = column_type.decode("utf-8")
    data_type = data_type.lower()
    column_type = column_type.lower()
    length = column.get("character_maximum_length")
    precision = column.get("numeric_precision")
    scale = column.get("numeric_scale")

    if data_type in {"tinyint", "smallint"}:
        if data_type == "tinyint" and column_type == "tinyint(1)":
            return "boolean"
        return "smallint"
    if data_type in {"int", "integer", "mediumint"}:
        return "integer"
    if data_type == "bigint":
        return "bigint"
    if data_type in {"decimal", "numeric"}:
        if precision and scale is not None:
            return f"numeric({precision},{scale})"
        return "numeric"
    if data_type == "float":
        return "real"
    if data_type in {"double", "real"}:
        return "double precision"
    if data_type in {"char", "varchar"} and length:
        return f"{data_type}({length})"
    if data_type in {"char", "varchar", "text", "tinytext", "mediumtext", "longtext"}:
        return "text" if data_type.endswith("text") else data_type
    if data_type in {"enum", "set"}:
        return "text"
    if data_type in {"binary", "varbinary", "blob", "tinyblob", "mediumblob", "longblob"}:
        return "bytea"
    if data_type == "json":
        return "jsonb"
    if data_type == "date":
        return "date"
    if data_type in {"datetime", "timestamp"}:
        return "timestamp"
    if data_type == "time":
        return "time"
    if data_type == "year":
        return "integer"
    return "text"


def get_metadata(source):
    cursor = source.cursor(dictionary=True)
    cursor.execute(
        """
        SELECT
            TABLE_NAME AS table_name,
            ORDINAL_POSITION AS ordinal_position,
            COLUMN_NAME AS column_name,
            DATA_TYPE AS data_type,
            COLUMN_TYPE AS column_type,
            IS_NULLABLE AS is_nullable,
            COLUMN_DEFAULT AS column_default,
            EXTRA AS extra,
            CHARACTER_MAXIMUM_LENGTH AS character_maximum_length,
            NUMERIC_PRECISION AS numeric_precision,
            NUMERIC_SCALE AS numeric_scale
        FROM information_schema.columns
        WHERE TABLE_SCHEMA = DATABASE()
        ORDER BY TABLE_NAME, ORDINAL_POSITION
        """
    )
    columns = defaultdict(list)
    for row in cursor.fetchall():
        columns[row["table_name"]].append(row)

    cursor.execute(
        """
        SELECT TABLE_NAME AS table_name, INDEX_NAME AS index_name,
               NON_UNIQUE AS non_unique, SEQ_IN_INDEX AS seq_in_index,
               COLUMN_NAME AS column_name
        FROM information_schema.statistics
        WHERE TABLE_SCHEMA = DATABASE()
        ORDER BY TABLE_NAME, INDEX_NAME, SEQ_IN_INDEX
        """
    )
    indexes = defaultdict(lambda: defaultdict(list))
    index_info = {}
    for row in cursor.fetchall():
        table = row["table_name"]
        key = row["index_name"]
        indexes[table][key].append(row["column_name"])
        index_info[(table, key)] = row["non_unique"]

    cursor.execute(
        """
        SELECT CONSTRAINT_NAME AS constraint_name,
               TABLE_NAME AS table_name,
               COLUMN_NAME AS column_name,
               REFERENCED_TABLE_NAME AS referenced_table_name,
               REFERENCED_COLUMN_NAME AS referenced_column_name,
               ORDINAL_POSITION AS ordinal_position
        FROM information_schema.key_column_usage
        WHERE TABLE_SCHEMA = DATABASE()
          AND REFERENCED_TABLE_NAME IS NOT NULL
        ORDER BY TABLE_NAME, CONSTRAINT_NAME, ORDINAL_POSITION
        """
    )
    foreign_keys = defaultdict(list)
    for row in cursor.fetchall():
        foreign_keys[(row["table_name"], row["constraint_name"])].append(row)

    cursor.close()
    return columns, indexes, index_info, foreign_keys


def ready(target) -> bool:
    with target.cursor() as cursor:
        cursor.execute(
            "SELECT 1 FROM information_schema.tables "
            "WHERE table_schema = 'public' AND table_name = '_migration_status'"
        )
        if cursor.fetchone() is None:
            return False
        cursor.execute("SELECT 1 FROM _migration_status WHERE status = 'ready'")
        return cursor.fetchone() is not None


def create_tables(target, columns, indexes):
    with target.cursor() as cursor:
        cursor.execute("DROP SCHEMA public CASCADE")
        cursor.execute("CREATE SCHEMA public")

        for table, table_columns in columns.items():
            definitions = []
            for column in table_columns:
                definition = sql.SQL("{} {}{}").format(
                    sql.Identifier(column["column_name"]),
                    sql.SQL(pg_type(column)),
                    sql.SQL(" NOT NULL") if column["is_nullable"] == "NO" else sql.SQL(""),
                )
                definitions.append(definition)

            primary_columns = indexes[table].get("PRIMARY", [])
            if primary_columns:
                definitions.append(
                    sql.SQL("PRIMARY KEY ({})").format(
                        sql.SQL(", ").join(sql.Identifier(name) for name in primary_columns)
                    )
                )

            cursor.execute(
                sql.SQL("CREATE TABLE {} ({})").format(
                    sql.Identifier(table), sql.SQL(", ").join(definitions)
                )
            )
    target.commit()


def copy_table(source, target, table: str, table_columns: list[dict]) -> int:
    column_names = [column["column_name"] for column in table_columns]
    select_sql = "SELECT " + ", ".join(f"`{name}`" for name in column_names)
    select_sql += f" FROM `{table}`"

    source_cursor = source.cursor(buffered=False)
    source_cursor.execute(select_sql)
    copy_statement = sql.SQL("COPY {} ({}) FROM STDIN").format(
        sql.Identifier(table),
        sql.SQL(", ").join(sql.Identifier(name) for name in column_names),
    ).as_string(target)

    count = 0
    with target.cursor() as target_cursor:
        with target_cursor.copy(copy_statement) as copy:
            for row in source_cursor:
                copy.write_row(row)
                count += 1
    target.commit()
    source_cursor.close()
    logger.info("Loaded %-28s %,d rows", table, count)
    return count


def create_indexes(target, indexes, index_info):
    used_names = set()
    with target.cursor() as cursor:
        for table, table_indexes in indexes.items():
            for index_name, column_names in table_indexes.items():
                if index_name == "PRIMARY":
                    continue
                pg_index_name = short_name("idx", table, index_name)
                while pg_index_name in used_names:
                    pg_index_name = short_name(pg_index_name, "x")
                used_names.add(pg_index_name)
                unique = index_info[(table, index_name)] == 0
                cursor.execute(
                    sql.SQL("CREATE {} INDEX {} ON {} ({})").format(
                        sql.SQL("UNIQUE") if unique else sql.SQL(""),
                        sql.Identifier(pg_index_name),
                        sql.Identifier(table),
                        sql.SQL(", ").join(sql.Identifier(name) for name in column_names),
                    )
                )
    target.commit()


def create_foreign_keys(target, foreign_keys):
    used_names = set()
    with target.cursor() as cursor:
        for (table, constraint_name), rows in foreign_keys.items():
            pg_name = short_name("fk", table, constraint_name)
            while pg_name in used_names:
                pg_name = short_name(pg_name, "x")
            used_names.add(pg_name)
            cursor.execute(
                sql.SQL("ALTER TABLE {} ADD CONSTRAINT {} FOREIGN KEY ({}) REFERENCES {} ({})").format(
                    sql.Identifier(table),
                    sql.Identifier(pg_name),
                    sql.SQL(", ").join(sql.Identifier(row["column_name"]) for row in rows),
                    sql.Identifier(rows[0]["referenced_table_name"]),
                    sql.SQL(", ").join(sql.Identifier(row["referenced_column_name"]) for row in rows),
                )
            )
    target.commit()


def write_status(target, counts):
    with target.cursor() as cursor:
        cursor.execute(
            """
            CREATE TABLE _migration_status (
                status VARCHAR(32) PRIMARY KEY,
                completed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
            )
            """
        )
        cursor.execute("CREATE TABLE migration_row_counts (table_name VARCHAR(255) PRIMARY KEY, row_count BIGINT NOT NULL)")
        for table, count in counts.items():
            cursor.execute(
                "INSERT INTO migration_row_counts (table_name, row_count) VALUES (%s, %s)",
                (table, count),
            )
        cursor.execute("INSERT INTO _migration_status (status) VALUES ('ready')")
    target.commit()


def main() -> None:
    logger.info("Connecting to source MySQL %s:%s/%s", SOURCE_CONFIG["host"], SOURCE_CONFIG["port"], SOURCE_CONFIG["database"])
    source = mysql.connector.connect(**SOURCE_CONFIG)
    target = psycopg.connect(**TARGET_CONFIG)
    try:
        if ready(target) and os.getenv("MIGRATION_FORCE", "0") != "1":
            logger.info("PostgreSQL migration marker already exists; skipping re-import")
            return

        columns, indexes, index_info, foreign_keys = get_metadata(source)
        logger.info("Discovered %d tables", len(columns))
        create_tables(target, columns, indexes)

        counts = {}
        for table, table_columns in columns.items():
            counts[table] = copy_table(source, target, table, table_columns)

        create_indexes(target, indexes, index_info)
        create_foreign_keys(target, foreign_keys)
        write_status(target, counts)
        logger.info("PostgreSQL migration completed: %,d total rows", sum(counts.values()))
    finally:
        source.close()
        target.close()


if __name__ == "__main__":
    main()
