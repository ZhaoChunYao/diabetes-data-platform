"""
Flask Server with MySQL Backend
Course: Database Management Systems
Date: December 7, 2025

This server uses MySQL database instead of CSV files for better performance.
Demonstrates: Connection pooling, prepared statements, query optimization
"""

import os
import json
from pathlib import Path
from flask import Flask, jsonify, request, send_from_directory
import mysql.connector
from mysql.connector import pooling
from dotenv import load_dotenv
import logging

app = Flask(__name__)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FRONTEND_DIR = os.path.join(ROOT, 'frontend')
load_dotenv(os.path.join(ROOT, '.env'))

DB_DRIVER = os.getenv('DB_DRIVER', 'mysql').lower()
if DB_DRIVER not in ('mysql', 'postgres'):
    raise ValueError("DB_DRIVER must be 'mysql' or 'postgres'")

DATA_SOURCE = DB_DRIVER
RANDOM_ORDER = 'RANDOM()' if DB_DRIVER == 'postgres' else 'RAND()'

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# MySQL connection pool configuration
DB_CONFIG = {
    'host': os.getenv('DB_HOST', 'localhost'),
    'user': os.getenv('DB_USER', 'root'),
    'password': os.getenv('DB_PASS', ''),
    'database': os.getenv('DB_NAME', 'project_554'),
    'pool_name': 'mypool',
    'pool_size': 5,
    'pool_reset_session': True
}

POSTGRES_CONFIG = {
    'host': os.getenv('DB_HOST', 'localhost'),
    'user': os.getenv('DB_USER', 'app'),
    'password': os.getenv('DB_PASS', ''),
    'dbname': os.getenv('DB_NAME', 'project_554'),
    'port': int(os.getenv('DB_PORT', '5432'))
}

# Create connection pool
try:
    if DB_DRIVER == 'postgres':
        import psycopg
        from psycopg.rows import dict_row

        # Phase 2 uses one short-lived connection per query. This keeps the
        # adapter small while the PostgreSQL version is being validated.
        test_connection = psycopg.connect(**POSTGRES_CONFIG)
        test_connection.close()
        connection_pool = True
        logger.info(f"✓ PostgreSQL connection verified for database: {POSTGRES_CONFIG['dbname']}")
    else:
        connection_pool = pooling.MySQLConnectionPool(**DB_CONFIG)
        logger.info(f"✓ MySQL connection pool created for database: {DB_CONFIG['database']}")
except Exception as e:
    logger.error(f"✗ Failed to initialize {DB_DRIVER} database connection: {e}")
    connection_pool = None


def get_db_connection():
    """Get a connection from the pool."""
    if connection_pool is None:
        raise Exception("Connection pool not initialized")
    if DB_DRIVER == 'postgres':
        return psycopg.connect(**POSTGRES_CONFIG)
    return connection_pool.get_connection()


def execute_query(query, params=None, fetch_one=False, fetch_all=True):
    """
    Execute a SQL query with proper connection handling.
    
    Args:
        query: SQL query string
        params: Query parameters (tuple or dict)
        fetch_one: Return single row
        fetch_all: Return all rows
    
    Returns:
        Query results or None
    """
    conn = None
    cursor = None
    try:
        conn = get_db_connection()
        if DB_DRIVER == 'postgres':
            cursor = conn.cursor(row_factory=dict_row)
        else:
            cursor = conn.cursor(dictionary=True)
        cursor.execute(query, params or ())
        
        if fetch_one:
            return cursor.fetchone()
        elif fetch_all:
            return cursor.fetchall()
        else:
            conn.commit()
            return cursor.rowcount
            
    except Exception as e:
        logger.error(f"Database error: {e}")
        if conn:
            conn.rollback()
        raise
    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()


# ============================================================================
# ROUTE: Serve static files
# ============================================================================

@app.route('/')
def index():
    """Serve the landing page."""
    return send_from_directory(FRONTEND_DIR, 'index.html')


@app.route('/feature3')
def feature3():
    """Serve Feature 3 - CGM Trend Explorer."""
    return send_from_directory(FRONTEND_DIR, 'feature3.html')


@app.route('/feature4')
def feature4():
    """Serve Feature 4 - CGM & Activity Correlation."""
    return send_from_directory(FRONTEND_DIR, 'feature4.html')


@app.route('/<path:filename>')
def serve_static(filename):
    """Serve other static files."""
    return send_from_directory(FRONTEND_DIR, filename)


# ============================================================================
# ROUTE: Health check
# ============================================================================

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint."""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT 1")
        cursor.fetchone()
        cursor.close()
        conn.close()
        
        return jsonify({
            'status': 'healthy',
            'database': 'connected',
            'backend': DB_DRIVER
        })
    except Exception as e:
        return jsonify({
            'status': 'unhealthy',
            'database': 'disconnected',
            'error': str(e)
        }), 500


# ============================================================================
# ROUTE: Get available health condition groups
# ============================================================================

@app.route('/api/groups', methods=['GET'])
def get_groups():
    """
    Get list of available health study groups.
    Uses GROUP BY to find unique study groups.
    """
    try:
        query = """
            SELECT 
                study_group,
                COUNT(*) as participant_count
            FROM participants
            WHERE study_group IS NOT NULL
            GROUP BY study_group
            ORDER BY participant_count DESC
        """
        
        groups = execute_query(query)
        
        return jsonify({
            'groups': [
                {
                    'id': g['study_group'],
                    'name': g['study_group'].replace('_', ' ').title(),
                    'count': g['participant_count']
                }
                for g in groups
            ]
        })
        
    except Exception as e:
        logger.error(f"Error in /api/groups: {e}")
        return jsonify({'error': str(e)}), 500


# ============================================================================
# ROUTE: Get CGM trend data (Feature 3)
# ============================================================================

@app.route('/api/cgm/trend', methods=['GET'])
@app.route('/api/cgm_trend', methods=['GET'])  # Keep both for compatibility
def get_cgm_trend():
    """
    Get CGM glucose trend over days for Feature 3.
    
    Query params (matching original server.py):
        - group: Study group / condition group (e.g., 'healthy', 'other')
        - site: Site filter (optional)
        - age_min: Minimum age (optional)
        - age_max: Maximum age (optional)
        - start: Start day (default: 1)
        - end: End day (default: 10)
    
    Returns aggregated glucose data by day with participant counts.
    """
    try:
        # Get parameters matching the old API
        group = request.args.get('group', None)  # Default to None instead of 'other'
        site = request.args.get('site')
        age_min = request.args.get('age_min', type=int)
        age_max = request.args.get('age_max', type=int)
        start = int(request.args.get('start', 1))
        end = int(request.args.get('end', 10))
        
        # Clamp day range
        start = max(1, start)
        end = min(30, end)
        
        logger.info(f"CGM Trend request: group={group}, site={site}, start={start}, end={end}, age_min={age_min}, age_max={age_max}")
        
        # Build WHERE clause based on filters
        where_clauses = []
        params = []
        
        # Day range filter
        where_clauses.append("c.day_index BETWEEN %s AND %s")
        params.extend([start, end])
        
        # Group filter - only add if group is specified and not empty
        if group and group.lower() not in ('total', 'all', '(any)', ''):
            where_clauses.append("p.study_group = %s")
            params.append(group)
        
        # Site filter
        if site and site.lower() not in ('all', '(any)', ''):
            where_clauses.append("p.site = %s")
            params.append(site)
        
        # Age filters
        if age_min is not None:
            where_clauses.append("p.age >= %s")
            params.append(age_min)
        if age_max is not None:
            where_clauses.append("p.age <= %s")
            params.append(age_max)
        
        where_clause = " AND ".join(where_clauses) if where_clauses else "1=1"
        
        logger.info(f"WHERE clause: {where_clause}, params: {params}")
        
        # Query to aggregate CGM data by day
        query = f"""
            SELECT 
                c.day_index,
                AVG(c.mean_glucose) as avg_mean_glucose_weighted,
                AVG(c.mean_glucose) as avg_mean_glucose_unweighted,
                AVG(c.std_glucose) as avg_sd_glucose,
                AVG(c.tir) as avg_tir,
                AVG(CASE WHEN c.mean_glucose > 180 THEN 100 ELSE 0 END) as avg_tar,
                AVG(CASE WHEN c.mean_glucose < 70 THEN 100 ELSE 0 END) as avg_tbr,
                SUM(c.measurement_count) as total_points,
                COUNT(DISTINCT c.participant_id) as n_participants
            FROM cgm_daily c
            JOIN participants p ON c.participant_id = p.participant_id
            WHERE {where_clause}
            GROUP BY c.day_index
            ORDER BY c.day_index
        """
        
        results = execute_query(query, tuple(params))
        
        # Format response to match expected structure
        rows = []
        for row in results:
            rows.append({
                'day_index': int(row['day_index']),
                'avg_mean_glucose_weighted': round(float(row['avg_mean_glucose_weighted']), 2) if row['avg_mean_glucose_weighted'] else None,
                'avg_mean_glucose_unweighted': round(float(row['avg_mean_glucose_unweighted']), 2) if row['avg_mean_glucose_unweighted'] else None,
                'avg_sd_glucose': round(float(row['avg_sd_glucose']), 2) if row['avg_sd_glucose'] else None,
                'avg_tir': round(float(row['avg_tir']), 2) if row['avg_tir'] else None,
                'avg_tar': round(float(row['avg_tar']), 2) if row['avg_tar'] else None,
                'avg_tbr': round(float(row['avg_tbr']), 2) if row['avg_tbr'] else None,
                'total_points': int(row['total_points']) if row['total_points'] else 0,
                'n_participants': int(row['n_participants'])
            })
        
        return jsonify({
            'filters': {
                'group': group,
                'site': site,
                'age_min': age_min,
                'age_max': age_max
            },
            'start': start,
            'end': end,
            'rows': rows,
            'source': DATA_SOURCE
        })
        
    except Exception as e:
        logger.error(f"Error in /api/cgm/trend: {e}")
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500


# ============================================================================
# ROUTE: Get correlation data (Feature 4)
# ============================================================================

@app.route('/api/correlation', methods=['GET'])
def get_correlation():
    """
    Get correlation data between CGM glucose and activity metrics.
    
    Query params:
        - study_group: Health study group (required)
        - day_start: Start day (default: 1)
        - day_end: End day (default: 30)
        - cgm_metric: CGM metric (mean_glucose, tir, etc.)
        - activity_metric: Activity metric (total_steps, duration_minutes, etc.)
    
    Returns paired data points for correlation analysis.
    Demonstrates: Multi-table JOINs, data pairing, filtering
    """
    try:
        study_group = request.args.get('study_group', request.args.get('condition_group', 'healthy'))
        day_start = int(request.args.get('day_start', 1))
        day_end = int(request.args.get('day_end', 30))
        cgm_metric = request.args.get('cgm_metric', 'mean_glucose')
        activity_metric = request.args.get('activity_metric', 'total_steps')
        
        # SQL query with multiple JOINs
        query = f"""
            SELECT 
                c.participant_id,
                c.day_index,
                c.{cgm_metric} as cgm_value,
                a.{activity_metric} as activity_value,
                p.study_group,
                p.age,
                p.gender
            FROM cgm_daily c
            JOIN activity_daily a 
                ON c.participant_id = a.participant_id 
                AND c.day_index = a.day_index
            JOIN participants p 
                ON c.participant_id = p.participant_id
            WHERE p.study_group = %s
              AND c.day_index BETWEEN %s AND %s
              AND c.{cgm_metric} IS NOT NULL
              AND a.{activity_metric} IS NOT NULL
            ORDER BY c.participant_id, c.day_index
            LIMIT 10000
        """
        
        results = execute_query(query, (study_group, day_start, day_end))
        
        # Format response
        data_points = []
        for row in results:
            data_points.append({
                'participant_id': row['participant_id'],
                'day': row['day_index'],
                'cgm': float(row['cgm_value']),
                'activity': float(row['activity_value']),
                'age': row['age'],
                'gender': row['gender']
            })
        
        # Calculate basic statistics
        if data_points:
            cgm_values = [p['cgm'] for p in data_points]
            activity_values = [p['activity'] for p in data_points]
            
            import numpy as np
            correlation = np.corrcoef(cgm_values, activity_values)[0, 1] if len(cgm_values) > 1 else 0
            
            stats = {
                'correlation': round(float(correlation), 4),
                'cgm_mean': round(np.mean(cgm_values), 2),
                'cgm_std': round(np.std(cgm_values), 2),
                'activity_mean': round(np.mean(activity_values), 2),
                'activity_std': round(np.std(activity_values), 2)
            }
        else:
            stats = None
        
        return jsonify({
            'study_group': study_group,
            'cgm_metric': cgm_metric,
            'activity_metric': activity_metric,
            'day_range': [day_start, day_end],
            'data': data_points,
            'total_points': len(data_points),
            'statistics': stats
        })
        
    except Exception as e:
        logger.error(f"Error in /api/correlation: {e}")
        return jsonify({'error': str(e)}), 500


# ============================================================================
# ROUTE: Get participant summary
# ============================================================================

# ============================================================================
# ROUTE: Get Participant Summary
# ============================================================================

@app.route('/api/participants/meta', methods=['GET'])
def get_participants_meta():
    """
    Get participant metadata for Feature 3 dropdown filters.
    
    Returns list of all participants with CGM data and their metadata.
    This is used to populate the study group, site, and age filters.
    """
    try:
        # Get all participants with CGM data
        query = """
            SELECT DISTINCT
                p.participant_id,
                p.condition_group as study_group,
                p.site,
                p.age
            FROM participants p
            JOIN cgm_daily c ON p.participant_id = c.participant_id
            ORDER BY p.participant_id
        """
        
        results = execute_query(query)
        
        # Format response to match the expected structure
        participants = []
        for row in results:
            participants.append({
                'participant_id': row['participant_id'],
                'study_group': row['study_group'],
                'site': row['site'],
                'age': row['age']
            })
        
        return jsonify({
            'participants': participants,
            'source': DATA_SOURCE
        })
        
    except Exception as e:
        logger.error(f"Error in /api/participants/meta: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/participants', methods=['GET'])
def get_participants():
    """
    Get participant summary with data coverage information.
    
    Query params:
        - study_group: Filter by study group (optional)
        - limit: Max number of results (default: 100)
    
    Demonstrates: Subqueries, LEFT JOINs, aggregation
    """
    try:
        study_group = request.args.get('study_group', request.args.get('condition_group'))
        limit = int(request.args.get('limit', 100))
        
        where_clause = "WHERE 1=1"
        params = []
        if study_group:
            where_clause = "WHERE p.study_group = %s"
            params.append(study_group)
        
        # Optimized query using subqueries instead of multiple JOINs
        # This avoids Cartesian product and is much faster
        query = f"""
            SELECT 
                p.participant_id,
                p.study_group,
                p.age,
                p.gender,
                COALESCE(cgm.day_count, 0) as cgm_days,
                COALESCE(cgm.avg_glucose, 0) as avg_glucose,
                COALESCE(act.day_count, 0) as activity_days,
                COALESCE(act.avg_steps, 0) as avg_steps
            FROM participants p
            LEFT JOIN (
                SELECT participant_id, 
                       COUNT(DISTINCT day_index) as day_count,
                       AVG(mean_glucose) as avg_glucose
                FROM cgm_daily
                GROUP BY participant_id
            ) cgm ON p.participant_id = cgm.participant_id
            LEFT JOIN (
                SELECT participant_id, 
                       COUNT(DISTINCT day_index) as day_count,
                       AVG(total_steps) as avg_steps
                FROM activity_daily
                GROUP BY participant_id
            ) act ON p.participant_id = act.participant_id
            {where_clause}
              AND (COALESCE(cgm.day_count, 0) > 0 OR COALESCE(act.day_count, 0) > 0)
            ORDER BY cgm_days DESC, activity_days DESC
            LIMIT %s
        """
        
        params.append(limit)
        results = execute_query(query, tuple(params))
        
        # Format response
        participants = []
        for row in results:
            participants.append({
                'id': row['participant_id'],
                'study_group': row['study_group'],
                'age': row['age'],
                'gender': row['gender'],
                'cgm_days': row['cgm_days'],
                'activity_days': row['activity_days'],
                'avg_glucose': round(float(row['avg_glucose']), 2) if row['avg_glucose'] else None,
                'avg_steps': round(float(row['avg_steps']), 2) if row['avg_steps'] else None
            })
        
        return jsonify({
            'participants': participants,
            'total': len(participants),
            'filter': study_group
        })
        
    except Exception as e:
        logger.error(f"Error in /api/participants: {e}")
        return jsonify({'error': str(e)}), 500


# ============================================================================
# ROUTE: Get database statistics
# ============================================================================

@app.route('/api/stats', methods=['GET'])
def get_stats():
    """
    Get overall database statistics.
    Demonstrates: Multiple aggregate queries, UNION
    """
    try:
        stats_query = """
            SELECT 
                'participants' as table_name,
                COUNT(*) as count
            FROM participants
            UNION ALL
            SELECT 'cgm_daily', COUNT(*) FROM cgm_daily
            UNION ALL
            SELECT 'activity_daily', COUNT(*) FROM activity_daily
            UNION ALL
            SELECT 'heart_rate_daily', COUNT(*) FROM heart_rate_daily
            UNION ALL
            SELECT 'spo2_daily', COUNT(*) FROM spo2_daily
            UNION ALL
            SELECT 'sleep_daily', COUNT(*) FROM sleep_daily
            UNION ALL
            SELECT 'stress_daily', COUNT(*) FROM stress_daily
        """
        
        results = execute_query(stats_query)
        
        # Get intersection count
        intersection_query = """
            SELECT COUNT(DISTINCT c.participant_id) as count
            FROM cgm_daily c
            JOIN activity_daily a ON c.participant_id = a.participant_id
        """
        intersection = execute_query(intersection_query, fetch_one=True)
        
        return jsonify({
            'table_counts': {row['table_name']: row['count'] for row in results},
            'cgm_activity_intersection': intersection['count'],
            'backend': DB_DRIVER,
            'database': POSTGRES_CONFIG['dbname'] if DB_DRIVER == 'postgres' else DB_CONFIG['database']
        })
        
    except Exception as e:
        logger.error(f"Error in /api/stats: {e}")
        return jsonify({'error': str(e)}), 500


# ============================================================================
# ROUTE: Execute custom query (for testing/debugging)
# ============================================================================

@app.route('/api/query', methods=['POST'])
def execute_custom_query():
    """
    Execute a custom SQL query (READ-ONLY for safety).
    Useful for testing and debugging.
    
    POST body: { "query": "SELECT ...", "params": [] }
    """
    try:
        data = request.get_json()
        query = data.get('query', '').strip().upper()
        
        # Safety check: only allow SELECT queries
        if not query.startswith('SELECT'):
            return jsonify({'error': 'Only SELECT queries are allowed'}), 403
        
        results = execute_query(data.get('query'), data.get('params'))
        
        return jsonify({
            'results': results,
            'count': len(results)
        })
        
    except Exception as e:
        logger.error(f"Error in /api/query: {e}")
        return jsonify({'error': str(e)}), 500


# ============================================================================
# FEATURE 4 API ENDPOINTS
# ============================================================================

@app.route('/api/feature4/single-participant', methods=['GET'])
def get_single_participant_data():
    """
    Get CGM and activity TIMESERIES data for single participants from selected groups.
    Returns minute-level timeseries data from SQL timeseries tables for visualization.
    Used in Feature 4 Single Participant Mode.
    """
    try:
        groups = request.args.get('groups', '').split(',')
        groups = [g.strip() for g in groups if g.strip()]
        activity_metric = request.args.get('activity_metric', 'steps')
        day_start = int(request.args.get('day_start', 1))
        day_end = int(request.args.get('day_end', 10))
        
        if not groups:
            return jsonify({'error': 'No groups specified'}), 400
        
        # Get one representative participant from each group
        participants_data = []
        
        for group in groups:
            # Get a random participant from this group that has CGM timeseries data
            query = f"""
                SELECT p.participant_id, p.study_group, p.age
                FROM participants p
                JOIN cgm_readings c ON p.participant_id = c.participant_id
                WHERE p.study_group = %s
                  AND c.day_index BETWEEN %s AND %s
                GROUP BY p.participant_id, p.study_group, p.age
                ORDER BY {RANDOM_ORDER}
                LIMIT 1
            """
            result = execute_query(query, (group, day_start, day_end))
            
            if not result:
                continue
                
            participant = result[0]
            pid = participant['participant_id']
            
            # Get CGM timeseries data from SQL
            cgm_query = """
                SELECT 
                    timestamp as time,
                    glucose_mg_dl as value,
                    day_index as day
                FROM cgm_readings
                WHERE participant_id = %s 
                  AND day_index BETWEEN %s AND %s
                ORDER BY timestamp
            """
            cgm_data = execute_query(cgm_query, (pid, day_start, day_end))
            
            # Convert datetime to ISO string
            for record in cgm_data:
                if 'time' in record and record['time']:
                    record['time'] = record['time'].isoformat() if hasattr(record['time'], 'isoformat') else str(record['time'])
            
            # Get activity timeseries data based on metric
            activity_data = []
            
            if activity_metric in ['mean_hr', 'heart_rate', 'hr']:
                activity_query = """
                    SELECT 
                        timestamp as time,
                        hr_bpm as value,
                        day_index as day
                    FROM hr_readings
                    WHERE participant_id = %s 
                      AND day_index BETWEEN %s AND %s
                      AND hr_bpm IS NOT NULL
                      AND hr_bpm > 0 AND hr_bpm < 250
                    ORDER BY timestamp
                """
                activity_data = execute_query(activity_query, (pid, day_start, day_end))
                
            elif activity_metric in ['total_sleep_minutes', 'sleep']:
                activity_query = """
                    SELECT 
                        timestamp as time,
                        duration_minutes as value,
                        day_index as day
                    FROM sleep_readings
                    WHERE participant_id = %s 
                      AND day_index BETWEEN %s AND %s
                      AND duration_minutes IS NOT NULL
                    ORDER BY timestamp
                """
                activity_data = execute_query(activity_query, (pid, day_start, day_end))
                
            elif activity_metric in ['mean_spo2', 'spo2']:
                activity_query = """
                    SELECT 
                        timestamp as time,
                        spo2_percent as value,
                        day_index as day
                    FROM spo2_readings
                    WHERE participant_id = %s 
                      AND day_index BETWEEN %s AND %s
                      AND spo2_percent IS NOT NULL
                      AND spo2_percent > 0 AND spo2_percent <= 100
                    ORDER BY timestamp
                """
                activity_data = execute_query(activity_query, (pid, day_start, day_end))
                
            elif activity_metric in ['mean_stress', 'stress']:
                activity_query = """
                    SELECT 
                        timestamp as time,
                        stress_level as value,
                        day_index as day
                    FROM stress_readings
                    WHERE participant_id = %s 
                      AND day_index BETWEEN %s AND %s
                      AND stress_level IS NOT NULL
                      AND stress_level >= 0 AND stress_level <= 100
                    ORDER BY timestamp
                """
                activity_data = execute_query(activity_query, (pid, day_start, day_end))
                
            elif activity_metric in ['steps', 'total_steps']:
                activity_query = """
                    SELECT 
                        timestamp as time,
                        steps as value,
                        day_index as day
                    FROM activity_readings
                    WHERE participant_id = %s 
                      AND day_index BETWEEN %s AND %s
                      AND steps IS NOT NULL
                      AND steps >= 0
                    ORDER BY timestamp
                """
                activity_data = execute_query(activity_query, (pid, day_start, day_end))
                
            else:
                # Unknown metric, return empty array
                activity_data = []
            
            # Convert datetime to ISO string for activity data
            for record in activity_data:
                if 'time' in record and record['time']:
                    record['time'] = record['time'].isoformat() if hasattr(record['time'], 'isoformat') else str(record['time'])
            
            participants_data.append({
                'participant_info': {
                    'participant_id': pid,
                    'study_group': participant['study_group'],
                    'age': participant['age']
                },
                'activity_metric': activity_metric,
                'cgm_data': cgm_data,
                'activity_data': activity_data
            })
        
        return jsonify({
            'participants': participants_data,
            'source': 'sql_timeseries'
        })
        
    except Exception as e:
        logger.error(f"Error in /api/feature4/single-participant: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/feature4/group-data', methods=['GET'])
def get_group_data():
    """
    Get aggregated CGM and activity data by study group.
    Used in Feature 4 Group Analysis Mode.
    Returns format matching CSV server for compatibility with feature4.html
    """
    try:
        groups_str = request.args.get('groups', 'all')
        cgm_metric = request.args.get('cgm_metric', 'mean_glucose')
        activity_metric = request.args.get('activity_metric', 'total_steps')
        day_start = int(request.args.get('day_start', 1))
        day_end = int(request.args.get('day_end', 10))
        
        # Parse groups
        if groups_str.lower() == 'all':
            # Get all groups from database
            groups_query = "SELECT DISTINCT study_group FROM participants WHERE study_group IS NOT NULL"
            groups_result = execute_query(groups_query)
            requested_groups = [row['study_group'] for row in groups_result]
        else:
            requested_groups = [g.strip() for g in groups_str.split(',') if g.strip()]
        
        # Determine which CGM column to use
        cgm_column_map = {
            'mean_glucose': 'mean_glucose',
            'tir': 'tir',
            'tar': 'tar', 
            'tbr': 'tbr',
            'sd_glucose': 'std_glucose'
        }
        cgm_col = cgm_column_map.get(cgm_metric, 'mean_glucose')
        
        # Get CGM data aggregated by group (with group filter)
        if groups_str.lower() == 'all':
            cgm_query = f"""
                SELECT 
                    p.study_group,
                    c.day_index,
                    AVG(c.{cgm_col}) as avg_value
                FROM cgm_daily c
                JOIN participants p ON c.participant_id = p.participant_id
                WHERE c.day_index BETWEEN %s AND %s
                  AND p.study_group IS NOT NULL
                GROUP BY p.study_group, c.day_index
                ORDER BY p.study_group, c.day_index
            """
            cgm_results = execute_query(cgm_query, (day_start, day_end))
        else:
            # Filter by requested groups
            placeholders = ','.join(['%s'] * len(requested_groups))
            cgm_query = f"""
                SELECT 
                    p.study_group,
                    c.day_index,
                    AVG(c.{cgm_col}) as avg_value
                FROM cgm_daily c
                JOIN participants p ON c.participant_id = p.participant_id
                WHERE c.day_index BETWEEN %s AND %s
                  AND p.study_group IN ({placeholders})
                GROUP BY p.study_group, c.day_index
                ORDER BY p.study_group, c.day_index
            """
            cgm_results = execute_query(cgm_query, (day_start, day_end, *requested_groups))
        
        # Determine which activity table and column to use
        # Build WHERE clause for group filtering
        if groups_str.lower() == 'all':
            group_where = " AND p.study_group IS NOT NULL"
            params = (day_start, day_end)
        else:
            placeholders = ','.join(['%s'] * len(requested_groups))
            group_where = f" AND p.study_group IN ({placeholders})"
            params = (day_start, day_end, *requested_groups)
        
        # Map activity metric to table and column
        if activity_metric in ['total_steps', 'sedentary_duration', 'walking_duration', 'running_duration', 'duration_minutes']:
            activity_table = 'activity_daily'
            activity_col = activity_metric
        elif activity_metric in ['hr', 'mean_hr', 'min_hr', 'max_hr']:
            activity_table = 'heart_rate_daily'
            activity_col = 'mean_hr' if activity_metric == 'hr' else activity_metric
        elif activity_metric in ['spo2', 'mean_spo2', 'min_spo2', 'max_spo2']:
            activity_table = 'spo2_daily'
            activity_col = 'mean_spo2' if activity_metric == 'spo2' else activity_metric
        elif activity_metric in ['sleep', 'total_sleep_minutes', 'light_minutes', 'deep_minutes', 'awake_minutes', 'rem_minutes']:
            activity_table = 'sleep_daily'
            activity_col = 'total_sleep_minutes' if activity_metric == 'sleep' else activity_metric
        elif activity_metric in ['stress', 'mean_stress', 'min_stress', 'max_stress']:
            activity_table = 'stress_daily'
            activity_col = 'mean_stress' if activity_metric == 'stress' else activity_metric
        else:
            # Default to steps
            activity_table = 'activity_daily'
            activity_col = 'total_steps'
        
        # Build activity query
        activity_query = f"""
            SELECT 
                p.study_group,
                a.day_index,
                AVG(a.{activity_col}) as avg_value
            FROM {activity_table} a
            JOIN participants p ON a.participant_id = p.participant_id
            WHERE a.day_index BETWEEN %s AND %s 
              AND a.{activity_col} IS NOT NULL{group_where}
            GROUP BY p.study_group, a.day_index
            ORDER BY p.study_group, a.day_index
        """
        
        activity_results = execute_query(activity_query, params)
        
        # Organize data by group in CSV server format
        group_data = {}
        
        # Group CGM data
        for row in cgm_results:
            group = row['study_group']
            if group not in group_data:
                group_data[group] = {'cgm_data': [], 'activity_data': []}
            group_data[group]['cgm_data'].append({
                'day': int(row['day_index']),
                'value': float(row['avg_value']) if row['avg_value'] is not None else 0
            })
        
        # Group activity data
        for row in activity_results:
            group = row['study_group']
            if group not in group_data:
                group_data[group] = {'cgm_data': [], 'activity_data': []}
            group_data[group]['activity_data'].append({
                'day': int(row['day_index']),
                'value': float(row['avg_value']) if row['avg_value'] is not None else 0
            })
        
        # Ensure all groups in requested_groups have entries (even if empty activity_data)
        for group in requested_groups:
            if group not in group_data:
                # This group has no CGM data, skip it entirely
                continue
            # If group has CGM but no activity data, ensure activity_data is empty list
            if 'activity_data' not in group_data[group]:
                group_data[group]['activity_data'] = []
        
        # Filter group_data to only include requested groups
        filtered_group_data = {k: v for k, v in group_data.items() if k in requested_groups}
        
        # Return in CSV server format
        return jsonify({
            'mode': 'group',
            'groups': requested_groups,
            'cgm_metric': cgm_metric,
            'activity_metric': activity_metric,
            'day_range': [day_start, day_end],
            'data': filtered_group_data
        })
        
    except Exception as e:
        logger.error(f"Error in /api/feature4/group-data: {e}")
        return jsonify({'error': str(e)}), 500


@app.route('/api/feature4/correlation', methods=['GET'])
def get_feature4_correlation():
    """
    Calculate correlation between CGM and activity metrics.
    Returns Pearson correlation coefficients.
    """
    try:
        cgm_metric = request.args.get('cgm_metric', 'mean_glucose')
        activity_metric = request.args.get('activity_metric', 'total_steps')
        day_start = int(request.args.get('day_start', 1))
        day_end = int(request.args.get('day_end', 10))
        lag = int(request.args.get('lag', 0))
        per_person = request.args.get('per_person', 'false').lower() == 'true'
        
        # Map activity metric to table and column
        if activity_metric in ['hr', 'mean_hr', 'min_hr', 'max_hr', 'heart_rate']:
            table = 'heart_rate_daily'
            activity_col = 'mean_hr' if activity_metric in ['hr', 'heart_rate'] else activity_metric
        elif activity_metric in ['spo2', 'mean_spo2', 'min_spo2', 'max_spo2']:
            table = 'spo2_daily'
            activity_col = 'mean_spo2' if activity_metric == 'spo2' else activity_metric
        elif activity_metric in ['sleep', 'total_sleep_minutes', 'light_minutes', 'deep_minutes', 'awake_minutes', 'rem_minutes']:
            table = 'sleep_daily'
            activity_col = 'total_sleep_minutes' if activity_metric == 'sleep' else activity_metric
        elif activity_metric in ['stress', 'mean_stress', 'min_stress', 'max_stress']:
            table = 'stress_daily'
            activity_col = 'mean_stress' if activity_metric == 'stress' else activity_metric
        else:
            # Default to activity metrics (steps, sedentary, walking, running)
            table = 'activity_daily'
            if activity_metric in ['steps', 'activity']:
                activity_col = 'total_steps'
            elif activity_metric in ['total_steps', 'sedentary_duration', 'walking_duration', 'running_duration']:
                activity_col = activity_metric
            else:
                activity_col = 'total_steps'
        
        # Get paired data for correlation
        query = f"""
            SELECT 
                p.study_group,
                c.participant_id,
                c.day_index,
                c.mean_glucose,
                c.tir,
                a.{activity_col} as activity_value
            FROM cgm_daily c
            JOIN {table} a ON c.participant_id = a.participant_id 
                AND c.day_index = a.day_index + %s
            JOIN participants p ON c.participant_id = p.participant_id
            WHERE c.day_index BETWEEN %s AND %s
                AND a.{activity_col} IS NOT NULL
                AND c.mean_glucose IS NOT NULL
                AND p.study_group IS NOT NULL
        """
        
        results = execute_query(query, (lag, day_start, day_end))
        
        if not results or len(results) < 3:
            return jsonify({
                'correlations': [],
                'cgm_metric': cgm_metric,
                'activity_metric': activity_metric,
                'lag': lag,
                'message': 'Insufficient data for correlation analysis',
                'source': DATA_SOURCE
            })
        
        # Calculate correlations by group using numpy
        import numpy as np
        correlations = []
        groups = set(r['study_group'] for r in results)
        
        for group in groups:
            group_data = [r for r in results if r['study_group'] == group]
            n = len(group_data)
            
            if n > 2:
                # Extract CGM and activity values
                cgm_values = np.array([float(r['mean_glucose']) for r in group_data])
                activity_values = np.array([float(r['activity_value']) for r in group_data])
                
                # Calculate Pearson correlation
                if np.std(cgm_values) > 0 and np.std(activity_values) > 0:
                    correlation = np.corrcoef(cgm_values, activity_values)[0, 1]
                    
                    # Calculate p-value using t-distribution
                    # For large n, use approximation: p ≈ 2 * (1 - Φ(|t|))
                    # where Φ is the CDF of standard normal (valid for n > 30)
                    if abs(correlation) < 1.0:
                        t_stat = correlation * np.sqrt(n - 2) / np.sqrt(1 - correlation**2)
                        # Approximation using normal distribution for large n
                        if n > 30:
                            from math import erf
                            p_value = 2 * (1 - 0.5 * (1 + erf(abs(t_stat) / np.sqrt(2))))
                        else:
                            # For small n, use a rough approximation
                            p_value = 2 * (1 - abs(t_stat) / (abs(t_stat) + np.sqrt(n - 2)))
                        p_value = min(1.0, max(0.0, p_value))  # Clamp to [0, 1]
                    else:
                        p_value = 0.0  # Perfect correlation
                    
                    correlations.append({
                        'study_group': group,
                        'n_observations': n,
                        'correlation': float(correlation),
                        'p_value': float(p_value)
                    })
                else:
                    correlations.append({
                        'study_group': group,
                        'n_observations': n,
                        'correlation': 0.0,
                        'p_value': 1.0,
                        'note': 'No variance in data'
                    })
        
        return jsonify({
            'correlations': correlations,
            'cgm_metric': cgm_metric,
            'activity_metric': activity_metric,
            'lag': lag,
            'source': DATA_SOURCE
        })
        
    except Exception as e:
        logger.error(f"Error in /api/feature4/correlation: {e}")
        return jsonify({'error': str(e)}), 500


# ============================================================================
# FEATURE 1: Data Availability
# ============================================================================

@app.route("/api/data_availability")
def data_availability():
    """Get data availability by study group"""
    try:
        query = """
            SELECT 
                p.study_group,
                COUNT(DISTINCT p.participant_id) AS total_participants,
                COUNT(DISTINCT e.participant_id) AS ecg_available,
                COUNT(DISTINCT m.person_id) AS clinical_available,
                COUNT(DISTINCT cgm.participant_id) AS cgm_available,
                COUNT(DISTINCT act.participant_id) AS activity_available,
                0 AS environment_available
            FROM participants p
            LEFT JOIN ecg_metadata e ON p.participant_id = e.participant_id
            LEFT JOIN measurement m ON p.participant_id = m.person_id
            LEFT JOIN cgm_daily cgm ON p.participant_id = cgm.participant_id
            LEFT JOIN activity_daily act ON p.participant_id = act.participant_id
            GROUP BY p.study_group
            ORDER BY total_participants DESC
        """
        results = execute_query(query)
        return jsonify(results)
    except Exception as e:
        logger.error(f"Error in data_availability: {e}")
        return jsonify({'error': str(e)}), 500


@app.route("/api/site_group_distribution")
def site_group_distribution():
    """Get participant distribution by site and study group"""
    try:
        query = """
            SELECT 
                site,
                study_group,
                COUNT(*) as participant_count
            FROM participants
            GROUP BY site, study_group
            ORDER BY site, study_group
        """
        results = execute_query(query)
        return jsonify(results)
    except Exception as e:
        logger.error(f"Error in site_group_distribution: {e}")
        return jsonify({'error': str(e)}), 500


# ============================================================================
# FEATURE 2: Clinical Measurements and Conditions
# ============================================================================

@app.route("/api/feature2/measurement_summary")
def measurement_summary():
    """Get summary statistics for clinical measurements"""
    try:
        source_value = request.args.get('source_value')
        
        if source_value:
            # Get mean by study group for a specific measurement
            query = """
                SELECT 
                    p.study_group,
                    AVG(m.value_as_number) as mean_value,
                    COUNT(*) as count
                FROM measurement m
                JOIN participants p ON m.person_id = p.participant_id
                WHERE m.measurement_source_value = %s
                  AND m.value_as_number IS NOT NULL
                GROUP BY p.study_group
                ORDER BY p.study_group
            """
            results = execute_query(query, (source_value,))
        else:
            # Get overall summary of all measurements
            query = """
                SELECT 
                    measurement_source_value as measurement_name,
                    COUNT(*) as count,
                    AVG(value_as_number) as avg_value,
                    MIN(value_as_number) as min_value,
                    MAX(value_as_number) as max_value,
                    unit_source_value as unit
                FROM measurement
                WHERE value_as_number IS NOT NULL
                GROUP BY measurement_source_value, unit_source_value
                ORDER BY count DESC
            """
            results = execute_query(query)
        
        return jsonify(results)
    except Exception as e:
        logger.error(f"Error in measurement_summary: {e}")
        return jsonify({'error': str(e)}), 500


@app.route("/api/feature2/measurement_options")
def measurement_options():
    """Get list of available measurement types"""
    try:
        query = """
            SELECT DISTINCT measurement_source_value
            FROM measurement
            WHERE measurement_source_value IS NOT NULL
            ORDER BY measurement_source_value
        """
        results = execute_query(query)
        return jsonify(results)
    except Exception as e:
        logger.error(f"Error in measurement_options: {e}")
        return jsonify({'error': str(e)}), 500


@app.route("/api/feature2/condition_options")
def condition_options():
    """Get list of available condition types"""
    try:
        query = """
            SELECT DISTINCT condition_source_value
            FROM condition_occurrence
            WHERE condition_source_value IS NOT NULL
            ORDER BY condition_source_value
        """
        results = execute_query(query)
        return jsonify(results)
    except Exception as e:
        logger.error(f"Error in condition_options: {e}")
        return jsonify({'error': str(e)}), 500


@app.route("/api/feature2/conditions")
def conditions():
    """Get conditions for a specific source value"""
    try:
        source_value = request.args.get('source_value')
        if not source_value:
            return jsonify({'error': 'source_value required'}), 400
        
        query = """
            SELECT 
                c.person_id,
                c.condition_start_date,
                c.condition_source_value,
                p.study_group as status
            FROM condition_occurrence c
            JOIN participants p ON c.person_id = p.participant_id
            WHERE c.condition_source_value = %s
            ORDER BY c.person_id, c.condition_start_date
            LIMIT 100
        """
        results = execute_query(query, (source_value,))
        return jsonify(results)
    except Exception as e:
        logger.error(f"Error in conditions: {e}")
        return jsonify({'error': str(e)}), 500


@app.route("/api/feature2/condition_counts")
def condition_counts():
    """Get condition occurrence counts by study group"""
    try:
        source_value = request.args.get('source_value')
        
        if source_value:
            # Get counts by study group for specific condition
            query = """
                SELECT 
                    p.study_group,
                    COUNT(DISTINCT c.person_id) as patient_count
                FROM condition_occurrence c
                JOIN participants p ON c.person_id = p.participant_id
                WHERE c.condition_source_value = %s
                GROUP BY p.study_group
                ORDER BY p.study_group
            """
            results = execute_query(query, (source_value,))
        else:
            # Get overall counts
            query = """
                SELECT 
                    condition_source_value as condition_name,
                    COUNT(*) as occurrence_count,
                    COUNT(DISTINCT person_id) as patient_count
                FROM condition_occurrence
                GROUP BY condition_source_value
                ORDER BY occurrence_count DESC
                LIMIT 20
            """
            results = execute_query(query)
        
        return jsonify(results)
    except Exception as e:
        logger.error(f"Error in condition_counts: {e}")
        return jsonify({'error': str(e)}), 500


# ============================================================================
# FEATURE 5: ECG Analysis
# ============================================================================

@app.route("/api/feature5/ecg_hba1c")
def ecg_hba1c():
    """Get ECG metrics paired with HbA1c measurements"""
    try:
        # Get optional age filters (as per original design)
        min_age = request.args.get('min_age', type=int)
        max_age = request.args.get('max_age', type=int)
        
        # Build WHERE clause based on filters
        hba1c_label = 'HbA1c (%%)' if DB_DRIVER == 'postgres' else 'HbA1c (%)'
        where_clauses = [
            f"m.measurement_source_value = '{hba1c_label}'",
            "e.qtc IS NOT NULL",
            "e.heart_rate IS NOT NULL",
            "e.heart_rate > 0",
            "m.value_as_number IS NOT NULL"
        ]
        params = []
        
        if min_age is not None:
            where_clauses.append("p.age >= %s")
            params.append(min_age)
        if max_age is not None:
            where_clauses.append("p.age <= %s")
            params.append(max_age)
        
        where_clause = " AND ".join(where_clauses)
        
        # Calculate QT interval from QTc using reverse Bazett formula: QT = QTc / sqrt(HR/60)
        query = f"""
            SELECT 
                e.participant_id,
                e.qtc,
                e.heart_rate,
                ROUND(e.qtc / SQRT(e.heart_rate / 60.0), 1) as qt_interval,
                e.ecg_date,
                m.value_as_number as hba1c_value,
                m.measurement_date as hba1c_date,
                p.study_group,
                p.age,
                p.gender
            FROM ecg_metadata e
            JOIN measurement m ON e.participant_id = m.person_id
            JOIN participants p ON e.participant_id = p.participant_id
            WHERE {where_clause}
            ORDER BY e.participant_id, e.ecg_date
        """
        results = execute_query(query, tuple(params) if params else None)
        return jsonify(results)
    except Exception as e:
        logger.error(f"Error in ecg_hba1c: {e}")
        return jsonify({'error': str(e)}), 500


@app.route("/api/feature5/qtc_stats")
def qtc_stats():
    """Get QTc interval statistics by study group"""
    try:
        query = """
            SELECT 
                p.study_group,
                COUNT(*) as measurement_count,
                AVG(e.qtc) as avg_qtc,
                MIN(e.qtc) as min_qtc,
                MAX(e.qtc) as max_qtc,
                STDDEV(e.qtc) as std_qtc
            FROM ecg_metadata e
            JOIN participants p ON e.participant_id = p.participant_id
            WHERE e.qtc IS NOT NULL
            GROUP BY p.study_group
            ORDER BY p.study_group
        """
        results = execute_query(query)
        return jsonify(results)
    except Exception as e:
        logger.error(f"Error in qtc_stats: {e}")
        return jsonify({'error': str(e)}), 500


# ============================================================================
# Main
# ============================================================================

if __name__ == '__main__':
    if connection_pool is None:
        logger.error("Cannot start server: Database connection failed")
        exit(1)
    
    port = int(os.getenv('PORT', 5001))
    active_database = POSTGRES_CONFIG['dbname'] if DB_DRIVER == 'postgres' else DB_CONFIG['database']
    logger.info(f"Starting {DB_DRIVER}-backed Flask server on port {port}")
    logger.info(f"Database: {active_database}")
    logger.info(f"Open http://localhost:{port} in your browser")
    
    # Debug mode disabled for better performance
    app.run(host='0.0.0.0', port=port, debug=False)
