import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/api_config.dart';
import '../config/app_theme.dart';
import '../models/social_models.dart';
import '../services/api_service.dart';
import '../services/social_service.dart';

class LiveStreamScreen extends StatefulWidget {
  final CommunityLiveSession session;
  final bool isHost;

  const LiveStreamScreen({
    super.key,
    required this.session,
    this.isHost = false,
  });

  @override
  State<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen> {
  final RTCVideoRenderer _videoRenderer = RTCVideoRenderer();
  final TextEditingController _commentCtrl = TextEditingController();
  final Map<String, RTCPeerConnection> _viewerConnections = {};
  RTCPeerConnection? _viewerPeerConnection;
  MediaStream? _localStream;
  io.Socket? _socket;

  bool _rendererReady = false;
  bool _streamEnded = false;
  bool _micMuted = false;
  String? _mediaError;
  int _viewerCount = 1;
  final List<Map<String, dynamic>> _comments = [];
  final List<String> _floatingReactions = [];

  @override
  void initState() {
    super.initState();
    _initLive();
  }

  Future<void> _initLive() async {
    await _videoRenderer.initialize();
    if (mounted) setState(() => _rendererReady = true);

    await _loadExistingComments();
    if (widget.isHost) {
      await _startHostCamera();
    }
    await _connectSocket();
  }

  Future<void> _loadExistingComments() async {
    final detail = await SocialService.getLiveSessionDetail(widget.session.id);
    if (!mounted) return;
    final list = (detail['comments'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((c) => Map<String, dynamic>.from(c))
        .toList();
    setState(() {
      _comments.addAll(list);
      _viewerCount = int.tryParse((detail['session']?['viewer_count'] ?? widget.session.viewerCount).toString()) ?? 1;
      if (detail['session']?['status'] == 'ended') _streamEnded = true;
    });
  }

  Future<void> _startHostCamera() async {
    try {
      final stream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': {'facingMode': 'user', 'width': 1280, 'height': 720},
      });
      _localStream = stream;
      _videoRenderer.srcObject = stream;
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() => _mediaError = 'Camera/microphone unavailable ($e)');
      }
    }
  }

  Future<RTCPeerConnection> _createPc() async {
    final pc = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    });
    return pc;
  }

  Future<void> _connectSocket() async {
    final token = await ApiService.getToken();
    final origin = ApiConfig.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
    final socket = io.io(
      origin,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token ?? ''})
          .build(),
    );
    _socket = socket;

    socket.onConnect((_) {
      socket.emit('community:join-live', {
        'roomCode': widget.session.roomCode,
        'isHost': widget.isHost,
      });
    });

    socket.on('community:live-viewers', (data) {
      if (!mounted || data is! Map) return;
      setState(() => _viewerCount = int.tryParse(data['viewerCount'].toString()) ?? _viewerCount);
    });

    socket.on('community:live-comment', (data) {
      if (!mounted || data is! Map) return;
      setState(() => _comments.add(Map<String, dynamic>.from(data)));
    });

    socket.on('community:live-reaction', (data) {
      if (!mounted || data is! Map) return;
      final r = (data['reactionType'] ?? 'heart').toString();
      final emoji = r == 'fire' ? '🔥' : (r == 'clap' ? '👏' : '❤️');
      setState(() => _floatingReactions.add('$emoji ${data['username'] ?? ''}'));
      Timer(const Duration(seconds: 3), () {
        if (mounted && _floatingReactions.isNotEmpty) {
          setState(() => _floatingReactions.removeAt(0));
        }
      });
    });

    socket.on('community:live-ended', (_) {
      if (mounted) setState(() => _streamEnded = true);
    });

    // Host responds to joining viewer with WebRTC Offer
    if (widget.isHost) {
      socket.on('community:live-viewer-joined', (data) async {
        if (data is! Map) return;
        final viewerSocketId = data['viewerSocketId']?.toString();
        if (viewerSocketId == null || _localStream == null) return;
        final pc = await _createPc();
        _viewerConnections[viewerSocketId] = pc;
        for (final track in _localStream!.getTracks()) {
          await pc.addTrack(track, _localStream!);
        }
        pc.onIceCandidate = (cand) {
          socket.emit('community:live-signal', {
            'roomCode': widget.session.roomCode,
            'targetSocketId': viewerSocketId,
            'type': 'candidate',
            'signal': {
              'candidate': cand.candidate,
              'sdpMid': cand.sdpMid,
              'sdpMLineIndex': cand.sdpMLineIndex,
            },
          });
        };
        final offer = await pc.createOffer();
        await pc.setLocalDescription(offer);
        socket.emit('community:live-signal', {
          'roomCode': widget.session.roomCode,
          'targetSocketId': viewerSocketId,
          'type': 'offer',
          'signal': {'sdp': offer.sdp, 'type': offer.type},
        });
      });
    }

    socket.on('community:live-signal', (data) async {
      if (data is! Map) return;
      final senderSocketId = data['senderSocketId']?.toString();
      final signal = data['signal'];
      final type = data['type']?.toString();
      if (signal is! Map || senderSocketId == null) return;

      if (widget.isHost) {
        final pc = _viewerConnections[senderSocketId];
        if (pc == null) return;
        if (type == 'answer') {
          await pc.setRemoteDescription(RTCSessionDescription(signal['sdp'], signal['type']));
        } else if (type == 'candidate') {
          await pc.addCandidate(RTCIceCandidate(signal['candidate'], signal['sdpMid'], signal['sdpMLineIndex']));
        }
      } else {
        _viewerPeerConnection ??= await _createPc();
        final pc = _viewerPeerConnection!;
        pc.onTrack = (event) {
          if (event.streams.isNotEmpty && mounted) {
            setState(() => _videoRenderer.srcObject = event.streams.first);
          }
        };
        pc.onIceCandidate = (cand) {
          socket.emit('community:live-signal', {
            'roomCode': widget.session.roomCode,
            'targetSocketId': senderSocketId,
            'type': 'candidate',
            'signal': {
              'candidate': cand.candidate,
              'sdpMid': cand.sdpMid,
              'sdpMLineIndex': cand.sdpMLineIndex,
            },
          });
        };
        if (type == 'offer') {
          await pc.setRemoteDescription(RTCSessionDescription(signal['sdp'], signal['type']));
          final answer = await pc.createAnswer();
          await pc.setLocalDescription(answer);
          socket.emit('community:live-signal', {
            'roomCode': widget.session.roomCode,
            'targetSocketId': senderSocketId,
            'type': 'answer',
            'signal': {'sdp': answer.sdp, 'type': answer.type},
          });
        } else if (type == 'candidate') {
          await pc.addCandidate(RTCIceCandidate(signal['candidate'], signal['sdpMid'], signal['sdpMLineIndex']));
        }
      }
    });

    socket.connect();
  }

  Future<void> _sendComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    _commentCtrl.clear();
    await SocialService.postLiveComment(widget.session.id, content: text);
  }

  void _sendReaction(String reactionType) {
    _socket?.emit('community:live-reaction', {
      'roomCode': widget.session.roomCode,
      'reactionType': reactionType,
    });
  }

  Future<void> _endBroadcast() async {
    await SocialService.endLiveSession(widget.session.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _socket?.emit('community:leave-live', {'roomCode': widget.session.roomCode});
    _socket?.dispose();
    _localStream?.dispose();
    for (final pc in _viewerConnections.values) {
      pc.dispose();
    }
    _viewerPeerConnection?.dispose();
    _videoRenderer.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.session.title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
            Text(
              'Host: ${widget.session.hostName} • Room ${widget.session.roomCode}',
              style: const TextStyle(fontSize: 11.5, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: _streamEnded ? Colors.grey : AppTheme.accentCoral,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.visibility_rounded, size: 14, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  _streamEnded ? 'ENDED' : 'LIVE • $_viewerCount',
                  style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          if (widget.isHost && !_streamEnded)
            TextButton(
              onPressed: _endBroadcast,
              child: const Text('End', style: TextStyle(color: AppTheme.accentCoral, fontWeight: FontWeight.w800)),
            ),
        ],
      ),
      body: Column(
        children: [
          // Live WebRTC Video Stage
          Expanded(
            flex: 5,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_rendererReady && _videoRenderer.srcObject != null && !_streamEnded)
                  RTCVideoView(_videoRenderer, mirror: widget.isHost, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
                else
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _streamEnded ? Icons.videocam_off_rounded : Icons.live_tv_rounded,
                            size: 64,
                            color: AppTheme.brandBlue,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _streamEnded
                                ? 'This live stream has ended'
                                : (_mediaError ?? (widget.isHost ? 'Starting live camera stream...' : 'Waiting for host WebRTC broadcast stream...')),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Floating reactions overlay
                Positioned(
                  right: 14,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: _floatingReactions
                        .map((r) => Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(14)),
                              child: Text(r, style: const TextStyle(color: Colors.white, fontSize: 13)),
                            ))
                        .toList(),
                  ),
                ),

                if (widget.isHost && !_streamEnded)
                  Positioned(
                    left: 14,
                    bottom: 14,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: Icon(_micMuted ? Icons.mic_off : Icons.mic, color: Colors.white),
                        onPressed: () {
                          setState(() => _micMuted = !_micMuted);
                          _localStream?.getAudioTracks().forEach((t) => t.enabled = !_micMuted);
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Live Chat & Reactions Panel
          Expanded(
            flex: 4,
            child: Container(
              color: const Color(0xFF0F172A),
              child: Column(
                children: [
                  Expanded(
                    child: _comments.isEmpty
                        ? const Center(
                            child: Text('Live comments will appear here', style: TextStyle(color: Colors.white54)),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _comments.length,
                            itemBuilder: (_, i) {
                              final c = _comments[i];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '${c['author_name'] ?? c['username'] ?? 'Member'}: ',
                                        style: const TextStyle(color: Color(0xFF60A5FA), fontWeight: FontWeight.w700, fontSize: 13.5),
                                      ),
                                      TextSpan(
                                        text: (c['content'] ?? '').toString(),
                                        style: const TextStyle(color: Colors.white, fontSize: 13.5),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _commentCtrl,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Comment live...',
                                hintStyle: const TextStyle(color: Colors.white54),
                                filled: true,
                                fillColor: Colors.white10,
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          IconButton(icon: const Text('❤️', style: TextStyle(fontSize: 20)), onPressed: () => _sendReaction('heart')),
                          IconButton(icon: const Text('👏', style: TextStyle(fontSize: 20)), onPressed: () => _sendReaction('clap')),
                          IconButton(icon: const Text('🔥', style: TextStyle(fontSize: 20)), onPressed: () => _sendReaction('fire')),
                          IconButton.filled(
                            style: IconButton.styleFrom(backgroundColor: AppTheme.brandBlue),
                            icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                            onPressed: _sendComment,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
