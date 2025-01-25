import 'dart:collection';
import 'package:chainreaction/widgets/atom_widget.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class PlayingPage extends StatefulWidget {
  final int numberOfPlayers;
  final int representationMode; // 0 -> Numbers, 1 -> Dots

  const PlayingPage({
    super.key,
    required this.numberOfPlayers,
    required this.representationMode,
  });

  @override
  State<PlayingPage> createState() => _PlayingPageState();
}

class _PlayingPageState extends State<PlayingPage> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Use const for rows & cols if they never change
  static const int rows = 14;
  static const int cols = 7;

  late List<List<int>> orbs;
  late List<List<int>> owners;
  late List<bool> isActive;
  late List<int> turnCount;
  late List<List<double>> cellScales; // Add this line after other late vars

  int currentPlayer = 0;

  // Add these properties to class
  late double cellWidth;
  late double cellHeight;
  late double gridWidth;
  late double gridHeight;

  // History stack to store previous states
  final List<GameState> history = [];

  final List<Color> playerColors = [
    Colors.cyan,
    Colors.orange,
    Colors.blue,
    Colors.purple,
    Colors.red,
    Colors.green,
  ];

  final List<String> colorNames = [
    'cyan',
    'Orange',
    'Blue',
    'Purple',
    'Red',
    'Green',
  ];

  // Add cached neighbors map
  final Map<String, List<(int, int)>> _cachedNeighbors = {};

  // Add pending updates tracking
  final Map<String, Queue<(int, int)>> pendingUpdates = {};

  Future<void> _playSplitSound() async {
    await _audioPlayer.play(AssetSource('split.mp3'));
  }

  @override
  void initState() {
    super.initState();
    orbs = List.generate(rows, (_) => List.generate(cols, (_) => 0));
    owners = List.generate(rows, (_) => List.generate(cols, (_) => -1));
    isActive = List.filled(widget.numberOfPlayers, true);
    turnCount = List.filled(widget.numberOfPlayers, 0);
    cellScales = List.generate(
      rows,
      (r) => List.generate(cols, (c) => 1.0),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = MediaQuery.of(context).size;
      setState(() {
        gridWidth = size.width * 0.9;
        gridHeight = size.height * 0.8;
        cellWidth = gridWidth / cols;
        cellHeight = gridHeight / rows;
      });
    });
  }

  // Function to push current state to history
  void _pushToHistory() {
    history.add(GameState(
      orbs: _deepCopy(orbs),
      owners: _deepCopy(owners),
      isActive: List<bool>.from(isActive),
      turnCount: List<int>.from(turnCount),
      currentPlayer: currentPlayer,
    ));
  }

  // Deep copy utility for 2D lists
  List<List<int>> _deepCopy(List<List<int>> original) {
    return original.map((row) => List<int>.from(row)).toList();
  }

  void _handleTap(int r, int c) async {
    if (!isActive[currentPlayer]) return;
    if (orbs[r][c] == 0 || owners[r][c] == currentPlayer) {
      // Push current state to history before making changes
      _pushToHistory();

      setState(() {
        orbs[r][c]++;
        owners[r][c] = currentPlayer;
        turnCount[currentPlayer]++;
      });
      // Trigger chain reaction asynchronously
      await _triggerChainReaction(r, c);

      // Only check elimination if every player has had at least one turn
      final allPlayersHadOneTurn = turnCount.every((count) => count >= 1);
      if (allPlayersHadOneTurn) {
        _checkForElimination();
      }

      _nextPlayer();
    }
  }

  /// Optimized chain reaction
  Future<void> _triggerChainReaction(int r, int c) async {
    if (!mounted) return;

    var currentLevel = Queue<(int, int)>();
    currentLevel.add((r, c));

    const animationDuration = Duration(milliseconds: 200);

    try {
      while (currentLevel.isNotEmpty) {
        final nextLevel = Queue<(int, int)>();
        final explosionsThisLevel =
            <(int, int)>{}; // Use Set to prevent duplicates

        // Process current level
        for (final cell in currentLevel) {
          final (cr, cc) = cell;
          if (cr >= 0 && cr < rows && cc >= 0 && cc < cols) {
            // Check if cell should explode
            if (orbs[cr][cc] >= _neighbors(cr, cc).length) {
              explosionsThisLevel.add(cell);
            }
          }
        }

        if (explosionsThisLevel.isNotEmpty) {
          await _playSplitSound();

          // Process explosions with collision handling
          for (final (cr, cc) in explosionsThisLevel) {
            final neighbors = _neighbors(cr, cc);
            final cap = neighbors.length;
            final cellOwner = owners[cr][cc];

            // Update exploding cell
            setState(() {
              orbs[cr][cc] -= cap;
              // Reset owner if no orbs left
              if (orbs[cr][cc] == 0) {
                owners[cr][cc] = -1;
              }
            });

            // Distribute orbs to neighbors
            for (final (nr, nc) in neighbors) {
              if (nr >= 0 && nr < rows && nc >= 0 && nc < cols) {
                setState(() {
                  orbs[nr][nc]++;
                  owners[nr][nc] = cellOwner;
                });

                // Check if neighbor should be added to next level
                final key = '$nr-$nc';
                if (!pendingUpdates.containsKey(key)) {
                  pendingUpdates[key] = Queue<(int, int)>();
                }
                pendingUpdates[key]!.add((nr, nc));

                if (orbs[nr][nc] >= _neighbors(nr, nc).length) {
                  nextLevel.add((nr, nc));
                }
              }
            }
          }

          await Future.delayed(animationDuration);
        }

        // Clear processed updates
        for (var cell in explosionsThisLevel) {
          final (r, c) = cell;
          pendingUpdates.remove('$r-$c');
        }

        currentLevel = nextLevel;
      }
    } catch (e) {
      debugPrint('Chain reaction error: $e');
    } finally {
      pendingUpdates.clear();
    }
    setState(() {
      cellScales[r][c] = 1.2; // Scale up
    });
    await Future.delayed(const Duration(milliseconds: 100));
    setState(() {
      cellScales[r][c] = 1.0; // Scale back
    });
    await _audioPlayer.play(AssetSource('split.mp3'));
  }

  void _checkForElimination() {
    final counts = List.filled(widget.numberOfPlayers, 0);
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final owner = owners[r][c];
        if (owner >= 0) {
          counts[owner]++;
        }
      }
    }
    for (int p = 0; p < widget.numberOfPlayers; p++) {
      if (counts[p] == 0) {
        isActive[p] = false;
      }
    }
    final stillIn = isActive.where((active) => active).length;
    if (stillIn == 1) {
      final winner = isActive.indexWhere((p) => p);
      _showWinDialog(winner);
    }
  }

  void _nextPlayer() {
    do {
      currentPlayer = (currentPlayer + 1) % widget.numberOfPlayers;
    } while (!isActive[currentPlayer]);
    setState(() {});
  }

  /// Updated _showWinDialog method
  Future<void> _showWinDialog(int winner) async {
    final winnerColorName = colorNames[winner];
    await showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissal by tapping outside
      builder: (_) => AlertDialog(
        title: const Text('Game Over'),
        content: Text('$winnerColorName wins!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close the dialog
              Navigator.pop(context); // Navigate back to main page
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Optimize neighbor calculation
  List<(int, int)> _neighbors(int r, int c) {
    final key = '$r-$c';
    if (_cachedNeighbors.containsKey(key)) {
      return _cachedNeighbors[key]!;
    }

    final neighbors = <(int, int)>[];
    if (r > 0) neighbors.add((r - 1, c));
    if (r < rows - 1) neighbors.add((r + 1, c));
    if (c > 0) neighbors.add((r, c - 1));
    if (c < cols - 1) neighbors.add((r, c + 1));

    _cachedNeighbors[key] = neighbors;
    return neighbors;
  }

  Widget _buildOrbDisplay(int orbCount, Color cellColor, int cellCapacity) {
    if (widget.representationMode == 0) {
      return Text(
        '$orbCount',
        style: const TextStyle(color: Colors.white, fontSize: 12),
      );
    } else {
      return Stack(
        children: List.generate(orbCount, (index) {
          final offset = _getAtomOffset(index, orbCount);
          return Positioned(
            left: offset.dx,
            top: offset.dy,
            child: AtomWidget(
              color: cellColor,
              shouldRotate: orbCount > 1 && orbCount < 4,
            ),
          );
        }),
      );
    }
  }

  Offset _getAtomOffset(int index, int total) {
    switch (total) {
      case 1:
        return const Offset(15, 15);
      case 2:
        return index == 0 ? const Offset(10, 15) : const Offset(20, 15);
      case 3:
        switch (index) {
          case 0:
            return const Offset(15, 8);
          case 1:
            return const Offset(8, 22);
          case 2:
            return const Offset(22, 22);
          default:
            return const Offset(15, 15);
        }
      default:
        return const Offset(15, 15);
    }
  }

  /// Undo the last action
  void _undo() {
    if (history.isNotEmpty) {
      final lastState = history.removeLast();
      setState(() {
        orbs = _deepCopy(lastState.orbs);
        owners = _deepCopy(lastState.owners);
        isActive = List<bool>.from(lastState.isActive);
        turnCount = List<int>.from(lastState.turnCount);
        currentPlayer = lastState.currentPlayer;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = playerColors[currentPlayer % widget.numberOfPlayers];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Players: ${widget.numberOfPlayers}',
          style: const TextStyle(fontSize: 18),
        ),
        backgroundColor: borderColor, // Indicate current player's turn
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Undo',
            onPressed: history.isNotEmpty ? _undo : null,
          ),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal, // Allow horizontal scrolling
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical, // Allow vertical scrolling
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(rows, (r) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(cols, (c) {
                        final owner = owners[r][c];
                        final orbCount = orbs[r][c];
                        final cellCapacity = _neighbors(r, c).length;
                        final cellColor = owner == -1
                            ? Colors.black
                            : playerColors[owner % widget.numberOfPlayers];
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.all(
                              1), // Reduced margin for larger grid
                          width: 50, // Set to accommodate 15 rows and 8 cols
                          height: 50,
                          decoration: BoxDecoration(
                            color: cellColor.withAlpha(2),
                            border: Border.all(color: borderColor, width: 2),
                          ),
                          child: InkWell(
                            onTap: () => _handleTap(r, c),
                            child: Center(
                              child: Transform.scale(
                                scale: cellScales[r][c],
                                child: _buildOrbDisplay(
                                  orbCount,
                                  cellColor,
                                  cellCapacity,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cachedNeighbors.clear();
    pendingUpdates.clear();
    super.dispose();
  }
}

/// Class to hold the game state for undo functionality
class GameState {
  final List<List<int>> orbs;
  final List<List<int>> owners;
  final List<bool> isActive;
  final List<int> turnCount;
  final int currentPlayer;

  GameState({
    required this.orbs,
    required this.owners,
    required this.isActive,
    required this.turnCount,
    required this.currentPlayer,
  });
}
