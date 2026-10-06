import 'dart:async';
import 'package:app_links/app_links.dart';

class DeepLinkService {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  bool _isAuthReady = false;
  Uri? _pendingUri;
  Uri? _lastHandledUri;
  void Function(Uri uri)? _onLinkReceived;

  // Initialize early to catch the cold-start link
  void init(void Function(Uri uri) onLinkReceived) {
    _onLinkReceived = onLinkReceived;

    // أثناء تشغيل التطبيق
    _sub = _appLinks.uriLinkStream.listen((uri) {
      if (_lastHandledUri == uri) return; // Prevent parsing same URI twice
      _handleUri(uri);
    });
  }

  // A Future to get the cold-start link directly
  Future<Uri?> getInitialUri() async {
    final uri = await _appLinks.getInitialAppLink();
    if (uri != null) {
      _lastHandledUri = uri; // Track that we handled it natively on boot
    }
    return uri;
  }

  void _handleUri(Uri uri) {
    _lastHandledUri = uri;
    if (_isAuthReady && _onLinkReceived != null) {
      _onLinkReceived!(uri);
    } else {
      // Save it until auth is ready
      _pendingUri = uri;
    }
  }

  // Call this from StartupScreen after determining the start page
  void notifyAuthReady() {
    _isAuthReady = true;
    if (_pendingUri != null && _onLinkReceived != null) {
      _onLinkReceived!(_pendingUri!);
      _pendingUri = null; // process only once
    }
  }

  void dispose() {
    _sub?.cancel();
  }
}
