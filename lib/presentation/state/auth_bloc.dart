import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';

// events
abstract class AuthEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class LoginRequested extends AuthEvent {
  final String email;
  final String password;
  LoginRequested(this.email, this.password);
}

class SignUpRequested extends AuthEvent {
  final String email;
  final String password;
  final String fullName;
  SignUpRequested(this.email, this.password, this.fullName);
}

// state
abstract class AuthState extends Equatable {
  @override
  List<Object> get props => [];
}

class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}
class Authenticated extends AuthState {
  final UserEntity user;
  Authenticated(this.user);
}
class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}

//bloc
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;

  AuthBloc({required this.authRepository}) : super(AuthInitial()) {
    on<LoginRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        final user = await authRepository.signInWithEmail(event.email, event.password);
        emit(Authenticated(user));
      } catch (e) {
        emit(AuthError(e.toString().replaceAll('Exception: ', '')));
      }
    });

    on<SignUpRequested>((event, emit) async {
      emit(AuthLoading());
      try {

        final user = await authRepository.signUpWithEmail(
            email: event.email,
            password: event.password,
            fullName: event.fullName
        );
        emit(Authenticated(user));
      } catch (e) {
        emit(AuthError(e.toString().replaceAll('Exception: ', '')));
      }
    });
  }
}