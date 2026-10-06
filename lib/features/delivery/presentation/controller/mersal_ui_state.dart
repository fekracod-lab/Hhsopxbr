import 'package:google_maps_flutter/google_maps_flutter.dart';

enum MersalViewStatus {
  idle,
  selectingLocation,
  recordingVoice,
  requesting,
  ready
}

class MersalUiState {
  final MersalViewStatus status;
  final String? errorMessage;
  
  // Locations
  final LatLng? dropoffLocation;
  final String dropoffAddress;
  
  // Order Details
  final String selectedCategory; // pharmacy, supermarket, restaurant, other
  final String requestDescription;
  final String? storeName;
  final String? voiceUrl;
  final String? prescriptionPhotoUrl;
  final DateTime? scheduledTime;
  final int currentStep; // 0: Location/Service, 1: Details/Media, 2: Schedule/Submit
  final bool isRecording;
  final int recordingDuration; // in seconds
  final bool hasVoiceNote;

  MersalUiState({
    this.status = MersalViewStatus.idle,
    this.errorMessage,
    this.dropoffLocation,
    this.dropoffAddress = '',
    this.selectedCategory = 'other',
    this.requestDescription = '',
    this.storeName,
    this.voiceUrl,
    this.prescriptionPhotoUrl,
    this.scheduledTime,
    this.currentStep = 0,
    this.isRecording = false,
    this.recordingDuration = 0,
    this.hasVoiceNote = false,
  });

  MersalUiState copyWith({
    MersalViewStatus? status,
    String? errorMessage,
    bool clearError = false,
    LatLng? dropoffLocation,
    String? dropoffAddress,
    String? selectedCategory,
    String? requestDescription,
    String? storeName,
    String? voiceUrl,
    bool clearVoice = false,
    String? prescriptionPhotoUrl,
    DateTime? scheduledTime,
    int? currentStep,
    bool clearPhoto = false,
    bool clearSchedule = false,
    bool? isRecording,
    int? recordingDuration,
    bool? hasVoiceNote,
  }) {
    return MersalUiState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      dropoffLocation: dropoffLocation ?? this.dropoffLocation,
      dropoffAddress: dropoffAddress ?? this.dropoffAddress,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      requestDescription: requestDescription ?? this.requestDescription,
      storeName: storeName ?? this.storeName,
      voiceUrl: clearVoice ? null : (voiceUrl ?? this.voiceUrl),
      prescriptionPhotoUrl: clearPhoto ? null : (prescriptionPhotoUrl ?? this.prescriptionPhotoUrl),
      scheduledTime: clearSchedule ? null : (scheduledTime ?? this.scheduledTime),
      currentStep: currentStep ?? this.currentStep,
      isRecording: isRecording ?? this.isRecording,
      recordingDuration: recordingDuration ?? this.recordingDuration,
      hasVoiceNote: hasVoiceNote ?? this.hasVoiceNote,
    );
  }
}
