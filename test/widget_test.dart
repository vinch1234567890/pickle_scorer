// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pickle_scorer_app/scoreboard.dart';

void main() {
  group('PickleballMatch', () {
    test('starts doubles at 0-0-2 and opening side-out starts server one', () {
      const match = PickleballMatch();
      expect(match.scoreCall, '0 - 0 - 2');
      final next = match.rallyWonBy(1);
      expect(next.servingSide, 1);
      expect(next.serverNumber, 1);
      expect(next.scoreCall, '0 - 0 - 1');
    });

    test('serving side scores and the game must be won by two', () {
      var match = const PickleballMatch(homeScore: 10, awayScore: 10, serverNumber: 1, openingSequence: false);
      match = match.rallyWonBy(0);
      expect(match.homeScore, 11);
      expect(match.winner, isNull);
      match = match.rallyWonBy(0);
      expect(match.winner, 0);
      expect(match.rallyWonBy(1), same(match));
    });

    test('doubles side-out advances server before changing teams', () {
      var match = const PickleballMatch(serverNumber: 1, openingSequence: false);
      match = match.rallyWonBy(1);
      expect(match.servingSide, 0);
      expect(match.serverNumber, 2);
      match = match.rallyWonBy(1);
      expect(match.servingSide, 1);
      expect(match.serverNumber, 1);
    });

    test('singles changes serve at side-out and omits server number', () {
      const match = PickleballMatch(mode: MatchMode.singles, serverNumber: 1, openingSequence: false);
      final next = match.rallyWonBy(1);
      expect(next.servingSide, 1);
      expect(next.scoreCall, '0 - 0');
    });
  });

  testWidgets('scoreboard controls update the called score', (tester) async {
    await tester.pumpWidget(const PickleScorerApp());
    expect(find.text('0 - 0 - 2'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('rally-0')));
    await tester.tap(find.byKey(const ValueKey('rally-0')));
    await tester.pumpAndSettle();
    expect(find.text('1 - 0 - 2'), findsOneWidget);
  });
}
