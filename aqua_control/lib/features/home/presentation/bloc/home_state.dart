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

  const HomeLoaded({
    required this.status,
    required this.userName,
    required this.societyInfo,
    required this.motorsOnline,
  });

  HomeLoaded copyWith({PumpStatusModel? status}) => HomeLoaded(
        status: status ?? this.status,
        userName: userName,
        societyInfo: societyInfo,
        motorsOnline: motorsOnline,
      );

  @override
  List<Object?> get props => [status, userName];
}

class HomeError extends HomeState {
  final String message;
  const HomeError(this.message);
  @override
  List<Object?> get props => [message];
}
