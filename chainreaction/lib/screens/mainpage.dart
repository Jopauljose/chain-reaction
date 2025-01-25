import 'package:chainreaction/screens/playingpage.dart';
import 'package:flutter/material.dart';

class ChainReactionGame extends StatefulWidget {
  const ChainReactionGame({super.key});

  @override
  ChainReactionGameState createState() => ChainReactionGameState();
}

class ChainReactionGameState extends State<ChainReactionGame> {
  int numberOfPlayers = 2;

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
            // Simple dropdown to control numberOfPlayers

            startbutton(context),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AlwaysDownDropdown(
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

  GestureDetector startbutton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlayingPage(
              numberOfPlayers: numberOfPlayers,
            ),
          ),
        );
      },
      child: Container(
        width: 160,
        height: 60,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Start Game',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
              ),
            ),
            Icon(Icons.play_arrow, color: Colors.white),
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
