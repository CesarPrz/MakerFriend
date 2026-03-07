import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maker_friend/features/profile/cubit/profile_projects_cubit.dart';
import 'package:go_router/go_router.dart';

import '../models/app_user_model.dart';
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
    final showBack = uid != null;
    final fabHeroTag =
        'profile_create_project_fab_${showBack ? 'pushed' : 'root'}_${profileUid ?? 'none'}';

    if (profileUid == null) {
      return const Scaffold(body: Center(child: Text("Tu n'es pas connecté.")));
    }

    final isMe = me?.uid == profileUid;
    final projectRepo = context.read<ProjectRepository>();
    final userRepo = context.read<UserRepository>();

    return Scaffold(
      appBar: showBack
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.pop(),
              ),
            )
          : null,
      body: SafeArea(
        child: BlocProvider(
          create: (_) => ProfileProjectsCubit(
            projectsStream: projectRepo.watchProjectsForOwner(profileUid),
          ),
          child: Column(
            children: [
              _ProfileHeader(
                uid: profileUid,
                currentUid: me?.uid,
                isMe: isMe,
                userRepo: userRepo,
                projectRepo: projectRepo,
                onEditProfile: isMe
                    ? () => context.push('/settings/profile')
                    : null,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: BlocBuilder<ProfileProjectsCubit, ProfileProjectsState>(
                  builder: (context, state) {
                    if (state.loading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (state.error != null) {
                      return Center(child: Text('Erreur: ${state.error}'));
                    }

                    final projects = state.projects;

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
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
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
                          onTap: () =>
                              context.push('/my-projects/${p.id}/timeline'),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: isMe
          ? FloatingActionButton.extended(
              heroTag: fabHeroTag,
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
  final ProjectRepository projectRepo;
  final VoidCallback? onEditProfile;

  const _ProfileHeader({
    required this.uid,
    required this.currentUid,
    required this.isMe,
    required this.userRepo,
    required this.projectRepo,
    required this.onEditProfile,
  });

  Stream<DocumentSnapshot<Map<String, dynamic>>> _watchUserDoc() {
    return FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
  }

  Stream<int> _watchFollowingCount() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('following')
        .snapshots()
        .map((snap) => snap.size);
  }

  Stream<int> _watchFollowersCount() {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('followers')
        .snapshots()
        .map((snap) => snap.size);
  }

  Stream<int> _watchLikedProjectsCount() {
    return projectRepo.watchLikedProjectsCount(uid);
  }

  Stream<int> _watchProjectsCount() {
    return FirebaseFirestore.instance
        .collection('projects')
        .where('ownerUid', isEqualTo: uid)
        .snapshots()
        .map((snap) => snap.size);
  }

  void _openLikedProjectsSheet(BuildContext context) {
    final rootContext = context;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.75,
          child: StreamBuilder<List<Project>>(
            stream: projectRepo.watchLikedProjects(uid),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(child: Text('Erreur: ${snap.error}'));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final liked = snap.data!;
              if (liked.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      "Aucun projet like pour l'instant.",
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                itemCount: liked.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final p = liked[i];
                  return ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    tileColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerLow,
                    leading: p.coverUrl != null && p.coverUrl!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              p.coverUrl!,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Icon(Icons.image_outlined),
                    title: Text(
                      p.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      p.owner?.displayName ?? 'Maker',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.favorite, size: 16),
                        const SizedBox(width: 4),
                        Text('${p.likesCount}'),
                      ],
                    ),
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      rootContext.push('/my-projects/${p.id}/timeline');
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  void _openUsersSheet(
    BuildContext context, {
    required String title,
    required Stream<List<AppUser>> stream,
  }) {
    final rootContext = context;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.75,
          child: StreamBuilder<List<AppUser>>(
            stream: stream,
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(child: Text('Erreur: ${snap.error}'));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final users = snap.data!;
              if (users.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      '$title: aucun utilisateur.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                      itemCount: users.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final u = users[i];
                        final name = (u.displayName ?? '').trim().isEmpty
                            ? 'Maker'
                            : u.displayName!.trim();
                        return ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          tileColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerLow,
                          leading: CircleAvatar(
                            backgroundImage:
                                (u.photoUrl != null && u.photoUrl!.isNotEmpty)
                                ? NetworkImage(u.photoUrl!)
                                : null,
                            child: (u.photoUrl == null || u.photoUrl!.isEmpty)
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(name),
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            rootContext.push('/u/${u.uid}');
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _watchUserDoc(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final displayName =
            (data?['displayName'] as String?) ??
            FirebaseAuth.instance.currentUser?.displayName ??
            'Maker';

        final photoUrl =
            (data?['photoUrl'] as String?) ??
            FirebaseAuth.instance.currentUser?.photoURL;

        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: SizedBox(
                      width: 106,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ProfileAvatar(photoUrl: photoUrl),
                          const SizedBox(height: 8),
                          Text(
                            displayName,
                            style: Theme.of(context).textTheme.titleMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: StreamBuilder<int>(
                                  stream: _watchFollowingCount(),
                                  builder: (context, countSnap) {
                                    return Center(
                                      child: InkWell(
                                        onTap: () => _openUsersSheet(
                                          context,
                                          title: 'Suivis',
                                          stream: userRepo.watchFollowingUsers(
                                            uid,
                                          ),
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 4,
                                          ),
                                          child: _StatTile(
                                            label: 'Suivis',
                                            value: countSnap.data ?? 0,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              Expanded(
                                child: StreamBuilder<int>(
                                  stream: _watchFollowersCount(),
                                  builder: (context, countSnap) {
                                    if (countSnap.hasError) {
                                      return const Center(
                                        child: _StatTile(
                                          label: 'Followers',
                                          value: 0,
                                        ),
                                      );
                                    }
                                    return Center(
                                      child: InkWell(
                                        onTap: () => _openUsersSheet(
                                          context,
                                          title: 'Followers',
                                          stream: userRepo.watchFollowersUsers(
                                            uid,
                                          ),
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 4,
                                          ),
                                          child: _StatTile(
                                            label: 'Followers',
                                            value: countSnap.data ?? 0,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: StreamBuilder<int>(
                                  stream: _watchProjectsCount(),
                                  builder: (context, countSnap) {
                                    return Center(
                                      child: _StatTile(
                                        label: 'Projets',
                                        value: countSnap.data ?? 0,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              Expanded(
                                child: StreamBuilder<int>(
                                  stream: _watchLikedProjectsCount(),
                                  builder: (context, countSnap) {
                                    final count = countSnap.data ?? 0;
                                    return Center(
                                      child: InkWell(
                                        onTap: () =>
                                            _openLikedProjectsSheet(context),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 4,
                                          ),
                                          child: _StatTile(
                                            label: 'Likes',
                                            value: count,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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

class _FollowButton extends StatefulWidget {
  final String? currentUid;
  final String targetUid;
  final UserRepository userRepo;

  const _FollowButton({
    required this.currentUid,
    required this.targetUid,
    required this.userRepo,
  });

  @override
  State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton> {
  bool _busy = false;

  Future<void> _toggleFollow({
    required BuildContext context,
    required bool isFollowing,
  }) async {
    final me = widget.currentUid;
    if (me == null || _busy) return;

    setState(() => _busy = true);
    try {
      if (isFollowing) {
        await widget.userRepo.unfollowUser(
          currentUid: me,
          targetUid: widget.targetUid,
        );
      } else {
        await widget.userRepo.followUser(
          currentUid: me,
          targetUid: widget.targetUid,
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur follow: $e')));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.currentUid;
    if (me == null || me == widget.targetUid) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: double.infinity,
      child: StreamBuilder<bool>(
        stream: widget.userRepo.watchIsFollowing(
          currentUid: me,
          targetUid: widget.targetUid,
        ),
        builder: (context, snap) {
          final isFollowing = snap.data ?? false;
          final onPressed = _busy
              ? null
              : () => _toggleFollow(context: context, isFollowing: isFollowing);

          if (isFollowing) {
            return OutlinedButton.icon(
              onPressed: onPressed,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check, size: 18),
              label: const Text('Suivi'),
            );
          }

          return FilledButton.icon(
            onPressed: onPressed,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.person_add, size: 18),
            label: const Text('Suivre'),
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
      backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty)
          ? NetworkImage(photoUrl!)
          : null,
      child: (photoUrl == null || photoUrl!.isEmpty)
          ? const Icon(Icons.person, size: 36)
          : null,
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
