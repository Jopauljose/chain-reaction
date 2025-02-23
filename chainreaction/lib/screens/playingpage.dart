import 'dart:math';
import 'dart:collection';
import 'dart:convert';

import 'package:chainreaction/widgets/atom_widget.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlayingPage extends StatefulWidget {
  final int numberOfPlayers;
  final GameStatesave? savedGame;

  const PlayingPage({
    super.key,
    required this.numberOfPlayers,
    this.savedGame,
  });

  @override
  State<PlayingPage> createState() => _PlayingPageState();
}

class _PlayingPageState extends State<PlayingPage>
    with SingleTickerProviderStateMixin {
  // Global animation variables
  bool _gameover = false;
  late AnimationController _globalAnimationController;
  late Animation<double> _globalAnimation;

  Future<void> _saveGame() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final prefs = await SharedPreferences.getInstance();
      final gameState = GameStatesave(
        orbs: orbs,
        owners: owners,
        isActive: isActive,
        turnCount: turnCount,
        currentPlayer: currentPlayer,
        numberOfPlayers: widget.numberOfPlayers,
      );

      final jsonStr = jsonEncode(gameState.toJson());
      await prefs.setString('savedGame', jsonStr);

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Game saved successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Error saving game: $e')),
        );
      }
    }
  }

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
  late List<List<double>> cellScales;

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

  // Add at class level
  bool _reactionsInProgress = false;

  // Add these variables to track player state
  Set<int> eliminatedPlayers = {};
  Set<int> playersWhoTookTurns = {};

  @override
  void initState() {
    super.initState();
    _gameover = false;
    if (widget.savedGame != null) {
      // Load saved game state
      orbs = widget.savedGame!.orbs;
      owners = widget.savedGame!.owners;
      isActive = widget.savedGame!.isActive;
      turnCount = widget.savedGame!.turnCount;
      currentPlayer = widget.savedGame!.currentPlayer;
    } else {
      // Initialize new game
      orbs = List.generate(rows, (_) => List.generate(cols, (_) => 0));
      owners = List.generate(rows, (_) => List.generate(cols, (_) => -1));
      isActive = List.filled(widget.numberOfPlayers, true);
      turnCount = List.filled(widget.numberOfPlayers, 0);
    }

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

    // Initialize global animation controller
    _globalAnimationController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
    _globalAnimation =
        Tween(begin: 0.0, end: 2 * pi).animate(_globalAnimationController);
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

  // Add new method to check single color
  bool hasSingleColorRemaining() {
    int activeColor = -1;
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (orbs[r][c] > 0) {
          if (activeColor == -1) {
            activeColor = owners[r][c];
          } else if (owners[r][c] != activeColor) {
            return false;
          }
        }
      }
    }
    return activeColor != -1;
  }

  // Add method to get winner
  int getWinner() {
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (orbs[r][c] > 0) {
          return owners[r][c];
        }
      }
    }
    return -1;
  }

  // Update validation in _handleTap
  void _handleTap(int r, int c) async {
    if (!mounted || _reactionsInProgress || _gameover) return;
    if (!isActive[currentPlayer]) return;

    if (orbs[r][c] == 0 || owners[r][c] == currentPlayer) {
      _reactionsInProgress = true;
      _pushToHistory();

      setState(() {
        orbs[r][c]++;
        owners[r][c] = currentPlayer;
        turnCount[currentPlayer]++;
        playersWhoTookTurns.add(currentPlayer); // Track who took turns
      });

      final allPlayersHadOneTurn = turnCount.every((count) => count >= 1);

      await _triggerChainReaction(r, c);
      await completeAllReactions();

      // Check for eliminated players after reactions complete
      if (allPlayersHadOneTurn) {
        checkPlayerElimination();
      }

      // Check winner
      if (allPlayersHadOneTurn && hasSingleColorRemaining()) {
        _showWinDialog(getWinner());
        return;
      }

      if (!hasUnstableCells() && !_gameover) {
        do {
          currentPlayer = (currentPlayer + 1) % widget.numberOfPlayers;
        } while (eliminatedPlayers.contains(currentPlayer));
        setState(() {});
      }

      _reactionsInProgress = false;
    }
  }

  /// Optimized chain reaction
  Future<void> _triggerChainReaction(int r, int c) async {
    if (!mounted || _gameover) return;

    var currentLevel = Queue<(int, int)>();
    currentLevel.add((r, c));
    final Set<(int, int)> processedCells = {};

    while (currentLevel.isNotEmpty && !_gameover) {
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
    if (!_gameover) {
      await validateAndCompleteReactions(processedCells);
    }
  }

  /// Updated _showWinDialog method
  Future<void> _showWinDialog(int winner) async {
    final winnerColorName = colorNames[winner];
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          title: const Text('Game Over'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$winnerColorName wins!'),
              const SizedBox(height: 16),
              Text('Player took ${turnCount[winner]} turns'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                // First pop dialog
                Navigator.pop(dialogContext);
                Navigator.pop(context);

                // Then reset game state
                if (mounted) {
                  setState(() {
                    _gameover = false;
                    _reactionsInProgress = false;
                    orbs = List.generate(
                        rows, (_) => List.generate(cols, (_) => 0));
                    owners = List.generate(
                        rows, (_) => List.generate(cols, (_) => -1));
                    isActive = List.filled(widget.numberOfPlayers, true);
                    turnCount = List.filled(widget.numberOfPlayers, 0);
                    currentPlayer = 0;
                    eliminatedPlayers.clear();
                    playersWhoTookTurns.clear();
                    history.clear();
                    cellScales = List.generate(
                        rows, (r) => List.generate(cols, (c) => 1.0));
                    _cachedNeighbors.clear();
                  });
                }
              },
              child: const Text('Play Again'),
            ),
            TextButton(
              onPressed: () {
                // First pop dialog
                Navigator.pop(dialogContext);
                // Then navigate back to main menu
                if (mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
              child: const Text('Main Menu'),
            ),
          ],
        ),
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

  // Updated _buildOrbDisplay method to use global animation value
  Widget _buildOrbDisplay(int orbCount, Color cellColor, int cellCapacity) {
    return AnimatedBuilder(
      animation: _globalAnimation,
      builder: (context, child) {
        return SizedBox(
          width: 50,
          height: 50,
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: List.generate(orbCount, (index) {
                return AtomWidget(
                  color: cellColor,
                  shouldRotate: true,
                  index: index,
                  total: orbCount,
                  animationValue:
                      _globalAnimation.value, // Pass the global value
                );
              }),
            ),
          ),
        );
      },
    );
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

  // Add this method to check if a player's color exists in grid
  bool isPlayerColorInGrid(int playerIndex) {
    for (var row = 0; row < orbs.length; row++) {
      for (var col = 0; col < orbs[row].length; col++) {
        if (orbs[row][col] > 0 && owners[row][col] == playerIndex) {
          return true;
        }
      }
    }
    return false;
  }

  // Add this method to check for player elimination
  void checkPlayerElimination() {
    if (playersWhoTookTurns.length < widget.numberOfPlayers) {
      return;
    }

    for (int i = 0; i < widget.numberOfPlayers; i++) {
      if (!eliminatedPlayers.contains(i) && !isPlayerColorInGrid(i)) {
        setState(() {
          eliminatedPlayers.add(i);
          isActive[i] = false; // Mark player as inactive
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${colorNames[i]} has been eliminated!'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }

    // Check if only one player remains
    final activePlayers = isActive.where((active) => active).toList();
    if (activePlayers.length == 1) {
      final winner = isActive.indexOf(true);
      if (winner != -1 && !_gameover) {
        setState(() {
          _gameover = true;
        });
        _showWinDialog(winner);
      }
    }
  }

  // Modify your turn handling method to track turns and check elimination
  void handlePlayerTurn(int row, int col) {
    // Add current player to the set of players who took turns
    playersWhoTookTurns.add(currentPlayer);

    // ... existing turn logic ...

    // After move is complete, check for elimination
    checkPlayerElimination();

    // Update current player, skipping eliminated players
    do {
      currentPlayer = (currentPlayer + 1) % widget.numberOfPlayers;
    } while (eliminatedPlayers.contains(currentPlayer));
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
            icon: const Icon(Icons.save),
            onPressed: _saveGame,
            tooltip: 'Save game',
          ),
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
                          margin: const EdgeInsets.all(1),
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(200),
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
    _globalAnimationController.dispose();
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

class GameStatesave {
  final List<List<int>> orbs;
  final List<List<int>> owners;
  final List<bool> isActive;
  final List<int> turnCount;
  final int currentPlayer;
  final int numberOfPlayers;

  GameStatesave({
    required this.orbs,
    required this.owners,
    required this.isActive,
    required this.turnCount,
    required this.currentPlayer,
    required this.numberOfPlayers,
  });

  Map<String, dynamic> toJson() => {
        'orbs': orbs.map((row) => row.toList()).toList(),
        'owners': owners.map((row) => row.toList()).toList(),
        'isActive': isActive.toList(),
        'turnCount': turnCount.toList(),
        'currentPlayer': currentPlayer,
        'numberOfPlayers': numberOfPlayers,
      };

  factory GameStatesave.fromJson(Map<String, dynamic> json) {
    return GameStatesave(
      orbs: (json['orbs'] as List)
          .map((row) => List<int>.from(row as List))
          .toList(),
      owners: (json['owners'] as List)
          .map((row) => List<int>.from(row as List))
          .toList(),
      isActive: List<bool>.from(json['isActive'] as List),
      turnCount: List<int>.from(json['turnCount'] as List),
      currentPlayer: json['currentPlayer'] as int,
      numberOfPlayers: json['numberOfPlayers'] as int,
    );
  }
}
