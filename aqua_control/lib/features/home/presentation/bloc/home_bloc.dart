import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/pump_status_model.dart';
import 'home_event.dart';
import 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc() : super(const HomeInitial()) {
    on<LoadHomeData>(_onLoad);
    on<RefreshStatus>(_onRefresh);
    on<ToggleMotor>(_onToggleMotor);
    on<ChangeMotorMode>(_onChangeMode);
  }

  Future<void> _onLoad(LoadHomeData event, Emitter<HomeState> emit) async {
    emit(const HomeLoading());
    try {
      await Future.delayed(const Duration(milliseconds: 600));
      emit(HomeLoaded(
        status: PumpStatusModel.mock,
        userName: 'Navin',
        societyInfo: 'Society A • Block 4',
        motorsOnline: 3,
      ));
    } catch (e) {
      emit(HomeError(e.toString()));
    }
  }

  Future<void> _onRefresh(RefreshStatus event, Emitter<HomeState> emit) async {
    if (state is HomeLoaded) {
      final current = state as HomeLoaded;
      await Future.delayed(const Duration(milliseconds: 400));
      emit(current.copyWith(status: PumpStatusModel.mock));
    }
  }

  Future<void> _onToggleMotor(ToggleMotor event, Emitter<HomeState> emit) async {
    if (state is! HomeLoaded) return;
    final current = state as HomeLoaded;
    final newStatus = current.status.copyWith(
      motorStatus: event.turnOn ? MotorStatus.on : MotorStatus.off,
    );
    emit(current.copyWith(status: newStatus));
    // TODO: send command to device via API/MQTT
  }

  Future<void> _onChangeMode(ChangeMotorMode event, Emitter<HomeState> emit) async {
    if (state is! HomeLoaded) return;
    final current = state as HomeLoaded;
    emit(current.copyWith(status: current.status.copyWith(mode: event.mode)));
  }
}
