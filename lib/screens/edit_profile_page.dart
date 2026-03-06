import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../models/app_user_model.dart';
import '../repositories/user_repository.dart';
import '../services/storage_service.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _nameCtrl = TextEditingController();
  final _picker = ImagePicker();
  final _storage = StorageService();

  File? _pickedImage;
  bool _saving = false;
  bool _initialized = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (x == null) return;
    setState(() => _pickedImage = File(x.path));
  }

  Future<void> _save({
    required User user,
    required UserRepository userRepo,
    required String currentPhotoUrl,
  }) async {
    final displayName = _nameCtrl.text.trim();
    if (displayName.isEmpty) return;

    setState(() => _saving = true);
    try {
      var photoUrl = currentPhotoUrl;
      if (_pickedImage != null) {
        photoUrl = await _storage.uploadUserAvatar(
          uid: user.uid,
          file: _pickedImage!,
        );
      }

      await user.updateDisplayName(displayName);
      if (photoUrl.isNotEmpty) {
        await user.updatePhotoURL(photoUrl);
      }

      await userRepo.updateUser(user.uid, {
        'displayName': displayName,
        'photoUrl': photoUrl.isEmpty ? null : photoUrl,
      });

      if (!mounted) return;
      context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Tu n'es pas connecte.")),
      );
    }

    final userRepo = context.read<UserRepository>();

    return Scaffold(
      appBar: AppBar(title: const Text('Modifier le profil')),
      body: StreamBuilder<AppUser?>(
        stream: userRepo.watchUser(user.uid),
        builder: (context, snap) {
          final appUser = snap.data;
          final displayName = (appUser?.displayName ?? user.displayName ?? '').trim();
          final photoUrl = (appUser?.photoUrl ?? user.photoURL ?? '').trim();

          if (!_initialized) {
            _initialized = true;
            _nameCtrl.text = displayName;
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 52,
                      backgroundImage: _pickedImage != null
                          ? FileImage(_pickedImage!)
                          : (photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null),
                      child: (_pickedImage == null && photoUrl.isEmpty)
                          ? const Icon(Icons.person, size: 44)
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: FilledButton(
                        onPressed: _saving ? null : _pickImage,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(40, 40),
                          padding: EdgeInsets.zero,
                          shape: const CircleBorder(),
                        ),
                        child: const Icon(Icons.camera_alt, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _nameCtrl,
                enabled: !_saving,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Nom',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving
                    ? null
                    : () => _save(
                          user: user,
                          userRepo: userRepo,
                          currentPhotoUrl: photoUrl,
                        ),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Enregistrer'),
              ),
            ],
          );
        },
      ),
    );
  }
}
