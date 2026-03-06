import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maker_friend/models/project_model.dart';
import 'package:maker_friend/models/app_user_model.dart';
import 'package:maker_friend/repositories/notification_repository.dart';

class ProjectRepository {
  final FirebaseFirestore _db;
  final NotificationRepository _notifications;

  ProjectRepository({FirebaseFirestore? db, NotificationRepository? notifications})
    : _db = db ?? FirebaseFirestore.instance,
      _notifications = notifications ?? NotificationRepository(db: db);

  CollectionReference<Map<String, dynamic>> get _projects =>
      _db.collection('projects');

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  DocumentReference<Map<String, dynamic>> _projectRef(String projectId) =>
      _projects.doc(projectId);

  DocumentReference<Map<String, dynamic>> _likedProjectRef(
    String uid,
    String projectId,
  ) => _users.doc(uid).collection('likedProjects').doc(projectId);

  /// Cache mémoire pour éviter de re-fetch les mêmes users
  final Map<String, AppUser> _userCache = {};

  /// ---- Public API ----

  /// Mes projets (owner) -> hydratés (withOwner)
  Stream<List<Project>> watchProjectsForOwner(String ownerUid) {
    return _projects
        .where('ownerUid', isEqualTo: ownerUid)
        .orderBy('lastTimelineUpdate', descending: true)
        .snapshots()
        .asyncMap(_hydrateProjectsFromSnapshot);
  }

  /// Découvrir -> hydratés (withOwner)
  Stream<List<Project>> watchDiscoverProjects({int limit = 50}) {
    return _projects
        .orderBy('lastTimelineUpdate', descending: true)
        .limit(limit)
        .snapshots()
        .asyncMap(_hydrateProjectsFromSnapshot);
  }

  /// Un projet en stream -> hydraté (withOwner)
  Stream<Project?> watchProject(String projectId) {
    return _projectRef(projectId).snapshots().asyncMap((doc) async {
      if (!doc.exists) return null;
      final project = Project.fromDoc(doc);
      final owner = await _getUser(project.ownerUid);
      return owner == null ? project : project.withOwner(owner);
    });
  }

  /// One-shot list -> hydratée (withOwner)
  Future<List<Project>> getProjects({int limit = 200}) async {
    final snap = await _projects
        .orderBy('lastTimelineUpdate', descending: true)
        .limit(limit)
        .get();

    return _hydrateProjectsFromSnapshot(snap);
  }

  Future<List<Project>> searchProjects(String query, {int limit = 50}) async {
    final queryLower = query.trim().toLowerCase();
    if (queryLower.isEmpty) return [];

    final snap = await _projects.orderBy('title').limit(limit).get();
    final filtered = snap.docs
        .map(Project.fromDoc)
        .where(
          (p) =>
              p.title.toLowerCase().contains(queryLower) ||
              (p.description ?? '').toLowerCase().contains(queryLower) ||
              p.types.any((t) => t.toLowerCase().contains(queryLower)),
        )
        .toList();

    return _hydrateProjects(filtered);
  }

  Future<String> createProject({
    required String ownerUid,
    required String title,

    String? description,
    List<String> types = const [],
  }) async {
    final now = FieldValue.serverTimestamp();
    final ownerDoc = await _users.doc(ownerUid).get();
    final ownerData = ownerDoc.data();

    final doc = await _projects.add({
      'ownerUid': ownerUid,
      'ownerDisplayName': ownerData?['displayName'],
      'ownerPhotoUrl': ownerData?['photoUrl'],
      'title': title.trim(),
      'description': (description == null || description.trim().isEmpty)
          ? null
          : description.trim(),
      'coverUrl': null,
      'createdAt': now,
      'types': types,
      'updatedAt': now,
      'lastTimelineUpdate': now,
      'followersCount': 0,
      'likesCount': 0,
    });

    return doc.id;
  }

  Future<void> updateProject(
    String projectId, {
    String? title,
    String? description,
    List<String>? types,
    String? coverUrl,
  }) async {
    final data = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};

    if (title != null) data['title'] = title.trim();
    if (description != null) {
      data['description'] = description.trim().isEmpty
          ? null
          : description.trim();
    }
    if (coverUrl != null) data['coverUrl'] = coverUrl;
    if (types != null) data['types'] = types;
    await _projectRef(projectId).set(data, SetOptions(merge: true));
  }

  Future<void> deleteProject(String projectId) async {
    if (projectId.isEmpty) return;
    await _projectRef(projectId).delete();
  }

  Stream<bool> watchIsProjectLiked({
    required String currentUid,
    required String projectId,
  }) {
    if (currentUid.isEmpty || projectId.isEmpty) return Stream.value(false);
    return _likedProjectRef(currentUid, projectId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  Future<void> likeProject({
    required String currentUid,
    required String projectId,
  }) async {
    if (currentUid.isEmpty || projectId.isEmpty) return;
    final ref = _likedProjectRef(currentUid, projectId);
    var created = false;
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) return;
      created = true;
      tx.set(ref, {
        'projectId': projectId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });

    if (!created) return;

    final meDoc = await _users.doc(currentUid).get();
    final me = meDoc.data();
    final projectDoc = await _projectRef(projectId).get();
    final project = projectDoc.data();
    final ownerUid = (project?['ownerUid'] as String?) ?? '';

    await _notifications.createNotification(
      recipientUid: ownerUid,
      type: 'project_like',
      actorUid: currentUid,
      actorName: me?['displayName'] as String?,
      actorPhotoUrl: me?['photoUrl'] as String?,
      projectId: projectId,
      projectTitle: project?['title'] as String?,
    );
  }

  Future<void> unlikeProject({
    required String currentUid,
    required String projectId,
  }) async {
    if (currentUid.isEmpty || projectId.isEmpty) return;
    await _likedProjectRef(currentUid, projectId).delete();
  }

  Stream<int> watchLikedProjectsCount(String uid) {
    if (uid.isEmpty) return Stream.value(0);
    return _users
        .doc(uid)
        .collection('likedProjects')
        .snapshots()
        .map((snap) => snap.size);
  }

  Stream<List<Project>> watchLikedProjects(String uid, {int limit = 100}) {
    if (uid.isEmpty) return Stream.value(const []);
    return _users
        .doc(uid)
        .collection('likedProjects')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .asyncMap((snap) async {
          final ids = snap.docs.map((d) => d.id).toList();
          if (ids.isEmpty) return <Project>[];

          final docs = await Future.wait(ids.map(_projectRef).map((r) => r.get()));
          final projects = <Project>[];
          for (final d in docs) {
            final data = d.data();
            if (!d.exists || data == null) continue;
            projects.add(Project.fromDoc(d));
          }

          return _hydrateProjects(projects);
        });
  }

  /// ---- Internals ----

  Future<List<Project>> _hydrateProjectsFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) async {
    return _hydrateProjects(snap.docs.map(Project.fromDoc).toList());
  }

  Future<List<Project>> _hydrateProjects(List<Project> projects) async {
    final ownerUids = <String>{};
    for (final p in projects) {
      if (p.ownerUid.isNotEmpty) ownerUids.add(p.ownerUid);
    }

    final toRefresh = ownerUids.toList();
    if (toRefresh.isNotEmpty) {
      final fetched = await Future.wait(toRefresh.map(_getUser));
      for (final u in fetched) {
        if (u != null) _userCache[u.uid] = u;
      }
    }

    return projects.map((p) {
      final owner = _userCache[p.ownerUid];
      return owner == null ? p : p.withOwner(owner);
    }).toList();
  }

  Future<AppUser?> _getUser(String uid) async {
    if (uid.isEmpty) return null;
    final doc = await _users.doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;

    // ✅ adapte cette ligne si ton AppUser n’a pas fromDoc
    final user = AppUser.fromFirestore(doc);

    _userCache[uid] = user;
    return user;
  }
}
