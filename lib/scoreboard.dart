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
      return copyWith(
        servingSide: 1 - servingSide,
        serverNumber: 1,
        openingSequence: false,
      );
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
  );
}

class PickleScorerApp extends StatelessWidget {
  const PickleScorerApp({super.key});

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
        content: const Text(
          'The current score and rally history will be cleared.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep playing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('New game'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      match = match.copyWith(
        homeScore: 0,
        awayScore: 0,
        servingSide: 0,
        serverNumber: 2,
        openingSequence: true,
      );
      history.clear();
    });
  }

  Future<void> _rename(int side) async {
    final controller = TextEditingController(
      text: side == 0 ? match.homeName : match.awayName,
    );
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || !mounted) return;
    setState(
      () => match = side == 0
          ? match.copyWith(homeName: name)
          : match.copyWith(awayName: name),
    );
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
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Change format'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      match = match.copyWith(
        mode: mode,
        homeScore: 0,
        awayScore: 0,
        servingSide: 0,
        serverNumber: 2,
        openingSequence: true,
      );
      history.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final winner = match.winner == 0
        ? match.homeName
        : match.winner == 1
        ? match.awayName
        : null;
    final server = match.servingSide == 0 ? match.homeName : match.awayName;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 600,
                  minHeight: constraints.maxHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _header(),
                          const SizedBox(height: 16),
                          _formatControls(),
                          const SizedBox(height: 16),
                          _board(server, winner),
                          const SizedBox(height: 16),
                          _scoreCall(server, winner),
                        ],
                      ),
                      const SizedBox(height: 30),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _rallyControls(winner),
                          const SizedBox(height: 10),
                          _rulesNote(),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

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
        tooltip: 'New game',
        onPressed: _newGame,
        icon: Icons.restart_alt_rounded,
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
    onSelectionChanged: (value) =>
        setState(() => match = match.copyWith(target: value.first)),
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

  Widget _board(String server, String? winner) => Container(
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
            Expanded(child: _team(0, winner)),
            Container(width: 3, color: const Color(0xFFB6CCD0)),
            Expanded(child: _team(1, winner)),
          ],
        ),
      ),
    ),
  );

  Widget _team(int side, String? winner) {
    final name = side == 0 ? match.homeName : match.awayName;
    final score = side == 0 ? match.homeScore : match.awayScore;
    final serving = match.servingSide == side && match.winner == null;
    return Material(
      color: side == 0 ? const Color(0xFF20538E) : const Color(0xFF1D5954),
      child: InkWell(
        onTap: () => _rename(side),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 15),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$score',
                  style: TextStyle(
                    color: side == match.servingSide
                        ? Colors.white
                        : const Color(0xFFD9E0E3),
                    fontSize: 136,
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

  Widget _rallyControls(String? winner) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        winner == null
            ? 'Who won the rally?'
            : 'Who won the rally?  ·  Game over',
        style: const TextStyle(
          color: Color(0xFF536B80),
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(child: _rallyButton(0)),
          const SizedBox(width: 10),
          Expanded(child: _rallyButton(1)),
        ],
      ),
    ],
  );

  Widget _rallyButton(int side) {
    final name = side == 0 ? match.homeName : match.awayName;
    return SizedBox(
      height: 83,
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
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            const Text(
              'won the rally',
              style: TextStyle(
                fontSize: 12,
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
        ? 'Call: serving score, receiving score, server number. The first service of a game starts at 0-0-2. Only the serving side scores; losing the rally passes service.'
        : 'Call: serving score, receiving score. Serve from the right on an even score and left on an odd score. Only the serving side scores; losing the rally passes service.',
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
