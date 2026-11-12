import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../config/api_config.dart';
import '../config/app_theme.dart';
import '../config/subnet_probe_stub.dart' if (dart.library.io) '../config/subnet_probe_io.dart';
import '../services/api_service.dart';
import '../widgets/safe_avatar.dart';

class ChatScreen extends StatefulWidget {
  final String contactName;
  final String avatarUrl;
  final bool showBackButton;
  final bool isGroup;
  final List<String> initialMembers;

  const ChatScreen({
    super.key,
    this.contactName = 'Lena Rivers',
    this.avatarUrl = 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=120',
    this.showBackButton = true,
    this.isGroup = false,
    this.initialMembers = const ['You', 'Soumo', 'Lena Rivers', 'David Kim'],
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;

  // Voice recording state
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;

  // Audio playback simulation state
  String? _playingMsgId;
  double _playProgress = 0.0;
  Timer? _playTimer;

  // Chat Search state
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final List<int> _searchResults = [];
  int _currentSearchIndex = 0;

  // Selection mode state (WhatsApp item: "Select messages")
  bool _isSelectionMode = false;
  final Set<String> _selectedMsgIds = {};
  final Map<String, bool> _deletedMsgModes = {};
  Timer? _syncTimer;

  // Chat settings & preferences
  bool _isMuted = false;
  String _muteDuration = '8 hours';
  String _disappearingTimer = 'Off';
  Color? _customThemeColor;
  bool _isBlocked = false;

  // Group-specific state
  late List<String> _groupMembers;
  bool _isFavourite = false;
  bool _hasLeftGroup = false;

  @override
  void initState() {
    super.initState();
    _groupMembers = List.from(widget.initialMembers);
    _loadHistory();
    if (!isFlutterTestEnv) {
      _syncTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        _loadHistory(silent: true);
      });
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _msgController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _recordTimer?.cancel();
    _playTimer?.cancel();
    super.dispose();
  }

  static bool _isDeletedPlaceholder(Map<String, dynamic> msg) {
    final text = (msg['text'] ?? '').toString().trim();
    return msg['isDeletedForEveryone'] == true ||
        text == 'You deleted this message' ||
        text == 'This message was deleted';
  }

  Future<void> _loadHistory({bool silent = false}) async {
    try {
      final rawHistory = await ApiService.getChatMessages(widget.contactName);
      final filtered = rawHistory.where((m) {
        final id = (m['id'] ?? '').toString();
        return !_isDeletedPlaceholder(m) && !_deletedMsgModes.containsKey(id);
      }).toList();

      if (!mounted) return;
      final unsentTemps = _messages
          .where((m) {
            final id = (m['id'] ?? '').toString();
            return id.startsWith('temp_') && !_deletedMsgModes.containsKey(id);
          })
          .toList();
      final nextMessages = [...filtered, ...unsentTemps];

      setState(() {
        _messages
          ..clear()
          ..addAll(nextMessages);
        _isLoading = false;
      });
      if (!silent) {
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted && !silent) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatCurrentTime() {
    final now = DateTime.now();
    final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final ampm = now.hour >= 12 ? 'pm' : 'am';
    return '${hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} $ampm';
  }

  // ====================================================================
  // TEXT & RICH MESSAGE DISPATCH
  // ====================================================================

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempMsg = {
      'id': tempId,
      'isMe': true,
      'text': text,
      'time': _formatCurrentTime(),
      'isRead': false,
    };

    setState(() {
      _messages.add(tempMsg);
      _msgController.clear();
    });
    _scrollToBottom();

    _dispatchToBackend(text, tempId: tempId);
  }

  Future<void> _sendRichMessage(Map<String, dynamic> richData) async {
    final jsonStr = jsonEncode(richData);
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempMsg = {
      'id': tempId,
      'isMe': true,
      'text': jsonStr,
      'time': _formatCurrentTime(),
      'isRead': false,
    };

    setState(() {
      _messages.add(tempMsg);
    });
    _scrollToBottom();

    _dispatchToBackend(jsonStr, tempId: tempId);
  }

  Future<void> _dispatchToBackend(String payloadText, {required String tempId}) async {
    try {
      final res = await ApiService.sendChatMessage(widget.contactName, payloadText);
      final serverId = res['id']?.toString();

      if (serverId != null && serverId.isNotEmpty) {
        // If user deleted this optimistic message before the send call finished, delete it on backend immediately.
        if (_deletedMsgModes.containsKey(tempId)) {
          final forEveryone = _deletedMsgModes[tempId] == true;
          await ApiService.deleteChatMessage(serverId, forEveryone: forEveryone);
          return;
        }
        if (mounted) {
          setState(() {
            for (final m in _messages) {
              if ((m['id'] ?? '').toString() == tempId) {
                m['id'] = serverId;
              }
            }
          });
        }
      }

      if (mounted && res['smsDispatched'] == true) {
        final phone = res['recipientPhone'] ?? widget.contactName;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.mark_email_read_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('📲 Real SMS dispatched to $phone', style: const TextStyle(fontSize: 13)),
                ),
              ],
            ),
            duration: const Duration(seconds: 3),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Message saved locally. SMS notice: $e'),
            backgroundColor: AppTheme.accentCoral,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ====================================================================
  // MICROPHONE (VOICE NOTE RECORDING & PLAYBACK)
  // ====================================================================

  void _startVoiceRecording() {
    setState(() {
      _isRecording = true;
      _recordSeconds = 0;
    });

    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _recordSeconds++;
      });
    });
  }

  void _cancelVoiceRecording() {
    _recordTimer?.cancel();
    setState(() {
      _isRecording = false;
      _recordSeconds = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Voice recording discarded'),
        duration: Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _finishAndSendVoiceRecording() {
    _recordTimer?.cancel();
    final durationSecs = max(_recordSeconds, 1);
    final mins = durationSecs ~/ 60;
    final secs = durationSecs % 60;
    final durationStr = '$mins:${secs.toString().padLeft(2, '0')}';

    setState(() {
      _isRecording = false;
      _recordSeconds = 0;
    });

    _sendRichMessage({
      'type': 'voice',
      'duration': durationStr,
      'seconds': durationSecs,
    });
  }

  void _togglePlayVoiceNote(String msgId, int durationSeconds) {
    if (_playingMsgId == msgId) {
      _playTimer?.cancel();
      setState(() {
        _playingMsgId = null;
        _playProgress = 0.0;
      });
      return;
    }

    _playTimer?.cancel();
    setState(() {
      _playingMsgId = msgId;
      _playProgress = 0.0;
    });

    const stepMs = 100;
    final totalSteps = (durationSeconds * 1000) / stepMs;

    _playTimer = Timer.periodic(const Duration(milliseconds: stepMs), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _playProgress += 1.0 / totalSteps;
        if (_playProgress >= 1.0) {
          _playingMsgId = null;
          _playProgress = 0.0;
          timer.cancel();
        }
      });
    });
  }

  // ====================================================================
  // WHATSAPP-STYLE ATTACHMENT MENU & ACTIONS
  // ====================================================================

  void _showAttachmentSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1E283D) : Colors.white;
    final labelColor = isDark ? Colors.white70 : const Color(0xFF475569);

    showModalBottomSheet(
      context: context,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 2 Rows x 3 Columns WhatsApp Attachment Grid
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildAttachmentItem(
                      icon: Icons.insert_drive_file_rounded,
                      label: 'Document',
                      gradient: const [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickDocument();
                      },
                      textColor: labelColor,
                    ),
                    _buildAttachmentItem(
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      gradient: const [Color(0xFFEC4899), Color(0xFFBE185D)],
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickImage(ImageSource.camera);
                      },
                      textColor: labelColor,
                    ),
                    _buildAttachmentItem(
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      gradient: const [Color(0xFF6366F1), Color(0xFF4338CA)],
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickImage(ImageSource.gallery);
                      },
                      textColor: labelColor,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildAttachmentItem(
                      icon: Icons.headphones_rounded,
                      label: 'Audio',
                      gradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickAudio();
                      },
                      textColor: labelColor,
                    ),
                    _buildAttachmentItem(
                      icon: Icons.location_on_rounded,
                      label: 'Location',
                      gradient: const [Color(0xFF10B981), Color(0xFF047857)],
                      onTap: () {
                        Navigator.pop(ctx);
                        _sendLocation();
                      },
                      textColor: labelColor,
                    ),
                    _buildAttachmentItem(
                      icon: Icons.person_rounded,
                      label: 'Contact',
                      gradient: const [Color(0xFF007AFF), Color(0xFF0051B3)],
                      onTap: () {
                        Navigator.pop(ctx);
                        _sendContact();
                      },
                      textColor: labelColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttachmentItem({
    required IconData icon,
    required String label,
    required List<Color> gradient,
    required VoidCallback onTap,
    required Color textColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: gradient.first.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDocument() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx', 'ppt', 'pptx', 'zip'],
      );

      if (files.isNotEmpty) {
        final file = files.first;
        final name = file.name;
        final sizeBytes = await file.length() ?? file.lengthSync() ?? 0;
        final sizeStr = _formatFileSize(sizeBytes);
        final ext = file.extension ?? 'file';

        String? uploadedUrl;
        if (file.path != null) {
          final upRes = await ApiService.uploadChatFile(file.path!, name);
          uploadedUrl = upRes?['url'];
        }

        _sendRichMessage({
          'type': 'file',
          'name': name,
          'size': sizeStr,
          'ext': ext,
          'url': uploadedUrl ?? '',
        });
      }
    } catch (e) {
      _showSnack('Document picker error: $e');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );

      if (picked != null) {
        final name = picked.name;
        final bytes = await picked.readAsBytes();
        final sizeStr = _formatFileSize(bytes.length);

        String? uploadedUrl;
        final upRes = await ApiService.uploadChatFile(picked.path, name);
        uploadedUrl = upRes?['url'];

        _sendRichMessage({
          'type': 'image',
          'name': name,
          'size': sizeStr,
          'url': uploadedUrl ?? '',
        });
      }
    } catch (e) {
      _showSnack('Image picker error: $e');
    }
  }

  Future<void> _pickAudio() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.audio);
      if (files.isNotEmpty) {
        final file = files.first;
        final name = file.name;
        final sizeBytes = await file.length() ?? file.lengthSync() ?? 0;
        final sizeStr = _formatFileSize(sizeBytes);

        _sendRichMessage({
          'type': 'audio',
          'name': name,
          'size': sizeStr,
          'duration': '3:24',
        });
      }
    } catch (e) {
      _showSnack('Audio picker error: $e');
    }
  }

  void _sendLocation() {
    _sendRichMessage({
      'type': 'location',
      'name': 'Kolkata, West Bengal, India',
      'lat': '22.5726° N',
      'lng': '88.3639° E',
    });
  }

  void _sendContact() {
    _sendRichMessage({
      'type': 'contact',
      'name': 'Koushiki Podder',
      'phone': '+91 9836828816',
      'username': '@kou12',
    });
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    final i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  void _showSnack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  // ====================================================================
  // BUBBLE RENDERER (WHATSAPP-STYLE RICH MEDIA & TEXT)
  // ====================================================================

  Widget _buildMessageContent(
    Map<String, dynamic> msg,
    bool isMe,
    Color textColor,
    Color subtextColor,
    bool isDark,
  ) {
    final rawText = (msg['text'] ?? '').toString();

    // Check if JSON payload
    if (rawText.startsWith('{') && rawText.endsWith('}')) {
      try {
        final data = jsonDecode(rawText);
        final type = data['type'];

        // 1. VOICE NOTE BUBBLE
        if (type == 'voice') {
          final duration = data['duration'] ?? '0:05';
          final durationSecs = (data['seconds'] as int?) ?? 5;
          final msgId = (msg['id'] ?? rawText).toString();
          final isPlaying = _playingMsgId == msgId;

          return SizedBox(
            width: 230,
            child: Row(
              children: [
                // Play / Pause Circle
                GestureDetector(
                  onTap: () => _togglePlayVoiceNote(msgId, durationSecs),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isMe ? Colors.white.withValues(alpha: 0.25) : AppTheme.brandBlue,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Audio Waveform & Timer
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Animated / Styled Waveform Bars
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(18, (index) {
                          final barHeight = 8.0 + (sin(index * 0.9) * 10).abs();
                          final activePercent = index / 18.0;
                          final isActive = isPlaying && (_playProgress >= activePercent);

                          return Container(
                            width: 3,
                            height: barHeight,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? (isMe ? Colors.white : AppTheme.brandBlue)
                                  : (isMe ? Colors.white38 : (isDark ? Colors.white24 : Colors.black26)),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isPlaying
                                ? '${(durationSecs * (1 - _playProgress)).ceil()}s'
                                : duration,
                            style: TextStyle(
                              color: isMe ? Colors.white70 : subtextColor,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Icon(
                            Icons.mic,
                            size: 13,
                            color: isMe ? Colors.white70 : AppTheme.brandBlue,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // 2. IMAGE BUBBLE
        if (type == 'image') {
          final imgUrl = data['url'] ?? '';
          final fullUrl = imgUrl.toString().startsWith('/')
              ? '${ApiConfig.rootUrl}$imgUrl'
              : imgUrl.toString();
          final name = data['name'] ?? 'Photo';
          final size = data['size'] ?? '';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 220,
                  height: 160,
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                  child: isValidHttpUrl(fullUrl)
                      ? Image.network(
                          fullUrl,
                          width: 220,
                          height: 160,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildMediaPlaceholder(Icons.image, name, size),
                        )
                      : _buildMediaPlaceholder(Icons.image, name, size),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$name ($size)',
                style: TextStyle(
                  color: isMe ? Colors.white70 : subtextColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          );
        }

        // 3. FILE / DOCUMENT BUBBLE
        if (type == 'file' || type == 'audio') {
          final isAudio = type == 'audio';
          final name = data['name'] ?? (isAudio ? 'Audio file' : 'Document');
          final size = data['size'] ?? '';
          final ext = (data['ext'] ?? (isAudio ? 'MP3' : 'FILE')).toString().toUpperCase();

          return Container(
            width: 220,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isMe ? Colors.black12 : (isDark ? const Color(0xFF131B2E) : Colors.white),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isAudio ? const Color(0xFFF59E0B) : const Color(0xFF8B5CF6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      ext.length > 4 ? ext.substring(0, 4) : ext,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isMe ? Colors.white : textColor,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        size,
                        style: TextStyle(
                          color: isMe ? Colors.white70 : subtextColor,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_circle_down_rounded,
                  color: isMe ? Colors.white : AppTheme.brandBlue,
                  size: 24,
                ),
              ],
            ),
          );
        }

        // 4. LOCATION BUBBLE
        if (type == 'location') {
          final name = data['name'] ?? 'Location';
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on_rounded, color: Color(0xFF10B981), size: 28),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: isMe ? Colors.white : textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Live Coordinates',
                      style: TextStyle(
                        color: isMe ? Colors.white70 : subtextColor,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }

        // 5. CONTACT BUBBLE
        if (type == 'contact') {
          final name = data['name'] ?? 'Contact';
          final phone = data['phone'] ?? '';
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppTheme.brandBlue,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0] : 'C',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: isMe ? Colors.white : textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      phone,
                      style: TextStyle(
                        color: isMe ? Colors.white70 : subtextColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }
      } catch (_) {}
    }

    // Default plain text message (with optional search highlight)
    if (_isSearching && _searchController.text.trim().isNotEmpty) {
      final query = _searchController.text.trim();
      final lowerText = rawText.toLowerCase();
      final lowerQuery = query.toLowerCase();

      if (lowerText.contains(lowerQuery)) {
        final spans = <TextSpan>[];
        int start = 0;
        while (true) {
          final index = lowerText.indexOf(lowerQuery, start);
          if (index == -1) {
            spans.add(TextSpan(
              text: rawText.substring(start),
              style: TextStyle(color: isMe ? Colors.white : textColor, fontSize: 14),
            ));
            break;
          }
          if (index > start) {
            spans.add(TextSpan(
              text: rawText.substring(start, index),
              style: TextStyle(color: isMe ? Colors.white : textColor, fontSize: 14),
            ));
          }
          spans.add(TextSpan(
            text: rawText.substring(index, index + query.length),
            style: const TextStyle(
              backgroundColor: Color(0xFFFDE047),
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ));
          start = index + query.length;
        }
        return RichText(text: TextSpan(children: spans));
      }
    }

    return Text(
      rawText,
      style: TextStyle(
        color: isMe ? Colors.white : textColor,
        fontSize: 14,
      ),
    );
  }

  Widget _buildMediaPlaceholder(IconData icon, String name, String size) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: AppTheme.brandBlue),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70),
            ),
          ),
          Text(size, style: const TextStyle(fontSize: 9.5, color: Colors.white38)),
        ],
      ),
    );
  }

  // ====================================================================
  // BUILD METHOD
  // ====================================================================

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBg = isDark ? AppTheme.bgDark : const Color(0xFFF8FAFC);
    final bgColor = _customThemeColor ?? defaultBg;
    final cardColor = isDark ? AppTheme.bgCard : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? AppTheme.textMuted : const Color(0xFF64748B);
    final inputBg = isDark ? AppTheme.bgInput : const Color(0xFFF1F5F9);
    final borderColor = isDark ? const Color(0xFF1E283D) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: _isSelectionMode
            ? IconButton(
                icon: Icon(Icons.close_rounded, color: textColor),
                onPressed: () {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedMsgIds.clear();
                  });
                },
              )
            : _isSearching
                ? IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: textColor),
                    onPressed: _closeSearch,
                  )
                : widget.showBackButton && Navigator.canPop(context)
                    ? IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          size: 20,
                        ),
                        onPressed: () => Navigator.pop(context),
                      )
                    : null,
        automaticallyImplyLeading: false,
        titleSpacing: (_isSearching || _isSelectionMode) ? 0 : (widget.showBackButton ? 0 : 16),
        title: _isSelectionMode
            ? Text(
                '${_selectedMsgIds.length} selected',
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
              )
            : _isSearching
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: TextStyle(color: textColor, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Search messages...',
                      hintStyle: TextStyle(color: subtextColor, fontSize: 15),
                      border: InputBorder.none,
                    ),
                    onChanged: _performSearch,
                  )
                : Row(
                    children: [
                      Stack(
                        children: [
                          SafeAvatar(
                            url: widget.avatarUrl,
                            fallbackText: widget.contactName,
                            fallbackIcon: widget.isGroup ? Icons.group : null,
                            size: 38,
                            radius: 19,
                          ),
                          if (!widget.isGroup)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: bgColor, width: 2),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    widget.contactName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                                if (_isFavourite) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.favorite_rounded, size: 14, color: AppTheme.accentCoral),
                                ],
                                if (_isMuted) ...[
                                  const SizedBox(width: 4),
                                  Icon(Icons.notifications_off_outlined, size: 14, color: subtextColor),
                                ],
                                if (_disappearingTimer != 'Off') ...[
                                  const SizedBox(width: 4),
                                  Icon(Icons.timer_outlined, size: 14, color: subtextColor),
                                ],
                              ],
                            ),
                            const SizedBox(height: 1),
                            Text(
                              widget.isGroup ? _groupMembers.join(', ') : 'online',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: widget.isGroup ? subtextColor : (isDark ? const Color(0xFF10B981) : const Color(0xFF059669)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
        actions: _isSelectionMode
            ? [
                IconButton(
                  icon: Icon(Icons.star_outline_rounded, color: textColor),
                  tooltip: 'Star',
                  onPressed: () {
                    _showSnack('${_selectedMsgIds.length} message(s) starred');
                    setState(() {
                      _isSelectionMode = false;
                      _selectedMsgIds.clear();
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.accentCoral),
                  tooltip: 'Delete',
                  onPressed: () => _showDeleteMessagesDialog(),
                ),
                IconButton(
                  icon: Icon(Icons.copy_rounded, color: textColor),
                  tooltip: 'Copy',
                  onPressed: () {
                    final texts = _messages
                        .where((m) => _selectedMsgIds.contains(m['id']))
                        .map((m) => m['text'] ?? '')
                        .join('\n');
                    Clipboard.setData(ClipboardData(text: texts));
                    setState(() {
                      _isSelectionMode = false;
                      _selectedMsgIds.clear();
                    });
                    _showSnack('Copied to clipboard');
                  },
                ),
              ]
            : _isSearching
                ? [
                    if (_searchResults.isNotEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            '${_currentSearchIndex + 1}/${_searchResults.length}',
                            style: TextStyle(color: subtextColor, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    IconButton(
                      icon: Icon(Icons.keyboard_arrow_up_rounded, color: textColor),
                      onPressed: _searchResults.isEmpty ? null : _prevSearchResult,
                    ),
                    IconButton(
                      icon: Icon(Icons.keyboard_arrow_down_rounded, color: textColor),
                      onPressed: _searchResults.isEmpty ? null : _nextSearchResult,
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: textColor),
                      onPressed: _closeSearch,
                    ),
                  ]
                : widget.isGroup
                    ? [
                        // Group Video Call with Dropdown (📹 ▼)
                        PopupMenuButton<String>(
                          icon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.videocam_outlined, color: textColor, size: 24),
                              Icon(Icons.arrow_drop_down, color: textColor, size: 18),
                            ],
                          ),
                          color: isDark ? const Color(0xFF1F2733) : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          onSelected: (val) {
                            if (val == 'video') _startGroupCall(isVideo: true);
                            if (val == 'voice') _startGroupCall(isVideo: false);
                          },
                          itemBuilder: (ctx) => [
                            PopupMenuItem(
                              value: 'video',
                              child: Row(
                                children: [
                                  Icon(Icons.videocam_rounded, color: isDark ? Colors.white : Colors.black87, size: 20),
                                  const SizedBox(width: 12),
                                  Text('Group video call', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14)),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'voice',
                              child: Row(
                                children: [
                                  Icon(Icons.call_rounded, color: isDark ? Colors.white : Colors.black87, size: 20),
                                  const SizedBox(width: 12),
                                  Text('Group voice call', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        // Search Icon (🔍)
                        IconButton(
                          icon: Icon(Icons.search_rounded, color: textColor, size: 22),
                          tooltip: 'Search',
                          onPressed: _startSearch,
                        ),
                        // 3-dots Group Chat Menu (⋮)
                        _buildGroupChatMenu(isDark, textColor),
                      ]
                    : [
                        IconButton(
                          icon: Icon(Icons.videocam_outlined, color: textColor, size: 24),
                          tooltip: 'Video call',
                          onPressed: () => _startCall(isVideo: true),
                        ),
                        IconButton(
                          icon: Icon(Icons.call_outlined, color: textColor, size: 22),
                          tooltip: 'Voice call',
                          onPressed: () => _startCall(isVideo: false),
                        ),
                        _buildIndividualChatMenu(isDark, textColor),
                      ],
      ),
      body: Column(
        children: [
          // Chat Messages List, Loading or Empty State
          Expanded(
            child: _isLoading
                ? const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(color: AppTheme.brandBlue, strokeWidth: 2.5),
                    ),
                  )
                : _messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: AppTheme.brandBlue.withValues(alpha: isDark ? 0.15 : 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 40,
                                  color: AppTheme.brandBlue,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No messages yet',
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Send a message to start the conversation!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: subtextColor,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];

                          // System Message Capsule (e.g. Disappearing Messages notice)
                          if (msg['isSystem'] == true) {
                            return Center(
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E283D) : const Color(0xFFE2E8F0),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  msg['text'] ?? '',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: subtextColor, fontSize: 12),
                                ),
                              ),
                            );
                          }

                          final isMe = msg['isMe'] == true;
                          final msgId = (msg['id'] ?? index.toString()).toString();
                          final isSelected = _selectedMsgIds.contains(msgId);

                          return GestureDetector(
                            onTap: _isSelectionMode
                                ? () {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedMsgIds.remove(msgId);
                                        if (_selectedMsgIds.isEmpty) _isSelectionMode = false;
                                      } else {
                                        _selectedMsgIds.add(msgId);
                                      }
                                    });
                                  }
                                : null,
                            onLongPress: () {
                              _showMessageActionSheet(msg, msgId);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: _isSelectionMode ? const EdgeInsets.symmetric(vertical: 4) : EdgeInsets.zero,
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.brandBlue.withValues(alpha: 0.15) : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (_isSelectionMode && !isMe) ...[
                                    Icon(
                                      isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                      color: isSelected ? AppTheme.brandBlue : subtextColor,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Column(
                                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                    children: [
                                      if (widget.isGroup && !isMe)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 4, bottom: 3),
                                          child: Text(
                                            (msg['sender'] ?? 'Member').toString(),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF6366F1),
                                            ),
                                          ),
                                        ),
                                      Container(
                                        constraints: BoxConstraints(
                                          maxWidth: MediaQuery.of(context).size.width * 0.74,
                                        ),
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: isMe
                                                ? AppTheme.brandBlue
                                                : (isDark ? cardColor : const Color(0xFFF1F5F9)),
                                            borderRadius: BorderRadius.only(
                                              topLeft: const Radius.circular(18),
                                              topRight: const Radius.circular(18),
                                              bottomLeft: Radius.circular(isMe ? 18 : 4),
                                              bottomRight: Radius.circular(isMe ? 4 : 18),
                                            ),
                                            boxShadow: isMe
                                                ? [
                                                    BoxShadow(
                                                      color: AppTheme.brandBlue.withValues(alpha: 0.22),
                                                      blurRadius: 8,
                                                      offset: const Offset(0, 3),
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                          child: _buildMessageContent(msg, isMe, textColor, subtextColor, isDark),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              msg['time'] ?? '',
                                              style: TextStyle(color: subtextColor, fontSize: 10),
                                            ),
                                            if (isMe) ...[
                                              const SizedBox(width: 4),
                                              Icon(
                                                Icons.done_all,
                                                size: 14,
                                                color: msg['isRead'] == true
                                                    ? const Color(0xFF10B981)
                                                    : subtextColor,
                                              ),
                                            ],
                                          ],
                                        ),
                                    ],
                                  ),
                                  if (_isSelectionMode && isMe) ...[
                                    const SizedBox(width: 8),
                                    Icon(
                                      isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                      color: isSelected ? AppTheme.brandBlue : subtextColor,
                                      size: 20,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // ====================================================================
          // BOTTOM BAR (LEFT GROUP NOTICE, BLOCKED BANNER, TEXT INPUT, RECORDER)
          // ====================================================================
          if (_hasLeftGroup)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E283D) : const Color(0xFFF1F5F9),
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: SafeArea(
                top: false,
                child: Text(
                  "You can't send messages to this group because you're no longer a participant.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: subtextColor, fontSize: 13, height: 1.4),
                ),
              ),
            )
          else if (_isBlocked)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E283D) : const Color(0xFFF1F5F9),
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('You blocked this contact. ', style: TextStyle(color: subtextColor, fontSize: 13)),
                    GestureDetector(
                      onTap: () {
                        setState(() => _isBlocked = false);
                        _showSnack('Unblocked ${widget.contactName}');
                      },
                      child: const Text('Tap to unblock.', style: TextStyle(color: AppTheme.brandBlue, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: bgColor,
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: SafeArea(
                top: false,
                child: _isRecording
                    ? _buildVoiceRecorderBar(isDark, textColor)
                    : _buildNormalInputBar(inputBg, borderColor, textColor, subtextColor),
              ),
            ),
        ],
      ),
    );
  }

  // Normal Input Bar with '+' attachment button, TextField, and Microphone button
  Widget _buildNormalInputBar(Color inputBg, Color borderColor, Color textColor, Color subtextColor) {
    return Row(
      children: [
        // WhatsApp Attachment '+' Button
        GestureDetector(
          onTap: () => _showAttachmentSheet(context),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: inputBg,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor),
            ),
            child: const Icon(Icons.add_rounded, color: AppTheme.brandBlue, size: 24),
          ),
        ),
        const SizedBox(width: 8),

        // Text Field with inside Microphone Action
        Expanded(
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: inputBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    style: TextStyle(color: textColor, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Chat...',
                      hintStyle: TextStyle(color: subtextColor, fontSize: 14),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                // Workable Microphone Button
                GestureDetector(
                  onTap: _startVoiceRecording,
                  child: Tooltip(
                    message: 'Record voice note',
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.mic_rounded, color: AppTheme.brandBlue, size: 22),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Send Button
        GestureDetector(
          onTap: _sendMessage,
          child: Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
          ),
        ),
      ],
    );
  }

  // Active Voice Recorder Bar (Pulsing Red indicator, Timer, Waveform, Discard, Send)
  Widget _buildVoiceRecorderBar(bool isDark, Color textColor) {
    final mins = _recordSeconds ~/ 60;
    final secs = _recordSeconds % 60;
    final timerString = '$mins:${secs.toString().padLeft(2, '0')}';

    return Row(
      children: [
        // Trash / Cancel Button
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.accentCoral, size: 26),
          tooltip: 'Discard voice note',
          onPressed: _cancelVoiceRecording,
        ),
        const SizedBox(width: 6),

        // Center Pulsing Recording Indicator + Timer + Waveform
        Expanded(
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E283D) : const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                // Pulsing Red Recording Dot
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppTheme.accentCoral,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  timerString,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppTheme.accentCoral,
                  ),
                ),
                const SizedBox(width: 12),

                // Simulated Live Audio Waveform Bars
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(14, (i) {
                      final h = 6.0 + ((i + _recordSeconds) % 5) * 4.0;
                      return Container(
                        width: 3,
                        height: h,
                        decoration: BoxDecoration(
                          color: AppTheme.accentCoral.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Send Voice Note Button
        GestureDetector(
          onTap: _finishAndSendVoiceRecording,
          child: Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFF1D4ED8),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          ),
        ),
      ],
    );
  }

  // ====================================================================
  // INDIVIDUAL CHAT 3-DOTS OVERFLOW MENU (WHATSAPP FEATURES)
  // ====================================================================

  Widget _buildIndividualChatMenu(bool isDark, Color textColor) {
    final menuBg = isDark ? const Color(0xFF1F2733) : Colors.white;
    final itemTextColor = isDark ? const Color(0xFFE9EDEF) : const Color(0xFF1E293B);

    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded, color: textColor, size: 22),
      color: menuBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      offset: const Offset(0, 48),
      elevation: 8,
      onSelected: (value) => _handleMenuSelection(value),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'ask_ai',
          child: Text('Ask Meta AI privately', style: TextStyle(color: itemTextColor, fontSize: 14)),
        ),
        PopupMenuItem<String>(
          value: 'new_group',
          child: Text('New group', style: TextStyle(color: itemTextColor, fontSize: 14)),
        ),
        PopupMenuItem<String>(
          value: 'view_contact',
          child: Text('View contact', style: TextStyle(color: itemTextColor, fontSize: 14)),
        ),
        PopupMenuItem<String>(
          value: 'search',
          child: Text('Search', style: TextStyle(color: itemTextColor, fontSize: 14)),
        ),
        PopupMenuItem<String>(
          value: 'media_links_docs',
          child: Text('Media, links, and docs', style: TextStyle(color: itemTextColor, fontSize: 14)),
        ),
        PopupMenuItem<String>(
          value: 'mute',
          child: Text('Mute notifications', style: TextStyle(color: itemTextColor, fontSize: 14)),
        ),
        PopupMenuItem<String>(
          value: 'disappearing',
          child: Text('Disappearing messages', style: TextStyle(color: itemTextColor, fontSize: 14)),
        ),
        PopupMenuItem<String>(
          value: 'theme',
          child: Text('Chat theme', style: TextStyle(color: itemTextColor, fontSize: 14)),
        ),
        PopupMenuItem<String>(
          value: 'more',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('More', style: TextStyle(color: itemTextColor, fontSize: 14)),
              Icon(Icons.arrow_right_rounded, color: itemTextColor.withValues(alpha: 0.6), size: 22),
            ],
          ),
        ),
      ],
    );
  }

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'ask_ai':
        _showAskAISheet();
        break;
      case 'new_group':
        _showNewGroupDialog();
        break;
      case 'view_contact':
        _showViewContactSheet();
        break;
      case 'search':
        _startSearch();
        break;
      case 'media_links_docs':
        _showMediaLinksDocsSheet();
        break;
      case 'mute':
        _showMuteDialog();
        break;
      case 'disappearing':
        _showDisappearingMessagesSheet();
        break;
      case 'theme':
        _showChatThemeSheet();
        break;
      case 'more':
        _showMoreOptionsSheet();
        break;
    }
  }

  // 1. ASK AI PRIVATELY
  void _showAskAISheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E283D) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? AppTheme.textMuted : const Color(0xFF64748B);
    final inputBg = isDark ? const Color(0xFF121A2B) : const Color(0xFFF1F5F9);
    final promptController = TextEditingController();

    String? aiResponse;
    bool isThinking = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            void runPrompt(String prompt) {
              setSheetState(() {
                isThinking = true;
                aiResponse = null;
              });

              Future.delayed(const Duration(milliseconds: 600), () {
                if (!mounted) return;
                setSheetState(() {
                  isThinking = false;
                  if (prompt.contains('Summarize')) {
                    aiResponse = '📌 Chat Summary with ${widget.contactName}:\n• Discussed project updates and shared files.\n• All deliverables are on track.\n• No pending blockers.';
                  } else if (prompt.contains('Draft')) {
                    aiResponse = 'Sounds great! I will review the shared files and get back to you shortly. 👍';
                  } else if (prompt.contains('Action') || prompt.contains('Dates')) {
                    aiResponse = '📋 Action Items:\n1. Verify latest documents.\n2. Coordinate upcoming meeting with ${widget.contactName}.';
                  } else {
                    aiResponse = 'CONNEKT AI: Here is what I found for "$prompt" regarding your chat with ${widget.contactName}. Everything is synced and encrypted.';
                  }
                });
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ask Meta AI privately',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textColor),
                            ),
                            Text(
                              'Private & end-to-end encrypted to this chat',
                              style: TextStyle(fontSize: 12, color: subtextColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Quick Suggestion Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildAiChip('💡 Summarize chat', () => runPrompt('Summarize this conversation'), isDark),
                        const SizedBox(width: 8),
                        _buildAiChip('✍️ Draft reply', () => runPrompt('Draft a polite reply'), isDark),
                        const SizedBox(width: 8),
                        _buildAiChip('📋 Action items', () => runPrompt('Extract Action items and Dates'), isDark),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // AI Response Card
                  if (isThinking)
                    Container(
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF8B5CF6)),
                          ),
                          const SizedBox(width: 12),
                          Text('AI is thinking...', style: TextStyle(color: subtextColor, fontSize: 13)),
                        ],
                      ),
                    )
                  else if (aiResponse != null)
                    Container(
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(aiResponse!, style: TextStyle(color: textColor, fontSize: 13, height: 1.4)),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF8B5CF6)),
                                label: const Text('Use in chat', style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 12, fontWeight: FontWeight.bold)),
                                onPressed: () {
                                  _msgController.text = aiResponse!;
                                  Navigator.pop(ctx);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                  // Input Box
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: inputBg,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: TextField(
                            controller: promptController,
                            style: TextStyle(color: textColor, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Ask anything about this chat...',
                              hintStyle: TextStyle(color: subtextColor, fontSize: 13),
                              border: InputBorder.none,
                            ),
                            onSubmitted: (q) {
                              if (q.trim().isNotEmpty) runPrompt(q.trim());
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          final q = promptController.text.trim();
                          if (q.isNotEmpty) runPrompt(q);
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAiChip(String label, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF121A2B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF8B5CF6)),
        ),
      ),
    );
  }

  // 2. NEW GROUP
  void _showNewGroupDialog() {
    final groupNameController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E283D) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? AppTheme.textMuted : const Color(0xFF64748B);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('New group', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Participants:', style: TextStyle(color: subtextColor, fontSize: 12)),
            const SizedBox(height: 8),
            Chip(
              avatar: SafeAvatar(url: widget.avatarUrl, fallbackText: widget.contactName, size: 24, radius: 12),
              label: Text(widget.contactName, style: TextStyle(color: textColor, fontSize: 13)),
              backgroundColor: isDark ? const Color(0xFF121A2B) : const Color(0xFFF1F5F9),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: groupNameController,
              style: TextStyle(color: textColor, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Group subject',
                labelStyle: TextStyle(color: subtextColor),
                hintText: 'Enter group name...',
                hintStyle: TextStyle(color: subtextColor.withValues(alpha: 0.6)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: subtextColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.brandBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final groupName = groupNameController.text.trim();
              Navigator.pop(ctx);
              _showSnack(groupName.isNotEmpty
                  ? 'Created group "$groupName" with ${widget.contactName}'
                  : 'Created group with ${widget.contactName}');
            },
            child: const Text('Create', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // 3. VIEW CONTACT
  void _showViewContactSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E283D) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? AppTheme.textMuted : const Color(0xFF64748B);
    final cardBg = isDark ? const Color(0xFF121A2B) : const Color(0xFFF8FAFC);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Avatar & Name & Status
                Center(
                  child: Column(
                    children: [
                      SafeAvatar(
                        url: widget.avatarUrl,
                        fallbackText: widget.contactName,
                        size: 96,
                        radius: 48,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        widget.contactName,
                        style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '+91 98301 13038',
                        style: TextStyle(color: subtextColor, fontSize: 14),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'online',
                          style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons Row: Audio, Video, Search, Share
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildContactActionButton(Icons.call_rounded, 'Audio', () {
                      Navigator.pop(ctx);
                      _startCall(isVideo: false);
                    }, isDark),
                    _buildContactActionButton(Icons.videocam_rounded, 'Video', () {
                      Navigator.pop(ctx);
                      _startCall(isVideo: true);
                    }, isDark),
                    _buildContactActionButton(Icons.search_rounded, 'Search', () {
                      Navigator.pop(ctx);
                      _startSearch();
                    }, isDark),
                    _buildContactActionButton(Icons.share_rounded, 'Share', () {
                      Navigator.pop(ctx);
                      _showSnack('Contact shared');
                    }, isDark),
                  ],
                ),
                const SizedBox(height: 24),

                // About / Bio
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('About', style: TextStyle(color: subtextColor, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text('Hey there! I am using CONNEKT.', style: TextStyle(color: textColor, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text('Updated recently', style: TextStyle(color: subtextColor, fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Media, links, and docs
                ListTile(
                  tileColor: cardBg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: const Icon(Icons.perm_media_outlined, color: AppTheme.brandBlue),
                  title: Text('Media, links, and docs', style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showMediaLinksDocsSheet();
                  },
                ),
                const SizedBox(height: 10),

                // Mute & Disappearing
                ListTile(
                  tileColor: cardBg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: const Icon(Icons.notifications_off_outlined, color: AppTheme.accentCoral),
                  title: Text('Mute notifications', style: TextStyle(color: textColor, fontSize: 14)),
                  subtitle: Text(_isMuted ? 'Muted ($_muteDuration)' : 'No', style: TextStyle(color: subtextColor, fontSize: 12)),
                  trailing: Switch(
                    value: _isMuted,
                    activeColor: AppTheme.brandBlue,
                    onChanged: (val) {
                      Navigator.pop(ctx);
                      _showMuteDialog();
                    },
                  ),
                ),
                const SizedBox(height: 10),

                ListTile(
                  tileColor: cardBg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: const Icon(Icons.timer_outlined, color: Color(0xFF8B5CF6)),
                  title: Text('Disappearing messages', style: TextStyle(color: textColor, fontSize: 14)),
                  subtitle: Text(_disappearingTimer, style: TextStyle(color: subtextColor, fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showDisappearingMessagesSheet();
                  },
                ),
                const SizedBox(height: 10),

                // Encryption Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline_rounded, color: Color(0xFF10B981), size: 24),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Encryption', style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(
                              'Messages and calls are end-to-end encrypted. No one outside of this chat can read or listen to them.',
                              style: TextStyle(color: subtextColor, fontSize: 11, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Block & Report Contact Buttons
                ListTile(
                  tileColor: cardBg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: const Icon(Icons.block_rounded, color: AppTheme.accentCoral),
                  title: Text(_isBlocked ? 'Unblock ${widget.contactName}' : 'Block ${widget.contactName}', style: const TextStyle(color: AppTheme.accentCoral, fontWeight: FontWeight.bold, fontSize: 14)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _toggleBlockContact();
                  },
                ),
                const SizedBox(height: 10),
                ListTile(
                  tileColor: cardBg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: const Icon(Icons.thumb_down_alt_outlined, color: AppTheme.accentCoral),
                  title: Text('Report ${widget.contactName}', style: const TextStyle(color: AppTheme.accentCoral, fontWeight: FontWeight.bold, fontSize: 14)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showReportDialog();
                  },
                ),
                const SizedBox(height: 24),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildContactActionButton(IconData icon, String label, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E283D) : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.brandBlue, size: 22),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: AppTheme.brandBlue, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // 4. SEARCH
  void _startSearch() {
    setState(() {
      _isSearching = true;
      _searchResults.clear();
      _currentSearchIndex = 0;
    });
  }

  void _closeSearch() {
    setState(() {
      _isSearching = false;
      _searchController.clear();
      _searchResults.clear();
      _currentSearchIndex = 0;
    });
  }

  void _performSearch(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _searchResults.clear();
      _currentSearchIndex = 0;
      if (q.isNotEmpty) {
        for (int i = 0; i < _messages.length; i++) {
          final text = (_messages[i]['text'] ?? '').toString().toLowerCase();
          if (text.contains(q)) {
            _searchResults.add(i);
          }
        }
        if (_searchResults.isNotEmpty) {
          _scrollToSearchIndex(_searchResults.first);
        }
      }
    });
  }

  void _prevSearchResult() {
    if (_searchResults.isEmpty) return;
    setState(() {
      _currentSearchIndex = (_currentSearchIndex - 1 + _searchResults.length) % _searchResults.length;
    });
    _scrollToSearchIndex(_searchResults[_currentSearchIndex]);
  }

  void _nextSearchResult() {
    if (_searchResults.isEmpty) return;
    setState(() {
      _currentSearchIndex = (_currentSearchIndex + 1) % _searchResults.length;
    });
    _scrollToSearchIndex(_searchResults[_currentSearchIndex]);
  }

  void _scrollToSearchIndex(int msgIndex) {
    if (_scrollController.hasClients) {
      final target = (msgIndex / max(1, _messages.length)) * _scrollController.position.maxScrollExtent;
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // 5. MEDIA, LINKS, AND DOCS
  void _showMediaLinksDocsSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E283D) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? AppTheme.textMuted : const Color(0xFF64748B);

    final mediaList = <Map<String, dynamic>>[];
    final docsList = <Map<String, dynamic>>[];
    final linksList = <String>[];

    for (final m in _messages) {
      final raw = (m['text'] ?? '').toString();
      if (raw.startsWith('{') && raw.endsWith('}')) {
        try {
          final data = jsonDecode(raw);
          if (data['type'] == 'image') mediaList.add(data);
          if (data['type'] == 'file' || data['type'] == 'audio') docsList.add(data);
        } catch (_) {}
      } else {
        final words = raw.split(RegExp(r'\s+'));
        for (final w in words) {
          if (w.startsWith('http://') || w.startsWith('https://')) {
            linksList.add(w);
          }
        }
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DefaultTabController(
          length: 3,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.75,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TabBar(
                  labelColor: AppTheme.brandBlue,
                  unselectedLabelColor: subtextColor,
                  indicatorColor: AppTheme.brandBlue,
                  tabs: [
                    Tab(text: 'Media (${mediaList.length})'),
                    Tab(text: 'Docs (${docsList.length})'),
                    Tab(text: 'Links (${linksList.length})'),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: TabBarView(
                    children: [
                      // Media tab
                      mediaList.isEmpty
                          ? Center(child: Text('No media shared yet', style: TextStyle(color: subtextColor)))
                          : GridView.builder(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 6,
                                mainAxisSpacing: 6,
                              ),
                              itemCount: mediaList.length,
                              itemBuilder: (context, i) {
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    color: AppTheme.brandBlue.withValues(alpha: 0.2),
                                    child: const Center(child: Icon(Icons.image, color: AppTheme.brandBlue)),
                                  ),
                                );
                              },
                            ),
                      // Docs tab
                      docsList.isEmpty
                          ? Center(child: Text('No documents shared yet', style: TextStyle(color: subtextColor)))
                          : ListView.builder(
                              itemCount: docsList.length,
                              itemBuilder: (context, i) {
                                final doc = docsList[i];
                                return ListTile(
                                  leading: const Icon(Icons.insert_drive_file_rounded, color: Color(0xFF8B5CF6)),
                                  title: Text(doc['name'] ?? 'Document', style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold)),
                                  subtitle: Text(doc['size'] ?? '', style: TextStyle(color: subtextColor, fontSize: 11)),
                                );
                              },
                            ),
                      // Links tab
                      linksList.isEmpty
                          ? Center(child: Text('No links shared yet', style: TextStyle(color: subtextColor)))
                          : ListView.builder(
                              itemCount: linksList.length,
                              itemBuilder: (context, i) {
                                final link = linksList[i];
                                return ListTile(
                                  leading: const Icon(Icons.link_rounded, color: AppTheme.brandBlue),
                                  title: Text(link, style: const TextStyle(color: AppTheme.brandBlue, fontSize: 13)),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.copy_rounded, size: 18),
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: link));
                                      _showSnack('Link copied');
                                    },
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 6. MUTE NOTIFICATIONS
  void _showMuteDialog() {
    String selected = _muteDuration;
    bool showNotif = true;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E283D) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? AppTheme.textMuted : const Color(0xFF64748B);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            backgroundColor: bg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('Mute notifications for...', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  title: Text('8 hours', style: TextStyle(color: textColor, fontSize: 14)),
                  value: '8 hours',
                  groupValue: selected,
                  activeColor: AppTheme.brandBlue,
                  onChanged: (v) => setDlgState(() => selected = v!),
                ),
                RadioListTile<String>(
                  title: Text('1 week', style: TextStyle(color: textColor, fontSize: 14)),
                  value: '1 week',
                  groupValue: selected,
                  activeColor: AppTheme.brandBlue,
                  onChanged: (v) => setDlgState(() => selected = v!),
                ),
                RadioListTile<String>(
                  title: Text('Always', style: TextStyle(color: textColor, fontSize: 14)),
                  value: 'Always',
                  groupValue: selected,
                  activeColor: AppTheme.brandBlue,
                  onChanged: (v) => setDlgState(() => selected = v!),
                ),
                const Divider(),
                CheckboxListTile(
                  title: Text('Show notifications', style: TextStyle(color: textColor, fontSize: 13)),
                  value: showNotif,
                  activeColor: AppTheme.brandBlue,
                  onChanged: (v) => setDlgState(() => showNotif = v ?? true),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: TextStyle(color: subtextColor)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.brandBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _isMuted = true;
                    _muteDuration = selected;
                  });
                  _showSnack('Notifications muted for $selected');
                },
                child: const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  // 7. DISAPPEARING MESSAGES
  void _showDisappearingMessagesSheet() {
    String selected = _disappearingTimer;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E283D) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? AppTheme.textMuted : const Color(0xFF64748B);

    showModalBottomSheet(
      context: context,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Icon(Icons.timer_outlined, size: 48, color: Color(0xFF8B5CF6)),
                const SizedBox(height: 12),
                Text('Disappearing messages', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 6),
                Text(
                  'For more privacy and storage, all new messages will disappear from this chat for everyone after the selected duration.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: subtextColor, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 16),
                ...['24 hours', '7 days', '90 days', 'Off'].map((val) => RadioListTile<String>(
                      title: Text(val, style: TextStyle(color: textColor, fontSize: 14)),
                      value: val,
                      groupValue: selected,
                      activeColor: AppTheme.brandBlue,
                      onChanged: (v) {
                        setSheetState(() => selected = v!);
                        setState(() => _disappearingTimer = selected);
                        Navigator.pop(ctx);
                        if (selected != 'Off') {
                          setState(() {
                            _messages.add({
                              'id': 'sys_${DateTime.now().millisecondsSinceEpoch}',
                              'isSystem': true,
                              'text': '🕒 You turned on disappearing messages ($selected). New messages will disappear from this chat.',
                              'time': _formatCurrentTime(),
                            });
                          });
                        }
                        _showSnack(selected == 'Off' ? 'Disappearing messages turned off' : 'Disappearing messages set to $selected');
                      },
                    )),
              ],
            ),
          );
        },
      ),
    );
  }

  // 8. CHAT THEME
  void _showChatThemeSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E283D) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    final themes = [
      {'name': 'Default', 'color': null},
      {'name': 'Emerald Green', 'color': const Color(0xFF0B241E)},
      {'name': 'Midnight Navy', 'color': const Color(0xFF0F172A)},
      {'name': 'Royal Indigo', 'color': const Color(0xFF1E1B4B)},
      {'name': 'Deep Amber', 'color': const Color(0xFF3B1515)},
      {'name': 'Charcoal OLED', 'color': const Color(0xFF000000)},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Chat theme', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: themes.map((t) {
                final Color? col = t['color'] as Color?;
                final isSelected = _customThemeColor == col;

                return GestureDetector(
                  onTap: () {
                    setState(() => _customThemeColor = col);
                    Navigator.pop(ctx);
                    _showSnack('Theme applied: ${t['name']}');
                  },
                  child: Container(
                    width: 90,
                    height: 80,
                    decoration: BoxDecoration(
                      color: col ?? (isDark ? AppTheme.bgDark : const Color(0xFFF8FAFC)),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? AppTheme.brandBlue : Colors.grey.withValues(alpha: 0.3),
                        width: isSelected ? 2.5 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      t['name'] as String,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: col != null ? Colors.white : textColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // 9. MORE OPTIONS (REPORT, BLOCK, CLEAR CHAT, EXPORT CHAT, ADD SHORTCUT)
  void _showMoreOptionsSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E283D) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    showModalBottomSheet(
      context: context,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.report_problem_outlined, color: AppTheme.accentCoral),
                title: Text('Report', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showReportDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.block_rounded, color: AppTheme.accentCoral),
                title: Text(_isBlocked ? 'Unblock' : 'Block', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _toggleBlockContact();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_sweep_outlined, color: AppTheme.accentCoral),
                title: Text('Clear chat', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showClearChatDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.download_rounded, color: AppTheme.brandBlue),
                title: Text('Export chat', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _exportChat();
                },
              ),
              ListTile(
                leading: const Icon(Icons.add_to_home_screen_rounded, color: Color(0xFF10B981)),
                title: Text('Add shortcut', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showSnack('Shortcut for ${widget.contactName} added to Home screen');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReportDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E283D) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? AppTheme.textMuted : const Color(0xFF64748B);
    bool blockAndClear = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: bg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Report ${widget.contactName}?', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The last 5 messages from this chat will be forwarded to CONNEKT Trust & Safety. This contact will not be notified.',
                style: TextStyle(color: subtextColor, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Block contact and delete chat', style: TextStyle(color: textColor, fontSize: 13)),
                value: blockAndClear,
                activeColor: AppTheme.accentCoral,
                onChanged: (val) => setDlgState(() => blockAndClear = val ?? true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: subtextColor)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentCoral,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                if (blockAndClear) {
                  setState(() {
                    _isBlocked = true;
                    _messages.clear();
                  });
                }
                _showSnack('Report sent. Thank you for keeping CONNEKT safe.');
              },
              child: const Text('Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleBlockContact() {
    if (_isBlocked) {
      setState(() => _isBlocked = false);
      _showSnack('Unblocked ${widget.contactName}');
    } else {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final bg = isDark ? const Color(0xFF1E283D) : Colors.white;
      final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
      final subtextColor = isDark ? AppTheme.textMuted : const Color(0xFF64748B);

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: bg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Block ${widget.contactName}?', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
          content: Text(
            'Blocked contacts will no longer be able to call you or send you messages.',
            style: TextStyle(color: subtextColor, fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: subtextColor)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentCoral,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                setState(() => _isBlocked = true);
                _showSnack('Blocked ${widget.contactName}');
              },
              child: const Text('Block', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  void _showClearChatDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E283D) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? AppTheme.textMuted : const Color(0xFF64748B);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Clear this chat?', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
        content: Text(
          'Messages will be deleted from your chat history.',
          style: TextStyle(color: subtextColor, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: subtextColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentCoral,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _messages.clear());
              _showSnack('Chat cleared');
            },
            child: const Text('Clear chat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _exportChat() {
    final buffer = StringBuffer();
    buffer.writeln('--- CONNEKT Chat with ${widget.contactName} ---');
    buffer.writeln('Exported on ${DateTime.now()}');
    buffer.writeln('');
    for (final m in _messages) {
      final sender = m['isMe'] == true ? 'You' : widget.contactName;
      final time = m['time'] ?? '';
      final text = m['text'] ?? '';
      buffer.writeln('[$time] $sender: $text');
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    _showSnack('Chat transcript copied to clipboard');
  }

  // 10. VOICE & VIDEO CALL
  void _startCall({required bool isVideo}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: bg,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isVideo ? 'CONNEKT Video Call' : 'CONNEKT Voice Call',
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              SafeAvatar(url: widget.avatarUrl, fallbackText: widget.contactName, size: 84, radius: 42),
              const SizedBox(height: 16),
              Text(
                widget.contactName,
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Ringing...',
                style: TextStyle(color: Color(0xFF10B981), fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 36),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white12,
                    radius: 26,
                    child: Icon(isVideo ? Icons.videocam_off_rounded : Icons.mic_off_rounded, color: Colors.white),
                  ),
                  const CircleAvatar(
                    backgroundColor: Colors.white12,
                    radius: 26,
                    child: Icon(Icons.volume_up_rounded, color: Colors.white),
                  ),
                  CircleAvatar(
                    backgroundColor: AppTheme.accentCoral,
                    radius: 30,
                    child: IconButton(
                      icon: const Icon(Icons.call_end_rounded, color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ====================================================================
  // MESSAGE DELETION (DELETE FOR ME / DELETE FOR EVERYONE)
  // ====================================================================

  void _showMessageActionSheet(Map<String, dynamic> msg, String msgId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E283D) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final rawText = (msg['text'] ?? '').toString();

    showModalBottomSheet(
      context: context,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  rawText.startsWith('{') ? 'Attachment' : rawText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppTheme.accentCoral),
                title: const Text('Delete message', style: TextStyle(color: AppTheme.accentCoral, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDeleteMessagesDialog(singleMsgId: msgId);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded, color: AppTheme.brandBlue),
                title: Text('Copy text', style: TextStyle(color: textColor)),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: rawText));
                  _showSnack('Copied to clipboard');
                },
              ),
              ListTile(
                leading: const Icon(Icons.star_outline_rounded, color: Color(0xFFEAB308)),
                title: Text('Star message', style: TextStyle(color: textColor)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showSnack('Message starred');
                },
              ),
              ListTile(
                leading: const Icon(Icons.check_box_outlined, color: AppTheme.brandBlue),
                title: Text('Select messages', style: TextStyle(color: textColor)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _isSelectionMode = true;
                    _selectedMsgIds.clear();
                    _selectedMsgIds.add(msgId);
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteMessagesDialog({String? singleMsgId}) {
    final idsToDelete = singleMsgId != null ? {singleMsgId} : Set<String>.from(_selectedMsgIds);
    if (idsToDelete.isEmpty) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E283D) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? AppTheme.textMuted : const Color(0xFF64748B);

    final hasMyMessages = _messages.any(
      (m) => idsToDelete.contains((m['id'] ?? '').toString()) && m['isMe'] == true,
    );

    final title = idsToDelete.length == 1 ? 'Delete message?' : 'Delete ${idsToDelete.length} messages?';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
        content: Text(
          hasMyMessages
              ? 'You can delete this message for everyone or delete it just for yourself.'
              : 'Delete this message from your chat history?',
          style: TextStyle(color: subtextColor, fontSize: 13, height: 1.4),
        ),
        actions: [
          // 1. Delete for everyone (shown if sent by Me)
          if (hasMyMessages)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _executeDeleteMessages(idsToDelete, forEveryone: true);
              },
              child: const Text(
                'Delete for everyone',
                style: TextStyle(color: AppTheme.accentCoral, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          // 2. Delete for me (always available)
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _executeDeleteMessages(idsToDelete, forEveryone: false);
            },
            child: Text(
              'Delete for me',
              style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          // 3. Cancel
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: subtextColor, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  void _executeDeleteMessages(Set<String> ids, {required bool forEveryone}) {
    setState(() {
      for (final id in ids) {
        _deletedMsgModes[id] = forEveryone;
      }
      // Remove deleted messages completely so nothing appears (like nothing was sent).
      _messages.removeWhere((m) {
        final id = (m['id'] ?? '').toString();
        if (!ids.contains(id)) return false;
        return !forEveryone || m['isMe'] == true;
      });
      _isSelectionMode = false;
      _selectedMsgIds.clear();
    });

    for (final id in ids) {
      if (!id.startsWith('temp_')) {
        ApiService.deleteChatMessage(id, forEveryone: forEveryone);
      }
    }

    _showSnack(forEveryone
        ? 'Message deleted for everyone'
        : 'Message deleted for you');
  }

  // ====================================================================
  // GROUP CHAT 3-DOTS OVERFLOW MENU (WHATSAPP FEATURES)
  // ====================================================================

  Widget _buildGroupChatMenu(bool isDark, Color textColor) {
    final menuBg = isDark ? const Color(0xFF1F2733) : Colors.white;
    final itemTextColor = isDark ? const Color(0xFFE9EDEF) : const Color(0xFF1E293B);

    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded, color: textColor, size: 22),
      color: menuBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      offset: const Offset(0, 48),
      elevation: 8,
      onSelected: (value) => _handleGroupMenuSelection(value),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'add_member',
          child: Row(
            children: [
              Icon(Icons.person_add_alt_1_outlined, color: itemTextColor, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text('Add member', style: TextStyle(color: itemTextColor, fontSize: 14))),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'group_info',
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: itemTextColor, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text('Group info', style: TextStyle(color: itemTextColor, fontSize: 14))),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'search',
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: itemTextColor, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text('Search', style: TextStyle(color: itemTextColor, fontSize: 14))),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'select_messages',
          child: Row(
            children: [
              Icon(Icons.check_box_outlined, color: itemTextColor, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text('Select messages', style: TextStyle(color: itemTextColor, fontSize: 14))),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'mute',
          child: Row(
            children: [
              Icon(Icons.notifications_off_outlined, color: itemTextColor, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text('Mute notifications', style: TextStyle(color: itemTextColor, fontSize: 14))),
              Icon(Icons.arrow_right_rounded, color: itemTextColor.withValues(alpha: 0.6), size: 20),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'disappearing',
          child: Row(
            children: [
              Icon(Icons.timelapse_rounded, color: itemTextColor, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text('Disappearing messages', style: TextStyle(color: itemTextColor, fontSize: 14))),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'theme',
          child: Row(
            children: [
              Icon(Icons.palette_outlined, color: itemTextColor, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text('Chat theme', style: TextStyle(color: itemTextColor, fontSize: 14))),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'favourites',
          child: Row(
            children: [
              Icon(_isFavourite ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: _isFavourite ? AppTheme.accentCoral : itemTextColor, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(_isFavourite ? 'Remove from favourites' : 'Add to favourites', style: TextStyle(color: itemTextColor, fontSize: 14))),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'add_to_list',
          child: Row(
            children: [
              Icon(Icons.add_photo_alternate_outlined, color: itemTextColor, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text('Add to list', style: TextStyle(color: itemTextColor, fontSize: 14))),
              Icon(Icons.arrow_right_rounded, color: itemTextColor.withValues(alpha: 0.6), size: 20),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'export',
          child: Row(
            children: [
              Icon(Icons.file_download_outlined, color: itemTextColor, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text('Export chat', style: TextStyle(color: itemTextColor, fontSize: 14))),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'close',
          child: Row(
            children: [
              Icon(Icons.highlight_off_rounded, color: itemTextColor, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text('Close chat', style: TextStyle(color: itemTextColor, fontSize: 14))),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'clear',
          child: Row(
            children: [
              Icon(Icons.remove_circle_outline_rounded, color: itemTextColor, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text('Clear chat', style: TextStyle(color: itemTextColor, fontSize: 14))),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'exit',
          child: Row(
            children: [
              const Icon(Icons.logout_rounded, color: AppTheme.accentCoral, size: 20),
              const SizedBox(width: 12),
              const Expanded(child: Text('Exit group', style: TextStyle(color: AppTheme.accentCoral, fontSize: 14, fontWeight: FontWeight.bold))),
            ],
          ),
        ),
      ],
    );
  }

  void _handleGroupMenuSelection(String value) {
    switch (value) {
      case 'add_member':
        _showAddMemberSheet();
        break;
      case 'group_info':
        _showGroupInfoSheet();
        break;
      case 'search':
        _startSearch();
        break;
      case 'select_messages':
        _startSelectionMode();
        break;
      case 'mute':
        _showMuteDialog();
        break;
      case 'disappearing':
        _showDisappearingMessagesSheet();
        break;
      case 'theme':
        _showChatThemeSheet();
        break;
      case 'favourites':
        _toggleFavourites();
        break;
      case 'add_to_list':
        _showAddToListDialog();
        break;
      case 'export':
        _exportChat();
        break;
      case 'close':
        Navigator.pop(context);
        break;
      case 'clear':
        _showClearChatDialog();
        break;
      case 'exit':
        _showExitGroupDialog();
        break;
    }
  }

  void _startSelectionMode() {
    setState(() {
      _isSelectionMode = true;
      _selectedMsgIds.clear();
      if (_messages.isNotEmpty) {
        _selectedMsgIds.add((_messages.last['id'] ?? '0').toString());
      }
    });
  }

  void _toggleFavourites() {
    setState(() => _isFavourite = !_isFavourite);
    _showSnack(_isFavourite ? 'Group added to Favourites' : 'Group removed from Favourites');
  }

  void _showAddMemberSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E283D) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? AppTheme.textMuted : const Color(0xFF64748B);

    final availableContacts = [
      {'name': 'Alex Chen', 'phone': '+91 98301 98765'},
      {'name': 'Priya Sharma', 'phone': '+91 98312 34567'},
      {'name': 'Rahul Verma', 'phone': '+91 98365 43210'},
      {'name': 'David Kim', 'phone': '+91 98300 11223'},
      {'name': 'Koushiki Podder', 'phone': '+91 98368 28816'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Add members', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 6),
            Text('Select contacts to add to "${widget.contactName}"', style: TextStyle(color: subtextColor, fontSize: 12)),
            const SizedBox(height: 14),
            ...availableContacts.map((c) {
              final alreadyIn = _groupMembers.contains(c['name']);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: SafeAvatar(url: null, fallbackText: c['name']!, size: 40, radius: 20),
                title: Text(c['name']!, style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(c['phone']!, style: TextStyle(color: subtextColor, fontSize: 11)),
                trailing: alreadyIn
                    ? Text('Added', style: TextStyle(color: subtextColor, fontSize: 12, fontWeight: FontWeight.w600))
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.brandBlue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _groupMembers.add(c['name']!);
                            _messages.add({
                              'id': 'sys_${DateTime.now().millisecondsSinceEpoch}',
                              'isSystem': true,
                              'text': '👤 You added ${c['name']} to the group',
                              'time': _formatCurrentTime(),
                            });
                          });
                          _showSnack('Added ${c['name']} to group');
                        },
                        child: const Text('Add', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
              );
            }),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _showGroupInfoSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E283D) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? AppTheme.textMuted : const Color(0xFF64748B);
    final cardBg = isDark ? const Color(0xFF121A2B) : const Color(0xFFF8FAFC);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Group Avatar & Title
            Center(
              child: Column(
                children: [
                  SafeAvatar(
                    url: widget.avatarUrl,
                    fallbackText: widget.contactName,
                    fallbackIcon: Icons.group,
                    size: 96,
                    radius: 48,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.contactName,
                    style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Group • ${_groupMembers.length} participants',
                    style: TextStyle(color: subtextColor, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Action Buttons Row: Video, Audio, Add, Search
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildContactActionButton(Icons.videocam_rounded, 'Video', () {
                  Navigator.pop(ctx);
                  _startGroupCall(isVideo: true);
                }, isDark),
                _buildContactActionButton(Icons.call_rounded, 'Voice', () {
                  Navigator.pop(ctx);
                  _startGroupCall(isVideo: false);
                }, isDark),
                _buildContactActionButton(Icons.person_add_alt_1_rounded, 'Add', () {
                  Navigator.pop(ctx);
                  _showAddMemberSheet();
                }, isDark),
                _buildContactActionButton(Icons.search_rounded, 'Search', () {
                  Navigator.pop(ctx);
                  _startSearch();
                }, isDark),
              ],
            ),
            const SizedBox(height: 24),

            // Description
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Description', style: TextStyle(color: subtextColor, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('Official group for CONNEKT team updates, file sharing, and project discussions.', style: TextStyle(color: textColor, fontSize: 13, height: 1.4)),
                  const SizedBox(height: 4),
                  Text('Created by You', style: TextStyle(color: subtextColor, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Media, links, and docs
            ListTile(
              tileColor: cardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              leading: const Icon(Icons.perm_media_outlined, color: AppTheme.brandBlue),
              title: Text('Media, links, and docs', style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
              onTap: () {
                Navigator.pop(ctx);
                _showMediaLinksDocsSheet();
              },
            ),
            const SizedBox(height: 10),

            // Mute & Disappearing
            ListTile(
              tileColor: cardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              leading: const Icon(Icons.notifications_off_outlined, color: AppTheme.accentCoral),
              title: Text('Mute notifications', style: TextStyle(color: textColor, fontSize: 14)),
              subtitle: Text(_isMuted ? 'Muted ($_muteDuration)' : 'No', style: TextStyle(color: subtextColor, fontSize: 12)),
              trailing: Switch(
                value: _isMuted,
                activeColor: AppTheme.brandBlue,
                onChanged: (val) {
                  Navigator.pop(ctx);
                  _showMuteDialog();
                },
              ),
            ),
            const SizedBox(height: 10),

            ListTile(
              tileColor: cardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              leading: const Icon(Icons.timelapse_rounded, color: Color(0xFF8B5CF6)),
              title: Text('Disappearing messages', style: TextStyle(color: textColor, fontSize: 14)),
              subtitle: Text(_disappearingTimer, style: TextStyle(color: subtextColor, fontSize: 12)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
              onTap: () {
                Navigator.pop(ctx);
                _showDisappearingMessagesSheet();
              },
            ),
            const SizedBox(height: 16),

            // Participants List Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text('${_groupMembers.length} participants', style: TextStyle(color: subtextColor, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 6),

            // Add Participant Row
            ListTile(
              tileColor: cardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              leading: CircleAvatar(
                backgroundColor: AppTheme.brandBlue.withValues(alpha: 0.15),
                child: const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.brandBlue, size: 20),
              ),
              title: const Text('Add participant', style: TextStyle(color: AppTheme.brandBlue, fontSize: 14, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(ctx);
                _showAddMemberSheet();
              },
            ),
            const SizedBox(height: 8),

            // Member Tiles
            ..._groupMembers.map((member) {
              final isYou = member == 'You';
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  tileColor: cardBg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: SafeAvatar(url: null, fallbackText: member, size: 38, radius: 19),
                  title: Row(
                    children: [
                      Text(member, style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600)),
                      if (isYou) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.brandBlue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Group Admin', style: TextStyle(color: AppTheme.brandBlue, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(isYou ? 'Hey there! I am using CONNEKT' : 'Available', style: TextStyle(color: subtextColor, fontSize: 11)),
                ),
              );
            }),
            const SizedBox(height: 16),

            // Exit group
            ListTile(
              tileColor: cardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              leading: const Icon(Icons.logout_rounded, color: AppTheme.accentCoral),
              title: const Text('Exit group', style: TextStyle(color: AppTheme.accentCoral, fontWeight: FontWeight.bold, fontSize: 14)),
              onTap: () {
                Navigator.pop(ctx);
                _showExitGroupDialog();
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showAddToListDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E283D) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? AppTheme.textMuted : const Color(0xFF64748B);

    final lists = ['💼 Work', '🏠 Personal', '🎓 Study', '⭐ Priority', '👥 Team'];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Add to list', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: lists.map((l) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l, style: TextStyle(color: textColor, fontSize: 14)),
            trailing: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.brandBlue, size: 20),
            onTap: () {
              Navigator.pop(ctx);
              _showSnack('Added "${widget.contactName}" to $l');
            },
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: subtextColor)),
          ),
        ],
      ),
    );
  }

  void _showExitGroupDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E283D) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? AppTheme.textMuted : const Color(0xFF64748B);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Exit "${widget.contactName}" group?', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
        content: Text(
          'Only group admins will be notified that you left the group.',
          style: TextStyle(color: subtextColor, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: subtextColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentCoral,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _hasLeftGroup = true;
                _messages.add({
                  'id': 'sys_${DateTime.now().millisecondsSinceEpoch}',
                  'isSystem': true,
                  'text': 'You left the group.',
                  'time': _formatCurrentTime(),
                });
              });
              _showSnack('You left the group');
            },
            child: const Text('Exit group', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _startGroupCall({required bool isVideo}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: bg,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isVideo ? 'CONNEKT Group Video Call' : 'CONNEKT Group Conference Call',
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              // Participants avatars row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _groupMembers.take(4).map((m) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: SafeAvatar(url: null, fallbackText: m, size: 52, radius: 26),
                )).toList(),
              ),
              const SizedBox(height: 16),
              Text(
                widget.contactName,
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Calling ${_groupMembers.length} participants...',
                style: const TextStyle(color: Color(0xFF10B981), fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 36),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white12,
                    radius: 26,
                    child: Icon(isVideo ? Icons.videocam_off_rounded : Icons.mic_off_rounded, color: Colors.white),
                  ),
                  const CircleAvatar(
                    backgroundColor: Colors.white12,
                    radius: 26,
                    child: Icon(Icons.volume_up_rounded, color: Colors.white),
                  ),
                  CircleAvatar(
                    backgroundColor: AppTheme.accentCoral,
                    radius: 30,
                    child: IconButton(
                      icon: const Icon(Icons.call_end_rounded, color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
