import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:maker_friend/repositories/project_repository.dart';
import 'package:maker_friend/repositories/user_repository.dart';

import '../models/project_model.dart';
import '../models/app_user_model.dart';
import '../widgets/project_card.dart';

class SearchPage extends StatefulWidget {
  final UserRepository userRepo;
  final ProjectRepository projectRepo;
  const SearchPage({
    super.key,
    required this.userRepo,
    required this.projectRepo,
  });

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _ctrl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _queryLower => _q.trim().toLowerCase();

  @override
  Widget build(BuildContext context) {
    final q = _queryLower;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          autofocus: false,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Rechercher des projets et des makers…',
            border: InputBorder.none,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: q.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _ctrl.clear();
                      setState(() => _q = '');
                    },
                    icon: const Icon(Icons.close),
                  ),
          ),
          onChanged: (v) => setState(() => _q = v),
        ),
      ),
      body: q.isEmpty
          ? const _EmptySearchHint()
          : _CombinedResults(queryLower: q),
    );
  }
}

class _EmptySearchHint extends StatelessWidget {
  const _EmptySearchHint();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          "Tape un mot-clé pour rechercher partout.\n\nEx: “impression”, “Arduino”, “Alice”…",
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _CombinedResults extends StatelessWidget {
  final String queryLower;
  const _CombinedResults({required this.queryLower});

  Query<Map<String, dynamic>> _projectQuery() {
    final db = FirebaseFirestore.instance;
    final ref = db.collection('projects');

    return ref
        .orderBy('titleLower')
        .startAt([queryLower])
        .endAt(['$queryLower\uf8ff'])
        .limit(20);
  }

  Query<Map<String, dynamic>> _userQuery() {
    final db = FirebaseFirestore.instance;
    final ref = db.collection('users');

    return ref
        .orderBy('displayNameLower')
        .startAt([queryLower])
        .endAt(['$queryLower\uf8ff'])
        .limit(20);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _projectQuery().snapshots(),
      builder: (context, projectSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _userQuery().snapshots(),
          builder: (context, userSnap) {
            if (projectSnap.hasError) {
              return Center(child: Text('Erreur projets: ${projectSnap.error}'));
            }
            if (userSnap.hasError) {
              return Center(child: Text('Erreur makers: ${userSnap.error}'));
            }

            final loading = !projectSnap.hasData || !userSnap.hasData;
            if (loading) {
              return const Center(child: CircularProgressIndicator());
            }

            final projects = projectSnap.data!.docs.map(Project.fromDoc).toList();
            final users = userSnap.data!.docs
                .map((d) => AppUser.fromFirestore(d))
                .toList();

            if (projects.isEmpty && users.isEmpty) {
              return const Center(
                child: Text('Aucun résultat trouvé pour cette recherche.'),
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              children: [
                _SectionHeader(
                  icon: Icons.folder_outlined,
                  title: 'Projets',
                  count: projects.length,
                ),
                const SizedBox(height: 8),
                if (projects.isEmpty)
                  const _EmptySectionMessage(message: 'Aucun projet trouvé.')
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.78,
                        ),
                    itemCount: projects.length,
                    itemBuilder: (context, i) {
                      final p = projects[i];
                      return ProjectCard(
                        project: p,
                        onTap: () => context.push('/my-projects/${p.id}'),
                      );
                    },
                  ),
                const SizedBox(height: 24),
                _SectionHeader(
                  icon: Icons.person_outline,
                  title: 'Makers',
                  count: users.length,
                ),
                const SizedBox(height: 8),
                if (users.isEmpty)
                  const _EmptySectionMessage(message: 'Aucun maker trouvé.')
                else
                  ...users.map(
                    (u) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage:
                              (u.photoUrl != null && u.photoUrl!.isNotEmpty)
                              ? NetworkImage(u.photoUrl!)
                              : null,
                          child: (u.photoUrl == null || u.photoUrl!.isEmpty)
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        title: Text(u.displayName ?? 'Maker'),
                        subtitle: Text(u.uid),
                        onTap: () => context.push('/u/${u.uid}'),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Text(
          '$title ($count)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}

class _EmptySectionMessage extends StatelessWidget {
  final String message;

  const _EmptySectionMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message),
    );
  }
}
