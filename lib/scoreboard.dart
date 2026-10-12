import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'match.dart';
import 'match_storage.dart';

export 'match.dart';

class PickleScorerApp extends StatelessWidget {
  const PickleScorerApp({super.key, this.storage});

  final MatchStorage? storage;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF102131);
    return MaterialApp(
      title: 'Pickle Scorer App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFEEF3F6),
        colorScheme: ColorScheme.fromSeed(
          seedColor: ink,
          primary: ink,
          surface: const Color(0xFFEEF3F6),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Color(0xFF536B80)),
        ),
      ),
      home: ScoreboardPage(storage: storage),
    );
  }
}

class ScoreboardPage extends StatefulWidget {
  const ScoreboardPage({super.key, this.storage});

  final MatchStorage? storage;

  @override
  State<ScoreboardPage> createState() => _ScoreboardPageState();
}

class _ScoreboardPageState extends State<ScoreboardPage> {
  PickleballMatch match = const PickleballMatch();
  final history = <PickleballMatch>[];
  final rallyEvents = <RallyEvent>[];
  final completedMatches = <CompletedMatch>[];
  late final MatchStorage _storage;
  Future<void> _saveQueue = Future<void>.value();
  bool _loading = true;
  Object? _loadError;
  bool soundEnabled = false;
  bool hapticsEnabled = false;
  bool largeControls = false;
  bool landscapeView = false;

  @override
  void initState() {
    super.initState();
    _storage = widget.storage ?? MatchStorage();
    unawaited(_restore());
  }

  Future<void> _restore() async {
    try {
      final saved = await _storage.load();
      if (!mounted) return;
      setState(() {
        match = saved.match ?? match;
        history
          ..clear()
          ..addAll(saved.undoHistory);
        rallyEvents
          ..clear()
          ..addAll(saved.rallyEvents);
        completedMatches
          ..clear()
          ..addAll(saved.completedMatches);
        soundEnabled = saved.soundEnabled;
        hapticsEnabled = saved.hapticsEnabled;
        largeControls = saved.largeControls;
        landscapeView = saved.landscapeView;
        _loading = false;
      });
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'pickle scorer local storage',
          context: ErrorDescription('while restoring the saved match'),
        ),
      );
      if (mounted) {
        setState(() {
          _loadError = error;
          _loading = false;
        });
      }
    }
  }

  void _persist() {
    final snapshot = SavedAppState(
      match: match,
      undoHistory: List.unmodifiable(history),
      rallyEvents: List.unmodifiable(rallyEvents),
      completedMatches: List.unmodifiable(completedMatches),
      soundEnabled: soundEnabled,
      hapticsEnabled: hapticsEnabled,
      largeControls: largeControls,
      landscapeView: landscapeView,
    );
    _saveQueue = _saveQueue.then((_) => _storage.save(snapshot)).catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'pickle scorer local storage',
          context: ErrorDescription('while saving the match'),
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save the match locally.')),
        );
      }
    });
  }

  void _rally(int side) {
    if (match.gameWinner != null) return;
    final previousMatchWinner = match.winner;
    setState(() {
      history.add(match);
      match = match.rallyWonBy(side);
      rallyEvents.add(
        RallyEvent(
          winningSide: side,
          winningName: side == 0 ? match.homeName : match.awayName,
          gameNumber: match.gameNumber,
          homeScore: match.homeScore,
          awayScore: match.awayScore,
          scoreCall: match.scoreCall,
          createdAt: DateTime.now(),
        ),
      );
      if (previousMatchWinner == null && match.winner != null) {
        completedMatches.insert(
          0,
          CompletedMatch(
            homeName: match.homeName,
            awayName: match.awayName,
            homeGames: match.homeGames,
            awayGames: match.awayGames,
            homeScore: match.homeScore,
            awayScore: match.awayScore,
            winner: match.winner!,
            mode: match.mode,
            target: match.target,
            bestOfThree: match.bestOfThree,
            completedAt: DateTime.now(),
          ),
        );
      }
    });
    _persist();
    _playFeedback();
  }

  void _undo() {
    if (history.isNotEmpty) {
      final finishedMatch = match.winner != null;
      setState(() {
        match = history.removeLast();
        if (rallyEvents.isNotEmpty) rallyEvents.removeLast();
        if (finishedMatch && completedMatches.isNotEmpty) {
          completedMatches.removeAt(0);
        }
      });
      _persist();
    }
  }

  Future<void> _advanceGame() async {
    if (match.gameWinner == null || match.winner != null) return;
    setState(() {
      match = match.nextGame();
    });
    _persist();
  }

  void _switchEnds() {
    setState(() => match = match.copyWith(endsSwitched: true));
    _persist();
  }

  Future<void> _newGame() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          match.winner == null ? 'Start a new match?' : 'Start another match?',
        ),
        content: const Text(
          'The saved match will be cleared. Completed matches will stay in your local history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep playing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('New match'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      match = _freshMatch();
      history.clear();
      rallyEvents.clear();
    });
    _persist();
  }

  PickleballMatch _freshMatch({
    MatchMode? mode,
    int? target,
    bool? bestOfThree,
    bool? winByOne,
  }) => PickleballMatch(
    mode: mode ?? match.mode,
    target: target ?? match.target,
    bestOfThree: bestOfThree ?? match.bestOfThree,
    winByOne: winByOne ?? match.winByOne,
    homeName: match.homeName,
    awayName: match.awayName,
    homePlayerOne: match.homePlayerOne,
    homePlayerTwo: match.homePlayerTwo,
    awayPlayerOne: match.awayPlayerOne,
    awayPlayerTwo: match.awayPlayerTwo,
  );

  Future<void> _editTeam(int side) async {
    final isHome = side == 0;
    final teamController = TextEditingController(
      text: isHome ? match.homeName : match.awayName,
    );
    final firstController = TextEditingController(
      text: isHome ? match.homePlayerOne : match.awayPlayerOne,
    );
    final secondController = TextEditingController(
      text: isHome ? match.homePlayerTwo : match.awayPlayerTwo,
    );
    final names = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${isHome ? 'home' : 'away'} team'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: teamController,
              autofocus: true,
              maxLength: 18,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Team name'),
            ),
            TextField(
              controller: firstController,
              maxLength: 18,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Player 1'),
            ),
            if (match.mode == MatchMode.doubles)
              TextField(
                controller: secondController,
                maxLength: 18,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Player 2'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, [
              teamController.text.trim(),
              firstController.text.trim(),
              secondController.text.trim(),
            ]),
            child: const Text('Save team'),
          ),
        ],
      ),
    );
    teamController.dispose();
    firstController.dispose();
    secondController.dispose();
    if (names == null || !mounted) return;
    if (names.first.isEmpty ||
        names[1].isEmpty ||
        (match.mode == MatchMode.doubles && names[2].isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a team name and all player names.'),
        ),
      );
      return;
    }
    setState(() {
      match = isHome
          ? match.copyWith(
              homeName: names[0],
              homePlayerOne: names[1],
              homePlayerTwo: names[2].isEmpty ? names[1] : names[2],
            )
          : match.copyWith(
              awayName: names[0],
              awayPlayerOne: names[1],
              awayPlayerTwo: names[2].isEmpty ? names[1] : names[2],
            );
    });
    _persist();
  }

  Future<void> _setMode(MatchMode mode) async {
    if (mode == match.mode) return;
    if (!await _confirmReset('Change match format?')) return;
    if (!mounted) return;
    setState(() {
      match = _freshMatch(mode: mode);
      history.clear();
      rallyEvents.clear();
    });
    _persist();
  }

  Future<void> _setTarget(int target) async {
    if (target == match.target) return;
    if (!await _confirmReset('Change game target?')) return;
    if (!mounted) return;
    setState(() {
      match = _freshMatch(target: target);
      history.clear();
      rallyEvents.clear();
    });
    _persist();
  }

  Future<bool> _confirmReset(String title) async {
    if (rallyEvents.isEmpty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: const Text(
              'Changing match rules starts a fresh match. Completed matches remain saved in history.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Start fresh match'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _showSettings() async {
    var selectedBestOfThree = match.bestOfThree;
    var selectedWinByOne = match.winByOne;
    var selectedSound = soundEnabled;
    var selectedHaptics = hapticsEnabled;
    var selectedLargeControls = largeControls;
    var selectedLandscape = landscapeView;
    final values = await showDialog<List<bool>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Match & court settings'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('Best of three games'),
                  value: selectedBestOfThree,
                  onChanged: (value) =>
                      setDialogState(() => selectedBestOfThree = value),
                ),
                SwitchListTile(
                  title: const Text('Win by one point'),
                  value: selectedWinByOne,
                  onChanged: (value) =>
                      setDialogState(() => selectedWinByOne = value),
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('Sound on rally'),
                  value: selectedSound,
                  onChanged: (value) =>
                      setDialogState(() => selectedSound = value),
                ),
                SwitchListTile(
                  title: const Text('Vibration on rally'),
                  value: selectedHaptics,
                  onChanged: (value) =>
                      setDialogState(() => selectedHaptics = value),
                ),
                SwitchListTile(
                  title: const Text('Larger court buttons'),
                  value: selectedLargeControls,
                  onChanged: (value) =>
                      setDialogState(() => selectedLargeControls = value),
                ),
                SwitchListTile(
                  title: const Text('Landscape scoreboard layout'),
                  value: selectedLandscape,
                  onChanged: (value) =>
                      setDialogState(() => selectedLandscape = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, [
                selectedBestOfThree,
                selectedWinByOne,
                selectedSound,
                selectedHaptics,
                selectedLargeControls,
                selectedLandscape,
              ]),
              child: const Text('Save settings'),
            ),
          ],
        ),
      ),
    );
    if (values == null || !mounted) return;
    final matchRulesChanged =
        values[0] != match.bestOfThree || values[1] != match.winByOne;
    if (matchRulesChanged && !await _confirmReset('Update match rules?')) {
      return;
    }
    if (!mounted) return;
    setState(() {
      if (matchRulesChanged) {
        match = _freshMatch(bestOfThree: values[0], winByOne: values[1]);
        history.clear();
        rallyEvents.clear();
      } else {
        match = match.copyWith(bestOfThree: values[0], winByOne: values[1]);
      }
      soundEnabled = values[2];
      hapticsEnabled = values[3];
      largeControls = values[4];
      landscapeView = values[5];
    });
    _persist();
  }

  void _playFeedback() {
    final futures = <Future<void>>[];
    if (soundEnabled) futures.add(SystemSound.play(SystemSoundType.click));
    if (hapticsEnabled) futures.add(HapticFeedback.selectionClick());
    if (futures.isEmpty) return;
    unawaited(
      Future.wait(futures).then<void>((_) {}).catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'pickle scorer feedback',
            context: ErrorDescription('while playing rally feedback'),
          ),
        );
      }),
    );
  }

  Future<void> _showMatchCenter() async {
    await showDialog<void>(
      context: context,
      builder: (context) => DefaultTabController(
        length: 3,
        child: AlertDialog(
          title: const Text('Match center'),
          content: SizedBox(
            width: 480,
            height: 420,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: 'Rallies'),
                    Tab(text: 'Matches'),
                    Tab(text: 'Stats'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _rallyHistoryView(),
                      _completedMatchesView(),
                      _statisticsView(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rallyHistoryView() {
    if (rallyEvents.isEmpty) {
      return const Center(child: Text('Rally history will appear here.'));
    }
    return ListView.builder(
      itemCount: rallyEvents.length,
      itemBuilder: (context, index) {
        final event = rallyEvents[rallyEvents.length - index - 1];
        return ListTile(
          dense: true,
          leading: CircleAvatar(child: Text('${rallyEvents.length - index}')),
          title: Text('${event.winningName} won the rally'),
          subtitle: Text(
            'Game ${event.gameNumber}  ·  ${event.homeScore}-${event.awayScore}  ·  ${event.scoreCall}',
          ),
        );
      },
    );
  }

  Widget _completedMatchesView() {
    if (completedMatches.isEmpty) {
      return const Center(child: Text('Completed matches will appear here.'));
    }
    return ListView.builder(
      itemCount: completedMatches.length,
      itemBuilder: (context, index) {
        final saved = completedMatches[index];
        final winner = saved.winner == 0 ? saved.homeName : saved.awayName;
        return ListTile(
          title: Text('$winner won'),
          subtitle: Text(
            '${saved.homeName} ${saved.homeGames}-${saved.awayGames} ${saved.awayName}'
            '  ·  ${saved.mode.name}${saved.bestOfThree ? ', best of three' : ''}'
            '  ·  first to ${saved.target}'
            '  ·  ${saved.completedAt.toLocal()}',
          ),
        );
      },
    );
  }

  Widget _statisticsView() {
    if (completedMatches.isEmpty) {
      return const Center(child: Text('Finish a match to see your stats.'));
    }
    final wins = <String, int>{};
    for (final saved in completedMatches) {
      final name = saved.winner == 0 ? saved.homeName : saved.awayName;
      wins.update(name, (count) => count + 1, ifAbsent: () => 1);
    }
    final sorted = wins.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ListView(
      children: [
        ListTile(
          title: const Text('Matches played'),
          trailing: Text('${completedMatches.length}'),
        ),
        for (final entry in sorted)
          ListTile(
            title: Text(entry.key),
            subtitle: const Text('Match wins'),
            trailing: Text('${entry.value}'),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_loadError != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Could not restore the saved match.',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text('$_loadError'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      setState(() {
                        _loading = true;
                        _loadError = null;
                      });
                      unawaited(_restore());
                    },
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final winnerSide = match.winner ?? match.gameWinner;
    final winner = winnerSide == 0
        ? match.homeName
        : winnerSide == 1
        ? match.awayName
        : null;
    final server = match.servingPlayerName;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide =
                landscapeView && constraints.maxWidth > constraints.maxHeight;
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: wide ? 1050 : 600),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _header(),
                      const SizedBox(height: 12),
                      Expanded(
                        child: wide
                            ? _landscapeLayout(server, winner)
                            : _standardLayout(server, winner),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _standardLayout(String server, String? winner) =>
      SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 620),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _formatControls(),
                  const SizedBox(height: 14),
                  _board(winner),
                  const SizedBox(height: 12),
                  _scoreCall(server, winner),
                  if (match.endSwitchDue) ...[
                    const SizedBox(height: 8),
                    _endSwitchReminder(),
                  ],
                ],
              ),
              const SizedBox(height: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _rallyControls(),
                  const SizedBox(height: 9),
                  _rulesNote(),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _landscapeLayout(String server, String? winner) =>
      SingleChildScrollView(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _formatControls(),
                  const SizedBox(height: 12),
                  _board(winner),
                  const SizedBox(height: 10),
                  _scoreCall(server, winner),
                  if (match.endSwitchDue) ...[
                    const SizedBox(height: 8),
                    _endSwitchReminder(),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.only(top: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _rallyControls(),
                    const SizedBox(height: 12),
                    _rulesNote(),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _endSwitchReminder() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF4D5),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE7CB79)),
    ),
    child: Row(
      children: [
        const Expanded(
          child: Text(
            'Time to change ends',
            style: TextStyle(
              color: Color(0xFF584617),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        TextButton(onPressed: _switchEnds, child: const Text('Switch sides')),
      ],
    ),
  );

  Widget _seriesScore() => Text(
    match.bestOfThree
        ? 'Game ${match.gameNumber}  ·  ${match.homeName} ${match.homeGames} - ${match.awayGames} ${match.awayName}'
        : 'Game to ${match.target}${match.winByOne ? '  ·  Win by one' : '  ·  Win by two'}',
    textAlign: TextAlign.center,
    style: const TextStyle(
      color: Color(0xFF536B80),
      fontWeight: FontWeight.w700,
    ),
  );

  Widget _header() => Row(
    children: [
      Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(
          color: Color(0xFFD5F12F),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: Stack(
              children: [
                Positioned(left: 2, top: 2, child: _BallDot()),
                Positioned(right: 2, top: 2, child: _BallDot()),
                Positioned(left: 7, bottom: 2, child: _BallDot()),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      const Expanded(
        child: Text(
          'Pickle Scorer',
          style: TextStyle(
            color: Color(0xFF102131),
            fontSize: 21,
            fontWeight: FontWeight.w900,
            letterSpacing: -.5,
          ),
        ),
      ),
      _headerAction(
        tooltip: 'Undo last rally',
        onPressed: history.isEmpty ? null : _undo,
        icon: Icons.undo_rounded,
      ),
      const SizedBox(width: 7),
      _headerAction(
        tooltip: 'Start a new match',
        onPressed: _newGame,
        icon: Icons.restart_alt_rounded,
      ),
      const SizedBox(width: 6),
      _headerAction(
        tooltip: 'Match history and statistics',
        onPressed: _showMatchCenter,
        icon: Icons.history_rounded,
      ),
      const SizedBox(width: 6),
      _headerAction(
        tooltip: 'Match and court settings',
        onPressed: _showSettings,
        icon: Icons.tune_rounded,
      ),
    ],
  );

  Widget _headerAction({
    required String tooltip,
    required VoidCallback? onPressed,
    required IconData icon,
  }) => SizedBox(
    width: 46,
    height: 46,
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 21),
      style: IconButton.styleFrom(
        foregroundColor: const Color(0xFF182A3A),
        disabledForegroundColor: const Color(0xFF9DAAB4),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: const BorderSide(color: Color(0xFFD2DDE5)),
        ),
      ),
    ),
  );

  Widget _formatControls() => LayoutBuilder(
    builder: (context, constraints) {
      final modeControl = _modeSelector();
      final targetControl = _targetSelector();
      if (constraints.maxWidth < 460) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [modeControl, const SizedBox(height: 8), targetControl],
        );
      }
      return Row(
        children: [
          Expanded(child: modeControl),
          const SizedBox(width: 9),
          Expanded(child: targetControl),
        ],
      );
    },
  );

  Widget _modeSelector() => SegmentedButton<MatchMode>(
    segments: const [
      ButtonSegment(value: MatchMode.singles, label: Text('Singles')),
      ButtonSegment(value: MatchMode.doubles, label: Text('Doubles')),
    ],
    selected: {match.mode},
    showSelectedIcon: false,
    onSelectionChanged: (value) => _setMode(value.first),
    style: SegmentedButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF536B80),
      selectedBackgroundColor: const Color(0xFF102131),
      selectedForegroundColor: Colors.white,
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      side: const BorderSide(color: Color(0xFFD2DDE5)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    ),
  );

  Widget _targetSelector() => SegmentedButton<int>(
    segments: const [
      ButtonSegment(value: 7, label: Text('7')),
      ButtonSegment(value: 11, label: Text('11')),
      ButtonSegment(value: 15, label: Text('15')),
      ButtonSegment(value: 21, label: Text('21')),
    ],
    selected: {match.target},
    showSelectedIcon: false,
    onSelectionChanged: (value) => _setTarget(value.first),
    style: SegmentedButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF536B80),
      selectedBackgroundColor: const Color(0xFF102131),
      selectedForegroundColor: Colors.white,
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 13),
      side: const BorderSide(color: Color(0xFFD2DDE5)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    ),
  );

  Widget _board(String? winner) => Container(
    height: 290,
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: const Color(0xFF205C55),
      borderRadius: BorderRadius.circular(25),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1F102131),
          blurRadius: 24,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFB6CCD0), width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Row(
          children: [
            Expanded(child: _team(_logicalSide(0), winner)),
            Container(width: 3, color: const Color(0xFFB6CCD0)),
            Expanded(child: _team(_logicalSide(1), winner)),
          ],
        ),
      ),
    ),
  );

  Widget _team(int side, String? winner) {
    final name = side == 0 ? match.homeName : match.awayName;
    final score = side == 0 ? match.homeScore : match.awayScore;
    final serving = match.servingSide == side && match.gameWinner == null;
    final players = side == 0
        ? '${match.homePlayerOne}  ·  ${match.homePlayerTwo}'
        : '${match.awayPlayerOne}  ·  ${match.awayPlayerTwo}';
    return Material(
      color: side == 0 ? const Color(0xFF20538E) : const Color(0xFF1D5954),
      child: InkWell(
        onTap: () => _editTeam(side),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 15),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: serving ? Colors.white : const Color(0xFFD1DDDF),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (match.mode == MatchMode.doubles)
                    Text(
                      players,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFDAE4E5),
                        fontSize: 9,
                      ),
                    ),
                ],
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$score',
                  style: TextStyle(
                    color: side == match.servingSide
                        ? Colors.white
                        : const Color(0xFFD9E0E3),
                    fontSize: largeControls ? 146 : 136,
                    height: .9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              SizedBox(
                height: 29,
                child: serving
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const _BallBadge(),
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD5F12F),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              match.mode == MatchMode.doubles
                                  ? 'Server ${match.serverNumber}'
                                  : 'Serving',
                              style: const TextStyle(
                                color: Color(0xFF102131),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      )
                    : winner == name
                    ? const Icon(
                        Icons.emoji_events_rounded,
                        color: Color(0xFFD5F12F),
                        size: 24,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _logicalSide(int displaySide) =>
      match.endsSwitched ? 1 - displaySide : displaySide;

  Widget _scoreCall(String server, String? winner) {
    final servingScore = match.servingSide == 0
        ? match.homeScore
        : match.awayScore;
    final servingSide = servingScore.isEven ? 'right' : 'left';
    final callParts = match.scoreCall.split(' - ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD2DDE5)),
      ),
      child: Semantics(
        label: match.scoreCall,
        container: true,
        excludeSemantics: true,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    winner == null ? 'Call it' : 'Game over',
                    style: const TextStyle(
                      color: Color(0xFF102131),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    winner == null
                        ? '$server serves from the $servingSide side'
                        : '$winner wins',
                    style: const TextStyle(
                      color: Color(0xFF627B90),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < callParts.length; i++) ...[
                  if (i > 0)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        '-',
                        style: TextStyle(
                          color: Color(0xFF627080),
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  if (i == callParts.length - 1 &&
                      match.mode == MatchMode.doubles)
                    Container(
                      width: 45,
                      height: 58,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD5F12F),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Text(
                        callParts[i],
                        style: const TextStyle(
                          color: Color(0xFF102131),
                          fontSize: 40,
                          height: 1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    )
                  else
                    Text(
                      callParts[i],
                      style: const TextStyle(
                        color: Color(0xFF102131),
                        fontSize: 38,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _rallyControls() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        match.gameWinner == null
            ? 'Who won the rally?'
            : match.winner == null
            ? 'Game ${match.gameNumber} complete'
            : 'Match complete',
        style: const TextStyle(
          color: Color(0xFF536B80),
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 8),
      if (match.gameWinner == null)
        Row(
          children: [
            Expanded(child: _rallyButton(_logicalSide(0))),
            const SizedBox(width: 10),
            Expanded(child: _rallyButton(_logicalSide(1))),
          ],
        )
      else
        SizedBox(
          width: double.infinity,
          height: largeControls ? 92 : 72,
          child: FilledButton.icon(
            onPressed: match.winner == null ? _advanceGame : _newGame,
            icon: Icon(
              match.winner == null
                  ? Icons.navigate_next_rounded
                  : Icons.restart_alt_rounded,
            ),
            label: Text(
              match.winner == null ? 'Start next game' : 'Start another match',
            ),
          ),
        ),
      if (match.bestOfThree) ...[const SizedBox(height: 6), _seriesScore()],
    ],
  );

  Widget _rallyButton(int side) {
    final name = side == 0 ? match.homeName : match.awayName;
    return SizedBox(
      height: largeControls ? 108 : 83,
      child: FilledButton(
        key: ValueKey('rally-$side'),
        onPressed: match.winner == null ? () => _rally(side) : null,
        style: FilledButton.styleFrom(
          backgroundColor: side == 0
              ? const Color(0xFF20538E)
              : const Color(0xFF0E716A),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFAAB8C1),
          disabledForegroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: largeControls ? 20 : 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'won the rally',
              style: TextStyle(
                fontSize: largeControls ? 14 : 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFFDCE7EE),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rulesNote() => Text(
    match.mode == MatchMode.doubles
        ? 'Doubles call: serving score, receiving score, server number. A game starts at 0-0-2. Only the serving side scores; a lost rally passes service.'
        : 'Singles call: serving score, receiving score. Serve from the right on an even score and left on an odd score. Only the serving side scores.',
    style: const TextStyle(
      color: Color(0xFF627B90),
      fontSize: 13,
      height: 1.45,
    ),
  );
}

class _BallDot extends StatelessWidget {
  const _BallDot();

  @override
  Widget build(BuildContext context) => Container(
    width: 7,
    height: 7,
    decoration: const BoxDecoration(
      color: Color(0xFF426124),
      shape: BoxShape.circle,
    ),
  );
}

class _BallBadge extends StatelessWidget {
  const _BallBadge();

  @override
  Widget build(BuildContext context) => Container(
    width: 30,
    height: 30,
    decoration: BoxDecoration(
      color: const Color(0xFFD5F12F),
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0xFF8EA923), width: 3),
    ),
    child: const Center(
      child: SizedBox(
        width: 15,
        height: 15,
        child: Stack(
          children: [
            Positioned(left: 1, top: 1, child: _BallDot()),
            Positioned(right: 1, top: 1, child: _BallDot()),
            Positioned(left: 4, bottom: 1, child: _BallDot()),
          ],
        ),
      ),
    ),
  );
}
