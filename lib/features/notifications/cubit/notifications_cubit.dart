import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maker_friend/repositories/notification_repository.dart';

class NotificationsState {
  final int unreadCount;
  final bool loading;

  const NotificationsState({
    this.unreadCount = 0,
    this.loading = true,
  });

  NotificationsState copyWith({
    int? unreadCount,
    bool? loading,
  }) {
    return NotificationsState(
      unreadCount: unreadCount ?? this.unreadCount,
      loading: loading ?? this.loading,
    );
  }
}

class NotificationsCubit extends Cubit<NotificationsState> {
  final NotificationRepository _repository;
  StreamSubscription<int>? _sub;

  NotificationsCubit(this._repository) : super(const NotificationsState()) {
    _sub = _repository.watchUnreadCount().listen((count) {
      emit(state.copyWith(unreadCount: count, loading: false));
    });
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
