import 'dart:convert';

import 'package:chainreaction/screens/playingpage.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChainReactionGame extends StatefulWidget {
  const ChainReactionGame({super.key});

  @override
  ChainReactionGameState createState() => ChainReactionGameState();
}

class ChainReactionGameState extends State<ChainReactionGame>
    with WidgetsBindingObserver {
  int numberOfPlayers = 2;
  bool hasSavedGame = false;

  static const double buttonWidth = 160.0;
  static const double buttonHeight = 50.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkSavedGame();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkSavedGame();
    }
  }

  Future<void> _checkSavedGame() async {
    final prefs = await SharedPreferences.getInstance();
    final savedGame = prefs.getString('savedGame');
    setState(() {
      hasSavedGame = savedGame != null;
    });
  }

  Future<void> _loadGame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedGameStr = prefs.getString('savedGame');
      if (!mounted) return;

      if (savedGameStr != null) {
        final gameState = GameStatesave.fromJson(jsonDecode(savedGameStr));
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlayingPage(
              numberOfPlayers: gameState.numberOfPlayers,
              savedGame: gameState,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading game: $e')),
      );
    }
  }

  Widget _buildGameButton(BuildContext context, {bool isNewGame = true}) {
    return SizedBox(
      width: buttonWidth,
      height: buttonHeight,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        onPressed: isNewGame
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PlayingPage(
                      numberOfPlayers: numberOfPlayers,
                    ),
                  ),
                ).then((_) => _checkSavedGame());
              }
            : () {
                _loadGame().then((_) => _checkSavedGame());
              },
        child: Text(
          isNewGame ? 'New Game' : 'Continue Game',
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color.fromARGB(227, 58, 46, 67),
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Chain Reaction'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _buildGameButton(context), // New Game button
            if (hasSavedGame) ...[
              const SizedBox(height: 16),
              _buildGameButton(context,
                  isNewGame: false), // Continue Game button
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AlwaysDownDropdown(
                  width: buttonWidth,
                  height: buttonHeight,
                  items: const {
                    2: '2 Players',
                    3: '3 Players',
                    4: '4 Players',
                    5: '5 Players'
                  },
                  value: numberOfPlayers,
                  onChanged: (int value) {
                    setState(() {
                      numberOfPlayers = value;
                    });
                  },
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

/// A custom drop-down widget that always displays its menu below the button.
/// This example is tailored for int values, but you can adapt it as needed.
class AlwaysDownDropdown extends StatefulWidget {
  /// A map of [value -> display text] to present in the drop-down menu
  final Map<int, String> items;

  /// The currently selected value
  final int value;

  /// Callback when user selects a new value
  final ValueChanged<int> onChanged;

  /// (Optional) Width of the button, defaults to 160
  final double width;

  /// (Optional) Height of the button, defaults to 50
  final double height;

  const AlwaysDownDropdown({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.width = 160,
    this.height = 50,
  });

  @override
  State<AlwaysDownDropdown> createState() => _AlwaysDownDropdownState();
}

class _AlwaysDownDropdownState extends State<AlwaysDownDropdown> {
  final LayerLink _layerLink = LayerLink();
  bool _isOpen = false;
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  void _toggleOverlay() {
    if (_isOpen) {
      _closeOverlay();
    } else {
      _openOverlay();
    }
    _isOpen = !_isOpen;
    setState(() {});
  }

  void _openOverlay() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _closeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Size size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          offset: Offset(0, size.height),
          showWhenUnlinked: false,
          child: Material(
            elevation: 4,
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: widget.items.entries.map((entry) {
                return InkWell(
                  onTap: () {
                    widget.onChanged(entry.key);
                    _toggleOverlay(); // Close dropdown
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    child: Text(
                      entry.value,
                      style: const TextStyle(fontSize: 16, color: Colors.black),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedText = widget.items[widget.value] ?? 'Select';
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _toggleOverlay,
        child: Container(
          width: widget.width,
          height: widget.height,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                selectedText,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const Icon(Icons.arrow_drop_down, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
