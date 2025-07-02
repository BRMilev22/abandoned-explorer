const express = require('express');
const mysql = require('mysql2/promise');
const { authenticateToken } = require('../middleware/auth');
const { v4: uuidv4 } = require('uuid');
const crypto = require('crypto');

const router = express.Router();

// Database connection
const { pool } = require('../config/database');

// Helper function to create notifications
async function createNotification(userId, title, message, type, relatedType = null, relatedId = null, triggeredBy = null, data = null) {
  try {
    await pool.execute(
      'INSERT INTO notifications (user_id, title, message, type, related_type, related_id, triggered_by, data) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [userId, title, message, type, relatedType, relatedId, triggeredBy, JSON.stringify(data)]
    );
    console.log(`📩 Created ${type} notification for user ${userId}`);
  } catch (error) {
    console.error('Failed to create notification:', error);
    // Don't throw error - notifications are not critical
  }
}

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
        const { name, description, is_private = true, member_limit = 4, avatar_color = '#7289da', emoji = '🏚️', region = 'Unknown' } = req.body;
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
                INSERT INTO groups (uuid, name, description, invite_code, created_by, is_private, member_limit, avatar_color, emoji, region, points)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            `, [groupUuid, name.trim(), description || null, inviteCode, userId, is_private, member_limit, avatar_color, emoji, region, 0]);

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

            // Check if user is banned from this group
            const [banRecord] = await connection.execute(
                'SELECT ban_reason, created_at FROM group_bans WHERE group_id = ? AND user_id = ? AND unbanned_at IS NULL',
                [group.id, userId]
            );

            if (banRecord.length > 0) {
                await connection.rollback();
                return res.status(403).json({ 
                    error: 'You are banned from this group',
                    message: `You have been banned from this group. Reason: ${banRecord[0].ban_reason || 'No reason provided'}`,
                    ban_reason: banRecord[0].ban_reason,
                    banned_at: banRecord[0].created_at
                });
            }

            // Check region compatibility
            const [userRegion] = await connection.execute(
                'SELECT region FROM users WHERE id = ?',
                [userId]
            );

            if (userRegion.length > 0 && userRegion[0].region !== group.region && group.region !== 'Unknown' && userRegion[0].region !== 'Unknown') {
                await connection.rollback();
                return res.status(403).json({ 
                    error: 'Region mismatch',
                    message: `This group is for ${group.region} region only. You are in the ${userRegion[0].region} region.`
                });
            }

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

            // Get user info for notifications
            const [userInfo] = await connection.execute(
                'SELECT username FROM users WHERE id = ?',
                [userId]
            );

            // Notify group owner and admins about new member
            const [groupOwnerAndAdmins] = await connection.execute(`
                SELECT gm.user_id, u.username, gm.role
                FROM group_members gm
                JOIN users u ON gm.user_id = u.id
                WHERE gm.group_id = ? AND gm.role IN ('owner', 'admin') AND gm.user_id != ?
            `, [group.id, userId]);

            // Create notifications for owner and admins
            for (const admin of groupOwnerAndAdmins) {
                await createNotification(
                    admin.user_id,
                    'New Group Member',
                    `${userInfo[0].username} joined ${group.name}`,
                    'group_join',
                    'group',
                    group.id,
                    userId,
                    { groupName: group.name, newMemberUsername: userInfo[0].username }
                );
            }

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

            // Get user and group info for notifications
            const [userInfo] = await connection.execute('SELECT username FROM users WHERE id = ?', [userId]);
            const [groupInfo] = await connection.execute('SELECT name FROM groups WHERE id = ?', [groupId]);

            // Notify group owner and admins about member leaving (if not owner leaving)
            if (membership[0].role !== 'owner') {
                const [groupOwnerAndAdmins] = await connection.execute(`
                    SELECT gm.user_id, u.username, gm.role
                    FROM group_members gm
                    JOIN users u ON gm.user_id = u.id
                    WHERE gm.group_id = ? AND gm.role IN ('owner', 'admin') AND gm.user_id != ?
                `, [groupId, userId]);

                // Create notifications for owner and admins
                for (const admin of groupOwnerAndAdmins) {
                    await createNotification(
                        admin.user_id,
                        'Member Left Group',
                        `${userInfo[0].username} left ${groupInfo[0].name}`,
                        'group_leave',
                        'group',
                        groupId,
                        userId,
                        { groupName: groupInfo[0].name, memberUsername: userInfo[0].username }
                    );
                }
            }

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

// Update member activity
router.post('/:groupId/activity', authenticateToken, async (req, res) => {
    try {
        const { groupId } = req.params;
        const userId = req.user.userId;
        const connection = await pool.getConnection();

        // Check if user is a member
        const [membership] = await connection.execute(
            'SELECT id FROM group_members WHERE group_id = ? AND user_id = ?',
            [groupId, userId]
        );

        if (membership.length === 0) {
            connection.release();
            return res.status(403).json({ error: 'Access denied' });
        }

        // Update last active time
        await connection.execute(
            'UPDATE group_members SET last_active_at = NOW() WHERE group_id = ? AND user_id = ?',
            [groupId, userId]
        );

        connection.release();

        res.json({ success: true });

    } catch (error) {
        console.error('Error updating member activity:', error);
        res.status(500).json({ error: 'Failed to update activity' });
    }
});

// Like/unlike group message
router.post('/:groupId/messages/:messageId/like', authenticateToken, async (req, res) => {
    try {
        const { groupId, messageId } = req.params;
        const userId = req.user.userId;
        const connection = await pool.getConnection();

        // Check if user is a member
        const [membership] = await connection.execute(
            'SELECT id FROM group_members WHERE group_id = ? AND user_id = ?',
            [groupId, userId]
        );

        if (membership.length === 0) {
            connection.release();
            return res.status(403).json({ error: 'Access denied' });
        }

        // Check if like exists
        const [existingLike] = await connection.execute(
            'SELECT id FROM group_message_likes WHERE message_id = ? AND user_id = ?',
            [messageId, userId]
        );

        let liked = false;
        if (existingLike.length > 0) {
            // Unlike
            await connection.execute(
                'DELETE FROM group_message_likes WHERE message_id = ? AND user_id = ?',
                [messageId, userId]
            );
        } else {
            // Like
            const likeUuid = uuidv4();
            await connection.execute(
                'INSERT INTO group_message_likes (uuid, message_id, user_id) VALUES (?, ?, ?)',
                [likeUuid, messageId, userId]
            );
            liked = true;
        }

        // Get updated like count
        const [likeCount] = await connection.execute(
            'SELECT COUNT(*) as count FROM group_message_likes WHERE message_id = ?',
            [messageId]
        );

        connection.release();

        res.json({
            success: true,
            liked: liked,
            like_count: likeCount[0].count
        });

    } catch (error) {
        console.error('Error toggling message like:', error);
        res.status(500).json({ error: 'Failed to toggle like' });
    }
});

// ADMIN ACTIONS - Kick member from group
router.post('/:groupId/kick', authenticateToken, async (req, res) => {
    try {
        const { groupId } = req.params;
        const { user_id, reason } = req.body;
        const adminId = req.user.userId;
        
        if (!user_id) {
            return res.status(400).json({ error: 'User ID is required' });
        }

        const connection = await pool.getConnection();

        try {
            await connection.beginTransaction();

            // Check if admin has permission (owner or admin)
            const [adminMembership] = await connection.execute(
                'SELECT role FROM group_members WHERE group_id = ? AND user_id = ?',
                [groupId, adminId]
            );

            if (adminMembership.length === 0 || !['owner', 'admin'].includes(adminMembership[0].role)) {
                await connection.rollback();
                return res.status(403).json({ error: 'Access denied. Owner or admin role required' });
            }

            // Check if target user is a member
            const [targetMembership] = await connection.execute(
                'SELECT role, user_id FROM group_members gm JOIN users u ON gm.user_id = u.id WHERE gm.group_id = ? AND gm.user_id = ?',
                [groupId, user_id]
            );

            if (targetMembership.length === 0) {
                await connection.rollback();
                return res.status(404).json({ error: 'User is not a member of this group' });
            }

            // Cannot kick the owner
            if (targetMembership[0].role === 'owner') {
                await connection.rollback();
                return res.status(400).json({ error: 'Cannot kick the group owner' });
            }

            // Admin can only kick members, not other admins (unless admin is owner)
            if (targetMembership[0].role === 'admin' && adminMembership[0].role !== 'owner') {
                await connection.rollback();
                return res.status(403).json({ error: 'Admins can only kick members, not other admins' });
            }

            // Cannot kick yourself
            if (parseInt(user_id) === adminId) {
                await connection.rollback();
                return res.status(400).json({ error: 'You cannot kick yourself' });
            }

            // Remove user from group
            await connection.execute(
                'DELETE FROM group_members WHERE group_id = ? AND user_id = ?',
                [groupId, user_id]
            );

            // Log the action
            const actionUuid = uuidv4();
            await connection.execute(`
                INSERT INTO group_admin_actions (uuid, group_id, admin_id, target_user_id, action_type, reason)
                VALUES (?, ?, ?, ?, 'kick', ?)
            `, [actionUuid, groupId, adminId, user_id, reason || null]);

            // Add system message
            const messageUuid = uuidv4();
            const [targetUser] = await connection.execute('SELECT username FROM users WHERE id = ?', [user_id]);
            await connection.execute(`
                INSERT INTO group_messages (uuid, group_id, user_id, message_type, content)
                VALUES (?, ?, ?, 'system', ?)
            `, [messageUuid, groupId, adminId, `kicked ${targetUser[0].username} from the group`]);

            // Get group info for notifications
            const [groupInfo] = await connection.execute('SELECT name FROM groups WHERE id = ?', [groupId]);
            const [adminInfo] = await connection.execute('SELECT username FROM users WHERE id = ?', [adminId]);

            // Notify the kicked user
            await createNotification(
                user_id,
                'Kicked from Group',
                `You were kicked from ${groupInfo[0].name}` + (reason ? ` Reason: ${reason}` : ''),
                'group_kick',
                'group',
                groupId,
                adminId,
                { 
                    groupName: groupInfo[0].name, 
                    adminUsername: adminInfo[0].username,
                    reason: reason 
                }
            );

            // Notify other group members about the kick
            const [otherMembers] = await connection.execute(`
                SELECT gm.user_id, u.username
                FROM group_members gm
                JOIN users u ON gm.user_id = u.id
                WHERE gm.group_id = ? AND gm.user_id NOT IN (?, ?)
            `, [groupId, adminId, user_id]);

            for (const member of otherMembers) {
                await createNotification(
                    member.user_id,
                    'Member Kicked',
                    `${targetUser[0].username} was kicked from ${groupInfo[0].name} by ${adminInfo[0].username}`,
                    'group_member_kick',
                    'group',
                    groupId,
                    adminId,
                    { 
                        groupName: groupInfo[0].name, 
                        kickedUsername: targetUser[0].username,
                        adminUsername: adminInfo[0].username,
                        reason: reason
                    }
                );
            }

            await connection.commit();

            res.json({
                success: true,
                message: 'User kicked successfully'
            });

        } catch (error) {
            await connection.rollback();
            throw error;
        } finally {
            connection.release();
        }

    } catch (error) {
        console.error('Error kicking member:', error);
        res.status(500).json({ error: 'Failed to kick member' });
    }
});

// ADMIN ACTIONS - Ban member from group
router.post('/:groupId/ban', authenticateToken, async (req, res) => {
    try {
        const { groupId } = req.params;
        const { user_id, reason, is_permanent = true } = req.body;
        const adminId = req.user.userId;
        
        if (!user_id) {
            return res.status(400).json({ error: 'User ID is required' });
        }

        const connection = await pool.getConnection();

        try {
            await connection.beginTransaction();

            // Check if admin has permission (owner or admin)
            const [adminMembership] = await connection.execute(
                'SELECT role FROM group_members WHERE group_id = ? AND user_id = ?',
                [groupId, adminId]
            );

            if (adminMembership.length === 0 || !['owner', 'admin'].includes(adminMembership[0].role)) {
                await connection.rollback();
                return res.status(403).json({ error: 'Access denied. Owner or admin role required' });
            }

            // Check if target user exists
            const [targetUser] = await connection.execute('SELECT username FROM users WHERE id = ?', [user_id]);
            if (targetUser.length === 0) {
                await connection.rollback();
                return res.status(404).json({ error: 'User not found' });
            }

            // Check if user is already banned
            const [existingBan] = await connection.execute(
                'SELECT id FROM group_bans WHERE group_id = ? AND user_id = ? AND unbanned_at IS NULL',
                [groupId, user_id]
            );

            if (existingBan.length > 0) {
                await connection.rollback();
                return res.status(400).json({ error: 'User is already banned' });
            }

            // Check if target user is a member
            const [targetMembership] = await connection.execute(
                'SELECT role FROM group_members WHERE group_id = ? AND user_id = ?',
                [groupId, user_id]
            );

            // Cannot ban the owner
            if (targetMembership.length > 0 && targetMembership[0].role === 'owner') {
                await connection.rollback();
                return res.status(400).json({ error: 'Cannot ban the group owner' });
            }

            // Admin can only ban members, not other admins (unless admin is owner)
            if (targetMembership.length > 0 && targetMembership[0].role === 'admin' && adminMembership[0].role !== 'owner') {
                await connection.rollback();
                return res.status(403).json({ error: 'Admins can only ban members, not other admins' });
            }

            // Cannot ban yourself
            if (parseInt(user_id) === adminId) {
                await connection.rollback();
                return res.status(400).json({ error: 'You cannot ban yourself' });
            }

            // Remove user from group if they are a member
            if (targetMembership.length > 0) {
                await connection.execute(
                    'DELETE FROM group_members WHERE group_id = ? AND user_id = ?',
                    [groupId, user_id]
                );
            }

            // Add ban record
            const banUuid = uuidv4();
            await connection.execute(`
                INSERT INTO group_bans (uuid, group_id, user_id, banned_by, ban_reason, ban_type, is_permanent)
                VALUES (?, ?, ?, ?, ?, 'ban', ?)
            `, [banUuid, groupId, user_id, adminId, reason || null, is_permanent]);

            // Log the action
            const actionUuid = uuidv4();
            await connection.execute(`
                INSERT INTO group_admin_actions (uuid, group_id, admin_id, target_user_id, action_type, reason)
                VALUES (?, ?, ?, ?, 'ban', ?)
            `, [actionUuid, groupId, adminId, user_id, reason || null]);

            // Add system message
            const messageUuid = uuidv4();
            await connection.execute(`
                INSERT INTO group_messages (uuid, group_id, user_id, message_type, content)
                VALUES (?, ?, ?, 'system', ?)
            `, [messageUuid, groupId, adminId, `banned ${targetUser[0].username} from the group`]);

            // Get group info for notifications  
            const [groupInfo] = await connection.execute('SELECT name FROM groups WHERE id = ?', [groupId]);
            const [adminInfo] = await connection.execute('SELECT username FROM users WHERE id = ?', [adminId]);

            // Notify the banned user
            await createNotification(
                user_id,
                'Banned from Group',
                `You were banned from ${groupInfo[0].name}` + (reason ? ` Reason: ${reason}` : ''),
                'group_ban',
                'group',
                groupId,
                adminId,
                { 
                    groupName: groupInfo[0].name, 
                    adminUsername: adminInfo[0].username,
                    reason: reason,
                    isPermanent: is_permanent
                }
            );

            // Notify other group members about the ban
            const [otherMembers] = await connection.execute(`
                SELECT gm.user_id, u.username
                FROM group_members gm
                JOIN users u ON gm.user_id = u.id
                WHERE gm.group_id = ? AND gm.user_id NOT IN (?, ?)
            `, [groupId, adminId, user_id]);

            for (const member of otherMembers) {
                await createNotification(
                    member.user_id,
                    'Member Banned',
                    `${targetUser[0].username} was banned from ${groupInfo[0].name} by ${adminInfo[0].username}`,
                    'group_member_ban',
                    'group',
                    groupId,
                    adminId,
                    { 
                        groupName: groupInfo[0].name, 
                        bannedUsername: targetUser[0].username,
                        adminUsername: adminInfo[0].username,
                        reason: reason,
                        isPermanent: is_permanent
                    }
                );
            }

            await connection.commit();

            res.json({
                success: true,
                message: 'User banned successfully'
            });

        } catch (error) {
            await connection.rollback();
            throw error;
        } finally {
            connection.release();
        }

    } catch (error) {
        console.error('Error banning member:', error);
        res.status(500).json({ error: 'Failed to ban member' });
    }
});

// ADMIN ACTIONS - Unban member
router.post('/:groupId/unban', authenticateToken, async (req, res) => {
    try {
        const { groupId } = req.params;
        const { user_id } = req.body;
        const adminId = req.user.userId;
        
        if (!user_id) {
            return res.status(400).json({ error: 'User ID is required' });
        }

        const connection = await pool.getConnection();

        try {
            await connection.beginTransaction();

            // Check if admin has permission (owner or admin)
            const [adminMembership] = await connection.execute(
                'SELECT role FROM group_members WHERE group_id = ? AND user_id = ?',
                [groupId, adminId]
            );

            if (adminMembership.length === 0 || !['owner', 'admin'].includes(adminMembership[0].role)) {
                await connection.rollback();
                return res.status(403).json({ error: 'Access denied. Owner or admin role required' });
            }

            // Check if user is banned
            const [banRecord] = await connection.execute(
                'SELECT id FROM group_bans WHERE group_id = ? AND user_id = ? AND unbanned_at IS NULL',
                [groupId, user_id]
            );

            if (banRecord.length === 0) {
                await connection.rollback();
                return res.status(404).json({ error: 'User is not banned' });
            }

            // Unban the user
            await connection.execute(
                'UPDATE group_bans SET unbanned_at = NOW(), unbanned_by = ? WHERE group_id = ? AND user_id = ? AND unbanned_at IS NULL',
                [adminId, groupId, user_id]
            );

            // Log the action
            const actionUuid = uuidv4();
            await connection.execute(`
                INSERT INTO group_admin_actions (uuid, group_id, admin_id, target_user_id, action_type)
                VALUES (?, ?, ?, ?, 'unban')
            `, [actionUuid, groupId, adminId, user_id]);

            // Add system message
            const messageUuid = uuidv4();
            const [targetUser] = await connection.execute('SELECT username FROM users WHERE id = ?', [user_id]);
            await connection.execute(`
                INSERT INTO group_messages (uuid, group_id, user_id, message_type, content)
                VALUES (?, ?, ?, 'system', ?)
            `, [messageUuid, groupId, adminId, `unbanned ${targetUser[0].username}`]);

            // Get group info for notifications
            const [groupInfo] = await connection.execute('SELECT name FROM groups WHERE id = ?', [groupId]);
            const [adminInfo] = await connection.execute('SELECT username FROM users WHERE id = ?', [adminId]);

            // Notify the unbanned user
            await createNotification(
                user_id,
                'Unbanned from Group',
                `You have been unbanned from ${groupInfo[0].name} by ${adminInfo[0].username}. You can now rejoin the group.`,
                'group_unban',
                'group',
                groupId,
                adminId,
                { 
                    groupName: groupInfo[0].name, 
                    adminUsername: adminInfo[0].username
                }
            );

            await connection.commit();

            res.json({
                success: true,
                message: 'User unbanned successfully'
            });

        } catch (error) {
            await connection.rollback();
            throw error;
        } finally {
            connection.release();
        }

    } catch (error) {
        console.error('Error unbanning member:', error);
        res.status(500).json({ error: 'Failed to unban member' });
    }
});

// Get banned users
router.get('/:groupId/banned', authenticateToken, async (req, res) => {
    try {
        const { groupId } = req.params;
        const userId = req.user.userId;
        const connection = await pool.getConnection();

        // Check if user has permission (owner or admin)
        const [membership] = await connection.execute(
            'SELECT role FROM group_members WHERE group_id = ? AND user_id = ?',
            [groupId, userId]
        );

        if (membership.length === 0 || !['owner', 'admin'].includes(membership[0].role)) {
            connection.release();
            return res.status(403).json({ error: 'Access denied. Owner or admin role required' });
        }

        // Get banned users
        const [bannedUsers] = await connection.execute(`
            SELECT gb.*, u.username, u.profile_image_url,
                   admin_user.username as banned_by_username,
                   unban_user.username as unbanned_by_username
            FROM group_bans gb
            JOIN users u ON gb.user_id = u.id
            JOIN users admin_user ON gb.banned_by = admin_user.id
            LEFT JOIN users unban_user ON gb.unbanned_by = unban_user.id
            WHERE gb.group_id = ?
            ORDER BY gb.created_at DESC
        `, [groupId]);

        connection.release();

        res.json({
            success: true,
            banned_users: bannedUsers
        });

    } catch (error) {
        console.error('Error fetching banned users:', error);
        res.status(500).json({ error: 'Failed to fetch banned users' });
    }
});

// Delete entire group
router.delete('/:groupId', authenticateToken, async (req, res) => {
    try {
        const { groupId } = req.params;
        const userId = req.user.userId;
        const connection = await pool.getConnection();

        try {
            await connection.beginTransaction();

            // Check if user is the owner
            const [membership] = await connection.execute(
                'SELECT role FROM group_members WHERE group_id = ? AND user_id = ?',
                [groupId, userId]
            );

            if (membership.length === 0 || membership[0].role !== 'owner') {
                await connection.rollback();
                return res.status(403).json({ error: 'Access denied. Only group owner can delete the group' });
            }

            // Get group name for logging
            const [groupData] = await connection.execute('SELECT name FROM groups WHERE id = ?', [groupId]);
            
            if (groupData.length === 0) {
                await connection.rollback();
                return res.status(404).json({ error: 'Group not found' });
            }

            // Log the action
            const actionUuid = uuidv4();
            await connection.execute(`
                INSERT INTO group_admin_actions (uuid, group_id, admin_id, action_type, reason)
                VALUES (?, ?, ?, 'delete_group', ?)
            `, [actionUuid, groupId, userId, `Deleted group: ${groupData[0].name}`]);

            // Delete the group (cascade will handle related records)
            await connection.execute('DELETE FROM groups WHERE id = ?', [groupId]);

            await connection.commit();

            res.json({
                success: true,
                message: 'Group deleted successfully'
            });

        } catch (error) {
            await connection.rollback();
            throw error;
        } finally {
            connection.release();
        }

    } catch (error) {
        console.error('Error deleting group:', error);
        res.status(500).json({ error: 'Failed to delete group' });
    }
});

// Promote/demote member
router.post('/:groupId/promote', authenticateToken, async (req, res) => {
    try {
        const { groupId } = req.params;
        const { user_id, new_role } = req.body;
        const adminId = req.user.userId;
        
        if (!user_id || !new_role) {
            return res.status(400).json({ error: 'User ID and new role are required' });
        }

        if (!['member', 'admin'].includes(new_role)) {
            return res.status(400).json({ error: 'Invalid role. Must be member or admin' });
        }

        const connection = await pool.getConnection();

        try {
            await connection.beginTransaction();

            // Check if admin is the owner
            const [adminMembership] = await connection.execute(
                'SELECT role FROM group_members WHERE group_id = ? AND user_id = ?',
                [groupId, adminId]
            );

            if (adminMembership.length === 0 || adminMembership[0].role !== 'owner') {
                await connection.rollback();
                return res.status(403).json({ error: 'Access denied. Only group owner can promote/demote members' });
            }

            // Check if target user is a member
            const [targetMembership] = await connection.execute(
                'SELECT role FROM group_members WHERE group_id = ? AND user_id = ?',
                [groupId, user_id]
            );

            if (targetMembership.length === 0) {
                await connection.rollback();
                return res.status(404).json({ error: 'User is not a member of this group' });
            }

            // Cannot change owner role
            if (targetMembership[0].role === 'owner') {
                await connection.rollback();
                return res.status(400).json({ error: 'Cannot change owner role' });
            }

            // Cannot change your own role
            if (parseInt(user_id) === adminId) {
                await connection.rollback();
                return res.status(400).json({ error: 'You cannot change your own role' });
            }

            const oldRole = targetMembership[0].role;

            // Update member role
            await connection.execute(
                'UPDATE group_members SET role = ? WHERE group_id = ? AND user_id = ?',
                [new_role, groupId, user_id]
            );

            // Log the action
            const actionUuid = uuidv4();
            const actionType = new_role === 'admin' ? 'promote' : 'demote';
            await connection.execute(`
                INSERT INTO group_admin_actions (uuid, group_id, admin_id, target_user_id, action_type, reason)
                VALUES (?, ?, ?, ?, ?, ?)
            `, [actionUuid, groupId, adminId, user_id, actionType, `Changed role from ${oldRole} to ${new_role}`]);

            // Add system message
            const messageUuid = uuidv4();
            const [targetUser] = await connection.execute('SELECT username FROM users WHERE id = ?', [user_id]);
            await connection.execute(`
                INSERT INTO group_messages (uuid, group_id, user_id, message_type, content)
                VALUES (?, ?, ?, 'system', ?)
            `, [messageUuid, groupId, adminId, `${actionType}d ${targetUser[0].username} to ${new_role}`]);

            // Get group info for notifications
            const [groupInfo] = await connection.execute('SELECT name FROM groups WHERE id = ?', [groupId]);
            const [adminInfo] = await connection.execute('SELECT username FROM users WHERE id = ?', [adminId]);

            // Notify the user whose role changed
            await createNotification(
                user_id,
                'Role Changed',
                `Your role in ${groupInfo[0].name} has been changed from ${oldRole} to ${new_role} by ${adminInfo[0].username}`,
                actionType === 'promote' ? 'group_promote' : 'group_demote',
                'group',
                groupId,
                adminId,
                { 
                    groupName: groupInfo[0].name, 
                    adminUsername: adminInfo[0].username,
                    oldRole: oldRole,
                    newRole: new_role
                }
            );

            // Notify other group members about the role change
            const [otherMembers] = await connection.execute(`
                SELECT gm.user_id, u.username
                FROM group_members gm
                JOIN users u ON gm.user_id = u.id
                WHERE gm.group_id = ? AND gm.user_id NOT IN (?, ?)
            `, [groupId, adminId, user_id]);

            for (const member of otherMembers) {
                await createNotification(
                    member.user_id,
                    'Member Role Changed',
                    `${targetUser[0].username} was ${actionType}d to ${new_role} in ${groupInfo[0].name}`,
                    'group_member_role_change',
                    'group',
                    groupId,
                    adminId,
                    { 
                        groupName: groupInfo[0].name, 
                        changedUsername: targetUser[0].username,
                        adminUsername: adminInfo[0].username,
                        oldRole: oldRole,
                        newRole: new_role,
                        actionType: actionType
                    }
                );
            }

            await connection.commit();

            res.json({
                success: true,
                message: `User ${actionType}d successfully`
            });

        } catch (error) {
            await connection.rollback();
            throw error;
        } finally {
            connection.release();
        }

    } catch (error) {
        console.error('Error promoting/demoting member:', error);
        res.status(500).json({ error: 'Failed to change member role' });
    }
});

// Check if user is banned before allowing join
router.post('/check-ban', authenticateToken, async (req, res) => {
    try {
        const { invite_code } = req.body;
        const userId = req.user.userId;
        const connection = await pool.getConnection();

        // Find the group
        const [groups] = await connection.execute(
            'SELECT id FROM groups WHERE invite_code = ?',
            [invite_code.trim().toUpperCase()]
        );

        if (groups.length === 0) {
            connection.release();
            return res.status(404).json({ error: 'Invalid invite code' });
        }

        // Check if user is banned
        const [banRecord] = await connection.execute(
            'SELECT ban_reason, created_at FROM group_bans WHERE group_id = ? AND user_id = ? AND unbanned_at IS NULL',
            [groups[0].id, userId]
        );

        connection.release();

        if (banRecord.length > 0) {
            return res.status(403).json({ 
                error: 'You are banned from this group',
                ban_reason: banRecord[0].ban_reason,
                banned_at: banRecord[0].created_at
            });
        }

        res.json({ success: true, can_join: true });

    } catch (error) {
        console.error('Error checking ban status:', error);
        res.status(500).json({ error: 'Failed to check ban status' });
    }
});

module.exports = router; 