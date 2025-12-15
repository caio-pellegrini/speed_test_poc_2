import '../entities/connection_info.dart';

abstract class INetworkInfoRepository {
  /// Obtém o tipo de conexão atual
  Future<ConnectionInfo> getConnectionType();

  /// Stream que emite mudanças no tipo de conexão
  Stream<ConnectionInfo> getConnectionTypeStream();

  /// Testa a latência da conexão
  Future<int> testLatency({String host = '8.8.8.8'});

  /// Cancela o teste de latência
  void cancelLatencyTest();
}

