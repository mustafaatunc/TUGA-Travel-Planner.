import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:harita_uygulamasi/models/place_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';

// Diğer ekranlar
import 'map_screen.dart';
import 'planner_screen.dart';
import 'trip_detail_screen.dart';
import 'favorites_screen.dart';
import '../data/city_data.dart';
import '../widgets/google_place_image.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Şehir verileri
  List<Map<String, dynamic>> _randomCities = [];
  bool _isLoadingCities = true;

  // API Anahtarları
  final String _placesApiKey = dotenv.env['GOOGLE_PLACES_API_KEY'] ?? "";
  final String _pexelsApiKey = dotenv.env['PEXELS_API_KEY'] ?? "";

  // Resim Cache
  final Map<String, String> _imageCache = {};

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initFavorites();
      _prepareRandomCities();
    });
  }

  Future<void> _initFavorites() async {
    if (FavoritesScreen.favoritesNotifier.value.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      FavoritesScreen.favoritesNotifier.value =
          prefs.getStringList('favoriler') ?? [];
    }
  }

  void _prepareRandomCities() {
    try {
      var allCities = List<Map<String, dynamic>>.from(
        CityData.popularCities.map((e) => e.toMap()),
      );
      allCities.shuffle();

      if (mounted) {
        setState(() {
          _randomCities = allCities.take(10).toList();
          _isLoadingCities = false;
        });
      }
    } catch (e) {
      debugPrint("Şehir verisi yüklenirken hata: $e");
      if (mounted) setState(() => _isLoadingCities = false);
    }
  }

  Future<void> _refreshCities() async {
    await Future.delayed(const Duration(milliseconds: 800));
    _prepareRandomCities();
  }

  // Akıllı Resim Getirme (Cache -> Google -> Pexels -> Sabit Yedek)
  Future<String> _fetchCityImageSmart(String city, {String? defaultUrl}) async {
    if (_imageCache.containsKey(city)) {
      return _imageCache[city]!;
    }
    final prefs = await SharedPreferences.getInstance();
    final cacheKey =
        "img_cache_v4_${city.replaceAll(' ', '_')}"; // Cache versiyonunu artırdım

    //Önce Telefon Hafızasına Bak
    final cachedUrl = prefs.getString(cacheKey);
    if (cachedUrl != null && cachedUrl.isNotEmpty) {
      return cachedUrl;
    }

    String cleanCity = city.trim();
    String? foundUrl;

    //Google Places API
    if (_placesApiKey.isNotEmpty) {
      try {
        String query = "$cleanCity city tourism landmark";
        final url = Uri.parse(
          "https://maps.googleapis.com/maps/api/place/textsearch/json?query=$query&language=tr&key=$_placesApiKey",
        );

        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['results'] != null && (data['results'] as List).isNotEmpty) {
            var firstResult = data['results'][0];
            if (firstResult['photos'] != null &&
                (firstResult['photos'] as List).isNotEmpty) {
              String photoRef = firstResult['photos'][0]['photo_reference'];

              foundUrl =
                  "https://maps.googleapis.com/maps/api/place/photo?maxwidth=600&photo_reference=$photoRef&key=$_placesApiKey";
            }
          }
        }
      } catch (e) {
        debugPrint("Google API Hatası ($city): $e");
      }
    }

    //Pexels API
    if (foundUrl == null && _pexelsApiKey.isNotEmpty) {
      try {
        final url = Uri.parse(
          "https://api.pexels.com/v1/search?query=$cleanCity travel&per_page=1&orientation=landscape",
        );
        final response = await http.get(
          url,
          headers: {'Authorization': _pexelsApiKey},
        );
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['photos'] != null && (data['photos'] as List).isNotEmpty) {
            foundUrl = data['photos'][0]['src']['medium'];
          }
        }
      } catch (e) {
        debugPrint("Pexels API Hatası ($city): $e");
      }
    }

    //Bulunanı Kaydet
    if (foundUrl != null) {
      await prefs.setString(cacheKey, foundUrl);
      _imageCache[city] = foundUrl; //
      return foundUrl;
    }

    //Hiçbir şey bulunamazsa varsayılanı veya şeffaf bir resim döndür
    return defaultUrl ??
        "https://upload.wikimedia.org/wikipedia/commons/1/14/No_Image_Available.jpg";
  }

  Future<void> _toggleFavoriteGlobal(String city) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> currentList = List.from(
      FavoritesScreen.favoritesNotifier.value,
    );

    if (currentList.contains(city)) {
      currentList.remove(city);
    } else {
      currentList.add(city);
    }

    FavoritesScreen.favoritesNotifier.value = currentList;
    await prefs.setStringList('favoriler', currentList);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor; // Otomatik renk
    final textColor = isDark ? Colors.white : Colors.black87;

    // İsim görüntüleme mantığı
    String displayName = "Gezgin";
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      displayName = user.displayName!.split(' ')[0];

      displayName =
          displayName[0].toUpperCase() + displayName.substring(1).toLowerCase();
    }

    return Scaffold(
      resizeToAvoidBottomInset: false, // Klavye açıldığında harita sıkışmasın
      body: Stack(
        children: [
          //ARKA PLAN HARİTA
          const Positioned.fill(child: MapScreen(isEmbedded: true)),

          //ARAMA ÇUBUĞU
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 20,
            right: 20,
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MapScreen(isEmbedded: false),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    decoration: BoxDecoration(
                      color: cardColor.withOpacity(0.9), // Hafif transparan
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: Color(0xFF0066CC)),
                        const SizedBox(width: 10),
                        Text(
                          "Nereye gitmek istersin?",
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.grey[600],
                            fontSize: 15,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.tune,
                            size: 18,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          //BOTTOM SHEET
          DraggableScrollableSheet(
            initialChildSize: 0.45,
            minChildSize: 0.35,
            maxChildSize: 0.92,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF121212)
                      : const Color(0xFFF8F9FA),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: RefreshIndicator(
                  onRefresh: _refreshCities,
                  color: const Color(0xFF0066CC),
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                    physics: const BouncingScrollPhysics(), // iOS hissi
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Hoş Geldin,",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "$displayName 👋",
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                            ],
                          ),
                          // Profil Resmi
                          GestureDetector(
                            onTap: () {},
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(
                                    0xFF0066CC,
                                  ).withOpacity(0.2),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: user?.photoURL != null
                                    ? CachedNetworkImage(
                                        imageUrl: user!.photoURL!,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            const CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                        errorWidget: (context, url, error) =>
                                            const Icon(
                                              Icons.person,
                                              color: Color(0xFF0066CC),
                                            ),
                                      )
                                    : const Icon(
                                        Icons.person,
                                        color: Color(0xFF0066CC),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 25),

                      //SEYAHAT KARTI
                      const Text(
                        "Sıradaki Maceran",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 15),
                      _buildNextTripCard(context, user?.uid),

                      const SizedBox(height: 35),

                      //POPÜLER ROTALAR
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Popüler Rotalar 🔥",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const MapScreen(isEmbedded: false),
                              ),
                            ),
                            child: const Text(
                              "Tümü",
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),

                      //YATAY LİSTE
                      ValueListenableBuilder<List<String>>(
                        valueListenable: FavoritesScreen.favoritesNotifier,
                        builder: (context, favoritesList, child) {
                          if (_isLoadingCities) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(20.0),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          return SizedBox(
                            height: 260,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: _randomCities.length,
                              itemBuilder: (context, index) {
                                final cityData = _randomCities[index];
                                final isFavorite = favoritesList.contains(
                                  cityData['isim'],
                                );
                                return _buildDestinationCard(
                                  context,
                                  cityData['isim'],
                                  cityData['aciklama'] ?? "Bilinmiyor",
                                  cityData['lat'],
                                  cityData['lng'],
                                  isFavorite,
                                  cityData['resimUrl'],
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDestinationCard(
    BuildContext context,
    String city,
    String country,
    double lat,
    double lng,
    bool isFavori,
    String? knownImageUrl,
  ) {
    return GestureDetector(
      onTap: () async {
        String imgUrl = _imageCache[city] ?? "";
        if (imgUrl.isEmpty) {
          imgUrl = await _fetchCityImageSmart(city, defaultUrl: knownImageUrl);
        }
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MapScreen(
                odakLat: lat,
                odakLng: lng,
                odakIsim: city,
                odakResim: imgUrl,
                isEmbedded: false,
              ),
            ),
          );
        }
      },
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 15, bottom: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            //Resim Alanı
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: (knownImageUrl != null && knownImageUrl.isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: knownImageUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: 400,
                        placeholder: (context, url) => Container(
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (context, url, error) {
                          return FutureBuilder<String>(
                            future: _fetchCityImageSmart(
                              city,
                              defaultUrl: knownImageUrl,
                            ),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return Container(color: Colors.grey.shade200);
                              }
                              if (snapshot.hasData &&
                                  snapshot.data!.isNotEmpty) {
                                return CachedNetworkImage(
                                  imageUrl: snapshot.data!,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Image.asset(
                                    "assets/images/default_city.jpg",
                                    fit: BoxFit.cover,
                                  ),
                                );
                              }
                              return Image.asset(
                                "assets/images/default_city.jpg",
                                fit: BoxFit.cover,
                              );
                            },
                          );
                        },
                      )
                    : FutureBuilder<String>(
                        future: _fetchCityImageSmart(city, defaultUrl: null),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Container(
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          }
                          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                            return CachedNetworkImage(
                              imageUrl: snapshot.data!,
                              fit: BoxFit.cover,
                            );
                          }
                          return Image.asset(
                            "assets/images/default_city.jpg",
                            fit: BoxFit.cover,
                          );
                        },
                      ),
              ),
            ),

            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.2),
                      Colors.black.withOpacity(0.8),
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 15,
              right: 15,
              child: GestureDetector(
                onTap: () => _toggleFavoriteGlobal(city),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    isFavori ? Icons.favorite : Icons.favorite_border,
                    color: isFavori ? const Color(0xFFFF4757) : Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 15,
              right: 15,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    city,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      shadows: [Shadow(color: Colors.black45, blurRadius: 5)],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.white70,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          country,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Seyahat Kartı (Firebase Stream)
  Widget _buildNextTripCard(BuildContext context, String? uid) {
    if (uid == null) return _buildEmptyTripCard(context);

    DateTime now = DateTime.now();
    DateTime todayStart = DateTime(now.year, now.month, now.day);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('trips')
          .where('members', arrayContains: uid)
          .where(
            'baslangicTarihi',
            isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart),
          )
          .orderBy('baslangicTarihi')
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 180,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError ||
            !snapshot.hasData ||
            snapshot.data!.docs.isEmpty) {
          return _buildEmptyTripCard(context);
        }

        var doc = snapshot.data!.docs.first;
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        DateTime? baslangic = (data['baslangicTarihi'] as Timestamp?)?.toDate();
        String kalanGunText = "Yaklaşıyor ✈️";

        if (baslangic != null) {
          final tripDate = DateTime(
            baslangic.year,
            baslangic.month,
            baslangic.day,
          );
          int diff = tripDate.difference(todayStart).inDays;

          if (diff > 0) {
            kalanGunText = "$diff Gün Kaldı";
          } else if (diff == 0) {
            kalanGunText = "Bugün Gidiyorsun! 🚀";
          }
        }

        String coverImage = data['resimUrl'] ?? "";

        const String defaultImage =
            "https://images.pexels.com/photos/3278215/pexels-photo-3278215.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1";

        if (coverImage.isEmpty) {
          coverImage = defaultImage;
        }

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TripDetailScreen(
                  tripId: doc.id,
                  tripTitle: data['baslik'] ?? "Plan",
                  destination: data['destination'],
                  initialDays: data['gunSayisi'] ?? 3,
                  heroImage: coverImage,
                ),
              ),
            );
          },
          child: Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  //RESİM GÖSTERİMİ
                  CachedNetworkImage(
                    imageUrl: coverImage,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey.shade300,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) {
                      String destination = data['destination'] ?? "";

                      if (destination.isEmpty && data['baslik'] != null) {
                        destination = data['baslik']
                            .toString()
                            .replaceAll(" Gezisi", "")
                            .trim();
                      }

                      if (_placesApiKey.isNotEmpty && destination.isNotEmpty) {
                        return GooglePlaceImage(
                          placeName: destination,
                          apiKey: _placesApiKey,
                          fit: BoxFit.cover,
                        );
                      }

                      return CachedNetworkImage(
                        imageUrl: defaultImage,
                        fit: BoxFit.cover,
                      );
                    },
                  ),

                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.9),
                        ],
                        stops: const [0.4, 1.0],
                      ),
                    ),
                  ),

                  // Yazılar
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            kalanGunText,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0066CC),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          data['baslik'] ?? "İsimsiz Seyahat",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(blurRadius: 10, color: Colors.black),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              color: Colors.white70,
                              size: 14,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              data['tarih_araligi'] ?? "Tarih Belirlenmedi",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                          ],
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

  Widget _buildEmptyTripCard(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0066CC), Color(0xFF003366)],
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
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -30,
            child: Opacity(
              opacity: 0.1,
              child: Image.asset(
                'assets/images/ic_foreground.png',
                height: 200,
                width: 200,
                fit: BoxFit.cover,
                errorBuilder: (c, o, s) => const Icon(
                  Icons.airplanemode_active,
                  size: 150,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(25),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Henüz bir planın yok",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Hayalindeki tatili TUGA ile planlamaya hemen başla!",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 15),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PlannerScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0066CC),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 5,
                  ),
                  child: const Text(
                    "Planla",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
