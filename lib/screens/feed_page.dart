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
          if (state.items.isEmpty) {
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
            itemCount: state.groups.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final g = state.groups[i];
              return _FeedGroupListItem(
                group: g,
                currentUid: FirebaseAuth.instance.currentUser?.uid ?? '',
              );
            },
          );
        },
      ),
    );
  }
}

class _FeedGroupListItem extends StatelessWidget {
  final FeedGroup group;
  final String currentUid;

  const _FeedGroupListItem({required this.group, required this.currentUid});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FollowedLikesCard(
          currentUid: currentUid,
          projectId: group.projectId,
          projectTitle: group.projectTitle,
          projectCoverUrl: group.projectCoverUrl,
        ),
        _FeedGroupCard(group: group),
      ],
    );
  }
}

class _FollowedLikesCard extends StatelessWidget {
  final String currentUid;
  final String projectId;
  final String projectTitle;
  final String? projectCoverUrl;

  const _FollowedLikesCard({
    required this.currentUid,
    required this.projectId,
    required this.projectTitle,
    required this.projectCoverUrl,
  });

  Stream<_FollowedLikesPreview> _watchFollowedLikes() {
    if (currentUid.isEmpty) {
      return Stream.value(const _FollowedLikesPreview(totalCount: 0, users: []));
    }

    final controller = StreamController<_FollowedLikesPreview>();
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? followingSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? likesSub;
    Set<String> followedUids = <String>{};

    Future<void> emitPreview(
      QuerySnapshot<Map<String, dynamic>> likesSnap,
    ) async {
      final likedByUid = <String, DateTime?>{};
      for (final doc in likesSnap.docs) {
        final likerUid = doc.reference.parent.parent?.id;
        if (likerUid == null || !followedUids.contains(likerUid)) continue;

        final data = doc.data();
        final rawCreatedAt = data['createdAt'];
        DateTime? likedAt;
        if (rawCreatedAt is Timestamp) likedAt = rawCreatedAt.toDate();
        if (rawCreatedAt is DateTime) likedAt = rawCreatedAt;

        final previous = likedByUid[likerUid];
        if (previous == null || (likedAt != null && likedAt.isAfter(previous))) {
          likedByUid[likerUid] = likedAt;
        }
      }

      if (likedByUid.isEmpty) {
        controller.add(const _FollowedLikesPreview(totalCount: 0, users: []));
        return;
      }

      final ordered = likedByUid.entries.toList()
        ..sort((a, b) {
          final ad = a.value;
          final bd = b.value;
          if (ad == null && bd == null) return 0;
          if (ad == null) return 1;
          if (bd == null) return -1;
          return bd.compareTo(ad);
        });

      final previewUids = ordered.take(4).map((e) => e.key).toList(growable: false);
      final userDocs = await Future.wait(
        previewUids.map(
          (uid) => FirebaseFirestore.instance.collection('users').doc(uid).get(),
        ),
      );

      final users = <_FollowedLikeUser>[];
      for (final doc in userDocs) {
        final data = doc.data();
        final name = (data?['displayName'] as String?)?.trim();
        final photo = (data?['photoUrl'] as String?)?.trim();
        users.add(
          _FollowedLikeUser(
            name: (name == null || name.isEmpty) ? 'Maker' : name,
            photoUrl: (photo == null || photo.isEmpty) ? null : photo,
          ),
        );
      }

      controller.add(
        _FollowedLikesPreview(totalCount: likedByUid.length, users: users),
      );
    }

    followingSub = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUid)
        .collection('following')
        .snapshots()
        .listen(
          (followingSnap) async {
            followedUids = followingSnap.docs.map((d) => d.id).toSet();

            await likesSub?.cancel();
            likesSub = null;

            if (followedUids.isEmpty) {
              controller.add(const _FollowedLikesPreview(totalCount: 0, users: []));
              return;
            }

            likesSub = FirebaseFirestore.instance
                .collectionGroup('likedProjects')
                .where('projectId', isEqualTo: projectId)
                .snapshots()
                .listen(
                  (likesSnap) => unawaited(emitPreview(likesSnap)),
                  onError: controller.addError,
                );
          },
          onError: controller.addError,
        );

    controller.onCancel = () async {
      await followingSub?.cancel();
      await likesSub?.cancel();
    };

    return controller.stream;
  }

  String _line(_FollowedLikesPreview preview) {
    if (preview.users.isEmpty || preview.totalCount == 0) return '';
    final first = preview.users.first.name;
    final others = preview.totalCount - 1;
    if (others <= 0) return '$first a like le projet $projectTitle';
    if (others == 1) return '$first et 1 autre ont like le projet $projectTitle';
    return '$first et $others autres ont like le projet $projectTitle';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<_FollowedLikesPreview>(
      stream: _watchFollowedLikes(),
      builder: (context, snap) {
        final preview = snap.data;
        if (preview == null || preview.totalCount == 0) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => context.push('/my-projects/$projectId/timeline'),
              child: Stack(
                children: [
                  SizedBox(
                    height: 74,
                    width: double.infinity,
                    child:
                        (projectCoverUrl != null && projectCoverUrl!.isNotEmpty)
                        ? Image.network(projectCoverUrl!, fit: BoxFit.cover)
                        : Container(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
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
                        _StackedFollowedLikeAvatars(users: preview.users),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _line(preview),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
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
          ),
        );
      },
    );
  }
}

class _FollowedLikesPreview {
  final int totalCount;
  final List<_FollowedLikeUser> users;

  const _FollowedLikesPreview({required this.totalCount, required this.users});
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
