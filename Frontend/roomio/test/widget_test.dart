import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roomio/features/auth/presentation/pages/check_phone_page.dart';
import 'package:roomio/injection_container.dart';
import 'package:roomio/main.dart';

void main() {
  testWidgets('Unauthenticated app opens phone sign-in page', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await sl.reset();
    await initializeDependencies();
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.byType(CheckPhonePage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await sl.reset();
  });
}
