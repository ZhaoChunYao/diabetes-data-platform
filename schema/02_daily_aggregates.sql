
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
CREATE TABLE `cgm_daily` (
  `participant_id` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `day_index` int NOT NULL,
  `mean_glucose` decimal(6,2) DEFAULT NULL,
  `std_glucose` decimal(6,2) DEFAULT NULL,
  `min_glucose` decimal(6,2) DEFAULT NULL,
  `max_glucose` decimal(6,2) DEFAULT NULL,
  `tir` decimal(5,2) DEFAULT NULL,
  `cv` decimal(5,2) DEFAULT NULL,
  `measurement_count` int DEFAULT NULL,
  PRIMARY KEY (`participant_id`,`day_index`),
  KEY `idx_participant` (`participant_id`),
  KEY `idx_day` (`day_index`),
  KEY `idx_participant_day` (`participant_id`,`day_index`),
  KEY `idx_mean_glucose` (`mean_glucose`),
  KEY `idx_tir` (`tir`),
  CONSTRAINT `cgm_daily_ibfk_1` FOREIGN KEY (`participant_id`) REFERENCES `participants` (`participant_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `cgm_daily_chk_1` CHECK (((`mean_glucose` >= 0) and (`mean_glucose` <= 600))),
  CONSTRAINT `cgm_daily_chk_2` CHECK ((`std_glucose` >= 0)),
  CONSTRAINT `cgm_daily_chk_3` CHECK (((`min_glucose` >= 0) and (`min_glucose` <= 600))),
  CONSTRAINT `cgm_daily_chk_4` CHECK (((`max_glucose` >= 0) and (`max_glucose` <= 600))),
  CONSTRAINT `cgm_daily_chk_5` CHECK (((`tir` >= 0) and (`tir` <= 100))),
  CONSTRAINT `cgm_daily_chk_6` CHECK ((`cv` >= 0)),
  CONSTRAINT `cgm_daily_chk_7` CHECK ((`measurement_count` >= 0)),
  CONSTRAINT `cgm_daily_chk_8` CHECK ((`day_index` > 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Daily aggregated CGM data';
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `heart_rate_daily` (
  `participant_id` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `day_index` int NOT NULL,
  `mean_hr` decimal(5,2) DEFAULT NULL,
  `min_hr` int DEFAULT NULL,
  `max_hr` int DEFAULT NULL,
  `resting_hr` int DEFAULT NULL,
  PRIMARY KEY (`participant_id`,`day_index`),
  KEY `idx_participant` (`participant_id`),
  KEY `idx_day` (`day_index`),
  KEY `idx_participant_day` (`participant_id`,`day_index`),
  KEY `idx_mean_hr` (`mean_hr`),
  CONSTRAINT `heart_rate_daily_ibfk_1` FOREIGN KEY (`participant_id`) REFERENCES `participants` (`participant_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `heart_rate_daily_chk_1` CHECK (((`mean_hr` >= 30) and (`mean_hr` <= 250))),
  CONSTRAINT `heart_rate_daily_chk_2` CHECK (((`min_hr` >= 30) and (`min_hr` <= 250))),
  CONSTRAINT `heart_rate_daily_chk_3` CHECK (((`max_hr` >= 30) and (`max_hr` <= 250))),
  CONSTRAINT `heart_rate_daily_chk_4` CHECK (((`resting_hr` >= 30) and (`resting_hr` <= 150))),
  CONSTRAINT `heart_rate_daily_chk_5` CHECK ((`day_index` > 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Daily heart rate data';
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sleep_daily` (
  `participant_id` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `day_index` int NOT NULL,
  `total_sleep_minutes` int DEFAULT NULL,
  `light_sleep_minutes` int DEFAULT NULL,
  `deep_sleep_minutes` int DEFAULT NULL,
  `rem_sleep_minutes` int DEFAULT NULL,
  `awake_minutes` int DEFAULT NULL,
  `sleep_efficiency` decimal(5,2) DEFAULT NULL,
  PRIMARY KEY (`participant_id`,`day_index`),
  KEY `idx_participant` (`participant_id`),
  KEY `idx_day` (`day_index`),
  KEY `idx_participant_day` (`participant_id`,`day_index`),
  KEY `idx_total_sleep` (`total_sleep_minutes`),
  CONSTRAINT `sleep_daily_ibfk_1` FOREIGN KEY (`participant_id`) REFERENCES `participants` (`participant_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `sleep_daily_chk_1` CHECK (((`total_sleep_minutes` >= 0) and (`total_sleep_minutes` <= 1440))),
  CONSTRAINT `sleep_daily_chk_2` CHECK ((`light_sleep_minutes` >= 0)),
  CONSTRAINT `sleep_daily_chk_3` CHECK ((`deep_sleep_minutes` >= 0)),
  CONSTRAINT `sleep_daily_chk_4` CHECK ((`rem_sleep_minutes` >= 0)),
  CONSTRAINT `sleep_daily_chk_5` CHECK ((`awake_minutes` >= 0)),
  CONSTRAINT `sleep_daily_chk_6` CHECK (((`sleep_efficiency` >= 0) and (`sleep_efficiency` <= 100))),
  CONSTRAINT `sleep_daily_chk_7` CHECK ((`day_index` > 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Daily sleep data';
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `spo2_daily` (
  `participant_id` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `day_index` int NOT NULL,
  `mean_spo2` decimal(5,2) DEFAULT NULL,
  `min_spo2` decimal(5,2) DEFAULT NULL,
  `max_spo2` decimal(5,2) DEFAULT NULL,
  PRIMARY KEY (`participant_id`,`day_index`),
  KEY `idx_participant` (`participant_id`),
  KEY `idx_day` (`day_index`),
  KEY `idx_participant_day` (`participant_id`,`day_index`),
  KEY `idx_mean_spo2` (`mean_spo2`),
  CONSTRAINT `spo2_daily_ibfk_1` FOREIGN KEY (`participant_id`) REFERENCES `participants` (`participant_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `spo2_daily_chk_1` CHECK (((`mean_spo2` >= 0) and (`mean_spo2` <= 100))),
  CONSTRAINT `spo2_daily_chk_2` CHECK (((`min_spo2` >= 0) and (`min_spo2` <= 100))),
  CONSTRAINT `spo2_daily_chk_3` CHECK (((`max_spo2` >= 0) and (`max_spo2` <= 100))),
  CONSTRAINT `spo2_daily_chk_4` CHECK ((`day_index` > 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Daily SpO2 (oxygen saturation) data';
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `stress_daily` (
  `participant_id` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `day_index` int NOT NULL,
  `mean_stress` decimal(5,2) DEFAULT NULL,
  `max_stress` decimal(5,2) DEFAULT NULL,
  PRIMARY KEY (`participant_id`,`day_index`),
  KEY `idx_participant` (`participant_id`),
  KEY `idx_day` (`day_index`),
  KEY `idx_participant_day` (`participant_id`,`day_index`),
  KEY `idx_mean_stress` (`mean_stress`),
  CONSTRAINT `stress_daily_ibfk_1` FOREIGN KEY (`participant_id`) REFERENCES `participants` (`participant_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `stress_daily_chk_1` CHECK (((`mean_stress` >= 0) and (`mean_stress` <= 100))),
  CONSTRAINT `stress_daily_chk_2` CHECK (((`max_stress` >= 0) and (`max_stress` <= 100))),
  CONSTRAINT `stress_daily_chk_3` CHECK ((`day_index` > 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Daily stress level data';
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `activity_daily` (
  `participant_id` varchar(50) COLLATE utf8mb4_unicode_ci NOT NULL,
  `day_index` int NOT NULL,
  `total_steps` int DEFAULT NULL,
  `duration_minutes` int DEFAULT NULL,
  `walking_duration` int DEFAULT NULL,
  `running_duration` int DEFAULT NULL,
  `sedentary_duration` int DEFAULT NULL,
  PRIMARY KEY (`participant_id`,`day_index`),
  KEY `idx_participant` (`participant_id`),
  KEY `idx_day` (`day_index`),
  KEY `idx_participant_day` (`participant_id`,`day_index`),
  KEY `idx_total_steps` (`total_steps`),
  CONSTRAINT `activity_daily_ibfk_1` FOREIGN KEY (`participant_id`) REFERENCES `participants` (`participant_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `activity_daily_chk_1` CHECK ((`total_steps` >= 0)),
  CONSTRAINT `activity_daily_chk_2` CHECK ((`duration_minutes` >= 0)),
  CONSTRAINT `activity_daily_chk_3` CHECK ((`walking_duration` >= 0)),
  CONSTRAINT `activity_daily_chk_4` CHECK ((`running_duration` >= 0)),
  CONSTRAINT `activity_daily_chk_5` CHECK ((`sedentary_duration` >= 0)),
  CONSTRAINT `activity_daily_chk_6` CHECK ((`day_index` > 0))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Daily physical activity data';
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

