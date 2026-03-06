import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/project_model.dart';
import '../repositories/project_repository.dart';

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
              if (owner) ...[
                const SizedBox(height: 20),
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
