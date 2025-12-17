import 'dart:async';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../../domain/entities/speed_result.dart';
import '../../domain/repositories/ispeed_test_repository.dart';
import '../../domain/exceptions/speed_test_exception.dart';

/// Implementação customizada de speed test com múltiplas conexões paralelas
/// Segue metodologias do Fast.com e Speedtest.net:
/// - Usa múltiplas conexões HTTP paralelas para saturar a banda
/// - Exclui fase de ramp-up do cálculo
/// - Aplica filtro estatístico para remover outliers
class ParallelSpeedTestRepositoryImpl implements ISpeedTestRepository {
  static const int _defaultParallelConnections =
      6; // Aumentado para melhor saturação
  static const int _rampUpDurationSeconds = 2; // Descartar primeiros 2 segundos
  static const int _minTestDurationSeconds = 5; // Duração mínima do teste
  static const int _maxTestDurationSeconds = 30; // Duração máxima do teste
  static const double _outlierRemovalPercent = 0.25; // Remove 25% mais lentos

  bool _isCancelled = false;
  bool _userCancelled = false; // Flag separada para cancelamento do usuário
  final List<http.Client> _activeClients = [];

  @override
  Future<SpeedResult> runSpeedTest({
    required Function(double downloadRate, double uploadRate) onProgress,
    required Function(String? serverIp) onServerSelected,
  }) async {
    _isCancelled = false;
    _userCancelled = false;
    final completer = Completer<SpeedResult>();
    double downloadRate = 0;
    double uploadRate = 0;
    String? serverIp;

    try {
      // Seleciona servidores (usa Fast.com API - retorna múltiplas URLs)
      final serverUrls = await _selectServers();

      // Usa primeira URL para exibir no UI
      serverIp = serverUrls.isNotEmpty ? serverUrls.first : null;
      onServerSelected(serverIp);

      if (serverUrls.isEmpty) {
        // Tenta usar servidor padrão como fallback
        serverUrls.add('https://speed.cloudflare.com/__down?bytes=25000000');
        serverIp = serverUrls.first;
        onServerSelected(serverIp);
      }

      // Executa teste de download com múltiplas conexões paralelas
      downloadRate = await _testDownloadParallel(
        serverUrls: serverUrls,
        onProgress: (rate) {
          downloadRate = rate;
          onProgress(downloadRate, uploadRate);
        },
      );

      // Verifica cancelamento apenas se foi explicitamente cancelado pelo usuário
      // (não verifica aqui pois _isCancelled pode ser setado internamente para parar conexões)

      // Executa teste de upload (mantém implementação original por enquanto)
      if (serverIp != null) {
        uploadRate = await _testUpload(
          serverUrl: serverIp,
          onProgress: (rate) {
            uploadRate = rate;
            onProgress(downloadRate, uploadRate);
          },
        );
      }

      if (!completer.isCompleted) {
        completer.complete(
          SpeedResult(
            downloadRate: downloadRate,
            uploadRate: uploadRate,
            serverIp: serverIp,
          ),
        );
      }

      return await completer.future;
    } catch (e) {
      if (!completer.isCompleted) {
        completer.completeError(
          SpeedTestException(
            'Erro ao executar teste: ${e.toString()}',
            e,
          ),
        );
      }
      rethrow;
    } finally {
      _cleanupClients();
    }
  }

  /// Seleciona servidor usando Fast.com API
  /// Retorna lista de URLs para usar em conexões paralelas
  Future<List<String>> _selectServers() async {
    try {
      // Obtém token do Fast.com
      final tokenResponse = await http
          .get(
            Uri.parse('https://fast.com/app-a32983.js'),
          )
          .timeout(const Duration(seconds: 10));

      if (tokenResponse.statusCode != 200) {
        return [];
      }

      const tag = 'token:"';
      if (!tokenResponse.body.contains(tag)) {
        return [];
      }

      final start = tokenResponse.body.lastIndexOf(tag) + tag.length;
      final token = tokenResponse.body.substring(start, start + 32);

      // Obtém múltiplas URLs dos servidores (pede mais URLs para ter opções)
      final serverResponse = await http
          .get(
            Uri.parse(
              'https://api.fast.com/netflix/speedtest/v2?https=true&token=$token&urlCount=10',
            ),
          )
          .timeout(const Duration(seconds: 10));

      if (serverResponse.statusCode != 200) {
        return [];
      }

      // Parse JSON - extrai todas as URLs
      final body = serverResponse.body;
      final urlMatches = RegExp(r'"url"\s*:\s*"([^"]+)"').allMatches(body);
      final urls = urlMatches.map((match) => match.group(1)!).toList();

      if (urls.isNotEmpty) {
        return urls;
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// Testa download com múltiplas conexões paralelas
  Future<double> _testDownloadParallel({
    required List<String> serverUrls,
    required Function(double) onProgress,
  }) async {
    _isCancelled = false;
    final startTime = DateTime.now();
    final List<double> speedSamples = []; // Amostras de velocidade agregada
    final List<http.Client> clients = [];
    final List<ConnectionStats> connectionStats = [];
    final List<Future<void>> connectionFutures = [];

    // Determina número de conexões paralelas baseado na latência estimada
    final int parallelConnections = _determineParallelConnections();

    try {
      // Cria múltiplas conexões paralelas
      // Usa URLs diferentes ou a mesma URL com range requests
      for (int i = 0; i < parallelConnections; i++) {
        final client = http.Client();
        clients.add(client);
        _activeClients.add(client);

        final stats = ConnectionStats();
        connectionStats.add(stats);

        // Seleciona URL para esta conexão (roda entre as URLs disponíveis)
        final serverUrl = serverUrls[i % serverUrls.length];

        // Inicia download em cada conexão de forma assíncrona
        final future = _startDownloadConnection(
          client: client,
          serverUrl: serverUrl,
          stats: stats,
          onChunk: (bytes, elapsed) {
            if (_isCancelled) return;
            // Atualiza bytes recebidos desta conexão
            stats.bytesReceived = bytes;
            stats.lastUpdate = DateTime.now();
          },
        );
        connectionFutures.add(future);
      }

      // Aguarda fase de ramp-up
      await Future.delayed(Duration(seconds: _rampUpDurationSeconds + 1));

      // Coleta amostras de velocidade agregada periodicamente
      final sampleInterval = const Duration(
          milliseconds: 300); // Mais frequente para melhor precisão
      DateTime lastSampleTime = DateTime.now();
      int lastTotalBytes = 0;

      // Continua coletando amostras até duração máxima ou cancelamento
      // Garante duração mínima para estabilização
      while (!_isCancelled) {
        final elapsed = DateTime.now().difference(startTime).inSeconds;
        if (elapsed >= _maxTestDurationSeconds) break;
        if (elapsed < _minTestDurationSeconds) {
          await Future.delayed(sampleInterval);
          continue;
        }
        await Future.delayed(sampleInterval);

        // Calcula velocidade agregada de todas as conexões
        final now = DateTime.now();
        final elapsedSinceStart = now.difference(startTime);
        final elapsedSinceRampUp =
            elapsedSinceStart.inSeconds - _rampUpDurationSeconds;

        if (elapsedSinceRampUp > 0) {
          // Soma bytes recebidos de todas as conexões
          int totalBytes = 0;
          for (final stats in connectionStats) {
            totalBytes += stats.bytesReceived;
          }

          // Calcula velocidade agregada (soma de todas as conexões)
          final timeSinceLastSample =
              now.difference(lastSampleTime).inMilliseconds / 1000.0;
          if (timeSinceLastSample > 0.1 && totalBytes > lastTotalBytes) {
            // Velocidade instantânea (mais precisa para conexões paralelas)
            final bytesSinceLastSample = totalBytes - lastTotalBytes;
            final instantSpeedMbps = (bytesSinceLastSample * 8) /
                (timeSinceLastSample * 1024 * 1024);

            // Velocidade média desde o início (após ramp-up) - para referência
            final totalSpeedMbps =
                (totalBytes * 8) / (elapsedSinceRampUp * 1024 * 1024);

            // Usa 70% velocidade instantânea + 30% velocidade total
            // Isso dá mais peso à velocidade atual (que reflete melhor o paralelismo)
            // mas mantém estabilidade com a média total
            final weightedSpeedMbps =
                (instantSpeedMbps * 0.7) + (totalSpeedMbps * 0.3);

            if (weightedSpeedMbps > 0) {
              speedSamples.add(weightedSpeedMbps);
              onProgress(weightedSpeedMbps);
            }

            lastTotalBytes = totalBytes;
          }

          lastSampleTime = now;
        }
      }

      // Marca como cancelado para parar todas as conexões (após tempo máximo)
      _isCancelled = true;

      // Aguarda todas as conexões terminarem (com timeout)
      try {
        await Future.wait(
          connectionFutures,
          eagerError: false,
        ).timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            return <void>[];
          },
        );
      } catch (e) {
        // Ignora erros ao aguardar conexões
      }

      // Verifica se foi cancelado pelo usuário
      if (_userCancelled) {
        throw SpeedTestException('Teste cancelado pelo usuário');
      }

      // Verifica se temos amostras suficientes
      if (speedSamples.isEmpty) {
        throw SpeedTestException(
          'Não foi possível coletar amostras de velocidade. Verifique sua conexão.',
        );
      }

      // Calcula velocidade final usando filtro estatístico
      final finalSpeed = _calculateFinalSpeed(speedSamples);

      if (finalSpeed <= 0) {
        throw SpeedTestException(
          'Não foi possível calcular velocidade. Verifique sua conexão.',
        );
      }

      return finalSpeed;
    } finally {
      // Fecha todos os clientes HTTP
      for (final client in clients) {
        try {
          client.close();
        } catch (e) {
          // Ignora erros ao fechar
        }
        _activeClients.remove(client);
      }
    }
  }

  /// Inicia uma conexão de download individual
  Future<void> _startDownloadConnection({
    required http.Client client,
    required String serverUrl,
    required ConnectionStats stats,
    required Function(int bytes, Duration elapsed) onChunk,
  }) async {
    try {
      final request = http.Request('GET', Uri.parse(serverUrl));
      final connectionStartTime = DateTime.now();
      stats.startTime = connectionStartTime;

      final streamedResponse = await client.send(request).timeout(
            const Duration(seconds: _maxTestDurationSeconds + 5),
          );

      if (streamedResponse.statusCode != 200 &&
          streamedResponse.statusCode != 206) {
        return;
      }

      int bytesReceived = 0;

      await for (final chunk in streamedResponse.stream) {
        if (_isCancelled) break;

        bytesReceived += chunk.length;
        final elapsed = DateTime.now().difference(connectionStartTime);
        stats.bytesReceived = bytesReceived;

        onChunk(bytesReceived, elapsed);
      }
    } catch (e) {
      // Ignora erros individuais, continua com outras conexões
    }
  }

  /// Determina número ótimo de conexões paralelas
  int _determineParallelConnections() {
    // Para Wi-Fi com latência média/alta, usa mais conexões
    // Fast.com usa múltiplas conexões variáveis (geralmente 4-8)
    // Aumentamos para 6 para melhor saturação em Wi-Fi
    return _defaultParallelConnections;
  }

  /// Calcula velocidade atual usando média móvel
  double _calculateCurrentSpeed(List<double> samples) {
    if (samples.isEmpty) return 0;

    // Usa média dos últimos 10% das amostras ou últimas 5, o que for maior
    final recentSamples = samples.length > 5
        ? samples.sublist(samples.length - max(5, samples.length ~/ 10))
        : samples;

    return recentSamples.reduce((a, b) => a + b) / recentSamples.length;
  }

  /// Calcula velocidade final aplicando filtro estatístico
  /// Remove outliers (25% mais lentos) e calcula média
  double _calculateFinalSpeed(List<double> samples) {
    if (samples.isEmpty) return 0;

    // Ordena amostras por velocidade
    final sorted = List<double>.from(samples)..sort();

    // Remove 25% mais lentos (outliers e ramp-up residual)
    final removeCount = (sorted.length * _outlierRemovalPercent).floor();
    final filtered = sorted.sublist(removeCount);

    if (filtered.isEmpty) {
      // Se após filtro não sobrou nada, usa média de todas
      return samples.reduce((a, b) => a + b) / samples.length;
    }

    // Calcula média das amostras filtradas
    return filtered.reduce((a, b) => a + b) / filtered.length;
  }

  /// Testa upload (implementação simplificada - pode ser melhorada)
  Future<double> _testUpload({
    required String serverUrl,
    required Function(double) onProgress,
  }) async {
    _isCancelled = false;
    final client = http.Client();
    _activeClients.add(client);

    try {
      // Gera dados de teste (10MB)
      const testDataSize = 10 * 1024 * 1024;
      final testData = List<int>.generate(
        testDataSize,
        (index) => index % 256,
      );

      final startTime = DateTime.now();
      final request = http.Request('POST', Uri.parse(serverUrl));
      request.bodyBytes = testData;

      final response = await client.send(request).timeout(
            const Duration(seconds: 30),
          );

      if (response.statusCode != 200 && response.statusCode != 201) {
        return 0;
      }

      final elapsed = DateTime.now().difference(startTime);
      final elapsedSeconds = elapsed.inMilliseconds / 1000.0;

      if (elapsedSeconds <= 0) return 0;

      // Calcula velocidade em Mbps
      final speedMbps = (testDataSize * 8) / (elapsedSeconds * 1024 * 1024);
      onProgress(speedMbps);

      return speedMbps;
    } finally {
      client.close();
      _activeClients.remove(client);
    }
  }

  void _cleanupClients() {
    for (final client in _activeClients) {
      try {
        client.close();
      } catch (e) {
        // Ignora erros ao fechar
      }
    }
    _activeClients.clear();
  }

  @override
  void cancelTest() {
    _userCancelled = true; // Marca como cancelado pelo usuário
    _isCancelled = true; // Para todas as conexões
    _cleanupClients();
  }
}

/// Estatísticas de uma conexão individual
class ConnectionStats {
  DateTime? startTime;
  DateTime? lastUpdate;
  int bytesReceived = 0;
  final List<double> samples = [];

  void addSample(double speedMbps) {
    samples.add(speedMbps);
  }
}
