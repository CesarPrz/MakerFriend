import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maker_friend/models/project_model.dart';

class ProjectRepository {
  final FirebaseFirestore _db;

  ProjectRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _projects =>
      _db.collection('projects');

  Stream<List<Project>> watchProjectsForOwner(String ownerUid) {
    return _projects
        .where('ownerUid', isEqualTo: ownerUid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Project.fromDoc).toList());
  }

  Future<String> createProject({
    required String ownerUid,
    required String title,
    String? description,
  }) async {
    final now = FieldValue.serverTimestamp();

    final doc = await _projects.add({
      'ownerUid': ownerUid,
      'title': title.trim(),
      'description': (description == null || description.trim().isEmpty)
          ? null
          : description.trim(),
      'createdAt': now,
      'updatedAt': now,
    });

    return doc.id;
  }
}
