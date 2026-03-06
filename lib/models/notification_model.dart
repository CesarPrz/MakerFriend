import 'package:cloud_firestore/cloud_firestore.dart';

enum AppNotificationType { projectLike, newFollower, postComment }

class AppNotification {
  final String id;
  final AppNotificationType type;
  final String recipientUid;
  final String actorUid;
  final String? actorName;
  final String? actorPhotoUrl;
  final String? projectId;
  final String? projectTitle;
  final String? itemId;
  final String? itemTitle;
  final DateTime? createdAt;
  final DateTime? readAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.recipientUid,
    required this.actorUid,
    this.actorName,
    this.actorPhotoUrl,
    this.projectId,
    this.projectTitle,
    this.itemId,
    this.itemTitle,
    this.createdAt,
    this.readAt,
  });

  bool get isRead => readAt != null;

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return AppNotification(
      id: doc.id,
      type: _typeFromString((data['type'] as String?) ?? ''),
      recipientUid: (data['recipientUid'] as String?) ?? '',
      actorUid: (data['actorUid'] as String?) ?? '',
      actorName: data['actorName'] as String?,
      actorPhotoUrl: data['actorPhotoUrl'] as String?,
      projectId: data['projectId'] as String?,
      projectTitle: data['projectTitle'] as String?,
      itemId: data['itemId'] as String?,
      itemTitle: data['itemTitle'] as String?,
      createdAt: _tsToDt(data['createdAt']),
      readAt: _tsToDt(data['readAt']),
    );
  }

  static AppNotificationType _typeFromString(String raw) {
    switch (raw) {
      case 'project_like':
        return AppNotificationType.projectLike;
      case 'new_follower':
        return AppNotificationType.newFollower;
      case 'post_comment':
        return AppNotificationType.postComment;
      default:
        return AppNotificationType.postComment;
    }
  }

  static DateTime? _tsToDt(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }
}
