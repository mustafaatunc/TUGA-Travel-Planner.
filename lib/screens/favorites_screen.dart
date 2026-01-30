import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../data/city_data.dart';
import 'map_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  static final ValueNotifier<List<String>> favoritesNotifier = ValueNotifier(
    [],
  );

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> favs = prefs.getStringList('favoriler') ?? [];
    FavoritesScreen.favoritesNotifier.value = favs;
  }

  Map<String, dynamic>? _findCityData(String cityName) {
    try {
      final city = CityData.popularCities.firstWhere(
        (element) => element.isim.toLowerCase() == cityName.toLowerCase(),
      );

      return {
        'resim': city.resimUrl,
        'lat': city.konum.latitude,
        'lng': city.konum.longitude,
      };
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    //TEMA AYARLARI
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final subtitleColor = isDark ? Colors.white70 : Colors.grey.shade600;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: Text(
          "Favorilerim ❤️",
          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
        ),
        backgroundColor: cardColor,
        elevation: 0,
        centerTitle: true,
        foregroundColor: textColor,
      ),
      body: ValueListenableBuilder<List<String>>(
        valueListenable: FavoritesScreen.favoritesNotifier,
        builder: (context, favorites, child) {
          if (favorites.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      color: cardColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.favorite_border,
                      size: 70,
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                    ),
                  ),
                  const SizedBox(height: 25),
                  Text(
                    "Listen Henüz Boş",
                    style: TextStyle(
                      fontSize: 20,
                      color: textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Beğendiğin rotaları kalp ikonuna\nbasarak buraya ekleyebilirsin.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: subtitleColor,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            physics: const BouncingScrollPhysics(),
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              final isim = favorites[index];
              final cityData = _findCityData(isim);
              final String? resimUrl = cityData?['resim'];

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: cardColor, //
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MapScreen(
                            odakLat: cityData?['lat'],
                            odakLng: cityData?['lng'],
                            odakIsim: isim,
                            odakResim: resimUrl,
                            isEmbedded: false,
                          ),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(20),
                          ),
                          child: SizedBox(
                            width: 110,
                            height: 110,
                            child: resimUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: resimUrl,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 300,
                                    placeholder: (c, u) => Container(
                                      color: isDark
                                          ? Colors.white10
                                          : Colors.grey[100],
                                    ),
                                    errorWidget: (c, u, e) => Image.asset(
                                      "assets/images/default_city.jpg",
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Image.asset(
                                    "assets/images/default_city.jpg",
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ),

                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isim,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: 14,
                                      color: subtitleColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "Rotaya Git",
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: subtitleColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: IconButton(
                            icon: const Icon(
                              Icons.favorite,
                              color: Colors.redAccent,
                            ),
                            onPressed: () => _removeFavorite(isim, context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _removeFavorite(String isim, BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();

    List<String> oldList = List.from(FavoritesScreen.favoritesNotifier.value);
    List<String> newList = List.from(oldList);
    newList.remove(isim);

    FavoritesScreen.favoritesNotifier.value = newList;
    await prefs.setStringList('favoriler', newList);

    if (context.mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("$isim favorilerden çıkarıldı"),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF333333),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          action: SnackBarAction(
            label: "GERİ AL",
            textColor: Colors.orangeAccent,
            onPressed: () async {
              final currentList = List<String>.from(
                FavoritesScreen.favoritesNotifier.value,
              );
              if (!currentList.contains(isim)) {
                currentList.add(isim);
                FavoritesScreen.favoritesNotifier.value = currentList;
                await prefs.setStringList('favoriler', currentList);
              }
            },
          ),
        ),
      );
    }
  }
}
