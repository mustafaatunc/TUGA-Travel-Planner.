import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'auth_screen.dart';
import '../data/city_data.dart';
import 'onboarding_screen.dart';
import '../main.dart';
import 'paywall_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isDataLoading = false;
  bool _isImageLoading = false;
  bool _darkModeEnabled = false;
  bool _isProMember = false;

  // İstatistikler
  int _planCount = 0;
  int _favCount = 0;

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _fetchUserStats();
  }

  Future<void> _fetchUserStats() async {
    if (_user == null) return;
    try {
      var tripSnapshot = await FirebaseFirestore.instance
          .collection('trips')
          .where('userId', isEqualTo: _user!.uid)
          .count()
          .get();

      final prefs = await SharedPreferences.getInstance();
      List<String> favs = prefs.getStringList('favoriler') ?? [];

      if (mounted) {
        setState(() {
          _planCount = tripSnapshot.count ?? 0;
          _favCount = favs.length;
        });
      }
    } catch (e) {
      debugPrint("İstatistik hatası: $e");
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _darkModeEnabled = themeNotifier.value == ThemeMode.dark;
      _isProMember = prefs.getBool('is_pro_test') ?? false;
    });
  }

  Future<void> _openPaywall() async {
    if (_isProMember) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Zaten Premium Üyesiniz! 🌟"),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PaywallScreen()),
    );

    if (result == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_pro_test', true);

      if (mounted) {
        setState(() {
          _isProMember = true;
        });
      }
    }
  }

  Future<void> _changeProfilePhoto() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
        maxWidth: 800,
      );

      if (pickedFile != null) {
        setState(() => _isImageLoading = true);
        File file = File(pickedFile.path);

        String fileName = 'profile_photos/${_user!.uid}.jpg';
        Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
        await storageRef.putFile(file);

        String downloadUrl = await storageRef.getDownloadURL();
        await _user!.updatePhotoURL(downloadUrl);
        await _user!.reload();

        await CachedNetworkImage.evictFromCache(downloadUrl);

        if (mounted) {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Fotoğraf güncellendi! ✨"),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Yükleme başarısız oldu."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isImageLoading = false);
    }
  }

  Future<void> _deleteAccount() async {
    //Tema
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : Colors.black87;

    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        content: Text(
          "Bu işlem geri alınamaz! Tüm verilerin silinecek.",
          style: TextStyle(color: textColor.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Vazgeç", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "Evet, Sil",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Hesap siliniyor...")));

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      var snapshots = await firestore
          .collection('trips')
          .where('userId', isEqualTo: user.uid)
          .get();
      for (var doc in snapshots.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(firestore.collection('users').doc(user.uid));
      await batch.commit();

      await FirebaseAuth.instance.signOut();
      await user.delete();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        await FirebaseAuth.instance.signOut();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _adminDbUpload() async {
    // 🎨 Tema
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : Colors.black87;

    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        title: Text("⚠️ Admin İşlemi", style: TextStyle(color: textColor)),
        content: Text(
          "city_data.dart içindeki tüm şehirler Firestore 'mekanlar' koleksiyonuna yüklenecek/güncellenecek. Onaylıyor musun?",
          style: TextStyle(color: textColor.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("İptal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("YÜKLE", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDataLoading = true);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Veriler yükleniyor... ⏳")));

    try {
      var batch = FirebaseFirestore.instance.batch();
      var collection = FirebaseFirestore.instance.collection('mekanlar');
      var sehirler = CityData.popularCities;

      for (var sehir in sehirler) {
        var docRef = collection.doc(sehir.id);
        Map<String, dynamic> veri = sehir.toMap();
        veri['haritadaGoster'] = true;
        batch.set(docRef, veri);
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ BAŞARILI! Tüm veriler güncellendi."),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("HATA: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isDataLoading = false);
    }
  }

  void _showEditProfileDialog() {
    //Tema
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : Colors.black87;

    final TextEditingController nameController = TextEditingController(
      text: _user?.displayName,
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Profili Düzenle", style: TextStyle(color: textColor)),
        content: TextField(
          controller: nameController,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            labelText: "Ad Soyad",
            labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                await _user?.updateDisplayName(nameController.text.trim());
                await _user?.reload();
                if (mounted) {
                  setState(() {});
                  Navigator.pop(context);
                }
              }
            },
            child: const Text("Kaydet"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    //TEMA AYARLARI
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildProfileHeader(isDark),
            Transform.translate(
              offset: const Offset(0, -40),
              child: _buildStatsCard(cardColor, textColor),
            ),

            // Pro Kartı
            GestureDetector(onTap: _openPaywall, child: _buildProCard()),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildSectionHeader("Hesap Ayarları", isDark),
                  _buildSettingsTile(
                    icon: Icons.person_outline_rounded,
                    title: "Profili Düzenle",
                    color: Colors.blueAccent,
                    cardColor: cardColor,
                    textColor: textColor,
                    onTap: _showEditProfileDialog,
                  ),

                  // Tema Butonu
                  _buildSettingsTile(
                    icon: Icons.dark_mode_outlined,
                    title: "Karanlık Mod",
                    color: Colors.deepPurpleAccent,
                    cardColor: cardColor,
                    textColor: textColor,
                    onTap: () {},
                    trailing: Switch(
                      value: _darkModeEnabled,
                      onChanged: (val) async {
                        final prefs = await SharedPreferences.getInstance();
                        setState(() => _darkModeEnabled = val);
                        await prefs.setBool('dark_mode', val);
                        themeNotifier.value = val
                            ? ThemeMode.dark
                            : ThemeMode.light;
                      },
                      activeColor: const Color(0xFF0066CC),
                    ),
                  ),

                  const SizedBox(height: 20),
                  _buildSectionHeader("Destek", isDark),

                  _buildSettingsTile(
                    icon: Icons.support_agent_rounded,
                    title: "Yardım & Destek",
                    color: Colors.teal,
                    cardColor: cardColor,
                    textColor: textColor,
                    onTap: () async {
                      final Uri emailUri = Uri(
                        scheme: 'mailto',
                        path: 'iletisim@tugaapp.com',
                        queryParameters: {'subject': 'TUGA Destek'},
                      );
                      try {
                        if (!await launchUrl(emailUri)) {
                          if (mounted)
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Mail uygulaması bulunamadı."),
                              ),
                            );
                        }
                      } catch (e) {
                        debugPrint("Mail hatası: $e");
                      }
                    },
                  ),

                  _buildSettingsTile(
                    icon: Icons.logout_rounded,
                    title: "Çıkış Yap",
                    color: Colors.redAccent,
                    cardColor: cardColor,
                    textColor: textColor,
                    hideArrow: true,
                    onTap: () async {
                      await FirebaseAuth.instance.signOut();
                      if (mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const AuthScreen(),
                          ),
                          (route) => false,
                        );
                      }
                    },
                  ),

                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _deleteAccount,
                    child: Text(
                      "Hesabımı Sil",
                      style: TextStyle(
                        color: Colors.red.shade300,
                        fontSize: 12,
                      ),
                    ),
                  ),

                  // Admin Butonu
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    child: OutlinedButton.icon(
                      onPressed: _isDataLoading ? null : _adminDbUpload,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.deepOrange,
                        side: const BorderSide(color: Colors.deepOrange),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _isDataLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_upload),
                      label: Text(
                        _isDataLoading
                            ? "Yükleniyor..."
                            : "ADMIN: DB'yi Güncelle",
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),
                  Opacity(
                    opacity: 0.5,
                    child: Column(
                      children: [
                        Image.asset(
                          'assets/images/ic_foreground.png',
                          height: 40,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          "v1.0.0",
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 25),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: _isProMember
            ? const LinearGradient(
                colors: [Color(0xFFDAA520), Color(0xFFFFD700)],
              )
            : const LinearGradient(
                colors: [Color(0xFF2E3192), Color(0xFF1BFFFF)],
              ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _isProMember
                ? Colors.amber.withOpacity(0.3)
                : const Color(0xFF2E3192).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isProMember ? Icons.star : Icons.workspace_premium,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isProMember ? "TUGA Pro Üyesisiniz" : "TUGA Pro'ya Geç",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isProMember
                      ? "Ayrıcalıkların tadını çıkarın! ✨"
                      : "Sınırsız AI planlama ve reklamsız deneyim.",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (!_isProMember)
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 60, bottom: 60),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E1E1E), const Color(0xFF2C2C2C)]
              : [const Color(0xFF0066CC), const Color(0xFF003366)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    const BoxShadow(color: Colors.black26, blurRadius: 10),
                  ],
                ),
                child: ClipOval(
                  child: _user?.photoURL != null
                      ? CachedNetworkImage(
                          imageUrl: _user!.photoURL!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              const CircularProgressIndicator(
                                color: Colors.white,
                              ),
                          errorWidget: (_, __, ___) => const Icon(
                            Icons.person,
                            size: 50,
                            color: Colors.grey,
                          ),
                        )
                      : Container(
                          color: Colors.white,
                          child: const Icon(
                            Icons.person,
                            size: 50,
                            color: Colors.grey,
                          ),
                        ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _changeProfilePhoto,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black26, blurRadius: 4),
                      ],
                    ),
                    child: _isImageLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.camera_alt,
                            size: 18,
                            color: Colors.black87,
                          ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            _user?.displayName ?? "Gezgin",
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            _user?.email ?? "",
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(Color bgColor, Color textColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            "Planlar",
            _planCount.toString(),
            Icons.map_outlined,
            textColor,
          ),
          Container(height: 40, width: 1, color: Colors.grey.shade200),
          _buildStatItem(
            "Favoriler",
            _favCount.toString(),
            Icons.favorite_border,
            textColor,
          ),
          Container(height: 40, width: 1, color: Colors.grey.shade200),
          _buildStatItem("Seviye", "1", Icons.star_outline, textColor),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color textColor,
  ) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF0066CC), size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
    required Color cardColor,
    required Color textColor,
    String? subtitle,
    Widget? trailing,
    bool hideArrow = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: textColor,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              )
            : null,
        trailing:
            trailing ??
            (hideArrow
                ? null
                : const Icon(Icons.chevron_right_rounded, color: Colors.grey)),
      ),
    );
  }
}
