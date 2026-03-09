import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:maker_friend/features/feed/cubit/feed_cubit.dart';
import 'package:maker_friend/widgets/notification_bell_button.dart';

import '../models/timeline_item_model.dart';
import '../repositories/timeline_repository.dart';
import '../widgets/timeline_card.dart';

class FeedPage extends StatelessWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) {
      return const Scaffold(body: Center(child: Text("Tu n'es pas connecte.")));
    }

    final repo = context.read<TimelineRepository>();
    return BlocProvider(
      create: (_) => FeedCubit(feedStream: repo.watchFollowingFeed(me.uid)),
      child: const _FeedView(),
    );
  }
}

class _FeedView extends StatelessWidget {
  const _FeedView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon fil'),
        actions: const [NotificationBellButton()],
      ),
      body: BlocBuilder<FeedCubit, FeedState>(
        builder: (context, state) {
          if (state.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.error != null) {
            return Center(child: Text('Erreur: ${state.error}'));
          }

          return _FeedContent(
            groups: state.groups,
            currentUid: FirebaseAuth.instance.currentUser?.uid ?? '',
          );
        },
      ),
    );
  }
}

class _FeedContent extends StatefulWidget {
  final List<FeedGroup> groups;
  final String currentUid;

  const _FeedContent({required this.groups, required this.currentUid});

  @override
  State<_FeedContent> createState() => _FeedContentState();
}

class _FeedContentState extends State<_FeedContent> {
  late Stream<List<_FeedLikeActivity>> _likesStream;

  @override
  void initState() {
    super.initState();
    _likesStream = _watchFollowedLikesActivities(widget.currentUid);
  }

  @override
  void didUpdateWidget(covariant _FeedContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUid != widget.currentUid) {
      _likesStream = _watchFollowedLikesActivities(widget.currentUid);
    }
  }

  DateTime? _asDateTime(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }

  DateTime? _groupDate(FeedGroup group) {
    DateTime? latest;
    for (final entry in group.items) {
      final d = entry.item.createdAt;
      if (d == null) continue;
      if (latest == null || d.isAfter(latest)) latest = d;
    }
    return latest;
  }

  Stream<List<_FeedLikeActivity>> _watchFollowedLikesActivities(String currentUid) {
    if (currentUid.isEmpty) return Stream.value(const []);

    final controller = StreamController<List<_FeedLikeActivity>>();
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? followingSub;
    final likedSubsByUid =
        <String, StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>{};
    final likedByFollowedUid = <String, Map<String, DateTime?>>{};
    final projectCache = <String, _ProjectLikeMeta>{};
    final userCache = <String, _FollowedLikeUser>{};
    var closed = false;
    Future<void> emitQueue = Future.value();

    Future<void> emitActivities() async {
      final byProject = <String, Map<String, DateTime?>>{};
      for (final perUid in likedByFollowedUid.entries) {
        final likerUid = perUid.key;
        for (final perProject in perUid.value.entries) {
          byProject.putIfAbsent(perProject.key, () => <String, DateTime?>{})[likerUid] =
              perProject.value;
        }
      }

      if (byProject.isEmpty) {
        controller.add(const []);
        return;
      }

      final missingProjectIds = byProject.keys
          .where((id) => !projectCache.containsKey(id))
          .toList(growable: false);
      if (missingProjectIds.isNotEmpty) {
        final docs = await Future.wait(
          missingProjectIds.map(
            (id) => FirebaseFirestore.instance.collection('projects').doc(id).get(),
          ),
        );
        for (final doc in docs) {
          final data = doc.data();
          projectCache[doc.id] = _ProjectLikeMeta(
            title: (data?['title'] as String?) ?? 'Projet',
            coverUrl: data?['coverUrl'] as String?,
          );
        }
      }

      final orderedLikersByProject = <String, List<MapEntry<String, DateTime?>>>{};
      final neededUserIds = <String>{};
      byProject.forEach((projectId, likerMap) {
        final ordered = likerMap.entries.toList()
          ..sort((a, b) {
            final ad = a.value;
            final bd = b.value;
            if (ad == null && bd == null) return 0;
            if (ad == null) return 1;
            if (bd == null) return -1;
            return bd.compareTo(ad);
          });
        orderedLikersByProject[projectId] = ordered;
        neededUserIds.addAll(ordered.take(4).map((e) => e.key));
      });

      final missingUsers = neededUserIds
          .where((uid) => !userCache.containsKey(uid))
          .toList(growable: false);
      if (missingUsers.isNotEmpty) {
        final docs = await Future.wait(
          missingUsers.map(
            (uid) => FirebaseFirestore.instance.collection('users').doc(uid).get(),
          ),
        );
        for (final doc in docs) {
          final data = doc.data();
          final name = (data?['displayName'] as String?)?.trim();
          final photo = (data?['photoUrl'] as String?)?.trim();
          userCache[doc.id] = _FollowedLikeUser(
            name: (name == null || name.isEmpty) ? 'Maker' : name,
            photoUrl: (photo == null || photo.isEmpty) ? null : photo,
          );
        }
      }

      final activities = <_FeedLikeActivity>[];
      byProject.forEach((projectId, likerMap) {
        final meta = projectCache[projectId];
        final ordered = orderedLikersByProject[projectId] ?? const [];
        final users = ordered
            .take(4)
            .map(
              (e) => userCache[e.key] ?? const _FollowedLikeUser(name: 'Maker'),
            )
            .toList(growable: false);
        final likedAt = ordered.isEmpty ? null : ordered.first.value;

        activities.add(
          _FeedLikeActivity(
            projectId: projectId,
            projectTitle: meta?.title ?? 'Projet',
            projectCoverUrl: meta?.coverUrl,
            likedAt: likedAt,
            totalCount: likerMap.length,
            users: users,
          ),
        );
      });

      activities.sort((a, b) {
        final ad = a.likedAt;
        final bd = b.likedAt;
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return bd.compareTo(ad);
      });

      controller.add(activities);
    }

    void scheduleEmit() {
      if (closed) return;
      emitQueue = emitQueue
          .then((_) async {
            if (closed) return;
            await emitActivities();
          })
          .catchError((e, st) {
            if (!closed) controller.addError(e, st);
          });
    }

    Future<void> rebuildLikedSubs(List<String> followedUids) async {
      final previous = likedSubsByUid.values.toList(growable: false);
      likedSubsByUid.clear();
      likedByFollowedUid.clear();
      for (final sub in previous) {
        await sub.cancel();
      }

      if (followedUids.isEmpty) {
        scheduleEmit();
        return;
      }

      for (final uid in followedUids) {
        likedSubsByUid[uid] = FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('likedProjects')
            .orderBy('createdAt', descending: true)
            .limit(20)
            .snapshots()
            .listen(
              (snap) {
                final byProject = <String, DateTime?>{};
                for (final doc in snap.docs) {
                  final data = doc.data();
                  final fromField = (data['projectId'] as String?)?.trim();
                  final projectId =
                      (fromField != null && fromField.isNotEmpty) ? fromField : doc.id;
                  if (projectId.isEmpty) continue;

                  final likedAt = _asDateTime(data['createdAt']);
                  final previousAt = byProject[projectId];
                  if (previousAt == null ||
                      (likedAt != null && likedAt.isAfter(previousAt))) {
                    byProject[projectId] = likedAt;
                  }
                }
                likedByFollowedUid[uid] = byProject;
                scheduleEmit();
              },
              onError: controller.addError,
            );
      }
    }

    followingSub = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUid)
        .collection('following')
        .snapshots()
        .listen(
          (followingSnap) {
            final followedUids = followingSnap.docs.map((d) => d.id).toList();
            unawaited(rebuildLikedSubs(followedUids));
          },
          onError: controller.addError,
        );

    controller.onCancel = () async {
      closed = true;
      await followingSub?.cancel();
      final remaining = likedSubsByUid.values.toList(growable: false);
      likedSubsByUid.clear();
      for (final sub in remaining) {
        await sub.cancel();
      }
    };

    return controller.stream;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<_FeedLikeActivity>>(
      stream: _likesStream,
      builder: (context, likesSnap) {
        final likes = likesSnap.data ?? const <_FeedLikeActivity>[];
        var order = 0;
        final entries = <_FeedRenderEntry>[
          for (final g in widget.groups)
            _FeedRenderEntry.group(
              group: g,
              sortAt: _groupDate(g),
              originalOrder: order++,
            ),
          for (final l in likes)
            _FeedRenderEntry.like(
              like: l,
              sortAt: l.likedAt,
              originalOrder: order++,
            ),
        ]..sort((a, b) {
            final ad = a.sortAt;
            final bd = b.sortAt;
            if (ad == null && bd == null) {
              return a.originalOrder.compareTo(b.originalOrder);
            }
            if (ad == null) return 1;
            if (bd == null) return -1;
            final byDate = bd.compareTo(ad);
            if (byDate != 0) return byDate;
            return a.originalOrder.compareTo(b.originalOrder);
          });

        if (entries.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                "Ton fil est vide.\nSuis des makers pour voir leurs updates.",
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          itemCount: entries.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final entry = entries[i];
            if (entry.like != null) {
              return _FollowedLikesActivityCard(like: entry.like!);
            }
            return _FeedGroupCard(group: entry.group!);
          },
        );
      },
    );
  }
}

class _FeedRenderEntry {
  final FeedGroup? group;
  final _FeedLikeActivity? like;
  final DateTime? sortAt;
  final int originalOrder;

  const _FeedRenderEntry.group({
    required FeedGroup group,
    required this.sortAt,
    required this.originalOrder,
  })
      : group = group,
        like = null;

  const _FeedRenderEntry.like({
    required _FeedLikeActivity like,
    required this.sortAt,
    required this.originalOrder,
  })
      : like = like,
        group = null;
}

class _FeedLikeActivity {
  final String projectId;
  final String projectTitle;
  final String? projectCoverUrl;
  final DateTime? likedAt;
  final int totalCount;
  final List<_FollowedLikeUser> users;

  const _FeedLikeActivity({
    required this.projectId,
    required this.projectTitle,
    required this.projectCoverUrl,
    required this.likedAt,
    required this.totalCount,
    required this.users,
  });
}

class _ProjectLikeMeta {
  final String title;
  final String? coverUrl;

  const _ProjectLikeMeta({required this.title, required this.coverUrl});
}

class _FollowedLikesActivityCard extends StatelessWidget {
  final _FeedLikeActivity like;

  const _FollowedLikesActivityCard({required this.like});

  String _line() {
    if (like.users.isEmpty || like.totalCount == 0) return '';
    final first = like.users.first.name;
    final others = like.totalCount - 1;
    if (others <= 0) return '$first a like le projet ${like.projectTitle}';
    if (others == 1) {
      return '$first et 1 autre ont like le projet ${like.projectTitle}';
    }
    return '$first et $others autres ont like le projet ${like.projectTitle}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/my-projects/${like.projectId}/timeline'),
        child: Stack(
          children: [
            SizedBox(
              height: 74,
              width: double.infinity,
              child: (like.projectCoverUrl != null && like.projectCoverUrl!.isNotEmpty)
                  ? Image.network(like.projectCoverUrl!, fit: BoxFit.cover)
                  : Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.45),
                      Colors.black.withOpacity(0.78),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Row(
                children: [
                  _StackedFollowedLikeAvatars(users: like.users),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _line(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FollowedLikeUser {
  final String name;
  final String? photoUrl;

  const _FollowedLikeUser({
    required this.name,
    this.photoUrl,
  });
}

class _StackedFollowedLikeAvatars extends StatelessWidget {
  final List<_FollowedLikeUser> users;

  const _StackedFollowedLikeAvatars({required this.users});

  @override
  Widget build(BuildContext context) {
    final shown = users.take(4).toList(growable: false);
    if (shown.isEmpty) return const SizedBox.shrink();

    const avatarSize = 26.0;
    const overlap = 16.0;
    final width = avatarSize + (shown.length - 1) * overlap;

    return SizedBox(
      width: width,
      height: avatarSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * overlap,
              child: Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.6),
                ),
                child: CircleAvatar(
                  radius: avatarSize / 2,
                  backgroundImage: shown[i].photoUrl != null
                      ? NetworkImage(shown[i].photoUrl!)
                      : null,
                  child: shown[i].photoUrl == null
                      ? Text(
                          shown[i].name.isEmpty
                              ? '?'
                              : shown[i].name[0].toUpperCase(),
                          style: const TextStyle(fontSize: 11),
                        )
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FeedGroupCard extends StatelessWidget {
  final FeedGroup group;

  const _FeedGroupCard({required this.group});

  @override
  Widget build(BuildContext context) {
    final updatesCount = group.items.length;
    final label = updatesCount > 1 ? 'updates' : 'update';

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(group.authorUid)
          .snapshots(),
      builder: (context, userSnap) {
        final userData = userSnap.data?.data();
        final liveName = (userData?['displayName'] as String?)?.trim();
        final livePhoto = (userData?['photoUrl'] as String?)?.trim();

        final displayName = (liveName != null && liveName.isNotEmpty)
            ? liveName
            : ((group.authorName != null && group.authorName!.trim().isNotEmpty)
                  ? group.authorName!.trim()
                  : 'Maker');
        final photoUrl = (livePhoto != null && livePhoto.isNotEmpty)
            ? livePhoto
            : group.authorPhotoUrl;

        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push('/my-projects/${group.projectId}/timeline'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    SizedBox(
                      height: 82,
                      width: double.infinity,
                      child:
                          (group.projectCoverUrl != null &&
                              group.projectCoverUrl!.isNotEmpty)
                          ? Image.network(
                              group.projectCoverUrl!,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                            ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.5),
                              Colors.black.withOpacity(0.8),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () => context.push('/u/${group.authorUid}'),
                            child: CircleAvatar(
                              radius: 18,
                              backgroundImage:
                                  (photoUrl != null && photoUrl.isNotEmpty)
                                  ? NetworkImage(photoUrl)
                                  : null,
                              child: (photoUrl == null || photoUrl.isEmpty)
                                  ? const Icon(Icons.person, size: 18)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    InkWell(
                                      onTap: () =>
                                          context.push('/u/${group.authorUid}'),
                                      child: Text(
                                        displayName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    Text(
                                      ' a ajoute $updatesCount $label au projet',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(color: Colors.white),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  group.projectTitle,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (var i = 0; i < group.items.length; i++) ...[
                  _InnerFeedItem(
                    projectId: group.projectId,
                    item: group.items[i].item,
                    authorNameOverride: displayName,
                  ),
                  if (i != group.items.length - 1) ...[
                    const SizedBox(height: 10),
                  ],
                ],
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InnerFeedItem extends StatelessWidget {
  final String projectId;
  final TimelineItem item;
  final String? authorNameOverride;

  const _InnerFeedItem({
    required this.projectId,
    required this.item,
    this.authorNameOverride,
  });

  @override
  Widget build(BuildContext context) {
    final isStep = item.type == TimelineItemType.step;
    final card = TimelineCard(
      projectId: projectId,
      item: item,
      authorNameOverride: authorNameOverride,
    );

    if (isStep) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: card,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Padding(padding: const EdgeInsets.all(2), child: card),
      ),
    );
  }
}
