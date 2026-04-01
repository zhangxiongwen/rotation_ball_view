import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rotation_ball_view/rotation_ball_view.dart';

void main() {
  testWidgets('RotationBallView builds', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              height: 300,
              child: RotationBallView(
                itemCount: 3,
                itemBuilder: (context, index) => Text('$index'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(RotationBallView), findsOneWidget);
  });
}
