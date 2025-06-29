-- Migration: Add Video Support to Abandoned Explorer
-- Date: January 2025
-- Description: Adds location_videos table to support video uploads

USE `abandoned_explorer`;

-- Create location_videos table
CREATE TABLE IF NOT EXISTS `location_videos` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `uuid` char(36) DEFAULT NULL,
  `location_id` int(11) NOT NULL,
  `video_url` varchar(500) NOT NULL,
  `thumbnail_url` varchar(500) DEFAULT NULL,
  `video_order` int(11) DEFAULT 0,
  `uploaded_by` int(11) DEFAULT NULL,
  `file_size` int(11) DEFAULT NULL,
  `video_width` int(11) DEFAULT NULL,
  `video_height` int(11) DEFAULT NULL,
  `duration_seconds` int(11) DEFAULT NULL,
  `alt_text` varchar(255) DEFAULT NULL,
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS `idx_location_videos_location` ON `location_videos` (`location_id`);
CREATE INDEX IF NOT EXISTS `idx_location_videos_uploaded` ON `location_videos` (`uploaded_by`);
CREATE INDEX IF NOT EXISTS `idx_location_videos_created` ON `location_videos` (`created_at`);

-- Success message
SELECT 'Video support migration completed successfully!' as message; 