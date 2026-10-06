import 'osrm_route_service.dart';

String stepToArabic(RouteStep s) {
  final mod = (s.modifier ?? '').toLowerCase();

  String action;
  if (s.type == 'roundabout' || s.type == 'rotary') {
    action = 'ادخل الدوّار';
  } else if (mod.contains('right')) {
    action = 'انعطف يمين';
  } else if (mod.contains('left')) {
    action = 'انعطف يسار';
  } else if (mod.contains('straight')) {
    action = 'استمر للأمام';
  } else if (mod.contains('uturn')) {
    action = 'استدر للخلف';
  } else if (mod.contains('depart')) {
    action = 'ابدأ المسار';
  } else if (mod.contains('arrive')) {
    action = 'وصلت إلى الوجهة';
  } else {
    action = 'تابع الطريق';
  }

  final street = s.name.trim().isEmpty ? '' : 'باتجاه ${s.name}';
  return '$action$street';
}

String formatDistanceMeters(double meters) {
  if (meters < 1000) return '${meters.toStringAsFixed(0)} م';
  return '${(meters / 1000).toStringAsFixed(1)} كم';
}
