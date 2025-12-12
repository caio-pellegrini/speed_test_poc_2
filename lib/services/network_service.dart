import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dart_ping/dart_ping.dart';
import 'package:flutter/foundation.dart';

class NetworkService {
  final Connectivity _connectivity = Connectivity();
  bool _isCancelled = false;

  // --- TIPO DE CONEXÃO ---
  Future<Map<String, dynamic>> getConnectionType() async {
    try {
      final List<ConnectivityResult> results =
          await _connectivity.checkConnectivity();

      // Lógica de prioridade do Android: Ethernet > Wifi > Mobile > Bluetooth
      if (results.contains(ConnectivityResult.ethernet)) {
        return {'type': 'Cabo (Ethernet)', 'icon': 0}; // 0 = Icone Cabo
      } else if (results.contains(ConnectivityResult.wifi)) {
        return {'type': 'Wi-Fi', 'icon': 1}; // 1 = Icone Wifi
      } else if (results.contains(ConnectivityResult.mobile)) {
        return {'type': 'Dados Móveis (4G/5G)', 'icon': 2}; // 2 = Icone Celular
      } else if (results.contains(ConnectivityResult.bluetooth)) {
        return {'type': 'Bluetooth', 'icon': 4}; // 4 = Icone Bluetooth
      } else if (results.contains(ConnectivityResult.none)) {
        return {'type': 'Sem Conexão', 'icon': 3};
      } else {
        return {'type': 'Outro', 'icon': 5};
      }
    } catch (e) {
      return {'type': 'Desconhecido', 'icon': 5};
    }
  }

  // --- LATÊNCIA (PING) ---
  Future<int> testLatency({String host = '8.8.8.8'}) async {
    _isCancelled = false;
    final ping = Ping(host, count: 5);
    int totalTime = 0;
    int successCount = 0;

    try {
      await for (final PingData data in ping.stream) {
        if (_isCancelled) return 0;
        if (data.response != null && data.response!.time != null) {
          totalTime += data.response!.time!.inMilliseconds;
          successCount++;
        }
      }
    } catch (e) {
      if (kDebugMode) print("Erro no ping: $e");
      return -1;
    }

    if (successCount == 0) return -1;
    return (totalTime / successCount).round();
  }

  void cancelLatencyTest() {
    _isCancelled = true;
  }
}

