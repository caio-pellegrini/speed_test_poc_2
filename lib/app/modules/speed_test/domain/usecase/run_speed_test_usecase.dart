import '../entities/speed_result.dart';
import '../repositories/ispeed_test_repository.dart';
import '../exceptions/speed_test_exception.dart';

class RunSpeedTestUseCase {
  final ISpeedTestRepository repository;

  RunSpeedTestUseCase(this.repository);

  Future<SpeedResult> call({
    required Function(double downloadRate, double uploadRate) onProgress,
    required Function(String? serverIp) onServerSelected,
  }) async {
    try {
      return await repository.runSpeedTest(
        onProgress: onProgress,
        onServerSelected: onServerSelected,
      );
    } catch (e) {
      throw SpeedTestException(
        'Erro ao executar teste de velocidade: ${e.toString()}',
        e,
      );
    }
  }
}

