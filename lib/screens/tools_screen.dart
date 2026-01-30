import 'package:flutter/material.dart';
import 'browser_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    //TEMA AYARLARI
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: Text(
          "Seyahat Araçları",
          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
        ),
        centerTitle: true,
        backgroundColor: cardColor,
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 15,
          mainAxisSpacing: 15,
          children: [
            _buildToolCard(
              context,
              Icons.flight_takeoff,
              "Uçuşlar",
              const Color(0xFFFF9F1C),
              "https://www.skyscanner.com.tr",
            ),
            _buildToolCard(
              context,
              Icons.hotel_rounded,
              "Oteller",
              const Color(0xFF2EC4B6),
              "https://www.booking.com",
            ),
            _buildToolCard(
              context,
              Icons.directions_car_rounded,
              "Araç Kiralama",
              const Color(0xFFCB3066),
              "https://www.rentalcars.com",
            ),
            _buildToolCard(
              context,
              Icons.restaurant_menu_rounded,
              "Yemek & Keşif",
              const Color(0xFFE71D36),
              "https://www.tripadvisor.com.tr/Restaurants",
            ),

            _buildToolCard(
              context,
              Icons.currency_exchange,
              "Döviz Çevirici",
              Colors.green,
              "https://www.xe.com/currencyconverter/",
            ),
            _buildToolCard(
              context,
              Icons.translate,
              "Çeviri",
              Colors.blue,
              "https://translate.google.com/",
            ),
            _buildToolCard(
              context,
              Icons.wb_sunny,
              "Hava Durumu",
              Colors.orange,
              "https://weather.com/",
            ),
            _buildToolCard(
              context,
              Icons.flight,
              "Uçuş Takip",
              Colors.purple,
              "https://www.flightradar24.com/",
            ),
            _buildToolCard(
              context,
              Icons.schedule,
              "Dünya Saatleri",
              Colors.teal,
              "https://time.is/",
            ),
            _buildToolCard(
              context,
              Icons.local_hospital,
              "Acil Numaralar",
              Colors.redAccent,
              "",
              isAction: true,
              onTap: () => _showEmergencyDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolCard(
    BuildContext context,
    IconData icon,
    String title,
    Color color,
    String url, {
    bool isAction = false,
    VoidCallback? onTap,
  }) {
    //Tema Renkleri
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : Colors.black87;

    return GestureDetector(
      onTap: isAction
          ? onTap
          : () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BrowserScreen(url: url, title: title),
              ),
            ),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 15),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEmergencyDialog(BuildContext context) {
    //Tema Renkleri
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white70 : Colors.black54;

    Future<void> makeCall(String number) async {
      final Uri launchUri = Uri(scheme: 'tel', path: number);
      try {
        if (await canLaunchUrl(launchUri)) {
          await launchUrl(launchUri);
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Bu cihazda arama yapılamıyor."),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint("Arama hatası: $e");
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 10),
            Text("Acil Durum", style: TextStyle(color: textColor)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.phone, color: Colors.red),
              ),
              title: Text(
                "112 - Genel Acil",
                style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
              ),
              subtitle: Text(
                "Türkiye & Avrupa",
                style: TextStyle(color: subtitleColor),
              ),
              onTap: () => makeCall("112"),
            ),
            Divider(color: isDark ? Colors.white24 : Colors.grey.shade300),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.local_police, color: Colors.blue),
              ),
              title: Text(
                "911 - Genel Acil",
                style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
              ),
              subtitle: Text(
                "ABD & Kanada",
                style: TextStyle(color: subtitleColor),
              ),
              onTap: () => makeCall("911"),
            ),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                "Not: Bulunduğunuz ülkenin yerel acil durum numaralarını mutlaka kontrol edin.",
                style: TextStyle(fontSize: 12, color: Colors.brown),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Kapat", style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}
