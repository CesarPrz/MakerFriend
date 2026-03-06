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
    final data = doc.data()!;
    final ownerUid = data['ownerUid'] as String;
    final ownerDisplayName = data['ownerDisplayName'] as String?;
    final ownerPhotoUrl = data['ownerPhotoUrl'] as String?;

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
      title: data['title'] as String,
      description: data['description'] as String?,
      coverUrl: data['coverUrl'] as String?,
      ownerDisplayName: ownerDisplayName,
      ownerPhotoUrl: ownerPhotoUrl,
      createdAt: _tsToDt(data['createdAt']),
      updatedAt: _tsToDt(data['updatedAt']),
      lastTimelineUpdate: _tsToDt(data['lastTimelineUpdate']),
      followersCount: (data['followersCount'] as int?) ?? 0,
      likesCount:
          (data['likesCount'] as int?) ??
          (data['followersCount'] as int?) ??
          0,
      types: ((data['types'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
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
}
