import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:multyapp_pannel/pages/user_page.dart';
import 'package:multyapp_pannel/services/api_service.dart';

void main() {
  for (final width in [490.0, 800.0]) {
    testWidgets('user panel fits at ${width.toInt()}px width', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(home: UsersPage(module: Module.clinic)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Quarterly (3 Mo)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
