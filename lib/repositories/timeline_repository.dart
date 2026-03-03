import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:maker_friend/models/comment_model.dart';
import 'package:maker_friend/models/timeline_item_model.dart';

class TimelineRepository {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  TimelineRepository({FirebaseFirestore? db, FirebaseAuth? auth})
    : _db = db ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> _timelineCol(String projectId) =>
      _db.collection('projects').doc(projectId).collection('timeline');

  CollectionReference<Map<String, dynamic>> _commentsCol(
    String projectId,
    String itemId,
  ) => _timelineCol(projectId).doc(itemId).collection('comments');

  Stream<List<TimelineItem>> watchTimeline(String projectId, {int limit = 50}) {
    return _timelineCol(projectId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(TimelineItem.fromDoc).toList());
  }

  Future<String> addStep({
    required String projectId,
    required String title,
    String? body,
  }) async {
    final user = _auth.currentUser!;
    final now = FieldValue.serverTimestamp();

    final doc = await _timelineCol(projectId).add({
      'type': TimelineItemType.step.name,
      'title': title.trim(),
      'body': (body == null || body.trim().isEmpty) ? null : body.trim(),
      'createdAt': now,
      'authorUid': user.uid,
      'authorName': user.displayName,
      'authorPhotoUrl': user.photoURL,
      'photoUrls': <String>[],
    });

    return doc.id;
  }

  Future<String> addPost({
    required String projectId,
    required String title,
    String? body,
    List<String> photoUrls = const [],
  }) async {
    final user = _auth.currentUser!;
    final now = FieldValue.serverTimestamp();

    final doc = await _timelineCol(projectId).add({
      'type': TimelineItemType.post.name,
      'title': title.trim(),
      'body': (body == null || body.trim().isEmpty) ? null : body.trim(),
      'createdAt': now,
      'authorUid': user.uid,
      'authorName': user.displayName,
      'authorPhotoUrl': user.photoURL,
      'photoUrls': photoUrls,
    });

    return doc.id;
  }

  Stream<List<CommentModel>> watchComments(String projectId, String itemId) {
    return _commentsCol(projectId, itemId)
        .orderBy('createdAt', descending: false) // lecture “conversation”
        .snapshots()
        .map((snap) => snap.docs.map(CommentModel.fromDoc).toList());
  }

  Future<void> addComment({
    required String projectId,
    required String itemId,
    required String body,
  }) async {
    final user = _auth.currentUser!;
    final text = body.trim();
    if (text.isEmpty) return;

    await _commentsCol(projectId, itemId).add({
      'body': text,
      'createdAt': FieldValue.serverTimestamp(),
      'authorUid': user.uid,
      'authorName': user.displayName,
      'authorPhotoUrl': user.photoURL,
    });
  }
}
