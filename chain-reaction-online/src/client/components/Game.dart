import 'package:web_socket_channel/web_socket_channel.dart';

class _PlayingPageState extends State<PlayingPage> {
  late WebSocketChannel channel;

  @override
  void initState() {
    super.initState();
    channel = WebSocketChannel.connect(
      Uri.parse('ws://yourserver.com/socket'),
    );

    channel.stream.listen((message) {
      // Handle incoming messages (e.g., update game state)
      final data = jsonDecode(message);
      // Update your game state based on the data received
    });
  }

  void _makeMove(int move) {
    // Send the move to the server
    channel.sink.add(jsonEncode({'move': move, 'playerId': currentPlayer}));
  }

  @override
  void dispose() {
    channel.sink.close();
    super.dispose();
  }
}