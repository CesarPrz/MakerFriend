import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maker_friend/features/auth/cubit/auth_cubit.dart';
import 'package:maker_friend/features/notifications/cubit/notifications_cubit.dart';
import 'package:maker_friend/repositories/notification_repository.dart';

List<BlocProvider<dynamic>> buildBlocProviders() {
  return [
    BlocProvider<AuthCubit>(create: (_) => AuthCubit()),
    BlocProvider<NotificationsCubit>(
      create: (context) => NotificationsCubit(
        context.read<NotificationRepository>(),
      ),
    ),
  ];
}
