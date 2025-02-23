import 'package:cloud_firestore/cloud_firestore.dart';

class _PlayingPageState extends State<PlayingPage> {
  late final Stream<DocumentSnapshot> gameStream;

  @override
  void initState() {
    super.initState();
    // Assuming you have a game ID to listen to
    gameStream = FirebaseFirestore.instance.collection('games').doc(gameId).snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: gameStream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          // Update your game state based on the snapshot data
          final gameData = snapshot.data!.data() as Map<String, dynamic>;
          // Update your UI based on gameData
        }
        return Container(); // Your game UI here
      },
    );
  }
}