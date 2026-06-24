import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Stream<User?> get authStateChanges;

  Future<UserModel> signInWithEmail(String email, String password);

  Future<UserModel> signUpWithEmail(
    String email,
    String password,
    String fullName,
  );

  Future<void> updateProfile({
    required String fullName,
    Uint8List? avatarBytes,
  });

  Future<void> signOut();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final FirebaseAuth firebaseAuth;
  final FirebaseFirestore firestore;

  AuthRemoteDataSourceImpl({
    required this.firebaseAuth,
    required this.firestore,
  });

  @override
  Stream<User?> get authStateChanges => firebaseAuth.authStateChanges();

  @override
  Future<UserModel> signInWithEmail(String email, String password) async {
    final userCredential = await firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final doc = await firestore
        .collection('USERS')
        .doc(userCredential.user!.uid)
        .get();

    if (doc.exists) {
      return UserModel.fromFirestore(doc);
    } else {
      throw Exception(
        'Không tìm thấy thông tin người dùng trong cơ sở dữ liệu',
      );
    }
  }

  @override
  Future<UserModel> signUpWithEmail(
    String email,
    String password,
    String fullName,
  ) async {
    final userCredential = await firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await userCredential.user!.updateDisplayName(fullName);
    final newUser = UserModel(
      id: userCredential.user!.uid,
      email: email,
      fullName: fullName,
    );

    await firestore.collection('USERS').doc(newUser.id).set(newUser.toJson());

    return newUser;
  }

  @override
  Future<void> updateProfile({
    required String fullName,
    Uint8List? avatarBytes,
  }) async {
    final currentUser = firebaseAuth.currentUser;
    if (currentUser == null) {
      throw Exception('Người dùng chưa đăng nhập.');
    }

    String? newPhotoUrl = currentUser.photoURL;

    if (avatarBytes != null) {
      final fileName = 'avatar_${currentUser.uid}.jpg';
      final ref = FirebaseStorage.instance.ref().child('avatars/$fileName');

      await ref.putData(
        avatarBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      newPhotoUrl = await ref.getDownloadURL();
    }

    await currentUser.updateDisplayName(fullName.trim());
    if (newPhotoUrl != null) {
      await currentUser.updatePhotoURL(newPhotoUrl);
    }

    await firestore.collection('USERS').doc(currentUser.uid).update({
      'fullName': fullName.trim(),
      'avatarUrl': newPhotoUrl,
    });
  }

  @override
  Future<void> signOut() async {
    await firebaseAuth.signOut();
  }
}
