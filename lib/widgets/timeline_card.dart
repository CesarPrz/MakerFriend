import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:maker_friend/models/timeline_item_model.dart';
import 'package:maker_friend/screens/timeline_page.dart';
import 'package:maker_friend/utils/relative_time.dart';

class TimelineCard extends StatelessWidget {
  final String projectId;
  final TimelineItem item;
  final String? authorNameOverride;

  const TimelineCard({
    super.key,
    required this.projectId,
    required this.item,
    this.authorNameOverride,
  });

  @override
  Widget build(BuildContext context) {
    final isStep = item.type == TimelineItemType.step;
    if (isStep) {
      return _StepDividerTile(
        title: item.title,
        onTap: () {
          context.push(
            '/my-projects/$projectId/timeline/${item.id}',
            extra: item.title,
          );
        },
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          context.push(
            '/my-projects/$projectId/timeline/${item.id}',
            extra: item.title,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.chat_bubble_outline),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              if (item.body != null && item.body!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  item.body!.trim(),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              if (item.photoUrls.isNotEmpty) ...[
                const SizedBox(height: 12),
                _PhotoSection(urls: item.photoUrls),
              ],
              const SizedBox(height: 10),
              _MetaRow(
                projectId: projectId,
                itemId: item.id,
                authorName: authorNameOverride ?? item.authorName,
                createdAt: item.createdAt,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String projectId;
  final String itemId;
  final String? authorName;
  final DateTime? createdAt;

  const _MetaRow({
    required this.projectId,
    required this.itemId,
    required this.authorName,
    required this.createdAt,
  });

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (authorName != null && authorName!.trim().isNotEmpty) {
      parts.add(authorName!.trim());
    }
    if (createdAt != null) {
      parts.add(formatRelativeTime(createdAt));
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.black12),
          ),
          child: const Text('Post'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            parts.isEmpty ? '' : parts.join(' - '),
            style: Theme.of(context).textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        _CommentCount(projectId: projectId, itemId: itemId),
      ],
    );
  }
}

class _CommentCount extends StatelessWidget {
  final String projectId;
  final String itemId;

  const _CommentCount({required this.projectId, required this.itemId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .collection('timeline')
          .doc(itemId)
          .collection('comments')
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return const SizedBox.shrink();
        final count = snap.data?.docs.length ?? 0;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mode_comment_outlined, size: 16),
            const SizedBox(width: 4),
            Text('$count', style: Theme.of(context).textTheme.bodySmall),
          ],
        );
      },
    );
  }
}

class _StepDividerTile extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _StepDividerTile({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final orange = Theme.of(context).colorScheme.secondary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Row(
              children: [
                Expanded(
                  child: Divider(color: orange, thickness: 1.2),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.5),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      title,
                      maxLines: 3,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.labelLarge?.copyWith(color: orange),
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(color: orange, thickness: 1.2),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PhotoSection extends StatelessWidget {
  final List<String> urls;
  const _PhotoSection({required this.urls});

  @override
  Widget build(BuildContext context) {
    if (urls.length == 1) {
      return _OnePhoto(url: urls.first);
    }

    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          return _Thumb(url: urls[i], allUrls: urls, index: i);
        },
      ),
    );
  }
}

class _OnePhoto extends StatelessWidget {
  final String url;
  const _OnePhoto({required this.url});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PhotoViewer(urls: [url], initialIndex: 0),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Center(child: CircularProgressIndicator());
            },
            errorBuilder: (context, _, __) {
              return Container(
                color: Colors.black12,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String url;
  final List<String> allUrls;
  final int index;

  const _Thumb({required this.url, required this.allUrls, required this.index});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PhotoViewer(urls: allUrls, initialIndex: index),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 1,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return const Center(child: CircularProgressIndicator());
            },
            errorBuilder: (context, _, __) {
              return Container(
                color: Colors.black12,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined),
              );
            },
          ),
        ),
      ),
    );
  }
}

class PhotoViewer extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;

  const PhotoViewer({super.key, required this.urls, this.initialIndex = 0});

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.urls.length,
        itemBuilder: (context, i) {
          final url = widget.urls[i];
          return InteractiveViewer(
            child: Center(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const CircularProgressIndicator();
                },
                errorBuilder: (context, _, __) {
                  return const Icon(Icons.broken_image, color: Colors.white);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

