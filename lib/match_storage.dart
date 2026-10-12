import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'match.dart';

class SavedAppState {
  const SavedAppState({
    this.match,
    this.undoHistory = const [],
    this.rallyEvents = const [],
    this.completedMatches = const [],
    this.soundEnabled = false,
    this.hapticsEnabled = false,
    this.largeControls = false,
    this.landscapeView = false,
  });

  final PickleballMatch? match;
  final List<PickleballMatch> undoHistory;
  final List<RallyEvent> rallyEvents;
  final List<CompletedMatch> completedMatches;
  final bool soundEnabled;
  final bool hapticsEnabled;
  final bool largeControls;
  final bool landscapeView;

  Map<String, Object?> toJson() => {
    if (match != null) 'match': match!.toJson(),
    'undoHistory': undoHistory.map((match) => match.toJson()).toList(),
    'rallyEvents': rallyEvents.map((event) => event.toJson()).toList(),
    'completedMatches': completedMatches
        .map((match) => match.toJson())
        .toList(),
    'soundEnabled': soundEnabled,
    'hapticsEnabled': hapticsEnabled,
    'largeControls': largeControls,
    'landscapeView': landscapeView,
  };

  factory SavedAppState.fromJson(Map<String, Object?> json) => SavedAppState(
    match: json['match'] == null
        ? null
        : PickleballMatch.fromJson(
            Map<String, Object?>.from(json['match']! as Map),
          ),
    undoHistory: (json['undoHistory']! as List)
        .map(
          (match) =>
              PickleballMatch.fromJson(Map<String, Object?>.from(match as Map)),
        )
        .toList(),
    rallyEvents: (json['rallyEvents']! as List)
        .map(
          (event) =>
              RallyEvent.fromJson(Map<String, Object?>.from(event as Map)),
        )
        .toList(),
    completedMatches: (json['completedMatches']! as List)
        .map(
          (match) =>
              CompletedMatch.fromJson(Map<String, Object?>.from(match as Map)),
        )
        .toList(),
    soundEnabled: json['soundEnabled']! as bool,
    hapticsEnabled: json['hapticsEnabled']! as bool,
    largeControls: json['largeControls']! as bool,
    landscapeView: json['landscapeView']! as bool,
  );
}

abstract interface class MatchPreferenceStore {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
}

class _SharedPreferencesStore implements MatchPreferenceStore {
  _SharedPreferencesStore() : _preferences = SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> getString(String key) => _preferences.getString(key);

  @override
  Future<void> setString(String key, String value) =>
      _preferences.setString(key, value);
}

class MatchStorage {
  MatchStorage({MatchPreferenceStore? preferences})
    : _preferences = preferences ?? _SharedPreferencesStore();

  static const _stateKey = 'pickle_scorer_saved_state_v1';
  final MatchPreferenceStore _preferences;

  Future<SavedAppState> load() async {
    final value = await _preferences.getString(_stateKey);
    if (value == null) return const SavedAppState();
    final decoded = jsonDecode(value);
    return SavedAppState.fromJson(Map<String, Object?>.from(decoded as Map));
  }

  Future<void> save(SavedAppState state) =>
      _preferences.setString(_stateKey, jsonEncode(state.toJson()));
}
