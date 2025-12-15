import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dart_ping/dart_ping.dart';
import 'package:flutter/foundation.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:sim_card_info/sim_card_info.dart';
import 'package:network_type_detector/network_type_detector.dart';

class NetworkService {
  final Connectivity _connectivity = Connectivity();
  final NetworkInfo _networkInfo = NetworkInfo();
  bool _isCancelled = false;

  // --- TIPO DE CONEXÃO ---
  Future<Map<String, dynamic>> getConnectionType() async {
    try {
      final List<ConnectivityResult> results =
          await _connectivity.checkConnectivity();
      return _convertConnectivityResults(results);
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao obter tipo de conexão: $e');
      }
      return {'type': 'Desconhecido', 'icon': 5};
    }
  }

  /// Converte uma lista de ConnectivityResult para o formato Map usado na UI
  Map<String, dynamic> _convertConnectivityResults(
      List<ConnectivityResult> results) {
    // Lógica de prioridade do Android: Ethernet > Wifi > Mobile > Bluetooth
    if (results.contains(ConnectivityResult.ethernet)) {
      return {'type': 'Cabo (Ethernet)', 'icon': 0}; // 0 = Icone Cabo
    } else if (results.contains(ConnectivityResult.wifi)) {
      return {'type': 'Wi-Fi', 'icon': 1}; // 1 = Icone Wifi
    } else if (results.contains(ConnectivityResult.mobile)) {
      return {'type': 'Dados Móveis', 'icon': 2}; // 2 = Icone Celular
    } else if (results.contains(ConnectivityResult.bluetooth)) {
      return {'type': 'Bluetooth', 'icon': 4}; // 4 = Icone Bluetooth
    } else if (results.contains(ConnectivityResult.none)) {
      return {'type': 'Sem Conexão', 'icon': 3};
    } else {
      return {'type': 'Outro', 'icon': 5};
    }
  }

  /// Retorna um Stream que emite mudanças no tipo de conexão
  /// O stream escuta mudanças de conectividade e converte para o formato usado na UI
  Stream<Map<String, dynamic>> getConnectionTypeStream() {
    return _connectivity.onConnectivityChanged
        .map((List<ConnectivityResult> results) {
      try {
        return _convertConnectivityResults(results);
      } catch (e) {
        if (kDebugMode) {
          print('Erro ao converter conectividade: $e');
        }
        return {'type': 'Desconhecido', 'icon': 5};
      }
    });
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

  // --- INFORMAÇÕES DE DADOS MÓVEIS ---
  /// Obtém informações detalhadas da conexão de dados móveis
  /// Retorna um Map com IP, tipo de conexão, operadora e outras informações
  /// Retorna null se não estiver conectado via dados móveis ou se houver erro
  Future<Map<String, dynamic>?> getMobileInfo() async {
    try {
      // Verifica se está conectado via dados móveis
      final connectionType = await getConnectionType();
      if (connectionType['type'] != 'Dados Móveis') {
        return null;
      }

      // Verifica e solicita permissão de telefone se necessário
      await _checkPhonePermission();

      // Obtém informações básicas de rede
      final wifiIP = await _networkInfo.getWifiIP();
      final wifiIPv6 = await _networkInfo.getWifiIPv6();
      final wifiSubmask = await _networkInfo.getWifiSubmask();
      final wifiBroadcast = await _networkInfo.getWifiBroadcast();
      final wifiGatewayIP = await _networkInfo.getWifiGatewayIP();

      // Para dados móveis, o IP geralmente vem do getWifiIP() mesmo quando não está em Wi-Fi
      final ip = wifiIP ?? 'IP não disponível';

      // Obtém informações da operadora
      String? carrierName;
      try {
        final simCardInfo = SimCardInfo();
        final simCards = await simCardInfo.getSimInfo();
        if (simCards != null && simCards.isNotEmpty) {
          // Pega o primeiro cartão SIM (geralmente o ativo)
          carrierName = simCards.first.carrierName;
        }
      } catch (e) {
        if (kDebugMode) {
          print('Erro ao obter nome da operadora: $e');
        }
      }

      // Obtém o tipo de rede móvel (3G, 4G, 5G)
      String? networkType;
      try {
        final networkTypeDetector = NetworkTypeDetector();
        final networkStatus = await networkTypeDetector.currentNetworkStatus();

        if (kDebugMode) {
          print('[DEBUG] NetworkStatus retornado: $networkStatus');
        }

        switch (networkStatus) {
          case NetworkStatus.mobile2G:
            networkType = '2G';
            break;
          case NetworkStatus.mobile3G:
            networkType = '3G';
            break;
          case NetworkStatus.mobile4G:
            networkType = '4G';
            break;
          case NetworkStatus.mobile5G:
            networkType = '5G';
            break;
          case NetworkStatus.otherMobile:
            // Pode ser 5G em alguns casos, vamos tentar detectar melhor
            networkType = 'Móvel (Outro)';
            break;
          default:
            networkType = null;
        }

        // Se detectou 4G mas pode ser 5G, vamos adicionar uma nota
        // (alguns dispositivos mostram 5G na UI mas a API retorna 4G devido a limitações)
        if (networkType == '4G' && kDebugMode) {
          print(
              '[DEBUG] Detectado 4G - pode ser 5G (verificar na UI do dispositivo)');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Erro ao obter tipo de rede móvel: $e');
        }
      }

      if (kDebugMode) {
        print('''
[******Mobile Info*****]
Operadora: ${carrierName ?? 'N/A'}
Tipo de Rede: ${networkType ?? 'N/A'}
IP: $ip
Gateway: ${wifiGatewayIP ?? 'N/A'}
Submáscara: ${wifiSubmask ?? 'N/A'}
IPv6: ${wifiIPv6 ?? 'N/A'}
''');
      }

      return {
        'carrier': carrierName ?? 'Operadora desconhecida',
        'networkType': networkType ?? 'Desconhecido',
        'ip': ip,
        'gateway': wifiGatewayIP ?? 'N/A',
        'submask': wifiSubmask ?? 'N/A',
        'ipv6': wifiIPv6 ?? 'N/A',
        'broadcast': wifiBroadcast ?? 'N/A',
      };
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao obter informações de dados móveis: $e');
      }
      return {'error': 'Erro ao obter informações: ${e.toString()}'};
    }
  }

  /// Verifica e solicita permissão de telefone se necessário
  Future<void> _checkPhonePermission() async {
    final status = await Permission.phone.status;

    if (!status.isGranted) {
      final result = await Permission.phone.request();
      if (!result.isGranted) {
        if (kDebugMode) {
          print(
              '[PERMISSÃO] Telefone negada - informações da operadora podem estar limitadas');
        }
      }
    }
  }

  /// Verifica e solicita permissão de localização se necessário
  Future<void> _checkLocationPermission() async {
    final status = await Permission.location.status;

    if (!status.isGranted) {
      final result = await Permission.location.request();
      if (!result.isGranted) {
        if (kDebugMode) {
          print(
              '[PERMISSÃO] Localização negada - informações de Wi-Fi podem estar limitadas');
        }
      }
    }
  }
}
