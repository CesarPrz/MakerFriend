import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String id;
  final String body;
  final DateTime? createdAt;
  final String authorUid;
  final String? authorName;
  final String? authorPhotoUrl;

  const CommentModel({
    required this.id,
    required this.body,
    this.createdAt,
    required this.authorUid,
    this.authorName,
    this.authorPhotoUrl,
  });

  factory CommentModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return CommentModel(
      id: doc.id,
      body: (data['body'] as String?) ?? '',
      createdAt: _tsToDt(data['createdAt']),
      authorUid: data['authorUid'] as String,
      authorName: data['authorName'] as String?,
      authorPhotoUrl: data['authorPhotoUrl'] as String?,
    );
  }

  static DateTime? _tsToDt(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }
}
