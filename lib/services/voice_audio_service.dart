import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class VoiceStartResult {
  final bool granted;
  final bool started;
  final String? filePath;
  final String? error;

  const VoiceStartResult({
    required this.granted,
    required this.started,
    this.filePath,
    this.error,
  });
}

class VoiceStopResult {
  final String? filePath;
  final int sizeBytes;

  const VoiceStopResult({this.filePath, this.sizeBytes = 0});
}

class VoicePlaybackStatus {
  final bool isPlaying;
  final int positionMs;
  final int durationMs;

  const VoicePlaybackStatus({
    required this.isPlaying,
    required this.positionMs,
    required this.durationMs,
  });

  double get progress {
    if (durationMs <= 0) return 0.0;
    return (positionMs / durationMs).clamp(0.0, 1.0);
  }
}

/// Bridges Flutter ChatScreen to Android MediaRecorder & MediaPlayer for
/// real microphone audio capture and playback.
class VoiceAudioService {
  static const MethodChannel _channel = MethodChannel('com.connekt.app/audio');
  static VoidCallback? _onPlaybackCompleted;
  static bool _handlerRegistered = false;

  static void _ensureHandler() {
    if (_handlerRegistered) return;
    _handlerRegistered = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPlaybackCompleted') {
        _onPlaybackCompleted?.call();
      }
    });
  }

  static Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    try {
      final res = await _channel.invokeMethod<bool>('requestAudioPermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<VoiceStartResult> startRecording() async {
    if (kIsWeb) {
      return const VoiceStartResult(
        granted: false,
        started: false,
        error: 'Microphone recording is supported on mobile devices.',
      );
    }
    try {
      final granted = await requestPermission();
      if (!granted) {
        return const VoiceStartResult(
          granted: false,
          started: false,
          error: 'Microphone permission denied.',
        );
      }

      final raw = await _channel.invokeMapMethod<String, dynamic>('startRecording');
      final started = raw?['started'] == true;
      final path = raw?['path']?.toString();
      return VoiceStartResult(granted: true, started: started, filePath: path);
    } on PlatformException catch (e) {
      return VoiceStartResult(
        granted: e.code != 'PERMISSION_DENIED',
        started: false,
        error: e.message ?? e.code,
      );
    } catch (e) {
      return VoiceStartResult(granted: true, started: false, error: e.toString());
    }
  }

  static Future<VoiceStopResult> stopRecording({bool discard = false}) async {
    if (kIsWeb) return const VoiceStopResult();
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'stopRecording',
        {'discard': discard},
      );
      if (raw == null) return const VoiceStopResult();
      return VoiceStopResult(
        filePath: raw['path']?.toString(),
        sizeBytes: int.tryParse((raw['size'] ?? 0).toString()) ?? 0,
      );
    } catch (_) {
      return const VoiceStopResult();
    }
  }

  static Future<double> getAmplitude() async {
    if (kIsWeb) return 0.0;
    try {
      final res = await _channel.invokeMethod<num>('getAmplitude');
      return (res ?? 0).toDouble().clamp(0.0, 1.0);
    } catch (_) {
      return 0.0;
    }
  }

  static Future<int?> play(
    String source, {
    String? fallbackSource,
    VoidCallback? onComplete,
  }) async {
    if (kIsWeb) return null;
    _ensureHandler();
    _onPlaybackCompleted = onComplete;
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>('playAudio', {
        'source': source,
        'fallbackSource': fallbackSource ?? '',
      });
      if (raw == null) return null;
      return int.tryParse((raw['durationMs'] ?? '').toString());
    } catch (_) {
      return null;
    }
  }

  static Future<void> stopPlayback() async {
    _onPlaybackCompleted = null;
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>('stopAudio');
    } catch (_) {}
  }

  static Future<VoicePlaybackStatus> getPlaybackStatus() async {
    if (kIsWeb) {
      return const VoicePlaybackStatus(isPlaying: false, positionMs: 0, durationMs: 0);
    }
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>('getPlaybackStatus');
      return VoicePlaybackStatus(
        isPlaying: raw?['isPlaying'] == true,
        positionMs: int.tryParse((raw?['positionMs'] ?? 0).toString()) ?? 0,
        durationMs: int.tryParse((raw?['durationMs'] ?? 0).toString()) ?? 0,
      );
    } catch (_) {
      return const VoicePlaybackStatus(isPlaying: false, positionMs: 0, durationMs: 0);
    }
  }
}
