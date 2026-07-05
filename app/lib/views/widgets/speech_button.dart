import 'package:flutter/material.dart';

import '../../core/speech.dart';
import '../../theme/app_theme.dart';

/// A reusable "read it aloud" control. Speaks [text] (Japanese) through the
/// shared, pre-warmed [Speech] engine, gives haptic feedback, and pulses while
/// the utterance plays. Drop it anywhere a glyph, word or reading is shown.
class SpeechButton extends StatelessWidget {
  const SpeechButton({
    super.key,
    required this.text,
    this.size = 22,
    this.color,
    this.tooltip = 'Play audio',
  });

  final String text;
  final double size;
  final Color? color;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? context.jc.brand;
    final enabled = text.trim().isNotEmpty;
    return ValueListenableBuilder<bool>(
      valueListenable: Speech.instance.speaking,
      builder: (context, playing, _) => IconButton(
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        onPressed: enabled
            ? () {
                Haptics.tick();
                Speech.instance.say(text);
              }
            : null,
        icon: AnimatedScale(
          scale: playing ? 1.15 : 1.0,
          duration: Motion.fast,
          curve: Motion.out,
          child: Icon(
            playing ? Icons.volume_up_rounded : Icons.volume_up_outlined,
            size: size,
            color: enabled ? tint : context.jc.muted,
          ),
        ),
      ),
    );
  }
}
