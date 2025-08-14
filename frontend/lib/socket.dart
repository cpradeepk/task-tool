import 'package:socket_io_client/socket_io_client.dart' as IO;

class Realtime {
  late final IO.Socket socket;
  Realtime(String baseUrl) {
    socket = IO.io(baseUrl, IO.OptionBuilder()
      .setPath('/task/socket.io/')
      .setTransports(['websocket'])
      .disableAutoConnect()
      .build());
  }
  void connect() => socket.connect();
  void on(String event, Function(dynamic) handler) => socket.on(event, (data) => handler(data));
  void dispose() => socket.dispose();
}

