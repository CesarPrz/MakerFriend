import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../repositories/timeline_repository.dart';
import '../services/storage_service.dart';

class NewPhotoPostPage extends StatefulWidget {
  final String projectId;
  const NewPhotoPostPage({super.key, required this.projectId});

  @override
  State<NewPhotoPostPage> createState() => _NewPhotoPostPageState();
}

class _NewPhotoPostPageState extends State<NewPhotoPostPage> {
  final _titleCtrl = TextEditingController(text: "Photo update");
  final _bodyCtrl = TextEditingController();
  final _picker = ImagePicker();

  final _storage = StorageService();
  final _timelineRepo = TimelineRepository();

  File? _image;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final x = await _picker.pickImage(
      source: source,
      imageQuality: 85, // compresse un peu
      maxWidth: 2048,
    );
    if (x == null) return;
    setState(() => _image = File(x.path));
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _error = "Titre obligatoire");
      return;
    }
    if (_image == null) {
      setState(() => _error = "Choisis une image");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1) upload storage
      final url = await _storage.uploadProjectTimelineImage(
        projectId: widget.projectId,
        file: _image!,
      );

      // 2) create timeline item
      await _timelineRepo.addPost(
        projectId: widget.projectId,
        title: title,
        body: _bodyCtrl.text,
        photoUrls: [url],
      );

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
      appBar: AppBar(title: const Text("Nouveau post photo")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: "Titre"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyCtrl,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: "Texte (optionnel)"),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _loading
                      ? null
                      : () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo),
                  label: const Text("Galerie"),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _loading
                      ? null
                      : () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text("Caméra"),
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (_image != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _image!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                height: 180,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                ),
                child: const Text("Aperçu image"),
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
                    : const Icon(Icons.cloud_upload),
                label: Text(_loading ? "Upload..." : "Publier"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
