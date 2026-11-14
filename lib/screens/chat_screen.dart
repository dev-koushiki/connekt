import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../config/api_config.dart';
import '../config/app_theme.dart';
import '../config/subnet_probe_stub.dart' if (dart.library.io) '../config/subnet_probe_io.dart';
import '../services/api_service.dart';
import '../services/voice_audio_service.dart';
import '../services/chat_theme_service.dart';
import '../widgets/safe_avatar.dart';
import '../widgets/translatable_text_widget.dart';
import '../widgets/whatsapp_emoji_sticker_picker.dart';
import '../widgets/whatsapp_doodle_painter.dart';
import 'chat_theme_screen.dart';
import 'image_preview_send_screen.dart';

class ChatScreen extends StatefulWidget {
  final String contactName;
  final String avatarUrl;
  final bool showBackButton;
  final bool isGroup;
  final List<String> initialMembers;
  final String? conversationId;
  final String groupDescription;
  final String? contactPhone;

  const ChatScreen({
    super.key,
    this.contactName = 'Lena Rivers',
    this.avatarUrl = 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=120',
    this.showBackButton = true,
    this.isGroup = false,
    this.initialMembers = const ['You', 'Soumo', 'Lena Rivers', 'David Kim'],
    this.conversationId,
    this.groupDescription = '',
    this.contactPhone,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  String get _effectiveTarget {
    if (widget.conversationId != null && widget.conversationId!.isNotEmpty) {
      return widget.conversationId!;
    }
    if (widget.contactPhone != null && widget.contactPhone!.isNotEmpty) {
      return widget.contactPhone!;
    }
    return widget.contactName;
  }

  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;

  // Voice recording state
  bool _isRecording = false;
  bool _isSendingVoice = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  Timer? _amplitudeTimer;
  final List<double> _liveWaveform = List<double>.filled(14, 0.25);

  // Audio playback state
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
  late String _groupDescription;
  late String _groupTitle;
  String? _groupAvatarUrl;
  File? _groupAvatarLocalFile;
  final Set<String> _groupAdmins = {'You'};
  bool _onlyAdminsCanEditInfo = false;
  bool _onlyAdminsCanSendMessages = false;
  bool _requireAdminApproval = false;
  bool _isPendingInvite = false;
  bool _isRespondingInvite = false;
  List<Map<String, dynamic>> _participants = [];
  bool _isFavourite = false;
  bool _hasLeftGroup = false;

  // WhatsApp Emoji & Sticker picker state
  bool _showEmojiPicker = false;
  final FocusNode _focusNode = FocusNode();

  // WhatsApp Quoted Reply state
  Map<String, dynamic>? _replyingToMessage;

  // WhatsApp Pinned Message state
  Map<String, dynamic>? _pinnedMessage;

  // Voice Note Playback Speed state (1x, 1.5x, 2x)
  double _voicePlaybackSpeed = 1.0;

  @override
  void initState() {
    super.initState();
    _groupTitle = widget.contactName;
    _groupAvatarUrl = widget.avatarUrl;
    _groupMembers = List.from(widget.initialMembers);
    _groupDescription = widget.groupDescription;
    _groupAdmins.clear();
    _groupAdmins.add('You');
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _showEmojiPicker) {
        setState(() => _showEmojiPicker = false);
      }
    });
    _loadHistory();
    final initialConvId = widget.conversationId;
    if (initialConvId != null && initialConvId.isNotEmpty) {
      ApiService.markConversationAsRead(initialConvId);
    }
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
    _focusNode.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _recordTimer?.cancel();
    _amplitudeTimer?.cancel();
    _playTimer?.cancel();
    if (_isRecording && !isFlutterTestEnv) {
      unawaited(VoiceAudioService.stopRecording(discard: true));
    }
    if (_playingMsgId != null && !isFlutterTestEnv) {
      unawaited(VoiceAudioService.stopPlayback());
    }
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
      final lookupTarget = _effectiveTarget;

      Map<String, dynamic>? details;
      List<Map<String, dynamic>> rawHistory;

      if (!isFlutterTestEnv) {
        details = await ApiService.getChatDetails(lookupTarget);
      }

      if (details != null && details['messages'] is List) {
        rawHistory = (details['messages'] as List).map((m) => Map<String, dynamic>.from(m as Map)).toList();
      } else {
        rawHistory = await ApiService.getChatMessages(lookupTarget);
      }

      if (details != null) {
        if (details['conversation'] is Map) {
          final conv = details['conversation'] as Map<String, dynamic>;
          final cId = (conv['id'] ?? widget.conversationId)?.toString();
          if (cId != null && cId.isNotEmpty) {
            ApiService.markConversationAsRead(cId);
          }
          final desc = (conv['description'] ?? '').toString();
          if (desc.isNotEmpty) _groupDescription = desc;
          final title = (conv['title'] ?? '').toString();
          if (title.isNotEmpty) _groupTitle = title;
          if (widget.isGroup) {
            _isPendingInvite = conv['participant_status'] == 'pending';
          }
        }
        if (details['participants'] is List) {
          _participants = (details['participants'] as List)
              .map((p) => Map<String, dynamic>.from(p as Map))
              .toList();
          if (_participants.isNotEmpty) {
            final names = _participants.map((p) => (p['name'] ?? 'Member').toString()).toList();
            _groupMembers = ['You', ...names.where((n) => n != 'You' && n != 'Admin')];
            for (final p in _participants) {
              final role = (p['role'] ?? '').toString();
              final name = (p['name'] ?? '').toString();
              if (role == 'admin' && name.isNotEmpty) {
                _groupAdmins.add(name);
              }
            }
          }
        }
      }

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

  Future<void> _acceptInvitation() async {
    final convId = widget.conversationId;
    if (convId == null || convId.isEmpty) {
      setState(() => _isPendingInvite = false);
      return;
    }
    setState(() => _isRespondingInvite = true);
    final success = await ApiService.respondToGroupInvite(convId, accept: true);
    if (mounted) {
      setState(() {
        _isRespondingInvite = false;
        if (success || isFlutterTestEnv) {
          _isPendingInvite = false;
        }
      });
      if (success || isFlutterTestEnv) {
        _loadHistory();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You joined the group!')),
        );
      }
    }
  }

  Future<void> _declineInvitation() async {
    final convId = widget.conversationId;
    if (convId != null && convId.isNotEmpty) {
      await ApiService.respondToGroupInvite(convId, accept: false);
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Widget _buildInvitationBanner(bool isDark, Color textColor, Color subtextColor) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E283D) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.brandBlue.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.brandBlue.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mail_outline_rounded, color: AppTheme.brandBlue, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Group Invitation',
                  style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.hourglass_top_rounded, color: Colors.amber, size: 12),
                    SizedBox(width: 4),
                    Text('Pending', style: TextStyle(color: Colors.amber, fontSize: 10.5, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'You were invited to join "${widget.contactName}". Accept the invitation to join the conversation and receive messages.',
            style: TextStyle(color: textColor, fontSize: 12.5, height: 1.35),
          ),
          if (_groupDescription.isNotEmpty || widget.groupDescription.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'About: ${_groupDescription.isNotEmpty ? _groupDescription : widget.groupDescription}',
              style: TextStyle(color: subtextColor, fontSize: 11.5, fontStyle: FontStyle.italic),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _isRespondingInvite ? null : _declineInvitation,
                child: const Text('Decline', style: TextStyle(color: AppTheme.accentCoral, fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D4ED8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                onPressed: _isRespondingInvite ? null : _acceptInvitation,
                icon: _isRespondingInvite
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                label: Text(
                  _isRespondingInvite ? 'Joining...' : 'Accept & Join',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingInviteBottomBar(bool isDark, Color textColor, Color subtextColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E283D) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 20, color: AppTheme.brandBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Accept invitation to send and receive messages.',
              style: TextStyle(color: subtextColor, fontSize: 12.5),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D4ED8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _isRespondingInvite ? null : _acceptInvitation,
            child: Text(
              _isRespondingInvite ? 'Joining...' : 'Accept',
              style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
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

  String _getReplySnippet(Map<String, dynamic> msg) {
    final rawText = (msg['text'] ?? '').toString();
    if (rawText.startsWith('{') && rawText.endsWith('}')) {
      try {
        final data = jsonDecode(rawText);
        final type = data['type'];
        if (type == 'image') return '📷 Photo';
        if (type == 'video') return '🎥 Video';
        if (type == 'media_album') return '🖼️ Photos & Videos';
        if (type == 'voice') return '🎤 Voice message';
        if (type == 'audio') return '🎵 Audio';
        if (type == 'file') return '📄 ${data['name'] ?? 'Document'}';
        if (type == 'location') return '📍 Location';
        if (type == 'contact') return '👤 ${data['name'] ?? 'Contact'}';
        if (type == 'poll') return '📊 Poll: ${data['question'] ?? ''}';
        if (type == 'sticker') return '💟 Sticker';
      } catch (_) {}
    }
    return rawText;
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final replyQuote = _replyingToMessage != null
        ? {
            'id': _replyingToMessage!['id'],
            'sender': _replyingToMessage!['isMe'] == true ? 'You' : widget.contactName,
            'text': _getReplySnippet(_replyingToMessage!),
          }
        : null;

    final tempMsg = {
      'id': tempId,
      'isMe': true,
      'text': text,
      'time': _formatCurrentTime(),
      'isRead': false,
      'replyTo': ?replyQuote,
    };

    setState(() {
      _messages.add(tempMsg);
      _msgController.clear();
      _replyingToMessage = null;
    });
    _scrollToBottom();

    _dispatchToBackend(text, tempId: tempId);
  }

  Future<void> _sendRichMessage(Map<String, dynamic> richData) async {
    if (_replyingToMessage != null) {
      richData['replyTo'] = {
        'id': _replyingToMessage!['id'],
        'sender': _replyingToMessage!['isMe'] == true ? 'You' : widget.contactName,
        'text': _getReplySnippet(_replyingToMessage!),
      };
    }
    final jsonStr = jsonEncode(richData);
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempMsg = {
      'id': tempId,
      'isMe': true,
      'text': jsonStr,
      'time': _formatCurrentTime(),
      'isRead': false,
      if (richData.containsKey('replyTo')) 'replyTo': richData['replyTo'],
    };

    setState(() {
      _messages.add(tempMsg);
      _replyingToMessage = null;
    });
    _scrollToBottom();

    _dispatchToBackend(jsonStr, tempId: tempId);
  }

  Future<void> _dispatchToBackend(String payloadText, {required String tempId}) async {
    try {
      final target = _effectiveTarget;
      final res = await ApiService.sendChatMessage(target, payloadText);
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
        final phone = res['recipientPhone'] ?? widget.contactPhone ?? widget.contactName;
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
  // WHATSAPP EMOJI & STICKER ACTIONS
  // ====================================================================

  void _toggleEmojiPicker() {
    if (_showEmojiPicker) {
      setState(() => _showEmojiPicker = false);
      _focusNode.requestFocus();
    } else {
      FocusScope.of(context).unfocus();
      setState(() => _showEmojiPicker = true);
    }
  }

  void _onEmojiSelected(String emoji) {
    final text = _msgController.text;
    final selection = _msgController.selection;
    if (selection.start >= 0 && selection.end >= 0) {
      final newText = text.replaceRange(selection.start, selection.end, emoji);
      final newOffset = selection.start + emoji.length;
      _msgController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newOffset),
      );
    } else {
      _msgController.text = text + emoji;
      _msgController.selection = TextSelection.collapsed(offset: _msgController.text.length);
    }
  }

  void _onEmojiBackspace() {
    final text = _msgController.text;
    final textSelection = _msgController.selection;
    final selectionLength = textSelection.end - textSelection.start;

    if (selectionLength > 0) {
      final newText = text.replaceRange(textSelection.start, textSelection.end, '');
      _msgController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: textSelection.start),
      );
      return;
    }

    if (textSelection.start <= 0) return;

    final runes = text.runes.toList();
    if (runes.isNotEmpty) {
      runes.removeLast();
      final newString = String.fromCharCodes(runes);
      _msgController.value = TextEditingValue(
        text: newString,
        selection: TextSelection.collapsed(offset: newString.length),
      );
    }
  }

  void _onStickerSelected(WhatsAppStickerItem sticker) {
    _sendRichMessage({
      'type': 'sticker',
      'sticker': sticker.emoji,
      'title': sticker.title,
      'pack': sticker.pack,
    });
  }

  bool _isSticker(Map<String, dynamic> msg) {
    final rawText = (msg['text'] ?? '').toString();
    if (rawText.startsWith('{') && rawText.endsWith('}')) {
      try {
        final data = jsonDecode(rawText);
        return data['type'] == 'sticker';
      } catch (_) {}
    }
    return false;
  }

  // ====================================================================
  // MICROPHONE (VOICE NOTE RECORDING & PLAYBACK)
  // ====================================================================

  Future<void> _startVoiceRecording() async {
    if (!isFlutterTestEnv) {
      if (_playingMsgId != null) {
        await VoiceAudioService.stopPlayback();
        _playTimer?.cancel();
        if (mounted) {
          setState(() {
            _playingMsgId = null;
            _playProgress = 0.0;
          });
        }
      }

      final startRes = await VoiceAudioService.startRecording();
      if (!mounted) return;
      if (!startRes.granted) {
        _showSnack('Microphone permission is required to record voice notes.');
        return;
      }
      if (!startRes.started) {
        _showSnack(startRes.error ?? 'Could not start audio recording.');
        return;
      }
    }

    setState(() {
      _isRecording = true;
      _recordSeconds = 0;
      for (var i = 0; i < _liveWaveform.length; i++) {
        _liveWaveform[i] = 0.25;
      }
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

    _amplitudeTimer?.cancel();
    if (!isFlutterTestEnv) {
      _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 140), (timer) async {
        if (!mounted || !_isRecording) {
          timer.cancel();
          return;
        }
        final amp = await VoiceAudioService.getAmplitude();
        if (!mounted || !_isRecording) return;
        setState(() {
          _liveWaveform.removeAt(0);
          _liveWaveform.add(amp.clamp(0.15, 1.0));
        });
      });
    }
  }

  Future<void> _cancelVoiceRecording() async {
    _recordTimer?.cancel();
    _amplitudeTimer?.cancel();
    if (!isFlutterTestEnv) {
      await VoiceAudioService.stopRecording(discard: true);
    }
    if (!mounted) return;
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

  Future<void> _finishAndSendVoiceRecording() async {
    if (_isSendingVoice) return;
    _isSendingVoice = true;
    _recordTimer?.cancel();
    _amplitudeTimer?.cancel();

    final durationSecs = max(_recordSeconds, 1);
    final mins = durationSecs ~/ 60;
    final secs = durationSecs % 60;
    final durationStr = '$mins:${secs.toString().padLeft(2, '0')}';

    String localPath = '';
    String? uploadedUrl;

    if (!isFlutterTestEnv) {
      final stopRes = await VoiceAudioService.stopRecording(discard: false);
      localPath = stopRes.filePath ?? '';
      if (localPath.isEmpty || stopRes.sizeBytes <= 0) {
        _isSendingVoice = false;
        if (mounted) {
          setState(() {
            _isRecording = false;
            _recordSeconds = 0;
          });
          _showSnack('No audio was captured. Please allow microphone access and try again.');
        }
        return;
      }
    }

    if (mounted) {
      setState(() {
        _isRecording = false;
        _recordSeconds = 0;
      });
    }

    if (!isFlutterTestEnv && localPath.isNotEmpty) {
      final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final upRes = await ApiService.uploadChatFile(localPath, fileName);
      uploadedUrl = upRes?['url']?.toString();
    }

    _isSendingVoice = false;
    _sendRichMessage({
      'type': 'voice',
      'duration': durationStr,
      'seconds': durationSecs,
      if (uploadedUrl != null && uploadedUrl.isNotEmpty) 'url': uploadedUrl,
      if (localPath.isNotEmpty) 'localPath': localPath,
    });
  }

  void _cycleVoicePlaybackSpeed() {
    setState(() {
      if (_voicePlaybackSpeed == 1.0) {
        _voicePlaybackSpeed = 1.5;
      } else if (_voicePlaybackSpeed == 1.5) {
        _voicePlaybackSpeed = 2.0;
      } else {
        _voicePlaybackSpeed = 1.0;
      }
    });
    VoiceAudioService.setPlaybackRate(_voicePlaybackSpeed);
  }

  Future<void> _togglePlayVoiceNote(
    String msgId,
    int durationSeconds, {
    String audioUrl = '',
    String localPath = '',
  }) async {
    if (_playingMsgId == msgId) {
      _playTimer?.cancel();
      if (!isFlutterTestEnv) {
        await VoiceAudioService.stopPlayback();
      }
      if (!mounted) return;
      setState(() {
        _playingMsgId = null;
        _playProgress = 0.0;
      });
      return;
    }

    _playTimer?.cancel();

    final resolvedUrl = audioUrl.startsWith('/') ? '${ApiConfig.rootUrl}$audioUrl' : audioUrl;
    final hasPlayableAudio = localPath.isNotEmpty || isValidHttpUrl(resolvedUrl);

    if (!isFlutterTestEnv) {
      if (!hasPlayableAudio) {
        _showSnack('No playable audio file attached to this voice note.');
        return;
      }

      setState(() {
        _playingMsgId = msgId;
        _playProgress = 0.0;
      });

      final primarySource = localPath.isNotEmpty ? localPath : resolvedUrl;
      final fallbackSource = localPath.isNotEmpty && isValidHttpUrl(resolvedUrl) ? resolvedUrl : '';

      final startedDurationMs = await VoiceAudioService.play(
        primarySource,
        fallbackSource: fallbackSource,
        onComplete: () {
          _playTimer?.cancel();
          if (mounted) {
            setState(() {
              _playingMsgId = null;
              _playProgress = 0.0;
            });
          }
        },
      );

      if (startedDurationMs == null) {
        if (mounted) {
          setState(() {
            _playingMsgId = null;
            _playProgress = 0.0;
          });
          _showSnack('Unable to play audio.');
        }
        return;
      }

      _playTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) async {
        if (!mounted || _playingMsgId != msgId) {
          timer.cancel();
          return;
        }
        final status = await VoiceAudioService.getPlaybackStatus();
        if (!mounted || _playingMsgId != msgId) {
          timer.cancel();
          return;
        }
        setState(() {
          if (status.durationMs > 0) {
            _playProgress = status.progress;
          }
          if (!status.isPlaying && _playProgress > 0.05) {
            _playingMsgId = null;
            _playProgress = 0.0;
            timer.cancel();
          }
        });
      });
      return;
    }

    setState(() {
      _playingMsgId = msgId;
      _playProgress = 0.0;
    });

    const stepMs = 100;
    final totalSteps = max((durationSeconds * 1000) / stepMs, 1.0);

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
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF475569) : Colors.black26,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 2 Rows x 3 Columns CONNEKT Theme Attachment Grid (Document, Camera, Gallery, Audio, Location, Contact)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildAttachmentItem(
                      icon: Icons.description_rounded,
                      label: 'Document',
                      gradient: const [Color(0xFF4338CA), Color(0xFF6366F1)],
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickDocument();
                      },
                      textColor: labelColor,
                      isDark: isDark,
                    ),
                    _buildAttachmentItem(
                      icon: Icons.photo_camera_rounded,
                      label: 'Camera',
                      gradient: const [Color(0xFF1E40AF), Color(0xFF2563EB)],
                      onTap: () {
                        Navigator.pop(ctx);
                        _showCameraOptionSheet();
                      },
                      textColor: labelColor,
                      isDark: isDark,
                    ),
                    _buildAttachmentItem(
                      icon: Icons.image_rounded,
                      label: 'Gallery',
                      gradient: const [Color(0xFF0284C7), Color(0xFF38BDF8)],
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickGalleryMedia();
                      },
                      textColor: labelColor,
                      isDark: isDark,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildAttachmentItem(
                      icon: Icons.headphones_rounded,
                      label: 'Audio',
                      gradient: const [Color(0xFF334155), Color(0xFF64748B)],
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickAudio();
                      },
                      textColor: labelColor,
                      isDark: isDark,
                    ),
                    _buildAttachmentItem(
                      icon: Icons.location_on_rounded,
                      label: 'Location',
                      gradient: const [Color(0xFF0F766E), Color(0xFF14B8A6)],
                      onTap: () {
                        Navigator.pop(ctx);
                        _sendLocation();
                      },
                      textColor: labelColor,
                      isDark: isDark,
                    ),
                    _buildAttachmentItem(
                      icon: Icons.person_rounded,
                      label: 'Contact',
                      gradient: const [Color(0xFF1D4ED8), Color(0xFF60A5FA)],
                      onTap: () {
                        Navigator.pop(ctx);
                        _sendContact();
                      },
                      textColor: labelColor,
                      isDark: isDark,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildAttachmentItem(
                      icon: Icons.poll_rounded,
                      label: 'Poll',
                      gradient: const [Color(0xFF0D9488), Color(0xFF2DD4BF)],
                      onTap: () {
                        Navigator.pop(ctx);
                        _showCreatePollSheet();
                      },
                      textColor: labelColor,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 58),
                    const SizedBox(width: 58),
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
    required bool isDark,
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
                  color: gradient.first.withValues(alpha: isDark ? 0.35 : 0.22),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 9),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
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

  bool _checkIfVideo(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.3gp');
  }

  void _showCameraOptionSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E283D) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.brandBlue.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: AppTheme.brandBlue),
                  ),
                  title: const Text('Take Photo', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickCameraMedia(isVideo: false);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.videocam_rounded, color: Colors.redAccent),
                  ),
                  title: const Text('Record Video', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickCameraMedia(isVideo: true);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickCameraMedia({required bool isVideo}) async {
    try {
      XFile? picked;
      if (isVideo) {
        picked = await _imagePicker.pickVideo(
          source: ImageSource.camera,
          maxDuration: const Duration(minutes: 5),
        );
      } else {
        picked = await _imagePicker.pickImage(
          source: ImageSource.camera,
          maxWidth: 2048,
          maxHeight: 2048,
          imageQuality: 90,
        );
      }

      if (picked != null) {
        if (!mounted) return;
        final mediaItems = [
          MediaItem(
            path: picked.path,
            isVideo: isVideo || _checkIfVideo(picked.path),
          ),
        ];

        final targetName = widget.contactName.isNotEmpty ? widget.contactName : (widget.contactPhone ?? 'Chat');
        final result = await Navigator.of(context).push<MultiMediaSendResult>(
          MaterialPageRoute(
            builder: (_) => ImagePreviewSendScreen(
              initialItems: mediaItems,
              contactName: targetName,
            ),
          ),
        );

        if (result != null && result.items.isNotEmpty) {
          await _dispatchMultiMediaResult(result);
        }
      }
    } catch (e) {
      _showSnack('Camera capture error: $e');
    }
  }

  Future<void> _pickGalleryMedia() async {
    try {
      final pickedList = await _imagePicker.pickMultipleMedia(
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );

      if (pickedList.isNotEmpty) {
        if (!mounted) return;
        final mediaItems = pickedList.map((xf) {
          return MediaItem(
            path: xf.path,
            isVideo: _checkIfVideo(xf.path),
          );
        }).toList();

        final targetName = widget.contactName.isNotEmpty ? widget.contactName : (widget.contactPhone ?? 'Chat');
        final result = await Navigator.of(context).push<MultiMediaSendResult>(
          MaterialPageRoute(
            builder: (_) => ImagePreviewSendScreen(
              initialItems: mediaItems,
              contactName: targetName,
            ),
          ),
        );

        if (result != null && result.items.isNotEmpty) {
          await _dispatchMultiMediaResult(result);
        }
      }
    } catch (e) {
      _showSnack('Gallery media picker error: $e');
    }
  }

  Future<void> _dispatchMultiMediaResult(MultiMediaSendResult result) async {
    if (result.items.isEmpty) return;

    // Single item
    if (result.items.length == 1) {
      final item = result.items.first;
      final file = File(item.path);
      final sizeBytes = file.existsSync() ? await file.length() : 0;
      final sizeStr = _formatFileSize(sizeBytes);
      final fileName = item.path.split(Platform.pathSeparator).last;

      String? uploadedUrl;
      try {
        final upRes = await ApiService.uploadChatFile(item.path, fileName);
        uploadedUrl = upRes?['url'];
      } catch (_) {}

      final captionToSend = result.caption.isNotEmpty ? result.caption : item.caption;

      if (item.isVideo) {
        _sendRichMessage({
          'type': 'video',
          'name': fileName,
          'size': sizeStr,
          'url': uploadedUrl ?? '',
          'localPath': item.path,
          'caption': captionToSend,
          'isViewOnce': result.isViewOnce,
          'isOpened': false,
          'isMuted': item.isMuted,
        });
      } else {
        _sendRichMessage({
          'type': 'image',
          'name': fileName,
          'size': sizeStr,
          'url': uploadedUrl ?? '',
          'localPath': item.path,
          'caption': captionToSend,
          'isViewOnce': result.isViewOnce,
          'isOpened': false,
          'isHd': item.isHd,
          'filter': item.filterName,
          'overlayText': item.overlayText,
          'stickerEmoji': item.stickerEmoji,
          'rotationQuarterTurns': item.rotationQuarterTurns,
        });
      }
      return;
    }

    // Multiple items with View Once enabled: send individually
    if (result.isViewOnce) {
      for (final item in result.items) {
        final file = File(item.path);
        final sizeBytes = file.existsSync() ? await file.length() : 0;
        final sizeStr = _formatFileSize(sizeBytes);
        final fileName = item.path.split(Platform.pathSeparator).last;

        String? uploadedUrl;
        try {
          final upRes = await ApiService.uploadChatFile(item.path, fileName);
          uploadedUrl = upRes?['url'];
        } catch (_) {}

        _sendRichMessage({
          'type': item.isVideo ? 'video' : 'image',
          'name': fileName,
          'size': sizeStr,
          'url': uploadedUrl ?? '',
          'localPath': item.path,
          'caption': item.caption,
          'isViewOnce': true,
          'isOpened': false,
          'isHd': item.isHd,
        });
      }
      return;
    }

    // Multiple items (Photos & Videos together in batch collage)
    final List<Map<String, dynamic>> uploadedAlbumItems = [];
    for (final item in result.items) {
      final file = File(item.path);
      final sizeBytes = file.existsSync() ? await file.length() : 0;
      final sizeStr = _formatFileSize(sizeBytes);
      final fileName = item.path.split(Platform.pathSeparator).last;

      String? uploadedUrl;
      try {
        final upRes = await ApiService.uploadChatFile(item.path, fileName);
        uploadedUrl = upRes?['url'];
      } catch (_) {}

      uploadedAlbumItems.add({
        'name': fileName,
        'size': sizeStr,
        'isVideo': item.isVideo,
        'url': uploadedUrl ?? '',
        'localPath': item.path,
        'caption': item.caption,
        'isHd': item.isHd,
        'filter': item.filterName,
        'overlayText': item.overlayText,
        'stickerEmoji': item.stickerEmoji,
        'rotationQuarterTurns': item.rotationQuarterTurns,
        'isMuted': item.isMuted,
      });
    }

    _sendRichMessage({
      'type': 'media_album',
      'caption': result.caption,
      'isViewOnce': false,
      'count': uploadedAlbumItems.length,
      'items': uploadedAlbumItems,
    });
  }

  Future<void> _pickAudio() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.audio);
      if (files.isNotEmpty) {
        final file = files.first;
        final name = file.name;
        final sizeBytes = await file.length() ?? file.lengthSync() ?? 0;
        final sizeStr = _formatFileSize(sizeBytes);
        final ext = (file.extension ?? 'audio').toUpperCase();
        final localPath = file.path ?? '';

        String? uploadedUrl;
        if (localPath.isNotEmpty) {
          final upRes = await ApiService.uploadChatFile(localPath, name);
          uploadedUrl = upRes?['url']?.toString();
        }

        _sendRichMessage({
          'type': 'audio',
          'name': name,
          'size': sizeStr,
          'ext': ext,
          if (uploadedUrl != null && uploadedUrl.isNotEmpty) 'url': uploadedUrl,
          if (localPath.isNotEmpty) 'localPath': localPath,
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
          final audioUrl = (data['url'] ?? '').toString();
          final localPath = (data['localPath'] ?? '').toString();
          final msgId = (msg['id'] ?? rawText).toString();
          final isPlaying = _playingMsgId == msgId;

          return SizedBox(
            width: 230,
            child: Row(
              children: [
                // Play / Pause Circle
                GestureDetector(
                  onTap: () => _togglePlayVoiceNote(
                    msgId,
                    durationSecs,
                    audioUrl: audioUrl,
                    localPath: localPath,
                  ),
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
                          GestureDetector(
                            onTap: _cycleVoicePlaybackSpeed,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: isMe ? Colors.white24 : AppTheme.brandBlue.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _voicePlaybackSpeed == 1.0
                                    ? '1x'
                                    : (_voicePlaybackSpeed == 1.5 ? '1.5x' : '2x'),
                                style: TextStyle(
                                  color: isMe ? Colors.white : AppTheme.brandBlue,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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
          final isViewOnce = data['isViewOnce'] == true;
          if (isViewOnce) {
            return _buildViewOnceBubble(
              data: data,
              isMe: isMe,
              isDark: isDark,
              textColor: textColor,
              subtextColor: subtextColor,
              isVideo: false,
            );
          }

          final imgUrl = data['url'] ?? '';
          final localPath = (data['localPath'] ?? '').toString();
          final fullUrl = imgUrl.toString().startsWith('/')
              ? '${ApiConfig.rootUrl}$imgUrl'
              : imgUrl.toString();
          final name = data['name'] ?? 'Photo';
          final size = data['size'] ?? '';
          final caption = (data['caption'] ?? '').toString();
          final isHd = data['isHd'] == true;
          final overlayText = (data['overlayText'] ?? '').toString();
          final stickerEmoji = (data['stickerEmoji'] ?? '').toString();
          final int rotationTurns = (data['rotationQuarterTurns'] as int?) ?? 0;

          final bool hasLocalFile = localPath.isNotEmpty && File(localPath).existsSync();

          Widget baseImage;
          if (hasLocalFile) {
            baseImage = Image.file(
              File(localPath),
              width: 230,
              height: 165,
              fit: BoxFit.cover,
            );
          } else if (isValidHttpUrl(fullUrl)) {
            baseImage = Image.network(
              fullUrl,
              width: 230,
              height: 165,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildMediaPlaceholder(Icons.image, name, size),
            );
          } else {
            baseImage = _buildMediaPlaceholder(Icons.image, name, size);
          }

          if (rotationTurns > 0) {
            baseImage = RotatedBox(quarterTurns: rotationTurns, child: baseImage);
          }

          return GestureDetector(
            onTap: () {
              _openMultiMediaViewer([data], 0);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      Container(
                        width: 230,
                        height: 165,
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                        child: baseImage,
                      ),

                      // HD badge
                      if (isHd)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'HD',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),


                      // Sticker Emoji
                      if (stickerEmoji.isNotEmpty)
                        Positioned.fill(
                          child: Center(
                            child: Text(stickerEmoji, style: const TextStyle(fontSize: 36)),
                          ),
                        ),

                      // Text overlay
                      if (overlayText.isNotEmpty)
                        Positioned(
                          bottom: 8,
                          left: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              overlayText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Caption under photo
                if (caption.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    caption,
                    style: TextStyle(
                      color: isMe ? Colors.white : textColor,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],

                const SizedBox(height: 4),
                Text(
                  size.isNotEmpty ? '$name ($size)' : name,
                  style: TextStyle(
                    color: isMe ? Colors.white70 : subtextColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        // 2B. VIDEO BUBBLE (Single Video)
        if (type == 'video') {
          return _buildVideoMessageBubble(data, isMe, isDark, textColor, subtextColor);
        }

        // 2C. MULTI-MEDIA ALBUM BUBBLE (WhatsApp-style Collage Grid for Photos + Videos)
        if (type == 'media_album') {
          return _buildMediaAlbumBubble(data, isMe, isDark, textColor, subtextColor);
        }

        // 3. FILE / DOCUMENT BUBBLE
        if (type == 'file' || type == 'audio') {
          final isAudio = type == 'audio';
          final name = data['name'] ?? (isAudio ? 'Audio file' : 'Document');
          final size = data['size'] ?? '';
          final ext = (data['ext'] ?? (isAudio ? 'MP3' : 'FILE')).toString().toUpperCase();
          final audioUrl = (data['url'] ?? '').toString();
          final localPath = (data['localPath'] ?? '').toString();
          final msgId = (msg['id'] ?? rawText).toString();
          final isAudioPlaying = isAudio && _playingMsgId == msgId;

          return GestureDetector(
            onTap: isAudio
                ? () => _togglePlayVoiceNote(
                      msgId,
                      180,
                      audioUrl: audioUrl,
                      localPath: localPath,
                    )
                : null,
            child: Container(
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
                    isAudio
                        ? (isAudioPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded)
                        : Icons.arrow_circle_down_rounded,
                    color: isMe ? Colors.white : AppTheme.brandBlue,
                    size: 26,
                  ),
                ],
              ),
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

        // 6. STICKER BUBBLE (WhatsApp style)
        if (type == 'sticker') {
          final stickerEmoji = (data['sticker'] ?? '🌟').toString();
          final title = (data['title'] ?? '').toString();

          return Container(
            constraints: const BoxConstraints(minWidth: 110, maxWidth: 160),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Text(
                    stickerEmoji,
                    style: const TextStyle(fontSize: 64, height: 1.1),
                  ),
                ),
                if (title.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        // 7. POLL BUBBLE (WhatsApp style)
        if (type == 'poll') {
          return _buildPollMessageBubble(data, (msg['id'] ?? rawText).toString(), isMe, isDark, textColor, subtextColor);
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

    if (!isMe && rawText.trim().isNotEmpty) {
      return TranslatableTextWidget(
        text: rawText,
        style: TextStyle(
          color: textColor,
          fontSize: 14,
        ),
      );
    }

    return _buildWhatsAppFormattedText(rawText, isMe, textColor);
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

  Widget _buildVideoMessageBubble(
    Map<String, dynamic> data,
    bool isMe,
    bool isDark,
    Color textColor,
    Color subtextColor,
  ) {
    final name = (data['name'] ?? 'Video').toString();
    final size = (data['size'] ?? '').toString();
    final caption = (data['caption'] ?? '').toString();
    final isViewOnce = data['isViewOnce'] == true;
    final isMuted = data['isMuted'] == true;

    if (isViewOnce) {
      return _buildViewOnceBubble(
        data: data,
        isMe: isMe,
        isDark: isDark,
        textColor: textColor,
        subtextColor: subtextColor,
        isVideo: true,
      );
    }

    return GestureDetector(
      onTap: () {
        _openMultiMediaViewer([data], 0);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 230,
              height: 165,
              color: const Color(0xFF0F172A),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: AppTheme.brandBlue.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.brandBlue.withValues(alpha: 0.5),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.videocam_rounded, color: Colors.white, size: 13),
                          SizedBox(width: 4),
                          Text('VIDEO', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  if (isMuted)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.volume_off_rounded, color: Colors.white70, size: 12),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (caption.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              caption,
              style: TextStyle(
                color: isMe ? Colors.white : textColor,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            size.isNotEmpty ? '$name ($size)' : name,
            style: TextStyle(
              color: isMe ? Colors.white70 : subtextColor,
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaAlbumBubble(
    Map<String, dynamic> data,
    bool isMe,
    bool isDark,
    Color textColor,
    Color subtextColor,
  ) {
    final rawItems = data['items'];
    final List<Map<String, dynamic>> items = [];
    if (rawItems is List) {
      for (final it in rawItems) {
        if (it is Map<String, dynamic>) {
          items.add(it);
        } else if (it is Map) {
          items.add(Map<String, dynamic>.from(it));
        }
      }
    }

    final caption = (data['caption'] ?? '').toString();
    final isViewOnce = data['isViewOnce'] == true;
    final count = items.length;

    if (isViewOnce) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: items.map((it) {
          final isVid = it['isVideo'] == true || it['type'] == 'video';
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _buildViewOnceBubble(
              data: it,
              isMe: isMe,
              isDark: isDark,
              textColor: textColor,
              subtextColor: subtextColor,
              isVideo: isVid,
            ),
          );
        }).toList(),
      );
    }

    Widget collageWidget;
    const double collageWidth = 236;

    if (count <= 1) {
      if (count == 1) {
        final first = items.first;
        if (first['isVideo'] == true) {
          return _buildVideoMessageBubble(first, isMe, isDark, textColor, subtextColor);
        }
      }
      collageWidget = const SizedBox.shrink();
    } else if (count == 2) {
      collageWidget = SizedBox(
        width: collageWidth,
        height: 140,
        child: Row(
          children: [
            Expanded(child: _buildCollageTile(items[0], 0, items)),
            const SizedBox(width: 3),
            Expanded(child: _buildCollageTile(items[1], 1, items)),
          ],
        ),
      );
    } else if (count == 3) {
      collageWidget = SizedBox(
        width: collageWidth,
        child: Column(
          children: [
            SizedBox(
              height: 110,
              child: _buildCollageTile(items[0], 0, items),
            ),
            const SizedBox(height: 3),
            SizedBox(
              height: 95,
              child: Row(
                children: [
                  Expanded(child: _buildCollageTile(items[1], 1, items)),
                  const SizedBox(width: 3),
                  Expanded(child: _buildCollageTile(items[2], 2, items)),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      final remainingCount = count - 4;
      collageWidget = SizedBox(
        width: collageWidth,
        child: Column(
          children: [
            SizedBox(
              height: 105,
              child: Row(
                children: [
                  Expanded(child: _buildCollageTile(items[0], 0, items)),
                  const SizedBox(width: 3),
                  Expanded(child: _buildCollageTile(items[1], 1, items)),
                ],
              ),
            ),
            const SizedBox(height: 3),
            SizedBox(
              height: 105,
              child: Row(
                children: [
                  Expanded(child: _buildCollageTile(items[2], 2, items)),
                  const SizedBox(width: 3),
                  Expanded(
                    child: _buildCollageTile(
                      items[3],
                      3,
                      items,
                      extraCount: remainingCount > 0 ? remainingCount : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: collageWidget,
        ),
        if (caption.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            caption,
            style: TextStyle(
              color: isMe ? Colors.white : textColor,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.collections_rounded,
              size: 13,
              color: isMe ? Colors.white70 : subtextColor,
            ),
            const SizedBox(width: 4),
            Text(
              '$count items',
              style: TextStyle(
                color: isMe ? Colors.white70 : subtextColor,
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCollageTile(
    Map<String, dynamic> item,
    int index,
    List<Map<String, dynamic>> allItems, {
    int? extraCount,
  }) {
    final bool isVid = item['isVideo'] == true;
    final localPath = (item['localPath'] ?? '').toString();
    final url = (item['url'] ?? '').toString();
    final fullUrl = url.startsWith('/') ? '${ApiConfig.rootUrl}$url' : url;
    final int rotationTurns = (item['rotationQuarterTurns'] as int?) ?? 0;
    final bool hasLocalFile = localPath.isNotEmpty && File(localPath).existsSync();

    Widget content;
    if (isVid) {
      content = Container(
        color: const Color(0xFF0F172A),
        child: const Center(
          child: Icon(Icons.videocam_rounded, color: Colors.white70, size: 28),
        ),
      );
    } else if (hasLocalFile) {
      content = Image.file(
        File(localPath),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else if (isValidHttpUrl(fullUrl)) {
      content = Image.network(
        fullUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => Container(
          color: const Color(0xFF1E293B),
          child: const Center(child: Icon(Icons.image_rounded, color: Colors.white38)),
        ),
      );
    } else {
      content = Container(
        color: const Color(0xFF1E293B),
        child: const Center(child: Icon(Icons.image_rounded, color: Colors.white38)),
      );
    }

    if (rotationTurns > 0 && !isVid) {
      content = RotatedBox(quarterTurns: rotationTurns, child: content);
    }

    return GestureDetector(
      onTap: () {
        _openMultiMediaViewer(allItems, index);
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          content,
          if (isVid)
            Center(
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
              ),
            ),
          if (extraCount != null && extraCount > 0)
            Container(
              color: Colors.black.withValues(alpha: 0.65),
              alignment: Alignment.center,
              child: Text(
                '+$extraCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openMultiMediaViewer(List<dynamic> allItems, int initialIndex, {bool isViewOnce = false}) {
    if (allItems.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _MultiMediaViewerScreen(
          items: allItems,
          initialIndex: initialIndex,
          contactName: widget.contactName.isNotEmpty ? widget.contactName : (widget.contactPhone ?? 'Chat'),
          isViewOnce: isViewOnce,
        ),
      ),
    );
  }

  void _openViewOnceMedia(Map<String, dynamic> data, {required bool isVideo, required bool canExpire}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _MultiMediaViewerScreen(
          items: [data],
          initialIndex: 0,
          contactName: widget.contactName.isNotEmpty ? widget.contactName : (widget.contactPhone ?? 'Chat'),
          isViewOnce: true,
        ),
      ),
    ).then((_) {
      if (canExpire && mounted) {
        setState(() {
          data['isOpened'] = true;
        });
      }
    });
  }

  Widget _buildViewOnceBubble({
    required Map<String, dynamic> data,
    required bool isMe,
    required bool isDark,
    required Color textColor,
    required Color subtextColor,
    required bool isVideo,
  }) {
    final bool isOpened = data['isOpened'] == true;
    final String label = isOpened ? 'Opened' : (isVideo ? 'Video' : 'Photo');

    final Color iconColor = isOpened
        ? (isMe ? Colors.white54 : subtextColor)
        : (isMe ? Colors.white : AppTheme.brandBlue);

    final Color titleColor = isOpened
        ? (isMe ? Colors.white60 : subtextColor)
        : (isMe ? Colors.white : textColor);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        if (isOpened) {
          _showSnack('This ${isVideo ? 'video' : 'photo'} has expired');
          return;
        }

        if (isMe) {
          _openViewOnceMedia(data, isVideo: isVideo, canExpire: false);
          return;
        }

        _openViewOnceMedia(data, isVideo: isVideo, canExpire: true);
      },
      child: Container(
        constraints: const BoxConstraints(minWidth: 140, maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildViewOnceDashedIcon(isOpened, iconColor),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: titleColor,
                  fontSize: 14.5,
                  fontWeight: isOpened ? FontWeight.normal : FontWeight.w600,
                  fontStyle: isOpened ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewOnceDashedIcon(bool isOpened, Color color) {
    return CustomPaint(
      size: const Size(26, 26),
      painter: _ViewOnceDashedPainter(color: color, isOpened: isOpened),
    );
  }

  Widget _buildWhatsAppFormattedText(String text, bool isMe, Color textColor) {
    final baseColor = isMe ? Colors.white : textColor;
    final baseStyle = TextStyle(color: baseColor, fontSize: 14, height: 1.3);

    final hasMarkers = text.contains('*') || text.contains('_') || text.contains('~') || text.contains('`');
    if (!hasMarkers) {
      return Text(text, style: baseStyle);
    }

    final spans = <InlineSpan>[];
    final regex = RegExp(r'(\*[^*]+\*|_[^_]+_|~[^~]+~|`[^`]+`)');
    int lastMatchEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: baseStyle,
        ));
      }

      final matchedStr = match.group(0)!;
      if (matchedStr.startsWith('*') && matchedStr.endsWith('*') && matchedStr.length > 2) {
        spans.add(TextSpan(
          text: matchedStr.substring(1, matchedStr.length - 1),
          style: baseStyle.copyWith(fontWeight: FontWeight.bold),
        ));
      } else if (matchedStr.startsWith('_') && matchedStr.endsWith('_') && matchedStr.length > 2) {
        spans.add(TextSpan(
          text: matchedStr.substring(1, matchedStr.length - 1),
          style: baseStyle.copyWith(fontStyle: FontStyle.italic),
        ));
      } else if (matchedStr.startsWith('~') && matchedStr.endsWith('~') && matchedStr.length > 2) {
        spans.add(TextSpan(
          text: matchedStr.substring(1, matchedStr.length - 1),
          style: baseStyle.copyWith(decoration: TextDecoration.lineThrough),
        ));
      } else if (matchedStr.startsWith('`') && matchedStr.endsWith('`') && matchedStr.length > 2) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: isMe ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              matchedStr.substring(1, matchedStr.length - 1),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: baseColor,
              ),
            ),
          ),
        ));
      }
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: baseStyle,
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildQuotedReplyBox(Map<String, dynamic> replyTo, bool isMe, bool isDark) {
    final sender = (replyTo['sender'] ?? 'Reply').toString();
    final text = (replyTo['text'] ?? '').toString();
    final targetId = (replyTo['id'] ?? '').toString();

    return GestureDetector(
      onTap: () {
        if (targetId.isNotEmpty) {
          _scrollToMessage(targetId);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        decoration: BoxDecoration(
          color: isMe
              ? Colors.black.withValues(alpha: 0.18)
              : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: isMe ? Colors.white : AppTheme.brandBlue,
              width: 3.5,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              sender,
              style: TextStyle(
                color: isMe ? Colors.white : AppTheme.brandBlue,
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isMe ? Colors.white70 : (isDark ? Colors.white60 : const Color(0xFF475569)),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReactionBadge(Map<String, dynamic> msg, bool isMe, bool isDark) {
    final reactions = msg['reactions'] as Map?;
    if (reactions == null || reactions.isEmpty) return const SizedBox.shrink();

    final emojis = reactions.keys.take(3).join(' ');
    final total = reactions.values.fold<int>(0, (sum, val) => sum + (val is int ? val : 1));

    return GestureDetector(
      onTap: () => _showReactionsDetailSheet(msg),
      child: Container(
        margin: const EdgeInsets.only(top: 2),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E283D) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emojis, style: const TextStyle(fontSize: 12.5)),
            if (total > 1) ...[
              const SizedBox(width: 4),
              Text(
                '$total',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showReactionsDetailSheet(Map<String, dynamic> msg) {
    final reactions = msg['reactions'] as Map? ?? {};
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final msgId = (msg['id'] ?? '').toString();

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E283D) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Reactions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              const SizedBox(height: 12),
              for (final entry in reactions.entries)
                ListTile(
                  leading: Text(entry.key.toString(), style: const TextStyle(fontSize: 24)),
                  title: const Text('You', style: TextStyle(fontWeight: FontWeight.w600)),
                  trailing: TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _toggleMessageReaction(msgId, entry.key.toString());
                    },
                    child: const Text('Tap to remove', style: TextStyle(color: AppTheme.accentCoral, fontSize: 12)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReplyingBanner(
    bool isDark,
    Color textColor,
    Color subtextColor,
    Color inputBg,
    Color borderColor,
  ) {
    final sender = _replyingToMessage!['isMe'] == true ? 'You' : widget.contactName;
    final snippet = _getReplySnippet(_replyingToMessage!);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: inputBg,
        border: Border(
          top: BorderSide(color: borderColor),
          bottom: BorderSide(color: borderColor.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.brandBlue,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  sender,
                  style: const TextStyle(
                    color: AppTheme.brandBlue,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  snippet,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: subtextColor, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            color: subtextColor,
            onPressed: () => setState(() => _replyingToMessage = null),
          ),
        ],
      ),
    );
  }

  Widget _buildPinnedMessageBanner(bool isDark, Color textColor, Color subtextColor) {
    final sender = _pinnedMessage!['isMe'] == true ? 'You' : widget.contactName;
    final snippet = _getReplySnippet(_pinnedMessage!);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E283D) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.brandBlue.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.push_pin_rounded, color: AppTheme.brandBlue, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () {
                _scrollToMessage((_pinnedMessage!['id'] ?? '').toString());
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Pinned message',
                    style: TextStyle(
                      color: AppTheme.brandBlue,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$sender: $snippet',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: textColor, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            color: subtextColor,
            tooltip: 'Unpin',
            onPressed: () {
              setState(() => _pinnedMessage = null);
              _showSnack('Message unpinned');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPollMessageBubble(
    Map<String, dynamic> data,
    String msgId,
    bool isMe,
    bool isDark,
    Color textColor,
    Color subtextColor,
  ) {
    final question = (data['question'] ?? 'Poll').toString();
    final bool multipleAnswers = data['multipleAnswers'] == true;
    final rawOptions = data['options'] as List? ?? [];

    final List<Map<String, dynamic>> options = [];
    int totalVotes = 0;
    for (final opt in rawOptions) {
      if (opt is Map) {
        final optMap = Map<String, dynamic>.from(opt);
        final votes = (optMap['votes'] as List? ?? []);
        totalVotes += votes.length;
        options.add(optMap);
      }
    }

    return Container(
      width: 250,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.poll_rounded, color: AppTheme.brandBlue, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  question,
                  style: TextStyle(
                    color: isMe ? Colors.white : textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            multipleAnswers ? 'Select one or more' : 'Select one',
            style: TextStyle(
              color: isMe ? Colors.white70 : subtextColor,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < options.length; i++) ...[
            Builder(
              builder: (context) {
                final opt = options[i];
                final optText = (opt['text'] ?? '').toString();
                final votes = (opt['votes'] as List? ?? []);
                final bool hasMyVote = votes.contains('me');
                final double percent = totalVotes > 0 ? (votes.length / totalVotes) : 0.0;

                return GestureDetector(
                  onTap: () {
                    _togglePollVote(msgId, i, multipleAnswers);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.white12 : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: hasMyVote
                            ? (isMe ? Colors.white : AppTheme.brandBlue)
                            : (isMe ? Colors.white24 : (isDark ? Colors.white12 : Colors.black12)),
                        width: hasMyVote ? 1.5 : 1,
                      ),
                    ),
                    child: Stack(
                      children: [
                        FractionallySizedBox(
                          widthFactor: percent.clamp(0.0, 1.0),
                          child: Container(
                            height: 42,
                            decoration: BoxDecoration(
                              color: (isMe ? Colors.white : AppTheme.brandBlue).withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(9),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          child: Row(
                            children: [
                              Icon(
                                multipleAnswers
                                    ? (hasMyVote ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded)
                                    : (hasMyVote ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded),
                                size: 18,
                                color: hasMyVote ? (isMe ? Colors.white : AppTheme.brandBlue) : (isMe ? Colors.white60 : subtextColor),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  optText,
                                  style: TextStyle(
                                    color: isMe ? Colors.white : textColor,
                                    fontSize: 13,
                                    fontWeight: hasMyVote ? FontWeight.bold : FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (totalVotes > 0) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '${(percent * 100).round()}%',
                                  style: TextStyle(
                                    color: isMe ? Colors.white70 : subtextColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$totalVotes vote${totalVotes == 1 ? '' : 's'}',
                style: TextStyle(color: isMe ? Colors.white70 : subtextColor, fontSize: 11),
              ),
              GestureDetector(
                onTap: () {
                  _showPollResultsDialog(question, options, totalVotes);
                },
                child: Text(
                  'View votes',
                  style: TextStyle(
                    color: isMe ? Colors.white : AppTheme.brandBlue,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ====================================================================
  // BUILD METHOD
  // ====================================================================

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ChatThemeModel>(
      valueListenable: ChatThemeService.currentThemeNotifier,
      builder: (context, activeTheme, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final defaultBg = isDark ? AppTheme.bgDark : const Color(0xFFF8FAFC);
        final bgColor = activeTheme.backgroundColor ?? _customThemeColor ?? defaultBg;
        final cardColor = isDark ? activeTheme.incomingBubbleColor : Colors.white;
        final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
        final subtextColor = isDark ? AppTheme.textMuted : const Color(0xFF64748B);
        final inputBg = isDark ? AppTheme.bgInput : const Color(0xFFF1F5F9);
        final borderColor = isDark ? const Color(0xFF1E283D) : const Color(0xFFE2E8F0);
        final outgoingBubbleColor = activeTheme.outgoingBubbleColor;

        return PopScope(
          canPop: !_showEmojiPicker,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && _showEmojiPicker) {
              setState(() => _showEmojiPicker = false);
            }
          },
          child: Scaffold(
            backgroundColor: bgColor,
            appBar: AppBar(
              backgroundColor: bgColor.withValues(alpha: 0.94),
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
                : InkWell(
                    onTap: () {
                      if (widget.isGroup) {
                        _showGroupInfoSheet();
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              _groupAvatarLocalFile != null && widget.isGroup
                                  ? ClipOval(
                                      child: Image.file(
                                        _groupAvatarLocalFile!,
                                        width: 38,
                                        height: 38,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : SafeAvatar(
                                      url: _groupAvatarUrl,
                                      fallbackText: widget.isGroup ? _groupTitle : widget.contactName,
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
                                        widget.isGroup ? _groupTitle : widget.contactName,
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
                    ),
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
      body: Stack(
        children: [
          // 1. Theme Wallpaper / Gradient Layer
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: bgColor,
                gradient: activeTheme.backgroundGradient,
              ),
              child: activeTheme.wallpaperFilePath != null
                  ? Image.file(
                      File(activeTheme.wallpaperFilePath!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
          ),
          // 2. WhatsApp Doodle Pattern Overlay
          if (activeTheme.hasDoodle)
            Positioned.fill(
              child: WhatsAppDoodleBackground(
                opacity: activeTheme.doodleOpacity,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          // 3. Main Chat Interface Column
          Column(
            children: [
              if (_isPendingInvite)
                _buildInvitationBanner(isDark, textColor, subtextColor),
              if (_pinnedMessage != null)
                _buildPinnedMessageBanner(isDark, textColor, subtextColor),
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
                    : GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (_showEmojiPicker) setState(() => _showEmojiPicker = false);
                          FocusScope.of(context).unfocus();
                        },
                        child: ListView.builder(
                          controller: _scrollController,
                          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                            final isSticker = _isSticker(msg);

                            return Dismissible(
                              key: Key('reply_${msgId}_$index'),
                              direction: DismissDirection.startToEnd,
                              confirmDismiss: (_) async {
                                HapticFeedback.lightImpact();
                                _startReply(msg);
                                return false;
                              },
                              background: Container(
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.only(left: 16),
                                child: Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: AppTheme.brandBlue.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.reply_rounded, color: AppTheme.brandBlue, size: 20),
                                ),
                              ),
                              child: GestureDetector(
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
                                            padding: isSticker
                                                ? const EdgeInsets.symmetric(horizontal: 4, vertical: 4)
                                                : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                            decoration: BoxDecoration(
                                              color: isSticker
                                                  ? Colors.transparent
                                                  : (isMe
                                                      ? outgoingBubbleColor
                                                      : (isDark ? cardColor : const Color(0xFFF1F5F9))),
                                              borderRadius: BorderRadius.only(
                                                topLeft: const Radius.circular(18),
                                                topRight: const Radius.circular(18),
                                                bottomLeft: Radius.circular(isMe ? 18 : 4),
                                                bottomRight: Radius.circular(isMe ? 4 : 18),
                                              ),
                                              boxShadow: isSticker
                                                  ? null
                                                  : (isMe
                                                      ? [
                                                          BoxShadow(
                                                            color: outgoingBubbleColor.withValues(alpha: 0.28),
                                                            blurRadius: 8,
                                                            offset: const Offset(0, 3),
                                                          ),
                                                        ]
                                                      : null),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (msg['isForwarded'] == true) ...[
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.reply_rounded, size: 14, color: isMe ? Colors.white70 : subtextColor),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Forwarded',
                                                        style: TextStyle(
                                                          color: isMe ? Colors.white70 : subtextColor,
                                                          fontSize: 11,
                                                          fontStyle: FontStyle.italic,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                ],
                                                if (msg['replyTo'] != null)
                                                  _buildQuotedReplyBox(Map<String, dynamic>.from(msg['replyTo']), isMe, isDark),
                                                _buildMessageContent(msg, isMe, textColor, subtextColor, isDark),
                                              ],
                                            ),
                                          ),
                                          if (msg['reactions'] != null && (msg['reactions'] as Map).isNotEmpty)
                                            _buildReactionBadge(msg, isMe, isDark),
                                          const SizedBox(height: 4),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (msg['isEdited'] == true) ...[
                                                Text(
                                                  'Edited • ',
                                                  style: TextStyle(color: isMe ? Colors.white70 : subtextColor, fontSize: 10, fontStyle: FontStyle.italic),
                                                ),
                                              ],
                                              Text(
                                                msg['time'] ?? '',
                                                style: TextStyle(color: subtextColor, fontSize: 10),
                                              ),
                                              if (msg['isStarred'] == true) ...[
                                                const SizedBox(width: 4),
                                                const Icon(
                                                  Icons.star_rounded,
                                                  size: 13,
                                                  color: Color(0xFFEAB308),
                                                ),
                                              ],
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
                              ),
                            );
                          },
                        ),
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
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_replyingToMessage != null)
                  _buildReplyingBanner(isDark, textColor, subtextColor, inputBg, borderColor),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: bgColor,
                    border: Border(top: BorderSide(color: borderColor)),
                  ),
                  child: SafeArea(
                    top: false,
                    bottom: !_showEmojiPicker,
                    child: _isPendingInvite
                        ? _buildPendingInviteBottomBar(isDark, textColor, subtextColor)
                        : (_isRecording
                            ? _buildVoiceRecorderBar(isDark, textColor)
                            : _buildNormalInputBar(inputBg, borderColor, textColor, subtextColor)),
                  ),
                ),
              ],
            ),
          if (_showEmojiPicker)
            WhatsAppEmojiStickerPicker(
              onEmojiSelected: _onEmojiSelected,
              onStickerSelected: _onStickerSelected,
              onBackspace: _onEmojiBackspace,
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

  // Normal Input Bar with '+' attachment button, TextField, and Microphone button
  Widget _buildNormalInputBar(Color inputBg, Color borderColor, Color textColor, Color subtextColor) {
    return Row(
      children: [
        // WhatsApp Attachment '+' Button
        GestureDetector(
          onTap: () {
            if (_showEmojiPicker) setState(() => _showEmojiPicker = false);
            _showAttachmentSheet(context);
          },
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

        // Text Field with inside Emoji and Microphone Action
        Expanded(
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: inputBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                // WhatsApp Emoji / Keyboard toggle
                IconButton(
                  icon: Icon(
                    _showEmojiPicker ? Icons.keyboard_alt_outlined : Icons.sentiment_satisfied_alt_outlined,
                    color: _showEmojiPicker ? AppTheme.brandBlue : subtextColor,
                    size: 24,
                  ),
                  tooltip: _showEmojiPicker ? 'Keyboard' : 'Emoji & Stickers',
                  splashRadius: 20,
                  onPressed: _toggleEmojiPicker,
                ),

                Expanded(
                  child: TextField(
                    controller: _msgController,
                    focusNode: _focusNode,
                    style: TextStyle(color: textColor, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Chat...',
                      hintStyle: TextStyle(color: subtextColor, fontSize: 14),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onTap: () {
                      if (_showEmojiPicker) {
                        setState(() => _showEmojiPicker = false);
                      }
                    },
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
          onTap: () {
            if (_showEmojiPicker) setState(() => _showEmojiPicker = false);
            _sendMessage();
          },
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: ChatThemeService.currentTheme.outgoingBubbleColor,
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

                // Live Audio Waveform Bars
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(_liveWaveform.length, (i) {
                      final h = 6.0 + (_liveWaveform[i] * 20.0);
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
            decoration: BoxDecoration(
              color: ChatThemeService.currentTheme.outgoingBubbleColor,
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

  // 1. NEW GROUP
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
          if (data['type'] == 'image' || data['type'] == 'video') {
            mediaList.add(data);
          } else if (data['type'] == 'media_album' && data['items'] is List) {
            for (final item in (data['items'] as List)) {
              if (item is Map<String, dynamic>) {
                mediaList.add(item);
              } else if (item is Map) {
                mediaList.add(Map<String, dynamic>.from(item));
              }
            }
          }
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatThemeScreen(
          chatId: widget.conversationId,
          chatName: widget.contactName,
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
    final isMe = msg['isMe'] == true;
    final isStarred = msg['isStarred'] == true;
    final isPlainMsg = !rawText.startsWith('{');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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

              // WhatsApp Interactive Emoji Reactions Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final emoji in ['👍', '❤️', '😂', '😮', '😢', '🙏'])
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          _toggleMessageReaction(msgId, emoji);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          child: Text(emoji, style: const TextStyle(fontSize: 25)),
                        ),
                      ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _showCustomEmojiReactionPicker(msgId);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        margin: const EdgeInsets.only(left: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white12 : Colors.black12,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.add_rounded, size: 18, color: textColor),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  _getReplySnippet(msg),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              const Divider(),

              // WhatsApp Actions
              ListTile(
                leading: const Icon(Icons.reply_rounded, color: AppTheme.brandBlue),
                title: Text('Reply', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _startReply(msg);
                },
              ),
              ListTile(
                leading: const Icon(Icons.forward_rounded, color: AppTheme.brandBlue),
                title: Text('Forward', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showForwardMessageSheet(msg);
                },
              ),
              ListTile(
                leading: Icon(
                  isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: const Color(0xFFEAB308),
                ),
                title: Text(isStarred ? 'Unstar message' : 'Star message', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _toggleStarMessage(msgId);
                },
              ),
              ListTile(
                leading: const Icon(Icons.push_pin_rounded, color: Color(0xFF6366F1)),
                title: Text('Pin message', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showPinMessageDialog(msg);
                },
              ),
              if (isMe && isPlainMsg)
                ListTile(
                  leading: const Icon(Icons.edit_rounded, color: Color(0xFF10B981)),
                  title: Text('Edit message', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showEditMessageDialog(msg);
                  },
                ),
              if (isMe)
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded, color: AppTheme.brandBlue),
                  title: Text('Message info', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showMessageInfoSheet(msg);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.copy_rounded, color: Color(0xFF64748B)),
                title: Text('Copy text', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: rawText));
                  _showSnack('Copied to clipboard');
                },
              ),
              ListTile(
                leading: const Icon(Icons.check_box_outlined, color: AppTheme.brandBlue),
                title: Text('Select messages', style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _isSelectionMode = true;
                    _selectedMsgIds.clear();
                    _selectedMsgIds.add(msgId);
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppTheme.accentCoral),
                title: const Text('Delete message', style: TextStyle(color: AppTheme.accentCoral, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDeleteMessagesDialog(singleMsgId: msgId);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startReply(Map<String, dynamic> msg) {
    setState(() {
      _replyingToMessage = msg;
    });
    FocusScope.of(context).requestFocus(_focusNode);
  }

  void _toggleMessageReaction(String msgId, String emoji) {
    final msgIndex = _messages.indexWhere((m) => (m['id'] ?? '').toString() == msgId);
    if (msgIndex == -1) return;

    final msg = _messages[msgIndex];
    final Map<String, dynamic> reactions = Map<String, dynamic>.from(msg['reactions'] ?? {});

    if (reactions.containsKey(emoji)) {
      reactions.remove(emoji);
    } else {
      reactions[emoji] = 1;
    }

    setState(() {
      msg['reactions'] = reactions;
    });
    HapticFeedback.lightImpact();
  }

  void _showCustomEmojiReactionPicker(String msgId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E283D) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final popularEmojis = [
          '🔥', '👏', '🎉', '💯', '✨', '🤩', '🥳', '😎', '🤝', '🚀', '😍', '🤔', '👀', '💡', '✅', '❌'
        ];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('React with Emoji', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (final em in popularEmojis)
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(ctx);
                          _toggleMessageReaction(msgId, em);
                        },
                        child: Text(em, style: const TextStyle(fontSize: 28)),
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

  void _toggleStarMessage(String msgId) {
    final msgIndex = _messages.indexWhere((m) => (m['id'] ?? '').toString() == msgId);
    if (msgIndex == -1) return;

    final msg = _messages[msgIndex];
    final isStarred = msg['isStarred'] == true;
    setState(() {
      msg['isStarred'] = !isStarred;
    });
    _showSnack(!isStarred ? 'Message starred ⭐' : 'Message unstarred');
  }

  void _showPinMessageDialog(Map<String, dynamic> msg) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E283D) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pin message for...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.timer_outlined, color: AppTheme.brandBlue),
                  title: const Text('24 hours'),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _pinnedMessage = msg);
                    _showSnack('Message pinned for 24 hours');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.date_range_rounded, color: AppTheme.brandBlue),
                  title: const Text('7 days'),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _pinnedMessage = msg);
                    _showSnack('Message pinned for 7 days');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.calendar_month_rounded, color: AppTheme.brandBlue),
                  title: const Text('30 days'),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _pinnedMessage = msg);
                    _showSnack('Message pinned for 30 days');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditMessageDialog(Map<String, dynamic> msg) {
    final rawText = (msg['text'] ?? '').toString();
    final editCtrl = TextEditingController(text: rawText);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E283D) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit message', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        content: TextField(
          controller: editCtrl,
          autofocus: true,
          maxLines: 4,
          minLines: 1,
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.brandBlue),
            onPressed: () {
              final newText = editCtrl.text.trim();
              if (newText.isNotEmpty && newText != rawText) {
                setState(() {
                  msg['text'] = newText;
                  msg['isEdited'] = true;
                });
                _showSnack('Message edited');
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showForwardMessageSheet(Map<String, dynamic> msg) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E283D) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    final contacts = [
      {'name': 'Soumo Naskar', 'avatar': 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100'},
      {'name': 'Lena Rivers', 'avatar': 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=120'},
      {'name': 'IT Group', 'avatar': '', 'isGroup': true},
      {'name': 'David Kim', 'avatar': ''},
      {'name': 'Koushiki Podder', 'avatar': ''},
    ];
    final Set<String> selected = {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Forward to...', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 17)),
                    const SizedBox(height: 12),
                    for (final c in contacts)
                      CheckboxListTile(
                        value: selected.contains(c['name']),
                        activeColor: AppTheme.brandBlue,
                        title: Text(c['name'] as String, style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                        secondary: SafeAvatar(
                          url: c['avatar'] as String,
                          radius: 18,
                          fallbackText: (c['name'] as String)[0],
                        ),
                        onChanged: (val) {
                          setModalState(() {
                            if (val == true) {
                              selected.add(c['name'] as String);
                            } else {
                              selected.remove(c['name'] as String);
                            }
                          });
                        },
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.brandBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: selected.isEmpty
                            ? null
                            : () {
                                Navigator.pop(ctx);
                                _showSnack('Forwarded to ${selected.join(', ')}');
                              },
                        child: Text(
                          selected.isEmpty ? 'Select contact to forward' : 'Forward (${selected.length})',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showMessageInfoSheet(Map<String, dynamic> msg) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E283D) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? AppTheme.textMuted : const Color(0xFF64748B);

    showModalBottomSheet(
      context: context,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Message Info', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.done_all_rounded, color: Color(0xFF10B981)),
                title: Text('Read', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                subtitle: Text('Today, ${msg['time'] ?? '12:00 pm'}', style: TextStyle(color: subtextColor, fontSize: 12)),
              ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.done_all_rounded, color: subtextColor),
                title: Text('Delivered', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                subtitle: Text('Today, ${msg['time'] ?? '12:00 pm'}', style: TextStyle(color: subtextColor, fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _scrollToMessage(String id) {
    final index = _messages.indexWhere((m) => (m['id'] ?? '').toString() == id);
    if (index != -1 && _scrollController.hasClients) {
      final targetOffset = (index * 70.0).clamp(0.0, _scrollController.position.maxScrollExtent);
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showCreatePollSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E283D) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? AppTheme.textMuted : const Color(0xFF64748B);
    final inputBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);

    final questionCtrl = TextEditingController();
    final List<TextEditingController> optionCtrls = [
      TextEditingController(),
      TextEditingController(),
    ];
    bool allowMultiple = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
              child: SingleChildScrollView(
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Create Poll',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          color: subtextColor,
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Question',
                      style: TextStyle(color: subtextColor, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: questionCtrl,
                      style: TextStyle(color: textColor, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Ask a question...',
                        hintStyle: TextStyle(color: subtextColor),
                        filled: true,
                        fillColor: inputBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Options',
                      style: TextStyle(color: subtextColor, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    for (int i = 0; i < optionCtrls.length; i++) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: optionCtrls[i],
                                style: TextStyle(color: textColor, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'Option ${i + 1}',
                                  hintStyle: TextStyle(color: subtextColor),
                                  filled: true,
                                  fillColor: inputBg,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                              ),
                            ),
                            if (optionCtrls.length > 2) ...[
                              const SizedBox(width: 6),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline_rounded, color: AppTheme.accentCoral, size: 22),
                                onPressed: () {
                                  setModalState(() {
                                    optionCtrls[i].dispose();
                                    optionCtrls.removeAt(i);
                                  });
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    if (optionCtrls.length < 8)
                      TextButton.icon(
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add option'),
                        style: TextButton.styleFrom(foregroundColor: AppTheme.brandBlue),
                        onPressed: () {
                          setModalState(() {
                            optionCtrls.add(TextEditingController());
                          });
                        },
                      ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Allow multiple answers',
                          style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        Switch.adaptive(
                          value: allowMultiple,
                          activeColor: AppTheme.brandBlue,
                          onChanged: (val) {
                            setModalState(() => allowMultiple = val);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.brandBlue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        onPressed: () {
                          final q = questionCtrl.text.trim();
                          if (q.isEmpty) {
                            _showSnack('Please enter a question');
                            return;
                          }
                          final validOptions = optionCtrls
                              .map((c) => c.text.trim())
                              .where((t) => t.isNotEmpty)
                              .map((t) => {'text': t, 'votes': []})
                              .toList();
                          if (validOptions.length < 2) {
                            _showSnack('Please enter at least 2 options');
                            return;
                          }
                          Navigator.pop(ctx);
                          _sendRichMessage({
                            'type': 'poll',
                            'question': q,
                            'options': validOptions,
                            'multipleAnswers': allowMultiple,
                          });
                        },
                        child: const Text(
                          'Create Poll',
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showPollResultsDialog(String question, List<Map<String, dynamic>> options, int totalVotes) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E283D) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? AppTheme.textMuted : const Color(0xFF64748B);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.poll_rounded, color: AppTheme.brandBlue, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                question,
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total votes: $totalVotes', style: TextStyle(color: subtextColor, fontSize: 12)),
            const SizedBox(height: 12),
            for (final opt in options) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        (opt['text'] ?? '').toString(),
                        style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      '${(opt['votes'] as List? ?? []).length} vote(s)',
                      style: const TextStyle(color: AppTheme.brandBlue, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: AppTheme.brandBlue)),
          ),
        ],
      ),
    );
  }

  void _togglePollVote(String msgId, int optionIndex, bool multipleAnswers) {
    final msgIndex = _messages.indexWhere((m) => (m['id'] ?? '').toString() == msgId);
    if (msgIndex == -1) return;

    final rawText = (_messages[msgIndex]['text'] ?? '').toString();
    try {
      final data = jsonDecode(rawText);
      final List options = data['options'] as List? ?? [];
      if (optionIndex >= options.length) return;

      final targetOpt = Map<String, dynamic>.from(options[optionIndex]);
      final List votes = List.from(targetOpt['votes'] as List? ?? []);

      if (votes.contains('me')) {
        votes.remove('me');
      } else {
        if (!multipleAnswers) {
          for (int i = 0; i < options.length; i++) {
            final opt = Map<String, dynamic>.from(options[i]);
            final v = List.from(opt['votes'] as List? ?? []);
            v.remove('me');
            opt['votes'] = v;
            options[i] = opt;
          }
        }
        votes.add('me');
      }
      targetOpt['votes'] = votes;
      options[optionIndex] = targetOpt;
      data['options'] = options;

      setState(() {
        _messages[msgIndex]['text'] = jsonEncode(data);
      });
      HapticFeedback.lightImpact();
    } catch (_) {}
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
          value: 'group_settings',
          child: Row(
            children: [
              Icon(Icons.tune_rounded, color: itemTextColor, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text('Group settings', style: TextStyle(color: itemTextColor, fontSize: 14))),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'set_admins',
          child: Row(
            children: [
              Icon(Icons.manage_accounts_rounded, color: itemTextColor, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text('Set group admins', style: TextStyle(color: itemTextColor, fontSize: 14))),
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
      case 'group_settings':
        _showGroupSettingsSheet();
        break;
      case 'set_admins':
        _showSetGroupAdminSheet();
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
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => DraggableScrollableSheet(
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

              // Group Avatar & Title with Edit Controls
              Center(
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        _groupAvatarLocalFile != null
                            ? ClipOval(
                                child: Image.file(
                                  _groupAvatarLocalFile!,
                                  width: 96,
                                  height: 96,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : SafeAvatar(
                                url: _groupAvatarUrl,
                                fallbackText: _groupTitle,
                                fallbackIcon: Icons.group,
                                size: 96,
                                radius: 48,
                              ),
                        GestureDetector(
                          onTap: () async {
                            await _pickGroupImage();
                            setModalState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: AppTheme.brandBlue,
                              shape: BoxShape.circle,
                              border: Border.all(color: bg, width: 2),
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                              ],
                            ),
                            child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            _groupTitle,
                            style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 20),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () async {
                            await _showEditGroupNameDialog();
                            setModalState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.edit_rounded, color: subtextColor, size: 16),
                          ),
                        ),
                      ],
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

              // Description with Edit Button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Description', style: TextStyle(color: subtextColor, fontSize: 12, fontWeight: FontWeight.bold)),
                        GestureDetector(
                          onTap: () async {
                            await _showEditGroupDescriptionDialog();
                            setModalState(() {});
                          },
                          child: const Row(
                            children: [
                              Icon(Icons.edit_rounded, color: AppTheme.brandBlue, size: 14),
                              SizedBox(width: 4),
                              Text('Edit', style: TextStyle(color: AppTheme.brandBlue, fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () async {
                        await _showEditGroupDescriptionDialog();
                        setModalState(() {});
                      },
                      child: Text(
                        _groupDescription.isNotEmpty
                            ? _groupDescription
                            : 'Tap to add group description...',
                        style: TextStyle(
                          color: _groupDescription.isNotEmpty ? textColor : subtextColor.withValues(alpha: 0.8),
                          fontSize: 13,
                          height: 1.4,
                          fontStyle: _groupDescription.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Created by Group Admin', style: TextStyle(color: subtextColor, fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Group Settings Tile
              ListTile(
                tileColor: cardBg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                leading: const Icon(Icons.tune_rounded, color: AppTheme.brandBlue),
                title: Text('Group settings', style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: Text('Edit group info, send messages & admin controls', style: TextStyle(color: subtextColor, fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                onTap: () {
                  Navigator.pop(ctx);
                  _showGroupSettingsSheet();
                },
              ),
              const SizedBox(height: 10),

              // Set Group Admins Tile
              ListTile(
                tileColor: cardBg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                leading: const Icon(Icons.manage_accounts_rounded, color: Color(0xFF10B981)),
                title: Text('Set group admins', style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: Text('${_groupAdmins.length} admin(s) • Assign or dismiss admins', style: TextStyle(color: subtextColor, fontSize: 12)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                onTap: () {
                  Navigator.pop(ctx);
                  _showSetGroupAdminSheet();
                },
              ),
              const SizedBox(height: 10),

              // Media, links, and docs
              ListTile(
                tileColor: cardBg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                leading: const Icon(Icons.perm_media_outlined, color: Color(0xFF8B5CF6)),
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
                final isAdmin = isYou || _groupAdmins.contains(member);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    tileColor: cardBg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    leading: SafeAvatar(url: null, fallbackText: member, size: 38, radius: 19),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(member, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600)),
                        ),
                        if (isAdmin) ...[
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
                    subtitle: Text(
                      isAdmin ? (isYou ? 'Group Creator / Admin' : 'Group Admin') : 'Active Member',
                      style: TextStyle(color: subtextColor, fontSize: 11),
                    ),
                    trailing: Icon(Icons.more_vert_rounded, color: subtextColor, size: 20),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showMemberActionSheet(member);
                    },
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
      ),
    );
  }

  void _appendSystemEventMessage(String text) {
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final sysMsg = {
      'id': tempId,
      'isMe': true,
      'text': '[System message]: $text',
      'time': _formatCurrentTime(),
      'isRead': true,
    };
    setState(() {
      _messages.add(sysMsg);
    });
    _scrollToBottom();
    _dispatchToBackend('[System message]: $text', tempId: tempId);
  }

  Future<void> _pickGroupImage() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E283D) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    await showModalBottomSheet(
      context: context,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Text('Group icon', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppTheme.brandBlue),
              title: Text('Camera', style: TextStyle(color: textColor)),
              onTap: () async {
                Navigator.pop(ctx);
                final picked = await _imagePicker.pickImage(
                  source: ImageSource.camera,
                  maxWidth: 800,
                  maxHeight: 800,
                  imageQuality: 85,
                );
                if (picked != null) {
                  setState(() {
                    _groupAvatarLocalFile = File(picked.path);
                  });
                  _showSnack('Group image updated successfully!');
                  _appendSystemEventMessage('Group icon was updated by admin');
                  if (widget.conversationId != null) {
                    ApiService.updateGroupDetails(widget.conversationId!, avatarUrl: picked.path);
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppTheme.brandBlue),
              title: Text('Gallery', style: TextStyle(color: textColor)),
              onTap: () async {
                Navigator.pop(ctx);
                final picked = await _imagePicker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 800,
                  maxHeight: 800,
                  imageQuality: 85,
                );
                if (picked != null) {
                  setState(() {
                    _groupAvatarLocalFile = File(picked.path);
                  });
                  _showSnack('Group image updated successfully!');
                  _appendSystemEventMessage('Group icon was updated by admin');
                  if (widget.conversationId != null) {
                    ApiService.updateGroupDetails(widget.conversationId!, avatarUrl: picked.path);
                  }
                }
              },
            ),
            if (_groupAvatarLocalFile != null || _groupAvatarUrl != null)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppTheme.accentCoral),
                title: const Text('Remove icon', style: TextStyle(color: AppTheme.accentCoral)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _groupAvatarLocalFile = null;
                    _groupAvatarUrl = null;
                  });
                  _showSnack('Group icon removed');
                  _appendSystemEventMessage('Group icon was removed');
                  if (widget.conversationId != null) {
                    ApiService.updateGroupDetails(widget.conversationId!, avatarUrl: '');
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditGroupDescriptionDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E283D) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? AppTheme.textMuted : const Color(0xFF64748B);

    final descController = TextEditingController(text: _groupDescription);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Edit group description', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('The description is visible to members of this group.', style: TextStyle(color: subtextColor, fontSize: 12)),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              maxLines: 4,
              maxLength: 250,
              style: TextStyle(color: textColor, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Enter group description...',
                hintStyle: TextStyle(color: subtextColor),
                filled: true,
                fillColor: isDark ? const Color(0xFF121A2B) : const Color(0xFFF1F5F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
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
              final newDesc = descController.text.trim();
              Navigator.pop(ctx);
              setState(() {
                _groupDescription = newDesc;
              });
              _showSnack('Group description updated');
              _appendSystemEventMessage('Group description changed to: "$newDesc"');
              if (widget.conversationId != null) {
                ApiService.updateGroupDetails(widget.conversationId!, description: newDesc);
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditGroupNameDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E283D) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? AppTheme.textMuted : const Color(0xFF64748B);

    final titleController = TextEditingController(text: _groupTitle);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Edit group name', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
        content: TextField(
          controller: titleController,
          maxLength: 40,
          style: TextStyle(color: textColor, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Group name...',
            hintStyle: TextStyle(color: subtextColor),
            filled: true,
            fillColor: isDark ? const Color(0xFF121A2B) : const Color(0xFFF1F5F9),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
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
              final newTitle = titleController.text.trim();
              if (newTitle.isNotEmpty) {
                Navigator.pop(ctx);
                setState(() {
                  _groupTitle = newTitle;
                });
                _showSnack('Group name updated to "$newTitle"');
                _appendSystemEventMessage('Group subject changed to "$newTitle"');
                if (widget.conversationId != null) {
                  ApiService.updateGroupDetails(widget.conversationId!, title: newTitle);
                }
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showGroupSettingsSheet() {
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
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => SafeArea(
          child: Padding(
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
                Row(
                  children: [
                    const Icon(Icons.tune_rounded, color: AppTheme.brandBlue, size: 24),
                    const SizedBox(width: 10),
                    Text('Group settings', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Admins can manage group permissions, info, and administrators.', style: TextStyle(color: subtextColor, fontSize: 12)),
                const SizedBox(height: 18),

                // 1. Edit Group Info Permission
                ListTile(
                  tileColor: cardBg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: const Icon(Icons.edit_note_rounded, color: AppTheme.brandBlue),
                  title: Text('Edit group info', style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    'Choose who can change this group\'s name, icon, and description: ${_onlyAdminsCanEditInfo ? "Only admins" : "All participants"}',
                    style: TextStyle(color: subtextColor, fontSize: 11),
                  ),
                  trailing: Text(
                    _onlyAdminsCanEditInfo ? 'Only admins' : 'All members',
                    style: const TextStyle(color: AppTheme.brandBlue, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (dCtx) => AlertDialog(
                        backgroundColor: bg,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: Text('Who can edit group info?', style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            RadioListTile<bool>(
                              title: Text('All participants', style: TextStyle(color: textColor, fontSize: 14)),
                              value: false,
                              groupValue: _onlyAdminsCanEditInfo,
                              activeColor: AppTheme.brandBlue,
                              onChanged: (val) {
                                Navigator.pop(dCtx);
                                setState(() => _onlyAdminsCanEditInfo = false);
                                setModalState(() {});
                                _showSnack('All participants can now edit group info');
                              },
                            ),
                            RadioListTile<bool>(
                              title: Text('Only admins', style: TextStyle(color: textColor, fontSize: 14)),
                              value: true,
                              groupValue: _onlyAdminsCanEditInfo,
                              activeColor: AppTheme.brandBlue,
                              onChanged: (val) {
                                Navigator.pop(dCtx);
                                setState(() => _onlyAdminsCanEditInfo = true);
                                setModalState(() {});
                                _showSnack('Only admins can now edit group info');
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),

                // 2. Send Messages Permission
                ListTile(
                  tileColor: cardBg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: const Icon(Icons.send_rounded, color: Color(0xFF10B981)),
                  title: Text('Send messages', style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    'Choose who can send messages to this group: ${_onlyAdminsCanSendMessages ? "Only admins" : "All participants"}',
                    style: TextStyle(color: subtextColor, fontSize: 11),
                  ),
                  trailing: Text(
                    _onlyAdminsCanSendMessages ? 'Only admins' : 'All members',
                    style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (dCtx) => AlertDialog(
                        backgroundColor: bg,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: Text('Who can send messages?', style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            RadioListTile<bool>(
                              title: Text('All participants', style: TextStyle(color: textColor, fontSize: 14)),
                              value: false,
                              groupValue: _onlyAdminsCanSendMessages,
                              activeColor: AppTheme.brandBlue,
                              onChanged: (val) {
                                Navigator.pop(dCtx);
                                setState(() => _onlyAdminsCanSendMessages = false);
                                setModalState(() {});
                                _showSnack('All participants can send messages');
                              },
                            ),
                            RadioListTile<bool>(
                              title: Text('Only admins', style: TextStyle(color: textColor, fontSize: 14)),
                              value: true,
                              groupValue: _onlyAdminsCanSendMessages,
                              activeColor: AppTheme.brandBlue,
                              onChanged: (val) {
                                Navigator.pop(dCtx);
                                setState(() => _onlyAdminsCanSendMessages = true);
                                setModalState(() {});
                                _showSnack('Only admins can now send messages');
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),

                // 3. Edit Group Admins (Set Group Admin)
                ListTile(
                  tileColor: cardBg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: const Icon(Icons.manage_accounts_rounded, color: Color(0xFF8B5CF6)),
                  title: Text('Edit group admins', style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '${_groupAdmins.length} admin(s) assigned • Tap to assign or dismiss admins',
                    style: TextStyle(color: subtextColor, fontSize: 11),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showSetGroupAdminSheet();
                  },
                ),
                const SizedBox(height: 10),

                // 4. Quick Edit Description
                ListTile(
                  tileColor: cardBg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: const Icon(Icons.description_outlined, color: Colors.amber),
                  title: Text('Edit group description', style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text('Change the group overview visible to participants', style: TextStyle(color: subtextColor, fontSize: 11)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showEditGroupDescriptionDialog();
                  },
                ),
                const SizedBox(height: 10),

                // 5. Change Group Picture
                ListTile(
                  tileColor: cardBg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: const Icon(Icons.camera_alt_outlined, color: Color(0xFFEC4899)),
                  title: Text('Change group icon', style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text('Take photo with camera or pick from gallery', style: TextStyle(color: subtextColor, fontSize: 11)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickGroupImage();
                  },
                ),
                const SizedBox(height: 10),

                // 6. Approve new members switch
                ListTile(
                  tileColor: cardBg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: const Icon(Icons.how_to_reg_rounded, color: AppTheme.brandBlue),
                  title: Text('Approve new participants', style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text('Require admin confirmation for any invite join', style: TextStyle(color: subtextColor, fontSize: 11)),
                  trailing: Switch(
                    value: _requireAdminApproval,
                    activeColor: AppTheme.brandBlue,
                    onChanged: (val) {
                      setState(() => _requireAdminApproval = val);
                      setModalState(() {});
                      _showSnack(val ? 'Admin approval required to join' : 'Anyone with invite can join');
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSetGroupAdminSheet() {
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
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.45,
            maxChildSize: 0.95,
            expand: false,
            builder: (_, scrollCtrl) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
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
                      const Icon(Icons.manage_accounts_rounded, color: Color(0xFF10B981), size: 24),
                      const SizedBox(width: 10),
                      Text('Set group admins', style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Select participants to grant or revoke group admin permissions.', style: TextStyle(color: subtextColor, fontSize: 12)),
                  const SizedBox(height: 16),

                  Expanded(
                    child: ListView.builder(
                      controller: scrollCtrl,
                      itemCount: _groupMembers.length,
                      itemBuilder: (context, index) {
                        final member = _groupMembers[index];
                        final isYou = member == 'You';
                        final isAdmin = isYou || _groupAdmins.contains(member);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            tileColor: cardBg,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            leading: SafeAvatar(url: null, fallbackText: member, size: 40, radius: 20),
                            title: Text(member, style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: Text(
                              isYou
                                  ? 'Group Creator (Admin)'
                                  : (isAdmin ? 'Group Admin' : 'Member'),
                              style: TextStyle(
                                color: isAdmin ? AppTheme.brandBlue : subtextColor,
                                fontSize: 11,
                                fontWeight: isAdmin ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            trailing: isYou
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.brandBlue.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text('Creator', style: TextStyle(color: AppTheme.brandBlue, fontSize: 11, fontWeight: FontWeight.bold)),
                                  )
                                : Switch(
                                    value: isAdmin,
                                    activeColor: const Color(0xFF10B981),
                                    onChanged: (val) {
                                      setModalState(() {
                                        if (val) {
                                          _groupAdmins.add(member);
                                          _appendSystemEventMessage('$member is now a group admin');
                                          _showSnack('$member is now a group admin');
                                          if (widget.conversationId != null) {
                                            ApiService.setGroupParticipantRole(widget.conversationId!, targetIdentifier: member, role: 'admin');
                                          }
                                        } else {
                                          _groupAdmins.remove(member);
                                          _appendSystemEventMessage('$member is no longer a group admin');
                                          _showSnack('Removed $member as admin');
                                          if (widget.conversationId != null) {
                                            ApiService.setGroupParticipantRole(widget.conversationId!, targetIdentifier: member, role: 'member');
                                          }
                                        }
                                      });
                                      setState(() {});
                                    },
                                  ),
                          ),
                        );
                      },
                    ),
                  ),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.brandBlue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showMemberActionSheet(String member) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E283D) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? AppTheme.textMuted : const Color(0xFF64748B);

    final isYou = member == 'You';
    final isAdmin = isYou || _groupAdmins.contains(member);

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
              ListTile(
                leading: SafeAvatar(url: null, fallbackText: member, size: 44, radius: 22),
                title: Text(member, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text(isAdmin ? 'Group Admin' : 'Member', style: TextStyle(color: subtextColor, fontSize: 12)),
              ),
              const Divider(height: 1),
              if (!isYou) ...[
                if (!isAdmin)
                  ListTile(
                    leading: const Icon(Icons.admin_panel_settings_rounded, color: AppTheme.brandBlue),
                    title: const Text('Make group admin', style: TextStyle(fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _groupAdmins.add(member);
                      });
                      _showSnack('$member is now a group admin');
                      _appendSystemEventMessage('$member is now a group admin');
                      if (widget.conversationId != null) {
                        ApiService.setGroupParticipantRole(widget.conversationId!, targetIdentifier: member, role: 'admin');
                      }
                    },
                  )
                else
                  ListTile(
                    leading: const Icon(Icons.remove_moderator_rounded, color: Colors.orange),
                    title: const Text('Dismiss as admin', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600)),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _groupAdmins.remove(member);
                      });
                      _showSnack('Dismissed $member as group admin');
                      _appendSystemEventMessage('$member is no longer a group admin');
                      if (widget.conversationId != null) {
                        ApiService.setGroupParticipantRole(widget.conversationId!, targetIdentifier: member, role: 'member');
                      }
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF10B981)),
                  title: Text('Message $member'),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          contactName: member,
                          isGroup: false,
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.person_remove_rounded, color: AppTheme.accentCoral),
                  title: Text('Remove $member from group', style: const TextStyle(color: AppTheme.accentCoral, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _groupMembers.remove(member);
                      _groupAdmins.remove(member);
                    });
                    _showSnack('Removed $member from group');
                    _appendSystemEventMessage('$member was removed from the group');
                  },
                ),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('You are the Group Admin with full permissions.', style: TextStyle(color: subtextColor, fontSize: 13)),
                ),
              ],
            ],
          ),
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

// ====================================================================
// FULL-SCREEN MULTI-MEDIA VIEWER & GALLERY (PHOTOS + VIDEOS)
// ====================================================================

class _MultiMediaViewerScreen extends StatefulWidget {
  final List<dynamic> items;
  final int initialIndex;
  final String contactName;
  final bool isViewOnce;

  const _MultiMediaViewerScreen({
    required this.items,
    required this.initialIndex,
    required this.contactName,
    this.isViewOnce = false,
  });

  @override
  State<_MultiMediaViewerScreen> createState() => _MultiMediaViewerScreenState();
}

class _MultiMediaViewerScreenState extends State<_MultiMediaViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;
  bool _isPlayingVideo = false;

  static const Map<String, List<double>> _filterMatrices = {
    'None': [
      1, 0, 0, 0, 0,
      0, 1, 0, 0, 0,
      0, 0, 1, 0, 0,
      0, 0, 0, 1, 0,
    ],
    'Vivid': [
      1.2, 0, 0, 0, 0,
      0, 1.2, 0, 0, 0,
      0, 0, 1.2, 0, 0,
      0, 0, 0, 1, 0,
    ],
    'Warm': [
      1.15, 0, 0, 0, 10,
      0, 1.05, 0, 0, 5,
      0, 0, 0.9, 0, -10,
      0, 0, 0, 1, 0,
    ],
    'Cool': [
      0.9, 0, 0, 0, -5,
      0, 1.05, 0, 0, 5,
      0, 0, 1.2, 0, 15,
      0, 0, 0, 1, 0,
    ],
    'B&W': [
      0.2126, 0.7152, 0.0722, 0, 0,
      0.2126, 0.7152, 0.0722, 0, 0,
      0.2126, 0.7152, 0.0722, 0, 0,
      0, 0, 0, 1, 0,
    ],
    'Dramatic': [
      1.35, 0, 0, 0, -25,
      0, 1.35, 0, 0, -25,
      0, 0, 1.35, 0, -25,
      0, 0, 0, 1, 0,
    ],
  };

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.items.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _getItemMap(int index) {
    final raw = widget.items[index];
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }

  @override
  Widget build(BuildContext context) {
    final currentItem = _getItemMap(_currentIndex);
    final caption = (currentItem['caption'] ?? '').toString();
    final isHd = currentItem['isHd'] == true;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Center PageView for Media Swiping
            PageView.builder(
              controller: _pageController,
              itemCount: widget.items.length,
              onPageChanged: (idx) {
                setState(() {
                  _currentIndex = idx;
                  _isPlayingVideo = false;
                });
              },
              itemBuilder: (context, index) {
                final item = _getItemMap(index);
                final isVid = item['isVideo'] == true || item['type'] == 'video';
                if (isVid) {
                  return _buildVideoPage(item);
                }
                return _buildImagePage(item);
              },
            ),

            // Top App Bar Overlay
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black87, Colors.transparent],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.isViewOnce)
                            const Row(
                              children: [
                                Icon(Icons.looks_one_rounded, color: Colors.amberAccent, size: 18),
                                SizedBox(width: 6),
                                Text(
                                  'View once',
                                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            )
                          else
                            Text(
                              widget.contactName,
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (!widget.isViewOnce)
                            Text(
                              '${_currentIndex + 1} of ${widget.items.length}',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                    if (isHd)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.brandBlue,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('HD', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ),
            ),

            // Bottom Floating Controls (Caption + Thumbnail Bar)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black87, Colors.black],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Caption bubble if present
                    if (caption.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B).withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Text(
                          caption,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 14.5),
                        ),
                      ),
                    ],

                    // Horizontal Thumbnails Strip (if multiple items in batch)
                    if (widget.items.length > 1)
                      SizedBox(
                        height: 52,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: widget.items.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, thumbIdx) {
                            final thItem = _getItemMap(thumbIdx);
                            final isSel = thumbIdx == _currentIndex;
                            final isThVid = thItem['isVideo'] == true || thItem['type'] == 'video';
                            final thLocal = (thItem['localPath'] ?? '').toString();
                            final thHasLocal = thLocal.isNotEmpty && File(thLocal).existsSync();

                            return GestureDetector(
                              onTap: () {
                                _pageController.animateToPage(
                                  thumbIdx,
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeInOut,
                                );
                              },
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSel ? AppTheme.brandBlue : Colors.white24,
                                    width: isSel ? 2.5 : 1,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      if (!isThVid && thHasLocal)
                                        Image.file(File(thLocal), fit: BoxFit.cover)
                                      else
                                        Container(
                                          color: const Color(0xFF1E293B),
                                          child: Icon(
                                            isThVid ? Icons.videocam_rounded : Icons.image_rounded,
                                            color: Colors.white70,
                                            size: 20,
                                          ),
                                        ),
                                      if (isThVid)
                                        const Center(
                                          child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 18),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePage(Map<String, dynamic> item) {
    final localPath = (item['localPath'] ?? '').toString();
    final url = (item['url'] ?? '').toString();
    final fullUrl = url.startsWith('/') ? '${ApiConfig.rootUrl}$url' : url;
    final int rotationTurns = (item['rotationQuarterTurns'] as int?) ?? 0;
    final filterName = (item['filter'] ?? 'None').toString();
    final filterMatrix = _filterMatrices[filterName] ?? _filterMatrices['None']!;
    final overlayText = (item['overlayText'] ?? '').toString();
    final stickerEmoji = (item['stickerEmoji'] ?? '').toString();
    final bool hasLocalFile = localPath.isNotEmpty && File(localPath).existsSync();

    Widget imageContent;
    if (hasLocalFile) {
      imageContent = Image.file(
        File(localPath),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image_rounded, color: Colors.white38, size: 64),
        ),
      );
    } else if (isValidHttpUrl(fullUrl)) {
      imageContent = Image.network(
        fullUrl,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image_rounded, color: Colors.white38, size: 64),
        ),
      );
    } else {
      imageContent = const Center(
        child: Icon(Icons.broken_image_rounded, color: Colors.white38, size: 64),
      );
    }

    if (rotationTurns > 0) {
      imageContent = RotatedBox(quarterTurns: rotationTurns, child: imageContent);
    }

    imageContent = ColorFiltered(colorFilter: ColorFilter.matrix(filterMatrix), child: imageContent);

    return Center(
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Stack(
          alignment: Alignment.center,
          children: [
            imageContent,

            // Sticker Emoji
            if (stickerEmoji.isNotEmpty)
              Positioned(
                top: 80,
                child: Text(stickerEmoji, style: const TextStyle(fontSize: 60)),
              ),

            // Overlay Text
            if (overlayText.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  overlayText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPage(Map<String, dynamic> item) {
    final name = (item['name'] ?? 'Video').toString();
    final size = (item['size'] ?? '').toString();
    final isMuted = item['isMuted'] == true;

    return Center(
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () {
                setState(() => _isPlayingVideo = !_isPlayingVideo);
              },
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: AppTheme.brandBlue,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.brandBlue.withValues(alpha: 0.5),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: Icon(
                  _isPlayingVideo ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 46,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              size.isNotEmpty ? size : 'Video media',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            if (isMuted) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.volume_off_rounded, color: Colors.redAccent, size: 14),
                    SizedBox(width: 4),
                    Text('Audio muted', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),
            ],
            if (_isPlayingVideo) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(
                color: AppTheme.brandBlue,
                backgroundColor: Colors.white12,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// WhatsApp View Once Dashed Circle with '1' Painter
class _ViewOnceDashedPainter extends CustomPainter {
  final Color color;
  final bool isOpened;

  _ViewOnceDashedPainter({required this.color, required this.isOpened});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1.5;

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    if (isOpened) {
      strokePaint.color = color.withValues(alpha: 0.4);
      canvas.drawCircle(center, radius, strokePaint);
    } else {
      const int dashCount = 10;
      const double step = (2 * pi) / dashCount;
      const double dashArc = step * 0.65;

      for (int i = 0; i < dashCount; i++) {
        final startAngle = i * step - (pi / 2);
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          dashArc,
          false,
          strokePaint,
        );
      }
    }

    final textPainter = TextPainter(
      text: TextSpan(
        text: '1',
        style: TextStyle(
          color: color,
          fontSize: size.width * 0.54,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _ViewOnceDashedPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isOpened != isOpened;
  }
}
