import 'package:bidvibe/screens/bidder/auction_detail_screen.dart';
import 'package:bidvibe/screens/bidder/bidder_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A ListView can discard its heading while retaining its scroll position.
/// First verify navigation/session, then scroll the real discovery list back
/// to the heading. This must not pop a route or log in on behalf of the test.
Future<void> expectDiscoveryAfterBack(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 45),
}) async {
  final home = find.byType(BidderHomeScreen);
  final detail = find.byType(AuctionDetailScreen);
  bool returned() =>
      home.evaluate().length == 1 &&
      detail.evaluate().isEmpty &&
      ModalRoute.of(tester.element(home))?.isCurrent == true;

  final deadline = DateTime.now().add(timeout);
  while (!returned() && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  expect(
    returned(),
    isTrue,
    reason: 'Back must close auction details and reveal the current bidder '
        'discovery route. Visible home=${home.evaluate().length}, '
        'detail=${detail.evaluate().length}, '
        'loginFields=${find.byType(TextFormField).evaluate().length}.',
  );

  final scrollable = find
      .descendant(
        of: home,
        matching: find.byType(Scrollable),
      )
      .first;
  final heading = find.descendant(
    of: home,
    matching: find.text('Khám phá phiên đấu giá'),
  );
  await tester.scrollUntilVisible(
    heading,
    -200,
    scrollable: scrollable,
    maxScrolls: 30,
    duration: const Duration(milliseconds: 100),
  );
  await tester.pump(const Duration(milliseconds: 300));
  expect(heading, findsOneWidget);
  expect(detail, findsNothing);
}
