import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class MemoryScreen extends StatefulWidget {
  final String tripId;
  final String tripTitle;
  final String destination;

  const MemoryScreen({
    super.key,
    required this.tripId,
    required this.tripTitle,
    required this.destination,
  });

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('tr', null);
  }

  // Fotoğraf Yükleme Fonksiyonu
  Future<void> _uploadMemory() async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (pickedFile != null) {
      setState(() => _isUploading = true);
      try {
        File file = File(pickedFile.path);
        String fileName =
            'memories/${widget.tripId}/${DateTime.now().millisecondsSinceEpoch}.jpg';
        Reference storageRef = FirebaseStorage.instance.ref().child(fileName);

        await storageRef.putFile(file);
        String downloadUrl = await storageRef.getDownloadURL();

        await FirebaseFirestore.instance
            .collection('trips')
            .doc(widget.tripId)
            .collection('memories')
            .add({
              'url': downloadUrl,
              'date': FieldValue.serverTimestamp(),
              'caption': '',
            });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Anı albüme eklendi! 📸"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Hata: $e")));
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  // Fotoğraf Silme
  Future<void> _deleteMemory(String docId, String photoUrl) async {
    try {
      try {
        await FirebaseStorage.instance.refFromURL(photoUrl).delete();
      } catch (_) {
        debugPrint("Dosya Storage'da bulunamadı, Firestore'dan siliniyor...");
      }

      await FirebaseFirestore.instance
          .collection('trips')
          .doc(widget.tripId)
          .collection('memories')
          .doc(docId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Anı silindi 🗑️"),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint("Silme hatası: $e");
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Bir hata oluştu")));
    }
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
      body: CustomScrollView(
        slivers: [
          //HEADER
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: scaffoldBg,
            foregroundColor: textColor,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.tripTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl:
                        "https://loremflickr.com/800/600/${widget.destination.replaceAll(' ', '')},travel/all",
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: isDark ? Colors.grey[900] : Colors.grey[300],
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: isDark ? Colors.grey[900] : Colors.grey[300],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          //KONTROL PANELİ
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Hikaye Albümü",
                    style: TextStyle(
                      color: textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_isUploading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: _uploadMemory,
                      icon: const Icon(Icons.add_a_photo, size: 18),
                      label: const Text("Fotoğraf Ekle"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cardColor,
                        foregroundColor: textColor,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          //FOTOĞRAF IZGARASI
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('trips')
                .doc(widget.tripId)
                .collection('memories')
                .orderBy('date', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.photo_library_outlined,
                          size: 70,
                          color: isDark ? Colors.white24 : Colors.grey.shade400,
                        ),
                        const SizedBox(height: 15),
                        Text(
                          "Henüz hiç fotoğraf yok.",
                          style: TextStyle(
                            color: isDark
                                ? Colors.white60
                                : Colors.grey.shade600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          "İlk anıyı eklemek için butona bas 👆",
                          style: TextStyle(
                            color: isDark
                                ? Colors.white38
                                : Colors.grey.shade500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              var photos = snapshot.data!.docs;

              return SliverPadding(
                padding: const EdgeInsets.all(10),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.75,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    var photo = photos[index];
                    String url = photo['url'];

                    String dateStr = "";
                    if (photo.data().toString().contains('date') &&
                        photo['date'] != null) {
                      DateTime dt = (photo['date'] as Timestamp).toDate();
                      dateStr = DateFormat('dd MMM yyyy', 'tr').format(dt);
                    }

                    return GestureDetector(
                      onLongPress: () => _showDeleteDialog(photo.id, url),
                      onTap: () => _showFullImage(url, dateStr),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Hero(
                                tag: url,
                                child: CachedNetworkImage(
                                  imageUrl: url,
                                  fit: BoxFit.cover,
                                  memCacheHeight: 400,
                                  placeholder: (context, url) => Container(
                                    color: isDark
                                        ? Colors.grey[800]
                                        : Colors.grey[200],
                                  ),
                                  errorWidget: (context, url, error) =>
                                      const Icon(
                                        Icons.broken_image,
                                        color: Colors.grey,
                                      ),
                                ),
                              ),
                              if (dateStr.isNotEmpty)
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          Colors.black.withOpacity(0.8),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                    child: Text(
                                      dateStr,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }, childCount: photos.length),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 50)),
        ],
      ),
    );
  }

  // Tam Ekran Gösterim
  void _showFullImage(String url, String date) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: Hero(
                tag: url,
                child: CachedNetworkImage(
                  imageUrl: url,
                  placeholder: (context, url) =>
                      const CircularProgressIndicator(color: Colors.white),
                  errorWidget: (context, url, error) => const Icon(
                    Icons.broken_image,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            if (date.isNotEmpty)
              Positioned(
                bottom: 40,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    date,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Silme Diyaloğu
  void _showDeleteDialog(String docId, String url) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : Colors.black87;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(
          "Fotoğrafı Sil",
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Bu anıyı silmek istiyor musunuz?",
          style: TextStyle(color: textColor.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("İptal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteMemory(docId, url);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text("Sil"),
          ),
        ],
      ),
    );
  }
}
