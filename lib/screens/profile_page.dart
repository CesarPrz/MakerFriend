import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../models/project_model.dart';
import '../repositories/project_repository.dart';
import '../repositories/user_repository.dart';
import '../widgets/project_card.dart';

class ProfilePage extends StatelessWidget {
  final String? uid; // null => mon profil

  const ProfilePage({super.key, this.uid});

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser;
    final profileUid = uid ?? me?.uid;

    if (profileUid == null) {
      return const Scaffold(body: Center(child: Text("Tu n'es pas connecté.")));
    }

    final isMe = me?.uid == profileUid;
    final projectRepo = context.read<ProjectRepository>();
    final userRepo = context.read<UserRepository>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _ProfileHeader(
              uid: profileUid,
              currentUid: me?.uid,
              isMe: isMe,
              userRepo: userRepo,
              onEditProfile: isMe ? () => context.push('/settings') : null,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<List<Project>>(
                stream: projectRepo.watchProjectsForOwner(profileUid),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(child: Text('Erreur: ${snap.error}'));
                  }

                  final projects = snap.data ?? [];

                  if (projects.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          isMe
                              ? "Aucun projet pour l’instant.\nAppuie sur “Créer un projet” pour commencer."
                              : "Aucun projet pour l’instant.",
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.70,
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
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: isMe
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/my-projects/new'),
              icon: const Icon(Icons.add),
              label: const Text('Créer un projet'),
            )
          : null,
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String uid;
  final String? currentUid;
  final bool isMe;
  final UserRepository userRepo;
  final VoidCallback? onEditProfile;

  const _ProfileHeader({
    required this.uid,
    required this.currentUid,
    required this.isMe,
    required this.userRepo,
    required this.onEditProfile,
  });

  Stream<DocumentSnapshot<Map<String, dynamic>>> _watchUserDoc() {
    return FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _watchUserDoc(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final displayName =
            (data?['displayName'] as String?) ?? FirebaseAuth.instance.currentUser?.displayName ?? 'Maker';

        final photoUrl = (data?['photoUrl'] as String?) ?? FirebaseAuth.instance.currentUser?.photoURL;

        final projectsCount = null;
        final followingCount = (data?['followingCount'] as int?) ?? 0;
        final followersCount = (data?['followersCount'] as int?) ?? 0;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _ProfileAvatar(photoUrl: photoUrl),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _StatTile(label: 'Projets', value: projectsCount),
                        _StatTile(label: 'Suivis', value: followingCount),
                        _StatTile(label: 'Followers', value: followersCount),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(displayName, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              if (isMe)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onEditProfile,
                    child: const Text('Modifier le profil'),
                  ),
                )
              else
                _FollowButton(
                  currentUid: currentUid,
                  targetUid: uid,
                  userRepo: userRepo,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _FollowButton extends StatelessWidget {
  final String? currentUid;
  final String targetUid;
  final UserRepository userRepo;

  const _FollowButton({
    required this.currentUid,
    required this.targetUid,
    required this.userRepo,
  });

  @override
  Widget build(BuildContext context) {
    final me = currentUid;
    if (me == null || me == targetUid) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: double.infinity,
      child: StreamBuilder<bool>(
        stream: userRepo.watchIsFollowing(currentUid: me, targetUid: targetUid),
        builder: (context, snap) {
          final isFollowing = snap.data ?? false;

          return FilledButton(
            onPressed: () async {
              if (isFollowing) {
                await userRepo.unfollowUser(currentUid: me, targetUid: targetUid);
              } else {
                await userRepo.followUser(currentUid: me, targetUid: targetUid);
              }
            },
            child: Text(isFollowing ? 'Suivi' : 'Suivre'),
          );
        },
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final String? photoUrl;
  const _ProfileAvatar({this.photoUrl});

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surfaceVariant;

    return CircleAvatar(
      radius: 38,
      backgroundColor: bg,
      backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty) ? NetworkImage(photoUrl!) : null,
      child: (photoUrl == null || photoUrl!.isEmpty) ? const Icon(Icons.person, size: 36) : null,
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final int? value;

  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final v = value ?? 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$v', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
