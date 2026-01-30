import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GooglePlaceImage extends StatefulWidget {
  final String placeName;
  final String apiKey;
  final BoxFit fit;

  const GooglePlaceImage({
    super.key,
    required this.placeName,
    required this.apiKey,
    this.fit = BoxFit.cover,
  });

  @override
  State<GooglePlaceImage> createState() => _GooglePlaceImageState();
}

class _GooglePlaceImageState extends State<GooglePlaceImage> {
  String? _imageUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant GooglePlaceImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.placeName != oldWidget.placeName) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (widget.apiKey.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final cacheKey =
        "img_cache_v2_${widget.placeName.replaceAll(' ', '_').toLowerCase()}";
    final cachedUrl = prefs.getString(cacheKey);

    if (cachedUrl != null) {
      if (mounted) {
        setState(() {
          _imageUrl = cachedUrl;
          _isLoading = false;
        });
      }
      return;
    }

    await _fetchAndCacheImage(prefs, cacheKey);
  }

  Future<void> _fetchAndCacheImage(
    SharedPreferences prefs,
    String cacheKey,
  ) async {
    final searchUrl = Uri.parse(
      "https://maps.googleapis.com/maps/api/place/textsearch/json?query=${widget.placeName}&key=${widget.apiKey}",
    );

    try {
      final response = await http.get(searchUrl);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] != null && (data['results'] as List).isNotEmpty) {
          final firstResult = data['results'][0];
          if (firstResult['photos'] != null) {
            final photoRef = firstResult['photos'][0]['photo_reference'];
            final newUrl =
                "https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photo_reference=$photoRef&key=${widget.apiKey}";

            await prefs.setString(cacheKey, newUrl);
            if (mounted) {
              setState(() {
                _imageUrl = newUrl;
                _isLoading = false;
              });
            }
          } else {
            if (mounted) setState(() => _isLoading = false);
          }
        } else {
          if (mounted) setState(() => _isLoading = false);
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: Colors.grey.shade200,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_imageUrl != null) {
      return CachedNetworkImage(
        imageUrl: _imageUrl!,
        fit: widget.fit,
        memCacheHeight: 600,
        placeholder: (context, url) => Container(color: Colors.grey.shade200),
        errorWidget: (context, url, error) => _buildDefaultImage(),
      );
    }

    return _buildDefaultImage();
  }

  Widget _buildDefaultImage() {
    return Image.asset(
      "assets/images/default_city.jpg",
      fit: widget.fit,
      errorBuilder: (context, error, stackTrace) => Container(
        color: Colors.grey.shade300,
        child: const Icon(Icons.location_city, color: Colors.grey, size: 40),
      ),
    );
  }
}
