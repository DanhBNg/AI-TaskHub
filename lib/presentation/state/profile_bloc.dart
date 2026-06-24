import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/auth_repository.dart';

abstract class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

class UpdateProfileRequested extends ProfileEvent {
  final String fullName;
  final Uint8List? avatarBytes;

  const UpdateProfileRequested({required this.fullName, this.avatarBytes});

  @override
  List<Object?> get props => [fullName, avatarBytes];
}

abstract class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => [];
}

class ProfileInitial extends ProfileState {}

class ProfileUpdating extends ProfileState {}

class ProfileSuccess extends ProfileState {}

class ProfileError extends ProfileState {
  final String message;

  const ProfileError(this.message);

  @override
  List<Object?> get props => [message];
}

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final AuthRepository authRepository;

  ProfileBloc({required this.authRepository}) : super(ProfileInitial()) {
    on<UpdateProfileRequested>((event, emit) async {
      emit(ProfileUpdating());
      try {
        await authRepository.updateProfile(
          fullName: event.fullName,
          avatarBytes: event.avatarBytes,
        );
        emit(ProfileSuccess());
      } catch (e) {
        emit(ProfileError(e.toString().replaceAll('Exception: ', '')));
      }
    });
  }
}
