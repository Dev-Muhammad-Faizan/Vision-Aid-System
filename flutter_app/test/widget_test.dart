import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vision_aid_glasses_app/providers/glasses_provider.dart';
import 'package:vision_aid_glasses_app/screens/home_screen.dart';

void main() {
  testWidgets('HomeScreen renders without errors', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => GlassesProvider(),
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    expect(find.text('Vision-Aid Glasses'), findsOneWidget);
  });
}
