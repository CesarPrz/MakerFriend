import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../repositories/timeline_repository.dart';
import '../widgets/timeline_card.dart';

class FeedPage extends StatelessWidget {
  const FeedPage({super.key});

  List<_FeedGroup> _groupFeed(List<FollowingFeedItem> feed) {
    final groups = <_FeedGroup>[];
    for (final entry in feed) {
      if (groups.isNotEmpty) {
        final last = groups.last;
        if (last.projectId == entry.projectId &&
            last.authorUid == entry.item.authorUid) {
          last.items.add(entry);
          continue;
        }
      }

      groups.add(
        _FeedGroup(
          projectId: entry.projectId,
          projectTitle: entry.projectTitle,
          authorUid: entry.item.authorUid,
          authorName: entry.item.authorName,
          authorPhotoUrl: entry.item.authorPhotoUrl,
          projectCoverUrl: entry.projectCoverUrl,
          items: [entry],
        ),
      );
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) {
      return const Scaffold(
        body: Center(child: Text("Tu n'es pas connecte.")),
      );
    }

    final repo = context.read<TimelineRepository>();

    return Scaffold(
      appBar: AppBar(title: const Text('Mon fil')),
      body: StreamBuilder<List<FollowingFeedItem>>(
        stream: repo.watchFollowingFeed(me.uid),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Erreur: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final feed = snap.data!;
          if (feed.isEmpty) {
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

          final groups = _groupFeed(feed);

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            itemCount: groups.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final g = groups[i];
              return _FeedGroupCard(group: g);
            },
          );
        },
      ),
    );
  }
}

class _FeedGroup {
  final String projectId;
  final String projectTitle;
  final String authorUid;
  final String? authorName;
  final String? authorPhotoUrl;
  final String? projectCoverUrl;
  final List<FollowingFeedItem> items;

  _FeedGroup({
    required this.projectId,
    required this.projectTitle,
    required this.authorUid,
    required this.authorName,
    required this.authorPhotoUrl,
    required this.projectCoverUrl,
    required this.items,
  });
}

class _FeedGroupCard extends StatelessWidget {
  final _FeedGroup group;

  const _FeedGroupCard({required this.group});

  @override
  Widget build(BuildContext context) {
    final displayName =
        (group.authorName != null && group.authorName!.trim().isNotEmpty)
        ? group.authorName!.trim()
        : 'Maker';
    final updatesCount = group.items.length;
    final label = updatesCount > 1 ? 'updates' : 'update';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              SizedBox(
                height: 82,
                width: double.infinity,
                child: (group.projectCoverUrl != null &&
                        group.projectCoverUrl!.isNotEmpty)
                    ? Image.network(group.projectCoverUrl!, fit: BoxFit.cover)
                    : Container(color: Theme.of(context).colorScheme.surfaceContainerHighest),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.20),
                        Colors.black.withOpacity(0.55),
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
                    CircleAvatar(
                      radius: 18,
                      backgroundImage:
                          (group.authorPhotoUrl != null &&
                              group.authorPhotoUrl!.isNotEmpty)
                          ? NetworkImage(group.authorPhotoUrl!)
                          : null,
                      child:
                          (group.authorPhotoUrl == null ||
                              group.authorPhotoUrl!.isEmpty)
                          ? const Icon(Icons.person, size: 18)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$displayName a ajoute $updatesCount $label au projet',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.white),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: TimelineCard(
                    projectId: group.projectId,
                    item: group.items[i].item,
                  ),
                ),
              ),
            ),
            if (i != group.items.length - 1) ...[
              const SizedBox(height: 10),
            ],
          ],
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
