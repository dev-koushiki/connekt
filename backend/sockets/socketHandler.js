const { verifyToken } = require('../services/tokenService');

const setupSockets = (io) => {
  // Authentication middleware for socket connections
  io.use((socket, next) => {
    const token = socket.handshake.auth?.token || socket.handshake.query?.token;
    if (!token) {
      // Allow unauthenticated connection or reject depending on strictness
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
      // Join user specific room
      socket.join(`user:${socket.user.id}`);

      // Broadcast user online event
      socket.broadcast.emit('user:online', { userId: socket.user.id, username: socket.user.username });
    } else {
      console.log(`[Socket] Anonymous client connected: ${socket.id}`);
    }

    socket.on('disconnect', () => {
      if (socket.user) {
        console.log(`[Socket] User disconnected: @${socket.user.username}`);
        socket.broadcast.emit('user:offline', { userId: socket.user.id, lastSeen: new Date().toISOString() });
      }
    });
  });
};

module.exports = setupSockets;
