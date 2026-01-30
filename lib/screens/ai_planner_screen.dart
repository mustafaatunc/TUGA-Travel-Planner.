import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../widgets/google_place_image.dart';

class AiPlannerScreen extends StatefulWidget {
  final String? baslangicSehri;

  const AiPlannerScreen({super.key, this.baslangicSehri});

  @override
  State<AiPlannerScreen> createState() => _AiPlannerScreenState();
}

class _AiPlannerScreenState extends State<AiPlannerScreen> {
  final TextEditingController _cityController = TextEditingController();

  DateTimeRange? _selectedDateRange;
  int _calculatedDays = 3;

  final String _apiKey = dotenv.env['GEMINI_API_KEY'] ?? "";
  final String _pexelsApiKey = dotenv.env['PEXELS_API_KEY'] ?? "";
  final String _placesApiKey = dotenv.env['GOOGLE_PLACES_API_KEY'] ?? "";

  Map<String, dynamic>? _planData;
  bool _isLoading = false;
  bool _isSaving = false;

  final String _selectedModel = "gemini-2.0-flash";

  String _selectedBudget = "Farketmez";
  String _selectedPace = "Farketmez";
  final List<String> _selectedInterests = [];
  bool _showFilters = false;

  final List<String> _budgetOptions = ["Farketmez", "Ekonomik", "Orta", "Lüks"];
  final List<String> _paceOptions = ["Farketmez", "Sakin", "Dengeli", "Yoğun"];
  final List<String> _interestOptions = [
    "Tarih & Kültür",
    "Yemek & Gastronomi",
    "Doğa & Manzara",
    "Sanat & Müze",
    "Alışveriş",
    "Gece Hayatı",
    "Fotoğrafçılık",
  ];

  final Map<String, GeoPoint> _locationCache = {};
  List<dynamic> _placeSuggestions = [];
  Timer? _debounce;

  User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    if (widget.baslangicSehri != null) {
      _cityController.text = widget.baslangicSehri!;
    }
  }

  @override
  void dispose() {
    _cityController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchCitySuggestions(String input) async {
    if (input.length < 3 || _placesApiKey.isEmpty) {
      if (mounted) setState(() => _placeSuggestions = []);
      return;
    }

    try {
      String requestUrl =
          "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&types=(cities)&language=tr&key=$_placesApiKey";

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
      debugPrint("Autocomplete hatası: $e");
    }
  }

  void _onSearchChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _fetchCitySuggestions(val);
    });
  }

  Future<void> _createPlan() async {
    if (_cityController.text.isEmpty) {
      _showErrorSnackBar("Lütfen bir şehir girin.");
      return;
    }

    if (_apiKey.isEmpty) {
      _showErrorSnackBar("API Anahtarı bulunamadı (GEMINI_API_KEY).");
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _planData = null;
      _placeSuggestions = [];
      _showFilters = false;
    });

    int retryCount = 0;
    const int maxRetries = 3;
    bool success = false;
    String? errorMessage;

    while (retryCount < maxRetries && !success) {
      try {
        final url = Uri.parse(
          "https://generativelanguage.googleapis.com/v1beta/models/$_selectedModel:generateContent?key=$_apiKey",
        );

        String budgetInstruction = _selectedBudget == "Farketmez"
            ? "Bütçe dengeli olsun."
            : "Bütçe: $_selectedBudget.";

        String paceInstruction = _selectedPace == "Farketmez"
            ? "Tempo: Optimize edilmiş, yorucu olmayan akış."
            : "Tempo: $_selectedPace";

        final prompt =
            """
        Sen profesyonel bir tur rehberisin. Aşağıdaki kriterlere göre eksiksiz bir seyahat planı oluştur.
        
        Hedef: ${_cityController.text}
        Süre: $_calculatedDays gün
        $budgetInstruction
        $paceInstruction
        İlgi Alanları: ${_selectedInterests.isEmpty ? "Genel Turistik" : _selectedInterests.join(", ")}

        Önemli Kurallar:
        1. Yanıtın SADECE geçerli bir JSON formatında olmalı. Markdown yok.
        2. "days" dizisi tam olarak $_calculatedDays gün içermeli.
        3. "search_term" alanı, o yerin İngilizce adı ve şehirden oluşmalı.
        4. "location_key" Türkçe yer adı olmalı.

        JSON Şeması:
        {
          "destination": "${_cityController.text}",
          "summary": "Kısa ve heyecan verici bir özet (Max 2 cümle).",
          "days": [
            {
              "day": 1,
              "morning": { "description": "...", "location_key": "Mekan Adı", "search_term": "Place Name City" },
              "afternoon": { "description": "...", "location_key": "...", "search_term": "..." },
              "evening": { "description": "...", "location_key": "...", "search_term": "..." }
            }
          ]
        }
        """;

        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            "contents": [
              {
                "parts": [
                  {"text": prompt},
                ],
              },
            ],
            "generationConfig": {
              "temperature": 0.7,
              "maxOutputTokens": 4000,
              "response_mime_type": "application/json",
            },
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['candidates'] != null && data['candidates'].isNotEmpty) {
            String rawText =
                data['candidates'][0]['content']['parts'][0]['text'];

            rawText = rawText
                .replaceAll('```json', '')
                .replaceAll('```', '')
                .trim();

            try {
              _planData = jsonDecode(rawText);
              success = true;
            } catch (e) {
              debugPrint("JSON Parse Hatası: $e");
              throw Exception("AI yanıtı okunamadı.");
            }
          }
        } else if (response.statusCode == 503 || response.statusCode == 429) {
          retryCount++;
          await Future.delayed(Duration(seconds: 2 * retryCount));
          continue;
        } else {
          throw Exception("API Hatası: ${response.statusCode}");
        }
      } catch (e) {
        debugPrint("Deneme $retryCount Hata: $e");
        retryCount++;
        if (retryCount >= maxRetries)
          errorMessage = "Plan oluşturulamadı. Lütfen tekrar deneyin.";
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (!success && errorMessage != null) {
        _showErrorDialog(errorMessage!);
      }
    }
  }

  Future<String> _fetchUrlForSaving(
    String locationName,
    String englishTerm,
  ) async {
    String city = _cityController.text.trim();
    if (city.isEmpty) city = "Turkey";
    String cleanLocation = locationName
        .replaceAll(RegExp(r'\(.*\)'), '')
        .trim();

    if (_pexelsApiKey.isNotEmpty) {
      try {
        String searchQuery = englishTerm.isNotEmpty
            ? englishTerm
            : "$cleanLocation $city";
        final pexelsUrl = Uri.parse(
          "https://api.pexels.com/v1/search?query=$searchQuery&per_page=1&orientation=landscape",
        );
        final pResponse = await http.get(
          pexelsUrl,
          headers: {'Authorization': _pexelsApiKey},
        );

        if (pResponse.statusCode == 200) {
          final pData = jsonDecode(pResponse.body);
          if (pData['photos'] != null && (pData['photos'] as List).isNotEmpty) {
            return pData['photos'][0]['src']['medium'];
          }
        }
      } catch (e) {
        debugPrint("Pexels Err: $e");
      }
    }

    if (_placesApiKey.isNotEmpty) {
      try {
        String query = "$cleanLocation $city";
        final googleUrl = Uri.parse(
          "https://maps.googleapis.com/maps/api/place/textsearch/json?query=$query&language=tr&key=$_placesApiKey",
        );

        final gResponse = await http.get(googleUrl);
        if (gResponse.statusCode == 200) {
          final gData = jsonDecode(gResponse.body);
          if (gData['results'] != null &&
              (gData['results'] as List).isNotEmpty) {
            var firstPlace = gData['results'][0];

            if (firstPlace['geometry'] != null &&
                firstPlace['geometry']['location'] != null) {
              double lat = firstPlace['geometry']['location']['lat'];
              double lng = firstPlace['geometry']['location']['lng'];
              _locationCache[locationName] = GeoPoint(lat, lng);
            }

            if (firstPlace['photos'] != null &&
                (firstPlace['photos'] as List).isNotEmpty) {
              String photoRef = firstPlace['photos'][0]['photo_reference'];
              return "https://maps.googleapis.com/maps/api/place/photo?maxwidth=600&photo_reference=$photoRef&key=$_placesApiKey";
            }
          }
        }
      } catch (e) {
        debugPrint("Google Err: $e");
      }
    }

    int uniqueLock = cleanLocation.hashCode;
    return "https://loremflickr.com/600/400/travel,landmark?lock=$uniqueLock";
  }

  Future<void> _planKaydet() async {
    if (_planData == null || currentUser == null) {
      _showErrorSnackBar("Lütfen önce giriş yapın.");
      return;
    }
    setState(() => _isSaving = true);

    try {
      String coverImage =
          "https://images.pexels.com/photos/3278215/pexels-photo-3278215.jpeg";
      if (_planData!['days'].isNotEmpty) {
        var firstMorning = _planData!['days'][0]['morning'];
        coverImage = await _fetchUrlForSaving(
          firstMorning['location_key'],
          firstMorning['search_term'],
        );
      }

      DocumentReference
      tripRef = await FirebaseFirestore.instance.collection('trips').add({
        'userId': currentUser!.uid,
        'members': [currentUser!.uid],
        'baslik': "${_planData!['destination']} (AI ✨)",
        'destination': _planData!['destination'],
        'gunSayisi': _calculatedDays,
        'baslangicTarihi':
            _selectedDateRange?.start ?? FieldValue.serverTimestamp(),
        'tarih_araligi': _selectedDateRange != null
            ? "${_selectedDateRange!.start.day}.${_selectedDateRange!.start.month} - ${_selectedDateRange!.end.day}.${_selectedDateRange!.end.month}.${_selectedDateRange!.end.year}"
            : "Tarih Seçilmedi",
        'isAiGenerated': true,
        'resimUrl': coverImage,
      });

      List days = _planData!['days'];
      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (var day in days) {
        var slots = [
          {'type': 'Sabah', 'data': day['morning'], 'offset': 1},
          {'type': 'Öğle', 'data': day['afternoon'], 'offset': 2},
          {'type': 'Akşam', 'data': day['evening'], 'offset': 3},
        ];

        for (var slot in slots) {
          var sData = slot['data'] as Map<String, dynamic>?;
          if (sData == null) continue;

          String locationKey = sData['location_key'] ?? "";
          String description = sData['description'] ?? "";
          String searchTerm = sData['search_term'] ?? "";

          String finalImageUrl = await _fetchUrlForSaving(
            locationKey,
            searchTerm,
          );
          GeoPoint finalLocation =
              _locationCache[locationKey] ?? const GeoPoint(0, 0);

          DocumentReference stopRef = tripRef.collection('stops').doc();
          int baseOrder = (day['day'] as int) * 100;
          int timeOffset = slot['offset'] as int;

          batch.set(stopRef, {
            'isim': "${slot['type']}: $locationKey",
            'not': description,
            'gun': day['day'],
            'eklenmeTarihi': FieldValue.serverTimestamp(),
            'resimUrl': finalImageUrl,
            'konum': finalLocation,
            'sira': baseOrder + timeOffset,
            'type': slot['type'],
          });
        }
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Plan başarıyla kaydedildi! 🎉"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      _showErrorSnackBar("Kaydetme hatası: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showErrorSnackBar(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    }
  }

  void _showErrorDialog(String msg) {
    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Hata"),
          content: Text(msg),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Tamam"),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _tarihSec() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: Colors.teal),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
        _calculatedDays = picked.end.difference(picked.start).inDays + 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🎨 TEMA AYARLARI
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text("AI Seyahat Asistanı ✨"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: _planData != null && !_isLoading
          ? FloatingActionButton.extended(
              onPressed: _isSaving ? null : () => _onayliKaydet(),
              label: Text(_isSaving ? "Kaydediliyor..." : "Planı Kaydet"),
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : const Icon(Icons.save),
              backgroundColor: Colors.teal,
            )
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildInputCard(isDark, cardColor, textColor),
            const SizedBox(height: 20),

            if (_isLoading)
              _buildLoadingState(isDark)
            else if (_planData != null)
              _buildPlanVisualized(isDark, cardColor, textColor),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 30),
          Stack(
            alignment: Alignment.center,
            children: [
              const SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  color: Colors.teal,
                  strokeWidth: 3,
                ),
              ),
              const Icon(Icons.auto_awesome, color: Colors.teal, size: 30),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            "TUGA Yapay Zekası Çalışıyor...",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.teal,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Sana özel rota oluşturuluyor.\nBirazdan hazır! 🚀",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard(bool isDark, Color cardColor, Color textColor) {
    final inputFillColor = isDark
        ? Colors.white.withOpacity(0.05)
        : Colors.grey.shade50;

    return Card(
      elevation: 4,
      shadowColor: Colors.teal.withOpacity(0.2),
      color: cardColor, // ✅ DÜZELTİLDİ
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Hayalindeki Tatili Planla",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor, // ✅ DÜZELTİLDİ
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _cityController,
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
                labelText: "Nereye gitmek istersin?",
                labelStyle: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey,
                ),
                hintText: "Örn: Roma, Tokyo, Kaş",
                hintStyle: TextStyle(
                  color: isDark ? Colors.white30 : Colors.grey,
                ),
                prefixIcon: const Icon(Icons.location_on, color: Colors.teal),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                filled: true,
                fillColor: inputFillColor,
              ),
            ),

            if (_placeSuggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 5),
                constraints: const BoxConstraints(maxHeight: 150),
                decoration: BoxDecoration(
                  color: cardColor,
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.grey.shade300,
                  ),
                  borderRadius: BorderRadius.circular(8),
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
                        Icons.place,
                        size: 16,
                        color: Colors.grey,
                      ),
                      title: Text(
                        mainText,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: textColor,
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          _cityController.text = mainText;
                          _placeSuggestions = [];
                        });
                        FocusScope.of(context).unfocus();
                      },
                    );
                  },
                ),
              ),

            const SizedBox(height: 15),

            OutlinedButton.icon(
              onPressed: _tarihSec,
              icon: const Icon(Icons.calendar_month, color: Colors.teal),
              label: Text(
                _selectedDateRange == null
                    ? "Tarih Seç"
                    : "$_calculatedDays Gün",
                style: const TextStyle(
                  color: Colors.teal,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),

            const SizedBox(height: 10),

            TextButton.icon(
              onPressed: () => setState(() => _showFilters = !_showFilters),
              icon: Icon(
                _showFilters ? Icons.keyboard_arrow_up : Icons.tune,
                color: Colors.orange,
              ),
              label: Text(
                _showFilters
                    ? "Filtreleri Gizle"
                    : "Planımı Özelleştir (Bütçe, İlgi Alanı)",
                style: const TextStyle(color: Colors.orange),
              ),
            ),

            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  _buildFilterSection(
                    "💰 Bütçe",
                    _budgetOptions,
                    _selectedBudget,
                    (val) => setState(() => _selectedBudget = val),
                    textColor,
                  ),
                  const SizedBox(height: 10),
                  _buildFilterSection(
                    "⚡ Tempo",
                    _paceOptions,
                    _selectedPace,
                    (val) => setState(() => _selectedPace = val),
                    textColor,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "🎨 İlgi Alanları",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _interestOptions.map((interest) {
                      final isSelected = _selectedInterests.contains(interest);
                      return FilterChip(
                        label: Text(interest),
                        selected: isSelected,
                        selectedColor: Colors.teal.shade100,
                        checkmarkColor: Colors.teal,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.black : textColor,
                        ),
                        onSelected: (selected) {
                          setState(() {
                            selected
                                ? _selectedInterests.add(interest)
                                : _selectedInterests.remove(interest);
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
              crossFadeState: _showFilters
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
            ),

            const SizedBox(height: 15),

            ElevatedButton.icon(
              onPressed: _isLoading ? null : _createPlan,
              icon: const Icon(Icons.auto_awesome),
              label: const Text("Sihirli Planı Oluştur"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection(
    String title,
    List<String> options,
    String currentVal,
    Function(String) onSelect,
    Color textColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 5),
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: options.length,
            itemBuilder: (context, index) {
              final option = options[index];
              final isSelected = option == currentVal;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(option),
                  selected: isSelected,
                  selectedColor: Colors.teal,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : textColor,
                  ),
                  onSelected: (selected) {
                    if (selected) onSelect(option);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPlanVisualized(bool isDark, Color cardColor, Color textColor) {
    final List days = _planData!['days'];
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.teal.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.teal.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Text(
                _planData!['destination'].toString().toUpperCase(),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.teal,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _planData!['summary'],
                textAlign: TextAlign.center,
                style: TextStyle(color: textColor, fontSize: 15, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: days.length,
          itemBuilder: (context, index) =>
              _buildDayCard(days[index], isDark, cardColor, textColor),
        ),
      ],
    );
  }

  Widget _buildDayCard(
    Map<String, dynamic> dayData,
    bool isDark,
    Color cardColor,
    Color textColor,
  ) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 20),
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "${dayData['day']}. GÜN",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade900,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Divider(color: isDark ? Colors.white24 : Colors.grey.shade300),
            _buildTimeSlot("Sabah ☀️", dayData['morning'], textColor),
            _buildTimeSlot("Öğle 🍽️", dayData['afternoon'], textColor),
            _buildTimeSlot("Akşam 🌙", dayData['evening'], textColor),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSlot(
    String title,
    Map<String, dynamic> slotData,
    Color textColor,
  ) {
    final String locationName = slotData['location_key'] ?? "Gezilecek Yer";
    final String englishTerm = slotData['search_term'] ?? "";

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 140,
              width: double.infinity,
              child: GooglePlaceImage(
                placeName: "$locationName $englishTerm",
                apiKey: _placesApiKey,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "$locationName: ${slotData['description']}",
            style: TextStyle(
              fontSize: 14,
              color: textColor.withOpacity(0.8),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onayliKaydet() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Planı Kaydet"),
        content: const Text(
          "Bu planı hesabınıza kaydetmek ve düzenlemeye devam etmek ister misiniz?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("İptal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _planKaydet();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            child: const Text(
              "Evet, Kaydet",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
