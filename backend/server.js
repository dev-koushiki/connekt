const express = require('express');
const http = require('http');
const path = require('path');
const cors = require('cors');
const helmet = require('helmet');
const { Server } = require('socket.io');
require('dotenv').config({ path: path.join(__dirname, '.env') });

const db = require('./config/database');
const setupSockets = require('./sockets/socketHandler');
const authRoutes = require('./routes/authRoutes');
const userRoutes = require('./routes/userRoutes');
const sessionRoutes = require('./routes/sessionRoutes');
const { apiLimiter } = require('./middleware/rateLimiter');

const app = express();
const server = http.createServer(app);

// Socket.io initialization
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  }
});
setupSockets(io);

// Security & Middlewares
app.use(helmet({
  contentSecurityPolicy: false, // Disabled for ease of serving vanilla frontend assets and scripts
  crossOriginEmbedderPolicy: false
}));

app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Apply rate limiter to general API
app.use('/api', apiLimiter);

// Static file serving
const frontendPath = path.join(__dirname, '../frontend');
const uploadsPath = path.join(__dirname, 'uploads');
app.use(express.static(frontendPath));
app.use('/uploads', express.static(uploadsPath));

// Health Check API
app.get('/api/health', async (req, res) => {
  try {
    const dbRes = await db.query('SELECT NOW() as current_time, current_database() as database');
    return res.status(200).json({
      status: 'healthy',
      system: 'CONNEKT Digital Ecosystem',
      database: dbRes.rows[0],
      uptime: process.uptime()
    });
  } catch (err) {
    return res.status(500).json({
      status: 'unhealthy',
      error: err.message
    });
  }
});

// API Routes
app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/sessions', sessionRoutes);

// Fallback routing for SPA / Pages
app.use((req, res) => {
  if (req.path.startsWith('/api')) {
    return res.status(404).json({ success: false, message: 'API route not found' });
  }
  return res.sendFile(path.join(frontendPath, 'index.html'));
});

// Global Error Handler
app.use((err, req, res, next) => {
  console.error('[Global Error]:', err);
  const status = err.statusCode || 500;
  return res.status(status).json({
    success: false,
    message: err.message || 'Internal Server Error'
  });
});

const PORT = parseInt(process.env.PORT || '5000', 10);

server.listen(PORT, async () => {
  console.log(`====================================================`);
  console.log(`🚀 CONNEKT Unified Ecosystem Server Running!`);
  console.log(`🌐 Address: http://localhost:${PORT}`);
  console.log(`📦 Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`====================================================`);

  try {
    const res = await db.query('SELECT version();');
    console.log(`✅ Connected to PostgreSQL: ${res.rows[0].version.split(',')[0]}`);
  } catch (dbErr) {
    console.error(`❌ Database Connection Failed:`, dbErr.message);
  }
});
