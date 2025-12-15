import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dart_ping/dart_ping.dart';
import 'package:flutter/foundation.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:permission_handler/permission_handler.dart';

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

  // --- INFORMAÇÕES DE WI-FI ---
  /// Obtém informações detalhadas da rede Wi-Fi conectada
  /// Retorna um Map com SSID, BSSID, sinal, frequência e IP
  /// Retorna null se não estiver conectado via Wi-Fi ou se houver erro
  Future<Map<String, dynamic>?> getWiFiInfo() async {
    try {
      // Verifica se está conectado via Wi-Fi
      final connectionType = await getConnectionType();
      if (connectionType['type'] != 'Wi-Fi') {
        return null;
      }

      // Verifica se Wi-Fi está habilitado
      final isEnabled = await WiFiForIoTPlugin.isEnabled();
      if (!isEnabled) {
        return {'error': 'Wi-Fi desativado'};
      }

      // Verifica e solicita permissão de localização
      await _checkLocationPermission();

      // Obtém informações da rede
      final ssid = await WiFiForIoTPlugin.getSSID();
      final bssid = await WiFiForIoTPlugin.getBSSID();
      final signal = await WiFiForIoTPlugin.getCurrentSignalStrength();
      final frequency = await WiFiForIoTPlugin.getFrequency();
      final ip = await WiFiForIoTPlugin.getIP();

      if (kDebugMode) {
        print('''
        [******WiFi Info*****]
        SSID: ${ssid ?? 'SSID desconhecido'}
        BSSID: ${bssid ?? 'BSSID desconhecido'}
        Sinal: ${signal ?? '?'} dBm
        Frequência: ${frequency ?? '?'} MHz
        IP: ${ip ?? 'IP desconhecido'}
        ''');
      }

      return {
        'ssid': ssid ?? 'SSID desconhecido',
        'bssid': bssid ?? 'BSSID desconhecido',
        'signal': signal,
        'frequency': frequency,
        'ip': ip ?? 'IP desconhecido',
      };
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao obter informações Wi-Fi: $e');
      }
      return {'error': 'Erro ao obter informações: ${e.toString()}'};
    }
  }

  /// Verifica e solicita permissão de localização se necessário
  Future<void> _checkLocationPermission() async {
    final status = await Permission.location.status;

    if (!status.isGranted) {
      final result = await Permission.location.request();
      if (!result.isGranted) {
        if (kDebugMode) {
          print('[PERMISSÃO] Localização negada - informações de Wi-Fi podem estar limitadas');
        }
      }
    }
  }
}

