/**
 * CONNEKT Real-Time Communication Manager (Phase 2 Foundation)
 */
class ChatManager {
  constructor() {
    this.socket = null;
    this.conversations = [];
    this.activeConversation = null;
  }

  init(token) {
    if (typeof io !== 'undefined') {
      this.socket = io({
        auth: { token }
      });

      this.socket.on('connect', () => {
        console.log('[Chat] Connected to real-time messaging gateway.');
      });

      this.socket.on('message:received', (msg) => {
        console.log('[Chat] New incoming message:', msg);
        window.dispatchEvent(new CustomEvent('chat:new_message', { detail: msg }));
      });

      this.socket.on('user:online', (data) => {
        window.dispatchEvent(new CustomEvent('presence:online', { detail: data }));
      });

      this.socket.on('user:offline', (data) => {
        window.dispatchEvent(new CustomEvent('presence:offline', { detail: data }));
      });
    }
  }

  disconnect() {
    if (this.socket) {
      this.socket.disconnect();
      this.socket = null;
    }
  }
}

window.chatManager = new ChatManager();
