import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:team4tune/main.dart';

void main() {
  testWidgets('home screen shows create and join', (tester) async {
    await tester.pumpWidget(ProviderScope(child: Team4tuneApp()));
    await tester.pump();

    expect(find.text('Create room'), findsOneWidget);
    expect(find.text('Join room'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
  });
}
