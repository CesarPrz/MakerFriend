import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ProjectDetailPage extends StatelessWidget {
  final String projectId;
  const ProjectDetailPage({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Projet')),
      body: Column(
        children: [
          // Add button to navigate to timeline
          ElevatedButton(
            onPressed: () {
              // Navigate to timeline page
              context.push('/projects/$projectId/timeline/new');
            },
            child: const Text('Voir la timeline'),
          ),
          Center(child: Text('ProjectId: $projectId')),
        ],
      ),
    );
  }
}
