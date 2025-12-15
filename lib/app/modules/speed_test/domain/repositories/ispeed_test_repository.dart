import '../entities/speed_result.dart';

abstract class ISpeedTestRepository {
  /// Executa teste de velocidade (download e upload)
  /// Retorna SpeedResult com os resultados
  Future<SpeedResult> runSpeedTest({
    required Function(double downloadRate, double uploadRate) onProgress,
    required Function(String? serverIp) onServerSelected,
  });

  /// Cancela o teste em andamento
  void cancelTest();
}

