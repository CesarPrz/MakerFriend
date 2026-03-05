import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/project_model.dart';
import '../repositories/project_repository.dart';
import '../widgets/project_card.dart';

class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = ProjectRepository();

    return Scaffold(
      appBar: AppBar(title: const Text('Découvrir')),
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
                  "Aucun projet à découvrir pour l’instant.",
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          // Grille compacte 2 colonnes
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: projects.length,
            itemBuilder: (context, i) {
              final project = projects[i];

              return ProjectCard(
                project: project,
                onTap: () {
                  // ✅ si tu as ajouté l’alias /projects/:projectId
                  // context.push('/projects/${project.id}');

                  // ✅ sinon (selon ton router actuel)
                },
              );
            },
          );
        },
      ),
    );
  }
}
