import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:maker_friend/models/timeline_item_model.dart';
import 'package:maker_friend/screens/timeline_page.dart';

class TimelineCard extends StatelessWidget {
  final String projectId;
  final TimelineItem item;

  const TimelineCard({super.key, required this.projectId, required this.item});

  @override
  Widget build(BuildContext context) {
    final isStep = item.type == TimelineItemType.step;
    final icon = isStep ? Icons.flag : Icons.chat_bubble_outline;

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
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon),
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

              // Footer (auteur/date) - optionnel
              _MetaRow(
                authorName: item.authorName,
                createdAt: item.createdAt,
                isStep: isStep,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String? authorName;
  final DateTime? createdAt;
  final bool isStep;

  const _MetaRow({
    required this.authorName,
    required this.createdAt,
    required this.isStep,
  });

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];

    if (authorName != null && authorName!.trim().isNotEmpty) {
      parts.add(authorName!.trim());
    }
    if (createdAt != null) {
      final d = createdAt!;
      final hh = d.hour.toString().padLeft(2, '0');
      final mm = d.minute.toString().padLeft(2, '0');
      parts.add('${d.day}/${d.month} ${hh}:${mm}');
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.black12),
          ),
          child: Text(isStep ? 'Étape' : 'Post'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            parts.isEmpty ? '' : parts.join(' • '),
            style: Theme.of(context).textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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

    // 2+ photos : mini grille horizontale scrollable
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

/// Viewer simple plein écran (swipe si plusieurs)
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
