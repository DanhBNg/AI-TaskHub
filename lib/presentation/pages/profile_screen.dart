import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

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
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Hiển thị tên hiện tại lên ô nhập liệu
    _nameController.text = currentUser?.displayName ?? '';
  }

  // Hàm chọn ảnh từ máy
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _selectedImageBytes = bytes;
      });
    }
  }

  // Hàm lưu thông tin lên Firebase
  Future<void> _updateProfile() async {
    if (_nameController.text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      String? newPhotoUrl = currentUser?.photoURL;

      // 1. Nếu có chọn ảnh mới, up lên Storage trước
      if (_selectedImageBytes != null) {
        final fileName = 'avatar_${currentUser!.uid}.jpg';
        final ref = FirebaseStorage.instance.ref().child('avatars/$fileName');

        await ref.putData(_selectedImageBytes!, SettableMetadata(contentType: 'image/jpeg'));
        newPhotoUrl = await ref.getDownloadURL();
      }

      // 2. Cập nhật thông tin trên Firebase Auth
      await currentUser!.updateDisplayName(_nameController.text.trim());
      if (newPhotoUrl != null) {
        await currentUser!.updatePhotoURL(newPhotoUrl);
      }

      // 3. Đồng bộ tên và avatar sang bảng USERS trên Firestore
      await FirebaseFirestore.instance.collection('USERS').doc(currentUser!.uid).update({
        'fullName': _nameController.text.trim(),
        'avatarUrl': newPhotoUrl,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cập nhật thành công!'), backgroundColor: Colors.green));
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thông tin cá nhân')),
      drawer: const AppDrawer(currentIndex: 2),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Khu vực hiển thị và chọn Avatar
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage: _selectedImageBytes != null
                        ? MemoryImage(_selectedImageBytes!) // Hiển thị ảnh vừa chọn
                        : (currentUser?.photoURL != null ? NetworkImage(currentUser!.photoURL!) : null) as ImageProvider?,
                    child: (_selectedImageBytes == null && currentUser?.photoURL == null)
                        ? const Icon(Icons.person, size: 60, color: Colors.grey)
                        : null,
                  ),
                  IconButton(
                    onPressed: _pickImage,
                    icon: const CircleAvatar(
                      backgroundColor: Colors.blueAccent,
                      radius: 18,
                      child: Icon(Icons.camera_alt, size: 20, color: Colors.white),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 32),

              // Ô nhập Tên hiển thị
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Tên hiển thị',
                  prefixIcon: const Icon(Icons.badge),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 32),

              // Nút Lưu thay đổi
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateProfile,
                  style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Lưu Thay Đổi', style: TextStyle(fontSize: 16)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}