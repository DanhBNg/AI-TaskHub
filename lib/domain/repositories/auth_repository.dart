import '../entities/user_entity.dart';

abstract class AuthRepository {
  // trag thai user
  Stream<UserEntity?> get authStateChanges;

  Future<UserEntity> signInWithEmail(String email, String password);

  Future<UserEntity> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
  });
  
  Future<void> signOut();
}