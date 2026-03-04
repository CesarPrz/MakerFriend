import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/project_model.dart';

class ProjectCard extends StatelessWidget {
  final Project project;
  final VoidCallback? onTap;

  const ProjectCard({super.key, required this.project, this.onTap});

  @override
  Widget build(BuildContext context) {
    final owner = project.owner;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CoverImage(url: project.coverUrl),

            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// TITLE
                  Text(
                    project.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),

                  const SizedBox(height: 10),

                  /// OWNER + FOLLOWERS
                  Row(
                    children: [
                      _Avatar(url: owner?.photoUrl),

                      const SizedBox(width: 8),

                      Expanded(
                        child: Text(
                          owner?.displayName ?? "Maker",
                          style: Theme.of(context).textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      Row(
                        children: [
                          const Icon(Icons.star_border, size: 32),
                          const SizedBox(width: 4),
                          Text(
                            project.followersCount.toString(),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  /// UPDATED DATE
                  Row(
                    children: [
                      const Icon(Icons.update, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(project.lastTimelineUpdate),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return "—";

    final diff = DateTime.now().difference(date);

    if (diff.inMinutes < 1) return "à l’instant";
    if (diff.inMinutes < 60) return "il y a ${diff.inMinutes} min";
    if (diff.inHours < 24) return "il y a ${diff.inHours} h";
    if (diff.inDays < 7) return "il y a ${diff.inDays} j";

    return "${date.day}/${date.month}/${date.year}";
  }
}

class _CoverImage extends StatelessWidget {
  final String? url;

  const _CoverImage({this.url});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: url == null
          ? Container(
              color: Colors.black12,
              alignment: Alignment.center,
              child: const Icon(Icons.image_outlined),
            )
          : Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.black12,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? url;

  const _Avatar({this.url});

  @override
  Widget build(BuildContext context) {
    if (url == null) {
      return const CircleAvatar(
        radius: 16,
        child: Icon(Icons.person, size: 18),
      );
    }

    return CircleAvatar(radius: 16, backgroundImage: NetworkImage(url!));
  }
}
