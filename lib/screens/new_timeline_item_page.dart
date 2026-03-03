import 'package:flutter/material.dart';
import '../repositories/timeline_repository.dart';

enum NewItemType { step, post }

class NewTimelineItemPage extends StatefulWidget {
  final String projectId;
  const NewTimelineItemPage({super.key, required this.projectId});

  @override
  State<NewTimelineItemPage> createState() => _NewTimelineItemPageState();
}

class _NewTimelineItemPageState extends State<NewTimelineItemPage> {
  final _repo = TimelineRepository();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  NewItemType _type = NewItemType.step;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  String get _titleLabel =>
      _type == NewItemType.step ? "Titre de l’étape" : "Titre du post";
  String get _hintTitle => _type == NewItemType.step
      ? "Ex: Début de modélisation"
      : "Ex: Petit update du jour";
  String get _appBarTitle =>
      _type == NewItemType.step ? "Ajouter une étape" : "Ajouter un post";

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _error = "Le titre est obligatoire");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_type == NewItemType.step) {
        await _repo.addStep(
          projectId: widget.projectId,
          title: title,
          body: _bodyCtrl.text,
        );
      } else {
        await _repo.addPost(
          projectId: widget.projectId,
          title: title,
          body: _bodyCtrl.text,
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_appBarTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SegmentedButton<NewItemType>(
              segments: const [
                ButtonSegment(
                  value: NewItemType.step,
                  label: Text("Étape"),
                  icon: Icon(Icons.flag),
                ),
                ButtonSegment(
                  value: NewItemType.post,
                  label: Text("Post"),
                  icon: Icon(Icons.chat),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) {
                setState(() => _type = s.first);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: _titleLabel,
                hintText: _hintTitle,
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyCtrl,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: "Détails (optionnel)",
                hintText: "Ex: paramètres, soucis, prochaine étape…",
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading ? null : _submit,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: Text(_loading ? "Ajout..." : "Ajouter"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
