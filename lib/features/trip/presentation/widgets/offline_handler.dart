import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:dalal_alqaim/features/trip/presentation/trip_design.dart';

class ConnectivityService {
  final _connectivity = Connectivity();
  final _controller = StreamController<bool>.broadcast();

  Stream<bool> get isOfflineStream => _controller.stream;

  ConnectivityService() {
    _connectivity.onConnectivityChanged.listen((results) {
      _controller.add(results.contains(ConnectivityResult.none));
    });
  }

  void dispose() {
    _controller.close();
  }
}

class OfflineBanner extends StatelessWidget {
  final bool isOffline;

  const OfflineBanner({super.key, required this.isOffline});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: isOffline ? 40 : 0,
      width: double.infinity,
      color: TripDesign.error,
      child:
          isOffline
              ? const Center(
                child: Text(
                  "لا يوجد اتصال بالإنترنت - البيانات قد تكون قديمة",
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: TripDesign.kFontFamily,
                    fontSize: 12,
                  ),
                ),
              )
              : const SizedBox.shrink(),
    );
  }
}
