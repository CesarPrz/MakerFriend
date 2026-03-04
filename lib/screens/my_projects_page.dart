import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:maker_friend/models/project_model.dart';
import 'package:maker_friend/widgets/project_card.dart';

import '../repositories/project_repository.dart';

class MyProjectsPage extends StatefulWidget {
  const MyProjectsPage({super.key});

  @override
  State<MyProjectsPage> createState() => _MyProjectsPageState();
}

class _MyProjectsPageState extends State<MyProjectsPage> {
  final _repo = ProjectRepository();

  Future<void> _openCreateProjectDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _CreateProjectDialog(),
    );

    // rien d'autre à faire: le Stream refresh automatiquement
    if (created == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Projet créé')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text("Tu n'es pas connecté.")));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Mes Projets')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateProjectDialog,
        icon: const Icon(Icons.add),
        label: const Text('Créer un projet'),
      ),
      body: StreamBuilder<List<Project>>(
        stream: _repo.watchProjectsForOwner(user.uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Erreur: ${snap.error}'));
          }

          final projects = snap.data ?? [];
          if (projects.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  "Aucun projet pour l’instant.\nAppuie sur “Créer un projet” pour commencer.",
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, // mets 2 si tu veux une grille
              childAspectRatio: 0.85,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: projects.length,
            itemBuilder: (context, i) {
              final doc = projects[i];
              return ProjectCard(
                project: doc,
                onTap: () => context.push('/my-projects/${doc.id}'),
              );
            },
          );
        },
      ),
    );
  }
}

class _CreateProjectDialog extends StatefulWidget {
  const _CreateProjectDialog();

  @override
  State<_CreateProjectDialog> createState() => _CreateProjectDialogState();
}

class _CreateProjectDialogState extends State<_CreateProjectDialog> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  final _repo = ProjectRepository();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Le titre est obligatoire.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _repo.createProject(
        ownerUid: user.uid,
        title: title,
        description: _descCtrl.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Créer un projet'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleCtrl,
            autofocus: true,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Titre',
              hintText: 'Ex: Boîtier Raspberry Pi',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Description (optionnel)',
              hintText: 'Ex: PLA noir, 0.2mm, supports…',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _loading ? null : _create,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Créer'),
        ),
      ],
    );
  }
}
