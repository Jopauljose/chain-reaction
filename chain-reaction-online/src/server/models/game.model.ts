void makeMove(int playerId, Move move) {
  // Update the game state
  gameState.update(move);
  
  // Send the updated game state to Firebase
  FirebaseDatabase.instance
      .reference()
      .child('games/$gameId')
      .set(gameState.toJson());
}