import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class MultiplayerGame extends StatefulWidget {
  @override
  _MultiplayerGameState createState() => _MultiplayerGameState();
}

class _MultiplayerGameState extends State<MultiplayerGame> {
  late WebSocketChannel channel;

  @override
  void initState() {
    super.initState();
    channel = WebSocketChannel.connect(
      Uri.parse('ws://yourserver.com/socket'),
    );

    channel.stream.listen((message) {
      // Handle incoming messages (game state updates)
      print(message);
    });
  }

  void sendMove(String move) {
    channel.sink.add(move); // Send player's move to the server
  }

  @override
  void dispose() {
    channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Multiplayer Game')),
      body: Center(
        child: ElevatedButton(
          onPressed: () => sendMove('player_move_data'),
          child: Text('Make Move'),
        ),
      ),
    );
  }
}