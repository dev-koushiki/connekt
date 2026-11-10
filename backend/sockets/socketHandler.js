const { verifyToken } = require('../services/tokenService');
const MeetingModel = require('../models/meetingModel');

// Map of active meeting rooms: roomCode -> Map(socketId -> peerData)
const activeMeetingRooms = new Map();

const setupSockets = (io) => {
  // Authentication middleware for socket connections
  io.use((socket, next) => {
    const token = socket.handshake.auth?.token || socket.handshake.query?.token;
    if (!token) {
      return next();
    }
    const decoded = verifyToken(token);
    if (decoded) {
      socket.user = decoded;
    }
    next();
  });

  io.on('connection', (socket) => {
    if (socket.user) {
      console.log(`[Socket] Authenticated user connected: @${socket.user.username} (${socket.user.id})`);
      socket.join(`user:${socket.user.id}`);
      socket.broadcast.emit('user:online', { userId: socket.user.id, username: socket.user.username });
    } else {
      console.log(`[Socket] Anonymous client connected: ${socket.id}`);
    }

    // Helper: leave all meeting rooms for a disconnecting socket
    const cleanupMeetingRooms = () => {
      activeMeetingRooms.forEach((peersMap, roomCode) => {
        if (peersMap.has(socket.id)) {
          const peer = peersMap.get(socket.id);
          peersMap.delete(socket.id);

          const socketRoom = `meeting:${roomCode}`;
          socket.to(socketRoom).emit('meeting:peer-left', {
            socketId: socket.id,
            userId: peer.userId,
            username: peer.username,
            name: peer.name
          });

          if (peersMap.size === 0) {
            activeMeetingRooms.delete(roomCode);
          }
        }
      });
    };

    socket.on('disconnecting', () => {
      cleanupMeetingRooms();
    });

    socket.on('disconnect', () => {
      if (socket.user) {
        console.log(`[Socket] User disconnected: @${socket.user.username}`);
        socket.broadcast.emit('user:offline', { userId: socket.user.id, lastSeen: new Date().toISOString() });
      }
    });

    // ====================================================================
    // WEBRTC SIGNALING & COLLABORATION SOCKET EVENTS (PHASE 2)
    // ====================================================================

    /**
     * Join meeting room
     */
    socket.on('meeting:join-room', async ({ roomCode, user }) => {
      if (!roomCode) return;
      const cleanCode = roomCode.trim().toLowerCase();
      const socketRoom = `meeting:${cleanCode}`;
      socket.join(socketRoom);

      if (!activeMeetingRooms.has(cleanCode)) {
        activeMeetingRooms.set(cleanCode, new Map());
      }
      const peersMap = activeMeetingRooms.get(cleanCode);

      const peerData = {
        socketId: socket.id,
        userId: user?.id || socket.user?.id || `guest_${socket.id.substring(0, 6)}`,
        username: user?.username || socket.user?.username || 'Guest',
        name: user?.personalProfile?.fullName || user?.name || user?.username || socket.user?.username || 'Guest',
        avatarUrl: user?.personalProfile?.avatarUrl || user?.avatarUrl || '',
        role: user?.role || 'participant',
        isMicOn: user?.isMicOn !== false,
        isCameraOn: user?.isCameraOn !== false,
        isScreenSharing: false,
        joinedAt: new Date().toISOString()
      };

      // 1. Send all existing peers in the room to the newly joined peer
      const existingPeers = Array.from(peersMap.values());
      socket.emit('meeting:all-peers', {
        roomCode: cleanCode,
        peers: existingPeers
      });

      // 2. Add new peer to room map
      peersMap.set(socket.id, peerData);

      // 3. Notify other peers in this room
      socket.to(socketRoom).emit('meeting:peer-joined', {
        roomCode: cleanCode,
        peer: peerData
      });

      console.log(`[Socket] Peer ${peerData.name} (@${peerData.username}) joined room ${cleanCode}. Active in room: ${peersMap.size}`);
    });

    /**
     * WebRTC signaling message exchange (SDP offer, answer, or ICE candidate)
     */
    socket.on('meeting:signal', async (data) => {
      const { roomCode, targetSocketId, targetUserId, signal, type } = data;
      if (!roomCode || (!targetSocketId && !targetUserId) || !signal) return;

      const cleanCode = roomCode.trim().toLowerCase();
      const peersMap = activeMeetingRooms.get(cleanCode);
      const senderPeer = peersMap?.get(socket.id) || {
        socketId: socket.id,
        userId: socket.user?.id,
        username: socket.user?.username,
        name: socket.user?.username || 'Participant'
      };

      const forwardPayload = {
        roomCode: cleanCode,
        senderSocketId: socket.id,
        senderId: senderPeer.userId,
        senderName: senderPeer.name,
        signal,
        type: type || signal.type || 'signal'
      };

      // Deliver via socket id if targetSocketId provided
      if (targetSocketId) {
        io.to(targetSocketId).emit('meeting:signal', forwardPayload);
      } else if (targetUserId) {
        io.to(`user:${targetUserId}`).emit('meeting:signal', forwardPayload);
      }

      // Asynchronously persist in DB for reliability/audit
      if (targetUserId && senderPeer.userId) {
        MeetingModel.saveSignal({
          roomCode: cleanCode,
          senderId: senderPeer.userId,
          recipientId: targetUserId,
          signalType: forwardPayload.type,
          payload: signal
        }).catch(err => console.error('[Signaling DB Save Error]:', err.message));
      }
    });

    /**
     * Broadcast media toggle (mic, camera, screen share)
     */
    socket.on('meeting:media-status', ({ roomCode, isMicOn, isCameraOn, isScreenSharing }) => {
      if (!roomCode) return;
      const cleanCode = roomCode.trim().toLowerCase();
      const peersMap = activeMeetingRooms.get(cleanCode);
      if (peersMap && peersMap.has(socket.id)) {
        const peer = peersMap.get(socket.id);
        if (isMicOn !== undefined) peer.isMicOn = !!isMicOn;
        if (isCameraOn !== undefined) peer.isCameraOn = !!isCameraOn;
        if (isScreenSharing !== undefined) peer.isScreenSharing = !!isScreenSharing;
      }

      socket.to(`meeting:${cleanCode}`).emit('meeting:peer-media-status', {
        socketId: socket.id,
        userId: socket.user?.id,
        isMicOn,
        isCameraOn,
        isScreenSharing
      });
    });

    /**
     * In-meeting real-time chat message
     */
    socket.on('meeting:chat-message', async ({ roomCode, message }) => {
      if (!roomCode || !message || !message.trim()) return;
      const cleanCode = roomCode.trim().toLowerCase();
      const senderId = socket.user?.id || socket.id;
      const senderName = socket.user?.username || 'Guest';

      try {
        const savedMsg = await MeetingModel.saveChatMessage({
          roomCode: cleanCode,
          senderId,
          senderName,
          message: message.trim()
        });

        io.to(`meeting:${cleanCode}`).emit('meeting:new-chat-message', {
          id: savedMsg.id,
          roomCode: cleanCode,
          senderId,
          senderName,
          message: savedMsg.message,
          createdAt: savedMsg.created_at
        });
      } catch (err) {
        console.error('[Meeting Chat Socket Error]:', err.message);
      }
    });

    /**
     * Hand Raising collaboration event (Phase 3)
     */
    socket.on('meeting:hand-raise', ({ roomCode, isHandRaised }) => {
      if (!roomCode) return;
      const cleanCode = roomCode.trim().toLowerCase();
      const peersMap = activeMeetingRooms.get(cleanCode);
      const peer = peersMap?.get(socket.id);

      if (peer) {
        peer.isHandRaised = !!isHandRaised;
      }

      socket.to(`meeting:${cleanCode}`).emit('meeting:peer-hand-raise', {
        socketId: socket.id,
        userId: socket.user?.id,
        name: peer?.name || socket.user?.username || 'Participant',
        isHandRaised: !!isHandRaised
      });
    });

    /**
     * Host & Co-Host controls action (Phase 3)
     */
    socket.on('meeting:host-action', async ({ roomCode, action, targetSocketId, targetUserId }) => {
      if (!roomCode || !action) return;
      const cleanCode = roomCode.trim().toLowerCase();

      try {
        const meeting = await MeetingModel.findByRoomCode(cleanCode);
        if (!meeting) return;

        // Verify host or co-host authorization
        const isHost = socket.user?.id === meeting.host_id;
        let isAuthorized = isHost;

        if (!isHost && socket.user?.id) {
          const coHostCheck = await MeetingModel.getParticipants(meeting.id);
          isAuthorized = coHostCheck.some(p => p.user_id === socket.user.id && p.role === 'co-host');
        }

        if (!isAuthorized) {
          socket.emit('meeting:error', { message: 'Only the host or co-host has permission to perform this action.' });
          return;
        }

        if (action === 'mute-all') {
          io.to(`meeting:${cleanCode}`).emit('meeting:host-action', { action: 'mute-all' });
        } else if (action === 'mute-peer' && targetSocketId) {
          io.to(targetSocketId).emit('meeting:host-action', { action: 'mute-peer' });
        } else if (action === 'lower-hand' && targetSocketId) {
          io.to(targetSocketId).emit('meeting:host-action', { action: 'lower-hand' });
        } else if (action === 'promote-cohost' && targetUserId) {
          // Update role in DB
          const db = require('../config/database');
          await db.query(
            `UPDATE meeting_participants SET role = 'co-host' WHERE meeting_id = $1 AND user_id = $2`,
            [meeting.id, targetUserId]
          );

          if (targetSocketId) {
            io.to(targetSocketId).emit('meeting:host-action', { action: 'promoted-cohost' });
          }
          io.to(`meeting:${cleanCode}`).emit('meeting:peer-role-updated', {
            userId: targetUserId,
            socketId: targetSocketId,
            role: 'co-host'
          });
        } else if (action === 'lock-meeting') {
          await MeetingModel.setMeetingLock(meeting.id, meeting.host_id, true);
          io.to(`meeting:${cleanCode}`).emit('meeting:host-action', { action: 'locked', isLocked: true });
        } else if (action === 'unlock-meeting') {
          await MeetingModel.setMeetingLock(meeting.id, meeting.host_id, false);
          io.to(`meeting:${cleanCode}`).emit('meeting:host-action', { action: 'unlocked', isLocked: false });
        } else if (action === 'end-meeting') {
          await MeetingModel.endMeeting(meeting.id, meeting.host_id);
          io.to(`meeting:${cleanCode}`).emit('meeting:host-action', { action: 'ended' });
        } else if (action === 'kick-peer' && targetSocketId) {
          io.to(targetSocketId).emit('meeting:host-action', { action: 'kicked' });
        }
      } catch (err) {
        console.error('[Host Action Error]:', err.message);
      }
    });

    /**
     * Broadcast meeting recording status (Phase 4)
     */
    socket.on('meeting:recording-status', ({ roomCode, isRecording, startedBy }) => {
      if (!roomCode) return;
      const cleanCode = roomCode.trim().toLowerCase();
      io.to(`meeting:${cleanCode}`).emit('meeting:recording-status', {
        roomCode: cleanCode,
        isRecording: Boolean(isRecording),
        startedBy: startedBy || socket.user?.username || 'Host',
        startedAt: new Date().toISOString()
      });
    });

    /**
     * Leave meeting room explicit event
     */
    socket.on('meeting:leave-room', ({ roomCode }) => {
      if (!roomCode) return;
      const cleanCode = roomCode.trim().toLowerCase();
      const socketRoom = `meeting:${cleanCode}`;
      socket.leave(socketRoom);

      const peersMap = activeMeetingRooms.get(cleanCode);
      if (peersMap && peersMap.has(socket.id)) {
        const peer = peersMap.get(socket.id);
        peersMap.delete(socket.id);

        socket.to(socketRoom).emit('meeting:peer-left', {
          socketId: socket.id,
          userId: peer.userId,
          username: peer.username,
          name: peer.name
        });

        if (peersMap.size === 0) {
          activeMeetingRooms.delete(cleanCode);
        }
      }
    });
  });
};

module.exports = setupSockets;
