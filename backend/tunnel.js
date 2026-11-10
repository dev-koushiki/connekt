const localtunnel = require('localtunnel');
const path = require('path');
const fs = require('fs');
require('dotenv').config({ path: path.join(__dirname, '.env') });

const PORT = parseInt(process.env.PORT || '5000', 10);
const SUBDOMAIN = process.env.TUNNEL_SUBDOMAIN || undefined;

(async () => {
  console.log(`============================================================`);
  console.log(`🌐 INITIALIZING CONNEKT PUBLIC CLOUD TUNNEL...`);
  console.log(`   Connecting local port ${PORT} to secure worldwide HTTPS...`);
  console.log(`============================================================`);

  try {
    const tunnel = await localtunnel({
      port: PORT,
      subdomain: SUBDOMAIN
    });

    console.log(`\n✅ CLOUD TUNNEL ACTIVE! WORKS ON EVERY NETWORK:`);
    console.log(`👉 PUBLIC URL: ${tunnel.url}`);
    console.log(`👉 API BASE:   ${tunnel.url}/api\n`);
    console.log(`📱 HOW TO CONNECT ON ANY NETWORK (4G / 5G / DIFFERENT WI-FI):`);
    console.log(`   1. Open CONNEKT app on your phone`);
    console.log(`   2. Tap the Settings icon ⚙️ on the top-right of Sign In screen`);
    console.log(`   3. Paste this URL into Host: ${tunnel.url.replace(/^https?:\/\//, '')}`);
    console.log(`   4. Tap Save! (Runs anywhere in the world!)\n`);
    console.log(`Press Ctrl+C to close tunnel.\n`);

    // Write public URL to a config file for reference
    const infoPath = path.join(__dirname, 'active_tunnel.json');
    fs.writeFileSync(infoPath, JSON.stringify({
      url: tunnel.url,
      apiUrl: `${tunnel.url}/api`,
      updatedAt: new Date().toISOString()
    }, null, 2));

    tunnel.on('close', () => {
      console.log('Tunnel closed.');
      if (fs.existsSync(infoPath)) fs.unlinkSync(infoPath);
    });

    tunnel.on('error', (err) => {
      console.error('Tunnel error:', err.message);
    });
  } catch (err) {
    console.error('Failed to create cloud tunnel:', err.message);
    console.log('💡 Tip: You can also use "npx ngrok http 5000" or Cloudflare Quick Tunnels.');
  }
})();
