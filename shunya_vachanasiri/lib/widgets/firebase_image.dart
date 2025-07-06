// lib/widgets/firebase_image.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shunya_vachanasiri/providers/app_state.dart';

class FirebaseImage extends StatefulWidget {
  final int sharanaId;
  final String imageType; // 'coverart' or 'mini'
  final double size;
  final double borderRadius;
  final Widget placeholder;
  final Widget errorWidget;

  const FirebaseImage({
    super.key,
    required this.sharanaId,
    required this.imageType,
    this.size = 200,
    this.borderRadius = 0,
    this.placeholder = const Icon(Icons.music_note, color: Colors.white70),
    this.errorWidget = const Icon(Icons.music_note, color: Colors.white70),
  });

  @override
  State<FirebaseImage> createState() => _FirebaseImageState();
}

class _FirebaseImageState extends State<FirebaseImage> {
  static final Map<String, ImageProvider> _imageCache = {};
  late String _imageUrl;
  bool _isValidUrl = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeImage();
  }

  @override
  void didUpdateWidget(FirebaseImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sharanaId != widget.sharanaId ||
        oldWidget.imageType != widget.imageType) {
      _initializeImage();
    }
  }

  void _initializeImage() {
    final cacheKey = _getCacheKey();

    // 1. Check memory cache first
    if (_imageCache.containsKey(cacheKey)) {
      setState(() {
        _isLoading = false;
        _isValidUrl = true;
      });
      return;
    }

    // 2. Generate dynamic URL
    final generatedUrl =
        AppConstants.getSharanaImageUrl(widget.sharanaId, widget.imageType);

    // 3. Validate URL format
    if (!_validateUrl(generatedUrl)) {
      setState(() {
        _isValidUrl = false;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _imageUrl = generatedUrl;
      _isValidUrl = true;
      _isLoading = false;
    });
  }

  String _getCacheKey() {
    return '${widget.imageType}-${widget.sharanaId}';
  }

  bool _validateUrl(String url) {
    if (url.isEmpty) return false;
    try {
      final uri = Uri.parse(url);
      return uri.isAbsolute;
    } catch (e) {
      return false;
    }
  }

  void _cacheImageProvider(ImageProvider provider) {
    final cacheKey = _getCacheKey();
    if (!_imageCache.containsKey(cacheKey)) {
      _imageCache[cacheKey] = provider;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cacheKey = _getCacheKey();
    final cachedProvider = _imageCache[cacheKey];

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        color: Colors.grey[800],
      ),
      child: _isLoading
          ? widget.placeholder
          : cachedProvider != null
              ? _buildCachedImage(cachedProvider)
              : _isValidUrl
                  ? CachedNetworkImage(
                      imageUrl: _imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => widget.placeholder,
                      errorWidget: (_, __, ___) => widget.errorWidget,
                      imageBuilder: (context, imageProvider) {
                        _cacheImageProvider(imageProvider);
                        return _buildCachedImage(imageProvider);
                      },
                    )
                  : widget.errorWidget,
    );
  }

  Widget _buildCachedImage(ImageProvider provider) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Image(
        image: provider,
        fit: BoxFit.cover,
        width: widget.size,
        height: widget.size,
      ),
    );
  }
}
