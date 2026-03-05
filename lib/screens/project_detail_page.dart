import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:maker_friend/models/project_model.dart';
import 'package:maker_friend/repositories/project_repository.dart';
import 'package:maker_friend/services/storage_service.dart';

class ProjectDetailPage extends StatefulWidget {
  final String projectId;
  const ProjectDetailPage({super.key, required this.projectId});

  @override
  State<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage> {
  final _repo = ProjectRepository();
  final _storage = StorageService();
  final _picker = ImagePicker();

  bool _savingCover = false;

  Future<void> _editText({
    required String title,
    required String initialTitle,
    required String initialDescription,
  }) async {
    final titleCtrl = TextEditingController(text: initialTitle);
    final descCtrl = TextEditingController(text: initialDescription);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Nom du projet'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Description (optionnel)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _repo.updateProject(
        widget.projectId,
        title: titleCtrl.text,
        description: descCtrl.text,
      );
    }
  }

  Future<void> _changeCover() async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 2400,
    );
    if (x == null) return;

    setState(() => _savingCover = true);
    try {
      final url = await _storage.uploadProjectCover(
        projectId: widget.projectId,
        file: File(x.path),
      );
      await _repo.updateProject(widget.projectId, coverUrl: url);
    } finally {
      if (mounted) setState(() => _savingCover = false);
    }
  }

  bool _isOwner(Project projectData) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid != null && projectData.ownerUid == uid;
  }

  @override
  Widget build(BuildContext context) {
    final projectId = widget.projectId;

    return StreamBuilder<Project?>(
      stream: _repo.watchProject(projectId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snap.data!;
        if (data == null) {
          return const Scaffold(
            body: Center(child: Text("Projet introuvable")),
          );
        }

        final title = data.title;
        final description = data.description;
        final coverUrl = data.coverUrl;
        final owner = _isOwner(data);

        return Scaffold(
          appBar: AppBar(
            title: Text(title),
            actions: [
              IconButton(
                tooltip: 'Timeline',
                onPressed: () =>
                    context.push('/my-projects/$projectId/timeline'),
                icon: const Icon(Icons.timeline),
              ),
              if (owner)
                IconButton(
                  tooltip: 'Modifier',
                  onPressed: () => context.push('/my-projects/$projectId/edit'),
                  icon: const Icon(Icons.edit),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _CoverCard(
                coverUrl: coverUrl,
                title: title,
                saving: _savingCover,
                canEdit: owner,
                onEditCover: _changeCover,
              ),
              const SizedBox(height: 16),

              if (description != null && description.trim().isNotEmpty) ...[
                Text(
                  'Description',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  description.trim().isEmpty
                      ? 'Aucune description.'
                      : description.trim(),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () =>
                    context.push('/my-projects/$projectId/timeline'),
                icon: const Icon(Icons.timeline),
                label: const Text('Voir la timeline'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CoverCard extends StatelessWidget {
  final String? coverUrl;
  final String title;
  final String? description;
  final bool saving;
  final bool canEdit;
  final VoidCallback onEditCover;

  const _CoverCard({
    required this.coverUrl,
    required this.title,
    required this.saving,
    required this.canEdit,
    required this.onEditCover,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: coverUrl == null
                ? Container(
                    color: Colors.black12,
                    alignment: Alignment.center,
                    child: const Icon(Icons.image_outlined, size: 40),
                  )
                : Image.network(
                    coverUrl!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(child: CircularProgressIndicator());
                    },
                    errorBuilder: (context, _, __) => Container(
                      color: Colors.black12,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined, size: 40),
                    ),
                  ),
          ),

          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.50),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (description != null &&
                      description!.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      description!.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.90),
                        fontSize: 13,
                        height: 1.25,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          if (canEdit)
            Positioned(
              top: 10,
              right: 10,
              child: FilledButton.icon(
                onPressed: saving ? null : onEditCover,
                icon: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.photo_camera),
                label: Text(saving ? '...' : 'Couverture'),
              ),
            ),
        ],
      ),
    );
  }
}
