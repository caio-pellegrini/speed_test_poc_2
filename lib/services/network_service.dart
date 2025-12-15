import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dart_ping/dart_ping.dart';
import 'package:flutter/foundation.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:carrier_info/carrier_info.dart';

class NetworkService {
  final Connectivity _connectivity = Connectivity();
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

      // Obtém IP da rede usando dart:io (mais leve que network_info_plus)
      final ip = await _getBestIpAddress() ?? 'IP não disponível';

      // Obtém informações essenciais para diagnóstico usando carrier_info
      String? carrierName;
      String?
          networkTypeDisplay; // Tipo de rede combinado com rádio (ex: "4G (LTE)")
      String? simState;
      try {
        final androidInfo = await CarrierInfo.getAndroidInfo();
        if (androidInfo != null && androidInfo.telephonyInfo.isNotEmpty) {
          // Pega o primeiro item de telephonyInfo (geralmente o ativo)
          final telephonyInfo = androidInfo.telephonyInfo.first;

          // Nome da operadora (prioridade: carrierName > networkOperatorName > displayName)
          carrierName = telephonyInfo.carrierName.isNotEmpty
              ? telephonyInfo.carrierName
              : (telephonyInfo.networkOperatorName.isNotEmpty
                  ? telephonyInfo.networkOperatorName
                  : telephonyInfo.displayName);

          // Tipo de rede combinado com tipo de rádio (ex: "4G (LTE)" ou "5G (NR)")
          final networkGen = telephonyInfo.networkGeneration;
          final radio = telephonyInfo.radioType;
          if (radio != null && radio.isNotEmpty) {
            networkTypeDisplay = '$networkGen ($radio)';
          } else {
            networkTypeDisplay = networkGen;
          }

          // Estado do SIM
          simState = telephonyInfo.simState;
        }
      } catch (e) {
        if (kDebugMode) {
          print('Erro ao obter informações da operadora: $e');
        }
      }

      if (kDebugMode) {
        print('''
[******Mobile Info*****]
Operadora: ${carrierName ?? 'N/A'}
Tipo de Rede: ${networkTypeDisplay ?? 'N/A'}
Estado SIM: ${simState ?? 'N/A'}
IP: $ip
''');
      }

      return {
        'carrier': carrierName ?? 'Operadora desconhecida',
        'networkType': networkTypeDisplay ?? 'Desconhecido',
        'simState': simState,
        'ip': ip,
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

  /// Obtém o melhor endereço IP disponível na rede
  /// Prioriza interfaces de dados móveis (rmnet) quando em dados móveis
  /// ou Wi-Fi/Ethernet quando disponíveis
  Future<String?> _getBestIpAddress() async {
    try {
      final connectionType = await getConnectionType();
      final isMobile = connectionType['type'] == 'Dados Móveis';

      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      // Se estiver em dados móveis, prioriza interfaces rmnet (dados móveis Android)
      if (isMobile) {
        for (var interface in interfaces) {
          // Interfaces de dados móveis no Android: rmnet, ccmni, wwan
          if (interface.name.contains('rmnet') ||
              interface.name.contains('ccmni') ||
              interface.name.contains('wwan')) {
            for (var addr in interface.addresses) {
              if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
                return addr.address;
              }
            }
          }
        }
      }

      // Prioriza interfaces físicas conhecidas (Cabo, Wi-Fi)
      for (var interface in interfaces) {
        // eth0 = Cabo, wlan0 = Wi-Fi
        if (interface.name.contains('eth') || interface.name.contains('wlan')) {
          for (var addr in interface.addresses) {
            if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
              return addr.address;
            }
          }
        }
      }

      // Fallback: retorna a primeira interface não-loopback que encontrar
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            return addr.address;
          }
        }
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao obter IP: $e');
      }
      return null;
    }
  }
}
