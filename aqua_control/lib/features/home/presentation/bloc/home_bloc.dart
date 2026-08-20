import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/pump_status_model.dart';
import '../../data/repositories/motor_repository.dart';
import 'home_event.dart';
import 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final MotorRepository _motorRepo;

  String _productCode = '';
  String _societyCode = '';
  String _commandBy = '';
  Timer? _pollTimer;
  // GET /module-status/:productCode now blocks server-side for up to 15s
  // while it pings the device for a heartbeat, so a fetch already in flight
  // (initial load or a poll tick) fully covers the "is it online" wait —
  // guards against a new poll tick piling another 15s request on top of one
  // that hasn't returned yet.
  bool _fetching = false;

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
    _productCode = event.productCode;
    _societyCode = event.societyCode;
    _commandBy = event.commandBy;
    PumpStatusModel status;
    _fetching = true;
    try {
      status = await _fetchStatus();
    } catch (e, st) {
      // Surface the real cause (timeout vs 404 vs parse error vs connection
      // error) instead of silently zeroing — a bare 404 (no status row yet)
      // is expected here, anything else means the fetch itself failed.
      debugPrint('HomeBloc._onLoad: fetchStatus failed for $_productCode: $e');
      debugPrintStack(stackTrace: st);
      status = PumpStatusModel.empty(_productCode);
    } finally {
      _fetching = false;
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
    // A fetch already in flight (initial load, or a previous tick that's
    // still waiting on the device) can itself take up to 30s — skip the
    // *automatic* poll tick rather than pile another one on top of it.
    // A user-initiated pull-to-refresh (force: true) always goes through
    // instead — silently dropping it just because a background poll
    // happened to still be running is what made refresh look broken.
    if (_fetching && !event.force) return;
    if (state is HomeLoaded) {
      final current = state as HomeLoaded;
      _fetching = true;
      try {
        final status = await _fetchStatus();
        emit(current.copyWith(status: status));
      } catch (e) {
        // Keep showing the last known status if a background refresh fails.
        debugPrint('HomeBloc._onRefresh: fetchStatus failed for $_productCode: $e');
      } finally {
        _fetching = false;
      }
    }
  }

  Future<PumpStatusModel> _fetchStatus() async {
    if (_productCode.isEmpty) return PumpStatusModel.empty(_productCode);
    final moduleStatus = await _motorRepo.fetchStatus(_productCode);
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
        motorId: _productCode,
        productCode: _productCode,
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

    // 'schedule' has no backend support yet - stays a purely local UI
    // toggle, same as before this method sent anything over the network.
    if (event.mode == MotorMode.schedule) {
      emit(current.copyWith(status: current.status.copyWith(mode: event.mode)));
      return;
    }

    if (current.commandPending) return;

    // Optimistic update - reverted below if the backend rejects it (e.g.
    // "your module doesn't support auto mode" for a manual_controlled
    // device), same pattern as _onToggleMotor/_onSetThresholds.
    final optimisticStatus = current.status.copyWith(mode: event.mode);
    emit(current.copyWith(
        status: optimisticStatus, commandPending: true, clearError: true));

    try {
      await _motorRepo.sendCommand(
        societyCode: _societyCode,
        motorId: _productCode,
        productCode: _productCode,
        command: 'SET_MODE',
        mode: event.mode == MotorMode.auto ? 'auto' : 'manual',
        commandBy: _commandBy,
      );
      if (state is HomeLoaded) {
        emit((state as HomeLoaded).copyWith(commandPending: false));
      }
    } catch (e) {
      if (state is HomeLoaded) {
        emit((state as HomeLoaded).copyWith(
          status: current.status,
          commandPending: false,
          motorError: e.toString().replaceAll('Exception: ', ''),
        ));
      }
    }
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
        motorId: _productCode,
        productCode: _productCode,
        command: 'SET_OC',
        value: event.overcurrent,
        commandBy: _commandBy,
      );
      await _motorRepo.sendCommand(
        societyCode: _societyCode,
        motorId: _productCode,
        productCode: _productCode,
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
