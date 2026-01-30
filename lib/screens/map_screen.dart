import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../widgets/google_place_image.dart';
import '../models/place_model.dart';
import 'favorites_screen.dart';
import '../constants/map_styles.dart';
import 'ai_planner_screen.dart';
import '../data/city_data.dart';

class MapScreen extends StatefulWidget {
  final String? seciliPlanId;
  final String? seciliPlanAdi;
  final int? seciliGun;
  final double? odakLat;
  final double? odakLng;
  final String? odakIsim;
  final String? odakResim;
  final bool isEmbedded;

  const MapScreen({
    super.key,
    this.seciliPlanId,
    this.seciliPlanAdi,
    this.seciliGun,
    this.odakLat,
    this.odakLng,
    this.odakIsim,
    this.odakResim,
    this.isEmbedded = false,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  bool _haritaHazir = false;
  String _aktifHaritaStili = MapStyles.standard;
  final Completer<GoogleMapController> _mapCompleter = Completer();

  final String _placesApiKey = dotenv.env['GOOGLE_PLACES_API_KEY'] ?? "";

  late GoogleMapController _haritaKontrolcusu;
  Set<Marker> _isaretciler = {};
  List<TuristikYer> _gosterilenListe = [];
  List<String> _favoriMekanIsimleri = [];
  final TextEditingController _aramaKontrolcusu = TextEditingController();

  BitmapDescriptor? _favoriPin;
  BitmapDescriptor? _normalPin;

  bool _konumIzniVerildi = false;
  bool _verilerYukleniyor = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _baslat();
    });
    FavoritesScreen.favoritesNotifier.addListener(_favoriGuncellemeDinleyicisi);
  }

  @override
  void dispose() {
    FavoritesScreen.favoritesNotifier.removeListener(
      _favoriGuncellemeDinleyicisi,
    );
    _aramaKontrolcusu.dispose();
    super.dispose();
  }

  void _favoriGuncellemeDinleyicisi() {
    if (!mounted) return;
    setState(() {
      _favoriMekanIsimleri = List.from(FavoritesScreen.favoritesNotifier.value);
      _markerlariGuncelle();
    });
  }

  Future<void> _baslat() async {
    await _ikonlariOlustur();
    await _favorileriYukle();

    if (widget.seciliPlanAdi != null && widget.seciliPlanAdi!.isNotEmpty) {
      _aramaKontrolcusu.text = widget.seciliPlanAdi!;
      _yerAraGoogle("${widget.seciliPlanAdi} tourist attractions");
    } else {
      _tumMekanlariGetir();
    }
  }

  Future<void> _ikonlariOlustur() async {
    try {
      _favoriPin = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(devicePixelRatio: 2.5),
        'assets/icons/map_marker_yellow.png',
      );
      _normalPin = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(devicePixelRatio: 2.5),
        'assets/icons/map_marker_blue.png',
      );
    } catch (e) {
      debugPrint("Marker ikonu yüklenemedi: $e");
      _favoriPin = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueOrange,
      );
      _normalPin = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueAzure,
      );
    }
    if (mounted) setState(() {});
  }

  Future<void> _favorileriYukle() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _favoriMekanIsimleri =
            FavoritesScreen.favoritesNotifier.value.isNotEmpty
            ? FavoritesScreen.favoritesNotifier.value
            : (prefs.getStringList('favoriler') ?? []);
      });
    }
  }

  Future<void> _konumIzinVeGit() async {
    setState(() => _verilerYukleniyor = true);

    bool servisAcikMi = await Geolocator.isLocationServiceEnabled();
    if (!servisAcikMi) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Lütfen konum servisini açın.")),
        );
        setState(() => _verilerYukleniyor = false);
      }
      return;
    }

    LocationPermission izin = await Geolocator.checkPermission();
    if (izin == LocationPermission.denied) {
      izin = await Geolocator.requestPermission();
      if (izin == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Konum izni reddedildi.")),
          );
          setState(() => _verilerYukleniyor = false);
        }
        return;
      }
    }

    if (izin == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Konum izni kalıcı olarak engellendi. Ayarlardan açmalısınız.",
            ),
          ),
        );
        setState(() => _verilerYukleniyor = false);
      }
      return;
    }

    Position k = await Geolocator.getCurrentPosition();
    setState(() {
      _konumIzniVerildi = true;
      _verilerYukleniyor = false;
    });
    _kamerayiTasi(LatLng(k.latitude, k.longitude), zoom: 15);
  }

  void _onMapCreated(GoogleMapController controller) {
    _haritaKontrolcusu = controller;
    if (!_mapCompleter.isCompleted) {
      _mapCompleter.complete(controller);
    }

    try {
      if (MapStyles.standard.isNotEmpty) {
        controller.setMapStyle(MapStyles.standard);
      }
    } catch (_) {}

    Future.delayed(const Duration(milliseconds: 500), () async {
      if (mounted) {
        setState(() => _haritaHazir = true);

        if (widget.odakLat != null && widget.odakLng != null) {
          _kamerayiTasi(LatLng(widget.odakLat!, widget.odakLng!), zoom: 15);

          if (widget.odakIsim != null) {
            final hedefYer = _gosterilenListe.firstWhere(
              (y) => y.isim == widget.odakIsim,
              orElse: () => TuristikYer(
                id: 'temp',
                isim: widget.odakIsim!,
                aciklama: 'Detaylar yükleniyor...',
                konum: LatLng(widget.odakLat!, widget.odakLng!),
                resimUrl: widget.odakResim ?? '',
                kategori: Kategori.diger,
              ),
            );
            Future.delayed(
              const Duration(milliseconds: 600),
              () => _detayPenceresiniAc(hedefYer),
            );
          }
        }
      }
    });
  }

  void _kamerayiTasi(LatLng hedefKonum, {double zoom = 14.0}) {
    _haritaKontrolcusu.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: hedefKonum, zoom: zoom),
      ),
    );
  }

  void _markerlariGuncelle() {
    if (!mounted) return;
    setState(() {
      _isaretciler = _gosterilenListe.map((yer) {
        bool favoriMi = _favoriMekanIsimleri.contains(yer.isim);
        return Marker(
          markerId: MarkerId(yer.id),
          position: yer.konum,
          icon: favoriMi
              ? (_favoriPin ??
                    BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueOrange,
                    ))
              : (_normalPin ??
                    BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueAzure,
                    )),
          infoWindow: InfoWindow(title: yer.isim),
          onTap: () => _detayPenceresiniAc(yer),
        );
      }).toSet();
    });
  }

  Future<void> _tumMekanlariGetir() async {
    if (!mounted) return;
    setState(() => _verilerYukleniyor = true);

    try {
      var snapshot = await FirebaseFirestore.instance
          .collection('mekanlar')
          .get();

      List<TuristikYer> veritabaniListesi = snapshot.docs
          .map((doc) => TuristikYer.fromFirestore(doc))
          .toList();

      if (mounted) {
        setState(() {
          _gosterilenListe = veritabaniListesi;
          _markerlariGuncelle();
          _verilerYukleniyor = false;
        });
      }
    } catch (e) {
      debugPrint("Hata: $e");
      if (mounted) setState(() => _verilerYukleniyor = false);
    }
  }

  Future<void> _yerAraGoogle(String kelime) async {
    if (kelime.isEmpty) {
      _tumMekanlariGetir();
      return;
    }
    setState(() => _verilerYukleniyor = true);
    FocusScope.of(context).unfocus();

    try {
      if (_placesApiKey.isEmpty) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("API Anahtarı eksik!")));
        setState(() => _verilerYukleniyor = false);
        return;
      }

      final url = Uri.parse(
        "https://maps.googleapis.com/maps/api/place/textsearch/json?query=$kelime&language=tr&key=$_placesApiKey",
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'] != null) {
          List results = data['results'];
          List<TuristikYer> aramaSonuclari = results.map((yer) {
            String fotoUrl = "";
            if (yer['photos'] != null && (yer['photos'] as List).isNotEmpty) {
              String photoRef = yer['photos'][0]['photo_reference'];
              fotoUrl =
                  "https://maps.googleapis.com/maps/api/place/photo?maxwidth=800&photo_reference=$photoRef&key=$_placesApiKey";
            }
            double rating = (yer['rating'] ?? 0).toDouble();
            int userRatings = (yer['user_ratings_total'] ?? 0);
            String aciklama = yer['formatted_address'] ?? "";
            if (rating > 0) aciklama = "⭐ $rating ($userRatings) • $aciklama";

            return TuristikYer(
              id: yer['place_id'],
              isim: yer['name'],
              aciklama: aciklama,
              konum: LatLng(
                yer['geometry']['location']['lat'],
                yer['geometry']['location']['lng'],
              ),
              resimUrl: fotoUrl,
              kategori: Kategori.modern,
            );
          }).toList();

          if (mounted) {
            _gosterilenListe = aramaSonuclari;
            _markerlariGuncelle();
            setState(() => _verilerYukleniyor = false);
            if (aramaSonuclari.isNotEmpty) {
              _kamerayiTasi(aramaSonuclari.first.konum, zoom: 14);
            }
          }
        } else {
          if (mounted) setState(() => _verilerYukleniyor = false);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _verilerYukleniyor = false);
    }
  }

  void _detayPenceresiniAc(TuristikYer yer) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final cardColor = Theme.of(context).cardColor;
        final textColor = isDark ? Colors.white : Colors.black87;
        return DraggableScrollableSheet(
          initialChildSize: 0.45,
          minChildSize: 0.25,
          maxChildSize: 0.90,
          builder: (_, controller) {
            return StatefulBuilder(
              builder: (BuildContext context, StateSetter setModalState) {
                bool favoriMi = _favoriMekanIsimleri.contains(yer.isim);

                return Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(25),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 30,
                        offset: Offset(0, -5),
                      ),
                    ],
                  ),
                  child: ListView(
                    controller: controller,
                    padding: EdgeInsets.zero,
                    children: [
                      Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 12),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: SizedBox(
                            height: 200,
                            width: double.infinity,
                            child:
                                (yer.resimUrl.isNotEmpty &&
                                    yer.resimUrl.startsWith('http'))
                                ? CachedNetworkImage(
                                    imageUrl: yer.resimUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      color: Colors.grey.shade200,
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) {
                                      if (_placesApiKey.isNotEmpty) {
                                        return GooglePlaceImage(
                                          placeName: yer.isim,
                                          apiKey: _placesApiKey,
                                        );
                                      }
                                      return Image.asset(
                                        "assets/images/default_city.jpg",
                                        fit: BoxFit.cover,
                                      );
                                    },
                                  )
                                : (_placesApiKey.isNotEmpty
                                      ? GooglePlaceImage(
                                          placeName: yer.isim,
                                          apiKey: _placesApiKey,
                                        )
                                      : Image.asset(
                                          "assets/images/default_city.jpg",
                                          fit: BoxFit.cover,
                                        )),
                          ),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    yer.isim,
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                    maxLines: 2,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () async {
                                    final prefs =
                                        await SharedPreferences.getInstance();
                                    String key = yer.isim;
                                    setModalState(() {
                                      if (_favoriMekanIsimleri.contains(key)) {
                                        _favoriMekanIsimleri.remove(key);
                                      } else {
                                        _favoriMekanIsimleri.add(key);
                                      }
                                    });
                                    FavoritesScreen.favoritesNotifier.value =
                                        List.from(_favoriMekanIsimleri);
                                    await prefs.setStringList(
                                      'favoriler',
                                      _favoriMekanIsimleri,
                                    );
                                    _markerlariGuncelle();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white10
                                          : Colors.grey.shade100,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      favoriMi
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: favoriMi
                                          ? Colors.red
                                          : (isDark
                                                ? Colors.white70
                                                : Colors.grey),
                                      size: 28,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),
                            Text(
                              yer.aciklama,
                              style: TextStyle(
                                fontSize: 15,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 25),

                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      final Uri url = Uri.parse(
                                        "https://www.google.com/maps/search/?api=1&query=${yer.konum.latitude},${yer.konum.longitude}",
                                      );
                                      if (!await launchUrl(
                                        url,
                                        mode: LaunchMode.externalApplication,
                                      )) {
                                        if (mounted)
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text("Harita açılamadı"),
                                            ),
                                          );
                                      }
                                    },
                                    icon: const Icon(Icons.navigation),
                                    label: const Text("Yol Tarifi"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0066CC),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 15),

                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      if (widget.seciliPlanId != null) {
                                        _mekaniPlanaEkle(yer);
                                      } else {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                AiPlannerScreen(
                                                  baslangicSehri: yer.isim,
                                                ),
                                          ),
                                        );
                                      }
                                    },
                                    icon: Icon(
                                      widget.seciliPlanId != null
                                          ? Icons.add
                                          : Icons.auto_awesome,
                                      color: widget.seciliPlanId != null
                                          ? const Color(0xFF0066CC)
                                          : Colors.purple,
                                    ),
                                    label: Text(
                                      widget.seciliPlanId != null
                                          ? "Ekle"
                                          : "AI Planla",
                                      style: TextStyle(
                                        color: widget.seciliPlanId != null
                                            ? const Color(0xFF0066CC)
                                            : Colors.purple,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _mekaniPlanaEkle(TuristikYer yer) {
    if (widget.seciliPlanId == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("${yer.isim} Eklensin mi?"),
        content: Text(
          "${widget.seciliPlanAdi} planına bu mekanı eklemek istiyor musunuz?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Vazgeç"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance
                  .collection('trips')
                  .doc(widget.seciliPlanId)
                  .collection('stops')
                  .add({
                    'yerId': yer.id,
                    'isim': yer.isim,
                    'konum': GeoPoint(yer.konum.latitude, yer.konum.longitude),
                    'resimUrl': yer.resimUrl,
                    'eklenmeTarihi': FieldValue.serverTimestamp(),
                    'sira': DateTime.now().millisecondsSinceEpoch,
                    'gun': widget.seciliGun ?? 1,
                    'not': yer.aciklama,
                  });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Başarıyla eklendi!"),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text("Ekle"),
          ),
        ],
      ),
    );
  }

  void _stilSecimMenusunuAc() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : Colors.black87;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Text(
                "Harita Görünümü",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStyleOption(
                    "Standart",
                    MapStyles.standard,
                    Colors.blue,
                    [Colors.blue.shade100, Colors.blue.shade300],
                    textColor,
                  ),
                  _buildStyleOption("Gümüş", MapStyles.silver, Colors.grey, [
                    Colors.grey.shade200,
                    Colors.grey.shade400,
                  ], textColor),
                  _buildStyleOption(
                    "Gece",
                    MapStyles.dark,
                    isDark ? Colors.white : Colors.black87,
                    [Colors.black54, Colors.black87],
                    textColor,
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStyleOption(
    String label,
    String style,
    Color iconColor,
    List<Color> gradientColors,
    Color labelColor,
  ) {
    bool isSelected = _aktifHaritaStili == style;
    return GestureDetector(
      onTap: () {
        setState(() => _aktifHaritaStili = style);
        _haritaKontrolcusu.setMapStyle(style);
        Navigator.pop(context);
      },
      child: Column(
        children: [
          Container(
            height: 70,
            width: 70,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(15),
              border: isSelected
                  ? Border.all(color: iconColor, width: 3)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: gradientColors.last.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: isSelected
                ? const Center(
                    child: Icon(Icons.check, color: Colors.white, size: 30),
                  )
                : null,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? iconColor : labelColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : Colors.black87;

    Widget content = Stack(
      children: [
        ClipRRect(
          borderRadius: widget.isEmbedded
              ? BorderRadius.circular(24)
              : BorderRadius.zero,
          child: GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(39.0, 35.0),
              zoom: 4.5,
            ),
            markers: _isaretciler,
            mapType: MapType.normal,
            myLocationEnabled: _konumIzniVerildi,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            scrollGesturesEnabled: !widget.isEmbedded,
            zoomGesturesEnabled: !widget.isEmbedded,
            tiltGesturesEnabled: !widget.isEmbedded,
            rotateGesturesEnabled: !widget.isEmbedded,
            gestureRecognizers: {},
            onTap: (LatLng loc) {
              if (widget.isEmbedded) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MapScreen(isEmbedded: false),
                  ),
                );
              }
            },
            onMapCreated: _onMapCreated,
          ),
        ),

        if (!widget.isEmbedded)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutExpo,
            top: _haritaHazir ? (widget.seciliPlanId != null ? 110 : 60) : -150,
            left: 20,
            right: 20,
            child: Container(
              decoration: BoxDecoration(
                color: cardColor.withOpacity(0.95),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: TextField(
                controller: _aramaKontrolcusu,
                style: TextStyle(color: textColor),
                textInputAction: TextInputAction.search,
                onSubmitted: _yerAraGoogle,
                decoration: InputDecoration(
                  hintText: "Mekan veya Şehir ara...",
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white54 : Colors.grey,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF0066CC),
                  ),
                  suffixIcon: _aramaKontrolcusu.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _aramaKontrolcusu.clear();
                            _tumMekanlariGetir();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                ),
              ),
            ),
          ),

        if (_verilerYukleniyor)
          const Center(
            child: Card(
              shape: CircleBorder(),
              child: Padding(
                padding: EdgeInsets.all(10),
                child: CircularProgressIndicator(),
              ),
            ),
          ),

        if (_haritaHazir)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutBack,
            bottom: widget.isEmbedded ? 20 : 190,
            right: 20,
            child: FloatingActionButton(
              heroTag: "layer_btn_${widget.isEmbedded ? 'emb' : 'full'}",
              backgroundColor: cardColor,
              foregroundColor: isDark ? Colors.white : Colors.black87,
              mini: true,
              onPressed: _stilSecimMenusunuAc,
              child: const Icon(Icons.layers_outlined),
            ),
          ),

        AnimatedPositioned(
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeOutBack,
          bottom: widget.isEmbedded ? 80 : 130,
          right: 20,
          child: FloatingActionButton(
            heroTag: "loc_btn_${widget.isEmbedded ? 'emb' : 'full'}",
            backgroundColor: cardColor,
            foregroundColor: const Color(0xFF0066CC),
            onPressed: _konumIzinVeGit,
            child: Icon(
              _konumIzniVerildi ? Icons.my_location : Icons.location_searching,
            ),
          ),
        ),
      ],
    );

    if (widget.seciliPlanId != null) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text("${widget.seciliPlanAdi} - Gün ${widget.seciliGun}"),
          backgroundColor: cardColor.withOpacity(0.9),
          elevation: 0,
          foregroundColor: textColor,
        ),
        body: content,
      );
    }

    if (!widget.isEmbedded) {
      return Scaffold(resizeToAvoidBottomInset: false, body: content);
    }

    return content;
  }
}
