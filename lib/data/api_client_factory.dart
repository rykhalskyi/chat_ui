import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

class ApiClientFactory {
  const ApiClientFactory({this.clientFactory});

  final http.Client Function()? clientFactory;

  http.Client create({String? connectAddress}) {
    final testFactory = clientFactory;
    if (testFactory != null) {
      return testFactory();
    }
    final override = connectAddress?.trim() ?? '';
    final inner = HttpClient();
    if (override.isNotEmpty) {
      inner.connectionFactory = (uri, proxyHost, proxyPort) async {
        final task = await Socket.startConnect(
          proxyHost ?? override,
          proxyPort ?? uri.port,
        ).timeout(const Duration(seconds: 15));
        if (uri.scheme != 'https') {
          return task;
        }
        SecureSocket? secureSocket;
        final socketFuture = () async {
          final raw = await task.socket;
          secureSocket = await SecureSocket.secure(
            raw,
            host: uri.host,
          ).timeout(const Duration(seconds: 15));
          return secureSocket!;
        }();
        return ConnectionTask.fromSocket<Socket>(socketFuture, () {
          task.cancel();
          secureSocket?.destroy();
        });
      };
    }
    return IOClient(inner);
  }
}
