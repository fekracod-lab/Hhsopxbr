import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:dalal_alqaim/main.dart' as app;
import 'package:dalal_alqaim/core/automation/automation_agent.dart';
import 'package:dalal_alqaim/core/automation/ui_scanner.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Intelligent Automation Flow', (WidgetTester tester) async {
    // 1. Start the app
    app.main();
    await tester.pumpAndSettle();

    // 2. Initialize Automation Agent 
    final agent = AutomationAgent();

    String goal = "Navigate to the delivery management page and verify if there are any active drivers.";
    bool isDone = false;
    int maxSteps = 10;
    int currentStep = 0;

    debugPrint("--- Starting Intelligent Automation ---");
    debugPrint("Goal: $goal");

    while (!isDone && currentStep < maxSteps) {
      currentStep++;
      debugPrint("Step $currentStep...");

      // Scan UI
      // ignore: use_build_context_synchronously
      final BuildContext context = tester.element(find.byType(MaterialApp));
      String uiDescription = UIScanner.scan(context);

      // Get Next Action from AI
      String action = await agent.getNextAction(uiDescription, goal);
      debugPrint("AI Recommendation: $action");

      if (action.startsWith("DONE") || action.startsWith("SAY:")) {
        isDone = true;
        debugPrint("Automation finished: $action");
        break;
      }

      // Execute Action
      if (action.startsWith("CLICK:")) {
        String target = action.replaceFirst("CLICK:", "").trim();
        // Try finding by text or key
        final finder = find.textContaining(target);
        if (finder.evaluate().isNotEmpty) {
          await tester.tap(finder);
          await tester.pumpAndSettle();
        } else {
          debugPrint("Could not find target to click: $target");
        }
      } else if (action.startsWith("WAIT:")) {
        int seconds = int.tryParse(action.split(":")[1].trim()) ?? 2;
        await Future.delayed(Duration(seconds: seconds));
        await tester.pumpAndSettle();
      }
      
      // Add more action handlers as needed...
    }

    debugPrint("--- Automation Completed ---");
  });
}
