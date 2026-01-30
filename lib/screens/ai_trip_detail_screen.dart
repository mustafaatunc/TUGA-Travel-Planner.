import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AiTripDetailScreen extends StatelessWidget {
  final Map<String, dynamic> planData;
  final VoidCallback? onSave;

  const AiTripDetailScreen({super.key, required this.planData, this.onSave});

  @override
  Widget build(BuildContext context) {
    // Veri güvenliği
    final destination = planData['destination'] ?? 'Plan Detayı';
    final summary = planData['summary'] ?? '';
    final List<dynamic> days = planData['days'] ?? [];

    //TEMA AYARLARI
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: scaffoldBg, //
      appBar: AppBar(
        title: Text(
          destination,
          style: TextStyle(fontWeight: FontWeight.bold, color: textColor), //
        ),
        centerTitle: true,
        backgroundColor: cardColor, //
        foregroundColor: textColor,
        elevation: 0,
        actions: [
          if (onSave != null)
            IconButton(
              onPressed: onSave,
              icon: const Icon(Icons.save_alt, color: Colors.teal),
              tooltip: "Planı Kaydet",
            ),
        ],
      ),
      floatingActionButton: onSave != null
          ? FloatingActionButton.extended(
              onPressed: onSave,
              label: const Text("Bu Planı Kaydet"),
              icon: const Icon(Icons.check),
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            )
          : null,
      body: days.isEmpty
          ? _buildEmptyState(isDark)
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
              physics: const BouncingScrollPhysics(),
              children: [
                _buildHeaderCard(destination, summary),

                const SizedBox(height: 25),
                Text(
                  "Günlük Rota",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 15),

                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: days.length,
                  itemBuilder: (context, index) {
                    return _buildDaySection(
                      days[index],
                      index == days.length - 1,
                      isDark,
                      cardColor,
                      textColor,
                    );
                  },
                ),
              ],
            ),
    );
  }

  Widget _buildHeaderCard(String destination, String summary) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0066CC), Color(0xFF004e92)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0066CC).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assistant_photo, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  destination.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              summary,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDaySection(
    Map<String, dynamic> dayData,
    bool isLastDay,
    bool isDark,
    Color cardColor,
    Color textColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // GÜN BAŞLIĞI
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.grey.shade200,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            "${dayData['day']}. GÜN",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF0066CC),
              fontSize: 14,
            ),
          ),
        ),
        const SizedBox(height: 15),

        // AKTİVİTELER
        Container(
          margin: const EdgeInsets.only(left: 15),
          padding: const EdgeInsets.only(left: 20, bottom: 20),
          decoration: BoxDecoration(
            border: isLastDay
                ? null
                : Border(
                    left: BorderSide(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
          ),
          child: Column(
            children: [
              _buildActivityCard(
                Icons.wb_twilight,
                "Sabah",
                dayData['morning'],
                Colors.orange,
                cardColor,
                textColor,
              ),
              const SizedBox(height: 15),
              _buildActivityCard(
                Icons.wb_sunny,
                "Öğle",
                dayData['afternoon'],
                Colors.amber.shade700,
                cardColor,
                textColor,
              ),
              const SizedBox(height: 15),
              _buildActivityCard(
                Icons.nights_stay,
                "Akşam",
                dayData['evening'],
                Colors.indigo,
                cardColor,
                textColor,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActivityCard(
    IconData icon,
    String time,
    Map<String, dynamic>? slotData,
    Color iconColor,
    Color cardColor,
    Color textColor,
  ) {
    if (slotData == null || slotData.isEmpty) return const SizedBox();

    final location = slotData['location_key'] ?? "";
    final desc = slotData['description'] ?? "";
    final imageUrl = slotData['resimUrl'];

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  time,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                    fontSize: 15,
                  ),
                ),
                if (location.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  const Text("•", style: TextStyle(color: Colors.grey)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      location,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: textColor,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (imageUrl != null && imageUrl.toString().startsWith('http'))
            SizedBox(
              height: 150,
              width: double.infinity,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: Colors.grey.shade100,
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, url, error) => _buildDefaultImage(),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              desc,
              style: TextStyle(
                color: textColor.withOpacity(0.8),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultImage() {
    return Container(
      color: Colors.grey.shade200,
      child: const Center(child: Icon(Icons.image, color: Colors.grey)),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.map_outlined,
            size: 80,
            color: isDark ? Colors.white24 : Colors.grey.shade300,
          ),
          const SizedBox(height: 20),
          Text(
            "Plan detayları yüklenemedi.",
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white60 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}
