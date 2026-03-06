import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:maker_friend/widgets/notification_bell_button.dart';

import '../models/project_model.dart';
import '../repositories/project_repository.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  final Set<String> _selectedTags = <String>{};

  List<Project> _sortProjects(List<Project> projects) {
    if (_selectedTags.isEmpty) return projects;

    final selected = _selectedTags.map((e) => e.toLowerCase()).toSet();
    final sorted = [...projects];
    sorted.sort((a, b) {
      int score(Project p) {
        var s = 0;
        for (final t in p.types) {
          if (selected.contains(t.toLowerCase())) s++;
        }
        return s;
      }

      final scoreDiff = score(b) - score(a);
      if (scoreDiff != 0) return scoreDiff;

      final ad = a.lastTimelineUpdate;
      final bd = b.lastTimelineUpdate;
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return bd.compareTo(ad);
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ProjectRepository>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Decouvrir'),
        actions: const [NotificationBellButton()],
      ),
      body: StreamBuilder<List<Project>>(
        stream: repo.watchDiscoverProjects(limit: 100),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Erreur: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final projects = snap.data!;
          if (projects.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  "Aucun projet a decouvrir pour l'instant.",
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final allTags =
              projects
                  .expand((p) => p.types)
                  .map((t) => t.trim())
                  .where((t) => t.isNotEmpty)
                  .toSet()
                  .toList()
                ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

          final sortedProjects = _sortProjects(projects);

          return Column(
            children: [
              if (allTags.isNotEmpty)
                SizedBox(
                  height: 56,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    scrollDirection: Axis.horizontal,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: const Text('Tous'),
                          selected: _selectedTags.isEmpty,
                          onSelected: (_) {
                            setState(_selectedTags.clear);
                          },
                        ),
                      ),
                      for (final tag in allTags)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(tag),
                            selected: _selectedTags.contains(tag),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedTags.add(tag);
                                } else {
                                  _selectedTags.remove(tag);
                                }
                              });
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  itemCount: sortedProjects.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final project = sortedProjects[i];
                    return _DiscoverProjectCard(
                      project: project,
                      onTap: () =>
                          context.push('/my-projects/${project.id}/timeline'),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DiscoverProjectCard extends StatelessWidget {
  final Project project;
  final VoidCallback onTap;

  const _DiscoverProjectCard({required this.project, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ownerName = project.owner?.displayName ?? 'Maker';
    final ownerPhoto = project.owner?.photoUrl;
    final desc = project.description?.trim();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: project.coverUrl == null
                  ? Container(
                      color: Colors.black12,
                      alignment: Alignment.center,
                      child: const Icon(Icons.image_outlined, size: 32),
                    )
                  : Image.network(
                      project.coverUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.black12,
                        alignment: Alignment.center,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => context.push('/u/${project.ownerUid}'),
                        child: _Avatar(url: ownerPhoto),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => context.push('/u/${project.ownerUid}'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              ownerName,
                              style: Theme.of(context).textTheme.bodyMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                      _ProjectLikeButton(
                        projectId: project.id,
                        likesCount: project.likesCount,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    project.title,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (desc != null && desc.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  if (project.types.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final t in project.types.take(4))
                          Chip(
                            label: Text(t),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectLikeButton extends StatefulWidget {
  final String projectId;
  final int likesCount;
  const _ProjectLikeButton({required this.projectId, required this.likesCount});

  @override
  State<_ProjectLikeButton> createState() => _ProjectLikeButtonState();
}

class _ProjectLikeButtonState extends State<_ProjectLikeButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    final repo = context.read<ProjectRepository>();

    return StreamBuilder<bool>(
      stream: repo.watchIsProjectLiked(
        currentUid: uid,
        projectId: widget.projectId,
      ),
      builder: (context, snap) {
        final isLiked = snap.data ?? false;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: isLiked ? 'Retirer le like' : 'Liker',
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      try {
                        if (isLiked) {
                          await repo.unlikeProject(
                            currentUid: uid,
                            projectId: widget.projectId,
                          );
                        } else {
                          await repo.likeProject(
                            currentUid: uid,
                            projectId: widget.projectId,
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(isLiked ? Icons.favorite : Icons.favorite_border),
              color: isLiked ? Colors.redAccent : null,
            ),
            Text(
              '${widget.likesCount}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(width: 8),
          ],
        );
      },
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? url;
  const _Avatar({this.url});

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return const CircleAvatar(
        radius: 12,
        child: Icon(Icons.person, size: 14),
      );
    }

    return CircleAvatar(radius: 12, backgroundImage: NetworkImage(url!));
  }
}
