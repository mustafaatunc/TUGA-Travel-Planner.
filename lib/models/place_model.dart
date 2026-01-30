import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum Kategori {
  tarihi,
  modern,
  doga,
  yemeIcme,
  diger;

  String get nameStr => toString().split('.').last;

  static Kategori fromString(String? value) {
    return Kategori.values.firstWhere(
      (e) => e.nameStr == value,
      orElse: () => Kategori.diger,
    );
  }
}

class TuristikYer {
  final String id;
  final String isim;
  final String aciklama;
  final LatLng konum;
  final String resimUrl;
  final Kategori kategori;
  final double rating;

  TuristikYer({
    required this.id,
    required this.isim,
    required this.aciklama,
    required this.konum,
    required this.resimUrl,
    required this.kategori,
    this.rating = 0.0,
  });

  factory TuristikYer.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    LatLng parsedKonum;

    if (data['konum'] is GeoPoint) {
      GeoPoint gp = data['konum'];
      parsedKonum = LatLng(gp.latitude, gp.longitude);
    } else {
      double lat = _parseCoordinate(data['lat']);
      double lng = _parseCoordinate(data['lng']);
      parsedKonum = LatLng(lat, lng);
    }

    return TuristikYer(
      id: doc.id,
      isim: data['isim'] ?? 'İsimsiz Mekan',
      aciklama: data['aciklama'] ?? 'Açıklama bulunmuyor.',
      konum: parsedKonum,
      resimUrl: data['resimUrl'] ?? '',
      kategori: Kategori.fromString(data['kategori']),
      rating: (data['rating'] is num)
          ? (data['rating'] as num).toDouble()
          : 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isim': isim,
      'aciklama': aciklama,
      'konum': GeoPoint(konum.latitude, konum.longitude),
      'lat': konum.latitude,
      'lng': konum.longitude,
      'resimUrl': resimUrl,
      'kategori': kategori.nameStr,
      'rating': rating,
    };
  }

  static double _parseCoordinate(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      String cleanValue = value.replaceAll(',', '.').trim();
      return double.tryParse(cleanValue) ?? 0.0;
    }
    return 0.0;
  }
}
