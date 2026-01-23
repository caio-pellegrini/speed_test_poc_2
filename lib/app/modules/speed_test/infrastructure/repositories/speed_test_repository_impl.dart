import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_speed_test_plus/flutter_speed_test_plus.dart';
import '../../domain/entities/speed_result.dart';
import '../../domain/repositories/ispeed_test_repository.dart';
import '../../domain/exceptions/speed_test_exception.dart';

class SpeedTestRepositoryImpl implements ISpeedTestRepository {
  final FlutterInternetSpeedTest _speedTest = FlutterInternetSpeedTest()
    ..enableLog();
  final Connectivity _connectivity = Connectivity();

  /// Retorna o multiplicador de taxa de download baseado no tipo de rede
  double _getDownloadRateMultiplier(List<ConnectivityResult> results) {
    // Lógica de prioridade: Ethernet > Wifi > Mobile > Bluetooth
    if (results.contains(ConnectivityResult.ethernet) ||
        results.contains(ConnectivityResult.bluetooth)) {
      return 2.5;
    } else if (results.contains(ConnectivityResult.mobile)) {
      return 3.25;
    } else if (results.contains(ConnectivityResult.wifi)) {
      return 3.75;
    } else {
      // Valor padrão caso não seja possível determinar o tipo
      return 2.5;
    }
  }

  @override
  Future<SpeedResult> runSpeedTest({
    required Function(double downloadRate, double uploadRate) onProgress,
    required Function(String? serverIp) onServerSelected,
  }) async {
    final completer = Completer<SpeedResult>();
    double downloadRate = 0;
    double uploadRate = 0;
    String? serverIp;
    bool isCompleted = false;

    // Obtém o tipo de conexão atual e calcula o multiplicador
    final connectivityResults = await _connectivity.checkConnectivity();
    final double downloadRateMultiplier =
        _getDownloadRateMultiplier(connectivityResults);

    try {
      await _speedTest.startTesting(
        useFastApi: true,
        onCompleted: (download, upload) {
          if (!isCompleted) {
            isCompleted = true;
            // Se o valor do download for menor que 1.5 Mb, usa o valor raw
            // Caso contrário, aplica o multiplicador
            final rawDownloadRate = download.transferRate;
            downloadRate = double.parse(
              (rawDownloadRate < 1.5
                      ? rawDownloadRate
                      : rawDownloadRate * downloadRateMultiplier)
                  .toStringAsPrecision(3),
            );
            uploadRate = double.parse(
              upload.transferRate.toStringAsPrecision(3),
            );

            if (!completer.isCompleted) {
              completer.complete(
                SpeedResult(
                  downloadRate: downloadRate,
                  uploadRate: uploadRate,
                  serverIp: serverIp,
                ),
              );
            }
          }
        },
        onProgress: (percent, data) {
          if (data.type == TestType.download) {
            // Se o valor do download for menor que 1.5 Mb, usa o valor raw
            // Caso contrário, aplica o multiplicador
            final rawDownloadRate = data.transferRate;
            print('rawDownloadRate: $rawDownloadRate');
            downloadRate = double.parse(
              (rawDownloadRate < 1.5
                      ? rawDownloadRate
                      : rawDownloadRate * downloadRateMultiplier)
                  .toStringAsPrecision(3),
            );
          } else {
            uploadRate = double.parse(
              data.transferRate.toStringAsPrecision(3),
            );
          }
          onProgress(downloadRate, uploadRate);
        },
        onDefaultServerSelectionInProgress: () {
          // Server selection started
        },
        onDefaultServerSelectionDone: (client) {
          serverIp = client?.ip;
          onServerSelected(serverIp);
        },
        onError: (errorMessage, speedTestError) {
          if (!completer.isCompleted) {
            completer.completeError(
              SpeedTestException(
                errorMessage,
                speedTestError,
              ),
            );
          }
        },
        onCancel: () {
          if (!completer.isCompleted) {
            completer.completeError(
              SpeedTestException('Teste cancelado pelo usuário'),
            );
          }
        },
      );

      return await completer.future;
    } catch (e) {
      throw SpeedTestException(
        'Erro ao executar teste: ${e.toString()}',
        e,
      );
    }
  }

  @override
  void cancelTest() {
    // FlutterInternetSpeedTest não tem método cancel explícito
    // O cancelamento é tratado pelo callback onCancel
  }
}
