-- --------------------------------------------------------
-- Host:                         127.0.0.1
-- Server version:               10.4.28-MariaDB - Source distribution
-- Server OS:                    osx10.10
-- HeidiSQL Version:             12.10.0.7000
-- --------------------------------------------------------

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET NAMES utf8 */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;


-- Dumping database structure for abandoned_explorer
CREATE DATABASE IF NOT EXISTS `abandoned_explorer` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci */;
USE `abandoned_explorer`;

-- Dumping structure for table abandoned_explorer.admin_actions
CREATE TABLE IF NOT EXISTS `admin_actions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `uuid` char(36) DEFAULT NULL,
  `admin_id` int(11) NOT NULL,
  `action_type` enum('approve_location','reject_location','delete_location','ban_user','unban_user','delete_comment') NOT NULL,
  `target_type` enum('location','user','comment') NOT NULL,
  `target_id` int(11) NOT NULL,
  `reason` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uuid` (`uuid`),
  KEY `idx_uuid` (`uuid`),
  KEY `idx_admin_actions` (`admin_id`,`created_at`),
  KEY `idx_target` (`target_type`,`target_id`),
  KEY `idx_action_type` (`action_type`),
  CONSTRAINT `admin_actions_ibfk_1` FOREIGN KEY (`admin_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table abandoned_explorer.admin_actions: ~0 rows (approximately)

-- Dumping structure for table abandoned_explorer.admin_users
CREATE TABLE IF NOT EXISTS `admin_users` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `role` enum('admin','super_admin') DEFAULT 'admin',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `created_by` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_admin_user` (`user_id`),
  KEY `created_by` (`created_by`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_role` (`role`),
  CONSTRAINT `admin_users_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `admin_users_ibfk_2` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table abandoned_explorer.admin_users: ~1 rows (approximately)
INSERT INTO `admin_users` (`id`, `user_id`, `role`, `created_at`, `created_by`) VALUES
	(1, 2, 'admin', '2025-06-23 00:24:35', NULL);

-- Dumping structure for table abandoned_explorer.bookmarks
CREATE TABLE IF NOT EXISTS `bookmarks` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `uuid` char(36) DEFAULT NULL,
  `user_id` int(11) NOT NULL,
  `location_id` int(11) NOT NULL,
  `notes` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_bookmark` (`user_id`,`location_id`),
  UNIQUE KEY `uuid` (`uuid`),
  KEY `idx_uuid` (`uuid`),
  KEY `idx_user_bookmarks` (`user_id`,`created_at`),
  KEY `idx_location_bookmarks` (`location_id`),
  CONSTRAINT `bookmarks_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `bookmarks_ibfk_2` FOREIGN KEY (`location_id`) REFERENCES `locations` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=16 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table abandoned_explorer.bookmarks: ~2 rows (approximately)
INSERT INTO `bookmarks` (`id`, `uuid`, `user_id`, `location_id`, `notes`, `created_at`) VALUES
	(8, NULL, 1, 1, NULL, '2025-06-23 01:00:37'),
	(15, NULL, 2, 2, NULL, '2025-06-23 02:59:43');

-- Dumping structure for table abandoned_explorer.comments
CREATE TABLE IF NOT EXISTS `comments` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `uuid` char(36) DEFAULT NULL,
  `location_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `comment_text` text NOT NULL,
  `parent_comment_id` int(11) DEFAULT NULL,
  `is_approved` tinyint(1) DEFAULT 1,
  `likes_count` int(11) DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uuid` (`uuid`),
  KEY `idx_uuid` (`uuid`),
  KEY `idx_location_comments` (`location_id`,`created_at`),
  KEY `idx_user_comments` (`user_id`,`created_at`),
  KEY `idx_parent_comments` (`parent_comment_id`),
  KEY `idx_approved` (`is_approved`),
  CONSTRAINT `comments_ibfk_1` FOREIGN KEY (`location_id`) REFERENCES `locations` (`id`) ON DELETE CASCADE,
  CONSTRAINT `comments_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `comments_ibfk_3` FOREIGN KEY (`parent_comment_id`) REFERENCES `comments` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table abandoned_explorer.comments: ~0 rows (approximately)

-- Dumping structure for table abandoned_explorer.danger_levels
CREATE TABLE IF NOT EXISTS `danger_levels` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(20) NOT NULL,
  `color` varchar(20) NOT NULL,
  `description` text DEFAULT NULL,
  `risk_level` int(11) DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`),
  KEY `idx_name` (`name`),
  KEY `idx_risk_level` (`risk_level`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table abandoned_explorer.danger_levels: ~3 rows (approximately)
INSERT INTO `danger_levels` (`id`, `name`, `color`, `description`, `risk_level`, `created_at`) VALUES
	(1, 'Safe', 'green', 'Generally safe to explore with basic precautions', 1, '2025-06-22 23:44:43'),
	(2, 'Caution', 'yellow', 'Requires caution and proper safety equipment', 2, '2025-06-22 23:44:43'),
	(3, 'Dangerous', 'red', 'High risk - experienced explorers only', 3, '2025-06-22 23:44:43');

-- Dumping structure for table abandoned_explorer.likes
CREATE TABLE IF NOT EXISTS `likes` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `uuid` char(36) DEFAULT NULL,
  `user_id` int(11) NOT NULL,
  `location_id` int(11) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_like` (`user_id`,`location_id`),
  UNIQUE KEY `uuid` (`uuid`),
  KEY `idx_uuid` (`uuid`),
  KEY `idx_user_likes` (`user_id`,`created_at`),
  KEY `idx_location_likes` (`location_id`),
  CONSTRAINT `likes_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `likes_ibfk_2` FOREIGN KEY (`location_id`) REFERENCES `locations` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=16 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table abandoned_explorer.likes: ~2 rows (approximately)
INSERT INTO `likes` (`id`, `uuid`, `user_id`, `location_id`, `created_at`) VALUES
	(10, NULL, 1, 1, '2025-06-23 01:00:39'),
	(15, NULL, 2, 2, '2025-06-23 02:59:43');

-- Dumping structure for table abandoned_explorer.locations
CREATE TABLE IF NOT EXISTS `locations` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `uuid` char(36) DEFAULT NULL,
  `title` varchar(255) NOT NULL,
  `description` text DEFAULT NULL,
  `latitude` decimal(10,8) NOT NULL,
  `longitude` decimal(11,8) NOT NULL,
  `address` text DEFAULT NULL,
  `category_id` int(11) DEFAULT NULL,
  `danger_level_id` int(11) DEFAULT NULL,
  `submitted_by` int(11) DEFAULT NULL,
  `is_approved` tinyint(1) DEFAULT 0,
  `approval_date` timestamp NULL DEFAULT NULL,
  `approved_by` int(11) DEFAULT NULL,
  `featured` tinyint(1) DEFAULT 0,
  `views_count` int(11) DEFAULT 0,
  `likes_count` int(11) DEFAULT 0,
  `bookmarks_count` int(11) DEFAULT 0,
  `comments_count` int(11) DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `deleted_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uuid` (`uuid`),
  KEY `approved_by` (`approved_by`),
  KEY `idx_uuid` (`uuid`),
  KEY `idx_coordinates` (`latitude`,`longitude`),
  KEY `idx_approved` (`is_approved`),
  KEY `idx_category` (`category_id`),
  KEY `idx_danger_level` (`danger_level_id`),
  KEY `idx_submitted_by` (`submitted_by`),
  KEY `idx_created_at` (`created_at`),
  KEY `idx_featured` (`featured`),
  KEY `idx_location_search` (`latitude`,`longitude`,`is_approved`),
  KEY `idx_views` (`views_count`),
  KEY `idx_likes` (`likes_count`),
  CONSTRAINT `locations_ibfk_1` FOREIGN KEY (`category_id`) REFERENCES `location_categories` (`id`) ON DELETE SET NULL,
  CONSTRAINT `locations_ibfk_2` FOREIGN KEY (`danger_level_id`) REFERENCES `danger_levels` (`id`) ON DELETE SET NULL,
  CONSTRAINT `locations_ibfk_3` FOREIGN KEY (`submitted_by`) REFERENCES `users` (`id`) ON DELETE SET NULL,
  CONSTRAINT `locations_ibfk_4` FOREIGN KEY (`approved_by`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=46 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table abandoned_explorer.locations: ~45 rows (approximately)
INSERT INTO `locations` (`id`, `uuid`, `title`, `description`, `latitude`, `longitude`, `address`, `category_id`, `danger_level_id`, `submitted_by`, `is_approved`, `approval_date`, `approved_by`, `featured`, `views_count`, `likes_count`, `bookmarks_count`, `comments_count`, `created_at`, `updated_at`, `deleted_at`) VALUES
	(1, NULL, 'Abandoned Hospital', 'Description test', 37.78583400, -122.40641700, 'Lat: 37.785834, Lng: -122.406417', 1, 3, 1, 1, '2025-06-23 00:24:56', 1, 0, 969, 35, 36, 0, '2025-06-23 00:03:11', '2025-06-24 02:44:52', NULL),
	(2, NULL, 'Test 2', 'Test 2', 37.78583400, -122.40641700, 'Lat: 37.785834, Lng: -122.406417', 8, 2, 2, 1, '2025-06-23 01:36:42', 2, 0, 529, 79, 8, 0, '2025-06-23 01:25:15', '2025-06-24 02:44:52', NULL),
	(3, NULL, 'Test 3', 'Test 3', 37.78583400, -122.40641700, 'Lat: 37.785834, Lng: -122.406417', 4, 1, 1, 1, '2025-06-23 02:59:54', 2, 0, 686, 87, 33, 0, '2025-06-23 02:59:22', '2025-06-24 02:44:52', NULL),
	(4, NULL, 'Test', 'Teary', 42.34309088, 27.18902228, 'Lat: 42.343091, Lng: 27.189022', 4, 3, 1, 1, '2025-06-24 00:44:30', 2, 0, 794, 195, 40, 0, '2025-06-24 00:36:21', '2025-06-24 02:44:52', NULL),
	(5, '3437302c-50a5-11f0-a415-36cb2806145a', 'Abandoned Hospital NYC', 'Old Bellevue psychiatric ward, creepy but fascinating', 40.73860000, -73.98570000, 'Manhattan, NY', 1, 2, 1, 1, '2025-06-24 02:44:52', NULL, 0, 863, 109, 2, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(6, '34381eb0-50a5-11f0-a415-36cb2806145a', 'Defunct Factory Manhattan', 'Industrial complex from the 1920s', 40.75050000, -73.99340000, 'Manhattan, NY', 2, 2, 1, 1, '2025-06-24 02:44:52', NULL, 0, 885, 155, 90, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(7, '343854ac-50a5-11f0-a415-36cb2806145a', 'Old School Building', 'Abandoned elementary school with intact classrooms', 40.72820000, -73.99420000, 'Manhattan, NY', 3, 1, 1, 1, '2025-06-24 02:44:52', NULL, 0, 786, 43, 42, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(8, '34397e22-50a5-11f0-a415-36cb2806145a', 'Derelict Apartment Block', 'Residential building abandoned after fire', 40.75890000, -73.98510000, 'Manhattan, NY', 4, 2, 1, 1, '2025-06-24 02:44:52', NULL, 0, 224, 147, 39, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(9, '34398bb0-50a5-11f0-a415-36cb2806145a', 'Empty Shopping Center', 'Mall closed since 2015, nature taking over', 40.75050000, -74.00890000, 'Manhattan, NY', 5, 1, 1, 1, '2025-06-24 02:44:52', NULL, 0, 715, 201, 71, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(10, '34398dcc-50a5-11f0-a415-36cb2806145a', 'Abandoned Church Brooklyn', 'Gothic revival church, stunning architecture', 40.68920000, -73.94420000, 'Brooklyn, NY', 6, 1, 1, 1, '2025-06-24 02:44:52', NULL, 0, 852, 161, 35, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(11, '34398f34-50a5-11f0-a415-36cb2806145a', 'Old Theater Brooklyn', 'Art deco movie theater from the 1930s', 40.68310000, -73.97120000, 'Brooklyn, NY', 7, 2, 1, 1, '2025-06-24 02:44:52', NULL, 0, 65, 196, 61, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(12, '343990a6-50a5-11f0-a415-36cb2806145a', 'Industrial Warehouse', 'Massive warehouse complex near the waterfront', 40.66430000, -74.00920000, 'Brooklyn, NY', 2, 2, 1, 1, '2025-06-24 02:44:52', NULL, 0, 722, 93, 2, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(13, '34399204-50a5-11f0-a415-36cb2806145a', 'Hollywood Hospital Ruins', 'Famous hospital where celebrities were treated', 34.09280000, -118.32870000, 'Hollywood, CA', 1, 3, 1, 1, '2025-06-24 02:44:52', NULL, 0, 363, 74, 26, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(14, '34399362-50a5-11f0-a415-36cb2806145a', 'Sunset Strip Mall', 'Abandoned shopping complex on famous strip', 34.09010000, -118.38640000, 'West Hollywood, CA', 5, 1, 1, 1, '2025-06-24 02:44:52', NULL, 0, 600, 87, 22, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(15, '343994b6-50a5-11f0-a415-36cb2806145a', 'LA Factory District', 'Textile factory from the industrial era', 34.04890000, -118.25180000, 'Los Angeles, CA', 2, 2, 1, 1, '2025-06-24 02:44:52', NULL, 0, 862, 8, 34, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(16, '3439960a-50a5-11f0-a415-36cb2806145a', 'Venice Beach House', 'Beachfront property abandoned after storms', 33.98500000, -118.46950000, 'Venice, CA', 4, 1, 1, 1, '2025-06-24 02:44:52', NULL, 0, 458, 175, 3, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(17, '34399740-50a5-11f0-a415-36cb2806145a', 'Golden Gate Hospital', 'Psychiatric facility with ocean views', 37.80440000, -122.46800000, 'San Francisco, CA', 1, 2, 1, 1, '2025-06-24 02:44:52', NULL, 0, 657, 46, 13, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(18, '34399894-50a5-11f0-a415-36cb2806145a', 'Alcatraz Island Building', 'Former prison administrative building', 37.82670000, -122.42330000, 'San Francisco, CA', 8, 3, 1, 1, '2025-06-24 02:44:52', NULL, 0, 861, 99, 55, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(19, '343999e8-50a5-11f0-a415-36cb2806145a', 'Mission District School', 'Earthquake-damaged school building', 37.75990000, -122.41480000, 'San Francisco, CA', 3, 2, 1, 1, '2025-06-24 02:44:52', NULL, 0, 284, 152, 37, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(20, '34399b14-50a5-11f0-a415-36cb2806145a', 'Windy City Hospital', 'Large medical complex, partially demolished', 41.87810000, -87.62980000, 'Chicago, IL', 1, 2, 1, 1, '2025-06-24 02:44:52', NULL, 0, 789, 60, 18, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(21, '34399c54-50a5-11f0-a415-36cb2806145a', 'Steel Mill Chicago', 'Historic steel production facility', 41.83690000, -87.68470000, 'Chicago, IL', 2, 3, 1, 1, '2025-06-24 02:44:52', NULL, 0, 1043, 41, 78, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(22, '34399d80-50a5-11f0-a415-36cb2806145a', 'Loop Theater', 'Grand movie palace from golden age of cinema', 41.88190000, -87.62780000, 'Chicago, IL', 7, 1, 1, 1, '2025-06-24 02:44:52', NULL, 0, 799, 20, 36, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(23, '34399ede-50a5-11f0-a415-36cb2806145a', 'Art Deco Hospital Miami', 'Pastel-colored medical facility from the 40s', 25.77530000, -80.19010000, 'Miami, FL', 1, 1, 1, 1, '2025-06-24 02:44:52', NULL, 0, 816, 173, 46, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(24, '34399ff6-50a5-11f0-a415-36cb2806145a', 'South Beach Mall', 'Shopping center hit by multiple hurricanes', 25.79070000, -80.13000000, 'Miami Beach, FL', 5, 2, 1, 1, '2025-06-24 02:44:52', NULL, 0, 635, 198, 22, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(25, '3439a0fa-50a5-11f0-a415-36cb2806145a', 'Coral Gables Mansion', 'Luxury home abandoned after foreclosure', 25.74630000, -80.24360000, 'Coral Gables, FL', 4, 1, 1, 1, '2025-06-24 02:44:52', NULL, 0, 675, 67, 71, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(26, '3439a21c-50a5-11f0-a415-36cb2806145a', 'Big D Medical Center', 'Sprawling hospital campus, multiple buildings', 32.77670000, -96.79700000, 'Dallas, TX', 1, 2, 1, 1, '2025-06-24 02:44:52', NULL, 0, 420, 139, 88, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(27, '3439a320-50a5-11f0-a415-36cb2806145a', 'Oil Refinery Dallas', 'Petroleum processing plant from oil boom era', 32.82080000, -96.87140000, 'Dallas, TX', 2, 3, 1, 1, '2025-06-24 02:44:52', NULL, 0, 1025, 87, 26, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(28, '3439a474-50a5-11f0-a415-36cb2806145a', 'Prairie School House', 'One-room schoolhouse from frontier days', 32.73570000, -96.80840000, 'Dallas, TX', 3, 1, 1, 1, '2025-06-24 02:44:52', NULL, 0, 815, 13, 66, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(29, '3439a582-50a5-11f0-a415-36cb2806145a', 'Emerald City Hospital', 'Mental health facility in the hills', 47.62050000, -122.34930000, 'Seattle, WA', 1, 2, 1, 1, '2025-06-24 02:44:52', NULL, 0, 953, 202, 49, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(30, '3439a67c-50a5-11f0-a415-36cb2806145a', 'Boeing Factory Seattle', 'Aircraft manufacturing plant', 47.53490000, -122.30670000, 'Seattle, WA', 2, 2, 1, 1, '2025-06-24 02:44:52', NULL, 0, 270, 164, 50, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(31, '3439a780-50a5-11f0-a415-36cb2806145a', 'Pike Place Theater', 'Historic performance venue near the market', 47.60850000, -122.34250000, 'Seattle, WA', 7, 1, 1, 1, '2025-06-24 02:44:52', NULL, 0, 443, 12, 2, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(32, '3439a8ca-50a5-11f0-a415-36cb2806145a', 'Peachtree Hospital', 'Civil War era medical facility', 33.74900000, -84.38800000, 'Atlanta, GA', 1, 2, 1, 1, '2025-06-24 02:44:52', NULL, 0, 355, 162, 61, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(33, '3439a9ce-50a5-11f0-a415-36cb2806145a', 'Cotton Mill Atlanta', 'Textile manufacturing from reconstruction era', 33.76760000, -84.42050000, 'Atlanta, GA', 2, 2, 1, 1, '2025-06-24 02:44:52', NULL, 0, 398, 170, 98, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(34, '3439aad2-50a5-11f0-a415-36cb2806145a', 'Desert Hospital Phoenix', 'Mid-century modern medical complex', 33.44840000, -112.07400000, 'Phoenix, AZ', 1, 2, 1, 1, '2025-06-24 02:44:52', NULL, 0, 873, 159, 5, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(35, '3439abd6-50a5-11f0-a415-36cb2806145a', 'Adobe House Scottsdale', 'Luxury desert home, victim of housing crash', 33.49420000, -111.92610000, 'Scottsdale, AZ', 4, 1, 1, 1, '2025-06-24 02:44:52', NULL, 0, 123, 79, 29, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(36, '3439acda-50a5-11f0-a415-36cb2806145a', 'Vegas Strip Hospital', 'Former casino converted to medical center', 36.11470000, -115.17280000, 'Las Vegas, NV', 1, 1, 1, 1, '2025-06-24 02:44:52', NULL, 0, 947, 115, 31, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(37, '3439ae1a-50a5-11f0-a415-36cb2806145a', 'Desert Mall Vegas', 'Shopping center in the suburbs', 36.17160000, -115.13910000, 'Las Vegas, NV', 5, 1, 1, 1, '2025-06-24 02:44:52', NULL, 0, 318, 133, 67, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(38, '3439af1e-50a5-11f0-a415-36cb2806145a', 'Victorian Hospital London', 'Historic medical facility in East London', 51.50740000, -0.12780000, 'London, UK', 1, 2, 1, 1, '2025-06-24 02:44:52', NULL, 0, 697, 115, 43, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(39, '3439b04a-50a5-11f0-a415-36cb2806145a', 'Thames Factory', 'Industrial building along the river', 51.49940000, -0.12480000, 'London, UK', 2, 2, 1, 1, '2025-06-24 02:44:52', NULL, 0, 482, 174, 11, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(40, '3439b158-50a5-11f0-a415-36cb2806145a', 'Hôpital Abandonné Paris', 'Belle Époque era hospital building', 48.85660000, 2.35220000, 'Paris, France', 1, 2, 1, 1, '2025-06-24 02:44:52', NULL, 0, 268, 118, 29, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(41, '3439b25c-50a5-11f0-a415-36cb2806145a', 'Usine de Paris', 'Factory from industrial revolution', 48.87380000, 2.29500000, 'Paris, France', 2, 2, 1, 1, '2025-06-24 02:44:52', NULL, 0, 845, 63, 8, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(42, '3439b388-50a5-11f0-a415-36cb2806145a', 'Tokyo Metropolitan Hospital', 'Post-war medical facility', 35.67620000, 139.65030000, 'Tokyo, Japan', 1, 1, 1, 1, '2025-06-24 02:44:52', NULL, 0, 372, 158, 53, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(43, '3439b48c-50a5-11f0-a415-36cb2806145a', 'Shibuya Factory', 'Electronics manufacturing plant', 35.65940000, 139.70050000, 'Tokyo, Japan', 2, 2, 1, 1, '2025-06-24 02:44:52', NULL, 0, 275, 196, 41, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(44, '3439b586-50a5-11f0-a415-36cb2806145a', 'Harbor Hospital Sydney', 'Medical facility with harbor views', -33.86880000, 151.20930000, 'Sydney, Australia', 1, 1, 1, 1, '2025-06-24 02:44:52', NULL, 0, 210, 102, 47, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(45, '3439b6b2-50a5-11f0-a415-36cb2806145a', 'Opera House Mall', 'Shopping center near the famous opera house', -33.85680000, 151.21530000, 'Sydney, Australia', 5, 1, 1, 1, '2025-06-24 02:44:52', NULL, 0, 176, 117, 9, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL);

-- Dumping structure for table abandoned_explorer.location_categories
CREATE TABLE IF NOT EXISTS `location_categories` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL,
  `icon` varchar(50) NOT NULL,
  `description` text DEFAULT NULL,
  `color` varchar(20) DEFAULT '#FF6B35',
  `is_active` tinyint(1) DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`),
  KEY `idx_name` (`name`),
  KEY `idx_is_active` (`is_active`)
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table abandoned_explorer.location_categories: ~8 rows (approximately)
INSERT INTO `location_categories` (`id`, `name`, `icon`, `description`, `color`, `is_active`, `created_at`) VALUES
	(1, 'Hospital', 'cross.fill', 'Abandoned medical facilities and hospitals', '#FF3B30', 1, '2025-06-22 23:44:43'),
	(2, 'Factory', 'building.2.fill', 'Industrial buildings and manufacturing plants', '#FF6B35', 1, '2025-06-22 23:44:43'),
	(3, 'School', 'graduationcap.fill', 'Educational institutions and schools', '#FFCC02', 1, '2025-06-22 23:44:43'),
	(4, 'House', 'house.fill', 'Residential buildings and homes', '#34C759', 1, '2025-06-22 23:44:43'),
	(5, 'Mall', 'storefront.fill', 'Shopping centers and retail spaces', '#5AC8FA', 1, '2025-06-22 23:44:43'),
	(6, 'Church', 'building.columns.fill', 'Religious buildings and places of worship', '#AF52DE', 1, '2025-06-22 23:44:43'),
	(7, 'Theater', 'theatermasks.fill', 'Entertainment venues and theaters', '#FF2D92', 1, '2025-06-22 23:44:43'),
	(8, 'Other', 'questionmark.circle.fill', 'Other types of abandoned places', '#8E8E93', 1, '2025-06-22 23:44:43');

-- Dumping structure for table abandoned_explorer.location_images
CREATE TABLE IF NOT EXISTS `location_images` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `uuid` char(36) DEFAULT NULL,
  `location_id` int(11) NOT NULL,
  `image_url` varchar(500) NOT NULL,
  `thumbnail_url` varchar(500) DEFAULT NULL,
  `image_order` int(11) DEFAULT 0,
  `uploaded_by` int(11) DEFAULT NULL,
  `file_size` int(11) DEFAULT NULL,
  `image_width` int(11) DEFAULT NULL,
  `image_height` int(11) DEFAULT NULL,
  `alt_text` varchar(255) DEFAULT NULL,
  `is_primary` tinyint(1) DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uuid` (`uuid`),
  KEY `uploaded_by` (`uploaded_by`),
  KEY `idx_uuid` (`uuid`),
  KEY `idx_location_id` (`location_id`),
  KEY `idx_image_order` (`location_id`,`image_order`),
  KEY `idx_primary` (`location_id`,`is_primary`),
  CONSTRAINT `location_images_ibfk_1` FOREIGN KEY (`location_id`) REFERENCES `locations` (`id`) ON DELETE CASCADE,
  CONSTRAINT `location_images_ibfk_2` FOREIGN KEY (`uploaded_by`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table abandoned_explorer.location_images: ~5 rows (approximately)
INSERT INTO `location_images` (`id`, `uuid`, `location_id`, `image_url`, `thumbnail_url`, `image_order`, `uploaded_by`, `file_size`, `image_width`, `image_height`, `alt_text`, `is_primary`, `created_at`) VALUES
	(1, NULL, 2, 'http://localhost:3000/uploads/locations/2/original_1750641915626_0.jpg', 'http://localhost:3000/uploads/locations/2/thumb_1750641915626_0.jpg', 0, 2, 319950, 1920, 1080, NULL, 0, '2025-06-23 01:25:15'),
	(2, NULL, 2, 'http://localhost:3000/uploads/locations/2/original_1750641915814_1.jpg', 'http://localhost:3000/uploads/locations/2/thumb_1750641915814_1.jpg', 1, 2, 504761, 1920, 1080, NULL, 0, '2025-06-23 01:25:15'),
	(3, NULL, 3, 'http://192.168.0.116:3000/uploads/locations/3/original_1750647562318_1.jpg', 'http://192.168.0.116:3000/uploads/locations/3/thumb_1750647562318_1.jpg', 1, 1, 319950, 1920, 1080, NULL, 0, '2025-06-23 02:59:22'),
	(4, NULL, 3, 'http://192.168.0.116:3000/uploads/locations/3/original_1750647562513_0.jpg', 'http://192.168.0.116:3000/uploads/locations/3/thumb_1750647562513_0.jpg', 0, 1, 504761, 1920, 1080, NULL, 0, '2025-06-23 02:59:22'),
	(5, NULL, 4, 'http://192.168.0.116:3000/uploads/locations/4/original_1750725383000_0.jpg', 'http://192.168.0.116:3000/uploads/locations/4/thumb_1750725383000_0.jpg', 0, 1, 386585, 1920, 1080, NULL, 0, '2025-06-24 00:36:23');

-- Dumping structure for table abandoned_explorer.location_tags
CREATE TABLE IF NOT EXISTS `location_tags` (
  `location_id` int(11) NOT NULL,
  `tag_id` int(11) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`location_id`,`tag_id`),
  KEY `idx_location` (`location_id`),
  KEY `idx_tag` (`tag_id`),
  CONSTRAINT `location_tags_ibfk_1` FOREIGN KEY (`location_id`) REFERENCES `locations` (`id`) ON DELETE CASCADE,
  CONSTRAINT `location_tags_ibfk_2` FOREIGN KEY (`tag_id`) REFERENCES `tags` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table abandoned_explorer.location_tags: ~0 rows (approximately)

-- Dumping structure for table abandoned_explorer.location_visits
CREATE TABLE IF NOT EXISTS `location_visits` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `uuid` char(36) DEFAULT NULL,
  `location_id` int(11) NOT NULL,
  `user_id` int(11) DEFAULT NULL,
  `ip_address` varchar(45) DEFAULT NULL,
  `user_agent` text DEFAULT NULL,
  `visited_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uuid` (`uuid`),
  KEY `idx_uuid` (`uuid`),
  KEY `idx_location_visits` (`location_id`,`visited_at`),
  KEY `idx_user_visits` (`user_id`,`visited_at`),
  CONSTRAINT `location_visits_ibfk_1` FOREIGN KEY (`location_id`) REFERENCES `locations` (`id`) ON DELETE CASCADE,
  CONSTRAINT `location_visits_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table abandoned_explorer.location_visits: ~0 rows (approximately)

-- Dumping structure for table abandoned_explorer.notifications
CREATE TABLE IF NOT EXISTS `notifications` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `uuid` char(36) DEFAULT NULL,
  `user_id` int(11) NOT NULL,
  `title` varchar(255) NOT NULL,
  `message` text NOT NULL,
  `type` enum('like','comment','bookmark','approval','system') NOT NULL,
  `related_type` enum('location','comment','user') DEFAULT NULL,
  `related_id` int(11) DEFAULT NULL,
  `is_read` tinyint(1) DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uuid` (`uuid`),
  KEY `idx_uuid` (`uuid`),
  KEY `idx_user_notifications` (`user_id`,`created_at`),
  KEY `idx_unread` (`user_id`,`is_read`),
  KEY `idx_type` (`type`),
  CONSTRAINT `notifications_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table abandoned_explorer.notifications: ~0 rows (approximately)

-- Dumping structure for table abandoned_explorer.reports
CREATE TABLE IF NOT EXISTS `reports` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `uuid` char(36) DEFAULT NULL,
  `reporter_id` int(11) NOT NULL,
  `reported_type` enum('location','comment','user') NOT NULL,
  `reported_id` int(11) NOT NULL,
  `reason` enum('inappropriate','spam','fake','dangerous','other') NOT NULL,
  `description` text DEFAULT NULL,
  `status` enum('pending','reviewed','resolved','dismissed') DEFAULT 'pending',
  `resolved_by` int(11) DEFAULT NULL,
  `resolved_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uuid` (`uuid`),
  KEY `resolved_by` (`resolved_by`),
  KEY `idx_uuid` (`uuid`),
  KEY `idx_reporter` (`reporter_id`),
  KEY `idx_reported` (`reported_type`,`reported_id`),
  KEY `idx_status` (`status`),
  KEY `idx_created_at` (`created_at`),
  CONSTRAINT `reports_ibfk_1` FOREIGN KEY (`reporter_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `reports_ibfk_2` FOREIGN KEY (`resolved_by`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table abandoned_explorer.reports: ~0 rows (approximately)

-- Dumping structure for table abandoned_explorer.tags
CREATE TABLE IF NOT EXISTS `tags` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL,
  `usage_count` int(11) DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`),
  KEY `idx_name` (`name`),
  KEY `idx_usage_count` (`usage_count`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table abandoned_explorer.tags: ~0 rows (approximately)

-- Dumping structure for table abandoned_explorer.users
CREATE TABLE IF NOT EXISTS `users` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `uuid` char(36) DEFAULT NULL,
  `username` varchar(50) NOT NULL,
  `email` varchar(255) NOT NULL,
  `password_hash` varchar(255) NOT NULL,
  `age` int(11) DEFAULT NULL,
  `is_premium` tinyint(1) DEFAULT 0,
  `profile_image_url` varchar(500) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `last_login` timestamp NULL DEFAULT NULL,
  `is_active` tinyint(1) DEFAULT 1,
  `email_verified` tinyint(1) DEFAULT 0,
  `phone_number` varchar(20) DEFAULT NULL,
  `bio` text DEFAULT NULL,
  `profile_picture_url` varchar(500) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `username` (`username`),
  UNIQUE KEY `email` (`email`),
  UNIQUE KEY `uuid` (`uuid`),
  KEY `idx_uuid` (`uuid`),
  KEY `idx_username` (`username`),
  KEY `idx_email` (`email`),
  KEY `idx_is_premium` (`is_premium`),
  KEY `idx_created_at` (`created_at`),
  KEY `idx_email_verified` (`email_verified`),
  KEY `idx_last_login` (`last_login`),
  KEY `idx_active_status` (`is_active`,`last_login`)
) ENGINE=InnoDB AUTO_INCREMENT=351 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table abandoned_explorer.users: ~92 rows (approximately)
INSERT INTO `users` (`id`, `uuid`, `username`, `email`, `password_hash`, `age`, `is_premium`, `profile_image_url`, `created_at`, `updated_at`, `last_login`, `is_active`, `email_verified`, `phone_number`, `bio`, `profile_picture_url`) VALUES
	(1, NULL, 'test', 'test@test.com', '$2a$12$v5CguxvZGnoz3/rd18WWWu1QvgUkfgjczZk7ah8FxbZJZgs1XmOwG', 18, 0, NULL, '2025-06-22 23:49:51', '2025-06-24 23:59:42', '2025-06-24 23:59:42', 1, 0, NULL, NULL, NULL),
	(2, NULL, 'admin', 'admin@admin.com', '$2a$12$v5gBvVxl6dlJkqmtLaxXSO6KdZGuSbn9iwATEh2js7caXpbphKNx.', 18, 0, NULL, '2025-06-23 01:10:05', '2025-06-25 08:42:38', '2025-06-25 08:42:38', 1, 0, NULL, NULL, NULL),
	(18, NULL, 'alex_nyc', 'alex@example.com', '$2b$10$hash1', NULL, 1, 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100', '2025-06-24 11:56:40', '2025-06-24 12:22:22', '2025-06-24 11:54:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100'),
	(19, NULL, 'maria_london', 'maria@example.com', '$2b$10$hash2', NULL, 0, 'https://images.unsplash.com/photo-1494790108755-2616b612b786?w=100', '2025-06-24 11:56:40', '2025-06-24 12:22:22', '2025-06-24 11:55:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1494790108755-2616b612b786?w=100'),
	(20, NULL, 'tom_paris', 'tom@example.com', '$2b$10$hash3', NULL, 1, 'https://images.unsplash.com/photo-1599566150163-29194dcaad36?w=100', '2025-06-24 11:56:40', '2025-06-24 12:22:22', '2025-06-24 11:53:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1599566150163-29194dcaad36?w=100'),
	(21, NULL, 'sarah_tokyo', 'sarah@example.com', '$2b$10$hash4', NULL, 0, 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=100', '2025-06-24 11:56:40', '2025-06-24 12:22:22', '2025-06-24 11:52:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=100'),
	(22, NULL, 'david_sydney', 'david@example.com', '$2b$10$hash5', NULL, 1, 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100', '2025-06-24 11:56:40', '2025-06-24 12:22:22', '2025-06-24 11:51:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100'),
	(23, NULL, 'emma_berlin', 'emma@example.com', '$2b$10$hash6', NULL, 0, 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=100', '2025-06-24 11:56:40', '2025-06-24 12:22:22', '2025-06-24 11:54:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=100'),
	(24, NULL, 'james_toronto', 'james@example.com', '$2b$10$hash7', NULL, 1, 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100', '2025-06-24 11:56:40', '2025-06-24 12:22:22', '2025-06-24 11:55:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100'),
	(25, NULL, 'lisa_amsterdam', 'lisa@example.com', '$2b$10$hash8', NULL, 0, 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=100', '2025-06-24 11:56:40', '2025-06-24 12:22:22', '2025-06-24 11:53:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=100'),
	(26, NULL, 'mike_chicago', 'mike@example.com', '$2b$10$hash9', NULL, 1, 'https://images.unsplash.com/photo-1519244703995-f4e0f30006d5?w=100', '2025-06-24 11:56:40', '2025-06-24 12:22:22', '2025-06-24 11:52:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1519244703995-f4e0f30006d5?w=100'),
	(27, NULL, 'anna_madrid', 'anna@example.com', '$2b$10$hash10', NULL, 0, 'https://images.unsplash.com/photo-1502764613149-7f1d229e230f?w=100', '2025-06-24 11:56:40', '2025-06-24 12:22:22', '2025-06-24 11:51:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1502764613149-7f1d229e230f?w=100'),
	(28, NULL, 'john_vancouver', 'john@example.com', '$2b$10$hash11', NULL, 0, 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100', '2025-06-24 11:56:40', '2025-06-24 12:22:22', '2025-06-24 12:07:22', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100'),
	(29, NULL, 'sophie_rome', 'sophie@example.com', '$2b$10$hash12', NULL, 1, 'https://images.unsplash.com/photo-1487412720507-e7ab37603c6f?w=100', '2025-06-24 11:56:40', '2025-06-24 12:22:22', '2025-06-24 12:02:22', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1487412720507-e7ab37603c6f?w=100'),
	(30, NULL, 'carlos_barcelona', 'carlos@example.com', '$2b$10$hash13', NULL, 0, 'https://images.unsplash.com/photo-1560250097-0b93528c311a?w=100', '2025-06-24 11:56:40', '2025-06-24 12:22:22', '2025-06-24 11:57:22', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1560250097-0b93528c311a?w=100'),
	(31, NULL, 'nina_vienna', 'nina@example.com', '$2b$10$hash14', NULL, 1, 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100', '2025-06-24 11:56:40', '2025-06-24 12:22:22', '2025-06-24 12:12:22', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100'),
	(32, NULL, 'peter_moscow', 'peter@example.com', '$2b$10$hash15', NULL, 0, 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=100', '2025-06-24 11:56:40', '2025-06-24 12:22:22', '2025-06-24 12:04:22', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=100'),
	(33, NULL, 'chloe_zurich', 'chloe@example.com', '$2b$10$hash16', NULL, 1, 'https://images.unsplash.com/photo-1508214751196-bcfd4ca60f91?w=100', '2025-06-24 11:56:40', '2025-06-24 12:22:22', '2025-06-24 12:10:22', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1508214751196-bcfd4ca60f91?w=100'),
	(34, NULL, 'lucas_melbourne', 'lucas@example.com', '$2b$10$hash17', NULL, 0, 'https://images.unsplash.com/photo-1552058544-f2b08422138a?w=100', '2025-06-24 11:56:40', '2025-06-24 12:22:22', '2025-06-24 11:54:22', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1552058544-f2b08422138a?w=100'),
	(35, NULL, 'grace_oslo', 'grace@example.com', '$2b$10$hash18', NULL, 1, 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=100', '2025-06-24 11:56:40', '2025-06-24 12:22:22', '2025-06-24 12:00:22', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=100'),
	(36, NULL, 'ryan_dublin', 'ryan@example.com', '$2b$10$hash19', NULL, 0, 'https://images.unsplash.com/photo-1547425260-76bcadfb4f2c?w=100', '2025-06-24 11:56:40', '2025-06-24 12:22:22', '2025-06-24 12:06:22', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1547425260-76bcadfb4f2c?w=100'),
	(37, NULL, 'zoe_stockholm', 'zoe@example.com', '$2b$10$hash20', NULL, 1, 'https://images.unsplash.com/photo-1489424731084-a5d8b219a5bb?w=100', '2025-06-24 11:56:40', '2025-06-24 12:22:22', '2025-06-24 11:58:22', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1489424731084-a5d8b219a5bb?w=100'),
	(38, NULL, 'ben_brussels', 'ben@example.com', '$2b$10$hash21', NULL, 0, 'https://images.unsplash.com/photo-1557862921-37829c790f19?w=100', '2025-06-24 11:56:40', '2025-06-24 12:22:22', '2025-06-24 11:37:22', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1557862921-37829c790f19?w=100'),
	(39, NULL, 'mia_copenhagen', 'mia@example.com', '$2b$10$hash22', NULL, 1, 'https://images.unsplash.com/photo-1531123897727-8f129e1688ce?w=100', '2025-06-24 11:56:40', '2025-06-24 12:22:22', '2025-06-24 11:17:22', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1531123897727-8f129e1688ce?w=100'),
	(40, NULL, 'noah_helsinki', 'noah@example.com', '$2b$10$hash23', NULL, 0, 'https://images.unsplash.com/photo-1503443207922-dff7d543fd0e?w=100', '2025-06-24 11:56:40', '2025-06-24 12:22:22', '2025-06-24 10:52:22', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1503443207922-dff7d543fd0e?w=100'),
	(41, NULL, 'eva_budapest', 'eva@example.com', '$2b$10$hash24', NULL, 1, 'https://images.unsplash.com/photo-1616766098956-c81f12114571?w=100', '2025-06-24 11:56:40', '2025-06-24 12:22:22', '2025-06-24 11:07:22', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1616766098956-c81f12114571?w=100'),
	(42, NULL, 'leo_prague', 'leo@example.com', '$2b$10$hash25', NULL, 0, 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=100', '2025-06-24 11:56:40', '2025-06-24 12:22:22', '2025-06-24 10:32:22', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=100'),
	(43, NULL, 'isla_warsaw', 'isla@example.com', '$2b$10$hash26', NULL, 1, NULL, '2025-06-24 11:56:40', '2025-06-24 11:56:40', '2025-06-24 10:31:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1508186225823-0963cf9ab0de?w=100'),
	(44, NULL, 'finn_munich', 'finn@example.com', '$2b$10$hash27', NULL, 0, NULL, '2025-06-24 11:56:40', '2025-06-24 11:56:40', '2025-06-24 10:21:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1504593811423-6dd665756598?w=100'),
	(45, NULL, 'ruby_milan', 'ruby@example.com', '$2b$10$hash28', NULL, 1, NULL, '2025-06-24 11:56:40', '2025-06-24 11:56:40', '2025-06-24 10:46:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1521119989659-a83eee488004?w=100'),
	(46, NULL, 'oscar_lisbon', 'oscar@example.com', '$2b$10$hash29', NULL, 0, NULL, '2025-06-24 11:56:40', '2025-06-24 11:56:40', '2025-06-24 10:16:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1558203728-00f45181dd84?w=100'),
	(47, NULL, 'ivy_athens', 'ivy@example.com', '$2b$10$hash30', NULL, 1, NULL, '2025-06-24 11:56:40', '2025-06-24 11:56:40', '2025-06-24 10:56:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=100'),
	(48, NULL, 'jake_la', 'jake@example.com', '$2b$10$hash31', NULL, 0, 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=100', '2025-06-24 11:56:40', '2025-06-24 12:22:22', '2025-06-24 11:52:22', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=100'),
	(49, NULL, 'lily_miami', 'lily@example.com', '$2b$10$hash32', NULL, 1, 'https://images.unsplash.com/photo-1525134479668-1bee5c7c6845?w=100', '2025-06-24 11:56:40', '2025-06-24 12:22:22', '2025-06-24 11:42:22', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1525134479668-1bee5c7c6845?w=100'),
	(50, NULL, 'ethan_denver', 'ethan@example.com', '$2b$10$hash33', NULL, 0, 'https://images.unsplash.com/photo-1542909168-82c3e7fdca5c?w=100', '2025-06-24 11:56:40', '2025-06-24 12:22:22', '2025-06-24 11:32:22', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1542909168-82c3e7fdca5c?w=100'),
	(51, NULL, 'ava_seattle', 'ava@example.com', '$2b$10$hash34', NULL, 1, 'https://images.unsplash.com/photo-1494790108755-2616b612b786?w=100', '2025-06-24 11:56:40', '2025-06-24 12:22:22', '2025-06-24 11:47:22', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1494790108755-2616b612b786?w=100'),
	(52, NULL, 'owen_houston', 'owen@example.com', '$2b$10$hash35', NULL, 0, 'https://images.unsplash.com/photo-1507591064344-4c6ce005b128?w=100', '2025-06-24 11:56:40', '2025-06-24 12:22:22', '2025-06-24 11:02:22', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1507591064344-4c6ce005b128?w=100'),
	(53, NULL, 'maya_phoenix', 'maya@example.com', '$2b$10$hash36', NULL, 1, 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=100', '2025-06-24 11:56:40', '2025-06-24 12:22:22', '2025-06-24 11:57:22', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=100'),
	(54, NULL, 'liam_boston', 'liam@example.com', '$2b$10$hash37', NULL, 0, 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100', '2025-06-24 11:56:40', '2025-06-24 12:22:22', '2025-06-24 11:27:22', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100'),
	(55, NULL, 'nora_atlanta', 'nora@example.com', '$2b$10$hash38', NULL, 1, 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=100', '2025-06-24 11:56:40', '2025-06-24 12:22:22', '2025-06-24 11:37:22', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=100'),
	(56, NULL, 'theo_portland', 'theo@example.com', '$2b$10$hash39', NULL, 0, NULL, '2025-06-24 11:56:40', '2025-06-24 11:56:40', '2025-06-24 10:51:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1599566150163-29194dcaad36?w=100'),
	(57, NULL, 'zara_vegas', 'zara@example.com', '$2b$10$hash40', NULL, 1, NULL, '2025-06-24 11:56:40', '2025-06-24 11:56:40', '2025-06-24 10:41:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=100'),
	(58, NULL, 'kenji_osaka', 'kenji@example.com', '$2b$10$hash41', NULL, 0, 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100', '2025-06-24 11:56:40', '2025-06-24 12:22:22', '2025-06-24 12:02:22', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100'),
	(59, NULL, 'yuki_seoul', 'yuki@example.com', '$2b$10$hash42', NULL, 1, 'https://images.unsplash.com/photo-1502764613149-7f1d229e230f?w=100', '2025-06-24 11:56:40', '2025-06-24 12:22:22', '2025-06-24 11:52:22', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1502764613149-7f1d229e230f?w=100'),
	(60, NULL, 'chen_beijing', 'chen@example.com', '$2b$10$hash43', NULL, 0, 'https://images.unsplash.com/photo-1519244703995-f4e0f30006d5?w=100', '2025-06-24 11:56:40', '2025-06-24 12:22:22', '2025-06-24 11:42:22', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1519244703995-f4e0f30006d5?w=100'),
	(61, NULL, 'priya_mumbai', 'priya@example.com', '$2b$10$hash44', NULL, 1, 'https://images.unsplash.com/photo-1487412720507-e7ab37603c6f?w=100', '2025-06-24 11:56:40', '2025-06-24 12:22:22', '2025-06-24 11:32:22', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1487412720507-e7ab37603c6f?w=100'),
	(62, NULL, 'raj_bangalore', 'raj@example.com', '$2b$10$hash45', NULL, 0, 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100', '2025-06-24 11:56:40', '2025-06-24 12:22:22', '2025-06-24 11:22:22', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100'),
	(63, NULL, 'ming_shanghai', 'ming@example.com', '$2b$10$hash46', NULL, 1, NULL, '2025-06-24 11:56:40', '2025-06-24 11:56:40', '2025-06-24 11:21:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1560250097-0b93528c311a?w=100'),
	(64, NULL, 'siti_jakarta', 'siti@example.com', '$2b$10$hash47', NULL, 0, NULL, '2025-06-24 11:56:40', '2025-06-24 11:56:40', '2025-06-24 11:11:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100'),
	(65, NULL, 'kumar_delhi', 'kumar@example.com', '$2b$10$hash48', NULL, 1, NULL, '2025-06-24 11:56:40', '2025-06-24 11:56:40', '2025-06-24 11:01:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=100'),
	(66, NULL, 'lin_taipei', 'lin@example.com', '$2b$10$hash49', NULL, 0, NULL, '2025-06-24 11:56:40', '2025-06-24 11:56:40', '2025-06-24 11:31:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1508214751196-bcfd4ca60f91?w=100'),
	(67, NULL, 'aaron_singapore', 'aaron@example.com', '$2b$10$hash50', NULL, 1, NULL, '2025-06-24 11:56:40', '2025-06-24 11:56:40', '2025-06-24 10:46:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1552058544-f2b08422138a?w=100'),
	(68, NULL, 'amara_cairo', 'amara@example.com', '$2b$10$hash51', NULL, 0, NULL, '2025-06-24 11:56:40', '2025-06-24 11:56:40', '2025-06-24 10:36:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=100'),
	(69, NULL, 'omar_dubai', 'omar@example.com', '$2b$10$hash52', NULL, 1, NULL, '2025-06-24 11:56:40', '2025-06-24 11:56:40', '2025-06-24 10:26:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1547425260-76bcadfb4f2c?w=100'),
	(70, NULL, 'fatima_riyadh', 'fatima@example.com', '$2b$10$hash53', NULL, 0, NULL, '2025-06-24 11:56:40', '2025-06-24 11:56:40', '2025-06-24 10:16:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1489424731084-a5d8b219a5bb?w=100'),
	(71, NULL, 'hassan_istanbul', 'hassan@example.com', '$2b$10$hash54', NULL, 1, NULL, '2025-06-24 11:56:40', '2025-06-24 11:56:40', '2025-06-24 10:31:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1557862921-37829c790f19?w=100'),
	(72, NULL, 'kemi_lagos', 'kemi@example.com', '$2b$10$hash55', NULL, 0, NULL, '2025-06-24 11:56:40', '2025-06-24 11:56:40', '2025-06-24 10:21:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1531123897727-8f129e1688ce?w=100'),
	(73, NULL, 'thandiwe_johannesburg', 'thandiwe@example.com', '$2b$10$hash56', NULL, 1, NULL, '2025-06-24 11:56:40', '2025-06-24 11:56:40', '2025-06-24 10:41:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1503443207922-dff7d543fd0e?w=100'),
	(74, NULL, 'youssef_casablanca', 'youssef@example.com', '$2b$10$hash57', NULL, 0, NULL, '2025-06-24 11:56:40', '2025-06-24 11:56:40', '2025-06-24 10:51:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1616766098956-c81f12114571?w=100'),
	(75, NULL, 'aisha_nairobi', 'aisha@example.com', '$2b$10$hash58', NULL, 1, NULL, '2025-06-24 11:56:40', '2025-06-24 11:56:40', '2025-06-24 10:11:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=100'),
	(76, NULL, 'tariq_tehran', 'tariq@example.com', '$2b$10$hash59', NULL, 0, NULL, '2025-06-24 11:56:40', '2025-06-24 11:56:40', '2025-06-24 10:01:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1508186225823-0963cf9ab0de?w=100'),
	(77, NULL, 'zara_doha', 'zara2@example.com', '$2b$10$hash60', NULL, 1, NULL, '2025-06-24 11:56:40', '2025-06-24 11:56:40', '2025-06-24 11:01:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1504593811423-6dd665756598?w=100'),
	(78, NULL, 'diego_mexico_city', 'diego@example.com', '$2b$10$hash61', NULL, 0, 'https://images.unsplash.com/photo-1521119989659-a83eee488004?w=100', '2025-06-24 11:56:40', '2025-06-24 12:22:22', '2025-06-24 11:42:22', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1521119989659-a83eee488004?w=100'),
	(79, NULL, 'sofia_buenos_aires', 'sofia@example.com', '$2b$10$hash62', NULL, 1, 'https://images.unsplash.com/photo-1558203728-00f45181dd84?w=100', '2025-06-24 11:56:40', '2025-06-24 12:22:22', '2025-06-24 11:32:22', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1558203728-00f45181dd84?w=100'),
	(80, NULL, 'ricardo_sao_paulo', 'ricardo@example.com', '$2b$10$hash63', NULL, 0, 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=100', '2025-06-24 11:56:40', '2025-06-24 12:22:22', '2025-06-24 11:22:22', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=100'),
	(81, NULL, 'valeria_lima', 'valeria@example.com', '$2b$10$hash64', NULL, 1, NULL, '2025-06-24 11:56:40', '2025-06-24 11:56:40', '2025-06-24 10:46:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=100'),
	(82, NULL, 'carlos_bogota', 'carlos2@example.com', '$2b$10$hash65', NULL, 0, NULL, '2025-06-24 11:56:40', '2025-06-24 11:56:40', '2025-06-24 10:36:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1525134479668-1bee5c7c6845?w=100'),
	(83, NULL, 'lucia_santiago', 'lucia@example.com', '$2b$10$hash66', NULL, 1, NULL, '2025-06-24 11:56:40', '2025-06-24 11:56:40', '2025-06-24 10:26:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1542909168-82c3e7fdca5c?w=100'),
	(84, NULL, 'pablo_caracas', 'pablo@example.com', '$2b$10$hash67', NULL, 0, NULL, '2025-06-24 11:56:40', '2025-06-24 11:56:40', '2025-06-24 10:16:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1494790108755-2616b612b786?w=100'),
	(85, NULL, 'isabella_quito', 'isabella@example.com', '$2b$10$hash68', NULL, 1, NULL, '2025-06-24 11:56:40', '2025-06-24 11:56:40', '2025-06-24 10:31:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1507591064344-4c6ce005b128?w=100'),
	(86, NULL, 'mateo_montevideo', 'mateo@example.com', '$2b$10$hash69', NULL, 0, NULL, '2025-06-24 11:56:40', '2025-06-24 11:56:40', '2025-06-24 10:21:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=100'),
	(87, NULL, 'camila_la_paz', 'camila@example.com', '$2b$10$hash70', NULL, 1, NULL, '2025-06-24 11:56:40', '2025-06-24 11:56:40', '2025-06-24 10:41:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100'),
	(88, NULL, 'brandon_dallas', 'brandon@example.com', '$2b$10$hash71', NULL, 0, NULL, '2025-06-24 11:56:40', '2025-06-24 11:56:40', '2025-06-24 11:11:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=100'),
	(89, NULL, 'taylor_detroit', 'taylor@example.com', '$2b$10$hash72', NULL, 1, NULL, '2025-06-24 11:56:40', '2025-06-24 11:56:40', '2025-06-24 11:01:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1599566150163-29194dcaad36?w=100'),
	(90, NULL, 'jordan_philadelphia', 'jordan@example.com', '$2b$10$hash73', NULL, 0, NULL, '2025-06-24 11:56:40', '2025-06-24 11:56:40', '2025-06-24 10:51:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=100'),
	(91, NULL, 'riley_nashville', 'riley@example.com', '$2b$10$hash74', NULL, 1, NULL, '2025-06-24 11:56:40', '2025-06-24 11:56:40', '2025-06-24 10:41:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100'),
	(92, NULL, 'casey_sacramento', 'casey@example.com', '$2b$10$hash75', NULL, 0, NULL, '2025-06-24 11:56:40', '2025-06-24 11:56:40', '2025-06-24 10:31:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1502764613149-7f1d229e230f?w=100'),
	(93, NULL, 'jamie_salt_lake', 'jamie@example.com', '$2b$10$hash76', NULL, 1, NULL, '2025-06-24 11:56:40', '2025-06-24 11:56:40', '2025-06-24 10:21:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1519244703995-f4e0f30006d5?w=100'),
	(94, NULL, 'alex_minneapolis', 'alex2@example.com', '$2b$10$hash77', NULL, 0, NULL, '2025-06-24 11:56:40', '2025-06-24 11:56:40', '2025-06-24 10:11:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1487412720507-e7ab37603c6f?w=100'),
	(95, NULL, 'drew_kansas_city', 'drew@example.com', '$2b$10$hash78', NULL, 1, NULL, '2025-06-24 11:56:40', '2025-06-24 11:56:40', '2025-06-24 11:21:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100'),
	(96, NULL, 'sage_richmond', 'sage@example.com', '$2b$10$hash79', NULL, 0, NULL, '2025-06-24 11:56:40', '2025-06-24 11:56:40', '2025-06-24 10:01:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1560250097-0b93528c311a?w=100'),
	(97, NULL, 'river_charlotte', 'river@example.com', '$2b$10$hash80', NULL, 1, NULL, '2025-06-24 11:56:40', '2025-06-24 11:56:40', '2025-06-24 11:31:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100'),
	(98, NULL, 'jackson_auckland', 'jackson@example.com', '$2b$10$hash81', NULL, 0, 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=100', '2025-06-24 11:56:40', '2025-06-24 12:22:22', '2025-06-24 11:22:22', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=100'),
	(99, NULL, 'harper_wellington', 'harper@example.com', '$2b$10$hash82', NULL, 1, 'https://images.unsplash.com/photo-1508214751196-bcfd4ca60f91?w=100', '2025-06-24 11:56:40', '2025-06-24 12:22:22', '2025-06-24 11:12:22', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1508214751196-bcfd4ca60f91?w=100'),
	(100, NULL, 'mason_brisbane', 'mason@example.com', '$2b$10$hash83', NULL, 0, NULL, '2025-06-24 11:56:40', '2025-06-24 11:56:40', '2025-06-24 10:36:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1552058544-f2b08422138a?w=100'),
	(101, NULL, 'ella_perth', 'ella@example.com', '$2b$10$hash84', NULL, 1, NULL, '2025-06-24 11:56:40', '2025-06-24 11:56:40', '2025-06-24 10:26:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=100'),
	(102, NULL, 'logan_adelaide', 'logan@example.com', '$2b$10$hash85', NULL, 0, NULL, '2025-06-24 11:56:40', '2025-06-24 11:56:40', '2025-06-24 10:16:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1547425260-76bcadfb4f2c?w=100'),
	(103, NULL, 'felix_florence', 'felix@example.com', '$2b$10$hash86', NULL, 1, NULL, '2025-06-24 11:56:40', '2025-06-24 11:56:40', '2025-06-24 11:11:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1489424731084-a5d8b219a5bb?w=100'),
	(104, NULL, 'luna_venice', 'luna@example.com', '$2b$10$hash87', NULL, 0, NULL, '2025-06-24 11:56:40', '2025-06-24 11:56:40', '2025-06-24 11:01:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1557862921-37829c790f19?w=100'),
	(105, NULL, 'hugo_lyon', 'hugo@example.com', '$2b$10$hash88', NULL, 1, NULL, '2025-06-24 11:56:40', '2025-06-24 11:56:40', '2025-06-24 10:51:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1531123897727-8f129e1688ce?w=100'),
	(106, NULL, 'clara_marseille', 'clara@example.com', '$2b$10$hash89', NULL, 0, NULL, '2025-06-24 11:56:40', '2025-06-24 11:56:40', '2025-06-24 10:41:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1503443207922-dff7d543fd0e?w=100'),
	(107, NULL, 'axel_gothenburg', 'axel@example.com', '$2b$10$hash90', NULL, 1, NULL, '2025-06-24 11:56:40', '2025-06-24 11:56:40', '2025-06-24 10:31:40', 1, 0, NULL, NULL, 'https://images.unsplash.com/photo-1616766098956-c81f12114571?w=100');

-- Dumping structure for table abandoned_explorer.user_locations
CREATE TABLE IF NOT EXISTS `user_locations` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `user_id` int(11) NOT NULL,
  `latitude` decimal(10,8) NOT NULL,
  `longitude` decimal(11,8) NOT NULL,
  `accuracy_meters` int(11) DEFAULT 1000,
  `location_name` varchar(255) DEFAULT NULL,
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_user_location` (`user_id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_coordinates` (`latitude`,`longitude`),
  KEY `idx_updated_at` (`updated_at`),
  CONSTRAINT `user_locations_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=90 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table abandoned_explorer.user_locations: ~58 rows (approximately)
INSERT INTO `user_locations` (`id`, `user_id`, `latitude`, `longitude`, `accuracy_meters`, `location_name`, `updated_at`, `created_at`) VALUES
	(1, 2, 42.34304717, 27.18901499, 1000, NULL, '2025-06-25 08:42:38', '2025-06-24 10:16:44'),
	(2, 1, 37.78583400, -122.40641700, 1000, NULL, '2025-06-24 23:59:42', '2025-06-24 10:16:44'),
	(32, 18, 40.71280000, -74.00600000, 50, 'New York, NY, USA', '2025-06-24 12:20:22', '2025-06-24 12:22:22'),
	(33, 19, 51.50740000, -0.12780000, 30, 'London, UK', '2025-06-24 12:21:22', '2025-06-24 12:22:22'),
	(34, 20, 48.85660000, 2.35220000, 40, 'Paris, France', '2025-06-24 12:19:22', '2025-06-24 12:22:22'),
	(35, 21, 35.67620000, 139.65030000, 60, 'Tokyo, Japan', '2025-06-24 12:18:22', '2025-06-24 12:22:22'),
	(36, 22, -33.86880000, 151.20930000, 45, 'Sydney, Australia', '2025-06-24 12:17:22', '2025-06-24 12:22:22'),
	(37, 23, 52.52000000, 13.40500000, 35, 'Berlin, Germany', '2025-06-24 12:20:22', '2025-06-24 12:22:22'),
	(38, 24, 43.65320000, -79.38320000, 50, 'Toronto, Canada', '2025-06-24 12:21:22', '2025-06-24 12:22:22'),
	(39, 25, 52.36760000, 4.90410000, 25, 'Amsterdam, Netherlands', '2025-06-24 12:19:22', '2025-06-24 12:22:22'),
	(40, 26, 41.87810000, -87.62980000, 55, 'Chicago, IL, USA', '2025-06-24 12:18:22', '2025-06-24 12:22:22'),
	(41, 27, 40.41680000, -3.70380000, 40, 'Madrid, Spain', '2025-06-24 12:17:22', '2025-06-24 12:22:22'),
	(42, 28, 49.28270000, -123.12070000, 70, 'Vancouver, Canada', '2025-06-24 12:07:22', '2025-06-24 12:22:22'),
	(43, 29, 41.90280000, 12.49640000, 80, 'Rome, Italy', '2025-06-24 12:02:22', '2025-06-24 12:22:22'),
	(44, 30, 41.38510000, 2.17340000, 60, 'Barcelona, Spain', '2025-06-24 11:57:22', '2025-06-24 12:22:22'),
	(45, 31, 48.20820000, 16.37380000, 45, 'Vienna, Austria', '2025-06-24 12:12:22', '2025-06-24 12:22:22'),
	(46, 32, 55.75580000, 37.61760000, 90, 'Moscow, Russia', '2025-06-24 12:04:22', '2025-06-24 12:22:22'),
	(47, 33, 47.37690000, 8.54170000, 30, 'Zurich, Switzerland', '2025-06-24 12:10:22', '2025-06-24 12:22:22'),
	(48, 34, -37.81360000, 144.96310000, 65, 'Melbourne, Australia', '2025-06-24 11:54:22', '2025-06-24 12:22:22'),
	(49, 35, 59.91390000, 10.75220000, 40, 'Oslo, Norway', '2025-06-24 12:00:22', '2025-06-24 12:22:22'),
	(50, 36, 53.34980000, -6.26030000, 50, 'Dublin, Ireland', '2025-06-24 12:06:22', '2025-06-24 12:22:22'),
	(51, 37, 59.32930000, 18.06860000, 35, 'Stockholm, Sweden', '2025-06-24 11:58:22', '2025-06-24 12:22:22'),
	(52, 38, 50.85030000, 4.35170000, 75, 'Brussels, Belgium', '2025-06-24 11:37:22', '2025-06-24 12:22:22'),
	(53, 39, 55.67610000, 12.56830000, 55, 'Copenhagen, Denmark', '2025-06-24 11:17:22', '2025-06-24 12:22:22'),
	(54, 40, 60.16990000, 24.93840000, 60, 'Helsinki, Finland', '2025-06-24 10:52:22', '2025-06-24 12:22:22'),
	(55, 41, 47.49790000, 19.04020000, 70, 'Budapest, Hungary', '2025-06-24 11:07:22', '2025-06-24 12:22:22'),
	(56, 42, 50.07550000, 14.43780000, 45, 'Prague, Czech Republic', '2025-06-24 10:32:22', '2025-06-24 12:22:22'),
	(57, 48, 34.05220000, -118.24370000, 60, 'Los Angeles, CA, USA', '2025-06-24 11:52:22', '2025-06-24 12:22:22'),
	(58, 49, 25.76170000, -80.19180000, 45, 'Miami, FL, USA', '2025-06-24 11:42:22', '2025-06-24 12:22:22'),
	(59, 50, 39.73920000, -104.99030000, 70, 'Denver, CO, USA', '2025-06-24 11:32:22', '2025-06-24 12:22:22'),
	(60, 51, 47.60620000, -122.33210000, 40, 'Seattle, WA, USA', '2025-06-24 11:47:22', '2025-06-24 12:22:22'),
	(61, 52, 29.76040000, -95.36980000, 80, 'Houston, TX, USA', '2025-06-24 11:02:22', '2025-06-24 12:22:22'),
	(62, 53, 33.44840000, -112.07400000, 55, 'Phoenix, AZ, USA', '2025-06-24 11:57:22', '2025-06-24 12:22:22'),
	(63, 54, 42.36010000, -71.05890000, 35, 'Boston, MA, USA', '2025-06-24 11:27:22', '2025-06-24 12:22:22'),
	(64, 55, 33.74900000, -84.38800000, 65, 'Atlanta, GA, USA', '2025-06-24 11:37:22', '2025-06-24 12:22:22'),
	(65, 58, 34.69370000, 135.50230000, 40, 'Osaka, Japan', '2025-06-24 12:02:22', '2025-06-24 12:22:22'),
	(66, 59, 37.56650000, 126.97800000, 50, 'Seoul, South Korea', '2025-06-24 11:52:22', '2025-06-24 12:22:22'),
	(67, 60, 39.90420000, 116.40740000, 85, 'Beijing, China', '2025-06-24 11:42:22', '2025-06-24 12:22:22'),
	(68, 61, 19.07600000, 72.87770000, 90, 'Mumbai, India', '2025-06-24 11:32:22', '2025-06-24 12:22:22'),
	(69, 62, 12.97160000, 77.59460000, 70, 'Bangalore, India', '2025-06-24 11:22:22', '2025-06-24 12:22:22'),
	(70, 78, 19.43260000, -99.13320000, 75, 'Mexico City, Mexico', '2025-06-24 11:42:22', '2025-06-24 12:22:22'),
	(71, 79, -34.60370000, -58.38160000, 65, 'Buenos Aires, Argentina', '2025-06-24 11:32:22', '2025-06-24 12:22:22'),
	(72, 80, -23.55050000, -46.63330000, 80, 'São Paulo, Brazil', '2025-06-24 11:22:22', '2025-06-24 12:22:22'),
	(73, 98, -36.84850000, 174.76330000, 50, 'Auckland, New Zealand', '2025-06-24 11:22:22', '2025-06-24 12:22:22'),
	(74, 99, -41.28650000, 174.77620000, 40, 'Wellington, New Zealand', '2025-06-24 11:12:22', '2025-06-24 12:22:22');

-- Dumping structure for table abandoned_explorer.user_preferences
CREATE TABLE IF NOT EXISTS `user_preferences` (
  `user_id` int(11) NOT NULL,
  `category_id` int(11) NOT NULL,
  `notification_enabled` tinyint(1) DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`user_id`,`category_id`),
  KEY `category_id` (`category_id`),
  CONSTRAINT `user_preferences_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `user_preferences_ibfk_2` FOREIGN KEY (`category_id`) REFERENCES `location_categories` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table abandoned_explorer.user_preferences: ~0 rows (approximately)

-- Dumping structure for table abandoned_explorer.user_sessions
CREATE TABLE IF NOT EXISTS `user_sessions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `uuid` char(36) DEFAULT NULL,
  `user_id` int(11) NOT NULL,
  `token_hash` varchar(255) NOT NULL,
  `device_info` text DEFAULT NULL,
  `ip_address` varchar(45) DEFAULT NULL,
  `expires_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `last_used_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uuid` (`uuid`),
  KEY `idx_uuid` (`uuid`),
  KEY `idx_user_sessions` (`user_id`),
  KEY `idx_token_hash` (`token_hash`),
  KEY `idx_expires_at` (`expires_at`),
  CONSTRAINT `user_sessions_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table abandoned_explorer.user_sessions: ~0 rows (approximately)

/*!40103 SET TIME_ZONE=IFNULL(@OLD_TIME_ZONE, 'system') */;
/*!40101 SET SQL_MODE=IFNULL(@OLD_SQL_MODE, '') */;
/*!40014 SET FOREIGN_KEY_CHECKS=IFNULL(@OLD_FOREIGN_KEY_CHECKS, 1) */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40111 SET SQL_NOTES=IFNULL(@OLD_SQL_NOTES, 1) */;
