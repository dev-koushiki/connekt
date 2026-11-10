/**
 * CONNEKT Meetings & Real-Time Collaboration Module (Phase 2 & 3)
 * Full WebRTC Peer-to-Peer Mesh, STUN/TURN Signaling, Audio/Video, Screen Share Spotlight,
 * In-Meeting Chat with Export, Interactive Participants Roster, Hand Raising & Host Moderation
 */

class MeetingRoomManager {
  constructor() {
    this.meeting = null;
    this.role = 'participant'; // 'host' | 'co-host' | 'participant'
    this.currentUser = null;
    this.roomCode = '';

    // Media Streams & Devices
    this.localStream = null;
    this.screenStream = null;
    this.isMicOn = true;
    this.isCameraOn = true;
    this.isScreenSharing = false;

    // Phase 3 Collaboration States
    this.isHandRaised = false;
    this.activePresenter = null; // { id, name, isLocal }

    // Phase 4 Browser Recording
    this.isRecording = false;
    this.mediaRecorder = null;
    this.recordedChunks = [];
    this.recordTimerInterval = null;
    this.recordSeconds = 0;
    this.audioContext = null;
    this.audioDestination = null;

    // WebRTC Peer Connections Map: socketId -> RTCPeerConnection
    this.peerConnections = new Map();
    // Remote MediaStreams Map: socketId -> MediaStream
    this.remoteStreams = new Map();
    // Connected Peers Metadata Map: socketId -> peerData
    this.connectedPeers = new Map();
    // ICE candidate buffer: socketId -> Array of candidates
    this.pendingCandidates = new Map();

    // Call Timer & State
    this.callDurationSeconds = 0;
    this.timerInterval = null;
    this.pollingInterval = null;

    // Chat
    this.chatMessages = [];
    this.unreadChatCount = 0;
    this.isChatDrawerOpen = false;
    this.isParticipantsDrawerOpen = false;
    this.isInfoModalOpen = false;

    // STUN Servers Configuration
    this.rtcConfig = {
      iceServers: [
        { urls: 'stun:stun.l.google.com:19302' },
        { urls: 'stun:stun1.l.google.com:19302' },
        { urls: 'stun:global.stun.twilio.com:3478' }
      ]
    };
  }

  /**
   * Enter the Meeting Room and initialize WebRTC conferencing
   */
  async enterRoom(meeting, role = 'participant', currentUser = null) {
    this.meeting = meeting;
    this.role = role;
    this.currentUser = currentUser || window.api?.getUser();
    this.roomCode = meeting.roomCode || meeting.room_code;
    this.isHandRaised = false;
    this.activePresenter = null;

    console.log(`[MeetingRoom] Entering room ${this.roomCode} as ${this.role}...`);

    // 1. Render meeting room DOM layout
    this.renderMeetingRoomDOM();

    // 2. Initialize persistent audio playback container
    this.ensureAudioContainer();

    // 3. Request user media (mic + camera with audio fallback)
    await this.initLocalMedia();

    // 4. Connect to Socket.IO signaling
    this.setupSignaling();

    // 5. Start call duration timer
    this.startCallTimer();

    // 6. Load in-meeting chat history from PostgreSQL
    this.loadChatHistory();
  }

  /**
   * Render the meeting room full-screen overlay
   */
  renderMeetingRoomDOM() {
    const existing = document.getElementById('meetingRoomOverlay');
    if (existing) existing.remove();

    const isHostOrCoHost = this.role === 'host' || this.role === 'co-host' || this.meeting.host_id === this.currentUser?.id;

    const overlay = document.createElement('div');
    overlay.id = 'meetingRoomOverlay';
    overlay.className = 'meeting-room-overlay';
    overlay.innerHTML = `
      <!-- Top Bar -->
      <div class="meeting-room-topbar">
        <div style="display: flex; align-items: center; gap: 14px;">
          <div style="display: flex; align-items: center; gap: 8px;">
            <div style="width: 32px; height: 32px; border-radius: 8px; background: rgba(37, 99, 235, 0.2); color: #3b82f6; display: flex; align-items: center; justify-content: center; font-size: 1.1rem;">📹</div>
            <div>
              <div style="font-weight: 700; font-size: 0.95rem; color: var(--text-primary); line-height: 1.2;">
                ${this.meeting.title || 'CONNEKT Meeting'}
              </div>
              <div style="font-size: 0.75rem; color: var(--text-muted); display: flex; align-items: center; gap: 8px;">
                <span class="meeting-code-chip" style="padding: 1px 6px; font-size: 0.75rem;" onclick="window.meetingRoom.copyInviteLink()">
                  <span>CNK-${this.roomCode}</span>
                  <span>📋</span>
                </span>
                <span id="callDurationDisplay" style="font-family: monospace; color: var(--accent-cyan); font-weight: 600;">00:00</span>
                <span id="meetingRecPill" class="meeting-rec-pill" style="display: none;"><span class="rec-dot"></span>REC <span id="meetingRecTimer">00:00</span></span>
                <span id="meetingLockBadge" class="badge badge-warning" style="display: ${this.meeting.is_locked ? 'inline-block' : 'none'}; font-size: 0.68rem; padding: 1px 6px;">🔒 Room Locked</span>
              </div>
            </div>
          </div>
        </div>

        <div style="display: flex; align-items: center; gap: 10px;">
          <span class="status-beacon live"><span class="beacon-dot"></span>LIVE CALL</span>
          <button class="btn btn-secondary btn-sm" onclick="window.meetingRoom.toggleMeetingInfo()">
            ℹ️ Info
          </button>
          <button class="btn btn-secondary btn-sm" onclick="window.meetingRoom.copyInviteLink()">
            Copy Invite
          </button>
        </div>
      </div>

      <!-- Main Video Area & Side Drawers -->
      <div class="meeting-room-main">
        <div class="meeting-video-area">
          <!-- Screen Share Banner Notification -->
          <div id="screenShareIndicator" class="screen-share-indicator-pill" style="display: none;"></div>

          <div id="meetingVideoGrid" class="meeting-video-grid" data-count="1">
            <!-- Local User Tile -->
            <div id="localVideoTile" class="meeting-video-tile local">
              <div id="localHandBadge" class="hand-raise-badge" style="display: none;">✋</div>
              <video id="localVideoEl" autoplay playsinline muted></video>
              <div id="localAvatarPlaceholder" class="meeting-avatar-placeholder" style="display: none;">
                <div class="meeting-avatar-circle">
                  ${(this.currentUser?.personalProfile?.fullName || this.currentUser?.username || 'U')[0].toUpperCase()}
                </div>
                <div style="font-size: 0.9rem; font-weight: 600; color: var(--text-primary);">
                  ${this.currentUser?.personalProfile?.fullName || this.currentUser?.username || 'You'}
                </div>
              </div>
              <div class="meeting-tile-overlay">
                <div class="meeting-name-pill">
                  <span id="localNameLabel">${this.currentUser?.personalProfile?.fullName || this.currentUser?.username || 'You'} (You)</span>
                  <span id="localMicIcon">🎙️</span>
                </div>
              </div>
            </div>
            <!-- Remote participant tiles dynamically inserted here -->
          </div>
        </div>

        <!-- Chat Side Drawer -->
        <div id="meetingChatDrawer" class="meeting-side-drawer" style="display: none;">
          <div class="meeting-drawer-header">
            <h4 style="margin: 0; display: flex; align-items: center; gap: 8px;">
              <span>💬 Meeting Chat</span>
            </h4>
            <div style="display: flex; align-items: center; gap: 8px;">
              <button class="btn btn-secondary btn-sm" style="font-size: 0.75rem; padding: 3px 8px;" onclick="window.meetingRoom.exportChatHistory()">
                Export 📥
              </button>
              <button class="modal-close-btn" onclick="window.meetingRoom.toggleChatDrawer()">&times;</button>
            </div>
          </div>
          <div id="meetingChatMessagesList" class="meeting-drawer-body">
            <div style="text-align: center; color: var(--text-muted); font-size: 0.8rem; padding: 12px 0;">
              Messages in this meeting are end-to-end synchronized.
            </div>
          </div>
          <div class="meeting-chat-input-bar">
            <input type="text" id="meetingChatInput" class="form-control" placeholder="Type a message..." onkeydown="if(event.key === 'Enter') window.meetingRoom.sendChatMessage()" />
            <button class="btn btn-primary btn-sm" onclick="window.meetingRoom.sendChatMessage()">Send</button>
          </div>
        </div>

        <!-- Participants Side Drawer (Phase 3 Moderation) -->
        <div id="meetingParticipantsDrawer" class="meeting-side-drawer" style="display: none;">
          <div class="meeting-drawer-header">
            <h4 style="margin: 0; display: flex; align-items: center; gap: 8px;">
              <span>👥 Participants (<span id="meetingParticipantsCount">1</span>)</span>
            </h4>
            <button class="modal-close-btn" onclick="window.meetingRoom.toggleParticipantsDrawer()">&times;</button>
          </div>
          <div id="meetingParticipantsList" class="meeting-drawer-body">
            <!-- Dynamically populated -->
          </div>
          ${isHostOrCoHost ? `
            <div style="padding: 12px 16px; border-top: 1px solid var(--border-subtle); display: flex; flex-direction: column; gap: 8px; background: rgba(0,0,0,0.2);">
              <div style="font-size: 0.72rem; color: var(--text-muted); font-weight: 700; text-transform: uppercase;">Host Moderation Controls</div>
              <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 8px;">
                <button class="btn btn-secondary btn-sm" style="color: var(--color-warning);" onclick="window.meetingRoom.hostMuteAll()">
                  🔇 Mute All
                </button>
                <button id="btnHostLockToggle" class="btn btn-secondary btn-sm" style="color: var(--accent-cyan);" onclick="window.meetingRoom.hostToggleLock()">
                  ${this.meeting.is_locked ? '🔓 Unlock' : '🔒 Lock'} Room
                </button>
              </div>
            </div>
          ` : ''}
        </div>
      </div>

      <!-- Bottom Control Bar -->
      <div class="meeting-room-controls">
        <!-- Mic Toggle -->
        <button id="btnToggleMic" class="meeting-ctrl-btn" title="Toggle Microphone" onclick="window.meetingRoom.toggleMicrophone()">
          🎙️
        </button>

        <!-- Camera Toggle -->
        <button id="btnToggleCam" class="meeting-ctrl-btn" title="Toggle Camera" onclick="window.meetingRoom.toggleCamera()">
          📹
        </button>

        <!-- Screen Share (Spotlight Stage) -->
        <button id="btnToggleScreen" class="meeting-ctrl-btn" title="Share Screen" onclick="window.meetingRoom.toggleScreenShare()">
          🖥️
        </button>

        <!-- Recording (Phase 4) -->
        <button id="btnToggleRecord" class="meeting-ctrl-btn" title="Start/Stop Recording" onclick="window.meetingRoom.toggleRecording()">
          ⏺️
        </button>

        <!-- Hand Raise (Phase 3) -->
        <button id="btnToggleHand" class="meeting-ctrl-btn" title="Raise Hand (Ask to speak)" onclick="window.meetingRoom.toggleHandRaise()">
          ✋
        </button>

        <!-- Chat Drawer Toggle -->
        <button id="btnToggleChat" class="meeting-ctrl-btn" title="Meeting Chat" onclick="window.meetingRoom.toggleChatDrawer()">
          💬
          <span id="meetingUnreadBadge" class="meeting-ctrl-badge" style="display: none;">0</span>
        </button>

        <!-- Participants Drawer Toggle -->
        <button id="btnToggleParticipants" class="meeting-ctrl-btn" title="Participants List" onclick="window.meetingRoom.toggleParticipantsDrawer()">
          👥
        </button>

        <!-- Host End Meeting (if host) -->
        ${this.role === 'host' || this.meeting.host_id === this.currentUser?.id ? `
          <button class="meeting-ctrl-btn" style="color: var(--color-danger); border-color: rgba(239, 68, 68, 0.4);" title="End Meeting for Everyone" onclick="window.meetingRoom.hostEndMeeting()">
            🛑
          </button>
        ` : ''}

        <!-- Leave Call Button -->
        <button class="meeting-ctrl-btn end-call" title="Leave Meeting" onclick="window.meetingRoom.leaveRoom()">
          Leave 📞
        </button>
      </div>

      <!-- Meeting Information Modal -->
      <div id="meetingInfoModal" class="modal-overlay" style="z-index: 2600;">
        <div class="modal-content" style="max-width: 480px;">
          <div class="modal-header">
            <h3 class="modal-title">Meeting Information</h3>
            <button class="modal-close-btn" onclick="window.meetingRoom.toggleMeetingInfo()">&times;</button>
          </div>
          <div class="modal-body">
            <div style="font-size: 0.8rem; color: var(--text-muted); text-transform: uppercase;">Title</div>
            <h3 style="margin-bottom: 12px;">${this.meeting.title || 'CONNEKT Meeting'}</h3>

            <div class="grid-2" style="margin-bottom: 16px;">
              <div class="card" style="padding: 10px;">
                <div style="font-size: 0.72rem; color: var(--text-muted);">ROOM CODE</div>
                <div style="font-family: monospace; font-weight: 700; color: var(--accent-cyan); font-size: 1.05rem;">CNK-${this.roomCode}</div>
              </div>
              <div class="card" style="padding: 10px;">
                <div style="font-size: 0.72rem; color: var(--text-muted);">STATUS</div>
                <div style="font-weight: 700; color: #10b981; font-size: 1rem;">Active / Live</div>
              </div>
            </div>

            <div class="form-group">
              <label class="form-label">Shareable Link</label>
              <div style="display: flex; gap: 8px;">
                <input type="text" readonly value="${window.location.origin}/meet/${this.roomCode}" class="form-control" style="font-size: 0.85rem;" />
                <button class="btn btn-secondary" onclick="window.meetingRoom.copyInviteLink()">Copy</button>
              </div>
            </div>

            ${this.meeting.agenda ? `
              <div class="form-group">
                <label class="form-label">Meeting Agenda</label>
                <div style="font-size: 0.88rem; color: var(--text-secondary); background: var(--bg-input); padding: 8px 12px; border-radius: var(--radius-sm); border: 1px solid var(--border-subtle);">
                  ${this.escapeHtml(this.meeting.agenda)}
                </div>
              </div>
            ` : ''}
          </div>
          <div class="modal-footer">
            <button class="btn btn-primary" onclick="window.meetingRoom.toggleMeetingInfo()">Done</button>
          </div>
        </div>
      </div>
    `;

    document.body.appendChild(overlay);
  }

  /**
   * Capture local media (Camera + Microphone with audio-only fallback)
   */
  async initLocalMedia() {
    if (this.localStream) {
      this.localStream.getTracks().forEach(t => t.stop());
    }

    let stream = null;
    let cameraAvailable = true;

    try {
      stream = await navigator.mediaDevices.getUserMedia({
        audio: {
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true
        },
        video: {
          width: { ideal: 1280 },
          height: { ideal: 720 }
        }
      });
    } catch (err) {
      console.warn('[WebRTC] Audio+Video getUserMedia failed, attempting audio-only fallback:', err.message);
      cameraAvailable = false;
    }

    if (!stream) {
      try {
        stream = await navigator.mediaDevices.getUserMedia({
          audio: {
            echoCancellation: true,
            noiseSuppression: true,
            autoGainControl: true
          }
        });
        window.app?.showToast('Camera unavailable. Joined with audio-only.', 'info');
      } catch (audioErr) {
        console.error('[WebRTC] Microphone unavailable or permission denied:', audioErr.message);
        window.app?.showToast('Microphone access denied or unavailable.', 'warning');
        stream = new MediaStream();
        cameraAvailable = false;
      }
    }

    this.localStream = stream;
    this.isCameraOn = cameraAvailable && stream.getVideoTracks().length > 0;
    this.isMicOn = stream.getAudioTracks().length > 0 && stream.getAudioTracks()[0].enabled;

    const videoEl = document.getElementById('localVideoEl');
    const placeholder = document.getElementById('localAvatarPlaceholder');
    if (videoEl) {
      videoEl.srcObject = stream;
      if (!this.isCameraOn && placeholder) {
        videoEl.style.display = 'none';
        placeholder.style.display = 'flex';
      }
    }

    this.updateControlsUI();
    return stream;
  }

  /**
   * Set up Socket.IO signaling events
   */
  setupSignaling() {
    let socket = window.socket;
    if (!socket || !socket.connected) {
      const token = window.api?.getToken();
      socket = io({
        auth: { token },
        query: { token }
      });
      window.socket = socket;
    }

    this.socket = socket;

    // 1. Join room
    socket.emit('meeting:join-room', {
      roomCode: this.roomCode,
      user: {
        id: this.currentUser?.id,
        username: this.currentUser?.username,
        name: this.currentUser?.personalProfile?.fullName || this.currentUser?.username,
        role: this.role,
        isMicOn: this.isMicOn,
        isCameraOn: this.isCameraOn
      }
    });

    // 2. Receive list of existing peers in the room
    socket.off('meeting:all-peers');
    socket.on('meeting:all-peers', async ({ peers }) => {
      console.log(`[Signaling] Existing peers in room:`, peers);
      for (const peer of peers) {
        if (peer.socketId !== socket.id) {
          this.connectedPeers.set(peer.socketId, peer);
          await this.initiatePeerConnection(peer.socketId);
        }
      }
      this.updateVideoGridLayout();
      this.updateParticipantsDrawer();
    });

    // 3. Receive new peer joined notification
    socket.off('meeting:peer-joined');
    socket.on('meeting:peer-joined', async ({ peer }) => {
      console.log(`[Signaling] New peer joined room:`, peer);
      if (peer.socketId !== socket.id) {
        this.connectedPeers.set(peer.socketId, peer);
        this.getOrCreatePeerConnection(peer.socketId);
        this.updateVideoGridLayout();
        this.updateParticipantsDrawer();
        window.app?.showToast(`${peer.name || peer.username} joined the meeting`, 'info');
      }
    });

    // 4. Handle incoming WebRTC signals (Offer, Answer, Candidate)
    socket.off('meeting:signal');
    socket.on('meeting:signal', async ({ senderSocketId, signal, type }) => {
      await this.handleIncomingSignal(senderSocketId, signal, type);
    });

    // 5. Handle peer media state changes
    socket.off('meeting:peer-media-status');
    socket.on('meeting:peer-media-status', ({ socketId, isMicOn, isCameraOn, isScreenSharing }) => {
      const peer = this.connectedPeers.get(socketId);
      if (peer) {
        if (isMicOn !== undefined) peer.isMicOn = isMicOn;
        if (isCameraOn !== undefined) peer.isCameraOn = isCameraOn;
        if (isScreenSharing !== undefined) peer.isScreenSharing = isScreenSharing;
        this.updateRemoteTileUI(socketId);
      }
      this.syncSpotlightState();
    });

    // 6. Handle peer hand raising (Phase 3)
    socket.off('meeting:peer-hand-raise');
    socket.on('meeting:peer-hand-raise', ({ socketId, name, isHandRaised }) => {
      const peer = this.connectedPeers.get(socketId);
      if (peer) {
        peer.isHandRaised = !!isHandRaised;
      }

      const tile = document.getElementById(`tile-${socketId}`);
      if (tile) {
        let badge = tile.querySelector('.hand-raise-badge');
        if (isHandRaised) {
          if (!badge) {
            badge = document.createElement('div');
            badge.className = 'hand-raise-badge';
            badge.textContent = '✋';
            tile.appendChild(badge);
          }
          badge.style.display = 'flex';
        } else if (badge) {
          badge.style.display = 'none';
        }
      }

      if (isHandRaised) {
        window.app?.showToast(`${name || 'A participant'} raised their hand ✋`, 'info');
      }
      this.updateParticipantsDrawer();
    });

    // 7. Handle peer role updates (Phase 3 Co-Host promotion)
    socket.off('meeting:peer-role-updated');
    socket.on('meeting:peer-role-updated', ({ userId, socketId, role }) => {
      if (userId === this.currentUser?.id) {
        this.role = role;
        window.app?.showToast(`You are now a ${role.toUpperCase()} of this meeting!`, 'success');
        this.renderMeetingRoomDOM();
        this.updateControlsUI();
      }

      if (socketId && this.connectedPeers.has(socketId)) {
        this.connectedPeers.get(socketId).role = role;
      }
      this.updateParticipantsDrawer();
    });

    // 8. Handle in-meeting chat message
    socket.off('meeting:new-chat-message');
    socket.on('meeting:new-chat-message', (msg) => {
      this.chatMessages.push(msg);
      this.renderChatMessage(msg);
      if (!this.isChatDrawerOpen) {
        this.unreadChatCount++;
        const badge = document.getElementById('meetingUnreadBadge');
        if (badge) {
          badge.textContent = this.unreadChatCount;
          badge.style.display = 'flex';
        }
      }
    });

    // 9. Handle host actions
    socket.off('meeting:host-action');
    socket.on('meeting:host-action', async ({ action, isLocked }) => {
      console.log(`[Signaling] Host action received: ${action}`);
      if (action === 'mute-all' && this.role !== 'host' && this.role !== 'co-host') {
        if (this.isMicOn) {
          this.toggleMicrophone(false);
          window.app?.showToast('The host muted all participants.', 'info');
        }
      } else if (action === 'mute-peer') {
        if (this.isMicOn) {
          this.toggleMicrophone(false);
          window.app?.showToast('You were muted by the host.', 'warning');
        }
      } else if (action === 'lower-hand') {
        if (this.isHandRaised) {
          this.isHandRaised = false;
          this.updateHandUI();
          window.app?.showToast('Your hand was lowered by the host.', 'info');
        }
      } else if (action === 'promoted-cohost') {
        this.role = 'co-host';
        window.app?.showToast('You have been promoted to Co-Host!', 'success');
        this.updateParticipantsDrawer();
      } else if (action === 'ended') {
        window.app?.showToast('The meeting was ended by the host.', 'warning');
        this.leaveRoom(false);
      } else if (action === 'kicked') {
        window.app?.showToast('You were removed from the meeting by the host.', 'warning');
        this.leaveRoom(false);
      } else if (action === 'locked') {
        this.meeting.is_locked = true;
        const lockBadge = document.getElementById('meetingLockBadge');
        if (lockBadge) lockBadge.style.display = 'inline-block';
        window.app?.showToast('The host locked this meeting room.', 'info');
      } else if (action === 'unlocked') {
        this.meeting.is_locked = false;
        const lockBadge = document.getElementById('meetingLockBadge');
        if (lockBadge) lockBadge.style.display = 'none';
        window.app?.showToast('The meeting room has been unlocked.', 'info');
      }
    });

    // 10. Handle peer left / disconnected
    socket.off('meeting:peer-left');
    socket.on('meeting:peer-left', ({ socketId, name, username }) => {
      console.log(`[Signaling] Peer left: ${name || username} (${socketId})`);
      this.cleanupPeer(socketId);
      window.app?.showToast(`${name || username || 'Participant'} left the meeting`, 'info');
    });

    // 11. Handle recording status (Phase 4)
    socket.off('meeting:recording-status');
    socket.on('meeting:recording-status', ({ isRecording, startedBy }) => {
      const pill = document.getElementById('meetingRecPill');
      if (pill) {
        pill.style.display = isRecording ? 'inline-flex' : 'none';
      }
      if (isRecording) {
        window.app?.showToast(`Meeting recording was started by ${startedBy}.`, 'info');
      } else {
        window.app?.showToast('Meeting recording has stopped.', 'info');
      }
    });

    this.startRestSignalPolling();
  }

  /**
   * Get existing RTCPeerConnection or create a new one
   */
  getOrCreatePeerConnection(peerSocketId) {
    if (this.peerConnections.has(peerSocketId)) {
      const existing = this.peerConnections.get(peerSocketId);
      if (existing.connectionState !== 'closed' && existing.connectionState !== 'failed') {
        return existing;
      }
      try { existing.close(); } catch (_) {}
    }

    const pc = new RTCPeerConnection(this.rtcConfig);
    this.peerConnections.set(peerSocketId, pc);

    // 1. Add local media tracks
    const activeStream = this.screenStream || this.localStream;
    if (activeStream) {
      activeStream.getTracks().forEach(track => {
        try {
          pc.addTrack(track, activeStream);
        } catch (e) {
          console.warn(`[WebRTC] Add track failed for peer ${peerSocketId}:`, e.message);
        }
      });
    }

    // Ensure bidirectional transceivers
    const audioTransceiver = pc.getTransceivers().find(t => t.receiver?.track?.kind === 'audio');
    if (!audioTransceiver) {
      try { pc.addTransceiver('audio', { direction: 'sendrecv' }); } catch (_) {}
    }
    const videoTransceiver = pc.getTransceivers().find(t => t.receiver?.track?.kind === 'video');
    if (!videoTransceiver) {
      try { pc.addTransceiver('video', { direction: 'sendrecv' }); } catch (_) {}
    }

    // 2. ICE candidate event -> send to remote peer
    pc.onicecandidate = (event) => {
      if (event.candidate && this.socket) {
        this.socket.emit('meeting:signal', {
          roomCode: this.roomCode,
          targetSocketId: peerSocketId,
          signal: event.candidate.toJSON ? event.candidate.toJSON() : event.candidate,
          type: 'candidate'
        });
      }
    };

    // 3. Track received from remote peer -> render in video & audio
    pc.ontrack = (event) => {
      console.log(`[WebRTC] Received remote track (${event.track.kind}) from peer ${peerSocketId}`);
      let stream = this.remoteStreams.get(peerSocketId);
      if (!stream) {
        stream = new MediaStream();
        this.remoteStreams.set(peerSocketId, stream);
      }

      if (!stream.getTracks().some(t => t.id === event.track.id)) {
        stream.addTrack(event.track);
      }

      if (event.track.kind === 'audio') {
        this.attachRemoteAudio(peerSocketId, event.track);
      }

      this.renderRemoteTile(peerSocketId, stream);
    };

    pc.onconnectionstatechange = () => {
      console.log(`[WebRTC] Peer ${peerSocketId} connectionState: ${pc.connectionState}`);
      if (pc.connectionState === 'failed' || pc.connectionState === 'closed') {
        this.cleanupPeer(peerSocketId);
      }
    };

    return pc;
  }

  /**
   * Initiate WebRTC offer to a remote peer
   */
  async initiatePeerConnection(peerSocketId) {
    try {
      const pc = this.getOrCreatePeerConnection(peerSocketId);
      const offer = await pc.createOffer({
        offerToReceiveAudio: true,
        offerToReceiveVideo: true
      });
      await pc.setLocalDescription(offer);

      this.socket.emit('meeting:signal', {
        roomCode: this.roomCode,
        targetSocketId: peerSocketId,
        signal: offer,
        type: 'offer'
      });
    } catch (err) {
      console.error(`[WebRTC] Failed to create offer for peer ${peerSocketId}:`, err);
    }
  }

  /**
   * Handle incoming WebRTC signal (Offer, Answer, Candidate)
   */
  async handleIncomingSignal(senderSocketId, signal, type) {
    if (!signal) return;
    const pc = this.getOrCreatePeerConnection(senderSocketId);

    try {
      if (type === 'offer' || signal.type === 'offer') {
        await pc.setRemoteDescription(new RTCSessionDescription(signal));

        if (this.pendingCandidates.has(senderSocketId)) {
          const candidates = this.pendingCandidates.get(senderSocketId);
          for (const cand of candidates) {
            try { await pc.addIceCandidate(new RTCIceCandidate(cand)); } catch (_) {}
          }
          this.pendingCandidates.delete(senderSocketId);
        }

        const answer = await pc.createAnswer();
        await pc.setLocalDescription(answer);

        this.socket.emit('meeting:signal', {
          roomCode: this.roomCode,
          targetSocketId: senderSocketId,
          signal: answer,
          type: 'answer'
        });
      } else if (type === 'answer' || signal.type === 'answer') {
        await pc.setRemoteDescription(new RTCSessionDescription(signal));

        if (this.pendingCandidates.has(senderSocketId)) {
          const candidates = this.pendingCandidates.get(senderSocketId);
          for (const cand of candidates) {
            try { await pc.addIceCandidate(new RTCIceCandidate(cand)); } catch (_) {}
          }
          this.pendingCandidates.delete(senderSocketId);
        }
      } else if (type === 'candidate' || signal.candidate) {
        const candData = signal.candidate ? signal : { candidate: signal.candidate, sdpMid: signal.sdpMid, sdpMLineIndex: signal.sdpMLineIndex };
        if (pc.remoteDescription && pc.remoteDescription.type) {
          await pc.addIceCandidate(new RTCIceCandidate(candData));
        } else {
          if (!this.pendingCandidates.has(senderSocketId)) {
            this.pendingCandidates.set(senderSocketId, []);
          }
          this.pendingCandidates.get(senderSocketId).push(candData);
        }
      }
    } catch (err) {
      console.warn(`[WebRTC] Error handling signal from ${senderSocketId}:`, err.message);
    }
  }

  /**
   * Persistent hidden container for remote audio playback
   */
  ensureAudioContainer() {
    let container = document.getElementById('connekt-audio-container');
    if (!container) {
      container = document.createElement('div');
      container.id = 'connekt-audio-container';
      container.style.cssText = 'position:fixed;top:-9999px;left:-9999px;width:1px;height:1px;opacity:0.001;pointer-events:none;z-index:-9999;';
      document.body.appendChild(container);
    }
    return container;
  }

  /**
   * Dedicated HTML5 Audio element for remote audio stream to guarantee autoplay
   */
  attachRemoteAudio(peerSocketId, audioTrack) {
    if (!audioTrack || audioTrack.kind !== 'audio') return;
    const container = this.ensureAudioContainer();

    let audioEl = document.getElementById(`remote-audio-${peerSocketId}`);
    if (!audioEl) {
      audioEl = document.createElement('audio');
      audioEl.id = `remote-audio-${peerSocketId}`;
      audioEl.autoplay = true;
      audioEl.playsInline = true;
      audioEl.muted = false;
      container.appendChild(audioEl);
    }

    const audioStream = new MediaStream([audioTrack]);
    audioEl.srcObject = audioStream;
    audioEl.play().catch(e => console.warn(`[Audio] Autoplay waiting for user gesture for peer ${peerSocketId}:`, e.message));
  }

  /**
   * Render or update remote participant video tile in grid
   */
  renderRemoteTile(peerSocketId, stream) {
    const grid = document.getElementById('meetingVideoGrid');
    if (!grid) return;

    let tile = document.getElementById(`tile-${peerSocketId}`);
    const peer = this.connectedPeers.get(peerSocketId) || { name: 'Participant', username: 'peer' };

    if (!tile) {
      tile = document.createElement('div');
      tile.id = `tile-${peerSocketId}`;
      tile.className = 'meeting-video-tile';
      tile.innerHTML = `
        <div class="hand-raise-badge" style="display: ${peer.isHandRaised ? 'flex' : 'none'};">✋</div>
        <video id="video-${peerSocketId}" autoplay playsinline></video>
        <div id="avatar-${peerSocketId}" class="meeting-avatar-placeholder" style="display: none;">
          <div class="meeting-avatar-circle">
            ${(peer.name || peer.username || 'P')[0].toUpperCase()}
          </div>
          <div style="font-size: 0.9rem; font-weight: 600; color: var(--text-primary);">${peer.name || peer.username}</div>
        </div>
        <div class="meeting-tile-overlay">
          <div class="meeting-name-pill">
            <span>${peer.name || peer.username}</span>
            <span id="mic-icon-${peerSocketId}">🎙️</span>
          </div>
        </div>
      `;
      grid.appendChild(tile);
    }

    const videoEl = tile.querySelector('video');
    if (videoEl && videoEl.srcObject !== stream) {
      videoEl.srcObject = stream;
      videoEl.play().catch(() => {});
    }

    this.updateRemoteTileUI(peerSocketId);
    this.updateVideoGridLayout();
  }

  /**
   * Update visual states for remote tile
   */
  updateRemoteTileUI(peerSocketId) {
    const tile = document.getElementById(`tile-${peerSocketId}`);
    if (!tile) return;

    const peer = this.connectedPeers.get(peerSocketId);
    const videoEl = tile.querySelector('video');
    const avatar = tile.querySelector('.meeting-avatar-placeholder');
    const micIcon = document.getElementById(`mic-icon-${peerSocketId}`);
    const handBadge = tile.querySelector('.hand-raise-badge');

    if (peer) {
      if (micIcon) micIcon.textContent = peer.isMicOn ? '🎙️' : '🔇';
      if (handBadge) handBadge.style.display = peer.isHandRaised ? 'flex' : 'none';

      if (videoEl && avatar) {
        if (!peer.isCameraOn && !peer.isScreenSharing) {
          videoEl.style.display = 'none';
          avatar.style.display = 'flex';
        } else {
          videoEl.style.display = 'block';
          avatar.style.display = 'none';
        }
      }
    }
  }

  /**
   * Phase 3 Screen Sharing Spotlight synchronization
   */
  syncSpotlightState() {
    const grid = document.getElementById('meetingVideoGrid');
    const banner = document.getElementById('screenShareIndicator');
    if (!grid) return;

    // Check if anyone is sharing screen
    let presenter = null;
    if (this.isScreenSharing) {
      presenter = {
        name: this.currentUser?.personalProfile?.fullName || this.currentUser?.username || 'You',
        isLocal: true
      };
    } else {
      for (const [socketId, peer] of this.connectedPeers.entries()) {
        if (peer.isScreenSharing) {
          presenter = {
            id: socketId,
            name: peer.name || peer.username || 'Participant',
            isLocal: false
          };
          break;
        }
      }
    }

    this.activePresenter = presenter;

    if (presenter) {
      grid.classList.add('spotlight-active');
      if (banner) {
        banner.textContent = `🖥️ ${presenter.isLocal ? 'You are sharing your screen' : `${presenter.name} is presenting to everyone`}`;
        banner.style.display = 'inline-flex';
      }

      // Mark the active tile with spotlight class
      document.querySelectorAll('.meeting-video-tile').forEach(t => t.classList.remove('spotlight'));
      if (presenter.isLocal) {
        document.getElementById('localVideoTile')?.classList.add('spotlight');
      } else if (presenter.id) {
        document.getElementById(`tile-${presenter.id}`)?.classList.add('spotlight');
      }
    } else {
      grid.classList.remove('spotlight-active');
      document.querySelectorAll('.meeting-video-tile').forEach(t => t.classList.remove('spotlight'));
      if (banner) banner.style.display = 'none';
    }
  }

  /**
   * Adjust video grid layout based on total participant count
   */
  updateVideoGridLayout() {
    const grid = document.getElementById('meetingVideoGrid');
    if (!grid) return;

    const totalCount = 1 + this.connectedPeers.size;
    grid.setAttribute('data-count', Math.min(6, totalCount));

    const pCountBadge = document.getElementById('meetingParticipantsCount');
    if (pCountBadge) pCountBadge.textContent = totalCount;

    this.syncSpotlightState();
  }

  /**
   * Phase 3 Hand Raising Toggle
   */
  toggleHandRaise() {
    this.isHandRaised = !this.isHandRaised;
    this.updateHandUI();

    this.socket?.emit('meeting:hand-raise', {
      roomCode: this.roomCode,
      isHandRaised: this.isHandRaised
    });

    window.app?.showToast(this.isHandRaised ? 'Hand raised ✋' : 'Hand lowered', 'info');
  }

  updateHandUI() {
    const handBadge = document.getElementById('localHandBadge');
    const handBtn = document.getElementById('btnToggleHand');

    if (handBadge) handBadge.style.display = this.isHandRaised ? 'flex' : 'none';
    if (handBtn) {
      handBtn.classList.toggle('hand-raised', this.isHandRaised);
      handBtn.innerHTML = this.isHandRaised ? '✋' : '✋';
    }
    this.updateParticipantsDrawer();
  }

  /**
   * Toggle local microphone
   */
  toggleMicrophone(forceState = null) {
    if (!this.localStream) return;
    const audioTrack = this.localStream.getAudioTracks()[0];
    if (!audioTrack) {
      window.app?.showToast('No audio track available.', 'warning');
      return;
    }

    this.isMicOn = forceState !== null ? forceState : !this.isMicOn;
    audioTrack.enabled = this.isMicOn;

    const localMicIcon = document.getElementById('localMicIcon');
    if (localMicIcon) localMicIcon.textContent = this.isMicOn ? '🎙️' : '🔇';

    this.updateControlsUI();

    this.socket?.emit('meeting:media-status', {
      roomCode: this.roomCode,
      isMicOn: this.isMicOn,
      isCameraOn: this.isCameraOn,
      isScreenSharing: this.isScreenSharing
    });
  }

  /**
   * Toggle local camera
   */
  async toggleCamera() {
    if (!this.localStream) return;
    const videoTrack = this.localStream.getVideoTracks()[0];

    if (!videoTrack) {
      try {
        const camStream = await navigator.mediaDevices.getUserMedia({ video: true });
        const newTrack = camStream.getVideoTracks()[0];
        this.localStream.addTrack(newTrack);
        this.isCameraOn = true;

        this.peerConnections.forEach(pc => {
          const sender = pc.getSenders().find(s => s.track && s.track.kind === 'video');
          if (sender) sender.replaceTrack(newTrack).catch(() => {});
          else pc.addTrack(newTrack, this.localStream);
        });

        const videoEl = document.getElementById('localVideoEl');
        if (videoEl) videoEl.srcObject = this.localStream;
      } catch (e) {
        window.app?.showToast('Unable to start camera.', 'warning');
        return;
      }
    } else {
      this.isCameraOn = !this.isCameraOn;
      videoTrack.enabled = this.isCameraOn;
    }

    const videoEl = document.getElementById('localVideoEl');
    const placeholder = document.getElementById('localAvatarPlaceholder');
    if (videoEl && placeholder) {
      if (this.isCameraOn) {
        videoEl.style.display = 'block';
        placeholder.style.display = 'none';
      } else {
        videoEl.style.display = 'none';
        placeholder.style.display = 'flex';
      }
    }

    this.updateControlsUI();

    this.socket?.emit('meeting:media-status', {
      roomCode: this.roomCode,
      isMicOn: this.isMicOn,
      isCameraOn: this.isCameraOn,
      isScreenSharing: this.isScreenSharing
    });
  }

  /**
   * Toggle Screen Sharing
   */
  async toggleScreenShare() {
    if (this.isScreenSharing) {
      this.stopScreenSharing();
    } else {
      try {
        const screenStream = await navigator.mediaDevices.getDisplayMedia({
          video: true,
          audio: true
        });

        this.screenStream = screenStream;
        this.isScreenSharing = true;

        const screenTrack = screenStream.getVideoTracks()[0];
        const videoEl = document.getElementById('localVideoEl');
        if (videoEl) {
          videoEl.srcObject = screenStream;
          videoEl.classList.add('screen-share');
        }

        this.peerConnections.forEach(pc => {
          const sender = pc.getSenders().find(s => s.track && s.track.kind === 'video');
          if (sender) {
            sender.replaceTrack(screenTrack).catch(() => {});
          }
        });

        screenTrack.onended = () => {
          this.stopScreenSharing();
        };

        this.updateControlsUI();
        this.syncSpotlightState();

        this.socket?.emit('meeting:media-status', {
          roomCode: this.roomCode,
          isMicOn: this.isMicOn,
          isCameraOn: this.isCameraOn,
          isScreenSharing: true
        });

        window.app?.showToast('Screen sharing started.', 'info');
      } catch (err) {
        console.warn('Screen share cancelled or failed:', err);
      }
    }
  }

  /**
   * Stop screen sharing and restore camera
   */
  stopScreenSharing() {
    if (this.screenStream) {
      this.screenStream.getTracks().forEach(t => t.stop());
      this.screenStream = null;
    }
    this.isScreenSharing = false;

    const cameraTrack = this.localStream ? this.localStream.getVideoTracks()[0] : null;
    const videoEl = document.getElementById('localVideoEl');
    if (videoEl) {
      videoEl.classList.remove('screen-share');
      videoEl.srcObject = this.localStream;
      if (!this.isCameraOn) videoEl.style.display = 'none';
    }

    if (cameraTrack) {
      this.peerConnections.forEach(pc => {
        const sender = pc.getSenders().find(s => s.track && s.track.kind === 'video');
        if (sender) {
          sender.replaceTrack(cameraTrack).catch(() => {});
        }
      });
    }

    this.updateControlsUI();
    this.syncSpotlightState();

    this.socket?.emit('meeting:media-status', {
      roomCode: this.roomCode,
      isMicOn: this.isMicOn,
      isCameraOn: this.isCameraOn,
      isScreenSharing: false
    });

    window.app?.showToast('Screen sharing stopped.', 'info');
  }

  /**
   * Update bottom control bar buttons active/off states
   */
  updateControlsUI() {
    const micBtn = document.getElementById('btnToggleMic');
    const camBtn = document.getElementById('btnToggleCam');
    const screenBtn = document.getElementById('btnToggleScreen');
    const handBtn = document.getElementById('btnToggleHand');

    if (micBtn) {
      micBtn.classList.toggle('off', !this.isMicOn);
      micBtn.innerHTML = this.isMicOn ? '🎙️' : '🔇';
    }
    if (camBtn) {
      camBtn.classList.toggle('off', !this.isCameraOn);
      camBtn.innerHTML = this.isCameraOn ? '📹' : '🚫';
    }
    if (screenBtn) {
      screenBtn.classList.toggle('active', this.isScreenSharing);
    }
    if (handBtn) {
      handBtn.classList.toggle('hand-raised', this.isHandRaised);
    }
  }

  /**
   * Toggle In-Meeting Chat Drawer
   */
  toggleChatDrawer() {
    const drawer = document.getElementById('meetingChatDrawer');
    if (!drawer) return;

    this.isChatDrawerOpen = !this.isChatDrawerOpen;
    drawer.style.display = this.isChatDrawerOpen ? 'flex' : 'none';

    if (this.isChatDrawerOpen) {
      if (this.isParticipantsDrawerOpen) this.toggleParticipantsDrawer();
      this.unreadChatCount = 0;
      const badge = document.getElementById('meetingUnreadBadge');
      if (badge) badge.style.display = 'none';
      const input = document.getElementById('meetingChatInput');
      if (input) input.focus();
    }
  }

  /**
   * Export meeting chat transcript as a downloadable text file (Phase 3)
   */
  exportChatHistory() {
    if (!this.chatMessages || this.chatMessages.length === 0) {
      window.app?.showToast('No chat messages to export yet.', 'warning');
      return;
    }

    let transcript = `====================================================\n`;
    transcript += `CONNEKT Meeting Chat Transcript\n`;
    transcript += `Meeting: ${this.meeting.title || 'CONNEKT Meeting'}\n`;
    transcript += `Room Code: CNK-${this.roomCode}\n`;
    transcript += `Date: ${new Date().toLocaleString()}\n`;
    transcript += `====================================================\n\n`;

    this.chatMessages.forEach(m => {
      const time = m.createdAt || m.created_at ? new Date(m.createdAt || m.created_at).toLocaleTimeString() : '';
      transcript += `[${time}] ${m.senderName || 'Participant'}: ${m.message}\n`;
    });

    const blob = new Blob([transcript], { type: 'text/plain;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `connekt-chat-${this.roomCode}.txt`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);

    window.app?.showToast('Meeting chat transcript exported!', 'success');
  }

  /**
   * Toggle Participants Drawer
   */
  toggleParticipantsDrawer() {
    const drawer = document.getElementById('meetingParticipantsDrawer');
    if (!drawer) return;

    this.isParticipantsDrawerOpen = !this.isParticipantsDrawerOpen;
    drawer.style.display = this.isParticipantsDrawerOpen ? 'flex' : 'none';

    if (this.isParticipantsDrawerOpen) {
      if (this.isChatDrawerOpen) this.toggleChatDrawer();
      this.updateParticipantsDrawer();
    }
  }

  /**
   * Update Participants Drawer UI with Phase 3 Moderation Tools
   */
  updateParticipantsDrawer() {
    const list = document.getElementById('meetingParticipantsList');
    if (!list) return;

    const myName = this.currentUser?.personalProfile?.fullName || this.currentUser?.username || 'You';
    const isMeHost = this.role === 'host' || this.role === 'co-host' || this.meeting.host_id === this.currentUser?.id;

    let html = `
      <div style="display: flex; align-items: center; justify-content: space-between; padding: 10px 12px; background: var(--bg-input); border-radius: 8px;">
        <div style="display: flex; align-items: center; gap: 10px;">
          <div style="width: 28px; height: 28px; border-radius: 50%; background: var(--grad-primary); display: flex; align-items: center; justify-content: center; font-size: 0.8rem; font-weight: 700; color: white;">
            ${myName[0].toUpperCase()}
          </div>
          <div>
            <div style="font-size: 0.88rem; font-weight: 600;">${myName} (You)</div>
            <div style="font-size: 0.72rem; color: var(--text-muted); text-transform: capitalize;">${this.role}</div>
          </div>
        </div>
        <div style="display: flex; align-items: center; gap: 6px;">
          ${this.isHandRaised ? '<span title="Hand Raised">✋</span>' : ''}
          <span>${this.isMicOn ? '🎙️' : '🔇'}</span>
          <span>${this.isCameraOn ? '📹' : '🚫'}</span>
        </div>
      </div>
    `;

    this.connectedPeers.forEach((peer, socketId) => {
      html += `
        <div style="display: flex; flex-direction: column; gap: 6px; padding: 10px 12px; background: var(--bg-card); border-radius: 8px; border: 1px solid var(--border-subtle);">
          <div style="display: flex; align-items: center; justify-content: space-between;">
            <div style="display: flex; align-items: center; gap: 10px;">
              <div style="width: 28px; height: 28px; border-radius: 50%; background: #3b82f6; display: flex; align-items: center; justify-content: center; font-size: 0.8rem; font-weight: 700; color: white;">
                ${(peer.name || peer.username || 'P')[0].toUpperCase()}
              </div>
              <div>
                <div style="font-size: 0.88rem; font-weight: 600;">${peer.name || peer.username}</div>
                <div style="font-size: 0.72rem; color: var(--text-muted); text-transform: capitalize;">${peer.role || 'Participant'}</div>
              </div>
            </div>
            <div style="display: flex; align-items: center; gap: 6px;">
              ${peer.isHandRaised ? '<span title="Hand Raised" style="font-size: 1.1rem;">✋</span>' : ''}
              <span>${peer.isMicOn ? '🎙️' : '🔇'}</span>
              <span>${peer.isCameraOn ? '📹' : '🚫'}</span>
              ${peer.isScreenSharing ? '<span>🖥️</span>' : ''}
            </div>
          </div>

          ${isMeHost ? `
            <div style="display: flex; gap: 6px; align-items: center; justify-content: flex-end; margin-top: 4px; padding-top: 6px; border-top: 1px solid rgba(255,255,255,0.05);">
              ${peer.isHandRaised ? `
                <button class="participant-mod-btn" onclick="window.meetingRoom.hostLowerHand('${socketId}')">✋ Lower Hand</button>
              ` : ''}
              <button class="participant-mod-btn" onclick="window.meetingRoom.hostMutePeer('${socketId}')">🔇 Mute</button>
              ${peer.role !== 'host' && peer.role !== 'co-host' ? `
                <button class="participant-mod-btn primary" onclick="window.meetingRoom.hostPromoteCoHost('${peer.userId}', '${socketId}')">⭐ Make Co-Host</button>
              ` : ''}
              <button class="participant-mod-btn danger" onclick="window.meetingRoom.hostKickPeer('${socketId}')">Remove</button>
            </div>
          ` : ''}
        </div>
      `;
    });

    list.innerHTML = html;
  }

  /**
   * Send an in-meeting chat message
   */
  sendChatMessage() {
    const input = document.getElementById('meetingChatInput');
    if (!input) return;
    const msg = input.value.trim();
    if (!msg) return;

    input.value = '';

    this.socket?.emit('meeting:chat-message', {
      roomCode: this.roomCode,
      message: msg
    });
  }

  /**
   * Load chat history from PostgreSQL API
   */
  async loadChatHistory() {
    try {
      const res = await window.api.meetings.getChatMessages(this.roomCode);
      const messages = res.data.messages || [];
      this.chatMessages = messages;
      const list = document.getElementById('meetingChatMessagesList');
      if (list) {
        messages.forEach(m => this.renderChatMessage(m));
      }
    } catch (_) {}
  }

  /**
   * Append a chat message bubble to meeting chat drawer
   */
  renderChatMessage(msg) {
    const list = document.getElementById('meetingChatMessagesList');
    if (!list) return;

    const isMine = msg.senderId === this.currentUser?.id || msg.senderName === this.currentUser?.username;
    const time = msg.createdAt || msg.created_at ? new Date(msg.createdAt || msg.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : '';

    const div = document.createElement('div');
    div.className = `meeting-chat-bubble ${isMine ? 'mine' : 'remote'}`;
    div.innerHTML = `
      ${!isMine ? `<div style="font-size: 0.75rem; font-weight: 700; color: #60a5fa; margin-bottom: 2px;">${msg.senderName || 'Peer'}</div>` : ''}
      <div>${this.escapeHtml(msg.message)}</div>
      <div style="font-size: 0.65rem; opacity: 0.7; text-align: right; margin-top: 2px;">${time}</div>
    `;

    list.appendChild(div);
    list.scrollTop = list.scrollHeight;
  }

  /**
   * Host Control: Mute specific peer
   */
  hostMutePeer(targetSocketId) {
    this.socket?.emit('meeting:host-action', {
      roomCode: this.roomCode,
      action: 'mute-peer',
      targetSocketId
    });
    window.app?.showToast('Mute command sent to participant.', 'info');
  }

  /**
   * Host Control: Lower peer hand
   */
  hostLowerHand(targetSocketId) {
    this.socket?.emit('meeting:host-action', {
      roomCode: this.roomCode,
      action: 'lower-hand',
      targetSocketId
    });
  }

  /**
   * Host Control: Promote participant to Co-Host
   */
  hostPromoteCoHost(targetUserId, targetSocketId) {
    if (!confirm('Promote this participant to Co-Host with moderation privileges?')) return;
    this.socket?.emit('meeting:host-action', {
      roomCode: this.roomCode,
      action: 'promote-cohost',
      targetUserId,
      targetSocketId
    });
    window.app?.showToast('Promotion command sent.', 'info');
  }

  /**
   * Host Control: Mute all participants
   */
  hostMuteAll() {
    if (!confirm('Mute microphone for all participants?')) return;
    this.socket?.emit('meeting:host-action', {
      roomCode: this.roomCode,
      action: 'mute-all'
    });
    window.app?.showToast('Mute all command sent.', 'info');
  }

  /**
   * Host Control: Lock / Unlock Meeting
   */
  async hostToggleLock() {
    try {
      const nextLocked = !this.meeting.is_locked;
      await window.api.meetings.toggleLock(this.meeting.id, nextLocked);
      this.meeting.is_locked = nextLocked;

      this.socket?.emit('meeting:host-action', {
        roomCode: this.roomCode,
        action: nextLocked ? 'lock-meeting' : 'unlock-meeting'
      });

      const lockBadge = document.getElementById('meetingLockBadge');
      if (lockBadge) lockBadge.style.display = nextLocked ? 'inline-block' : 'none';

      const lockBtn = document.getElementById('btnHostLockToggle');
      if (lockBtn) lockBtn.textContent = `${nextLocked ? '🔓 Unlock' : '🔒 Lock'} Room`;

      window.app?.showToast(`Meeting room ${nextLocked ? 'locked' : 'unlocked'}.`, 'success');
    } catch (e) {
      window.app?.showToast(e.message, 'error');
    }
  }

  /**
   * Host Control: Kick peer
   */
  hostKickPeer(targetSocketId) {
    if (!confirm('Remove this participant from the meeting?')) return;
    this.socket?.emit('meeting:host-action', {
      roomCode: this.roomCode,
      action: 'kick-peer',
      targetSocketId
    });
  }

  /**
   * Host Control: End Meeting for everyone
   */
  async hostEndMeeting() {
    if (!confirm('End meeting for all participants? This will terminate all active audio/video sessions.')) return;
    try {
      this.socket?.emit('meeting:host-action', {
        roomCode: this.roomCode,
        action: 'end-meeting'
      });
      await window.api.meetings.endRoom(this.roomCode);
      this.leaveRoom(false);
    } catch (e) {
      window.app?.showToast(e.message, 'error');
    }
  }

  /**
   * Toggle Meeting Info modal
   */
  toggleMeetingInfo() {
    const modal = document.getElementById('meetingInfoModal');
    if (!modal) return;
    this.isInfoModalOpen = !this.isInfoModalOpen;
    modal.classList.toggle('active', this.isInfoModalOpen);
  }

  /**
   * Copy invite link
   */
  copyInviteLink() {
    const link = `${window.location.origin}/meet/${this.roomCode}`;
    const text = `Join my CONNEKT Meeting: "${this.meeting.title}"\nRoom Code: ${this.roomCode}\nDirect Link: ${link}`;
    window.app?.handleCopyText(text, 'Meeting invitation copied to clipboard!');
  }

  /**
   * Start call timer
   */
  startCallTimer() {
    if (this.timerInterval) clearInterval(this.timerInterval);
    this.callDurationSeconds = 0;

    this.timerInterval = setInterval(() => {
      this.callDurationSeconds++;
      const mins = String(Math.floor(this.callDurationSeconds / 60)).padStart(2, '0');
      const secs = String(this.callDurationSeconds % 60).padStart(2, '0');
      const display = document.getElementById('callDurationDisplay');
      if (display) display.textContent = `${mins}:${secs}`;
    }, 1000);
  }

  /**
   * Periodic REST signaling fallback polling
   */
  startRestSignalPolling() {
    if (this.pollingInterval) clearInterval(this.pollingInterval);
    this.pollingInterval = setInterval(async () => {
      try {
        const res = await window.api.meetings.getPendingSignals(this.roomCode);
        const signals = res.data.signals || [];
        for (const sig of signals) {
          await this.handleIncomingSignal(sig.sender_id, sig.payload, sig.signal_type);
        }
      } catch (_) {}
    }, 3000);
  }

  /**
   * Clean up a disconnected peer
   */
  cleanupPeer(peerSocketId) {
    if (this.peerConnections.has(peerSocketId)) {
      try {
        this.peerConnections.get(peerSocketId).close();
      } catch (_) {}
      this.peerConnections.delete(peerSocketId);
    }

    const tile = document.getElementById(`tile-${peerSocketId}`);
    if (tile) tile.remove();

    this.remoteStreams.delete(peerSocketId);
    const audioEl = document.getElementById(`remote-audio-${peerSocketId}`);
    if (audioEl) audioEl.remove();

    this.connectedPeers.delete(peerSocketId);
    this.pendingCandidates.delete(peerSocketId);

    this.updateVideoGridLayout();
    this.updateParticipantsDrawer();
  }

  /**
   * Leave room and clean up all resources
   */
  async leaveRoom(notifyServer = true) {
    console.log('[MeetingRoom] Leaving room and cleaning up media...');

    if (this.isRecording) {
      try {
        await this.stopRecording();
      } catch (_) {}
    }

    if (this.timerInterval) clearInterval(this.timerInterval);
    if (this.pollingInterval) clearInterval(this.pollingInterval);

    if (this.localStream) {
      this.localStream.getTracks().forEach(t => t.stop());
      this.localStream = null;
    }
    if (this.screenStream) {
      this.screenStream.getTracks().forEach(t => t.stop());
      this.screenStream = null;
    }

    this.peerConnections.forEach(pc => {
      try { pc.close(); } catch (_) {}
    });
    this.peerConnections.clear();
    this.remoteStreams.clear();
    this.connectedPeers.clear();
    this.pendingCandidates.clear();

    if (notifyServer) {
      this.socket?.emit('meeting:leave-room', { roomCode: this.roomCode });
      try {
        await window.api.meetings.leaveRoom(this.roomCode);
      } catch (_) {}
    }

    const overlay = document.getElementById('meetingRoomOverlay');
    if (overlay) overlay.remove();

    window.app?.showToast('You left the meeting.', 'info');
    window.app?.loadMeetingsList();
  }

  // ====================================================================
  // MEETING RECORDING (PHASE 4)
  // ====================================================================

  /**
   * Toggle recording on/off
   */
  async toggleRecording() {
    if (this.isRecording) {
      await this.stopRecording();
    } else {
      await this.startRecording();
    }
  }

  /**
   * Start in-meeting recording via MediaRecorder & Web Audio API
   */
  async startRecording() {
    try {
      // 1. Prepare Audio Mixing using Web Audio API
      const AudioCtx = window.AudioContext || window.webkitAudioContext;
      if (AudioCtx) {
        this.audioContext = new AudioCtx();
        this.audioDestination = this.audioContext.createMediaStreamDestination();

        // Connect local microphone stream
        if (this.localStream && this.localStream.getAudioTracks().length > 0) {
          try {
            const localSource = this.audioContext.createMediaStreamSource(this.localStream);
            localSource.connect(this.audioDestination);
          } catch (e) {
            console.warn('[Recording] Could not mix local audio:', e);
          }
        }

        // Connect all remote participant audio streams
        this.remoteStreams.forEach((stream) => {
          if (stream.getAudioTracks().length > 0) {
            try {
              const remoteSource = this.audioContext.createMediaStreamSource(stream);
              remoteSource.connect(this.audioDestination);
            } catch (e) {
              console.warn('[Recording] Could not mix remote audio:', e);
            }
          }
        });
      }

      // 2. Build Composite Video Stream
      let videoTrack = null;
      if (this.screenStream && this.screenStream.getVideoTracks().length > 0) {
        videoTrack = this.screenStream.getVideoTracks()[0];
      } else if (this.localStream && this.localStream.getVideoTracks().length > 0) {
        videoTrack = this.localStream.getVideoTracks()[0];
      }

      // Fallback: If no camera or screen track, generate a 640x360 canvas stream
      let fallbackCanvas = null;
      let canvasInterval = null;
      if (!videoTrack) {
        fallbackCanvas = document.createElement('canvas');
        fallbackCanvas.width = 640;
        fallbackCanvas.height = 360;
        const ctx = fallbackCanvas.getContext('2d');
        const updateCanvas = () => {
          ctx.fillStyle = '#0f172a';
          ctx.fillRect(0, 0, 640, 360);
          ctx.fillStyle = '#38bdf8';
          ctx.font = 'bold 24px Inter, sans-serif';
          ctx.fillText(`CONNEKT Meeting: ${this.roomCode}`, 40, 160);
          ctx.fillStyle = '#94a3b8';
          ctx.font = '16px Inter, sans-serif';
          ctx.fillText(`Recording in progress...`, 40, 200);
        };
        updateCanvas();
        canvasInterval = setInterval(updateCanvas, 1000);
        const canvasStream = fallbackCanvas.captureStream(15);
        videoTrack = canvasStream.getVideoTracks()[0];
      }

      // Combine video and mixed audio into recording stream
      const tracksToRecord = [];
      if (videoTrack) tracksToRecord.push(videoTrack);
      if (this.audioDestination && this.audioDestination.stream.getAudioTracks().length > 0) {
        tracksToRecord.push(this.audioDestination.stream.getAudioTracks()[0]);
      } else if (this.localStream && this.localStream.getAudioTracks().length > 0) {
        tracksToRecord.push(this.localStream.getAudioTracks()[0]);
      }

      const streamToRecord = new MediaStream(tracksToRecord);
      this.recordedChunks = [];

      // Determine supported MIME type
      let mimeType = 'video/webm;codecs=vp8,opus';
      if (!MediaRecorder.isTypeSupported(mimeType)) {
        mimeType = 'video/webm';
      }

      this.mediaRecorder = new MediaRecorder(streamToRecord, { mimeType });

      this.mediaRecorder.ondataavailable = (event) => {
        if (event.data && event.data.size > 0) {
          this.recordedChunks.push(event.data);
        }
      };

      this.mediaRecorder.onstop = async () => {
        if (canvasInterval) clearInterval(canvasInterval);
        const blob = new Blob(this.recordedChunks, { type: 'video/webm' });
        const fileName = `connekt-meeting-${this.roomCode}-${Date.now()}.webm`;

        // Trigger local browser download
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = fileName;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        setTimeout(() => URL.revokeObjectURL(url), 10000);

        // Send metadata to backend
        try {
          if (this.meeting?.id) {
            await window.api?.meetings?.logRecording(this.meeting.id, {
              fileName,
              durationSeconds: this.recordSeconds,
              fileSizeBytes: blob.size,
              storageLocation: 'browser-download'
            });
          }
        } catch (err) {
          console.warn('[Recording] Failed to log recording metadata to backend:', err);
        }

        window.app?.showToast(`Recording saved: ${fileName}`, 'success');
      };

      this.mediaRecorder.start(1000); // 1s timeslice
      this.isRecording = true;
      this.recordSeconds = 0;

      // Update UI button
      const btnRec = document.getElementById('btnToggleRecord');
      if (btnRec) {
        btnRec.classList.add('recording-active');
        btnRec.innerHTML = '⏹️';
        btnRec.title = 'Stop Recording';
      }

      // Update Top Bar Pill
      const pill = document.getElementById('meetingRecPill');
      const recTimer = document.getElementById('meetingRecTimer');
      if (pill) pill.style.display = 'inline-flex';
      if (recTimer) recTimer.textContent = '00:00';

      this.recordTimerInterval = setInterval(() => {
        this.recordSeconds++;
        const mins = String(Math.floor(this.recordSeconds / 60)).padStart(2, '0');
        const secs = String(this.recordSeconds % 60).padStart(2, '0');
        if (recTimer) recTimer.textContent = `${mins}:${secs}`;
      }, 1000);

      // Broadcast to room via socket
      const socket = window.socketService?.getSocket();
      if (socket) {
        socket.emit('meeting:recording-status', {
          roomCode: this.roomCode,
          isRecording: true,
          startedBy: this.currentUser?.personalProfile?.fullName || this.currentUser?.username || 'Host'
        });
      }

      window.app?.showToast('Meeting recording started.', 'success');
    } catch (err) {
      console.error('[Recording Error]:', err);
      window.app?.showToast('Failed to start recording: ' + err.message, 'error');
      this.isRecording = false;
    }
  }

  /**
   * Stop in-meeting recording
   */
  async stopRecording() {
    if (!this.isRecording || !this.mediaRecorder) return;

    try {
      if (this.mediaRecorder.state !== 'inactive') {
        this.mediaRecorder.stop();
      }
    } catch (e) {
      console.warn('[Recording Stop Error]:', e);
    }

    if (this.recordTimerInterval) {
      clearInterval(this.recordTimerInterval);
      this.recordTimerInterval = null;
    }

    if (this.audioContext && this.audioContext.state !== 'closed') {
      try {
        await this.audioContext.close();
      } catch (e) {}
    }

    this.isRecording = false;

    // Reset button
    const btnRec = document.getElementById('btnToggleRecord');
    if (btnRec) {
      btnRec.classList.remove('recording-active');
      btnRec.innerHTML = '⏺️';
      btnRec.title = 'Start Recording';
    }

    // Reset top pill
    const pill = document.getElementById('meetingRecPill');
    if (pill) pill.style.display = 'none';

    // Broadcast to room
    const socket = window.socketService?.getSocket();
    if (socket) {
      socket.emit('meeting:recording-status', {
        roomCode: this.roomCode,
        isRecording: false,
        startedBy: this.currentUser?.username || 'Host'
      });
    }
  }

  escapeHtml(str) {
    if (!str) return '';
    return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }
}

// Global instance
window.meetingRoom = new MeetingRoomManager();
