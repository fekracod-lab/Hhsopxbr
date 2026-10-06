// عقد خدمة مراقبة الاتصال وفحص الوصول الفعلي للإنترنت (MADAR SHOP IConnectivityService)
// Pure Dart — Zero UI Dependencies

import '../enums/connectivity_state.dart';

abstract class IConnectivityService {
  Stream<ConnectivityState> get connectivityStream;
  ConnectivityState get currentStatus;
  Future<bool> checkReachability();
  void dispose();
}
