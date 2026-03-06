import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:maker_friend/models/comment_model.dart';
import 'package:maker_friend/models/timeline_item_model.dart';

class FollowingFeedItem {
  final String projectId;
  final String projectTitle;
  final String? projectCoverUrl;
  final TimelineItem item;

  const FollowingFeedItem({
    required this.projectId,
    required this.projectTitle,
    required this.projectCoverUrl,
    required this.item,
  });
}

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

  Stream<List<FollowingFeedItem>> watchFollowingFeed(
    String currentUid, {
    int projectsPerUserLimit = 10,
    int perProjectTimelineLimit = 5,
    int totalLimit = 100,
  }) {
    if (currentUid.isEmpty) return Stream.value(const []);

    final followingRef = _db
        .collection('users')
        .doc(currentUid)
        .collection('following');
    final likedProjectsRef = _db
        .collection('users')
        .doc(currentUid)
        .collection('likedProjects');

    late StreamSubscription<QuerySnapshot<Map<String, dynamic>>> followingSub;
    late StreamSubscription<QuerySnapshot<Map<String, dynamic>>> likedSub;
    final projectSubs = <String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>{};
    final timelineSubs = <String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>{};
    final projectIdsByOwner = <String, List<String>>{};
    final projectTitleById = <String, String>{};
    final projectCoverById = <String, String?>{};
    final likedProjectIds = <String>{};
    final timelineByProject = <String, List<FollowingFeedItem>>{};
    final controller = StreamController<List<FollowingFeedItem>>();

    void emit() {
      final merged = timelineByProject.values.expand((x) => x).toList()
        ..sort((a, b) {
          final ad = a.item.createdAt;
          final bd = b.item.createdAt;
          if (ad == null && bd == null) return 0;
          if (ad == null) return 1;
          if (bd == null) return -1;
          return bd.compareTo(ad);
        });
      controller.add(merged.take(totalLimit).toList());
    }

    Future<void> rebuildTimelineSubsFromOwners() async {
      final allProjectIds = {
        ...projectIdsByOwner.values.expand((x) => x),
        ...likedProjectIds,
      };

      for (final sub in timelineSubs.values) {
        await sub.cancel();
      }
      timelineSubs.clear();
      timelineByProject.clear();

      if (allProjectIds.isEmpty) {
        emit();
        return;
      }

      for (final projectId in allProjectIds) {
        if (!projectTitleById.containsKey(projectId)) {
          final doc = await _db.collection('projects').doc(projectId).get();
          final data = doc.data();
          projectTitleById[projectId] = (data?['title'] as String?) ?? 'Projet';
          projectCoverById[projectId] = data?['coverUrl'] as String?;
        }

        final sub = _db
            .collection('projects')
            .doc(projectId)
            .collection('timeline')
            .orderBy('createdAt', descending: true)
            .limit(perProjectTimelineLimit)
            .snapshots()
            .listen(
              (snap) {
                final items = <FollowingFeedItem>[];
                for (final doc in snap.docs) {
                  items.add(
                    FollowingFeedItem(
                      projectId: projectId,
                      projectTitle: projectTitleById[projectId] ?? 'Projet',
                      projectCoverUrl: projectCoverById[projectId],
                      item: TimelineItem.fromDoc(doc),
                    ),
                  );
                }
                timelineByProject[projectId] = items;
                emit();
              },
              onError: controller.addError,
            );

        timelineSubs[projectId] = sub;
      }
    }

    Future<void> rebuildProjectSubs(List<String> followedUids) async {
      for (final sub in projectSubs.values) {
        await sub.cancel();
      }
      projectSubs.clear();
      projectIdsByOwner.clear();

      if (followedUids.isEmpty) {
        await rebuildTimelineSubsFromOwners();
        return;
      }

      for (final uid in followedUids) {
        final sub = _db
            .collection('projects')
            .where('ownerUid', isEqualTo: uid)
            .orderBy('lastTimelineUpdate', descending: true)
            .limit(projectsPerUserLimit)
            .snapshots()
            .listen(
              (snap) {
                projectIdsByOwner[uid] = snap.docs.map((d) => d.id).toList();
                for (final d in snap.docs) {
                  final data = d.data();
                  projectTitleById[d.id] = (data['title'] as String?) ?? 'Projet';
                  projectCoverById[d.id] = data['coverUrl'] as String?;
                }
                unawaited(rebuildTimelineSubsFromOwners());
              },
              onError: controller.addError,
            );
        projectSubs[uid] = sub;
      }
    }

    followingSub = followingRef.snapshots().listen(
      (followingSnap) {
        final followedUids = followingSnap.docs.map((d) => d.id).toList();
        unawaited(rebuildProjectSubs(followedUids));
      },
      onError: controller.addError,
    );

    likedSub = likedProjectsRef.snapshots().listen(
      (likedSnap) {
        likedProjectIds
          ..clear()
          ..addAll(likedSnap.docs.map((d) => d.id));
        unawaited(rebuildTimelineSubsFromOwners());
      },
      onError: controller.addError,
    );

    controller.onCancel = () async {
      await followingSub.cancel();
      await likedSub.cancel();
      for (final sub in projectSubs.values) {
        await sub.cancel();
      }
      for (final sub in timelineSubs.values) {
        await sub.cancel();
      }
    };

    return controller.stream;
  }

  Future<void> _touchProjectTimeline(String projectId) async {
    await FirebaseFirestore.instance.collection('projects').doc(projectId).set({
      'lastTimelineUpdate': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
    _touchProjectTimeline(projectId); // update lastTimelineUpdate du projet
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
    _touchProjectTimeline(projectId); // update lastTimelineUpdate du projet

    return doc.id;
  }

  Future<String> addPhotoPost({
    required String projectId,
    required String title,
    String? body,
    required List<String> photoUrls,
  }) async {
    final user = _auth.currentUser!;
    final now = FieldValue.serverTimestamp();

    final doc = await _timelineCol(projectId).add({
      'type': 'post',
      'title': title.trim(),
      'body': (body == null || body.trim().isEmpty) ? null : body.trim(),
      'createdAt': now,
      'authorUid': user.uid,
      'authorName': user.displayName,
      'authorPhotoUrl': user.photoURL,
      'photoUrls': photoUrls,
    });
    _touchProjectTimeline(projectId); // update lastTimelineUpdate du projet

    return doc.id;
  }

  Stream<List<CommentModel>> watchComments(String projectId, String itemId) {
    return _commentsCol(projectId, itemId)
        .orderBy('createdAt', descending: false) // lecture “conversation”
        .snapshots()
        .map((snap) => snap.docs.map(CommentModel.fromDoc).toList());
  }

  // Ne compte pas comme une update du projet (pas de touchProjectTimeline) car c’est un simple commentaire, pas une vraie update du projet
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
