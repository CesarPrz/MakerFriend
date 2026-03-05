import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:maker_friend/repositories/project_repository.dart';
import 'package:maker_friend/repositories/user_repository.dart';

import '../models/project_model.dart';
import '../models/app_user_model.dart';
import '../widgets/project_card.dart';

enum SearchTab { projects, users }

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
  SearchTab _tab = SearchTab.projects;

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
            hintText: _tab == SearchTab.projects
                ? 'Rechercher un projet…'
                : 'Rechercher un maker…',
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: SegmentedButton<SearchTab>(
              segments: const [
                ButtonSegment(
                  value: SearchTab.projects,
                  icon: Icon(Icons.folder_outlined),
                  label: Text('Projets'),
                ),
                ButtonSegment(
                  value: SearchTab.users,
                  icon: Icon(Icons.person_outline),
                  label: Text('Makers'),
                ),
              ],
              selected: {_tab},
              onSelectionChanged: (s) {
                setState(() => _tab = s.first);
              },
            ),
          ),
        ),
      ),
      body: q.isEmpty
          ? const _EmptySearchHint()
          : _tab == SearchTab.projects
          ? _ProjectResults(queryLower: q)
          : _UserResults(queryLower: q),
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
          "Tape un mot-clé pour rechercher.\n\nEx: “impression”, “Arduino”…",
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// --------- PROJECT SEARCH (prefix) ----------
class _ProjectResults extends StatelessWidget {
  final String queryLower;
  const _ProjectResults({required this.queryLower});

  Query<Map<String, dynamic>> _query() {
    final db = FirebaseFirestore.instance;
    final ref = db.collection('projects');

    // Requête prefix: titleLower startsWith queryLower
    return ref
        .orderBy('titleLower')
        .startAt([queryLower])
        .endAt(['$queryLower\uf8ff'])
        .limit(50);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _query().snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Erreur: ${snap.error}'));
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text("Aucun projet trouvé."));
        }

        // ⚠️ Ici on construit Project sans owner hydraté (si tu veux owner, on branchera ton ProjectRepository)
        final projects = docs.map(Project.fromDoc).toList();

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
        );
      },
    );
  }
}

/// --------- USER SEARCH (prefix) ----------
class _UserResults extends StatelessWidget {
  final String queryLower;
  const _UserResults({required this.queryLower});

  Query<Map<String, dynamic>> _query() {
    final db = FirebaseFirestore.instance;
    final ref = db.collection('users');

    return ref
        .orderBy('displayNameLower')
        .startAt([queryLower])
        .endAt(['$queryLower\uf8ff'])
        .limit(50);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _query().snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Erreur: ${snap.error}'));
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text("Aucun maker trouvé."));
        }

        final users = docs.map((d) => AppUser.fromFirestore(d)).toList();

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: users.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final u = users[i];
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: (u.photoUrl != null && u.photoUrl!.isNotEmpty)
                    ? NetworkImage(u.photoUrl!)
                    : null,
                child: (u.photoUrl == null || u.photoUrl!.isEmpty)
                    ? const Icon(Icons.person)
                    : null,
              ),
              title: Text(u.displayName ?? 'Maker'),
              subtitle: Text(u.uid),
              onTap: () {
                // plus tard : page profil autre user
                context.push('/u/${u.uid}');
              },
            );
          },
        );
      },
    );
  }
}
