import 'package:cloud_firestore/cloud_firestore.dart';

enum TimelineItemType { step, post }

class TimelineItem {
  final String id;
  final TimelineItemType type;
  final String title;
  final String? body;
  final DateTime? createdAt;

  final String authorUid;
  final String? authorName;
  final String? authorPhotoUrl;

  final List<String> photoUrls;

  const TimelineItem({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    this.createdAt,
    required this.authorUid,
    this.authorName,
    this.authorPhotoUrl,
    this.photoUrls = const [],
  });

  factory TimelineItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return TimelineItem(
      id: doc.id,
      type: _typeFromString(data['type'] as String),
      title: (data['title'] as String?) ?? '',
      body: data['body'] as String?,
      createdAt: _tsToDt(data['createdAt']),
      authorUid: data['authorUid'] as String,
      authorName: data['authorName'] as String?,
      authorPhotoUrl: data['authorPhotoUrl'] as String?,
      photoUrls:
          (data['photoUrls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'title': title,
    'body': body,
    'authorUid': authorUid,
    'authorName': authorName,
    'authorPhotoUrl': authorPhotoUrl,
    'photoUrls': photoUrls,
  };

  static TimelineItemType _typeFromString(String s) {
    return TimelineItemType.values.firstWhere(
      (e) => e.name == s,
      orElse: () => TimelineItemType.post,
    );
  }

  static DateTime? _tsToDt(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }
}
