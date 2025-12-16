import 'dart:async';
import 'package:mobx/mobx.dart';
import 'package:flutter/material.dart';
import '../../domain/entities/connection_info.dart';
import '../../domain/usecase/run_speed_test_usecase.dart';
import '../../domain/usecase/get_connection_info_usecase.dart';
import '../../domain/usecase/test_latency_usecase.dart';

part 'speed_test.store.g.dart';

class SpeedTestStore = _SpeedTestStore with _$SpeedTestStore;

abstract class _SpeedTestStore with Store {
  final RunSpeedTestUseCase _runSpeedTestUseCase;
  final GetConnectionInfoUseCase _getConnectionInfoUseCase;
  final TestLatencyUseCase _testLatencyUseCase;

  StreamSubscription<ConnectionInfo>? _connectivitySubscription;

  _SpeedTestStore(
    this._runSpeedTestUseCase,
    this._getConnectionInfoUseCase,
    this._testLatencyUseCase,
  ) {
    loadConnectionInfo();
    _setupConnectivityListener();
  }

  // Observables
  @observable
  double downloadRate = 0;

  @observable
  double uploadRate = 0;

  @observable
  int? latency;

  @observable
  bool isServerSelectionInProgress = false;

  @observable
  bool isTesting = false;

  @observable
  double testProgress = 0.0;

  @observable
  String currentTestPhase = '';

  @observable
  String? serverIp;

  @observable
  ConnectionInfo? connectionInfo;

  @observable
  bool isConnectionCardExpanded = false;

  // Contadores para progresso baseado em requisições
  int _downloadRequestCount = 0;
  int _uploadRequestCount = 0;
  int _pingCount = 0;

  // Computed
  @computed
  bool get hasConnection {
    return connectionInfo != null && connectionInfo!.hasConnection;
  }

  @computed
  String get connectionName {
    return connectionInfo?.type ?? 'Carregando...';
  }

  @computed
  IconData get connectionIcon {
    if (connectionInfo == null) return Icons.help_outline;
    switch (connectionInfo!.icon) {
      case 0: // Cabo (Ethernet)
        return Icons.cable;
      case 1: // Wi-Fi
        return Icons.wifi;
      case 2: // Dados Móveis
        return Icons.signal_cellular_alt;
      case 3: // Bluetooth
        return Icons.bluetooth;
      case 4: // Sem Conexão
        return Icons.signal_wifi_off;
      default:
        return Icons.help_outline;
    }
  }

  @computed
  Color get connectionColor {
    if (connectionInfo == null) return Colors.grey;
    switch (connectionInfo!.icon) {
      case 0: // Cabo (Ethernet)
        return Colors.green;
      case 1: // Wi-Fi
        return Colors.blue;
      case 2: // Dados Móveis
        return Colors.orange;
      case 3: // Bluetooth
        return Colors.purple;
      case 4: // Sem Conexão
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @computed
  bool get hasTestResults {
    return !isTesting &&
        (downloadRate > 0 || uploadRate > 0 || latency != null);
  }

  // Actions
  @action
  Future<void> loadConnectionInfo() async {
    try {
      connectionInfo = await _getConnectionInfoUseCase();
    } catch (e) {
      // Em caso de erro, mantém o estado atual
      debugPrint('Erro ao carregar tipo de conexão: $e');
    }
  }

  @action
  void _setupConnectivityListener() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = _getConnectionInfoUseCase.stream().listen(
      (ConnectionInfo info) {
        connectionInfo = info;
      },
      onError: (error) {
        debugPrint('Erro no listener de conectividade: $error');
      },
    );
  }

  @action
  Future<void> runTest() async {
    if (isTesting || !hasConnection) return;

    try {
      await loadConnectionInfo();

      isTesting = true;
      downloadRate = 0;
      uploadRate = 0;
      latency = null;
      testProgress = 0.0;
      currentTestPhase = '';
      serverIp = null;

      // Reset contadores
      _downloadRequestCount = 0;
      _uploadRequestCount = 0;
      _pingCount = 0;

      // Executa teste de velocidade
      setServerSelectionInProgress(true);
      final result = await _runSpeedTestUseCase.call(
        onProgress: (download, upload) {
          // Atualiza progresso baseado em contadores de requisições
          if (download > 0 && upload == 0) {
            // Fase de download
            downloadRate = download;
            currentTestPhase = 'Etapa 1 de 3';
            _downloadRequestCount++;
            // Progresso: 0.0 + (contador / 45) * 0.33
            testProgress =
                0.0 + ((_downloadRequestCount / 45) * 0.33).clamp(0.0, 0.33);
          } else if (upload > 0) {
            // Fase de upload
            uploadRate = upload;
            currentTestPhase = 'Etapa 2 de 3';
            _uploadRequestCount++;
            // Progresso: 0.33 + (contador / 45) * 0.33
            testProgress =
                0.33 + ((_uploadRequestCount / 45) * 0.33).clamp(0.0, 0.33);
          }
        },
        onServerSelected: (ip) {
          serverIp = ip;
          isServerSelectionInProgress = false;
        },
      );

      downloadRate = result.downloadRate;
      uploadRate = result.uploadRate;
      serverIp = result.serverIp;
      testProgress = 0.66;
      currentTestPhase = 'Etapa 3 de 3';

      // Executa teste de latência
      final latencyResult = await _testLatencyUseCase.call(
        onProgress: (pingCount) {
          _pingCount = pingCount;
          // Progresso: 0.66 + (contador / 5) * 0.33
          testProgress = 0.66 + ((_pingCount / 5) * 0.33).clamp(0.0, 0.34);
        },
      );
      latency = latencyResult;
      isTesting = false;
      testProgress = 1.0;
      currentTestPhase = '';
    } catch (e) {
      reset();
      debugPrint('Erro ao executar teste: $e');
      rethrow;
    }
  }

  @action
  void reset() {
    downloadRate = 0;
    uploadRate = 0;
    serverIp = null;
    isTesting = false;
    testProgress = 0.0;
    currentTestPhase = '';
    latency = null;
    _downloadRequestCount = 0;
    _uploadRequestCount = 0;
    _pingCount = 0;
    loadConnectionInfo();
  }

  @action
  void toggleConnectionCardExpanded() {
    isConnectionCardExpanded = !isConnectionCardExpanded;
  }

  @action
  void setServerSelectionInProgress(bool value) {
    isServerSelectionInProgress = value;
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}
