import 'package:get_it/get_it.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../data/datasources/auth_remote_data_source.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../presentation/state/auth_bloc.dart';

import '../../data/datasources/project_remote_data_source.dart';
import '../../data/repositories/project_repository_impl.dart';
import '../../domain/repositories/project_repository.dart';
import '../../presentation/state/invite_bloc.dart';
import '../../presentation/state/project_bloc.dart';

import '../../data/datasources/task_remote_data_source.dart';
import '../../data/repositories/task_repository_impl.dart';
import '../../domain/repositories/task_repository.dart';
import '../../presentation/state/task_bloc.dart';

import '../../data/datasources/message_remote_data_source.dart';
import '../../data/repositories/message_repository_impl.dart';
import '../../domain/repositories/message_repository.dart';
import '../../presentation/state/message_bloc.dart';
final sl = GetIt.instance;

Future<void> init() async {
  // ACCOUNT
  // Bloc
  sl.registerFactory(() => AuthBloc(authRepository: sl()));
  // Repository
  sl.registerLazySingleton<AuthRepository>(
        () => AuthRepositoryImpl(remoteDataSource: sl()),
  );
  // Data sources
  sl.registerLazySingleton<AuthRemoteDataSource>(
        () => AuthRemoteDataSourceImpl(firebaseAuth: sl(), firestore: sl()),
  );
  // External
  sl.registerLazySingleton(() => FirebaseAuth.instance);
  sl.registerLazySingleton(() => FirebaseFirestore.instance);

  // PROJECT
  // Bloc
  sl.registerFactory(() => ProjectBloc(projectRepository: sl()));

  // Repository
  sl.registerLazySingleton<ProjectRepository>(
        () => ProjectRepositoryImpl(remoteDataSource: sl()),
  );

  // Data Source
  sl.registerLazySingleton<ProjectRemoteDataSource>(
        () => ProjectRemoteDataSourceImpl(firestore: sl()),
  );

  //TASK
  sl.registerFactory(() => TaskBloc(taskRepository: sl()));
  sl.registerLazySingleton<TaskRepository>(() => TaskRepositoryImpl(remoteDataSource: sl()));
  sl.registerLazySingleton<TaskRemoteDataSource>(() => TaskRemoteDataSourceImpl(firestore: sl()));

  //MESSAGE
  sl.registerFactory(() => MessageBloc(messageRepository: sl()));
  sl.registerLazySingleton<MessageRepository>(() => MessageRepositoryImpl(remoteDataSource: sl()));
  sl.registerLazySingleton<MessageRemoteDataSource>(() => MessageRemoteDataSourceImpl(firestore: sl()));

  //INVITE
  sl.registerFactory(() => InviteBloc(projectRepository: sl()));
}