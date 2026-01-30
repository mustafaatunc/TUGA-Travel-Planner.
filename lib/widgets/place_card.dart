import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PlaceCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final String? tagPrefix;

  const PlaceCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.tagPrefix,
  });

  @override
  Widget build(BuildContext context) {
    //TEMA AYARLARI
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white70 : Colors.grey.shade600;
    final placeholderColor = isDark ? Colors.white10 : Colors.grey.shade200;

    // URL Kontrolü
    final bool isValidUrl = imageUrl.isNotEmpty && imageUrl.startsWith('http');

    return Card(
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            //RESİM BÖLÜMÜ
            SizedBox(
              height: 150,
              width: double.infinity,
              child: Hero(
                tag: "${tagPrefix ?? ''}$imageUrl$title",
                child: isValidUrl
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        memCacheHeight: 500,
                        placeholder: (context, url) => Container(
                          color: placeholderColor,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (context, url, error) =>
                            _buildErrorWidget(isDark),
                      )
                    : _buildErrorWidget(isDark),
              ),
            ),

            //BİLGİ BÖLÜMÜ
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: subtitleColor, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: trailing!,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(bool isDark) {
    return Container(
      color: isDark ? Colors.white10 : Colors.grey.shade300,
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_not_supported_outlined,
            color: isDark ? Colors.white30 : Colors.grey,
            size: 40,
          ),
          const SizedBox(height: 5),
          Text(
            "Görsel yok",
            style: TextStyle(
              color: isDark ? Colors.white30 : Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
