import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/pump_status_model.dart';
import '../../data/repositories/motor_repository.dart';
import 'home_event.dart';
import 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final MotorRepository _motorRepo;

  String _serialNumber = '';
  String _societyCode = '';
  String _commandBy = '';
  Timer? _pollTimer;

  HomeBloc({MotorRepository? motorRepo})
      : _motorRepo = motorRepo ?? MotorRepository(),
        super(const HomeInitial()) {
    on<LoadHomeData>(_onLoad);
    on<RefreshStatus>(_onRefresh);
    on<ToggleMotor>(_onToggleMotor);
    on<ChangeMotorMode>(_onChangeMode);
    on<SetThresholds>(_onSetThresholds);
  }

  Future<void> _onLoad(LoadHomeData event, Emitter<HomeState> emit) async {
    emit(const HomeLoading());
    _serialNumber = event.serialNumber;
    _societyCode = event.societyCode;
    _commandBy = event.commandBy;
    PumpStatusModel status;
    try {
      status = await _fetchStatus();
    } catch (_) {
      // No status recorded for this module yet — show zeroed values instead of an error screen.
      status = PumpStatusModel.empty(_serialNumber);
    }
    emit(HomeLoaded(
      status: status,
      userName: event.userName,
      societyInfo: 'Society A • Block 4',
      motorsOnline: 3,
    ));

    // Poll while this screen is open so a fresh overcurrent/undercurrent
    // alert (raised via MQTT on the backend) surfaces in the UI without
    // requiring push notification infrastructure.
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!isClosed) add(const RefreshStatus());
    });
  }

  @override
  Future<void> close() {
    _pollTimer?.cancel();
    return super.close();
  }

  Future<void> _onRefresh(RefreshStatus event, Emitter<HomeState> emit) async {
    if (state is HomeLoaded) {
      final current = state as HomeLoaded;
      try {
        final status = await _fetchStatus();
        emit(current.copyWith(status: status));
      } catch (_) {
        // Keep showing the last known status if a background refresh fails.
      }
    }
  }

  Future<PumpStatusModel> _fetchStatus() async {
    if (_serialNumber.isEmpty) return PumpStatusModel.empty(_serialNumber);
    final moduleStatus = await _motorRepo.fetchStatus(_serialNumber);
    return moduleStatus.toPumpStatus(pumpName: 'Main Pump');
  }

  Future<void> _onToggleMotor(
      ToggleMotor event, Emitter<HomeState> emit) async {
    if (state is! HomeLoaded) return;
    final current = state as HomeLoaded;
    if (current.commandPending) return;

    // Optimistic update
    final optimisticStatus = current.status.copyWith(
      motorStatus: event.turnOn ? MotorStatus.on : MotorStatus.off,
    );
    emit(current.copyWith(
        status: optimisticStatus, commandPending: true, clearError: true));

    try {
      await _motorRepo.sendCommand(
        societyCode: _societyCode,
        motorId: _serialNumber,
        serialNumber: _serialNumber,
        command: event.turnOn ? 'TURN_ON' : 'TURN_OFF',
        commandBy: _commandBy,
      );
      if (state is HomeLoaded) {
        emit((state as HomeLoaded).copyWith(commandPending: false));
      }
    } catch (e) {
      // Revert motor status on failure
      if (state is HomeLoaded) {
        emit((state as HomeLoaded).copyWith(
          status: current.status,
          commandPending: false,
          motorError: e.toString().replaceAll('Exception: ', ''),
        ));
      }
    }
  }

  Future<void> _onChangeMode(
      ChangeMotorMode event, Emitter<HomeState> emit) async {
    if (state is! HomeLoaded) return;
    final current = state as HomeLoaded;
    emit(current.copyWith(status: current.status.copyWith(mode: event.mode)));
  }

  Future<void> _onSetThresholds(
      SetThresholds event, Emitter<HomeState> emit) async {
    if (state is! HomeLoaded) return;
    final current = state as HomeLoaded;
    if (current.commandPending) return;

    // Optimistic update
    final optimisticStatus = current.status.copyWith(
      overcurrent: event.overcurrent,
      undercurrent: event.undercurrent,
    );
    emit(current.copyWith(
        status: optimisticStatus, commandPending: true, clearError: true));

    try {
      await _motorRepo.sendCommand(
        societyCode: _societyCode,
        motorId: _serialNumber,
        serialNumber: _serialNumber,
        command: 'SET_OC',
        value: event.overcurrent,
        commandBy: _commandBy,
      );
      await _motorRepo.sendCommand(
        societyCode: _societyCode,
        motorId: _serialNumber,
        serialNumber: _serialNumber,
        command: 'SET_UC',
        value: event.undercurrent,
        commandBy: _commandBy,
      );
      if (state is HomeLoaded) {
        emit((state as HomeLoaded).copyWith(commandPending: false));
      }
    } catch (e) {
      // Revert thresholds on failure
      if (state is HomeLoaded) {
        emit((state as HomeLoaded).copyWith(
          status: current.status,
          commandPending: false,
          motorError: e.toString().replaceAll('Exception: ', ''),
        ));
      }
    }
  }
}
