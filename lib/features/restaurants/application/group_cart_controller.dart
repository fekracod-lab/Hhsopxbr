import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../data/repositories/restaurant_repository.dart';
import '../domain/entities/restaurant_models.dart';
import '../domain/services/restaurant_calculator.dart';

/// متحكم السلة الجماعية وإدارة الجلسات المشتركة (Group Cart Application Controller)
class GroupCartController extends ChangeNotifier {
  final RestaurantRepository _repository;

  GroupCartController({
    required RestaurantRepository repository,
  }) : _repository = repository;

  // ─── الحالة الداخلية (Private State) ───────────────────────────────────────────
  String? _groupCartId;
  String? _hostId;
  String? _hostName;
  GroupCartEntity? _groupCart;
  bool _isActive = false;
  bool _isLoading = false;
  bool _isCreating = false;
  String? _errorMessage;

  bool _isDisposed = false;
  String? _myUid;

  // ─── إدارة التيارات والتزامن (Stream Ownership & Guards) ─────────────────────────
  StreamSubscription<GroupCartEntity?>? _groupCartSubscription;
  String? _currentStreamCode;

  // ─── الحقول العامة المقروءة فقط (Public Read-Only Getters) ──────────────────────
  String? get groupCartId => _groupCartId;
  String? get groupCartCode => _groupCartId;
  String? get hostId => _hostId;
  String? get hostName => _hostName;
  String? get groupHostName => _hostName;
  GroupCartEntity? get groupCart => _groupCart;
  bool get isActive => _isActive;
  bool get isLoading => _isLoading;
  bool get isCreating => _isCreating;
  String? get errorMessage => _errorMessage;
  bool get isDisposed => _isDisposed;
  String? get myUid => _myUid;

  /// التحقق مما إذا كان المستخدم الحالي هو مضيف السلة
  bool get isHost => _myUid != null && _hostId != null && _hostId == _myUid;

  /// معرّف السلة الفعّال المعتمد في سلة التسوق
  String get effectiveCartId {
    return RestaurantCalculator.getEffectiveCartId(
      userUid: _myUid ?? '',
      groupCartId: _isActive ? _groupCartId : null,
    );
  }

  // ─── الإجراءات والعمليات (Operations & Lifecycle) ───────────────────────────────

  /// تهيئة المتحكم بمعرف المستخدم الحالي
  Future<void> initialize({required String uid}) async {
    setMyUid(uid);
  }

  /// مغادرة السلة الجماعية
  Future<void> leaveGroupCart() => leaveOrDeactivateGroupCart();

  /// تعيين معرّف المستخدم الحالي
  void setMyUid(String uid) {
    if (_myUid == uid || _isDisposed) return;
    _myUid = uid;
    _safeNotifyListeners();
  }

  /// استعادة جلسة سلة جماعية سابقة (مثلاً من الذاكرة المحلية SharedPreferences)
  void restoreGroupCart({
    required String code,
    required String hostId,
    required String hostName,
  }) {
    if (_isDisposed || code.trim().isEmpty) return;

    _groupCartId = code;
    _hostId = hostId;
    _hostName = hostName;
    _isActive = true;
    _errorMessage = null;

    GroupCartManager.groupCartId = code;
    GroupCartManager.groupHostName = hostName;
    GroupCartManager.groupCartCode = code;

    _startWatchingGroupCart(code);
    _safeNotifyListeners();
  }

  /// إنشاء سلة جماعية جديدة برمز مكون من 5 أرقام مع قفل الإجراء لمنع التكرار (Action Lock)
  Future<String?> createGroupCart({
    required String hostId,
    required String hostName,
    String? forcedCode,
  }) async {
    if (_isDisposed || _isCreating) return null;
    _isCreating = true;
    _isLoading = true;
    _errorMessage = null;
    _safeNotifyListeners();

    try {
      final code = forcedCode ?? (10000 + math.Random().nextInt(90000)).toString();

      await _repository.createGroupCart(
        code: code,
        hostId: hostId,
        hostName: hostName,
      );

      if (_isDisposed) return null;

      _groupCartId = code;
      _hostId = hostId;
      _hostName = hostName;
      _isActive = true;
      _isLoading = false;
      _isCreating = false;

      GroupCartManager.groupCartId = code;
      GroupCartManager.groupHostName = hostName;
      GroupCartManager.groupCartCode = code;

      _startWatchingGroupCart(code);
      _safeNotifyListeners();
      return code;
    } catch (e) {
      if (_isDisposed) return null;
      _isLoading = false;
      _isCreating = false;
      _errorMessage = e.toString();
      _safeNotifyListeners();
      return null;
    }
  }

  /// الانضمام إلى سلة جماعية عبر الرمز والتأكد من فعاليتها
  Future<bool> joinGroupCart(String code) async {
    if (_isDisposed || code.trim().isEmpty) return false;
    _isLoading = true;
    _errorMessage = null;
    _safeNotifyListeners();

    try {
      final cart = await _repository.getGroupCart(code.trim());
      if (_isDisposed) return false;

      if (cart == null || !cart.active) {
        _isLoading = false;
        _errorMessage = 'السلة الجماعية غير موجودة أو تم إنهاؤها.';
        _safeNotifyListeners();
        return false;
      }

      _groupCart = cart;
      _groupCartId = cart.code;
      _hostId = cart.hostId;
      _hostName = cart.hostName;
      _isActive = true;
      _isLoading = false;

      GroupCartManager.groupCartId = cart.code;
      GroupCartManager.groupHostName = cart.hostName;
      GroupCartManager.groupCartCode = cart.code;

      _startWatchingGroupCart(cart.code);
      _safeNotifyListeners();
      return true;
    } catch (e) {
      if (_isDisposed) return false;
      _isLoading = false;
      _errorMessage = e.toString();
      _safeNotifyListeners();
      return false;
    }
  }

  /// مغادرة السلة الجماعية أو إنهاؤها إذا كان المستخدم هو المضيف
  Future<void> leaveOrDeactivateGroupCart() async {
    if (_isDisposed) return;
    final code = _groupCartId;

    if (isHost && code != null && code.isNotEmpty) {
      try {
        await _repository.deactivateGroupCart(code);
      } catch (_) {
        // Continue clearing local state defensively
      }
    }

    _clearLocalGroupState();
    _safeNotifyListeners();
  }

  /// مراقبة حالة السلة الجماعية حياً لاكتشاف إغلاقها من قبل المضيف
  void _startWatchingGroupCart(String code) {
    _groupCartSubscription?.cancel();
    _currentStreamCode = code;

    _groupCartSubscription = _repository.watchGroupCart(code).listen(
      (cart) {
        if (_isDisposed || _currentStreamCode != code) return;

        if (cart == null || !cart.active) {
          // تم إنهاء السلة من قبل المضيف
          _clearLocalGroupState();
          _safeNotifyListeners();
        } else {
          _groupCart = cart;
          _isActive = true;
          GroupCartManager.groupCartId = cart.code;
          GroupCartManager.groupHostName = cart.hostName;
          GroupCartManager.groupCartCode = cart.code;
          _safeNotifyListeners();
        }
      },
      onError: (_) {
        if (_isDisposed || _currentStreamCode != code) return;
        _clearLocalGroupState();
        _safeNotifyListeners();
      },
    );
  }

  void _clearLocalGroupState() {
    _groupCartSubscription?.cancel();
    _groupCartSubscription = null;
    _currentStreamCode = null;
    _groupCartId = null;
    _hostId = null;
    _hostName = null;
    _groupCart = null;
    _isActive = false;

    GroupCartManager.clear();
  }

  void _safeNotifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _groupCartSubscription?.cancel();
    _groupCartSubscription = null;
    _currentStreamCode = null;
    super.dispose();
  }
}
