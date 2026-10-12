// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pickle_scorer_app/match_storage.dart';
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
      var match = const PickleballMatch(
        homeScore: 10,
        awayScore: 10,
        serverNumber: 1,
        openingSequence: false,
      );
      match = match.rallyWonBy(0);
      expect(match.homeScore, 11);
      expect(match.winner, isNull);
      match = match.rallyWonBy(0);
      expect(match.winner, 0);
      expect(match.rallyWonBy(1), same(match));
    });

    test('doubles side-out advances server before changing teams', () {
      var match = const PickleballMatch(
        serverNumber: 1,
        openingSequence: false,
      );
      match = match.rallyWonBy(1);
      expect(match.servingSide, 0);
      expect(match.serverNumber, 2);
      match = match.rallyWonBy(1);
      expect(match.servingSide, 1);
      expect(match.serverNumber, 1);
    });

    test('singles changes serve at side-out and omits server number', () {
      const match = PickleballMatch(
        mode: MatchMode.singles,
        serverNumber: 1,
        openingSequence: false,
      );
      final next = match.rallyWonBy(1);
      expect(next.servingSide, 1);
      expect(next.scoreCall, '0 - 0');
    });

    test('win-by-one ends a tied game and increments the series score', () {
      var match = const PickleballMatch(
        target: 11,
        homeScore: 10,
        awayScore: 10,
        serverNumber: 1,
        openingSequence: false,
        bestOfThree: true,
        winByOne: true,
      );
      match = match.rallyWonBy(0);
      expect(match.gameWinner, 0);
      expect(match.homeGames, 1);
      expect(match.winner, isNull);
    });

    test('best of three completes after two game wins', () {
      var match = const PickleballMatch(
        target: 11,
        homeScore: 10,
        serverNumber: 1,
        openingSequence: false,
        bestOfThree: true,
      ).rallyWonBy(0);
      expect(match.homeGames, 1);
      expect(match.winner, isNull);

      match = match
          .nextGame()
          .copyWith(
            homeScore: 10,
            servingSide: 0,
            serverNumber: 1,
            openingSequence: false,
          )
          .rallyWonBy(0);
      expect(match.homeGames, 2);
      expect(match.winner, 0);
    });

    test('tracks doubles server by player and signals the end change', () {
      var match = const PickleballMatch(
        homeScore: 5,
        serverNumber: 1,
        openingSequence: false,
        homePlayerOne: 'Ava',
        homePlayerTwo: 'Bea',
      );
      match = match.rallyWonBy(0);
      expect(match.endSwitchDue, isTrue);
      expect(match.servingPlayerName, 'Bea');

      match = match.rallyWonBy(1);
      expect(match.serverNumber, 2);
      expect(match.servingPlayerName, 'Ava');
    });

    test('serializes the active game, undo stack and preferences', () {
      const state = SavedAppState(
        match: PickleballMatch(homeScore: 3),
        undoHistory: [PickleballMatch(homeScore: 2)],
        soundEnabled: true,
        landscapeView: true,
      );
      final restored = SavedAppState.fromJson(state.toJson());
      expect(restored.match?.homeScore, 3);
      expect(restored.undoHistory.single.homeScore, 2);
      expect(restored.soundEnabled, isTrue);
      expect(restored.landscapeView, isTrue);
    });
  });

  testWidgets('scoreboard controls update the called score', (tester) async {
    final storage = MatchStorage(preferences: _MemoryPreferences());
    await tester.pumpWidget(PickleScorerApp(storage: storage));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('0 - 0 - 2'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('rally-0')));
    await tester.tap(find.byKey(const ValueKey('rally-0')));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('1 - 0 - 2'), findsOneWidget);
  });

  testWidgets('active match resumes from local storage', (tester) async {
    final storage = MatchStorage(preferences: _MemoryPreferences());
    await tester.pumpWidget(PickleScorerApp(storage: storage));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('rally-0')));
    await tester.tap(find.byKey(const ValueKey('rally-0')));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(PickleScorerApp(storage: storage));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('1 - 0 - 2'), findsOneWidget);
  });

  testWidgets('match center shows the rally history', (tester) async {
    final storage = MatchStorage(preferences: _MemoryPreferences());
    await tester.pumpWidget(PickleScorerApp(storage: storage));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('rally-0')));
    await tester.tap(find.byKey(const ValueKey('rally-0')));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Match history and statistics'));
    await tester.pumpAndSettle();
    expect(find.text('Home won the rally'), findsOneWidget);
    expect(find.text('Game 1  ·  1-0  ·  1 - 0 - 2'), findsOneWidget);
  });

  testWidgets('settings allow best-of-three match format', (tester) async {
    final storage = MatchStorage(preferences: _MemoryPreferences());
    await tester.pumpWidget(PickleScorerApp(storage: storage));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Match and court settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Best of three games'));
    await tester.tap(find.text('Save settings'));
    await tester.pumpAndSettle();
    expect(find.text('Game 1  ·  Home 0 - 0 Away'), findsOneWidget);
  });

  testWidgets('completed games appear in match history and statistics', (
    tester,
  ) async {
    final storage = MatchStorage(preferences: _MemoryPreferences());
    await tester.pumpWidget(PickleScorerApp(storage: storage));
    await tester.pumpAndSettle();

    await tester.tap(find.text('7'));
    await tester.pumpAndSettle();
    for (var point = 0; point < 7; point++) {
      await tester.ensureVisible(find.byKey(const ValueKey('rally-0')));
      await tester.tap(find.byKey(const ValueKey('rally-0')));
      await tester.pumpAndSettle();
    }
    expect(find.text('Start another match'), findsOneWidget);

    await tester.tap(find.byTooltip('Match history and statistics'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Matches'));
    await tester.pumpAndSettle();
    expect(find.text('Home won'), findsOneWidget);
    await tester.tap(find.text('Stats'));
    await tester.pumpAndSettle();
    expect(find.text('Matches played'), findsOneWidget);
  });
}

class _MemoryPreferences implements MatchPreferenceStore {
  final values = <String, String>{};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}
