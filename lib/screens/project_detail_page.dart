import 'dart:collection';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/project_model.dart';
import '../repositories/project_repository.dart';
import '../widgets/timeline_card.dart';

class ProjectDetailPage extends StatelessWidget {
  final String projectId;
  const ProjectDetailPage({super.key, required this.projectId});

  bool _isOwner(Project project) {
    final me = FirebaseAuth.instance.currentUser?.uid;
    return me != null && me == project.ownerUid;
  }

  Future<void> _deleteProject(
    BuildContext context, {
    required ProjectRepository repo,
    required String id,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer le projet ?'),
        content: const Text(
          'Cette action est irreversible. Le projet sera retire de la liste.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    await repo.deleteProject(id);
    if (!context.mounted) return;
    context.go('/my-projects');
  }

  @override
  Widget build(BuildContext context) {
    final repo = ProjectRepository();

    return StreamBuilder<Project?>(
      stream: repo.watchProject(projectId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final project = snap.data;
        if (project == null) {
          return const Scaffold(
            body: Center(child: Text('Projet introuvable')),
          );
        }

        final owner = _isOwner(project);
        final ownerName =
            (project.owner?.displayName ?? '').trim().isEmpty
                ? 'Maker'
                : project.owner!.displayName!.trim();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Projet'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: project.coverUrl == null || project.coverUrl!.isEmpty
                      ? Container(
                          color: Colors.black12,
                          alignment: Alignment.center,
                          child: const Icon(Icons.image_outlined, size: 42),
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
              ),
              const SizedBox(height: 14),
              Text(
                project.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundImage: (project.owner?.photoUrl != null &&
                            project.owner!.photoUrl!.isNotEmpty)
                        ? NetworkImage(project.owner!.photoUrl!)
                        : null,
                    child: (project.owner?.photoUrl == null ||
                            project.owner!.photoUrl!.isEmpty)
                        ? const Icon(Icons.person, size: 16)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(ownerName),
                ],
              ),
              if (project.types.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in project.types)
                      Chip(label: Text(t), visualDensity: VisualDensity.compact),
                  ],
                ),
              ],
              if ((project.description ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  project.description!.trim(),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 16),
              _ProjectMediaSection(
                projectId: project.id,
                coverUrl: project.coverUrl,
              ),
              if (owner) ...[
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () => context.push('/my-projects/${project.id}/edit'),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editer le projet'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _deleteProject(
                    context,
                    repo: repo,
                    id: project.id,
                  ),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                  label: const Text('Supprimer le projet'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ProjectMediaSection extends StatelessWidget {
  final String projectId;
  final String? coverUrl;

  const _ProjectMediaSection({required this.projectId, required this.coverUrl});

  Stream<List<String>> _watchAllPhotoUrls() {
    return FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .collection('timeline')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
          final urls = LinkedHashSet<String>();

          final cover = (coverUrl ?? '').trim();
          if (cover.isNotEmpty) {
            urls.add(cover);
          }

          for (final doc in snap.docs) {
            final data = doc.data();
            final photoUrls = data['photoUrls'] as List<dynamic>? ?? const [];
            for (final raw in photoUrls) {
              final url = raw.toString().trim();
              if (url.isNotEmpty) {
                urls.add(url);
              }
            }
          }

          return urls.toList(growable: false);
        });
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = Theme.of(context).dividerColor.withOpacity(0.35);
    final surface = Theme.of(context).colorScheme.surface.withOpacity(0.5);

    return StreamBuilder<List<String>>(
      stream: _watchAllPhotoUrls(),
      builder: (context, snap) {
        final urls = snap.data ?? const <String>[];

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.photo_library_outlined, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Medias du projet',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Text(
                    '${urls.length}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snap.hasError)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Impossible de charger les medias.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                )
              else if (urls.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Aucune photo pour le moment.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final maxW = constraints.maxWidth;
                    final crossAxisCount = maxW >= 760
                        ? 5
                        : (maxW >= 520 ? 4 : 3);

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: urls.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 6,
                        mainAxisSpacing: 6,
                      ),
                      itemBuilder: (context, i) {
                        final url = urls[i];
                        final isCover =
                            i == 0 &&
                            (coverUrl ?? '').trim().isNotEmpty &&
                            url == coverUrl!.trim();

                        return _ProjectMediaThumb(
                          url: url,
                          isCover: isCover,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    PhotoViewer(urls: urls, initialIndex: i),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ProjectMediaThumb extends StatelessWidget {
  final String url;
  final bool isCover;
  final VoidCallback onTap;

  const _ProjectMediaThumb({
    required this.url,
    required this.isCover,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              url,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const ColoredBox(
                  color: Colors.black12,
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: Colors.black12,
                child: Center(child: Icon(Icons.broken_image_outlined)),
              ),
            ),
            if (isCover)
              Positioned(
                left: 6,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.62),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Couverture',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
