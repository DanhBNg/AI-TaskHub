import 'dart:typed_data';

import '../entities/user_entity.dart';

abstract class AuthRepository {
  Stream<UserEntity?> get authStateChanges;

  Future<UserEntity> signInWithEmail(String email, String password);

  Future<UserEntity> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
  });

  Future<void> updateProfile({
    required String fullName,
    Uint8List? avatarBytes,
  });

  Future<void> signOut();
}
