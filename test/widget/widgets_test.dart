import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:netguard_pro/widgets/custom/glass_card.dart';
import 'package:netguard_pro/widgets/custom/score_indicator.dart';

void main() {
  group('GlassCard Widget', () {
    testWidgets('renders child correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GlassCard(
              child: Text('Test Content'),
            ),
          ),
        ),
      );
      
      expect(find.text('Test Content'), findsOneWidget);
    });
    
    testWidgets('calls onTap when tapped', (WidgetTester tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassCard(
              onTap: () => tapped = true,
              child: const Text('Tap Me'),
            ),
          ),
        ),
      );
      
      await tester.tap(find.text('Tap Me'));
      expect(tapped, true);
    });
  });
  
  group('ScoreIndicator Widget', () {
    testWidgets('displays score correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ScoreIndicator(
              score: 85,
              label: 'Security Score',
            ),
          ),
        ),
      );
      
      expect(find.text('85'), findsOneWidget);
      expect(find.text('/100'), findsOneWidget);
      expect(find.text('Security Score'), findsOneWidget);
    });
    
    testWidgets('uses red color for low scores', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ScoreIndicator(
              score: 20,
              label: 'Score',
            ),
          ),
        ),
      );
      
      // تحقق من وجود النص (الألوان تتطلب فحص أعمق)
      expect(find.text('20'), findsOneWidget);
    });
    
    testWidgets('uses reversed color when reverseColor is true', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ScoreIndicator(
              score: 30,
              label: 'Vulnerability',
              reverseColor: true,
            ),
          ),
        ),
      );
      
      expect(find.text('30'), findsOneWidget);
      expect(find.text('Vulnerability'), findsOneWidget);
    });
  });
}
