import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:maker_friend/models/comment_model.dart';
import 'package:maker_friend/models/timeline_item_model.dart';
import 'package:maker_friend/repositories/notification_repository.dart';

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
  final NotificationRepository _notifications;

  TimelineRepository({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
    NotificationRepository? notifications,
  })
    : _db = db ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance,
      _notifications =
          notifications ?? NotificationRepository(db: db, auth: auth);

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
    int likedProjectsPerFollowedUserLimit = 20,
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
    final likedSubsByUid = <String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>{};
    final timelineSubs = <String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>{};
    final projectIdsByOwner = <String, List<String>>{};
    final likedProjectIdsByFollowedUid = <String, Set<String>>{};
    final projectTitleById = <String, String>{};
    final projectCoverById = <String, String?>{};
    final likedProjectIds = <String>{};
    final timelineByProject = <String, List<FollowingFeedItem>>{};
    final controller = StreamController<List<FollowingFeedItem>>();
    var closed = false;
    Future<void> timelineRebuildQueue = Future.value();
    Future<void> projectRebuildQueue = Future.value();
    late void Function() scheduleTimelineRebuild;
    late void Function(List<String>) scheduleProjectRebuild;

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
        ...likedProjectIdsByFollowedUid.values.expand((x) => x),
      };

      final previousTimelineSubs = timelineSubs.values.toList(growable: false);
      timelineSubs.clear();
      timelineByProject.clear();
      for (final sub in previousTimelineSubs) {
        await sub.cancel();
      }

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

    Future<void> rebuildLikedSubs(List<String> followedUids) async {
      final previousLikedSubs = likedSubsByUid.values.toList(growable: false);
      likedSubsByUid.clear();
      likedProjectIdsByFollowedUid.clear();
      for (final sub in previousLikedSubs) {
        await sub.cancel();
      }

      if (followedUids.isEmpty) return;

      for (final uid in followedUids) {
        final sub = _db
            .collection('users')
            .doc(uid)
            .collection('likedProjects')
            .orderBy('createdAt', descending: true)
            .limit(likedProjectsPerFollowedUserLimit)
            .snapshots()
            .listen(
              (snap) {
                final ids = <String>{};
                for (final d in snap.docs) {
                  final data = d.data();
                  final fromField = (data['projectId'] as String?)?.trim();
                  final candidate = (fromField != null && fromField.isNotEmpty)
                      ? fromField
                      : d.id;
                  if (candidate.isEmpty) continue;
                  ids.add(candidate);
                }
                likedProjectIdsByFollowedUid[uid] = ids;
                scheduleTimelineRebuild();
              },
              onError: controller.addError,
            );
        likedSubsByUid[uid] = sub;
      }
    }

    Future<void> rebuildProjectSubs(List<String> followedUids) async {
      final previousProjectSubs = projectSubs.values.toList(growable: false);
      projectSubs.clear();
      projectIdsByOwner.clear();
      for (final sub in previousProjectSubs) {
        await sub.cancel();
      }
      await rebuildLikedSubs(followedUids);

      if (followedUids.isEmpty) {
        scheduleTimelineRebuild();
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
                scheduleTimelineRebuild();
              },
              onError: controller.addError,
            );
        projectSubs[uid] = sub;
      }

      // Ensure liked projects from followed users can populate feed immediately.
      scheduleTimelineRebuild();
    }

    scheduleTimelineRebuild = () {
      if (closed) return;
      timelineRebuildQueue = timelineRebuildQueue
          .then((_) async {
            if (closed) return;
            await rebuildTimelineSubsFromOwners();
          })
          .catchError((e, st) {
            if (!closed) controller.addError(e, st);
          });
    };

    scheduleProjectRebuild = (followedUids) {
      if (closed) return;
      final copy = followedUids.toList(growable: false);
      projectRebuildQueue = projectRebuildQueue
          .then((_) async {
            if (closed) return;
            await rebuildProjectSubs(copy);
          })
          .catchError((e, st) {
            if (!closed) controller.addError(e, st);
          });
    };

    followingSub = followingRef.snapshots().listen(
      (followingSnap) {
        final followedUids = followingSnap.docs.map((d) => d.id).toList();
        scheduleProjectRebuild(followedUids);
      },
      onError: controller.addError,
    );

    likedSub = likedProjectsRef.snapshots().listen(
      (likedSnap) {
        likedProjectIds
          ..clear()
          ..addAll(likedSnap.docs.map((d) => d.id));
        scheduleTimelineRebuild();
      },
      onError: controller.addError,
    );

    controller.onCancel = () async {
      closed = true;
      await followingSub.cancel();
      await likedSub.cancel();
      final remainingProjectSubs = projectSubs.values.toList(growable: false);
      final remainingLikedSubs = likedSubsByUid.values.toList(growable: false);
      final remainingTimelineSubs = timelineSubs.values.toList(growable: false);
      projectSubs.clear();
      likedSubsByUid.clear();
      timelineSubs.clear();
      for (final sub in remainingProjectSubs) {
        await sub.cancel();
      }
      for (final sub in remainingLikedSubs) {
        await sub.cancel();
      }
      for (final sub in remainingTimelineSubs) {
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

  Future<void> updatePost({
    required String projectId,
    required String itemId,
    required String title,
    String? body,
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw ArgumentError('title must not be empty');
    }
    final trimmedBody = (body ?? '').trim();

    await _timelineCol(projectId).doc(itemId).update({
      'title': trimmedTitle,
      'body': trimmedBody.isEmpty ? null : trimmedBody,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _touchProjectTimeline(projectId);
  }

  Future<void> deleteTimelineItem({
    required String projectId,
    required String itemId,
  }) async {
    final comments = await _commentsCol(projectId, itemId).get();
    final batch = _db.batch();

    for (final doc in comments.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_timelineCol(projectId).doc(itemId));

    await batch.commit();
    await _touchProjectTimeline(projectId);
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

    final itemDoc = await _timelineCol(projectId).doc(itemId).get();
    final itemData = itemDoc.data();

    await _commentsCol(projectId, itemId).add({
      'body': text,
      'createdAt': FieldValue.serverTimestamp(),
      'authorUid': user.uid,
      'authorName': user.displayName,
      'authorPhotoUrl': user.photoURL,
    });

    if (itemData == null) return;
    final recipientUid = (itemData['authorUid'] as String?) ?? '';
    final itemTitle = itemData['title'] as String?;

    final projectDoc = await _db.collection('projects').doc(projectId).get();
    final projectData = projectDoc.data();

    await _notifications.createNotification(
      recipientUid: recipientUid,
      type: 'post_comment',
      actorUid: user.uid,
      actorName: user.displayName,
      actorPhotoUrl: user.photoURL,
      projectId: projectId,
      projectTitle: projectData?['title'] as String?,
      itemId: itemId,
      itemTitle: itemTitle,
    );
  }
}
