import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dalal_alqaim/features/delivery/presentation/controller/mersal_ui_state.dart';
import 'package:dalal_alqaim/models/mersal_request.dart';
import 'package:dalal_alqaim/services/mersal_service.dart';
import 'package:dalal_alqaim/services/notification_service.dart';
import 'package:dalal_alqaim/services/cloudinary_service.dart';
import 'package:dalal_alqaim/services/taxi_background_service.dart';
import 'package:dalal_alqaim/core/location_permission_helper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'dart:async';
import 'dart:io';

class MersalController extends ChangeNotifier {
  MersalUiState _state = MersalUiState();
  MersalUiState get state => _state;

  final MersalService _mersalService = MersalService();
  final AudioRecorder _audioRecorder = AudioRecorder();
  Timer? _recordingTimer;
  String? _tempPath;

  void setStep(int step) {
    _state = _state.copyWith(currentStep: step);
    notifyListeners();
  }

  void nextStep() {
    if (_state.currentStep < 2) {
      setStep(_state.currentStep + 1);
    }
  }

  void previousStep() {
    if (_state.currentStep > 0) {
      setStep(_state.currentStep - 1);
    }
  }

  void setCategory(String category) {
    _state = _state.copyWith(selectedCategory: category);
    _checkReadiness();
  }

  void updateDescription(String desc) {
    _state = _state.copyWith(requestDescription: desc);
    _checkReadiness();
  }

  void updateStoreName(String store) {
    _state = _state.copyWith(storeName: store);
  }

  Future<void> updateScheduledTime(DateTime time) async {
    _state = _state.copyWith(scheduledTime: time);
    notifyListeners();
  }

  Future<void> pickAndUploadPrescription() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      
      _state = _state.copyWith(status: MersalViewStatus.requesting); // Re-use requesting for "Uploading"
      notifyListeners();

      final url = await CloudinaryService.uploadBytes(bytes, image.name);
      
      if (url != null) {
        _state = _state.copyWith(prescriptionPhotoUrl: url, status: MersalViewStatus.ready);
      } else {
        _state = _state.copyWith(errorMessage: 'فشل رفع الصورة', status: MersalViewStatus.ready);
      }
      notifyListeners();
    } catch (e) {
      _state = _state.copyWith(errorMessage: 'خطأ أثناء اختيار الصورة: $e', status: MersalViewStatus.ready);
      notifyListeners();
    }
  }

  // --- [NEW] Recording Logic ---
  
  // --- [NEW] Real Recording Logic ---
  
  Future<void> startRecording() async {
    if (_state.isRecording) return;
    
    try {
      if (await _audioRecorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        _tempPath = p.join(tempDir.path, 'mersal_voice_${DateTime.now().millisecondsSinceEpoch}.m4a');

        const config = RecordConfig(); // Default for AAC/m4a

        await _audioRecorder.start(config, path: _tempPath!);

        _recordingTimer?.cancel();
        _state = _state.copyWith(
          isRecording: true, 
          recordingDuration: 0,
          hasVoiceNote: false,
          errorMessage: null,
        );
        notifyListeners();

        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (_state.recordingDuration >= 60) {
            stopRecording();
          } else {
            _state = _state.copyWith(recordingDuration: _state.recordingDuration + 1);
            notifyListeners();
          }
        });
      } else {
        _state = _state.copyWith(errorMessage: 'الإذن بالوصول للميكروفون مرفوض');
        notifyListeners();
      }
    } catch (e) {
      _state = _state.copyWith(errorMessage: 'فشل بدء التسجيل: $e');
      notifyListeners();
    }
  }

  Future<void> stopRecording() async {
    if (!_state.isRecording) return;
    _recordingTimer?.cancel();
    
    try {
      final path = await _audioRecorder.stop();
      _state = _state.copyWith(isRecording: false, status: MersalViewStatus.requesting); // "Requesting" used for "Uploading" state
      notifyListeners();

      if (path != null) {
        final file = File(path);
        final bytes = await file.readAsBytes();
        
        final url = await CloudinaryService.uploadVideo(bytes, p.basename(path));
        
        if (url != null) {
          _state = _state.copyWith(
            voiceUrl: url,
            hasVoiceNote: true,
            status: MersalViewStatus.ready,
          );
        } else {
          _state = _state.copyWith(
            errorMessage: 'فشل رفع الملاحظة الصوتية',
            status: MersalViewStatus.ready,
          );
        }
      }
    } catch (e) {
      _state = _state.copyWith(errorMessage: 'خطأ في معالجة التسجيل: $e', status: MersalViewStatus.ready);
    } finally {
      _checkReadiness();
    }
  }

  Future<void> cancelRecording() async {
    _recordingTimer?.cancel();
    await _audioRecorder.stop();
    _state = _state.copyWith(
      isRecording: false,
      recordingDuration: 0,
    );
    notifyListeners();
  }

  void deleteVoiceNote() {
    _state = _state.copyWith(hasVoiceNote: false, clearVoice: true);
    _checkReadiness();
  }

  Future<void> determinePosition(BuildContext context) async {
    bool hasPermission = await LocationPermissionHelper.requestLocationPermissionWithDisclosure(context);
    if (!hasPermission) return;

    try {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
      updateLocationFromMap(LatLng(pos.latitude, pos.longitude));
    } catch (e) {
      _state = _state.copyWith(errorMessage: 'فشل تحديد الموقع: $e');
      notifyListeners();
    }
  }

  void updateLocationFromMap(LatLng location) {
    _state = _state.copyWith(dropoffLocation: location);
    // Ideally we'd reverse geocode here to get a proper address string.
    // For now, we format the lat/lng.
    _state = _state.copyWith(
      dropoffAddress: 'الموقع المحدد على الخريطة',
    );
    _checkReadiness();
  }

  void _checkReadiness() {
    bool isLocationReady = _state.dropoffLocation != null;
    bool isDescriptionReady = _state.requestDescription.isNotEmpty || _state.hasVoiceNote;
    
    bool isReady = isLocationReady && isDescriptionReady;

    if (isReady && _state.status != MersalViewStatus.requesting) {
      _state = _state.copyWith(status: MersalViewStatus.ready, clearError: true);
    } else if (!isReady && _state.status != MersalViewStatus.requesting) {
      _state = _state.copyWith(status: MersalViewStatus.idle);
    }
    notifyListeners();
  }

  Future<String?> submitRequest() async {
    if (_state.dropoffLocation == null) {
      _state = _state.copyWith(errorMessage: 'يرجى تحديد الموقع على الخريطة أولاً');
      notifyListeners();
      return null;
    }
    if (_state.requestDescription.isEmpty && !_state.hasVoiceNote) {
      _state = _state.copyWith(errorMessage: 'يرجى كتابة الطلب أو تسجيل الملاحظة الصوتية');
      notifyListeners();
      return null;
    }

    _state = _state.copyWith(status: MersalViewStatus.requesting, clearError: true);
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('يجب تسجيل الدخول أولاً');
      }

      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data() ?? {};

      final request = MersalRequest(
        id: '',
        userId: user.uid,
        userName: data['name'] ?? 'مستخدم',
        userPhone: data['phone'] ?? '',
        requestDescription: _state.requestDescription,
        storeName: _state.storeName?.isNotEmpty == true ? _state.storeName : null,
        dropoffLat: _state.dropoffLocation!.latitude,
        dropoffLng: _state.dropoffLocation!.longitude,
        dropoffAddress: _state.dropoffAddress,
        status: 'pending',
        category: _state.selectedCategory,
        voiceUrl: _state.voiceUrl,
        prescriptionPhotoUrl: _state.prescriptionPhotoUrl,
        scheduledTime: _state.scheduledTime,
        createdAt: DateTime.now(),
      );

      final requestId = await _mersalService.createRequest(request);

      try {
        await NotificationService.emitEvent(
          type: 'new_mersal_request',
          payload: {
            'requestId': requestId,
            'id': requestId,
            'storeName': request.storeName ?? '',
            'description': request.requestDescription,
            'userId': request.userId,
            'userName': request.userName,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      } catch (e) {
        debugPrint('Error emitting notification request: $e');
      }

      await TaxiBackgroundService.initialize();
      TaxiBackgroundService.sendMessage({
        'type': 'create_order',
        'orderType': 'delivery',
        'requestId': requestId,
        'description': _state.requestDescription,
        'storeName': _state.storeName,
        'location': {
          'lat': _state.dropoffLocation!.latitude,
          'lng': _state.dropoffLocation!.longitude,
          'address': _state.dropoffAddress,
        },
        'items': [{'name': _state.requestDescription}],
        'total': 0,
      });

      // Reset on success
      _state = MersalUiState();
      notifyListeners();

      return requestId;
    } catch (e) {
      _state = _state.copyWith(
        status: MersalViewStatus.ready,
        errorMessage: 'حدث خطأ: $e',
      );
      notifyListeners();
      return null;
    }
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }
}
