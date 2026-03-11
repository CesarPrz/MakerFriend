import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_user_model.dart';

class Project {
  final String id;

  /// UID stocké dans Firestore
  final String ownerUid;

  /// Objet utilisateur chargé par le repository
  final AppUser? owner;

  final String title;
  final String? description;
  final String? coverUrl;
  final String? ownerDisplayName;
  final String? ownerPhotoUrl;
  final List<String> types;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastTimelineUpdate;
  final int followersCount;
  final int likesCount;

  const Project({
    required this.id,
    required this.ownerUid,
    this.owner,
    required this.title,
    this.description,
    this.coverUrl,
    this.ownerDisplayName,
    this.ownerPhotoUrl,
    this.createdAt,
    this.updatedAt,
    this.followersCount = 0,
    this.likesCount = 0,
    this.lastTimelineUpdate,
    this.types = const [],
  });

  /// Firestore -> Project (sans owner)
  factory Project.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final ownerUid = _asNullableString(data['ownerUid']) ?? '';
    final ownerDisplayName = _asNullableString(data['ownerDisplayName']);
    final ownerPhotoUrl = _asNullableString(data['ownerPhotoUrl']);
    final title = _asNullableString(data['title']) ?? 'Projet sans titre';
    final followersCount = _asInt(data['followersCount']) ?? 0;
    final likesCount = _asInt(data['likesCount']);
    final parsedTypes = ((data['types'] as List?) ?? const [])
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();

    return Project(
      id: doc.id,
      ownerUid: ownerUid,
      owner: (ownerDisplayName != null || ownerPhotoUrl != null)
          ? AppUser(
              uid: ownerUid,
              displayName: ownerDisplayName,
              photoUrl: ownerPhotoUrl,
            )
          : null,
      title: title,
      description: _asNullableString(data['description']),
      coverUrl: _asNullableString(data['coverUrl']),
      ownerDisplayName: ownerDisplayName,
      ownerPhotoUrl: ownerPhotoUrl,
      createdAt: _tsToDt(data['createdAt']),
      updatedAt: _tsToDt(data['updatedAt']),
      lastTimelineUpdate: _tsToDt(data['lastTimelineUpdate']),
      followersCount: followersCount,
      likesCount: likesCount ?? followersCount,
      types: parsedTypes,
    );
  }

  /// Permet d'ajouter l'owner après coup
  Project withOwner(AppUser owner) {
    return Project(
      id: id,
      ownerUid: ownerUid,
      owner: owner,
      title: title,
      description: description,
      coverUrl: coverUrl,
      ownerDisplayName: ownerDisplayName,
      ownerPhotoUrl: ownerPhotoUrl,
      createdAt: createdAt,
      updatedAt: updatedAt,
      lastTimelineUpdate: lastTimelineUpdate,
      followersCount: followersCount,
      likesCount: likesCount,
      types: types,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ownerUid': ownerUid,
      'title': title,
      'description': description,
      'coverUrl': coverUrl,
      'ownerDisplayName': ownerDisplayName,
      'ownerPhotoUrl': ownerPhotoUrl,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'lastTimelineUpdate': lastTimelineUpdate == null
          ? null
          : Timestamp.fromDate(lastTimelineUpdate!),
      'followersCount': followersCount,
      'likesCount': likesCount,
      'types': types,
    }..removeWhere((k, v) => v == null);
  }

  static DateTime? _tsToDt(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }

  static String? _asNullableString(dynamic value) {
    if (value == null) return null;
    final parsed = value.toString().trim();
    return parsed.isEmpty ? null : parsed;
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
