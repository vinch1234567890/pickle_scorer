import 'package:flutter/foundation.dart';

enum MatchMode { singles, doubles }

@immutable
class PickleballMatch {
  const PickleballMatch({
    this.mode = MatchMode.doubles,
    this.target = 11,
    this.homeScore = 0,
    this.awayScore = 0,
    this.servingSide = 0,
    this.serverNumber = 2,
    this.openingSequence = true,
    this.homeName = 'Home',
    this.awayName = 'Away',
    this.homePlayerOne = 'Home 1',
    this.homePlayerTwo = 'Home 2',
    this.awayPlayerOne = 'Away 1',
    this.awayPlayerTwo = 'Away 2',
    this.servingPlayerIndex = 1,
    this.homeRightPlayerIndex = 1,
    this.awayRightPlayerIndex = 0,
    this.homeGames = 0,
    this.awayGames = 0,
    this.gameNumber = 1,
    this.bestOfThree = false,
    this.winByOne = false,
    this.endsSwitched = false,
  });

  final MatchMode mode;
  final int target;
  final int homeScore;
  final int awayScore;
  final int servingSide;
  final int serverNumber;
  final bool openingSequence;
  final String homeName;
  final String awayName;
  final String homePlayerOne;
  final String homePlayerTwo;
  final String awayPlayerOne;
  final String awayPlayerTwo;
  final int servingPlayerIndex;
  final int homeRightPlayerIndex;
  final int awayRightPlayerIndex;
  final int homeGames;
  final int awayGames;
  final int gameNumber;
  final bool bestOfThree;
  final bool winByOne;
  final bool endsSwitched;

  int? get gameWinner {
    final margin = winByOne ? 1 : 2;
    if (homeScore >= target && homeScore - awayScore >= margin) return 0;
    if (awayScore >= target && awayScore - homeScore >= margin) return 1;
    return null;
  }

  int? get winner {
    if (bestOfThree) {
      if (homeGames >= 2) return 0;
      if (awayGames >= 2) return 1;
      return null;
    }
    return gameWinner;
  }

  int _scoreFor(int side) => side == 0 ? homeScore : awayScore;

  String get scoreCall => mode == MatchMode.doubles
      ? '${_scoreFor(servingSide)} - ${_scoreFor(1 - servingSide)} - $serverNumber'
      : '${_scoreFor(servingSide)} - ${_scoreFor(1 - servingSide)}';

  String get servingPlayerName {
    if (mode == MatchMode.singles) {
      return servingSide == 0 ? homeName : awayName;
    }
    final players = servingSide == 0
        ? [homePlayerOne, homePlayerTwo]
        : [awayPlayerOne, awayPlayerTwo];
    return players[servingPlayerIndex];
  }

  bool get endSwitchDue =>
      gameWinner == null &&
      !endsSwitched &&
      (homeScore >= (target + 1) ~/ 2 || awayScore >= (target + 1) ~/ 2);

  PickleballMatch rallyWonBy(int side) {
    if (gameWinner != null) return this;

    var updated = this;
    if (side == servingSide) {
      updated = copyWith(
        homeScore: homeScore + (side == 0 ? 1 : 0),
        awayScore: awayScore + (side == 1 ? 1 : 0),
        homeRightPlayerIndex: side == 0
            ? 1 - homeRightPlayerIndex
            : homeRightPlayerIndex,
        awayRightPlayerIndex: side == 1
            ? 1 - awayRightPlayerIndex
            : awayRightPlayerIndex,
      );
    } else if (openingSequence) {
      final nextSide = 1 - servingSide;
      updated = copyWith(
        servingSide: nextSide,
        serverNumber: 1,
        servingPlayerIndex: _rightPlayerFor(nextSide),
        openingSequence: false,
      );
    } else if (mode == MatchMode.singles || serverNumber == 2) {
      final nextSide = 1 - servingSide;
      updated = copyWith(
        servingSide: nextSide,
        serverNumber: 1,
        servingPlayerIndex: _rightPlayerFor(nextSide),
      );
    } else {
      updated = copyWith(
        serverNumber: 2,
        servingPlayerIndex: 1 - servingPlayerIndex,
      );
    }

    if (updated.gameWinner == 0) {
      updated = updated.copyWith(homeGames: homeGames + 1);
    } else if (updated.gameWinner == 1) {
      updated = updated.copyWith(awayGames: awayGames + 1);
    }
    return updated;
  }

  int _rightPlayerFor(int side) =>
      side == 0 ? homeRightPlayerIndex : awayRightPlayerIndex;

  PickleballMatch nextGame() {
    final nextGameNumber = gameNumber + 1;
    final nextServingSide = nextGameNumber.isEven ? 1 : 0;
    return copyWith(
      homeScore: 0,
      awayScore: 0,
      servingSide: nextServingSide,
      serverNumber: 2,
      openingSequence: true,
      servingPlayerIndex: 0,
      homeRightPlayerIndex: 0,
      awayRightPlayerIndex: 0,
      gameNumber: nextGameNumber,
      endsSwitched: false,
    );
  }

  PickleballMatch copyWith({
    MatchMode? mode,
    int? target,
    int? homeScore,
    int? awayScore,
    int? servingSide,
    int? serverNumber,
    bool? openingSequence,
    String? homeName,
    String? awayName,
    String? homePlayerOne,
    String? homePlayerTwo,
    String? awayPlayerOne,
    String? awayPlayerTwo,
    int? servingPlayerIndex,
    int? homeRightPlayerIndex,
    int? awayRightPlayerIndex,
    int? homeGames,
    int? awayGames,
    int? gameNumber,
    bool? bestOfThree,
    bool? winByOne,
    bool? endsSwitched,
  }) => PickleballMatch(
    mode: mode ?? this.mode,
    target: target ?? this.target,
    homeScore: homeScore ?? this.homeScore,
    awayScore: awayScore ?? this.awayScore,
    servingSide: servingSide ?? this.servingSide,
    serverNumber: serverNumber ?? this.serverNumber,
    openingSequence: openingSequence ?? this.openingSequence,
    homeName: homeName ?? this.homeName,
    awayName: awayName ?? this.awayName,
    homePlayerOne: homePlayerOne ?? this.homePlayerOne,
    homePlayerTwo: homePlayerTwo ?? this.homePlayerTwo,
    awayPlayerOne: awayPlayerOne ?? this.awayPlayerOne,
    awayPlayerTwo: awayPlayerTwo ?? this.awayPlayerTwo,
    servingPlayerIndex: servingPlayerIndex ?? this.servingPlayerIndex,
    homeRightPlayerIndex: homeRightPlayerIndex ?? this.homeRightPlayerIndex,
    awayRightPlayerIndex: awayRightPlayerIndex ?? this.awayRightPlayerIndex,
    homeGames: homeGames ?? this.homeGames,
    awayGames: awayGames ?? this.awayGames,
    gameNumber: gameNumber ?? this.gameNumber,
    bestOfThree: bestOfThree ?? this.bestOfThree,
    winByOne: winByOne ?? this.winByOne,
    endsSwitched: endsSwitched ?? this.endsSwitched,
  );

  Map<String, Object?> toJson() => {
    'mode': mode.name,
    'target': target,
    'homeScore': homeScore,
    'awayScore': awayScore,
    'servingSide': servingSide,
    'serverNumber': serverNumber,
    'openingSequence': openingSequence,
    'homeName': homeName,
    'awayName': awayName,
    'homePlayerOne': homePlayerOne,
    'homePlayerTwo': homePlayerTwo,
    'awayPlayerOne': awayPlayerOne,
    'awayPlayerTwo': awayPlayerTwo,
    'servingPlayerIndex': servingPlayerIndex,
    'homeRightPlayerIndex': homeRightPlayerIndex,
    'awayRightPlayerIndex': awayRightPlayerIndex,
    'homeGames': homeGames,
    'awayGames': awayGames,
    'gameNumber': gameNumber,
    'bestOfThree': bestOfThree,
    'winByOne': winByOne,
    'endsSwitched': endsSwitched,
  };

  factory PickleballMatch.fromJson(Map<String, Object?> json) =>
      PickleballMatch(
        mode: MatchMode.values.byName(json['mode']! as String),
        target: json['target']! as int,
        homeScore: json['homeScore']! as int,
        awayScore: json['awayScore']! as int,
        servingSide: json['servingSide']! as int,
        serverNumber: json['serverNumber']! as int,
        openingSequence: json['openingSequence']! as bool,
        homeName: json['homeName']! as String,
        awayName: json['awayName']! as String,
        homePlayerOne: json['homePlayerOne']! as String,
        homePlayerTwo: json['homePlayerTwo']! as String,
        awayPlayerOne: json['awayPlayerOne']! as String,
        awayPlayerTwo: json['awayPlayerTwo']! as String,
        servingPlayerIndex: json['servingPlayerIndex']! as int,
        homeRightPlayerIndex: json['homeRightPlayerIndex']! as int,
        awayRightPlayerIndex: json['awayRightPlayerIndex']! as int,
        homeGames: json['homeGames']! as int,
        awayGames: json['awayGames']! as int,
        gameNumber: json['gameNumber']! as int,
        bestOfThree: json['bestOfThree']! as bool,
        winByOne: json['winByOne']! as bool,
        endsSwitched: json['endsSwitched']! as bool,
      );
}

@immutable
class RallyEvent {
  const RallyEvent({
    required this.winningSide,
    required this.winningName,
    required this.gameNumber,
    required this.homeScore,
    required this.awayScore,
    required this.scoreCall,
    required this.createdAt,
  });

  final int winningSide;
  final String winningName;
  final int gameNumber;
  final int homeScore;
  final int awayScore;
  final String scoreCall;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'winningSide': winningSide,
    'winningName': winningName,
    'gameNumber': gameNumber,
    'homeScore': homeScore,
    'awayScore': awayScore,
    'scoreCall': scoreCall,
    'createdAt': createdAt.toIso8601String(),
  };

  factory RallyEvent.fromJson(Map<String, Object?> json) => RallyEvent(
    winningSide: json['winningSide']! as int,
    winningName: json['winningName']! as String,
    gameNumber: json['gameNumber']! as int,
    homeScore: json['homeScore']! as int,
    awayScore: json['awayScore']! as int,
    scoreCall: json['scoreCall']! as String,
    createdAt: DateTime.parse(json['createdAt']! as String),
  );
}

@immutable
class CompletedMatch {
  const CompletedMatch({
    required this.homeName,
    required this.awayName,
    required this.homeGames,
    required this.awayGames,
    required this.homeScore,
    required this.awayScore,
    required this.winner,
    required this.mode,
    required this.target,
    required this.bestOfThree,
    required this.completedAt,
  });

  final String homeName;
  final String awayName;
  final int homeGames;
  final int awayGames;
  final int homeScore;
  final int awayScore;
  final int winner;
  final MatchMode mode;
  final int target;
  final bool bestOfThree;
  final DateTime completedAt;

  Map<String, Object?> toJson() => {
    'homeName': homeName,
    'awayName': awayName,
    'homeGames': homeGames,
    'awayGames': awayGames,
    'homeScore': homeScore,
    'awayScore': awayScore,
    'winner': winner,
    'mode': mode.name,
    'target': target,
    'bestOfThree': bestOfThree,
    'completedAt': completedAt.toIso8601String(),
  };

  factory CompletedMatch.fromJson(Map<String, Object?> json) => CompletedMatch(
    homeName: json['homeName']! as String,
    awayName: json['awayName']! as String,
    homeGames: json['homeGames']! as int,
    awayGames: json['awayGames']! as int,
    homeScore: json['homeScore']! as int,
    awayScore: json['awayScore']! as int,
    winner: json['winner']! as int,
    mode: MatchMode.values.byName(json['mode']! as String),
    target: json['target']! as int,
    bestOfThree: json['bestOfThree']! as bool,
    completedAt: DateTime.parse(json['completedAt']! as String),
  );
}
