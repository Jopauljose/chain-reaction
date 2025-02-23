import 'package:cloud_firestore/cloud_firestore.dart';

class GameService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> createGame(String gameId, GameState gameState) {
    return _db.collection('games').doc(gameId).set(gameState.toJson());
  }

  Stream<GameState> getGameStream(String gameId) {
    return _db.collection('games').doc(gameId).snapshots().map((snapshot) {
      return GameState.fromJson(snapshot.data());
    });
  }

  Future<void> makeMove(String gameId, Move move) {
    return _db.collection('games').doc(gameId).update({
      'moves': FieldValue.arrayUnion([move.toJson()]),
      // Update other game state as necessary
    });
  }
}