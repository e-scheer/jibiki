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
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        // Google TTS ships a real Japanese voice; prefer it over any OEM engine
        // that may only speak the phone's UI language — otherwise 日本語 comes out
        // read with the device's default (e.g. French) accent.
        try {
          final engines = (await _tts.getEngines as List?)?.cast<String>() ?? const [];
          if (engines.contains('com.google.android.tts')) {
            await _tts.setEngine('com.google.android.tts');
          }
        } catch (_) {}
      }
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
      await _applyJapaneseVoice();
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

  /// Pin the engine to an actual Japanese voice. `setLanguage('ja-JP')` alone does
  /// not always switch the *voice*, so a device whose default voice is French will
  /// keep reading Japanese with a French accent. Picking a ja-* voice explicitly
  /// fixes the pronunciation; a local (offline) voice is preferred when present.
  Future<void> _applyJapaneseVoice() async {
    try {
      final available = await _tts.isLanguageAvailable('ja-JP');
      final raw = await _tts.getVoices;
      final voices = (raw as List?)?.whereType<Map>().toList() ?? const <Map>[];
      final ja = voices.where((v) {
        final loc = (v['locale'] ?? '').toString().toLowerCase().replaceAll('_', '-');
        return loc.startsWith('ja');
      }).toList();
      debugPrint('[Speech] ja-JP available=$available · ${voices.length} voices, '
          '${ja.length} japanese: ${ja.map((v) => v['name']).take(6).toList()}');
      if (ja.isNotEmpty) {
        final v = ja.firstWhere(
          (v) => (v['name'] ?? '').toString().toLowerCase().contains('local'),
          orElse: () => ja.first,
        );
        await _tts.setVoice({'name': '${v['name']}', 'locale': '${v['locale']}'});
        debugPrint('[Speech] using voice ${v['name']} (${v['locale']})');
      } else {
        debugPrint('[Speech] no Japanese voice installed — pronunciation will be wrong');
      }
    } catch (e) {
      debugPrint('[Speech] voice selection failed: $e');
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
