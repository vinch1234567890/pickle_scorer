import 'package:flutter/material.dart';

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

  int? get winner {
    if (homeScore >= target && homeScore - awayScore >= 2) return 0;
    if (awayScore >= target && awayScore - homeScore >= 2) return 1;
    return null;
  }

  int _scoreFor(int side) => side == 0 ? homeScore : awayScore;

  String get scoreCall => mode == MatchMode.doubles
      ? '${_scoreFor(servingSide)} - ${_scoreFor(1 - servingSide)} - $serverNumber'
      : '${_scoreFor(servingSide)} - ${_scoreFor(1 - servingSide)}';

  PickleballMatch rallyWonBy(int side) {
    if (winner != null) return this;
    if (side == servingSide) {
      return copyWith(
        homeScore: homeScore + (side == 0 ? 1 : 0),
        awayScore: awayScore + (side == 1 ? 1 : 0),
      );
    }
    if (openingSequence) {
      return copyWith(servingSide: 1 - servingSide, serverNumber: 1, openingSequence: false);
    }
    if (mode == MatchMode.singles || serverNumber == 2) {
      return copyWith(servingSide: 1 - servingSide, serverNumber: 1);
    }
    return copyWith(serverNumber: 2);
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
  }) =>
      PickleballMatch(
        mode: mode ?? this.mode,
        target: target ?? this.target,
        homeScore: homeScore ?? this.homeScore,
        awayScore: awayScore ?? this.awayScore,
        servingSide: servingSide ?? this.servingSide,
        serverNumber: serverNumber ?? this.serverNumber,
        openingSequence: openingSequence ?? this.openingSequence,
        homeName: homeName ?? this.homeName,
        awayName: awayName ?? this.awayName,
      );
}

class PickleScorerApp extends StatelessWidget {
  const PickleScorerApp({super.key});

  @override
  Widget build(BuildContext context) {
    const forest = Color(0xFF173D32);
    return MaterialApp(
      title: 'Pickle Scorer App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF4F3EC),
        colorScheme: ColorScheme.fromSeed(seedColor: forest, primary: forest, surface: const Color(0xFFF4F3EC)),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(fontFamily: 'serif', fontWeight: FontWeight.w700, color: forest),
          bodyMedium: TextStyle(color: Color(0xFF53625A)),
        ),
      ),
      home: const ScoreboardPage(),
    );
  }
}

class ScoreboardPage extends StatefulWidget {
  const ScoreboardPage({super.key});

  @override
  State<ScoreboardPage> createState() => _ScoreboardPageState();
}

class _ScoreboardPageState extends State<ScoreboardPage> {
  PickleballMatch match = const PickleballMatch();
  final history = <PickleballMatch>[];

  void _rally(int side) {
    if (match.winner != null) return;
    setState(() {
      history.add(match);
      match = match.rallyWonBy(side);
    });
  }

  void _undo() {
    if (history.isNotEmpty) setState(() => match = history.removeLast());
  }

  Future<void> _newGame() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start a new game?'),
        content: const Text('The current score and rally history will be cleared.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep playing')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('New game')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      match = match.copyWith(homeScore: 0, awayScore: 0, servingSide: 0, serverNumber: 2, openingSequence: true);
      history.clear();
    });
  }

  Future<void> _rename(int side) async {
    final controller = TextEditingController(text: side == 0 ? match.homeName : match.awayName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rename ${side == 0 ? 'home' : 'away'} side'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 18,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Team name'),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || !mounted) return;
    setState(() => match = side == 0 ? match.copyWith(homeName: name) : match.copyWith(awayName: name));
  }

  Future<void> _setMode(MatchMode mode) async {
    if (mode == match.mode) return;
    if (match.homeScore + match.awayScore > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Change match format?'),
          content: const Text('Changing format will start a fresh game.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Change format')),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      match = match.copyWith(mode: mode, homeScore: 0, awayScore: 0, servingSide: 0, serverNumber: 2, openingSequence: true);
      history.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final winner = match.winner == 0 ? match.homeName : match.winner == 1 ? match.awayName : null;
    final server = match.servingSide == 0 ? match.homeName : match.awayName;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                _header(),
                const SizedBox(height: 24),
                const Text('THE COURT IS YOURS', style: TextStyle(color: Color(0xFF68776E), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                const SizedBox(height: 4),
                Text('Keep the rally\nrolling.', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 34, height: 1.04)),
                const SizedBox(height: 22),
                _formatControls(),
                const SizedBox(height: 16),
                _board(server, winner),
                const SizedBox(height: 16),
                _rallyControls(winner),
                const SizedBox(height: 16),
                _rulesNote(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() => Row(
        children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFF173D32), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.sports_tennis, color: Color(0xFFD7F36A))),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PICKLE SCORER', style: TextStyle(color: Color(0xFF173D32), fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1)),
                Text('APP  /  MATCH 01', style: TextStyle(fontSize: 10, letterSpacing: 1)),
              ],
            ),
          ),
          IconButton(tooltip: 'Undo last rally', onPressed: history.isEmpty ? null : _undo, icon: const Icon(Icons.undo_rounded)),
          IconButton(tooltip: 'New game', onPressed: _newGame, icon: const Icon(Icons.restart_alt_rounded)),
        ],
      );

  Widget _formatControls() => Row(
        children: [
          Expanded(
            child: SegmentedButton<MatchMode>(
              segments: const [ButtonSegment(value: MatchMode.singles, label: Text('Singles')), ButtonSegment(value: MatchMode.doubles, label: Text('Doubles'))],
              selected: {match.mode},
              showSelectedIcon: false,
              onSelectionChanged: (value) => _setMode(value.first),
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E2D8))),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: match.target,
                borderRadius: BorderRadius.circular(12),
                items: const [11, 15, 21].map((score) => DropdownMenuItem(value: score, child: Text('To $score'))).toList(),
                onChanged: (score) {
                  if (score != null) setState(() => match = match.copyWith(target: score));
                },
              ),
            ),
          ),
        ],
      );

  Widget _board(String server, String? winner) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFF173D32), borderRadius: BorderRadius.circular(22), boxShadow: const [BoxShadow(color: Color(0x26173D32), blurRadius: 22, offset: Offset(0, 10))]),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(child: Text('LIVE SCORE', style: TextStyle(color: Color(0xFFAABBB1), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFF285242), borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(winner == null ? Icons.circle : Icons.emoji_events_rounded, size: 9, color: const Color(0xFFD7F36A)),
                      const SizedBox(width: 6),
                      Text(winner ?? '$server SERVING', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(children: [Expanded(child: _team(0)), Container(width: 1, height: 100, color: const Color(0xFF3B5B4E)), Expanded(child: _team(1))]),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(color: const Color(0xFF102F27), borderRadius: BorderRadius.circular(10)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('SCORE CALL', style: TextStyle(color: Color(0xFFAABBB1), fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1)),
                  const SizedBox(width: 10),
                  Text(match.scoreCall, style: const TextStyle(color: Color(0xFFD7F36A), fontSize: 18, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _team(int side) {
    final name = side == 0 ? match.homeName : match.awayName;
    final score = side == 0 ? match.homeScore : match.awayScore;
    final serving = match.servingSide == side && match.winner == null;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _rename(side),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (serving) ...[const Icon(Icons.sports_tennis, size: 12, color: Color(0xFFD7F36A)), const SizedBox(width: 4)],
                Flexible(child: Text(name.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: serving ? Colors.white : const Color(0xFFB3C2B8), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: .8))),
                const SizedBox(width: 4),
                const Icon(Icons.edit, size: 11, color: Color(0xFF80988B)),
              ],
            ),
            const SizedBox(height: 2),
            Text('$score', style: const TextStyle(color: Colors.white, fontFamily: 'serif', fontSize: 62, height: 1.15, fontWeight: FontWeight.w700)),
            Text(side == 0 ? 'HOME' : 'AWAY', style: const TextStyle(color: Color(0xFF91A69A), fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.6)),
          ],
        ),
      ),
    );
  }

  Widget _rallyControls(String? winner) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('WHO WON THE RALLY?', style: TextStyle(color: Color(0xFF53625A), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2))),
              if (winner != null) const Text('GAME OVER', style: TextStyle(color: Color(0xFFBC5843), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 10),
          Row(children: [Expanded(child: _rallyButton(0)), const SizedBox(width: 10), Expanded(child: _rallyButton(1))]),
          const SizedBox(height: 9),
          Text(winner == null ? 'A rally won by the receiving side is a side-out. Only the serving side scores.' : 'Well played. Start a new game when you are ready for the next one.', style: const TextStyle(color: Color(0xFF6B776F), fontSize: 11, height: 1.4)),
        ],
      );

  Widget _rallyButton(int side) {
    final name = side == 0 ? match.homeName : match.awayName;
    return SizedBox(
      height: 54,
      child: FilledButton.tonalIcon(
        key: ValueKey('rally-$side'),
        onPressed: match.winner == null ? () => _rally(side) : null,
        icon: const Icon(Icons.sports_tennis, size: 16),
        label: Text('$name RALLY', maxLines: 1, overflow: TextOverflow.ellipsis),
        style: FilledButton.styleFrom(
          backgroundColor: side == 0 ? const Color(0xFFD7F36A) : const Color(0xFFE2E5DD),
          foregroundColor: const Color(0xFF173D32),
          disabledBackgroundColor: const Color(0xFFE5E5DD),
          disabledForegroundColor: const Color(0xFF939A92),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: .4),
        ),
      ),
    );
  }

  Widget _rulesNote() => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(color: const Color(0xFFE9E9DF), borderRadius: BorderRadius.circular(13), border: Border.all(color: const Color(0xFFDFE0D5))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF53625A)),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                match.mode == MatchMode.doubles
                    ? 'Doubles call: serving score, receiving score, server number. First game service starts at 0-0-2.'
                    : 'Singles call: serving score, receiving score. Serve from the right on an even score, left on odd.',
                style: const TextStyle(color: Color(0xFF53625A), fontSize: 10, height: 1.45),
              ),
            ),
          ],
        ),
      );
}