const mysql = require('mysql2/promise');
const dbConfig = require('./config/database');

const migrations = [
    `CREATE TABLE IF NOT EXISTS \`groups\` (
        \`id\` int(11) NOT NULL AUTO_INCREMENT,
        \`uuid\` char(36) DEFAULT NULL,
        \`name\` varchar(100) NOT NULL,
        \`description\` text DEFAULT NULL,
        \`invite_code\` varchar(8) NOT NULL,
        \`created_by\` int(11) NOT NULL,
        \`is_private\` tinyint(1) DEFAULT 0,
        \`member_limit\` int(11) DEFAULT 50,
        \`avatar_color\` varchar(7) DEFAULT '#7289da',
        \`emoji\` varchar(10) DEFAULT '🏠',
        \`created_at\` timestamp NOT NULL DEFAULT current_timestamp(),
        \`updated_at\` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
        PRIMARY KEY (\`id\`),
        UNIQUE KEY \`uuid\` (\`uuid\`),
        UNIQUE KEY \`invite_code\` (\`invite_code\`),
        KEY \`idx_created_by\` (\`created_by\`),
        KEY \`idx_invite_code\` (\`invite_code\`),
        CONSTRAINT \`groups_ibfk_1\` FOREIGN KEY (\`created_by\`) REFERENCES \`users\` (\`id\`) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`,

    `CREATE TABLE IF NOT EXISTS \`group_members\` (
        \`id\` int(11) NOT NULL AUTO_INCREMENT,
        \`group_id\` int(11) NOT NULL,
        \`user_id\` int(11) NOT NULL,
        \`role\` enum('owner','admin','member') DEFAULT 'member',
        \`nickname\` varchar(50) DEFAULT NULL,
        \`joined_at\` timestamp NOT NULL DEFAULT current_timestamp(),
        \`last_active_at\` timestamp NULL DEFAULT NULL,
        PRIMARY KEY (\`id\`),
        UNIQUE KEY \`unique_group_user\` (\`group_id\`,\`user_id\`),
        KEY \`idx_group_id\` (\`group_id\`),
        KEY \`idx_user_id\` (\`user_id\`),
        KEY \`idx_role\` (\`role\`),
        CONSTRAINT \`group_members_ibfk_1\` FOREIGN KEY (\`group_id\`) REFERENCES \`groups\` (\`id\`) ON DELETE CASCADE,
        CONSTRAINT \`group_members_ibfk_2\` FOREIGN KEY (\`user_id\`) REFERENCES \`users\` (\`id\`) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`,

    `CREATE TABLE IF NOT EXISTS \`group_messages\` (
        \`id\` int(11) NOT NULL AUTO_INCREMENT,
        \`uuid\` char(36) DEFAULT NULL,
        \`group_id\` int(11) NOT NULL,
        \`user_id\` int(11) NOT NULL,
        \`message_type\` enum('text','location','image','system') DEFAULT 'text',
        \`content\` text DEFAULT NULL,
        \`location_id\` int(11) DEFAULT NULL,
        \`image_url\` varchar(500) DEFAULT NULL,
        \`reply_to_id\` int(11) DEFAULT NULL,
        \`created_at\` timestamp NOT NULL DEFAULT current_timestamp(),
        \`updated_at\` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
        PRIMARY KEY (\`id\`),
        UNIQUE KEY \`uuid\` (\`uuid\`),
        KEY \`idx_group_id\` (\`group_id\`),
        KEY \`idx_user_id\` (\`user_id\`),
        KEY \`idx_created_at\` (\`created_at\`),
        KEY \`idx_location_id\` (\`location_id\`),
        KEY \`idx_reply_to_id\` (\`reply_to_id\`),
        CONSTRAINT \`group_messages_ibfk_1\` FOREIGN KEY (\`group_id\`) REFERENCES \`groups\` (\`id\`) ON DELETE CASCADE,
        CONSTRAINT \`group_messages_ibfk_2\` FOREIGN KEY (\`user_id\`) REFERENCES \`users\` (\`id\`) ON DELETE CASCADE,
        CONSTRAINT \`group_messages_ibfk_3\` FOREIGN KEY (\`location_id\`) REFERENCES \`abandoned_locations\` (\`id\`) ON DELETE SET NULL,
        CONSTRAINT \`group_messages_ibfk_4\` FOREIGN KEY (\`reply_to_id\`) REFERENCES \`group_messages\` (\`id\`) ON DELETE SET NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`,

    `CREATE TABLE IF NOT EXISTS \`group_locations\` (
        \`id\` int(11) NOT NULL AUTO_INCREMENT,
        \`group_id\` int(11) NOT NULL,
        \`location_id\` int(11) NOT NULL,
        \`shared_by\` int(11) NOT NULL,
        \`notes\` text DEFAULT NULL,
        \`is_pinned\` tinyint(1) DEFAULT 0,
        \`shared_at\` timestamp NOT NULL DEFAULT current_timestamp(),
        PRIMARY KEY (\`id\`),
        UNIQUE KEY \`unique_group_location\` (\`group_id\`,\`location_id\`),
        KEY \`idx_group_id\` (\`group_id\`),
        KEY \`idx_location_id\` (\`location_id\`),
        KEY \`idx_shared_by\` (\`shared_by\`),
        KEY \`idx_shared_at\` (\`shared_at\`),
        CONSTRAINT \`group_locations_ibfk_1\` FOREIGN KEY (\`group_id\`) REFERENCES \`groups\` (\`id\`) ON DELETE CASCADE,
        CONSTRAINT \`group_locations_ibfk_2\` FOREIGN KEY (\`location_id\`) REFERENCES \`abandoned_locations\` (\`id\`) ON DELETE CASCADE,
        CONSTRAINT \`group_locations_ibfk_3\` FOREIGN KEY (\`shared_by\`) REFERENCES \`users\` (\`id\`) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`
];

async function runMigration() {
    try {
        const connection = await mysql.createConnection(dbConfig);
        console.log('Connected to database successfully');
        
        for (let i = 0; i < migrations.length; i++) {
            try {
                await connection.execute(migrations[i]);
                console.log(`Migration ${i + 1}/${migrations.length} completed successfully`);
            } catch (err) {
                if (err.message.includes('already exists')) {
                    console.log(`Migration ${i + 1}/${migrations.length} skipped (table already exists)`);
                } else {
                    console.error(`Migration ${i + 1}/${migrations.length} failed:`, err.message);
                    throw err;
                }
            }
        }
        
        await connection.end();
        console.log('All migrations completed successfully!');
        
    } catch (err) {
        console.error('Migration failed:', err.message);
        process.exit(1);
    }
}

runMigration(); 