import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../models/project_model.dart';
import '../repositories/project_repository.dart';
import '../services/storage_service.dart';

class ProjectFormPage extends StatefulWidget {
  /// null => création ; sinon édition
  final String? projectId;
  const ProjectFormPage({super.key, this.projectId});

  bool get isEdit => projectId != null;

  @override
  State<ProjectFormPage> createState() => _ProjectFormPageState();
}

class _ProjectFormPageState extends State<ProjectFormPage> {
  final _tagSearchCtrl = TextEditingController();
  String _tagQuery = '';

  static const kProjectTypes = <String>[
    // 3D / fabrication
    "Impression 3D",
    "Modélisation 3D",
    "Scan 3D",
    "Résine",
    "FDM",
    "Prototype",
    "Post-traitement",

    // Arts / finition
    "Peinture",
    "Dessin",
    "Illustration",
    "Aérographe",
    "Weathering",
    "Vernis",

    // Maquettes / figurines
    "Maquette",
    "Figurine",
    "Diorama",
    "Warhammer",
    "Cosplay",

    // Bois / artisanat
    "Travail du bois",
    "Menuiserie",
    "Sculpture bois",
    "Tournage bois",

    // Métal
    "Travail du métal",
    "Soudure",
    "Forge",

    // Électronique
    "Électronique",
    "Arduino",
    "Raspberry Pi",
    "ESP32",
    "IoT",
    "Robotique",

    // CNC / fabrication
    "CNC",
    "Découpe laser",
    "Gravure laser",
    "Usinage",

    // DIY / bricolage
    "DIY",
    "Upcycling",
    "Réparation",
    "Customisation",

    // Jeux / accessoires
    "Accessoire gaming",
    "Jeu de société",
    "Terrain de jeu",

    // Maison / déco
    "Décoration",
    "Objet maison",
    "Lampe",
    "Support",

    // Modélisme
    "RC",
    "Drone",
    "Modélisme",

    // Textile
    "Couture",
    "Broderie",
    "Textile",
  ];

  final _repo = ProjectRepository();
  final _storage = StorageService();
  final _picker = ImagePicker();

  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final Set<String> _selectedTypes = {};

  bool _loading = false;
  bool _saving = false;

  Project? _project;
  String? _coverUrl; // url existante (edit)
  File? _coverFile; // nouvelle image choisie

  @override
  void initState() {
    super.initState();
    _loadIfEdit();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _tagSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadIfEdit() async {
    if (!widget.isEdit) return;
    setState(() => _loading = true);

    try {
      final p = await _repo.watchProject(widget.projectId!).first;
      if (!mounted) return;

      if (p == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Projet introuvable")));
        context.pop();
        return;
      }

      _project = p;
      _titleCtrl.text = p.title;
      _descCtrl.text = p.description ?? '';
      _coverUrl = p.coverUrl;

      _selectedTypes
        ..clear()
        ..addAll(p.types);

      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erreur: $e")));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickCover() async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x == null) return;

    setState(() {
      _coverFile = File(x.path);
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Non connecté");

      final title = _titleCtrl.text.trim();
      final desc = _descCtrl.text.trim();
      final types = _selectedTypes.toList()..sort();

      String projectId;

      if (!widget.isEdit) {
        // CREATE
        projectId = await _repo.createProject(
          ownerUid: user.uid,
          title: title,
          description: desc.isEmpty ? null : desc,
          types: types,
        );
      } else {
        projectId = widget.projectId!;
        // UPDATE texte/types (cover après)
        await _repo.updateProject(
          projectId,
          title: title,
          description: desc.isEmpty ? null : desc,
          types: types,
        );
      }

      // Upload cover si nouvelle image choisie
      if (_coverFile != null) {
        final url = await _storage.uploadProjectCover(
          projectId: projectId,
          file: _coverFile!,
        );
        await _repo.updateProject(projectId, coverUrl: url);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isEdit ? "Projet mis à jour" : "Projet créé"),
        ),
      );

      // Navigue vers le détail du projet
      context.go('/my-projects/$projectId');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erreur: $e")));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.isEdit;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? "Modifier le projet" : "Créer un projet"),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text("Enregistrer"),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  _CoverPicker(
                    coverUrl: _coverUrl,
                    coverFile: _coverFile,
                    onPick: _pickCover,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      labelText: "Titre",
                      hintText: "Ex: Boîtier Raspberry Pi",
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (s.isEmpty) return "Le titre est requis";
                      if (s.length < 3) return "Min 3 caractères";
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _descCtrl,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: "Description",
                      hintText: "Décris ton projet (optionnel)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _TypesSelectorSearchable(
                    allTypes: kProjectTypes,
                    selectedTypes: _selectedTypes,
                    searchController: _tagSearchCtrl,
                    query: _tagQuery,
                    onQueryChanged: (q) => setState(() => _tagQuery = q),
                    onToggle: (type, selected) {
                      setState(() {
                        if (selected) {
                          _selectedTypes.add(type);
                        } else {
                          _selectedTypes.remove(type);
                        }
                      });
                    },
                    onAddCustom: (tag) {
                      setState(() {
                        _selectedTypes.add(tag);
                        _tagSearchCtrl.clear();
                        _tagQuery = '';
                      });
                    },
                  ),

                  const SizedBox(height: 24),

                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save),
                    label: Text(isEdit ? "Mettre à jour" : "Créer"),
                  ),
                ],
              ),
            ),
    );
  }
}

class _TypesSelectorSearchable extends StatelessWidget {
  final List<String> allTypes;
  final Set<String> selectedTypes;

  final TextEditingController searchController;
  final String query;
  final ValueChanged<String> onQueryChanged;

  final void Function(String type, bool selected) onToggle;

  /// Optionnel: ajout d’un tag custom
  final ValueChanged<String> onAddCustom;

  const _TypesSelectorSearchable({
    required this.allTypes,
    required this.selectedTypes,
    required this.searchController,
    required this.query,
    required this.onQueryChanged,
    required this.onToggle,
    required this.onAddCustom,
  });

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();

    final filtered = q.isEmpty
        ? allTypes
        : allTypes.where((t) => t.toLowerCase().contains(q)).toList();

    final canAddCustom =
        q.isNotEmpty &&
        !allTypes.any((t) => t.toLowerCase() == q) &&
        !selectedTypes.any((t) => t.toLowerCase() == q);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Tags / types", style: Theme.of(context).textTheme.titleSmall),
        Text(
          selectedTypes.isEmpty
              ? "Optionel - Tu peux en choisir plusieurs."
              : "${selectedTypes.length} sélectionné(s)",
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),

        TextField(
          controller: searchController,
          onChanged: onQueryChanged,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: "Rechercher un tag…",
            border: const OutlineInputBorder(),
            isDense: true,
            suffixIcon: q.isEmpty
                ? null
                : IconButton(
                    tooltip: "Effacer",
                    onPressed: () {
                      searchController.clear();
                      onQueryChanged('');
                    },
                    icon: const Icon(Icons.close),
                  ),
          ),
        ),

        const SizedBox(height: 10),

        // tags sélectionnés en haut (pratique)
        if (selectedTypes.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in selectedTypes.toList()..sort())
                InputChip(label: Text(t), onDeleted: () => onToggle(t, false)),
            ],
          ),
          const SizedBox(height: 12),
        ],

        // bouton tag custom
        if (canAddCustom) ...[
          FilledButton.tonalIcon(
            onPressed: () => onAddCustom(_capitalize(query.trim())),
            icon: const Icon(Icons.add),
            label: Text('Ajouter "${_capitalize(query.trim())}"'),
          ),
          const SizedBox(height: 12),
        ],

        // presets filtrés
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in filtered)
              FilterChip(
                label: Text(t),
                selected: selectedTypes.contains(t),
                onSelected: (v) => onToggle(t, v),
              ),
          ],
        ),
      ],
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}

class _CoverPicker extends StatelessWidget {
  final String? coverUrl;
  final File? coverFile;
  final VoidCallback onPick;

  const _CoverPicker({
    required this.coverUrl,
    required this.coverFile,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    Widget image;
    if (coverFile != null) {
      image = Image.file(coverFile!, fit: BoxFit.cover);
    } else if (coverUrl != null && coverUrl!.isNotEmpty) {
      image = Image.network(coverUrl!, fit: BoxFit.cover);
    } else {
      image = Container(
        color: Colors.black12,
        alignment: Alignment.center,
        child: const Icon(Icons.image_outlined, size: 42),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Photo de couverture",
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                image,
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: FilledButton.tonalIcon(
                    onPressed: onPick,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text("Choisir"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TypesSelector extends StatelessWidget {
  final List<String> allTypes;
  final Set<String> selectedTypes;
  final void Function(String type, bool selected) onToggle;

  const _TypesSelector({
    required this.allTypes,
    required this.selectedTypes,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Types de projet", style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in allTypes)
              FilterChip(
                label: Text(t),
                selected: selectedTypes.contains(t),
                onSelected: (v) => onToggle(t, v),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          selectedTypes.isEmpty
              ? "Optionnel — tu peux en choisir plusieurs"
              : "${selectedTypes.length} sélectionné(s)",
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
