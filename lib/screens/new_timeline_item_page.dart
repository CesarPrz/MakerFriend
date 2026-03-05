import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../repositories/timeline_repository.dart';
import '../services/storage_service.dart';

enum NewItemType { step, post, photoPost }

class NewTimelineItemPage extends StatefulWidget {
  final String projectId;
  const NewTimelineItemPage({super.key, required this.projectId});

  @override
  State<NewTimelineItemPage> createState() => _NewTimelineItemPageState();
}

class _NewTimelineItemPageState extends State<NewTimelineItemPage> {
  final _timelineRepo = TimelineRepository();
  final _storage = StorageService();
  final _picker = ImagePicker();

  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  NewItemType _type = NewItemType.step;

  final List<File> _images = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  String get _appBarTitle {
    switch (_type) {
      case NewItemType.step:
        return "Ajouter une étape";
      case NewItemType.post:
        return "Ajouter un post";
      case NewItemType.photoPost:
        return "Nouveau post photo";
    }
  }

  String get _titleLabel {
    switch (_type) {
      case NewItemType.step:
        return "Titre de l’étape";
      case NewItemType.post:
      case NewItemType.photoPost:
        return "Titre du post";
    }
  }

  String get _hintTitle {
    switch (_type) {
      case NewItemType.step:
        return "Ex: Début de modélisation";
      case NewItemType.post:
      case NewItemType.photoPost:
        return "Ex: Petit update du jour";
    }
  }

  Future<void> _pickImagesFromGallery() async {
    final xs = await _picker.pickMultiImage(imageQuality: 85, maxWidth: 2048);
    if (xs.isEmpty) return;

    setState(() {
      _images.addAll(xs.map((x) => File(x.path)));
    });
  }

  Future<void> _takePhoto() async {
    final x = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 2048,
    );
    if (x == null) return;

    setState(() {
      _images.add(File(x.path));
    });
  }

  Future<void> _submit() async {
    if (_loading) return;

    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _error = "Le titre est obligatoire");
      return;
    }

    if (_type == NewItemType.photoPost && _images.isEmpty) {
      setState(() => _error = "Choisis au moins une image");
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_type == NewItemType.step) {
        await _timelineRepo.addStep(
          projectId: widget.projectId,
          title: title,
          body: _bodyCtrl.text,
        );
      } else if (_type == NewItemType.post) {
        await _timelineRepo.addPost(
          projectId: widget.projectId,
          title: title,
          body: _bodyCtrl.text,
        );
      } else {
        // photo post
        final urls = <String>[];
        for (final img in _images) {
          final url = await _storage.uploadProjectTimelineImage(
            projectId: widget.projectId,
            file: img,
          );
          urls.add(url);
        }

        await _timelineRepo.addPost(
          projectId: widget.projectId,
          title: title,
          body: _bodyCtrl.text,
          photoUrls: urls,
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
    final isPhoto = _type == NewItemType.photoPost;

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
                ButtonSegment(
                  value: NewItemType.photoPost,
                  label: Text("Photo"),
                  icon: Icon(Icons.photo_camera),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) {
                setState(() {
                  _type = s.first;
                  _error = null;
                  // Option: reset image quand on quitte Photo
                  if (_type != NewItemType.photoPost) _images.clear();
                });
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

            if (isPhoto) ...[
              const SizedBox(height: 12),

              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _pickImagesFromGallery,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text("Galerie"),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _takePhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Caméra"),
                  ),
                  const Spacer(),
                  if (_images.isNotEmpty)
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => setState(() => _images.clear()),
                      child: const Text("Tout retirer"),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              const SizedBox(height: 12),

              if (_images.isNotEmpty)
                SizedBox(
                  height: 220,
                  child: GridView.builder(
                    scrollDirection: Axis.horizontal,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                    itemCount: _images.length,
                    itemBuilder: (context, i) {
                      final f = _images[i];
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(f, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: InkWell(
                              onTap: _loading
                                  ? null
                                  : () => setState(() => _images.removeAt(i)),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
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
                  child: const Text("Aperçu images"),
                ),
            ],

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
                    : Icon(isPhoto ? Icons.cloud_upload : Icons.add),
                label: Text(
                  _loading
                      ? (isPhoto ? "Upload..." : "Ajout...")
                      : (isPhoto ? "Publier" : "Ajouter"),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
