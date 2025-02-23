import 'package:cloud_firestore/cloud_firestore.dart';

class _PlayingPageState extends State<PlayingPage> {
  late final CollectionReference gameCollection;

  @override
  void initState() {
    super.initState();
    gameCollection = FirebaseFirestore.instance.collection('games');
    _listenToGameUpdates();
  }

  void _listenToGameUpdates() {
    gameCollection.doc('gameId').snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data();
        // Update your game state based on the data received
        setState(() {
          // Update your game state variables here
        });
      }
    });
  }

  Future<void> _makeMove(int playerId, Move move) async {
    // Update the game state in Firestore
    await gameCollection.doc('gameId').update({
      'currentPlayer': playerId,
      'gameState': updatedGameState,
    });
  }
}