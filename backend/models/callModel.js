const db = require('../config/database');

// In-memory tracker for live sync requests between web and mobile devices
const syncRequests = new Map(); // userId -> { requestedAt, resolvedAt }
let tableInitPromise = null;

class CallModel {
  /**
   * Ensure the user_device_call_logs table and indexes exist before querying.
   */
  static async ensureTable() {
    if (!tableInitPromise) {
      tableInitPromise = db.query(`
        CREATE TABLE IF NOT EXISTS user_device_call_logs (
          id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
          user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
          contact_name VARCHAR(150) NOT NULL,
          phone_number VARCHAR(50) NOT NULL,
          call_type VARCHAR(30) NOT NULL DEFAULT 'unknown',
          duration_seconds INTEGER NOT NULL DEFAULT 0,
          call_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          synced_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
          UNIQUE (user_id, phone_number, call_timestamp)
        );
        CREATE INDEX IF NOT EXISTS idx_device_call_logs_user_time
          ON user_device_call_logs(user_id, call_timestamp DESC);
      `).catch((err) => {
        tableInitPromise = null;
        throw err;
      });
    }
    return tableInitPromise;
  }

  /**
   * Save or upsert a batch of device call logs from user's phone contacts
   */
  static async saveDeviceCallLogs(userId, logs) {
    if (!logs || !Array.isArray(logs) || logs.length === 0) {
      return { insertedCount: 0, total: 0 };
    }

    await this.ensureTable();
    let insertedCount = 0;
    const client = await db.pool.connect();

    try {
      await client.query('BEGIN');

      const query = `
        INSERT INTO user_device_call_logs (
          user_id, contact_name, phone_number, call_type, duration_seconds, call_timestamp, synced_at
        ) VALUES ($1, $2, $3, $4, $5, $6, NOW())
        ON CONFLICT (user_id, phone_number, call_timestamp)
        DO UPDATE SET
          contact_name = EXCLUDED.contact_name,
          duration_seconds = EXCLUDED.duration_seconds,
          synced_at = NOW()
        RETURNING id;
      `;

      for (const log of logs) {
        const number = (log.number || log.phoneNumber || '').toString().trim();
        if (!number) continue;

        const name = (log.name || log.contactName || number).toString().trim();
        const type = (log.type || log.callType || 'unknown').toString().toLowerCase();
        const duration = parseInt(log.duration || log.durationSeconds || 0, 10) || 0;

        let timestamp;
        if (typeof log.timestamp === 'number') {
          timestamp = new Date(log.timestamp);
        } else if (log.timestamp) {
          timestamp = new Date(log.timestamp);
        } else {
          timestamp = new Date();
        }

        // Validate date
        if (isNaN(timestamp.getTime())) {
          timestamp = new Date();
        }

        await client.query(query, [
          userId,
          name,
          number,
          type,
          duration,
          timestamp
        ]);
        insertedCount++;
      }

      await client.query('COMMIT');

      // Clear pending sync request
      if (syncRequests.has(userId)) {
        syncRequests.get(userId).resolvedAt = new Date().toISOString();
      }

      return { insertedCount, total: logs.length };
    } catch (err) {
      await client.query('ROLLBACK');
      console.error('[CallModel.saveDeviceCallLogs Error]:', err.message);
      throw err;
    } finally {
      client.release();
    }
  }

  /**
   * Retrieve synced device call logs for a user with optional type filtering
   */
  static async getDeviceCallLogs(userId, { type = 'all', limit = 50, offset = 0 } = {}) {
    await this.ensureTable();
    let sql = `
      SELECT id, contact_name, phone_number, call_type, duration_seconds, call_timestamp, synced_at
      FROM user_device_call_logs
      WHERE user_id = $1
    `;
    const params = [userId];

    if (type && type !== 'all') {
      params.push(type.toLowerCase());
      sql += ` AND LOWER(call_type) = $${params.length}`;
    }

    sql += ` ORDER BY call_timestamp DESC LIMIT $${params.length + 1} OFFSET $${params.length + 2}`;
    params.push(parseInt(limit, 10) || 50);
    params.push(parseInt(offset, 10) || 0);

    const res = await db.query(sql, params);

    // Get total count
    let countSql = `SELECT COUNT(*) AS total FROM user_device_call_logs WHERE user_id = $1`;
    const countParams = [userId];
    if (type && type !== 'all') {
      countParams.push(type.toLowerCase());
      countSql += ` AND LOWER(call_type) = $2`;
    }
    const countRes = await db.query(countSql, countParams);

    return {
      logs: res.rows.map(r => ({
        id: r.id,
        name: r.contact_name,
        number: r.phone_number,
        type: r.call_type,
        duration: r.duration_seconds,
        timestamp: r.call_timestamp,
        syncedAt: r.synced_at
      })),
      total: parseInt(countRes.rows[0]?.total || 0, 10)
    };
  }

  /**
   * Flag that the website has requested call logs synchronization from the user's phone
   */
  static requestSync(userId) {
    syncRequests.set(userId, {
      requestedAt: new Date().toISOString(),
      resolvedAt: null
    });
  }

  /**
   * Get sync status for user
   */
  static async getSyncStatus(userId) {
    await this.ensureTable();
    const req = syncRequests.get(userId);
    const countRes = await db.query(
      `SELECT COUNT(*) AS count, MAX(synced_at) AS last_synced FROM user_device_call_logs WHERE user_id = $1`,
      [userId]
    );

    const hasPendingRequest = req ? !req.resolvedAt : false;

    return {
      syncRequested: hasPendingRequest,
      requestedAt: req?.requestedAt || null,
      lastSyncedAt: countRes.rows[0]?.last_synced || null,
      totalCount: parseInt(countRes.rows[0]?.count || 0, 10)
    };
  }
}

module.exports = CallModel;
