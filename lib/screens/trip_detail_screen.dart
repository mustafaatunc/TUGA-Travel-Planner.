import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'map_screen.dart';

import '../widgets/google_place_image.dart';

class TripDetailScreen extends StatefulWidget {
  final String tripId;
  final String tripTitle;
  final String? destination;
  final int initialDays;
  final String? heroImage;

  const TripDetailScreen({
    super.key,
    required this.tripId,
    required this.tripTitle,
    this.destination,
    this.initialDays = 3,
    this.heroImage,
  });

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  late String _guncelBaslik;
  final Completer<GoogleMapController> _mapCompleter = Completer();
  bool _isCameraMoved = false;
  int _seciliGun = 1;
  late int _toplamGun;

  // Veriler
  Set<Marker> _suggestedMarkers = {};
  bool _isFetching = false;
  String _statusMessage = "";
  final Set<String> _addedIds = {};

  final String _placesApiKey = dotenv.env['GOOGLE_PLACES_API_KEY'] ?? "";
  final String _weatherApiKey = dotenv.env['WEATHER_API_KEY'] ?? "";

  final String _defaultCoverImage =
      "https://images.pexels.com/photos/3278215/pexels-photo-3278215.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1";

  String _weatherTemp = "--";
  String _weatherDesc = "Yükleniyor...";
  IconData _weatherIcon = Icons.wb_sunny;

  final Color _primaryColor = const Color(0xFF0066CC);

  final List<String> _suggestedItems = [
    "Pasaport",
    "Şarj Aleti",
    "Powerbank",
    "Diş Fırçası",
    "Güneş Gözlüğü",
    "Rahat Ayakkabı",
    "İlaçlar",
    "Kulaklık",
    "Nakit Para",
    "Şemsiye",
  ];

  @override
  void initState() {
    super.initState();
    _guncelBaslik = widget.tripTitle;
    _toplamGun = widget.initialDays;
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _havaDurumunuGetir();
      _baslatElitGoogleTaramasi();
    });
  }

  //HARİTA VE ÖNERİ MOTORU
  Future<void> _baslatElitGoogleTaramasi() async {
    if (_isFetching || _placesApiKey.isEmpty) return;

    String city = widget.destination ?? "";
    if (city.isEmpty) city = widget.tripTitle.split(' ')[0].trim();
    if (city.length < 3) city = "Turkey";

    setState(() {
      _isFetching = true;
      _statusMessage = "$city çevresindeki popüler yerler taranıyor...";
    });

    await _focusOnCity(city);
    await _fetchElitPlacesFromGoogle(city);

    if (mounted) {
      setState(() {
        _isFetching = false;
        _statusMessage = _suggestedMarkers.isEmpty
            ? ""
            : "${_suggestedMarkers.length} öneri bulundu. Haritadan seçip ekleyebilirsin.";
      });

      if (_suggestedMarkers.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 500), _fitMapToMarkers);
      }

      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) setState(() => _statusMessage = "");
      });
    }
  }

  Future<void> _focusOnCity(String city) async {
    final url = Uri.parse(
      "https://nominatim.openstreetmap.org/search?q=$city&format=json&accept-language=tr&limit=1",
    );
    try {
      final response = await http.get(
        url,
        headers: {'User-Agent': 'TugaApp/1.0'},
      );
      if (response.statusCode == 200) {
        var results = json.decode(response.body);
        if (results is List && results.isNotEmpty) {
          double lat = double.parse(results[0]['lat']);
          double lng = double.parse(results[0]['lon']);

          if (_mapCompleter.isCompleted) {
            final controller = await _mapCompleter.future;
            controller.animateCamera(
              CameraUpdate.newLatLngZoom(LatLng(lat, lng), 12),
            );
            _isCameraMoved = true;
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchElitPlacesFromGoogle(String city) async {
    String query = "top tourist attractions in $city";
    try {
      final url = Uri.parse(
        "https://maps.googleapis.com/maps/api/place/textsearch/json?query=$query&language=tr&key=$_placesApiKey",
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'OK' && data['results'] != null) {
          for (var place in data['results']) {
            double rating = (place['rating'] ?? 0).toDouble();
            int userRatings = (place['user_ratings_total'] ?? 0);
            if (rating < 4.0 || userRatings < 50) continue;
            _addGoogleMarker(place, city);
          }
        }
      }
    } catch (e) {
      debugPrint("Google API Hatası: $e");
    }
  }

  void _addGoogleMarker(dynamic place, String city) {
    String name = place['name'];
    String id = place['place_id'];
    double lat = place['geometry']['location']['lat'];
    double lng = place['geometry']['location']['lng'];
    double rating = (place['rating'] ?? 0).toDouble();
    String? photoRef = (place['photos'] != null && place['photos'].isNotEmpty)
        ? place['photos'][0]['photo_reference']
        : null;

    if (_addedIds.contains(id)) return;
    _addedIds.add(id);

    final marker = Marker(
      markerId: MarkerId("g_$id"),
      position: LatLng(lat, lng),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
      infoWindow: InfoWindow(title: name, snippet: "$rating ⭐ - Ekle"),
      onTap: () => _showSingleSafeDialog(name, lat, lng, photoRef: photoRef),
    );

    setState(() => _suggestedMarkers.add(marker));
  }

  void _fitMapToMarkers() async {
    if (_suggestedMarkers.isEmpty) return;
    final controller = await _mapCompleter.future;

    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (var m in _suggestedMarkers) {
      if (m.position.latitude < minLat) minLat = m.position.latitude;
      if (m.position.latitude > maxLat) maxLat = m.position.latitude;
      if (m.position.longitude < minLng) minLng = m.position.longitude;
      if (m.position.longitude > maxLng) maxLng = m.position.longitude;
    }

    controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        60,
      ),
    );
  }

  void _showSingleSafeDialog(
    String name,
    double lat,
    double lng, {
    String? photoRef,
  }) {
    if (!mounted) return;

    //Tema Ayarı
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : Colors.black87;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          name,
          textAlign: TextAlign.center,
          style: TextStyle(color: textColor),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Bu mekanı planına eklemek ister misin?",
              style: TextStyle(color: textColor.withOpacity(0.8)),
            ),
            const SizedBox(height: 15),
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: SizedBox(
                height: 150,
                width: double.infinity,
                child: GooglePlaceImage(
                  placeName: name,
                  apiKey: _placesApiKey,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              String? urlToSave;
              if (photoRef != null && _placesApiKey.isNotEmpty) {
                urlToSave =
                    "https://maps.googleapis.com/maps/api/place/photo?maxwidth=600&photo_reference=$photoRef&key=$_placesApiKey";
              }
              _savePlaceInBackground(name, lat, lng, urlToSave);
            },
            style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
            child: const Text("Ekle", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _savePlaceInBackground(
    String name,
    double lat,
    double lng,
    String? imgUrl,
  ) {
    FirebaseFirestore.instance
        .collection('trips')
        .doc(widget.tripId)
        .collection('stops')
        .add({
          'isim': name,
          'not': "Önerilen Yer",
          'gun': _seciliGun,
          'sira': DateTime.now().millisecondsSinceEpoch,
          'konum': GeoPoint(lat, lng),
          'resimUrl': imgUrl,
          'eklenmeTarihi': FieldValue.serverTimestamp(),
        })
        .then((_) {
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Eklendi! 📍"),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 1),
              ),
            );
        });
  }

  Future<void> _havaDurumunuGetir() async {
    if (_weatherApiKey.isEmpty) return;
    try {
      String city = widget.destination ?? "";
      if (city.isEmpty) city = widget.tripTitle.split(' ')[0].trim();

      if (city.length >= 3) {
        final url = Uri.parse(
          "https://api.openweathermap.org/data/2.5/weather?q=$city&appid=$_weatherApiKey&units=metric&lang=tr",
        );
        final response = await http.get(url);
        if (response.statusCode == 200) {
          _weatherResponseIsle(response.body);
          return;
        }
      }
    } catch (_) {
      if (mounted) setState(() => _weatherDesc = "--");
    }
  }

  void _weatherResponseIsle(String body) {
    var data = json.decode(body);
    if (mounted) {
      setState(() {
        _weatherTemp = "${data['main']['temp'].round()}°C";
        _weatherDesc = data['weather'][0]['description']
            .toString()
            .toUpperCase();
        String icon = data['weather'][0]['icon'];
        if (icon.contains('01'))
          _weatherIcon = Icons.wb_sunny;
        else if (icon.contains('02'))
          _weatherIcon = Icons.cloud;
        else if (icon.contains('09') || icon.contains('10'))
          _weatherIcon = Icons.umbrella;
        else if (icon.contains('13'))
          _weatherIcon = Icons.ac_unit;
        else
          _weatherIcon = Icons.cloud_queue;
      });
    }
  }

  Future<void> _planiSil() async {
    //Tema Ayarı
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : Colors.black87;

    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        title: Text("Planı Sil", style: TextStyle(color: textColor)),
        content: Text(
          "Bu planı ve tüm içeriklerini (fotoğraflar, notlar, harcamalar) kalıcı olarak silmek istediğine emin misin?",
          style: TextStyle(color: textColor.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("İptal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Sil", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Siliniyor...")));

    try {
      final firestore = FirebaseFirestore.instance;
      final tripRef = firestore.collection('trips').doc(widget.tripId);
      final docSnap = await tripRef.get();

      if (docSnap.exists &&
          docSnap.data()?['userId'] != FirebaseAuth.instance.currentUser?.uid) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Sadece plan sahibi silebilir!"),
              backgroundColor: Colors.red,
            ),
          );
        return;
      }

      final subCols = [
        'stops',
        'expenses',
        'notes',
        'checklist',
        'docs',
        'memories',
      ];
      for (var col in subCols) {
        var snapshot = await tripRef.collection(col).limit(500).get();
        if (snapshot.docs.isNotEmpty) {
          var batch = firestore.batch();
          for (var doc in snapshot.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();
        }
      }

      await tripRef.delete();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Plan silindi! 🗑️"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: $e"), backgroundColor: Colors.red),
        );
    }
  }

  void _arkadasDavetEt() {
    final emailController = TextEditingController();
    //Tema
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : Colors.black87;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        title: Text("Arkadaş Davet Et", style: TextStyle(color: textColor)),
        content: TextField(
          controller: emailController,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            labelText: "E-posta Adresi",
            labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
            prefixIcon: const Icon(Icons.email, color: Colors.grey),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("İptal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              String email = emailController.text.trim();
              if (email.isEmpty) return;
              Navigator.pop(ctx);

              try {
                var userQuery = await FirebaseFirestore.instance
                    .collection('users')
                    .where('email', isEqualTo: email)
                    .limit(1)
                    .get();
                if (userQuery.docs.isNotEmpty) {
                  String uid = userQuery.docs.first.id;
                  var tripDoc = await FirebaseFirestore.instance
                      .collection('trips')
                      .doc(widget.tripId)
                      .get();
                  List members = tripDoc.data()?['members'] ?? [];

                  if (members.contains(uid)) {
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Bu kişi zaten planda ekli."),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    return;
                  }

                  await FirebaseFirestore.instance
                      .collection('trips')
                      .doc(widget.tripId)
                      .update({
                        'members': FieldValue.arrayUnion([uid]),
                      });
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Davet edildi! 🎉"),
                        backgroundColor: Colors.green,
                      ),
                    );
                } else {
                  if (mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Kullanıcı bulunamadı."),
                        backgroundColor: Colors.red,
                      ),
                    );
                }
              } catch (_) {}
            },
            child: const Text("Davet Et"),
          ),
        ],
      ),
    );
  }

  // UI
  @override
  Widget build(BuildContext context) {
    //TEMA DEĞİŞKENLERİ
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: true,
              title: Text(
                _guncelBaslik,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black45, blurRadius: 10)],
                ),
              ),

              background: Stack(
                fit: StackFit.expand,
                children: [
                  (widget.heroImage != null && widget.heroImage!.isNotEmpty)
                      ? CachedNetworkImage(
                          imageUrl: widget.heroImage!,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) {
                            if (widget.destination != null &&
                                widget.destination!.isNotEmpty &&
                                _placesApiKey.isNotEmpty) {
                              return GooglePlaceImage(
                                placeName: widget.destination!,
                                apiKey: _placesApiKey,
                                fit: BoxFit.cover,
                              );
                            }
                            return CachedNetworkImage(
                              imageUrl: _defaultCoverImage,
                              fit: BoxFit.cover,
                            );
                          },
                        )
                      : (widget.destination != null &&
                            widget.destination!.isNotEmpty &&
                            _placesApiKey.isNotEmpty)
                      ? GooglePlaceImage(
                          placeName: widget.destination!,
                          apiKey: _placesApiKey,
                          fit: BoxFit.cover,
                        )
                      : CachedNetworkImage(
                          imageUrl: _defaultCoverImage,
                          fit: BoxFit.cover,
                        ),
                  Container(color: Colors.black38),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: _planDetaylariniDuzenle,
              ),
              IconButton(
                icon: const Icon(Icons.person_add),
                onPressed: _arkadasDavetEt,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: _planiSil,
              ),
            ],
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverAppBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: _primaryColor,
                unselectedLabelColor: Colors.grey,
                indicatorColor: _primaryColor,
                isScrollable: true,
                tabs: const [
                  Tab(icon: Icon(Icons.map), text: "Rota"),
                  Tab(icon: Icon(Icons.check_box), text: "Hazırlık"),
                  Tab(icon: Icon(Icons.pie_chart), text: "Bütçe"),
                  Tab(icon: Icon(Icons.wallet), text: "Cüzdan"),
                  Tab(icon: Icon(Icons.note), text: "Notlar"),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildMapTab(),
            _buildChecklistTab(),
            _buildExpenseTab(),
            _buildWalletTab(),
            _buildNotesTab(),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildFAB() {
    if (_tabController.index == 0) return const SizedBox();
    IconData icon = Icons.add;
    String label = "Ekle";
    VoidCallback action = () {};

    switch (_tabController.index) {
      case 1:
        action = () => _showAddItemDialog('checklist');
        label = "Eşya";
        break;
      case 2:
        action = _showAddExpenseDialog;
        label = "Harcama";
        break;
      case 3:
        action = _belgeYukle;
        label = "Belge";
        break;
      case 4:
        action = () => _showAddItemDialog('notes');
        label = "Not";
        break;
    }

    return FloatingActionButton.extended(
      onPressed: action,
      label: Text(label),
      icon: Icon(icon),
      backgroundColor: _primaryColor,
      foregroundColor: Colors.white,
    );
  }

  Widget _buildMapTab() {
    //Tema
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : Colors.black;

    return Column(
      children: [
        if (_statusMessage.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: Colors.orange.shade100,
            child: Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.orange.shade900,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

        // GÜN SEÇİCİ
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(10),
            itemCount: _toplamGun,
            itemBuilder: (context, index) {
              int gun = index + 1;
              bool isSelected = gun == _seciliGun;
              return GestureDetector(
                onTap: () => setState(() {
                  _seciliGun = gun;
                  _isCameraMoved = false;
                }),
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? _primaryColor : cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: isSelected
                        ? null
                        : Border.all(
                            color: isDark
                                ? Colors.grey.shade800
                                : Colors.grey.shade300,
                          ),
                  ),
                  child: Text(
                    "Gün $gun",
                    style: TextStyle(
                      color: isSelected ? Colors.white : textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('trips')
                .doc(widget.tripId)
                .collection('stops')
                .orderBy('sira')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());

              var docs = snapshot.data!.docs
                  .where((d) => d['gun'] == _seciliGun)
                  .toList();
              Set<Marker> markers = Set.from(_suggestedMarkers);
              List<LatLng> route = [];

              for (int i = 0; i < docs.length; i++) {
                var d = docs[i].data() as Map<String, dynamic>;
                if (d['konum'] != null) {
                  LatLng pos = LatLng(
                    d['konum'].latitude,
                    d['konum'].longitude,
                  );
                  markers.add(
                    Marker(
                      markerId: MarkerId(docs[i].id),
                      position: pos,
                      infoWindow: InfoWindow(title: "${i + 1}. ${d['isim']}"),
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueRed,
                      ),
                    ),
                  );
                  route.add(pos);
                }
              }

              return Column(
                children: [
                  SizedBox(
                    height: 250,
                    child: GoogleMap(
                      initialCameraPosition: const CameraPosition(
                        target: LatLng(39, 35),
                        zoom: 5,
                      ),
                      markers: markers,
                      polylines: {
                        if (route.isNotEmpty)
                          Polyline(
                            polylineId: const PolylineId("route"),
                            points: route,
                            color: _primaryColor,
                            width: 4,
                          ),
                      },
                      onMapCreated: (c) {
                        if (!_mapCompleter.isCompleted)
                          _mapCompleter.complete(c);
                        _fitMapToMarkers();
                      },
                      zoomControlsEnabled: true,
                      gestureRecognizers: {
                        Factory<OneSequenceGestureRecognizer>(
                          () => EagerGestureRecognizer(),
                        ),
                      },
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(10),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        var data = docs[index].data() as Map<String, dynamic>;
                        return Card(
                          color: cardColor,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _primaryColor,
                              child: Text(
                                "${index + 1}",
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(
                              data['isim'],
                              style: TextStyle(color: textColor),
                            ),
                            subtitle: data['not'] != null
                                ? Text(
                                    data['not'],
                                    style: TextStyle(
                                      color: textColor.withOpacity(0.7),
                                    ),
                                  )
                                : null,
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => docs[index].reference.delete(),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildExpenseTab() {
    //Tema
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : Colors.black;

    final expensesRef = FirebaseFirestore.instance
        .collection('trips')
        .doc(widget.tripId)
        .collection('expenses');
    return StreamBuilder<QuerySnapshot>(
      stream: expensesRef.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        var docs = snapshot.data!.docs;

        double total = 0;
        Map<String, double> categoryMap = {};

        for (var doc in docs) {
          double amount = (doc['amount'] ?? 0).toDouble();
          String cat = doc['category'] ?? 'Diğer';
          total += amount;
          categoryMap[cat] = (categoryMap[cat] ?? 0) + amount;
        }

        return Column(
          children: [
            if (total > 0)
              SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: categoryMap.entries.map((e) {
                      final isLarge = e.value / total > 0.2;
                      return PieChartSectionData(
                        color: _getCategoryColor(e.key),
                        value: e.value,
                        title: "${(e.value / total * 100).toStringAsFixed(0)}%",
                        radius: isLarge ? 60 : 50,
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Toplam Harcama",
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  Text(
                    "${total.toStringAsFixed(0)} ₺",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  var data = docs[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getCategoryColor(data['category']),
                      child: const Icon(
                        Icons.attach_money,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(
                      data['title'],
                      style: TextStyle(color: textColor),
                    ),
                    subtitle: Text(
                      data['category'] ?? "Genel",
                      style: TextStyle(color: textColor.withOpacity(0.7)),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "${data['amount']} ₺",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                            size: 20,
                            color: Colors.grey,
                          ),
                          onPressed: () => data.reference.delete(),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Color _getCategoryColor(String? cat) {
    switch (cat) {
      case 'Yemek':
        return Colors.orange;
      case 'Ulaşım':
        return Colors.blue;
      case 'Otel':
        return Colors.purple;
      case 'Eğlence':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  Widget _buildChecklistTab() {
    //Tema
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    final ref = FirebaseFirestore.instance
        .collection('trips')
        .doc(widget.tripId)
        .collection('checklist');
    return StreamBuilder<QuerySnapshot>(
      stream: ref.orderBy('createdAt').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 8,
              children: _suggestedItems
                  .take(5)
                  .map(
                    (e) => ActionChip(
                      label: Text(e, style: TextStyle(color: textColor)),
                      backgroundColor: isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade200,
                      onPressed: () => ref.add({
                        'item': e,
                        'isDone': false,
                        'createdAt': FieldValue.serverTimestamp(),
                      }),
                    ),
                  )
                  .toList(),
            ),
            const Divider(),
            ...snapshot.data!.docs
                .map(
                  (doc) => CheckboxListTile(
                    value: doc['isDone'],
                    title: Text(
                      doc['item'],
                      style: TextStyle(
                        color: textColor,
                        decoration: doc['isDone']
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    onChanged: (v) => doc.reference.update({'isDone': v}),
                    secondary: IconButton(
                      icon: const Icon(
                        Icons.delete,
                        size: 20,
                        color: Colors.grey,
                      ),
                      onPressed: () => doc.reference.delete(),
                    ),
                  ),
                )
                .toList(),
          ],
        );
      },
    );
  }

  Widget _buildNotesTab() {
    //Tema
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : Colors.black;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('trips')
          .doc(widget.tripId)
          .collection('notes')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        if (snapshot.data!.docs.isEmpty)
          return Center(
            child: Text("Henüz not yok.", style: TextStyle(color: textColor)),
          );
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            return Card(
              color: cardColor,
              child: ListTile(
                title: Text(doc['content'], style: TextStyle(color: textColor)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.grey),
                  onPressed: () => doc.reference.delete(),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWalletTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('trips')
          .doc(widget.tripId)
          .collection('docs')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty)
          return Center(
            child: Text(
              "Cüzdan boş.",
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          );

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            return GestureDetector(
              onTap: () => showDialog(
                context: context,
                builder: (_) =>
                    Dialog(child: CachedNetworkImage(imageUrl: doc['url'])),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: doc['url'],
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 5,
                    right: 5,
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: Theme.of(context).cardColor,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.delete,
                          size: 16,
                          color: Colors.red,
                        ),
                        onPressed: () => doc.reference.delete(),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddItemDialog(String type) {
    final controller = TextEditingController();
    //Tema
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : Colors.black;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        title: Text(
          type == 'checklist' ? "Eşya Ekle" : "Not Ekle",
          style: TextStyle(color: textColor),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                FirebaseFirestore.instance
                    .collection('trips')
                    .doc(widget.tripId)
                    .collection(type)
                    .add({
                      type == 'checklist' ? 'item' : 'content': controller.text
                          .trim(),
                      if (type == 'checklist') 'isDone': false,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                Navigator.pop(ctx);
              }
            },
            child: const Text("Ekle"),
          ),
        ],
      ),
    );
  }

  void _showAddExpenseDialog() {
    final titleC = TextEditingController();
    final amountC = TextEditingController();
    String cat = 'Yemek';

    //Tema
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : Colors.black;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setD) => AlertDialog(
          backgroundColor: cardColor,
          title: Text("Harcama Ekle", style: TextStyle(color: textColor)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleC,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: "Başlık",
                  labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                ),
              ),
              TextField(
                controller: amountC,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: "Tutar",
                  labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                ),
                keyboardType: TextInputType.number,
              ),
              DropdownButton<String>(
                value: cat,
                isExpanded: true,
                dropdownColor: cardColor,
                style: TextStyle(color: textColor),
                items: ['Yemek', 'Ulaşım', 'Otel', 'Eğlence', 'Diğer']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setD(() => cat = v!),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                if (titleC.text.isNotEmpty && amountC.text.isNotEmpty) {
                  FirebaseFirestore.instance
                      .collection('trips')
                      .doc(widget.tripId)
                      .collection('expenses')
                      .add({
                        'title': titleC.text,
                        'amount': double.parse(amountC.text),
                        'category': cat,
                        'date': FieldValue.serverTimestamp(),
                      });
                  Navigator.pop(ctx);
                }
              },
              child: const Text("Ekle"),
            ),
          ],
        ),
      ),
    );
  }

  void _belgeYukle() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 60,
    );
    if (image == null) return;

    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Yükleniyor...")));

    try {
      var ref = FirebaseStorage.instance.ref().child(
        'docs/${widget.tripId}/${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await ref.putFile(File(image.path));
      String url = await ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('trips')
          .doc(widget.tripId)
          .collection('docs')
          .add({'url': url, 'createdAt': FieldValue.serverTimestamp()});
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Yüklendi!"),
            backgroundColor: Colors.green,
          ),
        );
    } catch (_) {}
  }

  void _planDetaylariniDuzenle() {
    final titleController = TextEditingController(text: _guncelBaslik);
    final daysController = TextEditingController(text: _toplamGun.toString());

    //Tema Renkleri
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : Colors.black87;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Planı Düzenle", style: TextStyle(color: textColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: "Plan Adı",
                labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: daysController,
              style: TextStyle(color: textColor),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Gün Sayısı",
                labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.isNotEmpty &&
                  daysController.text.isNotEmpty) {
                String newTitle = titleController.text.trim();
                int newDays =
                    int.tryParse(daysController.text.trim()) ?? _toplamGun;

                // Veritabanını Güncelle
                await FirebaseFirestore.instance
                    .collection('trips')
                    .doc(widget.tripId)
                    .update({'baslik': newTitle, 'gunSayisi': newDays});

                if (mounted) {
                  setState(() {
                    _guncelBaslik = newTitle;
                    _toplamGun = newDays;
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Plan güncellendi! ✅"),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _primaryColor),
            child: const Text("Kaydet", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  _SliverAppBarDelegate(this._tabBar);
  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(context, shrinkOffset, overlapsContent) {
    return Container(color: Theme.of(context).cardColor, child: _tabBar);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}
