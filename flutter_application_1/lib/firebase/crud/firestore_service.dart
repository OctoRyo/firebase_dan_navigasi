import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'measurement.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'measurements';

  // CREATE
  Future<void> addMeasurement(Measurement measurement) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw 'User tidak login';

    await _db.collection(_collection).add(measurement.toFirestore());
  }

  // READ (stream real-time, filter per user)
  Stream<List<Measurement>> getMeasurements() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value([]);

    return _db
        .collection(_collection)
        .where('userId', isEqualTo: user.uid)
        .orderBy('tanggal', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Measurement.fromFirestore).toList());
  }

  // UPDATE
  Future<void> updateMeasurement(String id, Measurement updated) async {
    await _db.collection(_collection).doc(id).update(updated.toFirestore());
  }

  // DELETE
  Future<void> deleteMeasurement(String id) async {
    await _db.collection(_collection).doc(id).delete();
  }

  // Untuk filter tambahan nanti (misal by date range)
  Stream<List<Measurement>> getMeasurementsByDateRange(DateTime start, DateTime end) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value([]);

    return _db
        .collection(_collection)
        .where('userId', isEqualTo: user.uid)
        .where('tanggal', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('tanggal', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('tanggal')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Measurement.fromFirestore).toList());
  }
}