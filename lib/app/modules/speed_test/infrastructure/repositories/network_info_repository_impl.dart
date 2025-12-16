import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dart_ping/dart_ping.dart';
import 'package:flutter/foundation.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:carrier_info/carrier_info.dart';
import '../../domain/entities/connection_info.dart';
import '../../domain/repositories/inetwork_info_repository.dart';
import '../../domain/exceptions/network_exception.dart';

class NetworkInfoRepositoryImpl implements INetworkInfoRepository {
  final Connectivity _connectivity = Connectivity();
  bool _isCancelled = false;

  @override
  Future<ConnectionInfo> getConnectionType() async {
    try {
      final List<ConnectivityResult> results =
          await _connectivity.checkConnectivity();
      final connectionData = _convertConnectivityResults(results);

      // Carrega informações detalhadas baseado no tipo
      Map<String, dynamic>? wifiInfo;
      Map<String, dynamic>? mobileInfo;
      Map<String, dynamic>? ethernetInfo;

      if (connectionData['type'] == 'Wi-Fi') {
        wifiInfo = await _getWiFiInfo();
      } else if (connectionData['type'] == 'Dados Móveis') {
        mobileInfo = await _getMobileInfo();
      } else if (connectionData['type'] == 'Cabo (Ethernet)') {
        ethernetInfo = await _getEthernetInfo();
      }

      return ConnectionInfo(
        type: connectionData['type'] as String,
        icon: connectionData['icon'] as int,
        wifiInfo: wifiInfo,
        mobileInfo: mobileInfo,
        ethernetInfo: ethernetInfo,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Erro ao obter tipo de conexão: $e');
      }
      throw NetworkException(
        'Erro ao obter tipo de conexão: ${e.toString()}',
        e,
      );
    }
  }

  @override
  Stream<ConnectionInfo> getConnectionTypeStream() {
    return _connectivity.onConnectivityChanged.asyncMap(
      (List<ConnectivityResult> results) async {
        try {
          final connectionData = _convertConnectivityResults(results);

          Map<String, dynamic>? wifiInfo;
          Map<String, dynamic>? mobileInfo;
          Map<String, dynamic>? ethernetInfo;

          if (connectionData['type'] == 'Wi-Fi') {
            wifiInfo = await _getWiFiInfo();
          } else if (connectionData['type'] == 'Dados Móveis') {
            mobileInfo = await _getMobileInfo();
          } else if (connectionData['type'] == 'Cabo (Ethernet)') {
            ethernetInfo = await _getEthernetInfo();
          }

          return ConnectionInfo(
            type: connectionData['type'] as String,
            icon: connectionData['icon'] as int,
            wifiInfo: wifiInfo,
            mobileInfo: mobileInfo,
            ethernetInfo: ethernetInfo,
          );
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Erro ao converter conectividade: $e');
          }
          return ConnectionInfo(
            type: 'Desconhecido',
            icon: 5,
          );
        }
      },
    );
  }

  @override
  Future<int> testLatency({
    String host = '8.8.8.8',
    int pingQuantity = 5,
    Function(int pingCount, int? partialLatency)? onProgress,
  }) async {
    _isCancelled = false;
    final ping = Ping(host, count: pingQuantity);
    int totalTime = 0;
    int successCount = 0;
    int pingCount = 0;

    try {
      await for (final PingData data in ping.stream) {
        if (_isCancelled) return 0;

        // Limita a processar apenas 5 pings, mesmo que o stream emita mais eventos
        if (pingCount >= pingQuantity) break;

        pingCount++;
        int? partialLatency;

        if (data.response != null && data.response!.time != null) {
          final pingTime = data.response!.time!.inMilliseconds;
          totalTime += pingTime;
          successCount++;
          // Calcula a latência parcial (média até o momento)
          partialLatency = (totalTime / successCount).round();
          if (kDebugMode) {
            debugPrint(
                'Ping #$pingCount: ${pingTime}ms (média parcial: ${partialLatency}ms)');
          }
        } else {
          if (kDebugMode) {
            debugPrint('Ping #$pingCount: timeout ou erro');
          }
        }

        // Chama o callback de progresso com o contador e a latência parcial
        onProgress?.call(pingCount, partialLatency);
      }
    } catch (e) {
      if (kDebugMode) debugPrint("Erro no ping: $e");
      return -1;
    }

    if (successCount == 0) return -1;
    return (totalTime / successCount).round();
  }

  @override
  void cancelLatencyTest() {
    _isCancelled = true;
  }

  /// Converte uma lista de ConnectivityResult para o formato Map usado na UI
  Map<String, dynamic> _convertConnectivityResults(
      List<ConnectivityResult> results) {
    // Lógica de prioridade do Android: Ethernet > Wifi > Mobile > Bluetooth
    if (results.contains(ConnectivityResult.ethernet)) {
      return {'type': 'Cabo (Ethernet)', 'icon': 0};
    } else if (results.contains(ConnectivityResult.wifi)) {
      return {'type': 'Wi-Fi', 'icon': 1};
    } else if (results.contains(ConnectivityResult.mobile)) {
      return {'type': 'Dados Móveis', 'icon': 2};
    } else if (results.contains(ConnectivityResult.bluetooth)) {
      return {'type': 'Bluetooth', 'icon': 3};
    } else if (results.contains(ConnectivityResult.none)) {
      return {'type': 'Sem Conexão', 'icon': 4};
    } else {
      return {'type': 'Outro', 'icon': 5};
    }
  }

  /// Obtém informações detalhadas da rede Wi-Fi conectada
  Future<Map<String, dynamic>?> _getWiFiInfo() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final connectionData = _convertConnectivityResults(results);
      if (connectionData['type'] != 'Wi-Fi') {
        return null;
      }

      final isEnabled = await WiFiForIoTPlugin.isEnabled();
      if (!isEnabled) {
        return {'error': 'Wi-Fi desativado'};
      }

      await _checkLocationPermission();

      final ssid = await WiFiForIoTPlugin.getSSID();
      final bssid = await WiFiForIoTPlugin.getBSSID();
      final signal = await WiFiForIoTPlugin.getCurrentSignalStrength();
      final frequency = await WiFiForIoTPlugin.getFrequency();
      final ip = await WiFiForIoTPlugin.getIP();

      return {
        'ssid': ssid ?? 'SSID desconhecido',
        'bssid': bssid ?? 'BSSID desconhecido',
        'signal': signal,
        'frequency': frequency,
        'ip': ip ?? 'IP desconhecido',
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Erro ao obter informações Wi-Fi: $e');
      }
      return {'error': 'Erro ao obter informações: ${e.toString()}'};
    }
  }

  /// Obtém informações detalhadas da conexão de dados móveis
  Future<Map<String, dynamic>?> _getMobileInfo() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final connectionData = _convertConnectivityResults(results);
      if (connectionData['type'] != 'Dados Móveis') {
        return null;
      }

      await _checkPhonePermission();

      final ip = await _getBestIpAddress() ?? 'IP não disponível';

      String? carrierName;
      String? networkTypeDisplay;
      String? simState;

      try {
        final androidInfo = await CarrierInfo.getAndroidInfo();
        if (androidInfo != null && androidInfo.telephonyInfo.isNotEmpty) {
          final telephonyInfo = androidInfo.telephonyInfo.first;

          carrierName = telephonyInfo.carrierName.isNotEmpty
              ? telephonyInfo.carrierName
              : (telephonyInfo.networkOperatorName.isNotEmpty
                  ? telephonyInfo.networkOperatorName
                  : telephonyInfo.displayName);

          final networkGen = telephonyInfo.networkGeneration;
          final radio = telephonyInfo.radioType;
          if (radio != null && radio.isNotEmpty) {
            networkTypeDisplay = '$networkGen ($radio)';
          } else {
            networkTypeDisplay = networkGen;
          }

          simState = telephonyInfo.simState;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Erro ao obter informações da operadora: $e');
        }
      }

      return {
        'carrier': carrierName ?? 'Operadora desconhecida',
        'networkType': networkTypeDisplay ?? 'Desconhecido',
        'simState': simState,
        'ip': ip,
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Erro ao obter informações de dados móveis: $e');
      }
      return {'error': 'Erro ao obter informações: ${e.toString()}'};
    }
  }

  /// Obtém informações detalhadas da conexão Ethernet (cabo)
  Future<Map<String, dynamic>?> _getEthernetInfo() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final connectionData = _convertConnectivityResults(results);
      if (connectionData['type'] != 'Cabo (Ethernet)') {
        return null;
      }

      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      NetworkInterface? ethernetInterface;
      String? ipAddress;

      for (var interface in interfaces) {
        if (interface.name.contains('eth')) {
          ethernetInterface = interface;
          for (var addr in interface.addresses) {
            if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
              ipAddress = addr.address;
              break;
            }
          }
          break;
        }
      }

      if (ethernetInterface == null) {
        return {'error': 'Interface Ethernet não encontrada'};
      }

      final interfaceName = ethernetInterface.name;
      final macAddress = await _getMacAddress(interfaceName);

      return {
        'interface': interfaceName,
        'ip': ipAddress ?? 'IP não disponível',
        'mac': macAddress ?? 'MAC não disponível',
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Erro ao obter informações Ethernet: $e');
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
          debugPrint(
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
          debugPrint(
              '[PERMISSÃO] Localização negada - informações de Wi-Fi podem estar limitadas');
        }
      }
    }
  }

  /// Obtém o endereço MAC da interface de rede no Android
  Future<String?> _getMacAddress(String interfaceName) async {
    try {
      if (Platform.isAndroid) {
        final result = await Process.run(
          'cat',
          ['/sys/class/net/$interfaceName/address'],
        );

        if (result.exitCode == 0 &&
            result.stdout.toString().trim().isNotEmpty) {
          final mac = result.stdout.toString().trim();
          if (mac.length == 17 && mac.split(':').length == 6) {
            return mac.toUpperCase();
          }
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Erro ao obter MAC address: $e');
      }
      return null;
    }
  }

  /// Obtém o melhor endereço IP disponível na rede
  Future<String?> _getBestIpAddress() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final connectionData = _convertConnectivityResults(results);
      final isMobile = connectionData['type'] == 'Dados Móveis';

      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      if (isMobile) {
        for (var interface in interfaces) {
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

      for (var interface in interfaces) {
        if (interface.name.contains('eth') || interface.name.contains('wlan')) {
          for (var addr in interface.addresses) {
            if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
              return addr.address;
            }
          }
        }
      }

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
        debugPrint('Erro ao obter IP: $e');
      }
      return null;
    }
  }
}
