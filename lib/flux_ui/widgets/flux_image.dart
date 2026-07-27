import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../flux_engine/radio_engine.dart';

class FluxImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool useProxy;

  const FluxImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.useProxy = true,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return errorWidget ?? _defaultError(context);
    }

    final engine = context.read<RadioEngine>();
    String finalUrl = imageUrl;
    
    // Apply Data Saver logic: Resize image via proxy to save bandwidth
    if (engine.dataSaver && useProxy && imageUrl.startsWith('http')) {
      final int size = (width ?? 100).toInt() * 2; // Request 2x for retina-ish quality but still small
      finalUrl = 'https://wsrv.nl/?url=${Uri.encodeComponent(imageUrl)}&w=$size&h=$size&fit=cover&q=60';
    }

    return CachedNetworkImage(
      imageUrl: finalUrl,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: width != null ? (width! * 2).toInt() : null,
      memCacheHeight: height != null ? (height! * 2).toInt() : null,
      placeholder: (context, url) => placeholder ?? _defaultPlaceholder(context),
      errorWidget: (context, url, error) => errorWidget ?? _defaultError(context),
      fadeOutDuration: const Duration(milliseconds: 300),
      fadeInDuration: const Duration(milliseconds: 500),
    );
  }

  Widget _defaultPlaceholder(BuildContext context) {
    return Center(
      child: Icon(
        Icons.radio_rounded,
        color: Colors.red.withValues(alpha: 0.5),
        size: (width ?? 24) * 0.5,
      ),
    );
  }

  Widget _defaultError(BuildContext context) {
    return Center(
      child: Icon(
        Icons.radio_rounded,
        color: Colors.red,
        size: (width ?? 24) * 0.5,
      ),
    );
  }
}
