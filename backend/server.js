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
const meetingRoutes = require('./routes/meetingRoutes');
const chatRoutes = require('./routes/chatRoutes');
const callRoutes = require('./routes/callRoutes');
const { apiLimiter } = require('./middleware/rateLimiter');

const app = express();
app.set('trust proxy', 1); // Trust first hop for reverse proxy / cloud tunnel rate limiting
const server = http.createServer(app);

// Socket.io initialization
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  }
});
app.set('io', io);
setupSockets(io);

// Security & Middlewares
app.use(helmet({
  contentSecurityPolicy: false, // Disabled for ease of serving vanilla frontend assets and scripts
  crossOriginEmbedderPolicy: false,
  crossOriginResourcePolicy: { policy: 'cross-origin' }
}));

app.use(cors({
  origin: '*',
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'bypass-tunnel-reminder']
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
app.use('/api/meetings', meetingRoutes);
app.use('/api/chats', chatRoutes);
app.use('/api/calls', callRoutes);

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
  if (err && err.name === 'MulterError') {
    const message = err.code === 'LIMIT_FILE_SIZE'
      ? 'Image file is too large. Maximum allowed size is 5MB.'
      : (err.message || 'Invalid file upload request.');
    return res.status(400).json({
      success: false,
      message
    });
  }
  const status = err.statusCode || 500;
  return res.status(status).json({
    success: false,
    message: err.message || 'Internal Server Error'
  });
});

const PORT = parseInt(process.env.PORT || '5000', 10);

server.on('error', (err) => {
  if (err.code === 'EADDRINUSE') {
    console.error(`\n❌ [PORT CONFLICT] Port ${PORT} is already in use by another running process.`);
    console.error(`💡 Run: npx kill-port ${PORT} or close the other terminal running node.\n`);
    process.exit(1);
  } else {
    console.error('[Server Error]:', err);
  }
});

const os = require('os');

const getLocalIpAddresses = () => {
  const interfaces = os.networkInterfaces();
  const addresses = [];
  for (const name of Object.keys(interfaces)) {
    for (const iface of interfaces[name]) {
      if (iface.family === 'IPv4' && !iface.internal) {
        const isVirtual = /virtual|vethernet|loopback|bluetooth|virtualbox|vbox|host-only/i.test(name) ||
                          iface.address.startsWith('192.168.56.') ||
                          iface.address.startsWith('169.254.');
        addresses.push({
          name,
          address: iface.address,
          isPreferred: (/wi-fi|wlan|wireless/i.test(name) || /ethernet/i.test(name)) && !isVirtual
        });
      }
    }
  }
  addresses.sort((a, b) => (b.isPreferred ? 1 : 0) - (a.isPreferred ? 1 : 0));
  return addresses;
};

server.listen(PORT, async () => {
  const ips = getLocalIpAddresses();
  const primaryIp = ips[0]?.address || 'localhost';

  console.log(`====================================================`);
  console.log(`🚀 CONNEKT Unified Ecosystem Server Running!`);
  console.log(`🌐 Localhost:     http://localhost:${PORT}`);
  console.log(`📱 Phone (Wi-Fi): http://${primaryIp}:${PORT}`);
  if (ips.length > 1) {
    console.log(`   Other IPs:    ${ips.slice(1).map(i => `${i.name}: ${i.address}`).join(', ')}`);
  }
  console.log(`🔌 USB Cable:     adb reverse tcp:${PORT} tcp:${PORT} (use localhost:${PORT})`);
  console.log(`🌍 Any Network:   npm run tunnel (works on 4G/5G mobile data anywhere)`);
  console.log(`====================================================`);

  try {
    const res = await db.query('SELECT version();');
    console.log(`✅ Connected to PostgreSQL: ${res.rows[0].version.split(',')[0]}`);
  } catch (dbErr) {
    console.error(`❌ Database Connection Failed:`, dbErr.message);
  }

  if (process.env.AUTO_START_TUNNEL === 'true') {
    try {
      const localtunnel = require('localtunnel');
      const tunnel = await localtunnel({ port: PORT, subdomain: process.env.TUNNEL_SUBDOMAIN || undefined });
      const fs = require('fs');
      fs.writeFileSync(path.join(__dirname, 'active_tunnel.json'), JSON.stringify({
        url: tunnel.url,
        apiUrl: `${tunnel.url}/api`,
        updatedAt: new Date().toISOString()
      }, null, 2));
      console.log(`\n====================================================`);
      console.log(`🌍 AUTO CLOUD TUNNEL RUNNING (FOR 5G MOBILE DATA):`);
      console.log(`   👉 URL: ${tunnel.url}`);
      console.log(`   👉 Use on 5G phone: Tap ⚙️ Settings in app and enter:`);
      console.log(`      ${tunnel.url.replace(/^https?:\/\//, '')}`);
      console.log(`====================================================\n`);
    } catch (tErr) {
      console.warn(`[Tunnel Warning] Could not start auto cloud tunnel: ${tErr.message}`);
    }
  }
});
