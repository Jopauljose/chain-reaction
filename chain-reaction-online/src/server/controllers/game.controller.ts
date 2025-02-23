   FirebaseFirestore.instance
       .collection('games')
       .doc(gameId)
       .snapshots()
       .listen((snapshot) {
         if (snapshot.exists) {
           // Update your game state based on the snapshot data
         }
       });