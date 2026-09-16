
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
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `cgm_readings` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `participant_id` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `day_index` int NOT NULL,
  `timestamp` datetime NOT NULL,
  `glucose_mg_dl` decimal(6,2) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_participant` (`participant_id`),
  KEY `idx_day` (`day_index`),
  KEY `idx_timestamp` (`timestamp`),
  KEY `idx_participant_day` (`participant_id`,`day_index`),
  KEY `idx_participant_day_time` (`participant_id`,`day_index`,`timestamp`),
  CONSTRAINT `cgm_readings_ibfk_1` FOREIGN KEY (`participant_id`) REFERENCES `participants` (`participant_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `cgm_readings_chk_1` CHECK (((`glucose_mg_dl` >= 0) and (`glucose_mg_dl` <= 600))),
  CONSTRAINT `cgm_readings_chk_2` CHECK ((`day_index` > 0))
) ENGINE=InnoDB AUTO_INCREMENT=5720701 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='CGM 5-minute-level timeseries data';
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `hr_readings` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `participant_id` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `day_index` int NOT NULL,
  `timestamp` datetime NOT NULL,
  `hr_bpm` int DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_participant` (`participant_id`),
  KEY `idx_day` (`day_index`),
  KEY `idx_timestamp` (`timestamp`),
  KEY `idx_participant_day` (`participant_id`,`day_index`),
  KEY `idx_participant_day_time` (`participant_id`,`day_index`,`timestamp`),
  CONSTRAINT `hr_readings_ibfk_1` FOREIGN KEY (`participant_id`) REFERENCES `participants` (`participant_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `hr_readings_chk_1` CHECK (((`hr_bpm` >= 0) and (`hr_bpm` <= 250))),
  CONSTRAINT `hr_readings_chk_2` CHECK ((`day_index` > 0))
) ENGINE=InnoDB AUTO_INCREMENT=10761335 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Heart rate minute-level timeseries data';
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sleep_readings` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `participant_id` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `day_index` int NOT NULL,
  `timestamp` datetime NOT NULL,
  `sleep_stage` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `duration_minutes` int DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_participant` (`participant_id`),
  KEY `idx_day` (`day_index`),
  KEY `idx_timestamp` (`timestamp`),
  KEY `idx_participant_day` (`participant_id`,`day_index`),
  KEY `idx_sleep_stage` (`sleep_stage`),
  CONSTRAINT `sleep_readings_ibfk_1` FOREIGN KEY (`participant_id`) REFERENCES `participants` (`participant_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `sleep_readings_chk_1` CHECK (((`duration_minutes` >= 0) and (`duration_minutes` <= 1440))),
  CONSTRAINT `sleep_readings_chk_2` CHECK ((`day_index` > 0))
) ENGINE=InnoDB AUTO_INCREMENT=235446 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Sleep minute-level timeseries data';
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `spo2_readings` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `participant_id` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `day_index` int NOT NULL,
  `timestamp` datetime NOT NULL,
  `spo2_percent` decimal(5,2) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_participant` (`participant_id`),
  KEY `idx_day` (`day_index`),
  KEY `idx_timestamp` (`timestamp`),
  KEY `idx_participant_day` (`participant_id`,`day_index`),
  KEY `idx_participant_day_time` (`participant_id`,`day_index`,`timestamp`),
  CONSTRAINT `spo2_readings_ibfk_1` FOREIGN KEY (`participant_id`) REFERENCES `participants` (`participant_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `spo2_readings_chk_1` CHECK (((`spo2_percent` >= 0) and (`spo2_percent` <= 100))),
  CONSTRAINT `spo2_readings_chk_2` CHECK ((`day_index` > 0))
) ENGINE=InnoDB AUTO_INCREMENT=1397806 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='SpO2 (oxygen saturation) timeseries data';
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `stress_readings` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `participant_id` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `day_index` int NOT NULL,
  `timestamp` datetime NOT NULL,
  `stress_level` int DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_participant` (`participant_id`),
  KEY `idx_day` (`day_index`),
  KEY `idx_timestamp` (`timestamp`),
  KEY `idx_participant_day` (`participant_id`,`day_index`),
  KEY `idx_participant_day_time` (`participant_id`,`day_index`,`timestamp`),
  CONSTRAINT `stress_readings_ibfk_1` FOREIGN KEY (`participant_id`) REFERENCES `participants` (`participant_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `stress_readings_chk_1` CHECK (((`stress_level` >= 0) and (`stress_level` <= 100))),
  CONSTRAINT `stress_readings_chk_2` CHECK ((`day_index` > 0))
) ENGINE=InnoDB AUTO_INCREMENT=9268597 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Stress level timeseries data';
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `activity_readings` (
  `id` bigint NOT NULL AUTO_INCREMENT,
  `participant_id` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `day_index` int NOT NULL,
  `timestamp` datetime NOT NULL,
  `steps` int DEFAULT NULL,
  `calories` decimal(8,2) DEFAULT NULL,
  `distance_km` decimal(8,3) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_participant` (`participant_id`),
  KEY `idx_day` (`day_index`),
  KEY `idx_timestamp` (`timestamp`),
  KEY `idx_participant_day` (`participant_id`,`day_index`),
  KEY `idx_participant_day_time` (`participant_id`,`day_index`,`timestamp`),
  CONSTRAINT `activity_readings_ibfk_1` FOREIGN KEY (`participant_id`) REFERENCES `participants` (`participant_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `activity_readings_chk_1` CHECK ((`steps` >= 0)),
  CONSTRAINT `activity_readings_chk_2` CHECK ((`day_index` > 0))
) ENGINE=InnoDB AUTO_INCREMENT=4208950 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Activity (steps, calories, distance) timeseries data';
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

