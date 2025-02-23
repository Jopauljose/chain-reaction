Future<void> createGameRoom() async {
  final gameRoomRef = FirebaseFirestore.instance.collection('gameRooms').doc();
  await gameRoomRef.set({
    'players': [],
    'gameState': {}, // Initialize your game state here
  });
}