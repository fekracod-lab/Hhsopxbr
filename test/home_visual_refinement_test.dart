import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:dalal_alqaim/features/home/widgets/madar_3d_service_graphics.dart';
import 'package:dalal_alqaim/features/home/widgets/draggable_services_row.dart';
import 'package:dalal_alqaim/core/automation/smart_assistant_fab.dart';

void main() {
  group('MADAR Home Visual & AI Refinement Tests', () {
    testWidgets('1. Madar3DServiceGraphic renders correctly for all core and quick services', (tester) async {
      final services = [
        'taxi',
        'restaurants',
        'stores',
        'mersal',
        'doctors',
        'medical',
        'real_estate',
        'jobs',
        'emergency',
        'complaints',
        'help',
        'contact',
      ];

      for (final service in services) {
        await tester.pumpWidget(
          ScreenUtilInit(
            designSize: const Size(375, 812),
            builder: (context, child) => MaterialApp(
              home: Scaffold(
                body: Center(
                  child: Madar3DServiceGraphic(
                    serviceType: service,
                    size: 80,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(Madar3DServiceGraphic), findsOneWidget);
      }
    });

    testWidgets('2. DraggableServicesRow renders all quick services smoothly', (tester) async {
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (context, child) => const MaterialApp(
            home: Scaffold(
              body: DraggableServicesRow(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DraggableServicesRow), findsOneWidget);
      expect(find.text('الوظائف'), findsOneWidget);
      expect(find.text('الشكاوي'), findsOneWidget);
      expect(find.text('الطوارئ'), findsOneWidget);
    });

    testWidgets('3. SmartAssistantFAB renders with AI neon aura and mascot framing', (tester) async {
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (context, child) => const MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  Positioned(
                    bottom: 20,
                    left: 20,
                    child: SmartAssistantFAB(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(SmartAssistantFAB), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('4. Responsive validation across multiple screen sizes (320, 360, 375, 390, 412, 600, 768)', (tester) async {
      final testSizes = [
        const Size(320, 568),
        const Size(360, 640),
        const Size(375, 812),
        const Size(390, 844),
        const Size(412, 915),
        const Size(600, 1024),
        const Size(768, 1024),
      ];

      for (final size in testSizes) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          ScreenUtilInit(
            designSize: const Size(375, 812),
            builder: (context, child) => MaterialApp(
              home: Scaffold(
                body: Directionality(
                  textDirection: TextDirection.rtl,
                  child: ListView(
                    children: const [
                      DraggableServicesRow(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull, reason: 'Zero layout overflow on width ${size.width}');
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  });
}
