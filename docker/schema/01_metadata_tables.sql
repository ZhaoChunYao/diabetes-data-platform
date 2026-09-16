
/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;
DROP TABLE IF EXISTS `participants`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `participants` (
  `participant_id` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `age` int DEFAULT NULL,
  `gender` varchar(10) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `ethnicity` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `race` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `condition_group` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `enrollment_date` date DEFAULT NULL,
  `clinical_site` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `study_group` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `site` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`participant_id`),
  KEY `idx_condition_group` (`condition_group`),
  KEY `idx_age` (`age`),
  KEY `idx_gender` (`gender`),
  CONSTRAINT `participants_chk_1` CHECK (((`age` >= 0) and (`age` <= 120))),
  CONSTRAINT `participants_chk_2` CHECK ((`gender` in (_utf8mb4'Male',_utf8mb4'Female',_utf8mb4'Other',_utf8mb4'Unknown')))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Participant demographics and basic information';
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `measurement`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `measurement` (
  `measurement_id` int NOT NULL,
  `person_id` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `measurement_concept_id` int NOT NULL,
  `measurement_date` date NOT NULL,
  `measurement_datetime` datetime DEFAULT NULL,
  `measurement_time` varchar(10) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `measurement_type_concept_id` int DEFAULT NULL,
  `operator_concept_id` int DEFAULT NULL,
  `value_as_number` decimal(10,3) DEFAULT NULL,
  `value_as_concept_id` int DEFAULT NULL,
  `unit_concept_id` int DEFAULT NULL,
  `range_low` decimal(10,3) DEFAULT NULL,
  `range_high` decimal(10,3) DEFAULT NULL,
  `provider_id` int DEFAULT NULL,
  `visit_occurrence_id` int DEFAULT NULL,
  `visit_detail_id` int DEFAULT NULL,
  `measurement_source_value` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `measurement_source_concept_id` int DEFAULT NULL,
  `unit_source_value` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `unit_source_concept_id` int DEFAULT NULL,
  `value_source_value` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `measurement_event_id` int DEFAULT NULL,
  `meas_event_field_concept_id` int DEFAULT NULL,
  PRIMARY KEY (`measurement_id`),
  KEY `idx_person` (`person_id`),
  KEY `idx_measurement_concept` (`measurement_concept_id`),
  KEY `idx_measurement_date` (`measurement_date`),
  KEY `idx_measurement_source` (`measurement_source_value`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Clinical measurements data (OMOP CDM format) for Feature 2 & 5';
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `ecg_metadata`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `ecg_metadata` (
  `ecg_id` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `participant_id` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `ecg_date` date DEFAULT NULL,
  `qtc` int DEFAULT NULL,
  `heart_rate` int DEFAULT NULL,
  `pr` int DEFAULT NULL,
  `qrsd` int DEFAULT NULL,
  `t_axis` int DEFAULT NULL,
  PRIMARY KEY (`ecg_id`),
  KEY `idx_participant` (`participant_id`),
  KEY `idx_ecg_date` (`ecg_date`),
  KEY `idx_qtc` (`qtc`),
  KEY `idx_heart_rate` (`heart_rate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='ECG metadata for Feature 5';
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `conditions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `conditions` (
  `condition_id` int NOT NULL AUTO_INCREMENT,
  `condition_code` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `condition_name` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL,
  `condition_category` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `description` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`condition_id`),
  UNIQUE KEY `condition_code` (`condition_code`),
  KEY `idx_condition_code` (`condition_code`),
  KEY `idx_condition_category` (`condition_category`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Medical condition definitions';
/*!40101 SET character_set_client = @saved_cs_client */;
DROP TABLE IF EXISTS `participant_conditions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `participant_conditions` (
  `participant_id` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `condition_id` int NOT NULL,
  `diagnosis_date` date DEFAULT NULL,
  `is_primary` tinyint(1) DEFAULT '0',
  PRIMARY KEY (`participant_id`,`condition_id`),
  KEY `idx_participant` (`participant_id`),
  KEY `idx_condition` (`condition_id`),
  KEY `idx_diagnosis_date` (`diagnosis_date`),
  CONSTRAINT `participant_conditions_ibfk_1` FOREIGN KEY (`participant_id`) REFERENCES `participants` (`participant_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `participant_conditions_ibfk_2` FOREIGN KEY (`condition_id`) REFERENCES `conditions` (`condition_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Participant-condition relationships (M:N)';
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

