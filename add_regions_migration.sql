-- --------------------------------------------------------
-- Migration: Add Regions Support
-- This migration adds region support for groups functionality
-- Run this file manually in your DBMS
-- --------------------------------------------------------

-- Add region column to users table if it doesn't exist
ALTER TABLE `users` 
ADD COLUMN IF NOT EXISTS `region` varchar(50) DEFAULT 'Unknown' AFTER `profile_image_url`;

-- Add indexes for better performance on region-based queries
ALTER TABLE `users` 
ADD INDEX IF NOT EXISTS `idx_region` (`region`);

-- Ensure groups table has the region index (in case it's missing)
ALTER TABLE `groups` 
ADD INDEX IF NOT EXISTS `idx_region` (`region`);

-- Update existing users to have a default region based on their location if possible
-- You can modify these UPDATE statements based on your actual user data
UPDATE `users` SET `region` = 'US' WHERE `region` = 'Unknown' AND `id` IN (1);
UPDATE `users` SET `region` = 'EU' WHERE `region` = 'Unknown' AND `id` IN (2);

-- Optional: Update existing groups to have proper regions
-- Modify these based on your existing group data
UPDATE `groups` SET `region` = 'EU' WHERE `region` = 'Unknown';

-- Add a check constraint to ensure valid regions (optional)
-- ALTER TABLE `users` ADD CONSTRAINT `chk_user_region` CHECK (`region` IN ('US', 'EU', 'ASIA', 'OCEANIA', 'AFRICA', 'SOUTH_AMERICA', 'Unknown'));
-- ALTER TABLE `groups` ADD CONSTRAINT `chk_group_region` CHECK (`region` IN ('US', 'EU', 'ASIA', 'OCEANIA', 'AFRICA', 'SOUTH_AMERICA', 'Unknown'));

-- Verify the changes
SELECT 'Users table structure:' as info;
DESCRIBE `users`;

SELECT 'Groups table structure:' as info;
DESCRIBE `groups`;

SELECT 'Sample users with regions:' as info;
SELECT `id`, `username`, `region` FROM `users` LIMIT 5;

SELECT 'Sample groups with regions:' as info;
SELECT `id`, `name`, `region`, `points` FROM `groups` LIMIT 5; 