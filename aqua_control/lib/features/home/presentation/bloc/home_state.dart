import 'package:equatable/equatable.dart';
import '../../data/models/pump_status_model.dart';

abstract class HomeState extends Equatable {
  const HomeState();
  @override
  List<Object?> get props => [];
}

class HomeInitial extends HomeState {
  const HomeInitial();
}

class HomeLoading extends HomeState {
  const HomeLoading();
}

class HomeLoaded extends HomeState {
  final PumpStatusModel status;
  final String userName;
  final String societyInfo;
  final int motorsOnline;
  final bool commandPending;
  final String? motorError;

  const HomeLoaded({
    required this.status,
    required this.userName,
    required this.societyInfo,
    required this.motorsOnline,
    this.commandPending = false,
    this.motorError,
  });

  HomeLoaded copyWith({
    PumpStatusModel? status,
    bool? commandPending,
    String? motorError,
    bool clearError = false,
  }) => HomeLoaded(
        status: status ?? this.status,
        userName: userName,
        societyInfo: societyInfo,
        motorsOnline: motorsOnline,
        commandPending: commandPending ?? this.commandPending,
        motorError: clearError ? null : (motorError ?? this.motorError),
      );

  @override
  List<Object?> get props => [status, userName, commandPending, motorError];
}

class HomeError extends HomeState {
  final String message;
  const HomeError(this.message);
  @override
  List<Object?> get props => [message];
}
