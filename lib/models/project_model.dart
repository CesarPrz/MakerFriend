import 'package:cloud_firestore/cloud_firestore.dart';

class Project {
  final String id;
  final String ownerUid;
  final String title;
  final String? description;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Project({
    required this.id,
    required this.ownerUid,
    required this.title,
    this.description,
    this.createdAt,
    this.updatedAt,
  });

  factory Project.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Project(
      id: doc.id,
      ownerUid: data['ownerUid'] as String,
      title: data['title'] as String,
      description: data['description'] as String?,
      createdAt: _tsToDt(data['createdAt']),
      updatedAt: _tsToDt(data['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ownerUid': ownerUid,
      'title': title,
      'description': description,
      // createdAt/updatedAt seront mis côté repository avec serverTimestamp
    };
  }

  static DateTime? _tsToDt(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }
}
