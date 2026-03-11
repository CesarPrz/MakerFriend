import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class AppUser extends Equatable {
  final String uid;
  final String? displayName;
  final String? email;
  final String? photoUrl;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;
  final List<String> providerIds;

  const AppUser({
    required this.uid,
    this.displayName,
    this.email,
    this.photoUrl,
    this.createdAt,
    this.lastLoginAt,
    this.providerIds = const [],
  });

  factory AppUser.fromJson(
    Map<String, dynamic> json, {
    String? fallbackUid,
  }) {
    final rawUid = json['uid'];
    final parsedUid = (rawUid is String && rawUid.trim().isNotEmpty)
        ? rawUid
        : (fallbackUid ?? '');

    return AppUser(
      uid: parsedUid,
      displayName: _asNullableString(json['displayName']),
      email: _asNullableString(json['email']),
      photoUrl: _asNullableString(json['photoUrl']),
      createdAt: _timestampToDateTime(json['createdAt']),
      lastLoginAt: _timestampToDateTime(json['lastLoginAt']),
      providerIds:
          (json['providerIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
    return AppUser.fromJson(data, fallbackUid: doc.id);
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'displayName': displayName,
      'email': email,
      'photoUrl': photoUrl,
      'createdAt': createdAt,
      'lastLoginAt': lastLoginAt,
      'providerIds': providerIds,
    };
  }

  AppUser copyWith({
    String? displayName,
    String? email,
    String? photoUrl,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    List<String>? providerIds,
  }) {
    return AppUser(
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      providerIds: providerIds ?? this.providerIds,
    );
  }

  static DateTime? _timestampToDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static String? _asNullableString(dynamic value) {
    if (value == null) return null;
    final parsed = value.toString().trim();
    return parsed.isEmpty ? null : parsed;
  }

  @override
  List<Object?> get props => [
    uid,
    displayName,
    email,
    photoUrl,
    createdAt,
    lastLoginAt,
    providerIds,
  ];
}
