import '../entities/connection_info.dart';
import '../repositories/inetwork_info_repository.dart';
import '../exceptions/network_exception.dart';

class GetConnectionInfoUseCase {
  final INetworkInfoRepository repository;

  GetConnectionInfoUseCase(this.repository);

  Future<ConnectionInfo> call() async {
    try {
      return await repository.getConnectionType();
    } catch (e) {
      throw NetworkException(
        'Erro ao obter informações de conexão: ${e.toString()}',
        e,
      );
    }
  }

  Stream<ConnectionInfo> stream() {
    try {
      return repository.getConnectionTypeStream();
    } catch (e) {
      throw NetworkException(
        'Erro ao obter stream de conexão: ${e.toString()}',
        e,
      );
    }
  }
}

