import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../state/profile_bloc.dart';
import '../theme/app_theme.dart';
import '../widgets/app_drawer.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final TextEditingController _nameController = TextEditingController();

  Uint8List? _selectedImageBytes;

  @override
  void initState() {
    super.initState();
    _nameController.text = currentUser?.displayName ?? '';
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _selectedImageBytes = bytes;
      });
    }
  }

  Future<void> _submitProfileUpdate() async {
    if (_nameController.text.trim().isEmpty) return;

    final bloc = context.read<ProfileBloc>();
    final resultFuture = bloc.stream.firstWhere(
      (state) => state is ProfileSuccess || state is ProfileError,
    );

    bloc.add(
      UpdateProfileRequested(
        fullName: _nameController.text.trim(),
        avatarBytes: _selectedImageBytes,
      ),
    );

    final result = await resultFuture;
    if (!mounted) return;

    if (result is ProfileSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cập nhật thành công!'),
          backgroundColor: AppColors.success,
        ),
      );
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      return;
    }

    if (result is ProfileError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: ${result.message}'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<ProfileBloc>().state is ProfileUpdating;

    return Scaffold(
      appBar: AppBar(title: const Text('Thông tin cá nhân')),
      drawer: const AppDrawer(currentIndex: 3),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.border),
                              ),
                              child: CircleAvatar(
                                radius: 60,
                                backgroundColor: AppColors.surfaceAlt,
                                backgroundImage: _selectedImageBytes != null
                                    ? MemoryImage(_selectedImageBytes!)
                                    : (currentUser?.photoURL != null
                                              ? NetworkImage(
                                                  currentUser!.photoURL!,
                                                )
                                              : null)
                                          as ImageProvider?,
                                child:
                                    (_selectedImageBytes == null &&
                                        currentUser?.photoURL == null)
                                    ? const Icon(
                                        Icons.person,
                                        size: 60,
                                        color: AppColors.muted,
                                      )
                                    : null,
                              ),
                            ),
                            IconButton.filled(
                              tooltip: 'Đổi ảnh đại diện',
                              onPressed: isLoading ? null : _pickImage,
                              icon: const Icon(Icons.camera_alt_outlined),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Hồ sơ của bạn',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Tên hiển thị',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: isLoading ? null : _submitProfileUpdate,
                          icon: isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: const Text('Lưu thay đổi'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
