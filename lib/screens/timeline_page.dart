import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:maker_friend/models/timeline_item_model.dart';
import '../repositories/timeline_repository.dart';

class TimelinePage extends StatelessWidget {
  final String projectId;
  const TimelinePage({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) {
    final repo = TimelineRepository();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Timeline"),
        actions: [
          IconButton(
            onPressed: () => context.push('/projects/$projectId/timeline/new'),
            icon: const Icon(Icons.flag),
            tooltip: "Ajouter une étape",
          ),
        ],
      ),
      body: StreamBuilder<List<TimelineItem>>(
        stream: repo.watchTimeline(projectId),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snap.data!;
          if (items.isEmpty) {
            return const Center(
              child: Text("Aucun update. Ajoute une étape !"),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];

              return InkWell(
                onTap: () {
                  context.push(
                    '/projects/$projectId/timeline/${item.id}',
                    extra: item.title,
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch, // ✅ IMPORTANT
                      children: [
                        TimelineIndicator(
                          isFirst: i == 0,
                          isLast: i == items.length - 1,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Card(
                            child: ListTile(
                              leading: Icon(
                                item.type == TimelineItemType.step
                                    ? Icons.flag
                                    : Icons.chat_bubble_outline,
                              ),
                              title: Text(item.title),
                              subtitle:
                                  (item.body == null || item.body!.isEmpty)
                                  ? null
                                  : Text(
                                      item.body!,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                              trailing: const Icon(Icons.chevron_right),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class TimelineIndicator extends StatelessWidget {
  final bool isFirst;
  final bool isLast;

  const TimelineIndicator({
    super.key,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _LinePainter(hideTop: isFirst, hideBottom: isLast),
            ),
          ),
          Container(
            width: 14,
            height: 14,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  final bool hideTop;
  final bool hideBottom;

  _LinePainter({required this.hideTop, required this.hideBottom});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color =
          const Color(0x1F000000) // équivalent Colors.black12-ish
      ..strokeWidth = 2;

    final x = size.width / 2;
    final centerY = size.height / 2;

    // Dessine du haut -> centre, sauf si premier
    if (!hideTop) {
      canvas.drawLine(Offset(x, 0), Offset(x, centerY), paint);
    }

    // Dessine centre -> bas, sauf si dernier
    if (!hideBottom) {
      canvas.drawLine(Offset(x, centerY), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter oldDelegate) {
    return hideTop != oldDelegate.hideTop ||
        hideBottom != oldDelegate.hideBottom;
  }
}
