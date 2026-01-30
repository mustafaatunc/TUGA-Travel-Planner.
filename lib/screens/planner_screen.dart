import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

// Ekran importları
import 'trip_detail_screen.dart';
import 'ai_planner_screen.dart';
import 'paywall_screen.dart';
import 'memory_screen.dart';
import '../data/city_data.dart';
import '../widgets/google_place_image.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final String _placesApiKey = dotenv.env['GOOGLE_PLACES_API_KEY'] ?? "";
  final String _pexelsApiKey = dotenv.env['PEXELS_API_KEY'] ?? "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // AI PLANLAMA MANTIĞI
  Future<void> _onAiPlanPressed() async {
    bool isPro = await _checkProStatus();

    if (!mounted) return;

    if (isPro) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const AiPlannerScreen()),
      );
    } else {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PaywallScreen()),
      );

      if (result == true) {
        await _saveProStatus();
        setState(() {});

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AiPlannerScreen()),
          );
        }
      }
    }
  }

  Future<bool> _checkProStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_pro_test') ?? false;
  }

  Future<void> _saveProStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_pro_test', true);
  }

  //MANUEL PLAN EKLEME
  void _manuelPlanEkle(BuildContext context, String uid) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ManualTripDialog(
        uid: uid,
        placesApiKey: _placesApiKey,
        pexelsApiKey: _pexelsApiKey,
      ),
    );
  }

  // PLAN SİLME
  void _planiSil(DocumentReference ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Planı Sil"),
        content: const Text(
          "Bu geziyi ve içerisindeki TÜM durakları, notları ve harcamaları kalıcı olarak silmek istediğine emin misin?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("İptal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);

              if (!mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text("Siliniyor...")));

              try {
                final firestore = FirebaseFirestore.instance;
                final subCollections = [
                  'stops',
                  'expenses',
                  'notes',
                  'checklist',
                  'docs',
                  'memories',
                ];

                for (var subCol in subCollections) {
                  var collectionRef = ref.collection(subCol);
                  var snapshot = await collectionRef.get();
                  if (snapshot.docs.isNotEmpty) {
                    WriteBatch batch = firestore.batch();
                    for (var doc in snapshot.docs) {
                      batch.delete(doc.reference);
                    }
                    await batch.commit();
                  }
                }
                await ref.delete();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Silme işlemi başarılı! 🗑️"),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text("Hata: $e")));
                }
              }
            },
            child: const Text("Sil", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    //TEMA RENKLERİ
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          "Planlarım & Anılar",
          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
        ),
        centerTitle: false,
        backgroundColor: cardColor,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF0066CC),
          unselectedLabelColor: isDark ? Colors.white54 : Colors.grey,
          indicatorColor: const Color(0xFF0066CC),
          indicatorWeight: 3,
          tabs: const [
            Tab(text: "Aktif Planlar ✈️"),
            Tab(text: "Anı Defteri 📖"),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('trips')
            .where('userId', isEqualTo: userId)
            .orderBy('baslangicTarihi')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint("Firestore Hatası: ${snapshot.error}");
            return Center(child: Text("Bir hata oluştu: ${snapshot.error}"));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          var allTrips = snapshot.data!.docs;
          DateTime now = DateTime.now();
          DateTime today = DateTime(now.year, now.month, now.day);

          List<DocumentSnapshot> upcomingTrips = [];
          List<DocumentSnapshot> pastTrips = [];

          for (var doc in allTrips) {
            var data = doc.data() as Map<String, dynamic>;
            Timestamp? startTs = data['baslangicTarihi'];
            int days = data['gunSayisi'] ?? 3;

            if (startTs != null) {
              DateTime start = startTs.toDate();
              DateTime startDateOnly = DateTime(
                start.year,
                start.month,
                start.day,
              );
              DateTime endDateOnly = startDateOnly.add(Duration(days: days));

              if (endDateOnly.isBefore(today)) {
                pastTrips.add(doc);
              } else {
                upcomingTrips.add(doc);
              }
            } else {
              upcomingTrips.add(doc);
            }
          }

          pastTrips = pastTrips.reversed.toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildTripList(upcomingTrips, isMemory: false),
              _buildTripList(pastTrips, isMemory: true),
            ],
          );
        },
      ),
      floatingActionButton: (_tabController.index == 0 && userId != null)
          ? Padding(
              padding: const EdgeInsets.only(bottom: 90.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton.extended(
                    heroTag: "btn_manual",
                    onPressed: () => _manuelPlanEkle(context, userId),
                    label: const Text("Manuel Ekle"),
                    icon: const Icon(Icons.edit_calendar),
                    backgroundColor: cardColor,
                    foregroundColor: const Color(0xFF0066CC),
                  ),
                  const SizedBox(height: 12),
                  FloatingActionButton.extended(
                    heroTag: "btn_ai",
                    onPressed: _onAiPlanPressed,
                    label: const Text("AI ile Planla"),
                    icon: const Icon(Icons.auto_awesome),
                    backgroundColor: const Color(0xFF0066CC),
                    foregroundColor: Colors.white,
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Opacity(
            opacity: 0.3,
            child: Image.asset(
              'assets/images/ic_foreground.png',
              height: 120,
              errorBuilder: (c, o, s) => const Icon(
                Icons.flight_takeoff,
                size: 80,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "Henüz bir planın yok.",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            "Sağ alttaki butonlarla hemen başla! 🚀",
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildTripList(
    List<DocumentSnapshot> trips, {
    required bool isMemory,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;

    if (trips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isMemory ? Icons.collections_bookmark_outlined : Icons.flight,
              size: 60,
              color: isDark ? Colors.white24 : Colors.grey.shade300,
            ),
            const SizedBox(height: 15),
            Text(
              isMemory ? "Henüz bitmiş bir gezin yok." : "Aktif planın yok.",
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white60 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      physics: const BouncingScrollPhysics(),
      itemCount: trips.length,
      itemBuilder: (context, index) {
        var doc = trips[index];
        var data = doc.data() as Map<String, dynamic>;
        String title = data['baslik'] ?? "İsimsiz";
        String dest = data['destination'] ?? "";

        String? bgImage = data['resimUrl'];

        return GestureDetector(
          onTap: () {
            if (isMemory) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MemoryScreen(
                    tripId: doc.id,
                    tripTitle: title,
                    destination: dest,
                  ),
                ),
              );
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TripDetailScreen(
                    tripId: doc.id,
                    tripTitle: title,
                    destination: dest,
                    initialDays: data['gunSayisi'] ?? 3,
                    heroImage: bgImage,
                  ),
                ),
              );
            }
          },
          child: Container(
            height: 180,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  (bgImage != null &&
                          bgImage.isNotEmpty &&
                          bgImage.startsWith('http'))
                      ? CachedNetworkImage(
                          imageUrl: bgImage,
                          fit: BoxFit.cover,
                          memCacheHeight: 500,
                          placeholder: (context, url) =>
                              Container(color: Colors.grey.shade200),
                          errorWidget: (context, url, error) {
                            if (_placesApiKey.isNotEmpty && dest.isNotEmpty) {
                              return GooglePlaceImage(
                                placeName: dest,
                                apiKey: _placesApiKey,
                                fit: BoxFit.cover,
                              );
                            }
                            return Image.asset(
                              "assets/images/default_city.jpg",
                              fit: BoxFit.cover,
                            );
                          },
                        )
                      :
                        // Karartma efekti
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: isMemory
                                  ? [Colors.black26, Colors.black87]
                                  : [Colors.transparent, Colors.black87],
                            ),
                          ),
                        ),

                  if (isMemory)
                    Positioned(
                      top: 15,
                      left: 15,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "TAMAMLANDI",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _planiSil(doc.reference),
                        borderRadius: BorderRadius.circular(50),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_month,
                              color: Colors.white70,
                              size: 14,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              data['tarih_araligi'] ?? "",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

//DİYALOG EKRANI

class ManualTripDialog extends StatefulWidget {
  final String uid;
  final String placesApiKey;
  final String pexelsApiKey;

  const ManualTripDialog({
    super.key,
    required this.uid,
    required this.placesApiKey,
    required this.pexelsApiKey,
  });

  @override
  State<ManualTripDialog> createState() => _ManualTripDialogState();
}

class _ManualTripDialogState extends State<ManualTripDialog> {
  final TextEditingController _sehirController = TextEditingController();
  final TextEditingController _gunController = TextEditingController();
  DateTimeRange? _secilenTarihAraligi;
  bool _isLoading = false;
  List<dynamic> _placeSuggestions = [];
  Timer? _debounce;

  @override
  void dispose() {
    _sehirController.dispose();
    _gunController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchCitySuggestions(String input) async {
    if (input.length < 3 || widget.placesApiKey.isEmpty) {
      if (mounted) setState(() => _placeSuggestions = []);
      return;
    }

    try {
      String requestUrl =
          "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&types=(cities)&language=tr&key=${widget.placesApiKey}";

      var response = await http.get(Uri.parse(requestUrl));

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        if (data['predictions'] != null && mounted) {
          setState(() {
            _placeSuggestions = data['predictions'];
          });
        }
      }
    } catch (e) {
      debugPrint("API Hatası: $e");
    }
  }

  void _onSearchChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      _fetchCitySuggestions(val);
    });
  }

  Future<String> _fetchCityImageForSave(String city) async {
    String cleanCity = city.trim();

    try {
      final localMatch = CityData.popularCities.firstWhere(
        (c) => c.isim.toLowerCase() == cleanCity.toLowerCase(),
      );
      if (localMatch.resimUrl.isNotEmpty &&
          localMatch.resimUrl.startsWith('http')) {
        return localMatch.resimUrl;
      }
    } catch (_) {}

    if (widget.placesApiKey.isNotEmpty) {
      try {
        String query = "$cleanCity city best view tourism";
        final url = Uri.parse(
          "https://maps.googleapis.com/maps/api/place/textsearch/json?query=$query&language=tr&key=${widget.placesApiKey}",
        );
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['results'] != null && (data['results'] as List).isNotEmpty) {
            var firstResult = data['results'][0];
            if (firstResult['photos'] != null &&
                (firstResult['photos'] as List).isNotEmpty) {
              String photoRef = firstResult['photos'][0]['photo_reference'];
              return "https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photo_reference=$photoRef&key=${widget.placesApiKey}";
            }
          }
        }
      } catch (e) {
        debugPrint("Google API Hatası: $e");
      }
    }

    if (widget.pexelsApiKey.isNotEmpty) {
      try {
        final url = Uri.parse(
          "https://api.pexels.com/v1/search?query=$cleanCity city&per_page=1&orientation=landscape",
        );
        final response = await http.get(
          url,
          headers: {'Authorization': widget.pexelsApiKey},
        );
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['photos'] != null && (data['photos'] as List).isNotEmpty) {
            return data['photos'][0]['src']['medium'];
          }
        }
      } catch (e) {
        debugPrint("Pexels Hatası: $e");
      }
    }

    int uniqueLock = cleanCity.hashCode;
    String safeCityTag = cleanCity.replaceAll(' ', ',');
    return "https://loremflickr.com/800/600/$safeCityTag,city/all?lock=$uniqueLock";
  }

  void _planiKaydet() async {
    if (_sehirController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Lütfen bir şehir girin.")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      String girilenSehir = _sehirController.text.trim();
      String finalBaslik = "$girilenSehir Gezisi";
      int gunSayisi = int.tryParse(_gunController.text) ?? 3;
      DateTime baslangic = _secilenTarihAraligi?.start ?? DateTime.now();
      DateTime bitis =
          _secilenTarihAraligi?.end ??
          baslangic.add(Duration(days: gunSayisi - 1));

      String formatDate(DateTime d) =>
          "${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}";
      String tarihMetni = "${formatDate(baslangic)} - ${formatDate(bitis)}";

      String cityImageUrl = await _fetchCityImageForSave(girilenSehir);

      await FirebaseFirestore.instance.collection('trips').add({
        'userId': widget.uid,
        'members': [widget.uid],
        'baslik': finalBaslik,
        'destination': girilenSehir,
        'gunSayisi': gunSayisi,
        'baslangicTarihi': Timestamp.fromDate(baslangic),
        'tarih_araligi': tarihMetni,
        'resimUrl': cityImageUrl, // Artık her zaman dolu gelecek
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Plan başarıyla oluşturuldu! 🎉"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Hata oluştu."),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    //TEMA RENKLERİ
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final inputFillColor = isDark
        ? Colors.white.withOpacity(0.05)
        : Colors.grey.shade50;

    return Dialog(
      backgroundColor: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Yeni Seyahat 🌍",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ŞEHİR INPUT
              TextField(
                controller: _sehirController,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(color: textColor),
                onChanged: (val) {
                  if (val.isEmpty) {
                    setState(() => _placeSuggestions = []);
                  } else {
                    _onSearchChanged(val);
                  }
                },
                decoration: InputDecoration(
                  labelText: "Nereye Gidiyoruz?",
                  labelStyle: TextStyle(
                    color: isDark ? Colors.white70 : Colors.grey,
                  ),
                  hintText: "Örn: Paris, Kapadokya...",
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white30 : Colors.grey,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF0066CC),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: inputFillColor,
                ),
              ),

              // AUTOCOMPLETE LISTESI
              if (_placeSuggestions.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 150),
                  margin: const EdgeInsets.only(top: 5),
                  decoration: BoxDecoration(
                    color: cardColor,
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.grey.shade200,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(color: Colors.black12, blurRadius: 4),
                    ],
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _placeSuggestions.length,
                    itemBuilder: (context, index) {
                      var suggestion = _placeSuggestions[index];
                      String mainText =
                          suggestion['structured_formatting']?['main_text'] ??
                          suggestion['description'];

                      return ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.location_on,
                          size: 16,
                          color: Colors.grey,
                        ),
                        title: Text(
                          mainText,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        onTap: () {
                          _sehirController.text = mainText;
                          setState(() => _placeSuggestions = []);
                          FocusScope.of(context).unfocus();
                        },
                      );
                    },
                  ),
                ),

              const SizedBox(height: 15),

              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: _gunController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: "Gün",
                        labelStyle: TextStyle(
                          color: isDark ? Colors.white70 : Colors.grey,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 15,
                        ),
                        filled: true,
                        fillColor: inputFillColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                          builder: (context, child) {
                            return Theme(
                              data: ThemeData.light().copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: Color(0xFF0066CC),
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() {
                            _secilenTarihAraligi = picked;
                            int gunFarki =
                                picked.end.difference(picked.start).inDays + 1;
                            _gunController.text = gunFarki.toString();
                          });
                        }
                      },
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(
                        _secilenTarihAraligi == null
                            ? "Tarih Seç"
                            : "Tarih Tamam",
                        style: const TextStyle(fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 25),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _planiKaydet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0066CC),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          "Planı Oluştur",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              SizedBox(
                height: MediaQuery.of(context).viewInsets.bottom > 0 ? 20 : 0,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
