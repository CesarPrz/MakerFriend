import 'package:flutter/material.dart';
import 'package:maker_friend/models/comment_model.dart';
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

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    await _repo.addComment(
      projectId: widget.projectId,
      itemId: widget.itemId,
      body: _ctrl.text,
    );
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<CommentModel>>(
              stream: _repo.watchComments(widget.projectId, widget.itemId),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final comments = snap.data!;
                if (comments.isEmpty) {
                  return const Center(
                    child: Text("Pas encore de commentaires."),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: comments.length,
                  itemBuilder: (_, i) {
                    final c = comments[i];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          (c.authorName ?? '?').isNotEmpty
                              ? (c.authorName ?? '?')[0]
                              : '?',
                        ),
                      ),
                      title: Text(c.authorName ?? "Utilisateur"),
                      subtitle: Text(c.body),
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
                      decoration: const InputDecoration(
                        hintText: "Écrire un commentaire…",
                      ),
                    ),
                  ),
                  IconButton(onPressed: _send, icon: const Icon(Icons.send)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
