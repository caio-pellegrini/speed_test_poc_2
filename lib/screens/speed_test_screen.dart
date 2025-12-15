import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_speed_test_plus/flutter_speed_test_plus.dart';
import 'package:speed_test/services/network_service.dart';
import 'package:speed_test/widgets/loading_widget.dart';

class SpeedTestScreen extends StatefulWidget {
  const SpeedTestScreen({super.key});

  @override
  State<SpeedTestScreen> createState() => _SpeedTestScreenState();
}

class _SpeedTestScreenState extends State<SpeedTestScreen> {
  final internetSpeedTest = FlutterInternetSpeedTest()..enableLog();
  final NetworkService _networkService = NetworkService();

  // Multiplicador para ajuste da taxa de download
  static const double _downloadRateMultiplier = 2.0;

  double _downloadRate = 0;
  double _uploadRate = 0;
  bool _isServerSelectionInProgress = false;
  bool _isTesting = false;
  bool _runTestIsComplete = false;

  String? _serverIp;
  String _status = "Pronto para testar";

  // Variáveis para tipo de conexão e latência
  Map<String, dynamic>? _connectionType;
  int? _latency;
  Map<String, dynamic>? _wifiInfo;
  Map<String, dynamic>? _mobileInfo;

  // Stream subscription para monitorar mudanças de conectividade
  StreamSubscription<Map<String, dynamic>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _loadConnectionType();
    _setupConnectivityListener();
  }

  /// Configura o listener para mudanças de conectividade
  void _setupConnectivityListener() {
    _connectivitySubscription =
        _networkService.getConnectionTypeStream().listen(
      (Map<String, dynamic> connectionType) {
        // Atualiza o tipo de conexão
        setState(() {
          _connectionType = connectionType;
        });

        // Se mudou para Wi-Fi, carrega informações detalhadas
        if (connectionType['type'] == 'Wi-Fi') {
          _loadWiFiInfo();
          setState(() {
            _mobileInfo = null;
          });
        } else if (connectionType['type'] == 'Dados Móveis') {
          // Se mudou para dados móveis, carrega informações detalhadas
          _loadMobileInfo();
          setState(() {
            _wifiInfo = null;
          });
        } else {
          // Se mudou para outro tipo, limpa as informações
          setState(() {
            _wifiInfo = null;
            _mobileInfo = null;
          });
        }
      },
      onError: (error) {
        // Em caso de erro, mantém o estado atual
        if (mounted) {
          // Opcional: pode adicionar um indicador de erro na UI
          print('Erro no listener de conectividade: $error');
        }
      },
    );
  }

  Future<void> _loadConnectionType() async {
    final connectionType = await _networkService.getConnectionType();
    setState(() {
      _connectionType = connectionType;
    });

    // Se estiver conectado via Wi-Fi, carrega informações detalhadas
    if (connectionType['type'] == 'Wi-Fi') {
      await _loadWiFiInfo();
      setState(() {
        _mobileInfo = null;
      });
    } else if (connectionType['type'] == 'Dados Móveis') {
      // Se estiver conectado via dados móveis, carrega informações detalhadas
      await _loadMobileInfo();
      setState(() {
        _wifiInfo = null;
      });
    } else {
      setState(() {
        _wifiInfo = null;
        _mobileInfo = null;
      });
    }
  }

  Future<void> _loadWiFiInfo() async {
    final wifiInfo = await _networkService.getWiFiInfo();
    setState(() {
      _wifiInfo = wifiInfo;
    });
  }

  Future<void> _loadMobileInfo() async {
    final mobileInfo = await _networkService.getMobileInfo();
    setState(() {
      _mobileInfo = mobileInfo;
    });
  }

  bool get _hasConnection {
    return _connectionType != null &&
        _connectionType!['type'] != 'Sem Conexão' &&
        _connectionType!['type'] != 'Desconhecido';
  }

  String get _connectionName {
    return _connectionType?['type'] ?? 'Carregando...';
  }

  IconData get _connectionIcon {
    if (_connectionType == null) return Icons.help_outline;
    switch (_connectionType!['icon']) {
      case 0: // Cabo (Ethernet)
        return Icons.cable;
      case 1: // Wi-Fi
        return Icons.wifi;
      case 2: // Dados Móveis
        return Icons.signal_cellular_alt;
      case 3: // Sem Conexão
        return Icons.signal_wifi_off;
      case 4: // Bluetooth
        return Icons.bluetooth;
      default:
        return Icons.help_outline;
    }
  }

  Color get _connectionColor {
    if (_connectionType == null) return Colors.grey;
    switch (_connectionType!['icon']) {
      case 0: // Cabo (Ethernet)
        return Colors.green;
      case 1: // Wi-Fi
        return Colors.blue;
      case 2: // Dados Móveis
        return Colors.orange;
      case 3: // Sem Conexão
        return Colors.red;
      case 4: // Bluetooth
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Diagnóstico de Rede - Totem"),
        backgroundColor: Colors.blueAccent,
      ),
      body: _isServerSelectionInProgress
          ? const LoadingWidget()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // Card de Status
                  Card(
                    elevation: 4,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          // Ícone e Status em Row
                          Row(
                            children: [
                              if (_isTesting)
                                const Icon(Icons.speed,
                                    size: 40, color: Colors.blueAccent)
                              else
                                Icon(Icons.check_circle_outline,
                                    size: 40, color: Colors.grey[400]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(_status,
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[800])),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Card de Conexão
                  _buildConnectionCard(),
                  const SizedBox(height: 10),

                  // Card de Informações Wi-Fi (apenas se conectado via Wi-Fi)
                  if (_connectionType?['type'] == 'Wi-Fi' &&
                      _wifiInfo != null) ...[
                    _buildWiFiInfoCard(),
                    const SizedBox(height: 10),
                  ],

                  // Card de Informações de Dados Móveis (apenas se conectado via dados móveis)
                  if (_connectionType?['type'] == 'Dados Móveis' &&
                      _mobileInfo != null) ...[
                    _buildMobileInfoCard(),
                    const SizedBox(height: 10),
                  ],
                  // Card de Endereço IP
                  if (_serverIp != null) ...[
                    _buildServerIpCard(),
                    const SizedBox(height: 10),
                  ],

                  // Grid de Resultados
                  LayoutBuilder(
                    builder: (context, constraints) {
                      // Determina o número de colunas baseado na largura da tela
                      final screenWidth = MediaQuery.of(context).size.width;
                      final crossAxisCount = screenWidth > 600 ? 4 : 2;
                      // Ajusta o aspect ratio para telas largas
                      final childAspectRatio = screenWidth > 600 ? 1.3 : 1.1;

                      return GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: childAspectRatio,
                        children: [
                          _buildMetricCard("Download", _downloadRate,
                              Icons.download, Colors.green),
                          _buildMetricCard("Upload", _uploadRate, Icons.upload,
                              Colors.purple),
                          _buildMetricInfo(
                              "Latência",
                              _latency == null
                                  ? "-- ms"
                                  : _latency == -1
                                      ? "Erro"
                                      : "$_latency ms",
                              Icons.network_check,
                              Colors.orange),
                          _buildMetricInfo(
                              "VPN",
                              _latency != null &&
                                      _latency! > 0 &&
                                      _latency! < 100
                                  ? "Estável"
                                  : "Verificar",
                              Icons.vpn_lock,
                              Colors.blueGrey),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // Botão
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed:
                          (_isTesting || !_hasConnection) ? null : _runTest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        disabledBackgroundColor: Colors.grey[400],
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                          _hasConnection ? "INICIAR TESTE" : "SEM CONEXÃO",
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildConnectionCard() {
    return Card(
      elevation: 3,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _connectionColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(_connectionIcon, color: _connectionColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Conexão atual",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _connectionName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _connectionColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWiFiInfoCard() {
    final hasError = _wifiInfo?.containsKey('error') ?? false;

    return Card(
      elevation: 3,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.wifi, color: Colors.blue, size: 22),
                ),
                const SizedBox(width: 12),
                const Text(
                  "Informações da Rede Wi-Fi",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (hasError)
              Text(
                _wifiInfo!['error'] ?? 'Erro ao obter informações',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.red,
                ),
              )
            else ...[
              _buildWiFiInfoRow("SSID", _wifiInfo!['ssid'] ?? '--'),
              const SizedBox(height: 8),
              _buildWiFiInfoRow("BSSID", _wifiInfo!['bssid'] ?? '--'),
              const SizedBox(height: 8),
              _buildWiFiInfoRow(
                "Sinal",
                _wifiInfo!['signal'] != null
                    ? "${_wifiInfo!['signal']} dBm"
                    : '--',
              ),
              const SizedBox(height: 8),
              _buildWiFiInfoRow(
                "Frequência",
                _wifiInfo!['frequency'] != null
                    ? "${_wifiInfo!['frequency']} MHz"
                    : '--',
              ),
              const SizedBox(height: 8),
              _buildWiFiInfoRow("IP", _wifiInfo!['ip'] ?? '--'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMobileInfoCard() {
    final hasError = _mobileInfo?.containsKey('error') ?? false;

    return Card(
      elevation: 3,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.signal_cellular_alt,
                      color: Colors.orange, size: 22),
                ),
                const SizedBox(width: 12),
                const Text(
                  "Informações de Dados Móveis",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (hasError)
              Text(
                _mobileInfo!['error'] ?? 'Erro ao obter informações',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.red,
                ),
              )
            else ...[
              _buildWiFiInfoRow("Operadora", _mobileInfo!['carrier'] ?? '--'),
              const SizedBox(height: 8),
              _buildWiFiInfoRow(
                  "Tipo de Rede", _mobileInfo!['networkType'] ?? '--'),
              const SizedBox(height: 8),
              if (_mobileInfo!['simState'] != null) ...[
                _buildWiFiInfoRow(
                    "Estado SIM", _mobileInfo!['simState'] ?? '--'),
                const SizedBox(height: 8),
              ],
              _buildWiFiInfoRow("IP", _mobileInfo!['ip'] ?? '--'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWiFiInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildServerIpCard() {
    return Card(
      elevation: 3,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.language, color: Colors.blue, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Endereço IP",
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isServerSelectionInProgress
                        ? "Selecionando servidor..."
                        : (_serverIp ?? "--"),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
      String title, double value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 35, color: color),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          const SizedBox(height: 4),
          Text("${value.toStringAsFixed(1)} Mbps",
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800])),
        ],
      ),
    );
  }

  Widget _buildMetricInfo(
      String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 35, color: color),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800])),
        ],
      ),
    );
  }

  Future<void> _runTest() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Verifica o tipo de conexão antes de iniciar o teste
      await _loadConnectionType();

      setState(() {
        _isTesting = true;
        _runTestIsComplete = false;
        _downloadRate = 0;
        _uploadRate = 0;
        _latency = null;
        _status = "Testando latência...";
      });

      // Executa o teste de latência antes do teste de velocidade
      final latency = await _networkService.testLatency();
      setState(() {
        _latency = latency;
        _status = "Testando velocidade...";
      });

      await internetSpeedTest.startTesting(
        useFastApi: true,
        onCompleted: (download, upload) {
          setState(() {
            _runTestIsComplete = true;
            _isTesting = false;
            _status = "Teste concluído";
            _downloadRate = double.parse(
                (download.transferRate * _downloadRateMultiplier)
                    .toStringAsPrecision(3));
            _uploadRate =
                double.parse(upload.transferRate.toStringAsPrecision(3));
          });
        },
        onProgress: (percent, data) {
          setState(() {
            if (data.type == TestType.download) {
              _downloadRate = double.parse(
                  (data.transferRate * _downloadRateMultiplier)
                      .toStringAsPrecision(3));
              _status = "Testando download...";
            } else {
              _uploadRate =
                  double.parse(data.transferRate.toStringAsPrecision(3));
              _status = "Testando upload...";
            }
          });
        },
        onDefaultServerSelectionInProgress: () {
          setState(() {
            _isServerSelectionInProgress = true;
            _status = "Selecionando servidor...";
          });
        },
        onDefaultServerSelectionDone: (client) {
          setState(() {
            _isServerSelectionInProgress = false;
            _serverIp = client?.ip;
          });
        },
        onError: (errorMessage, speedTestError) {
          reset();
        },
        onCancel: () {
          reset();
        },
      );
    });
  }

  void reset() {
    setState(() {
      _downloadRate = 0;
      _uploadRate = 0;
      _serverIp = null;
      _isTesting = false;
      _latency = null;
      _status = "Pronto para testar";
      _wifiInfo = null;
      _mobileInfo = null;
    });
    _loadConnectionType();
  }

  @override
  void dispose() {
    // Cancela a subscription para evitar memory leaks
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
