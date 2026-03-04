import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maker_friend/models/project_model.dart';
import 'package:maker_friend/models/app_user_model.dart';

class ProjectRepository {
  final FirebaseFirestore _db;

  ProjectRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _projects =>
      _db.collection('projects');

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  DocumentReference<Map<String, dynamic>> _projectRef(String projectId) =>
      _projects.doc(projectId);

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
      'coverUrl': null,
      'createdAt': now,
      'updatedAt': now,
      'lastTimelineUpdate': now,
      'followersCount': 0,
    });

    return doc.id;
  }

  Future<void> updateProject(
    String projectId, {
    String? title,
    String? description,
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

    await _projectRef(projectId).set(data, SetOptions(merge: true));
  }

  /// ---- Internals ----

  Future<List<Project>> _hydrateProjectsFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) async {
    final projects = snap.docs.map(Project.fromDoc).toList();

    // collect unique owner uids
    final ownerUids = <String>{};
    for (final p in projects) {
      if (p.ownerUid.isNotEmpty) ownerUids.add(p.ownerUid);
    }

    // fetch missing users in parallel
    final missing = ownerUids
        .where((uid) => !_userCache.containsKey(uid))
        .toList();
    if (missing.isNotEmpty) {
      final fetched = await Future.wait(missing.map(_getUser));
      for (final u in fetched) {
        if (u != null) _userCache[u.uid] = u;
      }
    }

    // attach owner
    return projects.map((p) {
      final owner = _userCache[p.ownerUid];
      return owner == null ? p : p.withOwner(owner);
    }).toList();
  }

  Future<AppUser?> _getUser(String uid) async {
    if (uid.isEmpty) return null;
    final cached = _userCache[uid];
    if (cached != null) return cached;

    final doc = await _users.doc(uid).get();
    if (!doc.exists || doc.data() == null) return null;

    // ✅ adapte cette ligne si ton AppUser n’a pas fromDoc
    final user = AppUser.fromFirestore(doc);

    _userCache[uid] = user;
    return user;
  }
}
