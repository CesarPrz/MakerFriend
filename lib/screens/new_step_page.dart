import 'package:flutter/material.dart';
import '../repositories/timeline_repository.dart';

class NewStepPage extends StatefulWidget {
  final String projectId;
  const NewStepPage({super.key, required this.projectId});

  @override
  State<NewStepPage> createState() => _NewStepPageState();
}

class _NewStepPageState extends State<NewStepPage> {
  final _repo = TimelineRepository();
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _error = "Titre obligatoire");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _repo.addStep(
        projectId: widget.projectId,
        title: title,
        body: _bodyCtrl.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ajouter une étape")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: "Titre",
                hintText: "Ex: Début de modélisation",
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyCtrl,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: "Détails (optionnel)",
                hintText: "Ex: Je commence sur Fusion 360...",
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const Spacer(),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text("Ajouter"),
            ),
          ],
        ),
      ),
    );
  }
}
