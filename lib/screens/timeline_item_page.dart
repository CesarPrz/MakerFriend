import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:maker_friend/models/comment_model.dart';
import 'package:maker_friend/models/timeline_item_model.dart';
import 'package:maker_friend/screens/timeline_page.dart';
import 'package:maker_friend/utils/relative_time.dart';
import 'package:maker_friend/widgets/timeline_card.dart';

import '../repositories/timeline_repository.dart';

class TimelineItemPage extends StatefulWidget {
  final String projectId;
  final String itemId;
  final String title;

  const TimelineItemPage({
    super.key,
    required this.projectId,
    required this.itemId,
    required this.title,
  });

  @override
  State<TimelineItemPage> createState() => _TimelineItemPageState();
}

class _TimelineItemPageState extends State<TimelineItemPage> {
  final _repo = TimelineRepository();
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await _repo.addComment(
        projectId: widget.projectId,
        itemId: widget.itemId,
        body: _ctrl.text,
      );
      _ctrl.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Stream<TimelineItem?> _watchItem() {
    return FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.projectId)
        .collection('timeline')
        .doc(widget.itemId)
        .snapshots()
        .map((doc) {
          if (!doc.exists || doc.data() == null) return null;
          return TimelineItem.fromDoc(doc);
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<TimelineItem?>(
              stream: _watchItem(),
              builder: (context, itemSnap) {
                if (!itemSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final item = itemSnap.data;
                if (item == null) {
                  return const Center(child: Text('Post introuvable.'));
                }

                return StreamBuilder<List<CommentModel>>(
                  stream: _repo.watchComments(widget.projectId, widget.itemId),
                  builder: (context, commentSnap) {
                    if (!commentSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final comments = commentSnap.data!;
                    return ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        _PostFullCard(projectId: widget.projectId, item: item),
                        const SizedBox(height: 12),
                        Text(
                          'Commentaires (${comments.length})',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        if (comments.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.black12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text('Pas encore de commentaires.'),
                          )
                        else
                          ...comments.map((c) => _CommentTile(comment: c)),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      minLines: 1,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Ecrire un commentaire...',
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PostFullCard extends StatelessWidget {
  final String projectId;
  final TimelineItem item;

  const _PostFullCard({required this.projectId, required this.item});

  @override
  Widget build(BuildContext context) {
    final isStep = item.type == TimelineItemType.step;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(isStep ? Icons.flag : Icons.chat_bubble_outline),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            if (item.body != null && item.body!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(item.body!.trim()),
            ],
            if (item.photoUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 220,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: item.photoUrls.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final url = item.photoUrls[i];
                    return GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PhotoViewer(
                              urls: item.photoUrls,
                              initialIndex: i,
                            ),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AspectRatio(
                          aspectRatio: 4 / 3,
                          child: Image.network(
                            url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.black12,
                              alignment: Alignment.center,
                              child: const Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(_metaLine(item), style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  String _metaLine(TimelineItem item) {
    final parts = <String>[
      item.type == TimelineItemType.step ? 'Etape' : 'Post',
    ];
    if ((item.authorName ?? '').trim().isNotEmpty) {
      parts.add(item.authorName!.trim());
    }
    if (item.createdAt != null) {
      parts.add(formatRelativeTime(item.createdAt));
    }
    return parts.join(' - ');
  }
}

class _CommentTile extends StatelessWidget {
  final CommentModel comment;

  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    final name = (comment.authorName ?? '').trim().isEmpty
        ? 'Utilisateur'
        : comment.authorName!.trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: GestureDetector(
          onTap: () => context.push('/u/${comment.authorUid}'),
          child: CircleAvatar(
            backgroundImage: (comment.authorPhotoUrl ?? '').isNotEmpty
                ? NetworkImage(comment.authorPhotoUrl!)
                : null,
            child: (comment.authorPhotoUrl ?? '').isNotEmpty
                ? null
                : Text(name[0].toUpperCase()),
          ),
        ),
        title: GestureDetector(
          onTap: () => context.push('/u/${comment.authorUid}'),
          child: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(comment.body),
            if (comment.createdAt != null) ...[
              const SizedBox(height: 4),
              Text(
                _dateLabel(comment.createdAt!),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _dateLabel(DateTime d) {
    return formatRelativeTime(d);
  }
}
