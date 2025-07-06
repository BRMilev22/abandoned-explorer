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
) ENGINE=InnoDB AUTO_INCREMENT=25 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table abandoned_explorer.bookmarks: ~5 rows (approximately)
INSERT INTO `bookmarks` (`id`, `uuid`, `user_id`, `location_id`, `notes`, `created_at`) VALUES
	(8, NULL, 1, 1, NULL, '2025-06-23 01:00:37'),
	(15, NULL, 2, 2, NULL, '2025-06-23 02:59:43'),
	(22, NULL, 2, 4, NULL, '2025-06-27 12:59:43'),
	(23, NULL, 2, 46, NULL, '2025-06-27 12:59:56'),
	(24, NULL, 1, 4, NULL, '2025-07-02 11:59:28');

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
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table abandoned_explorer.comments: ~8 rows (approximately)
INSERT INTO `comments` (`id`, `uuid`, `location_id`, `user_id`, `comment_text`, `parent_comment_id`, `is_approved`, `likes_count`, `created_at`, `updated_at`) VALUES
	(1, NULL, 46, 2, 'Kur', NULL, 1, 0, '2025-06-27 10:29:52', '2025-06-27 10:29:52'),
	(2, NULL, 4, 2, 'Test', NULL, 1, 0, '2025-06-27 11:41:05', '2025-06-27 11:41:05'),
	(3, NULL, 46, 2, 'Test', 1, 1, 0, '2025-06-27 12:16:28', '2025-06-27 12:16:28'),
	(4, NULL, 46, 2, 'Huuuu', 1, 1, 0, '2025-06-27 12:17:13', '2025-06-27 12:17:13'),
	(5, NULL, 4, 2, 'Testing reply', 2, 1, 0, '2025-06-27 12:31:52', '2025-06-27 12:31:52'),
	(6, NULL, 4, 2, 'Test', 2, 1, 0, '2025-06-27 12:57:45', '2025-06-27 12:57:45'),
	(7, NULL, 4, 2, 'Test', 2, 1, 0, '2025-06-27 12:59:51', '2025-06-27 12:59:51'),
	(8, NULL, 46, 1, 'Test', 1, 1, 0, '2025-06-29 21:40:42', '2025-06-29 21:40:42');

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

-- Dumping structure for table abandoned_explorer.groups
CREATE TABLE IF NOT EXISTS `groups` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `uuid` char(36) DEFAULT NULL,
  `name` varchar(100) NOT NULL,
  `description` text DEFAULT NULL,
  `invite_code` varchar(8) NOT NULL,
  `created_by` int(11) NOT NULL,
  `is_private` tinyint(1) DEFAULT 0,
  `member_limit` int(11) DEFAULT 50,
  `avatar_color` varchar(7) DEFAULT '#7289da',
  `emoji` varchar(10) DEFAULT '?️',
  `region` varchar(50) DEFAULT 'Unknown',
  `points` int(11) DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `invite_code` (`invite_code`),
  UNIQUE KEY `uuid` (`uuid`),
  KEY `idx_uuid` (`uuid`),
  KEY `idx_invite_code` (`invite_code`),
  KEY `idx_created_by` (`created_by`),
  KEY `idx_created_at` (`created_at`),
  KEY `idx_region` (`region`),
  CONSTRAINT `groups_ibfk_1` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table abandoned_explorer.groups: ~0 rows (approximately)

-- Dumping structure for table abandoned_explorer.group_admin_actions
CREATE TABLE IF NOT EXISTS `group_admin_actions` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `uuid` char(36) DEFAULT NULL,
  `group_id` int(11) NOT NULL,
  `admin_id` int(11) NOT NULL,
  `target_user_id` int(11) DEFAULT NULL,
  `action_type` enum('kick','ban','unban','delete_message','promote','demote','delete_group') NOT NULL,
  `reason` text DEFAULT NULL,
  `metadata` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`metadata`)),
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uuid` (`uuid`),
  KEY `idx_uuid` (`uuid`),
  KEY `idx_group_actions` (`group_id`,`created_at`),
  KEY `idx_admin_actions` (`admin_id`,`created_at`),
  KEY `idx_target_user` (`target_user_id`),
  KEY `idx_action_type` (`action_type`),
  CONSTRAINT `group_admin_actions_ibfk_1` FOREIGN KEY (`group_id`) REFERENCES `groups` (`id`) ON DELETE CASCADE,
  CONSTRAINT `group_admin_actions_ibfk_2` FOREIGN KEY (`admin_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `group_admin_actions_ibfk_3` FOREIGN KEY (`target_user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=10 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table abandoned_explorer.group_admin_actions: ~0 rows (approximately)

-- Dumping structure for table abandoned_explorer.group_bans
CREATE TABLE IF NOT EXISTS `group_bans` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `uuid` char(36) DEFAULT NULL,
  `group_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `banned_by` int(11) NOT NULL,
  `ban_reason` text DEFAULT NULL,
  `ban_type` enum('kick','ban') DEFAULT 'ban',
  `is_permanent` tinyint(1) DEFAULT 1,
  `expires_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `unbanned_at` timestamp NULL DEFAULT NULL,
  `unbanned_by` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_active_ban` (`group_id`,`user_id`,`unbanned_at`),
  UNIQUE KEY `uuid` (`uuid`),
  KEY `idx_uuid` (`uuid`),
  KEY `idx_group_bans` (`group_id`,`created_at`),
  KEY `idx_user_bans` (`user_id`,`created_at`),
  KEY `idx_banned_by` (`banned_by`),
  KEY `idx_unbanned_by` (`unbanned_by`),
  KEY `idx_ban_type` (`ban_type`),
  KEY `idx_active_bans` (`group_id`,`unbanned_at`),
  CONSTRAINT `group_bans_ibfk_1` FOREIGN KEY (`group_id`) REFERENCES `groups` (`id`) ON DELETE CASCADE,
  CONSTRAINT `group_bans_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `group_bans_ibfk_3` FOREIGN KEY (`banned_by`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `group_bans_ibfk_4` FOREIGN KEY (`unbanned_by`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table abandoned_explorer.group_bans: ~0 rows (approximately)

-- Dumping structure for table abandoned_explorer.group_locations
CREATE TABLE IF NOT EXISTS `group_locations` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `uuid` char(36) DEFAULT NULL,
  `group_id` int(11) NOT NULL,
  `location_id` int(11) NOT NULL,
  `shared_by` int(11) NOT NULL,
  `notes` text DEFAULT NULL,
  `is_pinned` tinyint(1) DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_group_location` (`group_id`,`location_id`),
  UNIQUE KEY `uuid` (`uuid`),
  KEY `idx_uuid` (`uuid`),
  KEY `idx_group_locations` (`group_id`,`created_at`),
  KEY `idx_location_groups` (`location_id`),
  KEY `idx_shared_by` (`shared_by`),
  KEY `idx_pinned` (`group_id`,`is_pinned`),
  CONSTRAINT `group_locations_ibfk_1` FOREIGN KEY (`group_id`) REFERENCES `groups` (`id`) ON DELETE CASCADE,
  CONSTRAINT `group_locations_ibfk_2` FOREIGN KEY (`location_id`) REFERENCES `locations` (`id`) ON DELETE CASCADE,
  CONSTRAINT `group_locations_ibfk_3` FOREIGN KEY (`shared_by`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table abandoned_explorer.group_locations: ~0 rows (approximately)

-- Dumping structure for table abandoned_explorer.group_members
CREATE TABLE IF NOT EXISTS `group_members` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `uuid` char(36) DEFAULT NULL,
  `group_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `role` enum('owner','admin','member') DEFAULT 'member',
  `nickname` varchar(50) DEFAULT NULL,
  `joined_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `last_active_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_group_member` (`group_id`,`user_id`),
  UNIQUE KEY `uuid` (`uuid`),
  KEY `idx_uuid` (`uuid`),
  KEY `idx_group_members` (`group_id`,`joined_at`),
  KEY `idx_user_groups` (`user_id`,`joined_at`),
  KEY `idx_role` (`role`),
  CONSTRAINT `group_members_ibfk_1` FOREIGN KEY (`group_id`) REFERENCES `groups` (`id`) ON DELETE CASCADE,
  CONSTRAINT `group_members_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=15 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table abandoned_explorer.group_members: ~0 rows (approximately)

-- Dumping structure for table abandoned_explorer.group_messages
CREATE TABLE IF NOT EXISTS `group_messages` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `uuid` char(36) DEFAULT NULL,
  `group_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `message_type` enum('text','location','image','system') DEFAULT 'text',
  `content` text DEFAULT NULL,
  `location_id` int(11) DEFAULT NULL,
  `image_url` varchar(500) DEFAULT NULL,
  `reply_to_id` int(11) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `deleted_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uuid` (`uuid`),
  KEY `idx_uuid` (`uuid`),
  KEY `idx_group_messages` (`group_id`,`created_at`),
  KEY `idx_user_messages` (`user_id`,`created_at`),
  KEY `idx_location_id` (`location_id`),
  KEY `idx_reply_to` (`reply_to_id`),
  CONSTRAINT `group_messages_ibfk_1` FOREIGN KEY (`group_id`) REFERENCES `groups` (`id`) ON DELETE CASCADE,
  CONSTRAINT `group_messages_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `group_messages_ibfk_3` FOREIGN KEY (`location_id`) REFERENCES `locations` (`id`) ON DELETE SET NULL,
  CONSTRAINT `group_messages_ibfk_4` FOREIGN KEY (`reply_to_id`) REFERENCES `group_messages` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=13 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table abandoned_explorer.group_messages: ~0 rows (approximately)

-- Dumping structure for table abandoned_explorer.group_message_likes
CREATE TABLE IF NOT EXISTS `group_message_likes` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `uuid` char(36) DEFAULT NULL,
  `message_id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_message_like` (`message_id`,`user_id`),
  UNIQUE KEY `uuid` (`uuid`),
  KEY `idx_uuid` (`uuid`),
  KEY `idx_message_likes` (`message_id`),
  KEY `idx_user_likes` (`user_id`),
  CONSTRAINT `group_message_likes_ibfk_1` FOREIGN KEY (`message_id`) REFERENCES `group_messages` (`id`) ON DELETE CASCADE,
  CONSTRAINT `group_message_likes_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table abandoned_explorer.group_message_likes: ~0 rows (approximately)

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
) ENGINE=InnoDB AUTO_INCREMENT=25 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table abandoned_explorer.likes: ~4 rows (approximately)
INSERT INTO `likes` (`id`, `uuid`, `user_id`, `location_id`, `created_at`) VALUES
	(10, NULL, 1, 1, '2025-06-23 01:00:39'),
	(15, NULL, 2, 2, '2025-06-23 02:59:43'),
	(23, NULL, 2, 4, '2025-06-27 12:59:42'),
	(24, NULL, 2, 46, '2025-06-27 12:59:56');

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
) ENGINE=InnoDB AUTO_INCREMENT=65 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table abandoned_explorer.locations: ~62 rows (approximately)
INSERT INTO `locations` (`id`, `uuid`, `title`, `description`, `latitude`, `longitude`, `address`, `category_id`, `danger_level_id`, `submitted_by`, `is_approved`, `approval_date`, `approved_by`, `featured`, `views_count`, `likes_count`, `bookmarks_count`, `comments_count`, `created_at`, `updated_at`, `deleted_at`) VALUES
	(1, NULL, 'Abandoned Hospital', 'Description test', 37.78583400, -122.40641700, 'Lat: 37.785834, Lng: -122.406417', 1, 3, 1, 1, '2025-06-23 00:24:56', 1, 0, 971, 35, 36, 0, '2025-06-23 00:03:11', '2025-07-02 11:59:23', NULL),
	(2, NULL, 'Test 2', 'Test 2', 37.78583400, -122.40641700, 'Lat: 37.785834, Lng: -122.406417', 8, 2, 2, 1, '2025-06-23 01:36:42', 2, 0, 530, 79, 8, 0, '2025-06-23 01:25:15', '2025-06-29 23:45:54', NULL),
	(3, NULL, 'Test 3', 'Test 3', 37.78583400, -122.40641700, 'Lat: 37.785834, Lng: -122.406417', 4, 1, 1, 1, '2025-06-23 02:59:54', 2, 0, 688, 87, 33, 0, '2025-06-23 02:59:22', '2025-06-29 16:20:07', NULL),
	(4, NULL, 'Test', 'Teary', 42.34309088, 27.18902228, 'Lat: 42.343091, Lng: 27.189022', 4, 3, 1, 1, '2025-06-24 00:44:30', 2, 0, 822, 1, 2, 4, '2025-06-24 00:36:21', '2025-07-06 13:47:14', NULL),
	(5, '3437302c-50a5-11f0-a415-36cb2806145a', 'Abandoned Hospital NYC', 'Old Bellevue psychiatric ward, creepy but fascinating', 40.73860000, -73.98570000, 'Manhattan, NY', 1, 2, 1, 1, '2025-06-24 02:44:52', NULL, 0, 863, 109, 2, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(6, '34381eb0-50a5-11f0-a415-36cb2806145a', 'Defunct Factory Manhattan', 'Industrial complex from the 1920s', 40.75050000, -73.99340000, 'Manhattan, NY', 2, 2, 1, 1, '2025-06-24 02:44:52', NULL, 0, 885, 155, 90, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(7, '343854ac-50a5-11f0-a415-36cb2806145a', 'Old School Building', 'Abandoned elementary school with intact classrooms', 40.72820000, -73.99420000, 'Manhattan, NY', 3, 1, 1, 1, '2025-06-24 02:44:52', NULL, 0, 787, 43, 42, 0, '2025-06-24 02:44:52', '2025-06-27 09:49:54', NULL),
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
	(18, '34399894-50a5-11f0-a415-36cb2806145a', 'Alcatraz Island Building', 'Former prison administrative building', 37.82670000, -122.42330000, 'San Francisco, CA', 8, 3, 1, 1, '2025-06-24 02:44:52', NULL, 0, 862, 99, 55, 0, '2025-06-24 02:44:52', '2025-06-29 16:37:00', NULL),
	(19, '343999e8-50a5-11f0-a415-36cb2806145a', 'Mission District School', 'Earthquake-damaged school building', 37.75990000, -122.41480000, 'San Francisco, CA', 3, 2, 1, 1, '2025-06-24 02:44:52', NULL, 0, 284, 152, 37, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(20, '34399b14-50a5-11f0-a415-36cb2806145a', 'Windy City Hospital', 'Large medical complex, partially demolished', 41.87810000, -87.62980000, 'Chicago, IL', 1, 2, 1, 1, '2025-06-24 02:44:52', NULL, 0, 789, 60, 18, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(21, '34399c54-50a5-11f0-a415-36cb2806145a', 'Steel Mill Chicago', 'Historic steel production facility', 41.83690000, -87.68470000, 'Chicago, IL', 2, 3, 1, 1, '2025-06-24 02:44:52', NULL, 0, 1043, 41, 78, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(22, '34399d80-50a5-11f0-a415-36cb2806145a', 'Loop Theater', 'Grand movie palace from golden age of cinema', 41.88190000, -87.62780000, 'Chicago, IL', 7, 1, 1, 1, '2025-06-24 02:44:52', NULL, 0, 799, 20, 36, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(23, '34399ede-50a5-11f0-a415-36cb2806145a', 'Art Deco Hospital Miami', 'Pastel-colored medical facility from the 40s', 25.77530000, -80.19010000, 'Miami, FL', 1, 1, 1, 1, '2025-06-24 02:44:52', NULL, 0, 816, 173, 46, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(24, '34399ff6-50a5-11f0-a415-36cb2806145a', 'South Beach Mall', 'Shopping center hit by multiple hurricanes', 25.79070000, -80.13000000, 'Miami Beach, FL', 5, 2, 1, 1, '2025-06-24 02:44:52', NULL, 0, 635, 198, 22, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(25, '3439a0fa-50a5-11f0-a415-36cb2806145a', 'Coral Gables Mansion', 'Luxury home abandoned after foreclosure', 25.74630000, -80.24360000, 'Coral Gables, FL', 4, 1, 1, 1, '2025-06-24 02:44:52', NULL, 0, 675, 67, 71, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(26, '3439a21c-50a5-11f0-a415-36cb2806145a', 'Big D Medical Center', 'Sprawling hospital campus, multiple buildings', 32.77670000, -96.79700000, 'Dallas, TX', 1, 2, 1, 1, '2025-06-24 02:44:52', NULL, 0, 420, 139, 88, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(27, '3439a320-50a5-11f0-a415-36cb2806145a', 'Oil Refinery Dallas', 'Petroleum processing plant from oil boom era', 32.82080000, -96.87140000, 'Dallas, TX', 2, 3, 1, 1, '2025-06-24 02:44:52', NULL, 0, 1025, 87, 26, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(28, '3439a474-50a5-11f0-a415-36cb2806145a', 'Prairie School House', 'One-room schoolhouse from frontier days', 32.73570000, -96.80840000, 'Dallas, TX', 3, 1, 1, 1, '2025-06-24 02:44:52', NULL, 0, 816, 13, 66, 0, '2025-06-24 02:44:52', '2025-06-27 12:55:39', NULL),
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
	(45, '3439b6b2-50a5-11f0-a415-36cb2806145a', 'Opera House Mall', 'Shopping center near the famous opera house', -33.85680000, 151.21530000, 'Sydney, Australia', 5, 1, 1, 1, '2025-06-24 02:44:52', NULL, 0, 176, 117, 9, 0, '2025-06-24 02:44:52', '2025-06-24 02:44:52', NULL),
	(46, NULL, 'Stefan', 'Bali', 42.34381161, 27.19039596, 'Lat: 42.343812, Lng: 27.190396', 8, 1, 2, 1, '2025-06-25 15:41:48', 2, 0, 38, 1, 1, 4, '2025-06-25 15:41:16', '2025-07-06 13:47:20', NULL),
	(47, NULL, 'Guy ggdhdhdhdhdhdhdhddudjdjdhdhdhdiaja uaidwbsiqxq', 'Guy ggdhdhdhdhdhdhdhddudjdjdhdhdhdiaja uaidwbsiqxqixvqbxuqbxquxbqixbwxiqbxiwbxwixbwixbwxibwixbwixbwixbwxihwxiwxiwbxwjbxwjxbwkxbwkxbwjxbwibxwixbwixvwjxbwjbxwjbx', 42.34310148, 27.18901287, 'Current Location', 1, 2, 2, 0, NULL, NULL, 0, 0, 0, 0, 0, '2025-06-28 11:56:45', '2025-06-28 11:56:45', NULL),
	(48, NULL, 'Guy ggdhdhdhdhdhdhdhddudjdjdhdhdhdiaja uaidwbsiqxq', 'Guy ggdhdhdhdhdhdhdhddudjdjdhdhdhdiaja uaidwbsiqxqixvqbxuqbxquxbqixbwxiqbxiwbxwixbwixbwxibwixbwixbwixbwxihwxiwxiwbxwjbxwjxbwkxbwkxbwjxbwibxwixbwixvwjxbwjbxwjbx', 42.34310148, 27.18901287, 'Current Location', 1, 2, 2, 0, NULL, NULL, 0, 0, 0, 0, 0, '2025-06-28 11:56:45', '2025-06-28 11:56:45', NULL),
	(49, NULL, 'Llbym dumfbdbykdvyevydvtksvyksvtjwtjevtkdvyfkysymv', 'Llbym dumfbdbykdvyevydvtksvyksvtjwtjevtkdvyfkysymvsyksbsdbykebydlbydlbckhxhlxlhlxlhclhlhcjvqktdvkydvykevykrukrurk ur ult url urlurrnulr irl ult url urlunru', 42.34495056, 27.18363819, 'Lat: 42.34495055748974, Lng: 27.18363819343972', 1, 2, 2, 1, '2025-06-28 12:44:16', 2, 0, 4, 0, 0, 0, '2025-06-28 12:43:53', '2025-07-02 11:52:17', NULL),
	(52, NULL, 'Test location', 'Itcitgicigcihiggcgcigcigchchcjsvdgdhdudhdhdivjvohcohcohhchocohcohcohcohcohcohcohvohcohcohco heihcohcoh oh oh oh oh oh chichi you hchchchchchchchchchchc h', 42.34718814, 27.17621524, 'Lat: 42.34718813625099, Lng: 27.176215236569618', 6, 2, 2, 1, '2025-06-28 13:07:51', 2, 0, 3, 0, 0, 0, '2025-06-28 13:07:39', '2025-06-30 11:31:07', NULL),
	(53, NULL, 'Test loc', 'Test dead\n\nExplored on: 28 Jun 2025\nTime of day: usk\nCompanions: 3 (Test )', 42.34197316, 27.19180132, 'Lat: 42.34197316003562, Lng: 27.191801316031643', 1, 2, 2, 0, NULL, NULL, 0, 0, 0, 0, 0, '2025-06-29 09:46:18', '2025-06-29 09:46:18', NULL),
	(54, NULL, 'Test loc', 'Test dead\n\nExplored on: 28 Jun 2025\nTime of day: usk\nCompanions: 3 (Test )', 42.34197316, 27.19180132, 'Lat: 42.34197316003562, Lng: 27.191801316031643', 1, 2, 2, 0, NULL, NULL, 0, 0, 0, 0, 0, '2025-06-29 09:46:18', '2025-06-29 09:46:18', NULL),
	(55, NULL, 'Test loc', 'Test dead\n\nExplored on: 28 Jun 2025\nTime of day: usk\nCompanions: 3 (Test )', 42.34197316, 27.19180132, 'Lat: 42.34197316003562, Lng: 27.191801316031643', 1, 2, 2, 0, NULL, NULL, 0, 0, 0, 0, 0, '2025-06-29 09:46:18', '2025-06-29 09:46:18', NULL),
	(56, NULL, 'Test loc', 'Test dead\n\nExplored on: 28 Jun 2025\nTime of day: usk\nCompanions: 3 (Test )', 42.34197316, 27.19180132, 'Lat: 42.34197316003562, Lng: 27.191801316031643', 1, 2, 2, 0, NULL, NULL, 0, 0, 0, 0, 0, '2025-06-29 09:46:19', '2025-06-29 09:46:19', NULL),
	(57, NULL, 'Murkier folkways', 'Explored on: 29 Jun 2025\nTime of day: ay\nExplored solo', 42.33633445, 27.18692345, 'Lat: 42.33633444808501, Lng: 27.18692345326727', 1, 2, 2, 0, NULL, NULL, 0, 0, 0, 0, 0, '2025-06-29 11:47:44', '2025-06-29 11:47:44', NULL),
	(58, NULL, 'Mitkooooo', 'Explored on: 30 Jun 2025\nTime of day: usk\nExplored solo', 42.33866878, 27.17469027, 'Lat: 42.338668778452586, Lng: 27.174690272925858', 1, 2, 2, 0, NULL, NULL, 0, 0, 0, 0, 0, '2025-06-29 11:51:56', '2025-06-29 11:51:56', NULL),
	(59, NULL, 'Test mitko', 'Explored on: 29 Jun 2025\nTime of day: ay\nExplored solo', 42.33832236, 27.17610871, 'Lat: 42.33832235566797, Lng: 27.176108707261818', 1, 2, 2, 1, '2025-06-29 13:24:01', 2, 0, 5, 0, 0, 0, '2025-06-29 12:07:17', '2025-06-30 11:30:59', NULL),
	(60, NULL, 'Test video', 'Explored on: 30 Jun 2025\nTime of day: ay\nExplored solo', 42.36139296, 27.22001771, 'Lat: 42.36139295944841, Lng: 27.2200177130307', 1, 2, 2, 1, '2025-06-29 15:54:44', 2, 0, 2, 0, 0, 0, '2025-06-29 15:50:39', '2025-06-29 16:03:19', NULL),
	(61, NULL, 'Test video plus picture', 'Explored on: 30 Jun 2025\nTime of day: Dusk\nExplored solo', 42.35824033, 27.17673936, 'Lat: 42.35824033095966, Lng: 27.176739360146655', 1, 2, 2, 1, '2025-06-29 16:05:55', 2, 0, 6, 0, 0, 0, '2025-06-29 16:04:29', '2025-07-02 23:10:20', NULL),
	(62, NULL, 'Test location danger level', 'Explored on: 29 Jun 2025\nTime of day: Night\nExplored solo', 42.35270209, 27.19636443, 'Lat: 42.352702088914185, Lng: 27.19636442890547', 1, 3, 2, 1, '2025-06-29 16:11:49', 2, 0, 2, 0, 0, 0, '2025-06-29 16:11:09', '2025-07-02 23:10:28', NULL),
	(63, NULL, 'Test test', 'Test test\n\nExplored on: 15 Jul 2025\nTime of day: Day\nExplored solo', 37.79415465, -122.39295137, 'Lat: 37.7941546505662, Lng: -122.39295136747454', 1, 1, 2, 1, '2025-06-29 16:31:35', 2, 0, 1, 0, 0, 0, '2025-06-29 16:31:05', '2025-07-01 05:26:59', NULL),
	(64, NULL, 'Ppppp', 'Explored on: 30 Jun 2025\nTime of day: Day\nExplored solo', 42.32973608, 27.20231546, 'Lat: 42.32973607633579, Lng: 27.20231545658629', 1, 2, 1, 0, NULL, NULL, 0, 0, 0, 0, 0, '2025-06-29 21:40:08', '2025-06-29 21:40:08', NULL);

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
) ENGINE=InnoDB AUTO_INCREMENT=21 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table abandoned_explorer.location_images: ~18 rows (approximately)
INSERT INTO `location_images` (`id`, `uuid`, `location_id`, `image_url`, `thumbnail_url`, `image_order`, `uploaded_by`, `file_size`, `image_width`, `image_height`, `alt_text`, `is_primary`, `created_at`) VALUES
	(1, NULL, 2, 'http://localhost:3000/uploads/locations/2/original_1750641915626_0.jpg', 'http://localhost:3000/uploads/locations/2/thumb_1750641915626_0.jpg', 0, 2, 319950, 1920, 1080, NULL, 0, '2025-06-23 01:25:15'),
	(2, NULL, 2, 'http://localhost:3000/uploads/locations/2/original_1750641915814_1.jpg', 'http://localhost:3000/uploads/locations/2/thumb_1750641915814_1.jpg', 1, 2, 504761, 1920, 1080, NULL, 0, '2025-06-23 01:25:15'),
	(3, NULL, 3, 'http://192.168.0.116:3000/uploads/locations/3/original_1750647562318_1.jpg', 'http://192.168.1.102:3000/uploads/locations/3/thumb_1750647562318_1.jpg', 1, 1, 319950, 1920, 1080, NULL, 0, '2025-06-23 02:59:22'),
	(4, NULL, 3, 'http://192.168.0.116:3000/uploads/locations/3/original_1750647562513_0.jpg', 'http://192.168.1.102:3000/uploads/locations/3/thumb_1750647562513_0.jpg', 0, 1, 504761, 1920, 1080, NULL, 0, '2025-06-23 02:59:22'),
	(5, NULL, 4, 'http://192.168.0.116:3000/uploads/locations/4/original_1750725383000_0.jpg', 'http://192.168.1.102:3000/uploads/locations/4/thumb_1750725383000_0.jpg', 0, 1, 386585, 1920, 1080, NULL, 0, '2025-06-24 00:36:23'),
	(6, NULL, 46, 'http://192.168.0.116:3000/uploads/locations/46/original_1750866076700_0.jpg', 'http://192.168.1.102:3000/uploads/locations/46/thumb_1750866076700_0.jpg', 0, 2, 102126, 1920, 1080, NULL, 0, '2025-06-25 15:41:16'),
	(7, NULL, 47, 'http://192.168.0.116:3000/uploads/locations/47/original_1751111807274_0.jpg', 'http://192.168.0.116:3000/uploads/locations/47/thumb_1751111807274_0.jpg', 0, 2, 386585, 1920, 1080, NULL, 0, '2025-06-28 11:56:47'),
	(8, NULL, 48, 'http://192.168.0.116:3000/uploads/locations/48/original_1751111812439_0.jpg', 'http://192.168.0.116:3000/uploads/locations/48/thumb_1751111812439_0.jpg', 0, 2, 386585, 1920, 1080, NULL, 0, '2025-06-28 11:56:52'),
	(9, NULL, 49, 'http://192.168.0.116:3000/uploads/locations/49/original_1751114634027_0.jpg', 'http://192.168.0.116:3000/uploads/locations/49/thumb_1751114634027_0.jpg', 0, 2, 116798, 1920, 1080, NULL, 0, '2025-06-28 12:43:54'),
	(12, NULL, 52, 'http://192.168.0.116:3000/uploads/locations/52/original_1751116060220_0.jpg', 'http://192.168.0.116:3000/uploads/locations/52/thumb_1751116060220_0.jpg', 0, 2, 212023, 1920, 1080, NULL, 0, '2025-06-28 13:07:40'),
	(13, NULL, 54, 'http://192.168.0.116:3000/uploads/locations/54/original_1751190379478_0.jpg', 'http://192.168.0.116:3000/uploads/locations/54/thumb_1751190379478_0.jpg', 0, 2, 212023, 1920, 1080, NULL, 0, '2025-06-29 09:46:19'),
	(14, NULL, 53, 'http://192.168.0.116:3000/uploads/locations/53/original_1751190379478_0.jpg', 'http://192.168.0.116:3000/uploads/locations/53/thumb_1751190379478_0.jpg', 0, 2, 212023, 1920, 1080, NULL, 0, '2025-06-29 09:46:19'),
	(15, NULL, 55, 'http://192.168.0.116:3000/uploads/locations/55/original_1751190379640_0.jpg', 'http://192.168.0.116:3000/uploads/locations/55/thumb_1751190379640_0.jpg', 0, 2, 212023, 1920, 1080, NULL, 0, '2025-06-29 09:46:19'),
	(16, NULL, 56, 'http://192.168.0.116:3000/uploads/locations/56/original_1751190379880_0.jpg', 'http://192.168.0.116:3000/uploads/locations/56/thumb_1751190379880_0.jpg', 0, 2, 212023, 1920, 1080, NULL, 0, '2025-06-29 09:46:19'),
	(17, NULL, 61, 'http://192.168.0.116:3000/uploads/locations/61/original_1751213070160_0.jpg', 'http://192.168.0.116:3000/uploads/locations/61/thumb_1751213070160_0.jpg', 0, 2, 212023, 1920, 1080, NULL, 0, '2025-06-29 16:04:30'),
	(18, NULL, 62, 'http://192.168.0.116:3000/uploads/locations/62/original_1751213470484_0.jpg', 'http://192.168.0.116:3000/uploads/locations/62/thumb_1751213470484_0.jpg', 0, 2, 212023, 1920, 1080, NULL, 0, '2025-06-29 16:11:10'),
	(19, NULL, 63, 'http://192.168.0.116:3000/uploads/locations/63/original_1751214666379_0.jpg', 'http://192.168.0.116:3000/uploads/locations/63/thumb_1751214666379_0.jpg', 0, 2, 504761, 1920, 1080, NULL, 0, '2025-06-29 16:31:06'),
	(20, NULL, 64, 'http://192.168.0.116:3000/uploads/locations/64/original_1751233208687_0.jpg', 'http://192.168.0.116:3000/uploads/locations/64/thumb_1751233208687_0.jpg', 0, 1, 212023, 1920, 1080, NULL, 0, '2025-06-29 21:40:08');

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

-- Dumping data for table abandoned_explorer.location_tags: ~46 rows (approximately)
INSERT INTO `location_tags` (`location_id`, `tag_id`, `created_at`) VALUES
	(46, 1, '2025-06-25 15:41:16'),
	(46, 2, '2025-06-25 15:41:16'),
	(46, 3, '2025-06-25 15:41:16'),
	(46, 4, '2025-06-25 15:41:16'),
	(47, 5, '2025-06-28 11:56:45'),
	(48, 5, '2025-06-28 11:56:45'),
	(49, 5, '2025-06-28 12:43:53'),
	(52, 10, '2025-06-28 13:07:39'),
	(53, 5, '2025-06-29 09:46:18'),
	(53, 11, '2025-06-29 09:46:18'),
	(53, 13, '2025-06-29 09:46:18'),
	(54, 5, '2025-06-29 09:46:18'),
	(54, 11, '2025-06-29 09:46:18'),
	(54, 13, '2025-06-29 09:46:18'),
	(55, 5, '2025-06-29 09:46:18'),
	(55, 11, '2025-06-29 09:46:18'),
	(55, 13, '2025-06-29 09:46:18'),
	(56, 5, '2025-06-29 09:46:19'),
	(56, 11, '2025-06-29 09:46:19'),
	(56, 13, '2025-06-29 09:46:19'),
	(57, 5, '2025-06-29 11:47:44'),
	(57, 23, '2025-06-29 11:47:44'),
	(58, 5, '2025-06-29 11:51:56'),
	(58, 25, '2025-06-29 11:51:56'),
	(59, 5, '2025-06-29 12:07:17'),
	(59, 27, '2025-06-29 12:07:17'),
	(60, 5, '2025-06-29 15:50:39'),
	(60, 29, '2025-06-29 15:50:39'),
	(61, 1, '2025-06-29 16:04:29'),
	(61, 5, '2025-06-29 16:04:29'),
	(61, 31, '2025-06-29 16:04:29'),
	(61, 32, '2025-06-29 16:04:29'),
	(61, 33, '2025-06-29 16:04:29'),
	(61, 35, '2025-06-29 16:04:29'),
	(61, 36, '2025-06-29 16:04:29'),
	(62, 5, '2025-06-29 16:11:10'),
	(62, 32, '2025-06-29 16:11:10'),
	(62, 35, '2025-06-29 16:11:09'),
	(62, 38, '2025-06-29 16:11:09'),
	(63, 1, '2025-06-29 16:31:05'),
	(63, 5, '2025-06-29 16:31:05'),
	(63, 32, '2025-06-29 16:31:05'),
	(63, 43, '2025-06-29 16:31:05'),
	(63, 44, '2025-06-29 16:31:05'),
	(64, 5, '2025-06-29 21:40:08'),
	(64, 47, '2025-06-29 21:40:08');

-- Dumping structure for table abandoned_explorer.location_videos
CREATE TABLE IF NOT EXISTS `location_videos` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `uuid` char(36) DEFAULT NULL,
  `location_id` int(11) NOT NULL,
  `video_url` varchar(500) NOT NULL,
  `thumbnail_url` varchar(500) DEFAULT NULL,
  `video_order` int(11) DEFAULT 0,
  `uploaded_by` int(11) DEFAULT NULL,
  `file_size` bigint(20) DEFAULT NULL,
  `duration_seconds` int(11) DEFAULT NULL,
  `video_width` int(11) DEFAULT NULL,
  `video_height` int(11) DEFAULT NULL,
  `caption` text DEFAULT NULL,
  `is_primary` tinyint(1) DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uuid` (`uuid`),
  KEY `uploaded_by` (`uploaded_by`),
  KEY `idx_uuid` (`uuid`),
  KEY `idx_location_id` (`location_id`),
  KEY `idx_video_order` (`location_id`,`video_order`),
  KEY `idx_primary` (`location_id`,`is_primary`),
  CONSTRAINT `location_videos_ibfk_1` FOREIGN KEY (`location_id`) REFERENCES `locations` (`id`) ON DELETE CASCADE,
  CONSTRAINT `location_videos_ibfk_2` FOREIGN KEY (`uploaded_by`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table abandoned_explorer.location_videos: ~5 rows (approximately)
INSERT INTO `location_videos` (`id`, `uuid`, `location_id`, `video_url`, `thumbnail_url`, `video_order`, `uploaded_by`, `file_size`, `duration_seconds`, `video_width`, `video_height`, `caption`, `is_primary`, `created_at`) VALUES
	(1, NULL, 58, 'http://192.168.0.116:3000/uploads/locations/58/video_1751197924276_0.mp4', 'http://192.168.0.116:3000/uploads/locations/58/video_thumb_1751197924276_0.jpg', 0, 2, 32411224, NULL, NULL, NULL, NULL, 0, '2025-06-29 11:52:04'),
	(2, NULL, 59, 'http://192.168.0.116:3000/uploads/locations/59/video_1751198845183_0.mp4', 'http://192.168.0.116:3000/uploads/locations/59/video_thumb_1751198845183_0.jpg', 0, 2, 18536124, NULL, NULL, NULL, NULL, 0, '2025-06-29 12:07:25'),
	(3, NULL, 60, 'http://192.168.0.116:3000/uploads/locations/60/video_1751212243814_0.mp4', 'http://192.168.0.116:3000/uploads/locations/60/video_thumb_1751212243814_0.jpg', 0, 2, 18536124, NULL, NULL, NULL, NULL, 0, '2025-06-29 15:50:43'),
	(4, NULL, 61, 'http://192.168.0.116:3000/uploads/locations/61/video_1751213071048_0.mp4', 'http://192.168.0.116:3000/uploads/locations/61/video_thumb_1751213071048_0.jpg', 0, 2, 4015826, NULL, NULL, NULL, NULL, 0, '2025-06-29 16:04:31'),
	(5, NULL, 62, 'http://192.168.0.116:3000/uploads/locations/62/video_1751213472551_0.mp4', 'http://192.168.0.116:3000/uploads/locations/62/video_thumb_1751213472551_0.jpg', 0, 2, 8112144, NULL, NULL, NULL, NULL, 0, '2025-06-29 16:11:12');

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
) ENGINE=InnoDB AUTO_INCREMENT=86 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table abandoned_explorer.location_visits: ~85 rows (approximately)
INSERT INTO `location_visits` (`id`, `uuid`, `location_id`, `user_id`, `ip_address`, `user_agent`, `visited_at`) VALUES
	(1, NULL, 7, NULL, '::ffff:192.168.0.116', 'upwork-project/1 CFNetwork/3826.500.131 Darwin/25.0.0', '2025-06-27 09:49:54'),
	(2, NULL, 46, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-27 09:54:38'),
	(3, NULL, 4, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-27 09:54:43'),
	(4, NULL, 46, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-27 09:54:50'),
	(5, NULL, 4, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-27 09:54:53'),
	(6, NULL, 4, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-27 10:16:03'),
	(7, NULL, 46, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-27 10:16:07'),
	(8, NULL, 46, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-27 10:17:10'),
	(9, NULL, 46, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-27 10:17:14'),
	(10, NULL, 46, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-27 10:17:22'),
	(11, NULL, 46, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-27 10:17:28'),
	(12, NULL, 46, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-27 10:26:20'),
	(13, NULL, 46, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-27 10:29:42'),
	(14, NULL, 46, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-27 10:30:11'),
	(15, NULL, 46, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-27 10:34:15'),
	(16, NULL, 46, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-27 10:38:14'),
	(17, NULL, 46, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-27 11:09:07'),
	(18, NULL, 46, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-27 11:10:04'),
	(19, NULL, 46, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-27 11:26:49'),
	(20, NULL, 46, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-27 11:27:35'),
	(21, NULL, 46, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-27 11:36:01'),
	(22, NULL, 46, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-27 11:36:25'),
	(23, NULL, 46, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-27 11:37:09'),
	(24, NULL, 46, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-27 11:40:43'),
	(25, NULL, 4, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-27 11:40:52'),
	(26, NULL, 46, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-27 12:16:07'),
	(27, NULL, 4, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-27 12:16:54'),
	(28, NULL, 46, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-27 12:31:27'),
	(29, NULL, 4, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-27 12:31:40'),
	(30, NULL, 46, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-27 12:46:29'),
	(31, NULL, 4, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-27 12:46:46'),
	(32, NULL, 28, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-27 12:55:39'),
	(33, NULL, 46, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-27 12:57:15'),
	(34, NULL, 4, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-27 12:57:36'),
	(35, NULL, 46, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-28 11:34:12'),
	(36, NULL, 49, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-28 12:45:18'),
	(37, NULL, 52, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-28 13:08:06'),
	(38, NULL, 49, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-29 09:44:41'),
	(39, NULL, 52, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-29 13:24:08'),
	(40, NULL, 59, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-29 13:24:38'),
	(41, NULL, 49, NULL, '::ffff:192.168.0.102', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-29 13:34:15'),
	(42, NULL, 4, NULL, '::ffff:192.168.0.102', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-29 13:36:01'),
	(43, NULL, 59, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-29 15:30:24'),
	(44, NULL, 60, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-29 15:55:25'),
	(45, NULL, 60, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-29 16:03:19'),
	(46, NULL, 59, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-29 16:09:36'),
	(47, NULL, 61, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-29 16:09:49'),
	(48, NULL, 62, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-29 16:12:25'),
	(49, NULL, 3, NULL, '::ffff:192.168.0.116', 'upwork-project/1 CFNetwork/3826.500.131 Darwin/25.0.0', '2025-06-29 16:20:07'),
	(50, NULL, 18, NULL, '::ffff:192.168.0.116', 'upwork-project/1 CFNetwork/3826.500.131 Darwin/25.0.0', '2025-06-29 16:37:00'),
	(51, NULL, 1, NULL, '::ffff:192.168.0.116', 'upwork-project/1 CFNetwork/3826.500.131 Darwin/25.0.0', '2025-06-29 21:02:43'),
	(52, NULL, 59, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-29 21:39:25'),
	(53, NULL, 46, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-29 21:40:34'),
	(54, NULL, 46, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-29 22:16:51'),
	(55, NULL, 46, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-29 22:20:40'),
	(56, NULL, 46, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-29 22:29:02'),
	(57, NULL, 46, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-29 22:39:59'),
	(58, NULL, 46, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-29 22:42:21'),
	(59, NULL, 46, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-29 23:01:14'),
	(60, NULL, 46, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-29 23:09:11'),
	(61, NULL, 46, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-29 23:42:46'),
	(62, NULL, 2, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-29 23:45:54'),
	(63, NULL, 4, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-29 23:45:57'),
	(64, NULL, 59, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-30 11:30:59'),
	(65, NULL, 52, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-30 11:31:07'),
	(66, NULL, 61, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-30 11:31:11'),
	(67, NULL, 4, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-30 11:33:16'),
	(68, NULL, 4, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-06-30 23:03:10'),
	(69, NULL, 63, NULL, '::ffff:192.168.0.116', 'upwork-project/1 CFNetwork/3826.500.131 Darwin/25.0.0', '2025-07-01 05:26:59'),
	(70, NULL, 4, NULL, '::ffff:192.168.0.116', 'upwork-project/1 CFNetwork/3826.500.131 Darwin/25.0.0', '2025-07-02 08:40:53'),
	(71, NULL, 4, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-07-02 08:50:53'),
	(72, NULL, 4, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-07-02 08:59:02'),
	(73, NULL, 4, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-07-02 09:05:39'),
	(74, NULL, 61, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-07-02 09:05:44'),
	(75, NULL, 61, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3852.100.1 Darwin/25.0.0', '2025-07-02 09:15:04'),
	(76, NULL, 49, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3855.100.1 Darwin/25.0.0', '2025-07-02 11:52:17'),
	(77, NULL, 61, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3855.100.1 Darwin/25.0.0', '2025-07-02 11:52:20'),
	(78, NULL, 46, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3855.100.1 Darwin/25.0.0', '2025-07-02 11:59:01'),
	(79, NULL, 1, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3855.100.1 Darwin/25.0.0', '2025-07-02 11:59:23'),
	(80, NULL, 4, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3855.100.1 Darwin/25.0.0', '2025-07-02 11:59:27'),
	(81, NULL, 61, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3855.100.1 Darwin/25.0.0', '2025-07-02 23:10:20'),
	(82, NULL, 62, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3855.100.1 Darwin/25.0.0', '2025-07-02 23:10:28'),
	(83, NULL, 4, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3855.100.1 Darwin/25.0.0', '2025-07-04 12:43:33'),
	(84, NULL, 4, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3855.100.1 Darwin/25.0.0', '2025-07-06 13:47:14'),
	(85, NULL, 46, NULL, '::ffff:192.168.0.108', 'upwork-project/1 CFNetwork/3855.100.1 Darwin/25.0.0', '2025-07-06 13:47:20');

-- Dumping structure for table abandoned_explorer.notifications
CREATE TABLE IF NOT EXISTS `notifications` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `uuid` char(36) DEFAULT NULL,
  `user_id` int(11) NOT NULL,
  `title` varchar(255) NOT NULL,
  `message` text NOT NULL,
  `type` enum('like','comment','bookmark','approval','rejection','submission','reply','visit','system','follow','mention','group_join','group_leave','group_kick','group_ban','group_unban','group_promote','group_demote','group_member_kick','group_member_ban','group_member_role_change') NOT NULL,
  `related_type` enum('location','comment','user','submission','group') DEFAULT NULL,
  `related_id` int(11) DEFAULT NULL,
  `triggered_by` int(11) DEFAULT NULL,
  `data` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`data`)),
  `is_read` tinyint(1) DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uuid` (`uuid`),
  KEY `idx_uuid` (`uuid`),
  KEY `idx_user_notifications` (`user_id`,`created_at`),
  KEY `idx_unread` (`user_id`,`is_read`),
  KEY `idx_type` (`type`),
  KEY `idx_triggered_by` (`triggered_by`),
  KEY `idx_related` (`related_type`,`related_id`),
  CONSTRAINT `notifications_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `notifications_ibfk_2` FOREIGN KEY (`triggered_by`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB AUTO_INCREMENT=12 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table abandoned_explorer.notifications: ~10 rows (approximately)
INSERT INTO `notifications` (`id`, `uuid`, `user_id`, `title`, `message`, `type`, `related_type`, `related_id`, `triggered_by`, `data`, `is_read`, `created_at`) VALUES
	(1, NULL, 1, 'New Comment', 'admin commented on your location', 'comment', 'location', 4, NULL, NULL, 1, '2025-06-27 11:41:05'),
	(2, NULL, 1, 'New Comment', 'admin commented on your location', 'comment', 'location', 4, NULL, NULL, 1, '2025-06-27 12:31:52'),
	(3, NULL, 1, 'New Comment', 'admin commented on your location', 'comment', 'location', 4, NULL, NULL, 1, '2025-06-27 12:57:45'),
	(4, NULL, 1, 'New Comment', 'admin commented on your location', 'comment', 'location', 4, NULL, NULL, 1, '2025-06-27 12:59:51'),
	(5, NULL, 1, 'Location Submitted', 'Your location "Ppppp" has been submitted for review', 'submission', 'location', 64, NULL, '{"locationTitle":"Ppppp","status":"pending_approval"}', 1, '2025-06-29 21:40:08'),
	(6, NULL, 2, 'New Comment', 'test commented on your location "Stefan"', 'comment', 'location', 46, 1, '{"locationTitle":"Stefan","commenterUsername":"test","commentText":"Test"}', 1, '2025-06-29 21:40:42'),
	(7, NULL, 2, 'New Reply', 'test replied to your comment', 'reply', 'comment', 1, 1, '{"locationTitle":"Stefan","commenterUsername":"test","replyText":"Test"}', 1, '2025-06-29 21:40:42'),
	(9, NULL, 1, 'Member Joined', 'admin joined Test Group', 'group_join', 'group', 1, 2, '{"groupName":"Test Group","newMemberUsername":"admin"}', 1, '2025-07-02 10:06:12'),
	(10, NULL, 2, 'Role Changed', 'Your role in Test has been changed from member to admin by test', 'group_promote', 'group', 7, 1, '{"groupName":"Test","adminUsername":"test","oldRole":"member","newRole":"admin"}', 0, '2025-07-02 10:11:28'),
	(11, NULL, 2, 'Role Changed', 'Your role in Test has been changed from admin to member by test', 'group_demote', 'group', 7, 1, '{"groupName":"Test","adminUsername":"test","oldRole":"admin","newRole":"member"}', 0, '2025-07-02 10:11:51');

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
) ENGINE=InnoDB AUTO_INCREMENT=49 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table abandoned_explorer.tags: ~22 rows (approximately)
INSERT INTO `tags` (`id`, `name`, `usage_count`, `created_at`) VALUES
	(1, 'creepy', 0, '2025-06-25 15:41:16'),
	(2, 'zavedenie', 0, '2025-06-25 15:41:16'),
	(3, 'stefan', 0, '2025-06-25 15:41:16'),
	(4, 'nali', 0, '2025-06-25 15:41:16'),
	(5, 'hospital', 0, '2025-06-28 11:56:45'),
	(9, 'mall', 0, '2025-06-28 13:01:29'),
	(10, 'church', 0, '2025-06-28 13:07:39'),
	(11, 'reepy', 0, '2025-06-29 09:46:18'),
	(13, 'ecay', 0, '2025-06-29 09:46:18'),
	(23, 'uburban', 0, '2025-06-29 11:47:44'),
	(25, 'ature', 0, '2025-06-29 11:51:56'),
	(27, 'quatters', 0, '2025-06-29 12:07:17'),
	(29, 'bandoned', 0, '2025-06-29 15:50:39'),
	(31, 'decay', 0, '2025-06-29 16:04:29'),
	(32, 'abandoned', 0, '2025-06-29 16:04:29'),
	(33, 'industrial', 0, '2025-06-29 16:04:29'),
	(35, 'historical', 0, '2025-06-29 16:04:29'),
	(36, 'dangerous', 0, '2025-06-29 16:04:29'),
	(38, 'rural', 0, '2025-06-29 16:11:09'),
	(43, 'nature', 0, '2025-06-29 16:31:05'),
	(44, 'suburban', 0, '2025-06-29 16:31:05'),
	(47, 'squatters', 0, '2025-06-29 21:40:08');

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
  `region` varchar(50) DEFAULT 'Unknown',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `last_login` timestamp NULL DEFAULT NULL,
  `is_active` tinyint(1) DEFAULT 1,
  `email_verified` tinyint(1) DEFAULT 0,
  `phone_number` varchar(20) DEFAULT NULL,
  `bio` text DEFAULT NULL,
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
  KEY `idx_active_status` (`is_active`,`last_login`),
  KEY `idx_region` (`region`)
) ENGINE=InnoDB AUTO_INCREMENT=351 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table abandoned_explorer.users: ~142 rows (approximately)
INSERT INTO `users` (`id`, `uuid`, `username`, `email`, `password_hash`, `age`, `is_premium`, `profile_image_url`, `region`, `created_at`, `updated_at`, `last_login`, `is_active`, `email_verified`, `phone_number`, `bio`) VALUES
	(1, NULL, 'test', 'test@test.com', '$2a$12$v5CguxvZGnoz3/rd18WWWu1QvgUkfgjczZk7ah8FxbZJZgs1XmOwG', 18, 0, NULL, 'EU', '2025-06-22 23:49:51', '2025-07-06 18:10:43', '2025-07-06 18:10:43', 1, 0, NULL, NULL),
	(2, NULL, 'admin', 'admin@admin.com', '$2a$12$v5gBvVxl6dlJkqmtLaxXSO6KdZGuSbn9iwATEh2js7caXpbphKNx.', 18, 0, NULL, 'US', '2025-06-23 01:10:05', '2025-07-06 17:31:57', '2025-07-06 17:31:57', 1, 0, NULL, NULL),
	(18, NULL, 'alex_nyc', 'alex@example.com', '$2b$10$hash1', NULL, 1, 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 12:22:22', 1, 0, NULL, NULL),
	(19, NULL, 'maria_london', 'maria@example.com', '$2b$10$hash2', NULL, 0, 'https://images.unsplash.com/photo-1494790108755-2616b612b786?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:20:22', '2025-06-25 12:20:22', 1, 0, NULL, NULL),
	(20, NULL, 'tom_paris', 'tom@example.com', '$2b$10$hash3', NULL, 1, 'https://images.unsplash.com/photo-1599566150163-29194dcaad36?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:18:22', '2025-06-25 12:18:22', 1, 0, NULL, NULL),
	(21, NULL, 'sarah_tokyo', 'sarah@example.com', '$2b$10$hash4', NULL, 0, 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:15:22', '2025-06-25 12:15:22', 1, 0, NULL, NULL),
	(22, NULL, 'david_sydney', 'david@example.com', '$2b$10$hash5', NULL, 1, 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:10:22', '2025-06-25 12:10:22', 1, 0, NULL, NULL),
	(23, NULL, 'emma_berlin', 'emma@example.com', '$2b$10$hash6', NULL, 0, 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:05:22', '2025-06-25 12:05:22', 1, 0, NULL, NULL),
	(24, NULL, 'james_toronto', 'james@example.com', '$2b$10$hash7', NULL, 1, 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:00:22', '2025-06-25 12:00:22', 1, 0, NULL, NULL),
	(25, NULL, 'lisa_amsterdam', 'lisa@example.com', '$2b$10$hash8', NULL, 0, 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 11:55:22', '2025-06-25 11:55:22', 1, 0, NULL, NULL),
	(26, NULL, 'mike_chicago', 'mike@example.com', '$2b$10$hash9', NULL, 1, 'https://images.unsplash.com/photo-1519244703995-f4e0f30006d5?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 11:50:22', '2025-06-25 11:50:22', 1, 0, NULL, NULL),
	(27, NULL, 'anna_madrid', 'anna@example.com', '$2b$10$hash10', NULL, 0, 'https://images.unsplash.com/photo-1502764613149-7f1d229e230f?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 11:45:22', '2025-06-25 11:45:22', 1, 0, NULL, NULL),
	(28, NULL, 'john_vancouver', 'john@example.com', '$2b$10$hash11', NULL, 0, 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 11:40:22', '2025-06-25 11:40:22', 1, 0, NULL, NULL),
	(29, NULL, 'sophie_rome', 'sophie@example.com', '$2b$10$hash12', NULL, 1, 'https://images.unsplash.com/photo-1487412720507-e7ab37603c6f?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 11:35:22', '2025-06-25 11:35:22', 1, 0, NULL, NULL),
	(30, NULL, 'carlos_barcelona', 'carlos@example.com', '$2b$10$hash13', NULL, 0, 'https://images.unsplash.com/photo-1560250097-0b93528c311a?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 11:30:22', '2025-06-25 11:30:22', 1, 0, NULL, NULL),
	(31, NULL, 'nina_vienna', 'nina@example.com', '$2b$10$hash14', NULL, 1, 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 11:25:22', '2025-06-25 11:25:22', 1, 0, NULL, NULL),
	(32, NULL, 'peter_moscow', 'peter@example.com', '$2b$10$hash15', NULL, 0, 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 11:20:22', '2025-06-25 11:20:22', 1, 0, NULL, NULL),
	(33, NULL, 'chloe_zurich', 'chloe@example.com', '$2b$10$hash16', NULL, 1, 'https://images.unsplash.com/photo-1508214751196-bcfd4ca60f91?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 11:15:22', '2025-06-25 11:15:22', 1, 0, NULL, NULL),
	(34, NULL, 'lucas_melbourne', 'lucas@example.com', '$2b$10$hash17', NULL, 0, 'https://images.unsplash.com/photo-1552058544-f2b08422138a?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 11:10:22', '2025-06-25 11:10:22', 1, 0, NULL, NULL),
	(35, NULL, 'grace_oslo', 'grace@example.com', '$2b$10$hash18', NULL, 1, 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 11:05:22', '2025-06-25 11:05:22', 1, 0, NULL, NULL),
	(36, NULL, 'ryan_dublin', 'ryan@example.com', '$2b$10$hash19', NULL, 0, 'https://images.unsplash.com/photo-1547425260-76bcadfb4f2c?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 11:00:22', '2025-06-25 11:00:22', 1, 0, NULL, NULL),
	(37, NULL, 'zoe_stockholm', 'zoe@example.com', '$2b$10$hash20', NULL, 1, 'https://images.unsplash.com/photo-1489424731084-a5d8b219a5bb?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 10:55:22', '2025-06-25 10:55:22', 1, 0, NULL, NULL),
	(38, NULL, 'ben_brussels', 'ben@example.com', '$2b$10$hash21', NULL, 0, 'https://images.unsplash.com/photo-1557862921-37829c790f19?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 10:50:22', '2025-06-25 10:50:22', 1, 0, NULL, NULL),
	(39, NULL, 'mia_copenhagen', 'mia@example.com', '$2b$10$hash22', NULL, 1, 'https://images.unsplash.com/photo-1531123897727-8f129e1688ce?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 10:45:22', '2025-06-25 10:45:22', 1, 0, NULL, NULL),
	(40, NULL, 'noah_helsinki', 'noah@example.com', '$2b$10$hash23', NULL, 0, 'https://images.unsplash.com/photo-1503443207922-dff7d543fd0e?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 10:40:22', '2025-06-25 10:40:22', 1, 0, NULL, NULL),
	(41, NULL, 'eva_budapest', 'eva@example.com', '$2b$10$hash24', NULL, 1, 'https://images.unsplash.com/photo-1616766098956-c81f12114571?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 11:07:22', 1, 0, NULL, NULL),
	(42, NULL, 'leo_prague', 'leo@example.com', '$2b$10$hash25', NULL, 0, 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:32:22', 1, 0, NULL, NULL),
	(43, NULL, 'isla_warsaw', 'isla@example.com', '$2b$10$hash26', NULL, 1, 'https://images.unsplash.com/photo-1531123897727-8f129e1688ce?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:31:22', 1, 0, NULL, NULL),
	(44, NULL, 'finn_munich', 'finn@example.com', '$2b$10$hash27', NULL, 0, 'https://images.unsplash.com/photo-1503443207922-dff7d543fd0e?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:21:22', 1, 0, NULL, NULL),
	(45, NULL, 'ruby_milan', 'ruby@example.com', '$2b$10$hash28', NULL, 1, 'https://images.unsplash.com/photo-1616766098956-c81f12114571?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:46:22', 1, 0, NULL, NULL),
	(46, NULL, 'oscar_lisbon', 'oscar@example.com', '$2b$10$hash29', NULL, 0, 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:16:22', 1, 0, NULL, NULL),
	(47, NULL, 'ivy_athens', 'ivy@example.com', '$2b$10$hash30', NULL, 1, 'https://images.unsplash.com/photo-1508186225823-0963cf9ab0de?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:56:22', 1, 0, NULL, NULL),
	(48, NULL, 'jake_la', 'jake@example.com', '$2b$10$hash31', NULL, 0, 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 11:52:22', 1, 0, NULL, NULL),
	(49, NULL, 'lily_miami', 'lily@example.com', '$2b$10$hash32', NULL, 1, 'https://images.unsplash.com/photo-1525134479668-1bee5c7c6845?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 11:42:22', 1, 0, NULL, NULL),
	(50, NULL, 'ethan_denver', 'ethan@example.com', '$2b$10$hash33', NULL, 0, 'https://images.unsplash.com/photo-1542909168-82c3e7fdca5c?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 11:32:22', 1, 0, NULL, NULL),
	(51, NULL, 'ava_seattle', 'ava@example.com', '$2b$10$hash34', NULL, 1, 'https://images.unsplash.com/photo-1494790108755-2616b612b786?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 11:47:22', 1, 0, NULL, NULL),
	(52, NULL, 'owen_houston', 'owen@example.com', '$2b$10$hash35', NULL, 0, 'https://images.unsplash.com/photo-1507591064344-4c6ce005b128?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 11:02:22', 1, 0, NULL, NULL),
	(53, NULL, 'maya_phoenix', 'maya@example.com', '$2b$10$hash36', NULL, 1, 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 11:57:22', 1, 0, NULL, NULL),
	(54, NULL, 'liam_boston', 'liam@example.com', '$2b$10$hash37', NULL, 0, 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 11:27:22', 1, 0, NULL, NULL),
	(55, NULL, 'nora_atlanta', 'nora@example.com', '$2b$10$hash38', NULL, 1, 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 11:37:22', 1, 0, NULL, NULL),
	(56, NULL, 'theo_portland', 'theo@example.com', '$2b$10$hash39', NULL, 0, 'https://images.unsplash.com/photo-1599566150163-29194dcaad36?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:51:22', 1, 0, NULL, NULL),
	(57, NULL, 'zara_vegas', 'zara@example.com', '$2b$10$hash40', NULL, 1, 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:41:22', 1, 0, NULL, NULL),
	(58, NULL, 'kenji_osaka', 'kenji@example.com', '$2b$10$hash41', NULL, 0, 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 12:02:22', 1, 0, NULL, NULL),
	(59, NULL, 'yuki_seoul', 'yuki@example.com', '$2b$10$hash42', NULL, 1, 'https://images.unsplash.com/photo-1502764613149-7f1d229e230f?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 11:52:22', 1, 0, NULL, NULL),
	(60, NULL, 'chen_beijing', 'chen@example.com', '$2b$10$hash43', NULL, 0, 'https://images.unsplash.com/photo-1519244703995-f4e0f30006d5?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 11:42:22', 1, 0, NULL, NULL),
	(61, NULL, 'priya_mumbai', 'priya@example.com', '$2b$10$hash44', NULL, 1, 'https://images.unsplash.com/photo-1487412720507-e7ab37603c6f?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 11:32:22', 1, 0, NULL, NULL),
	(62, NULL, 'raj_bangalore', 'raj@example.com', '$2b$10$hash45', NULL, 0, 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 11:22:22', 1, 0, NULL, NULL),
	(63, NULL, 'ming_shanghai', 'ming@example.com', '$2b$10$hash46', NULL, 1, 'https://images.unsplash.com/photo-1560250097-0b93528c311a?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 11:21:22', 1, 0, NULL, NULL),
	(64, NULL, 'siti_jakarta', 'siti@example.com', '$2b$10$hash47', NULL, 0, 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 11:11:22', 1, 0, NULL, NULL),
	(65, NULL, 'kumar_delhi', 'kumar@example.com', '$2b$10$hash48', NULL, 1, 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 11:01:22', 1, 0, NULL, NULL),
	(66, NULL, 'lin_taipei', 'lin@example.com', '$2b$10$hash49', NULL, 0, 'https://images.unsplash.com/photo-1508214751196-bcfd4ca60f91?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 11:31:22', 1, 0, NULL, NULL),
	(67, NULL, 'aaron_singapore', 'aaron@example.com', '$2b$10$hash50', NULL, 1, 'https://images.unsplash.com/photo-1552058544-f2b08422138a?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:46:22', 1, 0, NULL, NULL),
	(68, NULL, 'amara_cairo', 'amara@example.com', '$2b$10$hash51', NULL, 0, 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:36:22', 1, 0, NULL, NULL),
	(69, NULL, 'omar_dubai', 'omar@example.com', '$2b$10$hash52', NULL, 1, 'https://images.unsplash.com/photo-1547425260-76bcadfb4f2c?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:26:22', 1, 0, NULL, NULL),
	(70, NULL, 'fatima_riyadh', 'fatima@example.com', '$2b$10$hash53', NULL, 0, 'https://images.unsplash.com/photo-1489424731084-a5d8b219a5bb?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:16:22', 1, 0, NULL, NULL),
	(71, NULL, 'hassan_istanbul', 'hassan@example.com', '$2b$10$hash54', NULL, 1, 'https://images.unsplash.com/photo-1557862921-37829c790f19?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:31:22', 1, 0, NULL, NULL),
	(72, NULL, 'kemi_lagos', 'kemi@example.com', '$2b$10$hash55', NULL, 0, 'https://images.unsplash.com/photo-1531123897727-8f129e1688ce?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:21:22', 1, 0, NULL, NULL),
	(73, NULL, 'thandiwe_johannesburg', 'thandiwe@example.com', '$2b$10$hash56', NULL, 1, 'https://images.unsplash.com/photo-1503443207922-dff7d543fd0e?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:41:22', 1, 0, NULL, NULL),
	(74, NULL, 'youssef_casablanca', 'youssef@example.com', '$2b$10$hash57', NULL, 0, 'https://images.unsplash.com/photo-1616766098956-c81f12114571?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:51:22', 1, 0, NULL, NULL),
	(75, NULL, 'aisha_nairobi', 'aisha@example.com', '$2b$10$hash58', NULL, 1, 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:11:22', 1, 0, NULL, NULL),
	(76, NULL, 'tariq_tehran', 'tariq@example.com', '$2b$10$hash59', NULL, 0, 'https://images.unsplash.com/photo-1508186225823-0963cf9ab0de?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:01:22', 1, 0, NULL, NULL),
	(77, NULL, 'zara_doha', 'zara2@example.com', '$2b$10$hash60', NULL, 1, 'https://images.unsplash.com/photo-1504593811423-6dd665756598?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 11:01:22', 1, 0, NULL, NULL),
	(78, NULL, 'diego_mexico_city', 'diego@example.com', '$2b$10$hash61', NULL, 0, 'https://images.unsplash.com/photo-1521119989659-a83eee488004?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 11:42:22', 1, 0, NULL, NULL),
	(79, NULL, 'sofia_buenos_aires', 'sofia@example.com', '$2b$10$hash62', NULL, 1, 'https://images.unsplash.com/photo-1558203728-00f45181dd84?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 11:32:22', 1, 0, NULL, NULL),
	(80, NULL, 'ricardo_sao_paulo', 'ricardo@example.com', '$2b$10$hash63', NULL, 0, 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 11:22:22', 1, 0, NULL, NULL),
	(81, NULL, 'valeria_lima', 'valeria@example.com', '$2b$10$hash64', NULL, 1, 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:46:22', 1, 0, NULL, NULL),
	(82, NULL, 'carlos_bogota', 'carlos2@example.com', '$2b$10$hash65', NULL, 0, 'https://images.unsplash.com/photo-1525134479668-1bee5c7c6845?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:36:22', 1, 0, NULL, NULL),
	(83, NULL, 'lucia_santiago', 'lucia@example.com', '$2b$10$hash66', NULL, 1, 'https://images.unsplash.com/photo-1542909168-82c3e7fdca5c?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:26:22', 1, 0, NULL, NULL),
	(84, NULL, 'pablo_caracas', 'pablo@example.com', '$2b$10$hash67', NULL, 0, 'https://images.unsplash.com/photo-1494790108755-2616b612b786?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:16:22', 1, 0, NULL, NULL),
	(85, NULL, 'isabella_quito', 'isabella@example.com', '$2b$10$hash68', NULL, 1, 'https://images.unsplash.com/photo-1507591064344-4c6ce005b128?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:31:22', 1, 0, NULL, NULL),
	(86, NULL, 'mateo_montevideo', 'mateo@example.com', '$2b$10$hash69', NULL, 0, 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:21:22', 1, 0, NULL, NULL),
	(87, NULL, 'camila_la_paz', 'camila@example.com', '$2b$10$hash70', NULL, 1, 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:41:22', 1, 0, NULL, NULL),
	(88, NULL, 'brandon_dallas', 'brandon@example.com', '$2b$10$hash71', NULL, 0, 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 11:11:22', 1, 0, NULL, NULL),
	(89, NULL, 'taylor_detroit', 'taylor@example.com', '$2b$10$hash72', NULL, 1, 'https://images.unsplash.com/photo-1599566150163-29194dcaad36?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 11:01:22', 1, 0, NULL, NULL),
	(90, NULL, 'jordan_philadelphia', 'jordan@example.com', '$2b$10$hash73', NULL, 0, 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:51:22', 1, 0, NULL, NULL),
	(91, NULL, 'riley_nashville', 'riley@example.com', '$2b$10$hash74', NULL, 1, 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:41:22', 1, 0, NULL, NULL),
	(92, NULL, 'casey_sacramento', 'casey@example.com', '$2b$10$hash75', NULL, 0, 'https://images.unsplash.com/photo-1502764613149-7f1d229e230f?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:31:22', 1, 0, NULL, NULL),
	(93, NULL, 'jamie_salt_lake', 'jamie@example.com', '$2b$10$hash76', NULL, 1, 'https://images.unsplash.com/photo-1519244703995-f4e0f30006d5?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:21:22', 1, 0, NULL, NULL),
	(94, NULL, 'alex_minneapolis', 'alex2@example.com', '$2b$10$hash77', NULL, 0, 'https://images.unsplash.com/photo-1487412720507-e7ab37603c6f?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:11:22', 1, 0, NULL, NULL),
	(95, NULL, 'drew_kansas_city', 'drew@example.com', '$2b$10$hash78', NULL, 1, 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 11:21:22', 1, 0, NULL, NULL),
	(96, NULL, 'sage_richmond', 'sage@example.com', '$2b$10$hash79', NULL, 0, 'https://images.unsplash.com/photo-1560250097-0b93528c311a?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:01:22', 1, 0, NULL, NULL),
	(97, NULL, 'river_charlotte', 'river@example.com', '$2b$10$hash80', NULL, 1, 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 11:31:22', 1, 0, NULL, NULL),
	(98, NULL, 'jackson_auckland', 'jackson@example.com', '$2b$10$hash81', NULL, 0, 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 11:22:22', 1, 0, NULL, NULL),
	(99, NULL, 'harper_wellington', 'harper@example.com', '$2b$10$hash82', NULL, 1, 'https://images.unsplash.com/photo-1508214751196-bcfd4ca60f91?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 11:12:22', 1, 0, NULL, NULL),
	(100, NULL, 'mason_brisbane', 'mason@example.com', '$2b$10$hash83', NULL, 0, 'https://images.unsplash.com/photo-1552058544-f2b08422138a?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:36:22', 1, 0, NULL, NULL),
	(101, NULL, 'ella_perth', 'ella@example.com', '$2b$10$hash84', NULL, 1, 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:26:22', 1, 0, NULL, NULL),
	(102, NULL, 'logan_adelaide', 'logan@example.com', '$2b$10$hash85', NULL, 0, 'https://images.unsplash.com/photo-1547425260-76bcadfb4f2c?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:16:22', 1, 0, NULL, NULL),
	(103, NULL, 'felix_florence', 'felix@example.com', '$2b$10$hash86', NULL, 1, 'https://images.unsplash.com/photo-1489424731084-a5d8b219a5bb?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 11:11:22', 1, 0, NULL, NULL),
	(104, NULL, 'luna_venice', 'luna@example.com', '$2b$10$hash87', NULL, 0, 'https://images.unsplash.com/photo-1557862921-37829c790f19?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 11:01:22', 1, 0, NULL, NULL),
	(105, NULL, 'hugo_lyon', 'hugo@example.com', '$2b$10$hash88', NULL, 1, 'https://images.unsplash.com/photo-1531123897727-8f129e1688ce?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:51:22', 1, 0, NULL, NULL),
	(106, NULL, 'clara_marseille', 'clara@example.com', '$2b$10$hash89', NULL, 0, 'https://images.unsplash.com/photo-1503443207922-dff7d543fd0e?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:41:22', 1, 0, NULL, NULL),
	(107, NULL, 'axel_gothenburg', 'axel@example.com', '$2b$10$hash90', NULL, 1, 'https://images.unsplash.com/photo-1616766098956-c81f12114571?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:31:22', 1, 0, NULL, NULL),
	(108, NULL, 'natalie_edinburgh', 'natalie@example.com', '$2b$10$hash91', 25, 0, 'https://images.unsplash.com/photo-1506629905607-19e1469a4ec7?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:21:22', 1, 0, NULL, NULL),
	(109, NULL, 'sebastian_leeds', 'sebastian@example.com', '$2b$10$hash92', 31, 1, 'https://images.unsplash.com/photo-1522075469751-3847faf9d35a?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:11:22', 1, 0, NULL, NULL),
	(110, NULL, 'aurora_reykjavik', 'aurora@example.com', '$2b$10$hash93', 28, 0, 'https://images.unsplash.com/photo-1513956589380-bad6acb9b9d4?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:45:22', 1, 0, NULL, NULL),
	(111, NULL, 'dante_rome', 'dante@example.com', '$2b$10$hash94', 33, 1, 'https://images.unsplash.com/photo-1507591064344-4c6ce005b128?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:35:22', 1, 0, NULL, NULL),
	(112, NULL, 'valentina_naples', 'valentina@example.com', '$2b$10$hash95', 26, 0, 'https://images.unsplash.com/photo-1488426862026-3ee34a7d66df?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:25:22', 1, 0, NULL, NULL),
	(113, NULL, 'viktor_kiev', 'viktor@example.com', '$2b$10$hash96', 29, 1, 'https://images.unsplash.com/photo-1527980965255-d3b416303d12?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:15:22', 1, 0, NULL, NULL),
	(114, NULL, 'anastasia_minsk', 'anastasia@example.com', '$2b$10$hash97', 24, 0, 'https://images.unsplash.com/photo-1544345240-3f7ed06b5c95?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:55:22', 1, 0, NULL, NULL),
	(115, NULL, 'lars_bergen', 'lars@example.com', '$2b$10$hash98', 32, 1, 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:05:22', 1, 0, NULL, NULL),
	(116, NULL, 'ingrid_malmo', 'ingrid@example.com', '$2b$10$hash99', 27, 0, 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 09:55:22', 1, 0, NULL, NULL),
	(117, NULL, 'mikhail_riga', 'mikhail@example.com', '$2b$10$hash100', 30, 1, 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 09:45:22', 1, 0, NULL, NULL),
	(118, NULL, 'elena_tallinn', 'elena@example.com', '$2b$10$hash101', 26, 0, 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 09:35:22', 1, 0, NULL, NULL),
	(119, NULL, 'magnus_trondheim', 'magnus@example.com', '$2b$10$hash102', 34, 1, 'https://images.unsplash.com/photo-1519244703995-f4e0f30006d5?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 09:25:22', 1, 0, NULL, NULL),
	(120, NULL, 'astrid_stavanger', 'astrid@example.com', '$2b$10$hash103', 23, 0, 'https://images.unsplash.com/photo-1502764613149-7f1d229e230f?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 09:15:22', 1, 0, NULL, NULL),
	(121, NULL, 'erik_aalborg', 'erik@example.com', '$2b$10$hash104', 28, 1, 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 09:05:22', 1, 0, NULL, NULL),
	(122, NULL, 'freya_aarhus', 'freya@example.com', '$2b$10$hash105', 29, 0, 'https://images.unsplash.com/photo-1487412720507-e7ab37603c6f?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 08:55:22', 1, 0, NULL, NULL),
	(123, NULL, 'niko_tampere', 'niko@example.com', '$2b$10$hash106', 31, 1, 'https://images.unsplash.com/photo-1560250097-0b93528c311a?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 08:45:22', 1, 0, NULL, NULL),
	(124, NULL, 'aino_turku', 'aino@example.com', '$2b$10$hash107', 25, 0, 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 08:35:22', 1, 0, NULL, NULL),
	(125, NULL, 'gustav_linkoping', 'gustav@example.com', '$2b$10$hash108', 33, 1, 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 08:25:22', 1, 0, NULL, NULL),
	(126, NULL, 'saga_uppsala', 'saga@example.com', '$2b$10$hash109', 27, 0, 'https://images.unsplash.com/photo-1599566150163-29194dcaad36?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 08:15:22', 1, 0, NULL, NULL),
	(127, NULL, 'anton_vilnius', 'anton@example.com', '$2b$10$hash110', 30, 1, 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 08:05:22', 1, 0, NULL, NULL),
	(128, NULL, 'ruta_kaunas', 'ruta@example.com', '$2b$10$hash111', 26, 0, 'https://images.unsplash.com/photo-1494790108755-2616b612b786?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 07:55:22', 1, 0, NULL, NULL),
	(129, NULL, 'matteo_bologna', 'matteo@example.com', '$2b$10$hash112', 28, 1, 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 07:45:22', 1, 0, NULL, NULL),
	(130, NULL, 'giulia_turin', 'giulia@example.com', '$2b$10$hash113', 24, 0, 'https://images.unsplash.com/photo-1508214751196-bcfd4ca60f91?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 07:35:22', 1, 0, NULL, NULL),
	(131, NULL, 'alessandro_genoa', 'alessandro@example.com', '$2b$10$hash114', 32, 1, 'https://images.unsplash.com/photo-1552058544-f2b08422138a?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 11:25:22', 1, 0, NULL, NULL),
	(132, NULL, 'francesca_palermo', 'francesca@example.com', '$2b$10$hash115', 29, 0, 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 11:15:22', 1, 0, NULL, NULL),
	(133, NULL, 'hans_salzburg', 'hans@example.com', '$2b$10$hash116', 35, 1, 'https://images.unsplash.com/photo-1547425260-76bcadfb4f2c?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 11:05:22', 1, 0, NULL, NULL),
	(134, NULL, 'liesel_graz', 'liesel@example.com', '$2b$10$hash117', 27, 0, 'https://images.unsplash.com/photo-1489424731084-a5d8b219a5bb?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:55:22', 1, 0, NULL, NULL),
	(135, NULL, 'wolfgang_innsbruck', 'wolfgang@example.com', '$2b$10$hash118', 31, 1, 'https://images.unsplash.com/photo-1557862921-37829c790f19?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:45:22', 1, 0, NULL, NULL),
	(136, NULL, 'brigitte_linz', 'brigitte@example.com', '$2b$10$hash119', 28, 0, 'https://images.unsplash.com/photo-1531123897727-8f129e1688ce?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:35:22', 1, 0, NULL, NULL),
	(137, NULL, 'jean_lyon', 'jean@example.com', '$2b$10$hash120', 33, 1, 'https://images.unsplash.com/photo-1503443207922-dff7d543fd0e?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:25:22', 1, 0, NULL, NULL),
	(138, NULL, 'marie_toulouse', 'marie@example.com', '$2b$10$hash121', 26, 0, 'https://images.unsplash.com/photo-1616766098956-c81f12114571?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:15:22', 1, 0, NULL, NULL),
	(139, NULL, 'pierre_bordeaux', 'pierre@example.com', '$2b$10$hash122', 30, 1, 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 10:05:22', 1, 0, NULL, NULL),
	(140, NULL, 'camille_nantes', 'camille@example.com', '$2b$10$hash123', 25, 0, 'https://images.unsplash.com/photo-1508186225823-0963cf9ab0de?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 09:55:22', 1, 0, NULL, NULL),
	(141, NULL, 'henri_strasbourg', 'henri@example.com', '$2b$10$hash124', 34, 1, 'https://images.unsplash.com/photo-1504593811423-6dd665756598?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 09:45:22', 1, 0, NULL, NULL),
	(142, NULL, 'claire_nice', 'claire@example.com', '$2b$10$hash125', 27, 0, 'https://images.unsplash.com/photo-1521119989659-a83eee488004?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 09:35:22', 1, 0, NULL, NULL),
	(143, NULL, 'diego_valencia', 'diego2@example.com', '$2b$10$hash126', 29, 1, 'https://images.unsplash.com/photo-1558203728-00f45181dd84?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 09:25:22', 1, 0, NULL, NULL),
	(144, NULL, 'carmen_seville', 'carmen@example.com', '$2b$10$hash127', 31, 0, 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 09:15:22', 1, 0, NULL, NULL),
	(145, NULL, 'javier_bilbao', 'javier@example.com', '$2b$10$hash128', 28, 1, 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 09:05:22', 1, 0, NULL, NULL),
	(146, NULL, 'lucia_zaragoza', 'lucia2@example.com', '$2b$10$hash129', 26, 0, 'https://images.unsplash.com/photo-1525134479668-1bee5c7c6845?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 08:55:22', 1, 0, NULL, NULL),
	(147, NULL, 'pablo_murcia', 'pablo2@example.com', '$2b$10$hash130', 32, 1, 'https://images.unsplash.com/photo-1542909168-82c3e7fdca5c?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 08:45:22', 1, 0, NULL, NULL),
	(148, NULL, 'ines_cordoba', 'ines@example.com', '$2b$10$hash131', 24, 0, 'https://images.unsplash.com/photo-1494790108755-2616b612b786?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 08:35:22', 1, 0, NULL, NULL),
	(149, NULL, 'hugo_braga', 'hugo2@example.com', '$2b$10$hash132', 30, 1, 'https://images.unsplash.com/photo-1507591064344-4c6ce005b128?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 08:25:22', 1, 0, NULL, NULL),
	(150, NULL, 'ana_braga', 'ana@example.com', '$2b$10$hash133', 27, 0, 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 08:15:22', 1, 0, NULL, NULL),
	(151, NULL, 'carlos_coimbra', 'carlos3@example.com', '$2b$10$hash134', 29, 1, 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 08:05:22', 1, 0, NULL, NULL),
	(152, NULL, 'beatriz_funchal', 'beatriz@example.com', '$2b$10$hash135', 25, 0, 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 07:55:22', 1, 0, NULL, NULL),
	(153, NULL, 'rodrigo_aveiro', 'rodrigo@example.com', '$2b$10$hash136', 33, 1, 'https://images.unsplash.com/photo-1599566150163-29194dcaad36?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 07:45:22', 1, 0, NULL, NULL),
	(154, NULL, 'marta_faro', 'marta@example.com', '$2b$10$hash137', 28, 0, 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 07:35:22', 1, 0, NULL, NULL),
	(155, NULL, 'ivan_split', 'ivan@example.com', '$2b$10$hash138', 31, 1, 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 07:25:22', 1, 0, NULL, NULL),
	(156, NULL, 'ana_zagreb', 'ana2@example.com', '$2b$10$hash139', 26, 0, 'https://images.unsplash.com/photo-1502764613149-7f1d229e230f?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 07:15:22', 1, 0, NULL, NULL),
	(157, NULL, 'marko_rijeka', 'marko@example.com', '$2b$10$hash140', 34, 1, 'https://images.unsplash.com/photo-1519244703995-f4e0f30006d5?w=100', 'Unknown', '2025-06-24 11:56:40', '2025-06-25 12:22:22', '2025-06-25 07:05:22', 1, 0, NULL, NULL);

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
) ENGINE=InnoDB AUTO_INCREMENT=719 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Dumping data for table abandoned_explorer.user_locations: ~91 rows (approximately)
INSERT INTO `user_locations` (`id`, `user_id`, `latitude`, `longitude`, `accuracy_meters`, `location_name`, `updated_at`, `created_at`) VALUES
	(1, 2, 37.78583400, -122.40641700, 1000, NULL, '2025-07-06 17:31:57', '2025-06-24 10:16:44'),
	(2, 1, 42.34310106, 27.18914527, 1000, NULL, '2025-07-06 18:10:43', '2025-06-24 10:16:44'),
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
	(74, 99, -41.28650000, 174.77620000, 40, 'Wellington, New Zealand', '2025-06-24 11:12:22', '2025-06-24 12:22:22'),
	(75, 108, 55.95330000, -3.18800000, 50, 'Edinburgh, UK', '2025-06-25 11:21:22', '2025-06-25 12:22:22'),
	(76, 109, 53.79648000, -1.54785000, 45, 'Leeds, UK', '2025-06-25 11:11:22', '2025-06-25 12:22:22'),
	(77, 110, 64.13548000, -21.89541000, 60, 'Reykjavik, Iceland', '2025-06-25 10:45:22', '2025-06-25 12:22:22'),
	(78, 111, 41.90280000, 12.49640000, 40, 'Rome, Italy', '2025-06-25 10:35:22', '2025-06-25 12:22:22'),
	(79, 112, 40.85180000, 14.26810000, 55, 'Naples, Italy', '2025-06-25 10:25:22', '2025-06-25 12:22:22'),
	(80, 113, 50.45010000, 30.52340000, 65, 'Kiev, Ukraine', '2025-06-25 10:15:22', '2025-06-25 12:22:22'),
	(81, 114, 53.90540000, 27.56170000, 70, 'Minsk, Belarus', '2025-06-25 10:55:22', '2025-06-25 12:22:22'),
	(82, 115, 60.39130000, 5.32200000, 45, 'Bergen, Norway', '2025-06-25 10:05:22', '2025-06-25 12:22:22'),
	(83, 116, 55.60587000, 13.00073000, 35, 'Malmö, Sweden', '2025-06-25 09:55:22', '2025-06-25 12:22:22'),
	(84, 117, 56.94670000, 24.10590000, 50, 'Riga, Latvia', '2025-06-25 09:45:22', '2025-06-25 12:22:22'),
	(85, 118, 59.43700000, 24.75380000, 40, 'Tallinn, Estonia', '2025-06-25 09:35:22', '2025-06-25 12:22:22'),
	(86, 119, 63.43049000, 10.39506000, 60, 'Trondheim, Norway', '2025-06-25 09:25:22', '2025-06-25 12:22:22'),
	(87, 120, 58.96970000, 5.73310000, 45, 'Stavanger, Norway', '2025-06-25 09:15:22', '2025-06-25 12:22:22'),
	(88, 121, 57.04870000, 9.92180000, 55, 'Aalborg, Denmark', '2025-06-25 09:05:22', '2025-06-25 12:22:22'),
	(89, 122, 56.15670000, 10.21080000, 40, 'Aarhus, Denmark', '2025-06-25 08:55:22', '2025-06-25 12:22:22'),
	(90, 123, 61.49911000, 23.78712000, 50, 'Tampere, Finland', '2025-06-25 08:45:22', '2025-06-25 12:22:22'),
	(91, 124, 60.45120000, 22.26680000, 45, 'Turku, Finland', '2025-06-25 08:35:22', '2025-06-25 12:22:22'),
	(92, 125, 58.41080000, 15.62060000, 35, 'Linköping, Sweden', '2025-06-25 08:25:22', '2025-06-25 12:22:22'),
	(93, 126, 59.85880000, 17.63890000, 40, 'Uppsala, Sweden', '2025-06-25 08:15:22', '2025-06-25 12:22:22'),
	(94, 127, 54.68740000, 25.27980000, 55, 'Vilnius, Lithuania', '2025-06-25 08:05:22', '2025-06-25 12:22:22'),
	(95, 128, 54.89640000, 23.88400000, 50, 'Kaunas, Lithuania', '2025-06-25 07:55:22', '2025-06-25 12:22:22'),
	(96, 129, 44.49370000, 11.34270000, 45, 'Bologna, Italy', '2025-06-25 07:45:22', '2025-06-25 12:22:22'),
	(97, 130, 45.07050000, 7.68680000, 40, 'Turin, Italy', '2025-06-25 07:35:22', '2025-06-25 12:22:22'),
	(98, 131, 44.41150000, 8.93200000, 60, 'Genoa, Italy', '2025-06-25 07:25:22', '2025-06-25 12:22:22'),
	(99, 132, 38.11570000, 13.36160000, 55, 'Palermo, Italy', '2025-06-25 07:15:22', '2025-06-25 12:22:22'),
	(100, 133, 47.80950000, 13.05500000, 50, 'Salzburg, Austria', '2025-06-25 07:05:22', '2025-06-25 12:22:22'),
	(101, 134, 47.07090000, 15.43890000, 45, 'Graz, Austria', '2025-06-25 06:55:22', '2025-06-25 12:22:22'),
	(102, 135, 47.26720000, 11.39240000, 40, 'Innsbruck, Austria', '2025-06-25 06:45:22', '2025-06-25 12:22:22'),
	(103, 136, 48.30690000, 14.28580000, 35, 'Linz, Austria', '2025-06-25 06:35:22', '2025-06-25 12:22:22'),
	(104, 137, 45.76400000, 4.83550000, 50, 'Lyon, France', '2025-06-25 06:25:22', '2025-06-25 12:22:22'),
	(105, 138, 43.60430000, 1.44420000, 45, 'Toulouse, France', '2025-06-25 06:15:22', '2025-06-25 12:22:22'),
	(106, 139, 44.83780000, -0.57920000, 40, 'Bordeaux, France', '2025-06-25 06:05:22', '2025-06-25 12:22:22'),
	(107, 140, 47.21800000, -1.55370000, 55, 'Nantes, France', '2025-06-25 05:55:22', '2025-06-25 12:22:22'),
	(108, 141, 48.58390000, 7.74740000, 50, 'Strasbourg, France', '2025-06-25 05:45:22', '2025-06-25 12:22:22'),
	(109, 142, 43.69820000, 7.26810000, 45, 'Nice, France', '2025-06-25 05:35:22', '2025-06-25 12:22:22'),
	(110, 143, 39.46200000, -0.37540000, 40, 'Valencia, Spain', '2025-06-25 05:25:22', '2025-06-25 12:22:22'),
	(111, 144, 37.38830000, -5.97320000, 60, 'Seville, Spain', '2025-06-25 05:15:22', '2025-06-25 12:22:22'),
	(112, 145, 43.26300000, -2.93500000, 55, 'Bilbao, Spain', '2025-06-25 05:05:22', '2025-06-25 12:22:22'),
	(113, 146, 41.65610000, -0.87340000, 50, 'Zaragoza, Spain', '2025-06-25 04:55:22', '2025-06-25 12:22:22'),
	(114, 147, 37.98330000, -1.12830000, 45, 'Murcia, Spain', '2025-06-25 04:45:22', '2025-06-25 12:22:22'),
	(115, 148, 37.88610000, -4.77950000, 40, 'Córdoba, Spain', '2025-06-25 04:35:22', '2025-06-25 12:22:22'),
	(116, 149, 41.15270000, -8.61040000, 50, 'Porto, Portugal', '2025-06-25 04:25:22', '2025-06-25 12:22:22'),
	(117, 150, 41.54510000, -8.42610000, 45, 'Braga, Portugal', '2025-06-25 04:15:22', '2025-06-25 12:22:22'),
	(118, 151, 40.20560000, -8.41910000, 40, 'Coimbra, Portugal', '2025-06-25 04:05:22', '2025-06-25 12:22:22'),
	(119, 152, 32.66680000, -16.90900000, 60, 'Funchal, Portugal', '2025-06-25 03:55:22', '2025-06-25 12:22:22'),
	(120, 153, 40.64070000, -8.65340000, 55, 'Aveiro, Portugal', '2025-06-25 03:45:22', '2025-06-25 12:22:22'),
	(121, 154, 37.01650000, -7.93120000, 50, 'Faro, Portugal', '2025-06-25 03:35:22', '2025-06-25 12:22:22'),
	(122, 155, 43.50890000, 16.43990000, 45, 'Split, Croatia', '2025-06-25 03:25:22', '2025-06-25 12:22:22'),
	(123, 156, 45.81500000, 15.98190000, 40, 'Zagreb, Croatia', '2025-06-25 03:15:22', '2025-06-25 12:22:22'),
	(124, 157, 45.32730000, 14.50830000, 50, 'Rijeka, Croatia', '2025-06-25 03:05:22', '2025-06-25 12:22:22');

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
