import '../repositories/inetwork_info_repository.dart';
import '../exceptions/network_exception.dart';

class TestLatencyUseCase {
  final INetworkInfoRepository repository;

  TestLatencyUseCase(this.repository);

  Future<int> call({
    String host = '8.8.8.8',
    Function(int pingCount)? onProgress,
  }) async {
    try {
      return await repository.testLatency(
        host: host,
        onProgress: onProgress,
      );
    } catch (e) {
      throw NetworkException(
        'Erro ao testar latência: ${e.toString()}',
        e,
      );
    }
  }
}

