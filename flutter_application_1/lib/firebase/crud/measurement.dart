import 'package:cloud_firestore/cloud_firestore.dart';

class Measurement {
  final String? id;           // Document ID dari Firestore (nullable untuk data baru)
  final String userId;        // UID dari Firebase Auth
  final DateTime tanggal;     // Tanggal pengukuran
  final double kwh;           // Konsumsi energi dalam kWh
  final double tegangan;      // Tegangan dalam Volt
  final double arus;          // Arus dalam Ampere
  final String status;        // 'normal', 'warning', 'error'
  final String perangkat;     // Nama perangkat atau lokasi (misal: "Lampu Ruang Tamu")

  Measurement({
    this.id,
    required this.userId,
    required this.tanggal,
    required this.kwh,
    required this.tegangan,
    required this.arus,
    this.status = 'normal',     // default value
    required this.perangkat,
  });

  // Factory untuk convert dari Firestore document
  factory Measurement.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    if (data == null) {
      throw Exception('Data document kosong');
    }

    return Measurement(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      tanggal: (data['tanggal'] as Timestamp?)?.toDate() ?? DateTime.now(),
      kwh: (data['kwh'] as num?)?.toDouble() ?? 0.0,
      tegangan: (data['tegangan'] as num?)?.toDouble() ?? 0.0,
      arus: (data['arus'] as num?)?.toDouble() ?? 0.0,
      status: data['status'] as String? ?? 'normal',
      perangkat: data['perangkat'] as String? ?? 'Tidak diketahui',
    );
  }

  // Convert ke Map untuk disimpan/update ke Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'tanggal': Timestamp.fromDate(tanggal),
      'kwh': kwh,
      'tegangan': tegangan,
      'arus': arus,
      'status': status,
      'perangkat': perangkat,
    };
  }

  // Method copyWith untuk memudahkan update data (edit operation)
  Measurement copyWith({
    String? id,
    String? userId,
    DateTime? tanggal,
    double? kwh,
    double? tegangan,
    double? arus,
    String? status,
    String? perangkat,
  }) {
    return Measurement(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      tanggal: tanggal ?? this.tanggal,
      kwh: kwh ?? this.kwh,
      tegangan: tegangan ?? this.tegangan,
      arus: arus ?? this.arus,
      status: status ?? this.status,
      perangkat: perangkat ?? this.perangkat,
    );
  }

  // Untuk debugging & logging
  @override
  String toString() {
    return 'Measurement(id: $id, userId: $userId, tanggal: $tanggal, '
        'kwh: ${kwh.toStringAsFixed(2)} kWh, tegangan: ${tegangan.toStringAsFixed(1)} V, '
        'arus: ${arus.toStringAsFixed(2)} A, status: $status, perangkat: $perangkat)';
  }

  // Opsional: Equality check (berguna jika pakai state management)
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Measurement &&
        other.id == id &&
        other.userId == userId &&
        other.tanggal == tanggal &&
        other.kwh == kwh &&
        other.tegangan == tegangan &&
        other.arus == arus &&
        other.status == status &&
        other.perangkat == perangkat;
  }

  @override
  int get hashCode =>
      id.hashCode ^
      userId.hashCode ^
      tanggal.hashCode ^
      kwh.hashCode ^
      tegangan.hashCode ^
      arus.hashCode ^
      status.hashCode ^
      perangkat.hashCode;
}