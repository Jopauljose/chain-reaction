import 'dart:collection';
import 'package:chainreaction/widgets/atom_widget.dart';
import 'package:flutter/material.dart';

class PlayingPage extends StatefulWidget {
  final int numberOfPlayers;

  const PlayingPage({
    super.key,
    required this.numberOfPlayers,
  });

  @override
  State<PlayingPage> createState() => _PlayingPageState();
}

class _PlayingPageState extends State<PlayingPage> {
  static const int rows = 14;
  static const int cols = 7;

  static const animationDuration = Duration(milliseconds: 300);
  static const explosionDelay = Duration(milliseconds: 150);
  static const distributionDelay = Duration(milliseconds: 100);

  // Remove maxIterations constant

  // Add isUnstable helper method
  bool isUnstable(int r, int c) {
    return orbs[r][c] >= _neighbors(r, c).length;
  }

  // Add validation method
  Future<void> validateAndCompleteReactions(
      Set<(int, int)> processedCells) async {
    bool hasUnstable = true;
    while (hasUnstable) {
      hasUnstable = false;
      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          if (!processedCells.contains((r, c)) && isUnstable(r, c)) {
            hasUnstable = true;
            await _triggerChainReaction(r, c);
            processedCells.add((r, c));
          }
        }
      }
    }
  }

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

  // Add corner positions constant
  static const corners = {
    (0, 0),
    (0, cols - 1),
    (rows - 1, 0),
    (rows - 1, cols - 1)
  };

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

  // Add these helper methods at class level
  bool hasUnstableCells() {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (isUnstable(r, c)) {
          return true;
        }
      }
    }
    return false;
  }

  Future<void> completeAllReactions() async {
    while (hasUnstableCells()) {
      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          if (isUnstable(r, c)) {
            await _triggerChainReaction(r, c);
          }
        }
      }
    }
  }

  // Update validation in _handleTap
  void _handleTap(int r, int c) async {
    if (!mounted) return;

    // Add corner capacity check
    final isCorner = corners.contains((r, c));
    final neighborCount = _neighbors(r, c).length;

    if (orbs[r][c] > (isCorner ? 1 : neighborCount)) {
      // Fix illegal state
      setState(() {
        orbs[r][c] = isCorner ? 1 : neighborCount;
      });
    }

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
      await completeAllReactions(); // Add this line

      // Only check elimination if every player has had at least one turn
      final allPlayersHadOneTurn = turnCount.every((count) => count >= 1);
      if (allPlayersHadOneTurn) {
        _checkForElimination();
      }

      if (!hasUnstableCells()) {
        // Only change turn if no unstable cells
        _nextPlayer();
      }
    }
  }

  /// Optimized chain reaction
  Future<void> _triggerChainReaction(int r, int c) async {
    if (!mounted) return;

    var currentLevel = Queue<(int, int)>();
    currentLevel.add((r, c));
    final Set<(int, int)> processedCells = {};

    while (currentLevel.isNotEmpty) {
      final nextLevel = Queue<(int, int)>();
      final explosionsThisLevel = <(int, int)>{};
      final affectedCells = <(int, int)>{};
      final updates = <(int, int, int, int)>[];

      // Collect ALL unstable cells for this level
      for (final cell in currentLevel) {
        final (cr, cc) = cell;
        if (!processedCells.contains((cr, cc)) &&
            cr >= 0 &&
            cr < rows &&
            cc >= 0 &&
            cc < cols &&
            orbs[cr][cc] >= _neighbors(cr, cc).length) {
          explosionsThisLevel.add(cell);
          processedCells.add((cr, cc));
        }
      }

      if (explosionsThisLevel.isNotEmpty) {
        // Process explosions
        setState(() {
          for (final (cr, cc) in explosionsThisLevel) {
            cellScales[cr][cc] = 1.25;
          }
        });
        await Future.delayed(explosionDelay);

        // Collect ALL updates
        for (final (cr, cc) in explosionsThisLevel) {
          final neighbors = _neighbors(cr, cc);
          final cap = neighbors.length;
          final cellOwner = owners[cr][cc];

          setState(() {
            cellScales[cr][cc] = 0.95;
            orbs[cr][cc] -= cap;
            if (orbs[cr][cc] == 0) owners[cr][cc] = -1;
          });

          for (final (nr, nc) in neighbors) {
            if (nr >= 0 && nr < rows && nc >= 0 && nc < cols) {
              updates.add((nr, nc, 1, cellOwner));
              affectedCells.add((nr, nc));
            }
          }
        }

        // Apply ALL updates simultaneously
        setState(() {
          for (final (r, c, count, owner) in updates) {
            orbs[r][c] += count;
            owners[r][c] = owner;
            cellScales[r][c] = 1.15;
          }
        });

        // Check for new unstable cells
        for (int r = 0; r < rows; r++) {
          for (int c = 0; c < cols; c++) {
            if (!processedCells.contains((r, c)) &&
                orbs[r][c] >= _neighbors(r, c).length) {
              nextLevel.add((r, c));
            }
          }
        }

        await Future.delayed(distributionDelay);

        setState(() {
          for (final (r, c) in affectedCells.union(explosionsThisLevel)) {
            cellScales[r][c] = 1.0;
          }
        });
      }

      currentLevel = nextLevel;
    }

    // Add final validation
    await validateAndCompleteReactions(processedCells);
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

  // Update _neighbors method to handle corners correctly
  List<(int, int)> _neighbors(int r, int c) {
    final key = '$r-$c';
    if (_cachedNeighbors.containsKey(key)) {
      return _cachedNeighbors[key]!;
    }

    final neighbors = <(int, int)>[];

    // Check if corner position
    if (corners.contains((r, c))) {
      // Corners only have 2 neighbors
      if (r == 0 && c == 0) {
        neighbors.addAll([(0, 1), (1, 0)]);
      } else if (r == 0 && c == cols - 1) {
        neighbors.addAll([(0, cols - 2), (1, cols - 1)]);
      } else if (r == rows - 1 && c == 0) {
        neighbors.addAll([(rows - 2, 0), (rows - 1, 1)]);
      } else if (r == rows - 1 && c == cols - 1) {
        neighbors.addAll([(rows - 2, cols - 1), (rows - 1, cols - 2)]);
      }
    } else {
      if (r > 0) neighbors.add((r - 1, c));
      if (r < rows - 1) neighbors.add((r + 1, c));
      if (c > 0) neighbors.add((r, c - 1));
      if (c < cols - 1) neighbors.add((r, c + 1));
    }

    _cachedNeighbors[key] = neighbors;
    return neighbors;
  }

  Widget _buildOrbDisplay(int orbCount, Color cellColor, int cellCapacity) {
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
                          duration: animationDuration,
                          curve: Curves.easeInOutCubic,
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
                              child: AnimatedScale(
                                duration: animationDuration,
                                curve: Curves.easeOutBack,
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
