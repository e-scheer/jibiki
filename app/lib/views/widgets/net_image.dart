import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// A single, cached network image used everywhere community images appear.
/// Disk + memory cached (no re-download on scroll/revisit) and decoded down to
/// [cacheWidth] px so a 1200px upload doesn't sit full-res in memory in a tile.
///
/// Pass a [semanticLabel] when the image carries meaning (a mnemonic drawing, a
/// pack cover); leave it null for purely decorative uses and it is hidden from
/// screen readers rather than announced as an unlabelled image.
class NetImage extends StatelessWidget {
  const NetImage({
    super.key,
    required this.url,
    this.bytes,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.errorBuilder,
    this.semanticLabel,
  });

  final String url;

  /// In-memory image (an offline pack BLOB); wins over [url] when set.
  final Uint8List? bytes;
  final BoxFit fit;

  /// Target decode width in device pixels (memory downscale). Null = full size.
  final int? cacheWidth;
  final WidgetBuilder? errorBuilder;

  /// Announced to screen readers. Null = decorative (hidden from assistive tech).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final Widget image = bytes != null
        ? Image.memory(
            bytes!,
            fit: fit,
            cacheWidth: cacheWidth,
            errorBuilder: (c, _, __) =>
                errorBuilder?.call(c) ?? Container(color: jc.surfaceAlt),
          )
        : CachedNetworkImage(
            imageUrl: url,
            fit: fit,
            memCacheWidth: cacheWidth,
            fadeInDuration: Motion.timed(context, Motion.fast),
            placeholder: (_, __) => Container(color: jc.surfaceAlt),
            errorWidget: (c, _, __) =>
                errorBuilder?.call(c) ?? Container(color: jc.surfaceAlt),
          );
    if (semanticLabel == null) return ExcludeSemantics(child: image);
    return Semantics(image: true, label: semanticLabel, child: image);
  }
}
