const express = require('express');
const mysql = require('mysql2/promise');
const { authenticateToken } = require('../middleware/auth');
const { v4: uuidv4 } = require('uuid');
const crypto = require('crypto');

const router = express.Router();

// Database connection
const { pool } = require('../config/database');

// Helper function to generate unique invite code
function generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    let result = '';
    for (let i = 0; i < 8; i++) {
        result += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return result;
}

// Create a new group
router.post('/', authenticateToken, async (req, res) => {
    try {
        const { name, description, is_private = true, member_limit = 4, avatar_color = '#7289da', emoji = '🏚️' } = req.body;
        const userId = req.user.userId;

        if (!name || name.trim().length === 0) {
            return res.status(400).json({ error: 'Group name is required' });
        }

        if (name.length > 100) {
            return res.status(400).json({ error: 'Group name must be 100 characters or less' });
        }

        const connection = await pool.getConnection();

        try {
            await connection.beginTransaction();

            // Generate unique invite code
            let inviteCode;
            let isUnique = false;
            let attempts = 0;
            const maxAttempts = 10;

            while (!isUnique && attempts < maxAttempts) {
                inviteCode = generateInviteCode();
                const [existing] = await connection.execute(
                    'SELECT id FROM groups WHERE invite_code = ?',
                    [inviteCode]
                );
                if (existing.length === 0) {
                    isUnique = true;
                } else {
                    attempts++;
                }
            }

            if (!isUnique) {
                await connection.rollback();
                return res.status(500).json({ error: 'Failed to generate unique invite code' });
            }

            // Create the group
            const groupUuid = uuidv4();
            const [groupResult] = await connection.execute(`
                INSERT INTO groups (uuid, name, description, invite_code, created_by, is_private, member_limit, avatar_color, emoji)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            `, [groupUuid, name.trim(), description || null, inviteCode, userId, is_private, member_limit, avatar_color, emoji]);

            const groupId = groupResult.insertId;

            // Add creator as owner
            const memberUuid = uuidv4();
            await connection.execute(`
                INSERT INTO group_members (uuid, group_id, user_id, role, joined_at, last_active_at)
                VALUES (?, ?, ?, 'owner', NOW(), NOW())
            `, [memberUuid, groupId, userId]);

            await connection.commit();

            // Fetch the created group with member count
            const [groupData] = await connection.execute(`
                SELECT g.*, u.username as creator_username,
                       COUNT(gm.id) as member_count
                FROM groups g
                JOIN users u ON g.created_by = u.id
                LEFT JOIN group_members gm ON g.id = gm.group_id
                WHERE g.id = ?
                GROUP BY g.id
            `, [groupId]);

            res.status(201).json({
                success: true,
                group: groupData[0]
            });

        } catch (error) {
            await connection.rollback();
            throw error;
        } finally {
            connection.release();
        }

    } catch (error) {
        console.error('Error creating group:', error);
        res.status(500).json({ error: 'Failed to create group' });
    }
});

// Get user's groups
router.get('/my-groups', authenticateToken, async (req, res) => {
    try {
        const userId = req.user.userId;
        const connection = await pool.getConnection();

        const [groups] = await connection.execute(`
            SELECT g.*, u.username as creator_username,
                   COUNT(gm.id) as member_count,
                   um.role as my_role,
                   um.joined_at as my_joined_at,
                   MAX(gm.last_active_at) as last_activity,
                   COUNT(CASE WHEN gm.last_active_at > DATE_SUB(NOW(), INTERVAL 15 MINUTE) THEN 1 END) as active_members
            FROM group_members um
            JOIN groups g ON um.group_id = g.id
            JOIN users u ON g.created_by = u.id
            LEFT JOIN group_members gm ON g.id = gm.group_id
            WHERE um.user_id = ?
            GROUP BY g.id, um.role, um.joined_at
            ORDER BY um.joined_at DESC
        `, [userId]);

        connection.release();

        res.json({
            success: true,
            groups: groups
        });

    } catch (error) {
        console.error('Error fetching user groups:', error);
        res.status(500).json({ error: 'Failed to fetch groups' });
    }
});

// Join group by invite code
router.post('/join', authenticateToken, async (req, res) => {
    try {
        const { invite_code } = req.body;
        const userId = req.user.userId;

        if (!invite_code || invite_code.trim().length === 0) {
            return res.status(400).json({ error: 'Invite code is required' });
        }

        const connection = await pool.getConnection();

        try {
            await connection.beginTransaction();

            // Find the group
            const [groups] = await connection.execute(`
                SELECT g.*, COUNT(gm.id) as current_members
                FROM groups g
                LEFT JOIN group_members gm ON g.id = gm.group_id
                WHERE g.invite_code = ?
                GROUP BY g.id
            `, [invite_code.trim().toUpperCase()]);

            if (groups.length === 0) {
                await connection.rollback();
                return res.status(404).json({ error: 'Invalid invite code' });
            }

            const group = groups[0];

            // Check if user is already a member
            const [existing] = await connection.execute(
                'SELECT id FROM group_members WHERE group_id = ? AND user_id = ?',
                [group.id, userId]
            );

            if (existing.length > 0) {
                await connection.rollback();
                return res.status(400).json({ error: 'You are already a member of this group' });
            }

            // Check member limit
            if (group.current_members >= group.member_limit) {
                await connection.rollback();
                return res.status(400).json({ error: 'Group is full' });
            }

            // Add user to group
            const memberUuid = uuidv4();
            await connection.execute(`
                INSERT INTO group_members (uuid, group_id, user_id, role, joined_at, last_active_at)
                VALUES (?, ?, ?, 'member', NOW(), NOW())
            `, [memberUuid, group.id, userId]);

            // Add system message
            const messageUuid = uuidv4();
            await connection.execute(`
                INSERT INTO group_messages (uuid, group_id, user_id, message_type, content)
                VALUES (?, ?, ?, 'system', 'joined the group')
            `, [messageUuid, group.id, userId]);

            await connection.commit();

            // Fetch updated group data
            const [groupData] = await connection.execute(`
                SELECT g.*, u.username as creator_username,
                       COUNT(gm.id) as member_count
                FROM groups g
                JOIN users u ON g.created_by = u.id
                LEFT JOIN group_members gm ON g.id = gm.group_id
                WHERE g.id = ?
                GROUP BY g.id
            `, [group.id]);

            res.json({
                success: true,
                group: groupData[0]
            });

        } catch (error) {
            await connection.rollback();
            throw error;
        } finally {
            connection.release();
        }

    } catch (error) {
        console.error('Error joining group:', error);
        res.status(500).json({ error: 'Failed to join group' });
    }
});

// Get group details
router.get('/:groupId', authenticateToken, async (req, res) => {
    try {
        const { groupId } = req.params;
        const userId = req.user.userId;
        const connection = await pool.getConnection();

        // Check if user is a member
        const [membership] = await connection.execute(
            'SELECT role FROM group_members WHERE group_id = ? AND user_id = ?',
            [groupId, userId]
        );

        if (membership.length === 0) {
            connection.release();
            return res.status(403).json({ error: 'Access denied' });
        }

        // Get group details
        const [groups] = await connection.execute(`
            SELECT g.*, u.username as creator_username,
                   COUNT(gm.id) as member_count
            FROM groups g
            JOIN users u ON g.created_by = u.id
            LEFT JOIN group_members gm ON g.id = gm.group_id
            WHERE g.id = ?
            GROUP BY g.id
        `, [groupId]);

        if (groups.length === 0) {
            connection.release();
            return res.status(404).json({ error: 'Group not found' });
        }

        connection.release();

        res.json({
            success: true,
            group: groups[0],
            my_role: membership[0].role
        });

    } catch (error) {
        console.error('Error fetching group details:', error);
        res.status(500).json({ error: 'Failed to fetch group details' });
    }
});

// Get group members
router.get('/:groupId/members', authenticateToken, async (req, res) => {
    try {
        const { groupId } = req.params;
        const userId = req.user.userId;
        const connection = await pool.getConnection();

        // Check if user is a member
        const [membership] = await connection.execute(
            'SELECT role FROM group_members WHERE group_id = ? AND user_id = ?',
            [groupId, userId]
        );

        if (membership.length === 0) {
            connection.release();
            return res.status(403).json({ error: 'Access denied' });
        }

        // Get members with online status
        const [members] = await connection.execute(`
            SELECT gm.role, gm.nickname, gm.joined_at, gm.last_active_at,
                   u.id, u.username, u.profile_image_url,
                   CASE 
                       WHEN gm.last_active_at > DATE_SUB(NOW(), INTERVAL 15 MINUTE) THEN 1 
                       ELSE 0 
                   END as is_online,
                   TIMESTAMPDIFF(MINUTE, gm.last_active_at, NOW()) as minutes_since_active
            FROM group_members gm
            JOIN users u ON gm.user_id = u.id
            WHERE gm.group_id = ?
            ORDER BY 
                CASE gm.role 
                    WHEN 'owner' THEN 1 
                    WHEN 'admin' THEN 2 
                    ELSE 3 
                END,
                gm.joined_at ASC
        `, [groupId]);

        connection.release();

        res.json({
            success: true,
            members: members
        });

    } catch (error) {
        console.error('Error fetching group members:', error);
        res.status(500).json({ error: 'Failed to fetch group members' });
    }
});

// Get group messages
router.get('/:groupId/messages', authenticateToken, async (req, res) => {
    try {
        const { groupId } = req.params;
        const userId = req.user.userId;
        const { limit = 50, before } = req.query;
        const connection = await pool.getConnection();

        // Check if user is a member
        const [membership] = await connection.execute(
            'SELECT role FROM group_members WHERE group_id = ? AND user_id = ?',
            [groupId, userId]
        );

        if (membership.length === 0) {
            connection.release();
            return res.status(403).json({ error: 'Access denied' });
        }

        // Build query
        let query = `
            SELECT gm.*, u.username, u.profile_image_url,
                   l.title as location_title, l.latitude, l.longitude
            FROM group_messages gm
            JOIN users u ON gm.user_id = u.id
            LEFT JOIN locations l ON gm.location_id = l.id
            WHERE gm.group_id = ? AND gm.deleted_at IS NULL
        `;
        const params = [groupId];

        if (before) {
            query += ' AND gm.created_at < ?';
            params.push(before);
        }

        query += ' ORDER BY gm.created_at DESC LIMIT ?';
        params.push(parseInt(limit));

        const [messages] = await connection.execute(query, params);

        connection.release();

        res.json({
            success: true,
            messages: messages.reverse() // Return in ascending order
        });

    } catch (error) {
        console.error('Error fetching group messages:', error);
        res.status(500).json({ error: 'Failed to fetch group messages' });
    }
});

// Send message to group
router.post('/:groupId/messages', authenticateToken, async (req, res) => {
    try {
        const { groupId } = req.params;
        const userId = req.user.userId;
        const { message_type = 'text', content, location_id, reply_to_id } = req.body;
        const connection = await pool.getConnection();

        // Check if user is a member
        const [membership] = await connection.execute(
            'SELECT role FROM group_members WHERE group_id = ? AND user_id = ?',
            [groupId, userId]
        );

        if (membership.length === 0) {
            connection.release();
            return res.status(403).json({ error: 'Access denied' });
        }

        if (!content || content.trim().length === 0) {
            connection.release();
            return res.status(400).json({ error: 'Message content is required' });
        }

        // Create message
        const messageUuid = uuidv4();
        const [result] = await connection.execute(`
            INSERT INTO group_messages (uuid, group_id, user_id, message_type, content, location_id, reply_to_id)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        `, [messageUuid, groupId, userId, message_type, content.trim(), location_id || null, reply_to_id || null]);

        // Update user's last active time
        await connection.execute(
            'UPDATE group_members SET last_active_at = NOW() WHERE group_id = ? AND user_id = ?',
            [groupId, userId]
        );

        // Fetch the created message with user details
        const [messages] = await connection.execute(`
            SELECT gm.*, u.username, u.profile_image_url,
                   l.title as location_title, l.latitude, l.longitude
            FROM group_messages gm
            JOIN users u ON gm.user_id = u.id
            LEFT JOIN locations l ON gm.location_id = l.id
            WHERE gm.id = ?
        `, [result.insertId]);

        connection.release();

        res.status(201).json({
            success: true,
            message: messages[0]
        });

    } catch (error) {
        console.error('Error sending group message:', error);
        res.status(500).json({ error: 'Failed to send message' });
    }
});

// Leave group
router.delete('/:groupId/leave', authenticateToken, async (req, res) => {
    try {
        const { groupId } = req.params;
        const userId = req.user.userId;
        const connection = await pool.getConnection();

        try {
            await connection.beginTransaction();

            // Check if user is a member
            const [membership] = await connection.execute(
                'SELECT role FROM group_members WHERE group_id = ? AND user_id = ?',
                [groupId, userId]
            );

            if (membership.length === 0) {
                await connection.rollback();
                return res.status(403).json({ error: 'You are not a member of this group' });
            }

            // Check if user is the owner
            if (membership[0].role === 'owner') {
                // Count other members
                const [memberCount] = await connection.execute(
                    'SELECT COUNT(*) as count FROM group_members WHERE group_id = ? AND user_id != ?',
                    [groupId, userId]
                );

                if (memberCount[0].count > 0) {
                    await connection.rollback();
                    return res.status(400).json({ error: 'Group owner cannot leave while there are other members' });
                }
            }

            // Remove user from group
            await connection.execute(
                'DELETE FROM group_members WHERE group_id = ? AND user_id = ?',
                [groupId, userId]
            );

            // Add system message
            const messageUuid = uuidv4();
            await connection.execute(`
                INSERT INTO group_messages (uuid, group_id, user_id, message_type, content)
                VALUES (?, ?, ?, 'system', 'left the group')
            `, [messageUuid, groupId, userId]);

            await connection.commit();

            res.json({
                success: true,
                message: 'Successfully left the group'
            });

        } catch (error) {
            await connection.rollback();
            throw error;
        } finally {
            connection.release();
        }

    } catch (error) {
        console.error('Error leaving group:', error);
        res.status(500).json({ error: 'Failed to leave group' });
    }
});

// Share location to group
router.post('/:groupId/locations', authenticateToken, async (req, res) => {
    try {
        const { groupId } = req.params;
        const userId = req.user.userId;
        const { location_id, notes, is_pinned = false } = req.body;
        const connection = await pool.getConnection();

        try {
            await connection.beginTransaction();

            // Check if user is a member
            const [membership] = await connection.execute(
                'SELECT role FROM group_members WHERE group_id = ? AND user_id = ?',
                [groupId, userId]
            );

            if (membership.length === 0) {
                await connection.rollback();
                return res.status(403).json({ error: 'Access denied' });
            }

            // Check if location exists
            const [locations] = await connection.execute(
                'SELECT id, title FROM locations WHERE id = ?',
                [location_id]
            );

            if (locations.length === 0) {
                await connection.rollback();
                return res.status(404).json({ error: 'Location not found' });
            }

            // Check if already shared
            const [existing] = await connection.execute(
                'SELECT id FROM group_locations WHERE group_id = ? AND location_id = ?',
                [groupId, location_id]
            );

            if (existing.length > 0) {
                await connection.rollback();
                return res.status(400).json({ error: 'Location already shared to this group' });
            }

            // Share location
            const shareUuid = uuidv4();
            await connection.execute(`
                INSERT INTO group_locations (uuid, group_id, location_id, shared_by, notes, is_pinned)
                VALUES (?, ?, ?, ?, ?, ?)
            `, [shareUuid, groupId, location_id, userId, notes || null, is_pinned]);

            // Send message about shared location
            const messageUuid = uuidv4();
            await connection.execute(`
                INSERT INTO group_messages (uuid, group_id, user_id, message_type, location_id, content)
                VALUES (?, ?, ?, 'location', ?, ?)
            `, [messageUuid, groupId, userId, location_id, notes || `Shared location: ${locations[0].title}`]);

            await connection.commit();

            res.status(201).json({
                success: true,
                message: 'Location shared successfully'
            });

        } catch (error) {
            await connection.rollback();
            throw error;
        } finally {
            connection.release();
        }

    } catch (error) {
        console.error('Error sharing location:', error);
        res.status(500).json({ error: 'Failed to share location' });
    }
});

// Update member activity (called when user is active in group)
router.post('/:id/activity', authenticateToken, async (req, res) => {
    const groupId = parseInt(req.params.id);
    const userId = req.user.userId;
    
    try {
        const connection = await pool.getConnection();
        
        try {
            // Check if user is a member of the group
            const [memberCheck] = await connection.execute(
                'SELECT id FROM group_members WHERE group_id = ? AND user_id = ?',
                [groupId, userId]
            );
            
            if (memberCheck.length === 0) {
                return res.status(403).json({ error: 'Not a member of this group' });
            }
            
            // Update last_active_at timestamp
            await connection.execute(
                'UPDATE group_members SET last_active_at = NOW() WHERE group_id = ? AND user_id = ?',
                [groupId, userId]
            );
            
            res.json({ success: true, message: 'Activity updated' });
        } finally {
            connection.release();
        }
    } catch (error) {
        console.error('Error updating member activity:', error);
        res.status(500).json({ error: 'Internal server error' });
    }
});

module.exports = router; 