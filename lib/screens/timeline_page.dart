import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:maker_friend/models/project_model.dart';
import 'package:maker_friend/models/timeline_item_model.dart';
import 'package:maker_friend/repositories/project_repository.dart';
import 'package:maker_friend/repositories/timeline_repository.dart';
import 'package:maker_friend/widgets/timeline_card.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class TimelinePage extends StatefulWidget {
  final String projectId;
  const TimelinePage({super.key, required this.projectId});

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  final _timelineRepo = TimelineRepository();
  final _projectRepo = ProjectRepository();

  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  @override
  Widget build(BuildContext context) {
    const expandedH = 240.0;
    const collapsedH = 75.0;
    final projectId = widget.projectId;

    return Scaffold(
      body: StreamBuilder<Project?>(
        stream: _projectRepo.watchProject(projectId),
        builder: (context, projectSnap) {
          final Project? project = projectSnap.data;
          if (project == null) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          return StreamBuilder<List<TimelineItem>>(
            stream: _timelineRepo.watchTimeline(projectId),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final items = snap.data ?? const <TimelineItem>[];

              return CustomScrollView(
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    stretch: true,
                    expandedHeight: expandedH,
                    collapsedHeight: collapsedH,

                    backgroundColor: Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    scrolledUnderElevation: 0,
                    elevation: 0,

                    // ❌ PAS DE title: ICI
                    actions: [
                      IconButton(
                        tooltip: 'Projet',
                        onPressed: () => context.push('/projects/$projectId'),
                        icon: const Icon(Icons.info_outline),
                      ),
                      IconButton(
                        tooltip: 'Ajouter',
                        onPressed: () => context.push(
                          '/my-projects/$projectId/timeline/new',
                        ),
                        icon: const Icon(Icons.add),
                      ),
                    ],

                    flexibleSpace: LayoutBuilder(
                      builder: (context, constraints) {
                        final h = constraints.biggest.height;

                        // t = 1 (expanded) -> 0 (collapsed)
                        final t = ((h - collapsedH) / (expandedH - collapsedH))
                            .clamp(0.0, 1.0);

                        final isCollapsed = t < 0.5;

                        // ✅ cover text: 1 -> 0, MAIS on force à 0 quand collapsed
                        final coverTextOpacity = isCollapsed ? 0.0 : t;

                        // ✅ toolbar title: visible UNIQUEMENT quand collapsed
                        final toolbarTitleOpacity = isCollapsed ? 1.0 : 0.0;

                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            _CoverImage(coverUrl: project!.coverUrl),

                            // Gradient plus faible quand collapsed pour ne pas “assombrir” la liste
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.05),
                                    Colors.black.withOpacity(0.55 * t),
                                  ],
                                ),
                              ),
                            ),

                            // Texte sur l'image (fade out)
                            Positioned(
                              left: 16,
                              right: 16,
                              bottom: 16,
                              child: IgnorePointer(
                                ignoring: coverTextOpacity == 0,
                                child: AnimatedOpacity(
                                  opacity: coverTextOpacity,
                                  duration: const Duration(milliseconds: 120),
                                  child: _CoverText(
                                    title: project!.title,
                                    description: project.description ?? "",
                                  ),
                                ),
                              ),
                            ),

                            // Titre toolbar : apparaît seulement quand collapsed
                            Positioned(
                              left: 56,
                              right: 16,
                              top: MediaQuery.of(context).padding.top,
                              height: kToolbarHeight,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: IgnorePointer(
                                  ignoring: toolbarTitleOpacity == 0,
                                  child: AnimatedOpacity(
                                    opacity: toolbarTitleOpacity,
                                    duration: const Duration(milliseconds: 120),
                                    child: Text(
                                      project!.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(color: Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    // ✅ Titre dans la “toolbar” via bottom (affiché seulement quand collapsed)
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(0),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Ici constraints vient du bottom, donc on réutilise plutôt un Builder simple:
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),

                  if (items.isEmpty)
                    const SliverFillRemaining(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            "Aucun item pour l’instant.\nAjoute une étape ou un post.",
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                      sliver: SliverList.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final item = items[i];
                          return TimelineCard(projectId: projectId, item: item);
                        },
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// Cover header avec overlay titre + description + dégradé
class _CoverHeader extends StatelessWidget {
  final String? coverUrl;
  final String title;
  final String description;

  const _CoverHeader({
    required this.coverUrl,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: coverUrl == null
              ? Container(
                  color: Colors.black12,
                  child: const Center(
                    child: Icon(Icons.image_outlined, size: 44),
                  ),
                )
              : Image.network(
                  coverUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, _, __) => Container(
                    color: Colors.black12,
                    child: const Center(
                      child: Icon(Icons.broken_image_outlined, size: 44),
                    ),
                  ),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                ),
        ),

        // dégradé pour lisibilité
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0.60)],
              ),
            ),
          ),
        ),

        // texte overlay en bas (visible en expanded)
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (description.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  description.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.92),
                    fontSize: 13,
                    height: 1.25,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StepRail extends StatelessWidget {
  final List<int> stepIndexes;
  final ItemPositionsListener itemPositionsListener;
  final void Function(int index) onTapStep;

  const _StepRail({
    required this.stepIndexes,
    required this.itemPositionsListener,
    required this.onTapStep,
  });

  int? _activeItemIndex(Iterable<ItemPosition> positions) {
    final visible = positions
        .where((p) => p.itemTrailingEdge > 0 && p.itemLeadingEdge < 1)
        .toList();
    if (visible.isEmpty) return null;

    visible.sort((a, b) {
      final aCenter = (a.itemLeadingEdge + a.itemTrailingEdge) / 2;
      final bCenter = (b.itemLeadingEdge + b.itemTrailingEdge) / 2;
      return (aCenter - 0.5).abs().compareTo((bCenter - 0.5).abs());
    });

    return visible.first.index;
  }

  @override
  Widget build(BuildContext context) {
    if (stepIndexes.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 2,
          child: DecoratedBox(decoration: BoxDecoration(color: Colors.black12)),
        ),
      );
    }

    return ValueListenableBuilder<Iterable<ItemPosition>>(
      valueListenable: itemPositionsListener.itemPositions,
      builder: (context, positions, _) {
        final activeItem = _activeItemIndex(positions);

        int? activeStep;
        if (activeItem != null) {
          activeStep = stepIndexes.reduce((a, b) {
            return (a - activeItem).abs() < (b - activeItem).abs() ? a : b;
          });
        }

        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            for (final idx in stepIndexes)
              _RailDot(
                isActive: idx == activeStep,
                onTap: () => onTapStep(idx),
              ),
          ],
        );
      },
    );
  }
}

class _RailDot extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;

  const _RailDot({required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final size = isActive ? 14.0 : 8.0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? Colors.black87 : Colors.black26,
            ),
          ),
        ),
      ),
    );
  }
}

class _CoverImage extends StatelessWidget {
  final String? coverUrl;
  const _CoverImage({required this.coverUrl});

  @override
  Widget build(BuildContext context) {
    return coverUrl == null
        ? Container(
            color: Colors.black12,
            alignment: Alignment.center,
            child: const Icon(Icons.image_outlined, size: 44),
          )
        : Image.network(
            coverUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: Colors.black12,
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image_outlined, size: 44),
            ),
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Center(child: CircularProgressIndicator());
            },
          );
  }
}

class _CoverText extends StatelessWidget {
  final String title;
  final String description;
  const _CoverText({required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (description.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            description.trim(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.92),
              fontSize: 13,
              height: 1.25,
            ),
          ),
        ],
      ],
    );
  }
}
