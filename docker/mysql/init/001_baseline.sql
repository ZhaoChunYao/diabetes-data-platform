CREATE DATABASE IF NOT EXISTS project_554;
USE project_554;

CREATE TABLE participants (
    participant_id VARCHAR(32) PRIMARY KEY,
    study_group VARCHAR(100) NOT NULL,
    condition_group VARCHAR(100),
    site VARCHAR(100),
    age INT,
    gender VARCHAR(20)
);

CREATE TABLE ecg_metadata (
    ecg_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    participant_id VARCHAR(32) NOT NULL,
    ecg_date DATE,
    qtc DECIMAL(10, 2),
    heart_rate DECIMAL(10, 2),
    INDEX idx_participant (participant_id),
    CONSTRAINT fk_ecg_participant FOREIGN KEY (participant_id)
        REFERENCES participants (participant_id)
);

CREATE TABLE measurement (
    measurement_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    person_id VARCHAR(32) NOT NULL,
    measurement_date DATE,
    measurement_source_value VARCHAR(100),
    value_as_number DECIMAL(12, 3),
    unit_source_value VARCHAR(50),
    INDEX idx_person (person_id),
    INDEX idx_measurement_source (measurement_source_value),
    CONSTRAINT fk_measurement_participant FOREIGN KEY (person_id)
        REFERENCES participants (participant_id)
);

CREATE TABLE condition_occurrence (
    condition_occurrence_id BIGINT PRIMARY KEY AUTO_INCREMENT,
    person_id VARCHAR(32) NOT NULL,
    condition_start_date DATE,
    condition_source_value VARCHAR(100),
    INDEX idx_condition_person (person_id),
    INDEX idx_condition_source (condition_source_value),
    CONSTRAINT fk_condition_participant FOREIGN KEY (person_id)
        REFERENCES participants (participant_id)
);

CREATE TABLE cgm_daily (
    participant_id VARCHAR(32) NOT NULL,
    day_index INT NOT NULL,
    mean_glucose DECIMAL(10, 3),
    std_glucose DECIMAL(10, 3),
    tir DECIMAL(10, 3),
    tar DECIMAL(10, 3),
    tbr DECIMAL(10, 3),
    measurement_count INT,
    PRIMARY KEY (participant_id, day_index),
    CONSTRAINT fk_cgm_participant FOREIGN KEY (participant_id)
        REFERENCES participants (participant_id)
);

CREATE TABLE activity_daily (
    participant_id VARCHAR(32) NOT NULL,
    day_index INT NOT NULL,
    total_steps INT,
    sedentary_duration DECIMAL(10, 3),
    walking_duration DECIMAL(10, 3),
    running_duration DECIMAL(10, 3),
    duration_minutes DECIMAL(10, 3),
    PRIMARY KEY (participant_id, day_index),
    CONSTRAINT fk_activity_participant FOREIGN KEY (participant_id)
        REFERENCES participants (participant_id)
);

INSERT INTO participants
    (participant_id, study_group, condition_group, site, age, gender)
VALUES
    ('demo-001', 'healthy', 'healthy', 'Site A', 31, 'F'),
    ('demo-002', 'healthy', 'healthy', 'Site A', 45, 'M'),
    ('demo-003', 'insulin_dependent', 'insulin_dependent', 'Site B', 57, 'F'),
    ('demo-004', 'pre_diabetes_lifestyle_controlled', 'pre_diabetes_lifestyle_controlled', 'Site B', 63, 'M');

INSERT INTO ecg_metadata
    (participant_id, ecg_date, qtc, heart_rate)
VALUES
    ('demo-001', '2025-01-01', 410.00, 68.00),
    ('demo-002', '2025-01-02', 425.00, 72.00),
    ('demo-003', '2025-01-03', 438.00, 80.00);

INSERT INTO measurement
    (person_id, measurement_date, measurement_source_value, value_as_number, unit_source_value)
VALUES
    ('demo-001', '2025-01-01', 'HbA1c (%)', 5.20, '%'),
    ('demo-002', '2025-01-02', 'HbA1c (%)', 5.60, '%'),
    ('demo-003', '2025-01-03', 'HbA1c (%)', 8.10, '%'),
    ('demo-004', '2025-01-04', 'HbA1c (%)', 6.20, '%'),
    ('demo-001', '2025-01-01', 'Weight (kg)', 64.00, 'kg');

INSERT INTO condition_occurrence
    (person_id, condition_start_date, condition_source_value)
VALUES
    ('demo-003', '2025-01-03', 'Type 1 diabetes'),
    ('demo-004', '2025-01-04', 'Prediabetes');

INSERT INTO cgm_daily
    (participant_id, day_index, mean_glucose, std_glucose, tir, tar, tbr, measurement_count)
VALUES
    ('demo-001', 1, 98.00, 12.00, 96.00, 2.00, 2.00, 288),
    ('demo-001', 2, 101.00, 13.00, 94.00, 4.00, 2.00, 288),
    ('demo-002', 1, 105.00, 15.00, 92.00, 6.00, 2.00, 288),
    ('demo-002', 2, 108.00, 16.00, 90.00, 8.00, 2.00, 288),
    ('demo-003', 1, 164.00, 45.00, 61.00, 31.00, 8.00, 288),
    ('demo-003', 2, 172.00, 48.00, 55.00, 38.00, 7.00, 288),
    ('demo-004', 1, 132.00, 28.00, 78.00, 18.00, 4.00, 288),
    ('demo-004', 2, 137.00, 30.00, 74.00, 22.00, 4.00, 288);

INSERT INTO activity_daily
    (participant_id, day_index, total_steps, sedentary_duration, walking_duration, running_duration, duration_minutes)
VALUES
    ('demo-001', 1, 8200, 480.00, 62.00, 12.00, 74.00),
    ('demo-001', 2, 7600, 510.00, 55.00, 8.00, 63.00),
    ('demo-002', 1, 6900, 530.00, 48.00, 4.00, 52.00),
    ('demo-002', 2, 7100, 520.00, 51.00, 5.00, 56.00),
    ('demo-003', 1, 4300, 610.00, 31.00, 2.00, 33.00),
    ('demo-003', 2, 3900, 625.00, 28.00, 1.00, 29.00),
    ('demo-004', 1, 5600, 570.00, 39.00, 3.00, 42.00),
    ('demo-004', 2, 5200, 590.00, 36.00, 2.00, 38.00);

