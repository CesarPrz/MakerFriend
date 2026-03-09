import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:maker_friend/features/discover/cubit/discover_cubit.dart';
import 'package:maker_friend/widgets/notification_bell_button.dart';

import '../models/project_model.dart';
import '../repositories/project_repository.dart';

class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ProjectRepository>();
    return BlocProvider(
      create: (_) => DiscoverCubit(
        projectsStream: repo.watchDiscoverProjects(limit: 100),
      ),
      child: const _DiscoverView(),
    );
  }
}

class _DiscoverView extends StatelessWidget {
  const _DiscoverView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Decouvrir'),
        actions: const [NotificationBellButton()],
      ),
      body: BlocBuilder<DiscoverCubit, DiscoverState>(
        builder: (context, state) {
          if (state.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.error != null) {
            return Center(child: Text('Erreur: ${state.error}'));
          }
          if (state.projects.isEmpty) {
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

          final selectedTagValue = state.selectedTags.isEmpty
              ? null
              : state.selectedTags.first;
          final safeSelectedTag = (selectedTagValue != null &&
                  state.tags.contains(selectedTagValue))
              ? selectedTagValue
              : null;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<DiscoverSortMode>(
                        value: state.sortMode,
                        decoration: const InputDecoration(
                          labelText: 'Tri',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: DiscoverSortMode.newest,
                            child: Text('Nouveau'),
                          ),
                          DropdownMenuItem(
                            value: DiscoverSortMode.popular,
                            child: Text('Populaire'),
                          ),
                        ],
                        onChanged: (mode) {
                          if (mode == null) return;
                          context.read<DiscoverCubit>().setSortMode(mode);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        value: safeSelectedTag,
                        decoration: const InputDecoration(
                          labelText: 'Tags',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Tous les tags'),
                          ),
                          ...state.tags.map(
                            (tag) => DropdownMenuItem<String?>(
                              value: tag,
                              child: Text(tag),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) {
                            context.read<DiscoverCubit>().clearTags();
                            return;
                          }
                          context.read<DiscoverCubit>().setSingleTag(value);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  itemCount: state.sortedProjects.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final project = state.sortedProjects[i];
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
