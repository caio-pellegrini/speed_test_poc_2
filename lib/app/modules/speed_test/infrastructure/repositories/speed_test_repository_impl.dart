import 'dart:async';
import 'package:flutter_speed_test_plus/flutter_speed_test_plus.dart';
import '../../domain/entities/speed_result.dart';
import '../../domain/repositories/ispeed_test_repository.dart';
import '../../domain/exceptions/speed_test_exception.dart';

class SpeedTestRepositoryImpl implements ISpeedTestRepository {
  final FlutterInternetSpeedTest _speedTest = FlutterInternetSpeedTest()
    ..enableLog();

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

    const double downloadRateMultiplier = 1;

    try {
      await _speedTest.startTesting(
        useFastApi: true,
        onCompleted: (download, upload) {
          if (!isCompleted) {
            isCompleted = true;
            downloadRate = double.parse(
              (download.transferRate * downloadRateMultiplier)
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
            downloadRate = double.parse(
              (data.transferRate * downloadRateMultiplier)
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
