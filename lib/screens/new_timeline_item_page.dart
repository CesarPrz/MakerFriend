import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../repositories/timeline_repository.dart';
import '../services/storage_service.dart';

enum NewTimelineKind { post, step }

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
  NewTimelineKind _kind = NewTimelineKind.post;

  final List<File> _images = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
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
      setState(() => _error = 'Le titre est obligatoire');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final urls = <String>[];
      for (final img in _images) {
        final url = await _storage.uploadProjectTimelineImage(
          projectId: widget.projectId,
          file: img,
        );
        urls.add(url);
      }

      if (_kind == NewTimelineKind.step) {
        await _timelineRepo.addStep(
          projectId: widget.projectId,
          title: title,
          body: _bodyCtrl.text,
        );
      } else {
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
    return Scaffold(
      appBar: AppBar(title: const Text('Nouveau Post')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SegmentedButton<NewTimelineKind>(
              segments: const [
                ButtonSegment(
                  value: NewTimelineKind.post,
                  label: Text('Post'),
                  icon: Icon(Icons.chat_bubble_outline),
                ),
                ButtonSegment(
                  value: NewTimelineKind.step,
                  label: Text('Etape'),
                  icon: Icon(Icons.flag_outlined),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: _loading
                  ? null
                  : (selection) {
                      setState(() {
                        _kind = selection.first;
                        if (_kind == NewTimelineKind.step) {
                          _images.clear();
                        }
                      });
                    },
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Texte',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Titre',
                hintText: 'Ex: Petit update du jour',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyCtrl,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Details (optionnel)',
                hintText: 'Ex: avancee, blocages, prochaine etape...',
              ),
            ),
            const SizedBox(height: 16),
            if (_kind == NewTimelineKind.post) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Images (optionnel)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _pickImagesFromGallery,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Galerie'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _takePhoto,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                  ),
                  const Spacer(),
                  if (_images.isNotEmpty)
                    TextButton(
                      onPressed: _loading ? null : () => setState(_images.clear),
                      child: const Text('Tout retirer'),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (_images.isNotEmpty)
                SizedBox(
                  height: 150,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _images.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final f = _images[i];
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              f,
                              width: 150,
                              height: 150,
                              fit: BoxFit.cover,
                            ),
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
                  height: 110,
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: const Text('Apercu images'),
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
                    : Icon(
                        _kind == NewTimelineKind.post
                            ? Icons.cloud_upload
                            : Icons.flag,
                      ),
                label: Text(
                  _loading
                      ? 'Publication...'
                      : (_kind == NewTimelineKind.post
                            ? 'Publier'
                            : 'Ajouter l\'etape'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
