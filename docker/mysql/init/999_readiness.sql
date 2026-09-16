USE project_554;

CREATE TABLE IF NOT EXISTS _docker_init_status (
    status VARCHAR(32) PRIMARY KEY,
    initialized_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO _docker_init_status (status)
VALUES ('ready')
ON DUPLICATE KEY UPDATE initialized_at = CURRENT_TIMESTAMP;

