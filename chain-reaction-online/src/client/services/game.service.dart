import 'package:web_socket_channel/web_socket_channel.dart';

class _PlayingPageState extends State<PlayingPage> {
  late WebSocketChannel channel;

  @override
  void initState() {
    super.initState();
    channel = WebSocketChannel.connect(
      Uri.parse('wss://your-websocket-server.com'),
    );

    channel.stream.listen((data) {
      // Handle incoming data (e.g., update game state)
      setState(() {
        // Update your game state based on the received data
      });
    });
  }

  void _sendMove(String move) {
    channel.sink.add(move); // Send the player's move to the server
  }

  @override
  void dispose() {
    channel.sink.close();
    super.dispose();
  }
}