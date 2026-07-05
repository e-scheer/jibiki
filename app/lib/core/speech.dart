import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Reads Japanese aloud through the on-device TTS engine. Best-effort: with no
/// Japanese voice it simply stays silent rather than throwing.
///
/// One shared, **pre-warmed** instance. The slow part of TTS is the first call —
/// binding the platform engine and loading the ja-JP voice can take up to a
/// second the very first time. [warmUp] pays that cost once at app start, in the
/// background, so the user's first "play" tap plays instantly.
class Speech {
  Speech._();
  static final Speech instance = Speech._();

  final FlutterTts _tts = FlutterTts();

  /// True while an utterance is playing — lets buttons show an active state.
  final ValueNotifier<bool> speaking = ValueNotifier(false);

  Future<void>? _warming;

  /// Bind + configure the engine ahead of the first tap. Idempotent; safe to
  /// call from many places (each [SpeechButton] does).
  Future<void> warmUp() => _warming ??= _init();

  Future<void> _init() async {
    try {
      // iOS: route through a shared session that ducks (not stops) other audio,
      // and set it up now so the first utterance doesn't pay the session cost.
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        await _tts.setSharedInstance(true);
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.duckOthers,
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          ],
          IosTextToSpeechAudioMode.voicePrompt,
        );
      }
      await _tts.setLanguage('ja-JP');
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);
      _tts.setStartHandler(() => speaking.value = true);
      _tts.setCompletionHandler(() => speaking.value = false);
      _tts.setCancelHandler(() => speaking.value = false);
      _tts.setErrorHandler((_) => speaking.value = false);
    } catch (_) {
      // A platform without JA TTS — say() will simply no-op.
    }
  }

  Future<void> say(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    await warmUp(); // instant once warm
    try {
      await _tts.stop(); // interrupt any current utterance so taps feel snappy
      await _tts.speak(t);
    } catch (_) {
      // audio is an enhancement, never a failure path
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
    speaking.value = false;
  }
}
