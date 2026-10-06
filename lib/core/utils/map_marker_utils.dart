import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapMarkerUtils {
  static BitmapDescriptor? _tealCarCache;
  static BitmapDescriptor? _pickupCache;
  static BitmapDescriptor? _dropoffCache;
  static ui.Image? _cachedMadarLogo;

  /// Loads and caches Madar Logo image from assets for pin drawing
  static Future<ui.Image?> _getMadarLogo() async {
    if (_cachedMadarLogo != null) return _cachedMadarLogo;
    try {
      final ByteData data = await rootBundle.load('assets/images/logo.png');
      final Uint8List bytes = data.buffer.asUint8List();
      final ui.Codec codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 90,
        targetHeight: 90,
      );
      final ui.FrameInfo fi = await codec.getNextFrame();
      _cachedMadarLogo = fi.image;
      return _cachedMadarLogo;
    } catch (e) {
      debugPrint(' Error loading Madar logo for map pin: $e');
      return null;
    }
  }

  /// Creates a teal car marker from the asset image or custom canvas.
  static Future<BitmapDescriptor> createTealCarMarker({double scale = 1.0}) async {
    if (_tealCarCache != null) {
      return _tealCarCache!;
    }

    try {
      final icon = await _loadFromAsset('assets/teal_car_marker.png', targetWidth: (42 * scale).toInt());
      _tealCarCache = icon;
      return icon;
    } catch (e) {
      debugPrint(' Asset car marker failed: $e');
      try {
        final icon = await _drawCarMarker(color: const Color(0xFF26A69A), scale: scale);
        _tealCarCache = icon;
        return icon;
      } catch (e2) {
        debugPrint(' Programmatic car marker also failed: $e2');
        _tealCarCache = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan);
        return _tealCarCache!;
      }
    }
  }

  /// Creates a premium pickup badge marker with Madar logo & label 'موقع الزبون'.
  static Future<BitmapDescriptor> createPickupMarker({String label = 'موقع الزبون'}) async {
    if (_pickupCache != null && label == 'موقع الزبون') {
      return _pickupCache!;
    }
    try {
      final logoImg = await _getMadarLogo();
      final icon = await _drawBadgeMarkerWithLogo(
        label: label,
        gradientColors: [const Color(0xFF00BFA5), const Color(0xFF00796B)],
        borderColor: const Color(0xFF64FFDA),
        logoImage: logoImg,
      );
      if (label == 'موقع الزبون') _pickupCache = icon;
      return icon;
    } catch (e) {
      debugPrint(' Pickup marker creation failed: $e');
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    }
  }

  /// Creates a premium destination badge marker with Madar logo & label 'موقع الوجهة'.
  static Future<BitmapDescriptor> createDestinationMarker({String label = 'موقع الوجهة'}) async {
    if (_dropoffCache != null && label == 'موقع الوجهة') {
      return _dropoffCache!;
    }
    try {
      final logoImg = await _getMadarLogo();
      final icon = await _drawBadgeMarkerWithLogo(
        label: label,
        gradientColors: [const Color(0xFFFF5252), const Color(0xFFC62828)],
        borderColor: const Color(0xFFFF8A80),
        logoImage: logoImg,
      );
      if (label == 'موقع الوجهة') _dropoffCache = icon;
      return icon;
    } catch (e) {
      debugPrint(' Destination marker creation failed: $e');
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    }
  }

  /// Creates a standalone Madar pin marker with circular logo head and pointer.
  static Future<BitmapDescriptor> createMadarPinMarker({
    required String label,
    Color pinColor = const Color(0xFF00BFA5),
  }) async {
    try {
      final logoImg = await _getMadarLogo();
      return await _drawBadgeMarkerWithLogo(
        label: label,
        gradientColors: [pinColor, _darken(pinColor, 0.15)],
        borderColor: Colors.white,
        logoImage: logoImg,
      );
    } catch (e) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    }
  }

  /// Generic car marker with any color (drawn programmatically).
  static Future<BitmapDescriptor> createCarMarker({
    required Color color,
    double scale = 1.0,
  }) async {
    try {
      return await _drawCarMarker(color: color, scale: scale);
    } catch (e) {
      debugPrint(' createCarMarker failed: $e');
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan);
    }
  }

  /// Draws a modern branded pill badge with Madar logo inside and an arrow pointer at the bottom.
  static Future<BitmapDescriptor> _drawBadgeMarkerWithLogo({
    required String label,
    required List<Color> gradientColors,
    required Color borderColor,
    ui.Image? logoImage,
  }) async {
    final double pixelRatio = 3.0;
    final double paddingX = 12 * pixelRatio;
    final double height = 40 * pixelRatio;
    final double arrowHeight = 11 * pixelRatio;
    final double arrowWidth = 14 * pixelRatio;
    final double radius = height / 2;
    final double logoDiameter = 28 * pixelRatio;

    // Measure text
    final ui.ParagraphBuilder pb = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        fontSize: 13 * pixelRatio,
        fontWeight: FontWeight.bold,
      ),
    )..pushStyle(ui.TextStyle(color: Colors.white))
     ..addText(label);

    final ui.Paragraph paragraph = pb.build()..layout(const ui.ParagraphConstraints(width: 320));
    final double textWidth = paragraph.maxIntrinsicWidth;
    final double width = textWidth + paddingX * 2 + logoDiameter + (10 * pixelRatio);

    final double totalHeight = height + arrowHeight + (8 * pixelRatio);
    final int canvasWidth = width.ceil() + (14 * pixelRatio).toInt();
    final int canvasHeight = totalHeight.ceil();

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    final double startX = (canvasWidth - width) / 2;
    final double startY = 4 * pixelRatio;

    // --- 1. Soft Shadow ---
    final Path shadowPath = Path()
      ..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(startX, startY, width, height), Radius.circular(radius)))
      ..moveTo(startX + width / 2 - arrowWidth / 2, startY + height - 2)
      ..lineTo(startX + width / 2, startY + height + arrowHeight)
      ..lineTo(startX + width / 2 + arrowWidth / 2, startY + height - 2)
      ..close();

    canvas.drawPath(
      shadowPath,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 * pixelRatio),
    );

    // --- 2. Background with Gradient ---
    final Paint fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(startX, startY),
        Offset(startX + width, startY + height),
        gradientColors,
      );

    final Path badgePath = Path()
      ..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(startX, startY, width, height), Radius.circular(radius)))
      ..moveTo(startX + width / 2 - arrowWidth / 2, startY + height - 1)
      ..lineTo(startX + width / 2, startY + height + arrowHeight)
      ..lineTo(startX + width / 2 + arrowWidth / 2, startY + height - 1)
      ..close();

    canvas.drawPath(badgePath, fillPaint);

    // --- 3. Crisp Border ---
    canvas.drawPath(
      badgePath,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 * pixelRatio,
    );

    // --- 4. Madar Logo in Circular Emblem ---
    final double logoCenterX = startX + (8 * pixelRatio) + (logoDiameter / 2);
    final double logoCenterY = startY + (height / 2);

    // White disc background for logo
    canvas.drawCircle(
      Offset(logoCenterX, logoCenterY),
      logoDiameter / 2,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(logoCenterX, logoCenterY),
      logoDiameter / 2,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 * pixelRatio,
    );

    if (logoImage != null) {
      // Draw Madar Logo inside the circle clipped
      canvas.save();
      final Path clipPath = Path()
        ..addOval(Rect.fromCircle(center: Offset(logoCenterX, logoCenterY), radius: (logoDiameter / 2) - (2 * pixelRatio)));
      canvas.clipPath(clipPath);

      final Rect srcRect = Rect.fromLTWH(0, 0, logoImage.width.toDouble(), logoImage.height.toDouble());
      final Rect dstRect = Rect.fromCircle(center: Offset(logoCenterX, logoCenterY), radius: (logoDiameter / 2) - (2 * pixelRatio));
      canvas.drawImageRect(logoImage, srcRect, dstRect, Paint()..filterQuality = FilterQuality.high);
      canvas.restore();
    } else {
      // Fallback glowing dot
      canvas.drawCircle(
        Offset(logoCenterX, logoCenterY),
        4 * pixelRatio,
        Paint()..color = const Color(0xFF004D40),
      );
    }

    // --- 5. Arabic Text ---
    final double textX = startX + (8 * pixelRatio) + logoDiameter + (8 * pixelRatio);
    final double textY = startY + (height - paragraph.height) / 2;
    canvas.drawParagraph(paragraph, Offset(textX, textY));

    // --- 6. Convert to Image ---
    final ui.Image img = await recorder.endRecording().toImage(canvasWidth, canvasHeight);
    final ByteData? byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) {
      throw Exception('Failed to render badge marker with Madar logo');
    }

    return BitmapDescriptor.bytes(
      byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
    );
  }

  /// Loads a PNG asset and resizes it for use as a map marker.
  static Future<BitmapDescriptor> _loadFromAsset(String assetPath, {int targetWidth = 80}) async {
    final ByteData data = await rootBundle.load(assetPath);
    final Uint8List bytes = data.buffer.asUint8List();

    final ui.Codec codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: targetWidth,
    );
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    final ui.Image image = frameInfo.image;

    final ByteData? pngBytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (pngBytes == null) {
      throw Exception('Failed to convert asset image to PNG bytes');
    }

    return BitmapDescriptor.bytes(
      pngBytes.buffer.asUint8List(pngBytes.offsetInBytes, pngBytes.lengthInBytes),
    );
  }

  /// Draws a premium top-down car marker programmatically using Canvas.
  static Future<BitmapDescriptor> _drawCarMarker({
    required Color color,
    double scale = 1.0,
  }) async {
    final double pixelRatio = 3.0;
    final double baseWidth = 22 * scale * pixelRatio;
    final double baseHeight = 46 * scale * pixelRatio;
    final double padding = 6 * scale * pixelRatio;

    final int canvasWidth = (baseWidth + padding * 2).ceil();
    final int canvasHeight = (baseHeight + padding * 2).ceil();

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    canvas.translate(padding, padding);

    final double w = baseWidth;
    final double h = baseHeight;
    final double s = scale * pixelRatio;

    // Shadow
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 * s);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 2 * s, w, h),
        Radius.circular(w * 0.38),
      ),
      shadowPaint,
    );

    // Car Body
    final Path carBody = Path()
      ..moveTo(w * 0.25, 0)
      ..quadraticBezierTo(w * 0.5, -2 * s, w * 0.75, 0)
      ..lineTo(w * 0.9, h * 0.15)
      ..quadraticBezierTo(w, h * 0.5, w * 0.95, h * 0.85)
      ..lineTo(w * 0.85, h)
      ..lineTo(w * 0.15, h)
      ..lineTo(w * 0.05, h * 0.85)
      ..quadraticBezierTo(0, h * 0.5, w * 0.1, h * 0.15)
      ..close();

    final Paint bodyPaint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(w, h),
        [color, _darken(color, 0.05), _darken(color, 0.2)],
        [0.0, 0.5, 1.0],
      );

    canvas.drawPath(carBody, bodyPaint);

    // White outline
    canvas.drawPath(
      carBody,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * s,
    );

    // Glass
    final double gw = w * 0.65;
    final double gx = w * 0.175;
    final Path glassPath = Path()
      ..moveTo(gx + gw * 0.2, h * 0.18)
      ..lineTo(gx + gw * 0.8, h * 0.18)
      ..lineTo(gx + gw, h * 0.3)
      ..lineTo(gx + gw, h * 0.75)
      ..lineTo(gx + gw * 0.85, h * 0.85)
      ..lineTo(gx + gw * 0.15, h * 0.85)
      ..lineTo(gx, h * 0.75)
      ..lineTo(gx, h * 0.3)
      ..close();

    canvas.drawPath(
      glassPath,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(w / 2, h * 0.2),
          Offset(w / 2, h * 0.8),
          [const Color(0xFF1A1A1A), const Color(0xFF333333), const Color(0xFF1A1A1A)],
        ),
    );

    // Windshield glare
    canvas.drawPath(
      Path()
        ..moveTo(gx + 2 * s, h * 0.22)
        ..lineTo(gx + gw - 6 * s, h * 0.22)
        ..lineTo(gx + gw - 12 * s, h * 0.32)
        ..lineTo(gx + 6 * s, h * 0.32)
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: 0.15),
    );

    // LED Headlights
    final Paint ledPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 * s);

    canvas.drawRect(Rect.fromLTWH(w * 0.15, 2 * s, w * 0.15, 3 * s), ledPaint);
    canvas.drawRect(Rect.fromLTWH(w * 0.7, 2 * s, w * 0.15, 3 * s), ledPaint);

    // Taillights
    final Paint tailPaint = Paint()..color = const Color(0xFFFF1744);
    canvas.drawRect(Rect.fromLTWH(w * 0.1, h - 3 * s, w * 0.15, 2 * s), tailPaint);
    canvas.drawRect(Rect.fromLTWH(w * 0.75, h - 3 * s, w * 0.15, 2 * s), tailPaint);

    // Side mirrors
    final Paint mirrorPaint = Paint()..color = _darken(color, 0.1);
    canvas.drawRRect(
      RRect.fromRectXY(Rect.fromLTWH(-1 * s, h * 0.25, 2.5 * s, 5 * s), 1, 1),
      mirrorPaint,
    );
    canvas.drawRRect(
      RRect.fromRectXY(Rect.fromLTWH(w - 1.5 * s, h * 0.25, 2.5 * s, 5 * s), 1, 1),
      mirrorPaint,
    );

    final ui.Image img = await recorder.endRecording().toImage(canvasWidth, canvasHeight);
    final ByteData? byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) {
      throw Exception('Failed to generate byte data for car marker');
    }

    return BitmapDescriptor.bytes(
      byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
    );
  }

  /// Darkens a color by a given amount (0.0 - 1.0).
  static Color _darken(Color color, [double amount = 0.1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }
}
