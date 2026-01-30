import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class DataService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  //SEYAHAT (TRIP) İŞLEMLERİ

  Stream<QuerySnapshot> getUserTrips() {
    if (_userId == null) return const Stream.empty();

    return _db
        .collection('trips')
        .where('members', arrayContains: _userId)
        .orderBy('baslangicTarihi')
        .snapshots()
        .handleError((e) {
          if (e.toString().contains('failed-precondition')) {
            debugPrint(
              "KRİTİK HATA: Firestore İndeksi Eksik! Linki konsoldan takip et.",
            );
          }
          debugPrint("Hata (getUserTrips): $e");
          return const Stream.empty();
        });
  }

  Future<void> addTrip(Map<String, dynamic> tripData) async {
    if (_userId == null) throw Exception("Kullanıcı oturum açmamış.");

    try {
      await _db.collection('trips').add({
        ...tripData,
        'userId': _userId,
        'olusturulma_tarihi': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Hata (addTrip): $e");
      rethrow;
    }
  }

  Stream<QuerySnapshot> getNextTrip() {
    if (_userId == null) return const Stream.empty();

    return _db
        .collection('trips')
        .where('userId', isEqualTo: _userId)
        .where('baslangicTarihi', isGreaterThanOrEqualTo: DateTime.now())
        .orderBy('baslangicTarihi')
        .limit(1)
        .snapshots()
        .handleError((e) => debugPrint("Hata (getNextTrip): $e"));
  }

  //MEKAN (PLACE) İŞLEMLERİ

  Future<List<DocumentSnapshot>> getPlaces() async {
    try {
      var snapshot = await _db.collection('mekanlar').limit(50).get();
      return snapshot.docs;
    } catch (e) {
      debugPrint("Hata (getPlaces): $e");
      return [];
    }
  }

  Future<List<DocumentSnapshot>> getFavorites(List<String> ids) async {
    if (ids.isEmpty) return [];

    try {
      List<DocumentSnapshot> allFavorites = [];

      for (var i = 0; i < ids.length; i += 10) {
        var end = (i + 10 < ids.length) ? i + 10 : ids.length;
        var chunk = ids.sublist(i, end); // 0-10, 10-20, vs.

        var snapshot = await _db
            .collection('mekanlar')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        allFavorites.addAll(snapshot.docs);
      }

      return allFavorites;
    } catch (e) {
      debugPrint("Hata (getFavorites): $e");
      return [];
    }
  }

  // Rota Ekleme
  Future<void> addStopToTrip(
    String tripId,
    Map<String, dynamic> stopData,
  ) async {
    if (_userId == null) return;

    try {
      await _db.collection('trips').doc(tripId).collection('stops').add({
        ...stopData,
        'eklenmeTarihi': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Hata (addStopToTrip): $e");
      rethrow;
    }
  }
}
