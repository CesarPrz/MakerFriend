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
              return _FeedGroupCard(group: g);
            },
          );
        },
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
