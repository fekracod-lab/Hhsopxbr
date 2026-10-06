// خدمة مراقبة الاتصال وفحص الوصول الفعلي (MADAR SHOP Probe Connectivity Service)
// Pure Dart — Zero UI Dependencies

import 'dart:async';
import '../../../domain/sync/contracts/i_connectivity_service.dart';
import '../../../domain/sync/contracts/i_remote_sync_gateway.dart';
import '../../../domain/sync/enums/connectivity_state.dart';

class ProbeConnectivityService implements IConnectivityService {
  final IRemoteSyncGateway _gateway;
  final StreamController<ConnectivityState> _controller =
      StreamController<ConnectivityState>.broadcast();

  ConnectivityState _current = ConnectivityState.online;

  ProbeConnectivityService(this._gateway);

  @override
  Stream<ConnectivityState> get connectivityStream => _controller.stream;

  @override
  ConnectivityState get currentStatus => _current;

  void setStatus(ConnectivityState state) {
    if (_current != state) {
      _current = state;
      _controller.add(state);
    }
  }

  @override
  Future<bool> checkReachability() async {
    try {
      final reachable = await _gateway.probeReachability();
      final newState = reachable ? ConnectivityState.online : ConnectivityState.offline;
      setStatus(newState);
      return reachable;
    } catch (_) {
      setStatus(ConnectivityState.offline);
      return false;
    }
  }

  @override
  void dispose() {
    _controller.close();
  }
}
