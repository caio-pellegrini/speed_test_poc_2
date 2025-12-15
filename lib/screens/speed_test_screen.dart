import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_test_plus/flutter_speed_test_plus.dart';
import 'package:speed_test/services/network_service.dart';
import 'package:speed_test/widgets/loading_widget.dart';
import 'package:android_intent_plus/android_intent.dart';

class SpeedTestScreen extends StatefulWidget {
  const SpeedTestScreen({super.key});

  @override
  State<SpeedTestScreen> createState() => _SpeedTestScreenState();
}

class _SpeedTestScreenState extends State<SpeedTestScreen> {
  final internetSpeedTest = FlutterInternetSpeedTest()..enableLog();
  final NetworkService _networkService = NetworkService();

  // Constante: Multiplicador para ajuste da taxa de download
  // Nota: Ajuste aplicado para calibrar resultados do teste
  static const double _downloadRateMultiplier = 2.0;

  double _downloadRate = 0;
  double _uploadRate = 0;
  bool _isServerSelectionInProgress = false;
  bool _isTesting = false;
  double _testProgress = 0.0; // Progresso do teste (0.0 a 1.0)
  String _currentTestPhase = ''; // Fase atual do teste
  bool _isConnectionCardExpanded = false; // Estado do card de conexão

  String? _serverIp;

  // Variáveis para tipo de conexão e latência
  Map<String, dynamic>? _connectionType;
  int? _latency;
  Map<String, dynamic>? _wifiInfo;
  Map<String, dynamic>? _mobileInfo;
  Map<String, dynamic>? _ethernetInfo;

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

        // Atualiza informações de conexão baseado no tipo
        _updateConnectionInfoForType(connectionType['type']);
      },
      onError: (error) {
        // Em caso de erro, mantém o estado atual
        if (mounted) {
          if (kDebugMode) {
            debugPrint('Erro no listener de conectividade: $error');
          }
          // Mostra feedback de erro ao usuário
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao monitorar conexão: ${error.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      },
    );
  }

  Future<void> _loadConnectionType() async {
    try {
      final connectionType = await _networkService.getConnectionType();
      setState(() {
        _connectionType = connectionType;
      });

      // Atualiza informações de conexão baseado no tipo
      await _updateConnectionInfoForType(connectionType['type']);
    } catch (e) {
      if (mounted) {
        if (kDebugMode) {
          debugPrint('Erro ao carregar tipo de conexão: $e');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao verificar conexão: ${e.toString()}'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Limpa todas as informações de conexão
  void _clearConnectionInfo() {
    setState(() {
      _wifiInfo = null;
      _mobileInfo = null;
      _ethernetInfo = null;
    });
  }

  /// Atualiza informações de conexão baseado no tipo
  Future<void> _updateConnectionInfoForType(String? connectionType) async {
    if (connectionType == 'Wi-Fi') {
      await _loadWiFiInfo();
      setState(() {
        _mobileInfo = null;
        _ethernetInfo = null;
      });
    } else if (connectionType == 'Dados Móveis') {
      await _loadMobileInfo();
      setState(() {
        _wifiInfo = null;
        _ethernetInfo = null;
      });
    } else if (connectionType == 'Cabo (Ethernet)') {
      await _loadEthernetInfo();
      setState(() {
        _wifiInfo = null;
        _mobileInfo = null;
      });
    } else {
      _clearConnectionInfo();
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

  Future<void> _loadEthernetInfo() async {
    final ethernetInfo = await _networkService.getEthernetInfo();
    setState(() {
      _ethernetInfo = ethernetInfo;
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
      case 3: // Bluetooth
        return Icons.bluetooth;
      case 4: // Sem Conexão
        return Icons.signal_wifi_off;
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
      case 3: // Bluetooth
        return Colors.purple;
      case 4: // Sem Conexão
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 800;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final isTotem = isLargeScreen || (isLandscape && screenWidth > 600);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Diagnóstico de Rede - Totem"),
        backgroundColor: Colors.blueAccent,
        bottom: _isTesting
            ? PreferredSize(
                preferredSize: const Size.fromHeight(60),
                child: Container(
                  color: Colors.blueAccent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      _buildProgressBarWithIcons(),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              )
            : null,
      ),
      body: _isServerSelectionInProgress
          ? const LoadingWidget()
          : LayoutBuilder(
              builder: (context, constraints) {
                if (isTotem) {
                  // Layout horizontal para Totem (35% esquerda / 65% direita)
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Lado esquerdo (35%) - Conexão e Botão
                        Expanded(
                          flex: 35,
                          child: Column(
                            children: [
                              _buildConnectionCard(compact: false),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                height: 55,
                                child: ElevatedButton(
                                  onPressed: (_isTesting || !_hasConnection)
                                      ? null
                                      : _runTest,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueAccent,
                                    disabledBackgroundColor: Colors.grey[400],
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                  child: Text(
                                      _hasConnection
                                          ? "INICIAR TESTE"
                                          : "SEM CONEXÃO",
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 16)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        // Lado direito (65%) - Resultados
                        Expanded(
                          flex: 65,
                          child: Column(
                            children: [
                              _buildResultsGrid(isTotem: true),
                              if (_serverIp != null) ...[
                                const SizedBox(height: 10),
                                _buildServerIpCard(),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  // Layout vertical para Smart (Portrait)
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        // Card de Conexão Expansível (compacto por padrão)
                        _buildConnectionCard(compact: true),
                        const SizedBox(height: 10),

                        // Grid de Resultados (2 colunas)
                        _buildResultsGrid(isTotem: false),

                        // Card de IP do servidor (exibido após o grid)
                        if (_serverIp != null) ...[
                          const SizedBox(height: 10),
                          _buildServerIpCard(),
                        ],

                        const SizedBox(height: 20),

                        // Botão (sempre visível sem rolagem)
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: (_isTesting || !_hasConnection)
                                ? null
                                : _runTest,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              disabledBackgroundColor: Colors.grey[400],
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text(
                                _hasConnection
                                    ? "INICIAR TESTE"
                                    : "SEM CONEXÃO",
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 16)),
                          ),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
    );
  }

  /// Constrói barra de progresso com ícones de etapa no AppBar
  Widget _buildProgressBarWithIcons() {
    return Column(
      children: [
        // Ícones das etapas
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildPhaseIcon(Icons.download, 'Download', _testProgress > 0.0),
            const SizedBox(width: 20),
            _buildPhaseIcon(Icons.upload, 'Upload', _testProgress > 0.33),
            const SizedBox(width: 20),
            _buildPhaseIcon(
                Icons.network_check, 'Latência', _testProgress > 0.66),
          ],
        ),
        const SizedBox(height: 8),
        // Barra de progresso
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _testProgress,
            minHeight: 4,
            backgroundColor: Colors.white.withOpacity(0.3),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      ],
    );
  }

  /// Constrói ícone de fase do teste (aceso/apagado)
  Widget _buildPhaseIcon(IconData icon, String label, bool isActive) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.white.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: isActive ? Colors.blueAccent : Colors.white.withOpacity(0.5),
            size: 20,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  /// Abre as configurações de rede do sistema
  Future<void> _openNetworkSettings() async {
    try {
      if (Platform.isAndroid) {
        // Abre as configurações de Wi-Fi no Android usando Intent
        const AndroidIntent intent = AndroidIntent(
          action: 'android.settings.WIFI_SETTINGS',
        );
        await intent.launch();
      } else if (Platform.isIOS) {
        // No iOS, não há forma direta de abrir configurações de Wi-Fi
        // Mostra mensagem informativa
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'No iOS, acesse Configurações > Wi-Fi manualmente para alterar a rede.'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Erro ao abrir configurações de rede: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Não foi possível abrir as configurações. Tente abrir manualmente nas configurações do dispositivo.'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  Widget _buildConnectionCard({bool compact = true}) {
    // Determina quais informações técnicas exibir
    final connectionType = _connectionType?['type'];
    final hasWiFiInfo = connectionType == 'Wi-Fi' && _wifiInfo != null;
    final hasMobileInfo =
        connectionType == 'Dados Móveis' && _mobileInfo != null;
    final hasEthernetInfo =
        connectionType == 'Cabo (Ethernet)' && _ethernetInfo != null;
    final hasTechnicalInfo = hasWiFiInfo || hasMobileInfo || hasEthernetInfo;

    // Obter subtitle para exibição compacta baseado no tipo de conexão
    String? subtitleText;
    if (hasWiFiInfo) {
      // Wi-Fi: mostrar SSID
      subtitleText = _wifiInfo!['ssid']?.toString();
    } else if (hasMobileInfo) {
      // Dados Móveis: mostrar operadora, se não houver ou for desconhecido, mostrar IP
      final carrier = _mobileInfo!['carrier']?.toString();
      if (carrier != null &&
          carrier.isNotEmpty &&
          carrier.toLowerCase() != 'unknown' &&
          carrier.toLowerCase() != 'desconhecido') {
        subtitleText = carrier;
      } else {
        subtitleText = _mobileInfo!['ip']?.toString();
        if (subtitleText != null) {
          subtitleText = "IP: $subtitleText";
        }
      }
    } else if (hasEthernetInfo) {
      // Ethernet: mostrar IP
      final ip = _ethernetInfo!['ip']?.toString();
      if (ip != null) {
        subtitleText = "IP: $ip";
      }
    }

    if (!compact || !hasTechnicalInfo) {
      // Modo expandido ou sem informações técnicas (para Totem)
      return Card(
        elevation: 3,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabeçalho: Tipo de conexão
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _connectionColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_connectionIcon,
                        color: _connectionColor, size: 22),
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
                  // Botão para abrir configurações de rede
                  IconButton(
                    icon: const Icon(Icons.settings, size: 20),
                    color: Colors.grey[600],
                    tooltip: 'Abrir configurações de rede',
                    onPressed: _openNetworkSettings,
                  ),
                ],
              ),
              // Informações técnicas (se disponíveis)
              if (hasTechnicalInfo) ...[
                if (hasWiFiInfo) _buildTechnicalInfo(_wifiInfo!, 'Wi-Fi'),
                if (hasMobileInfo) _buildTechnicalInfo(_mobileInfo!, 'Mobile'),
                if (hasEthernetInfo)
                  _buildTechnicalInfo(_ethernetInfo!, 'Ethernet'),
              ],
            ],
          ),
        ),
      );
    }

    // Modo compacto expansível (para Smart)
    return Card(
      elevation: 3,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        initiallyExpanded: _isConnectionCardExpanded,
        onExpansionChanged: (expanded) {
          setState(() {
            _isConnectionCardExpanded = expanded;
          });
        },
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _connectionColor.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(_connectionIcon, color: _connectionColor, size: 20),
        ),
        title: Text(
          _connectionName,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: _connectionColor,
          ),
        ),
        subtitle: subtitleText != null
            ? Text(
                subtitleText,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.settings, size: 20),
              color: Colors.grey[600],
              tooltip: 'Abrir configurações de rede',
              onPressed: _openNetworkSettings,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            Icon(
              _isConnectionCardExpanded ? Icons.expand_less : Icons.expand_more,
              color: Colors.grey[600],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasWiFiInfo) _buildTechnicalInfo(_wifiInfo!, 'Wi-Fi'),
                if (hasMobileInfo) _buildTechnicalInfo(_mobileInfo!, 'Mobile'),
                if (hasEthernetInfo)
                  _buildTechnicalInfo(_ethernetInfo!, 'Ethernet'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechnicalInfo(Map<String, dynamic> info, String type) {
    final hasError = info.containsKey('error');

    if (hasError) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          info['error'] ?? 'Erro ao obter informações',
          style: const TextStyle(
            fontSize: 13,
            color: Colors.red,
          ),
        ),
      );
    }

    if (type == 'Wi-Fi') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow("SSID", info['ssid'] ?? '--'),
          const SizedBox(height: 6),
          _buildInfoRow("BSSID", info['bssid'] ?? '--'),
          const SizedBox(height: 6),
          _buildInfoRow(
            "Sinal",
            info['signal'] != null ? "${info['signal']} dBm" : '--',
          ),
          const SizedBox(height: 6),
          _buildInfoRow(
            "Frequência",
            info['frequency'] != null ? "${info['frequency']} MHz" : '--',
          ),
          const SizedBox(height: 6),
          _buildInfoRow("IP", info['ip'] ?? '--'),
        ],
      );
    } else if (type == 'Mobile') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow("Operadora", info['carrier'] ?? '--'),
          const SizedBox(height: 6),
          _buildInfoRow("Tipo de Rede", info['networkType'] ?? '--'),
          if (info['simState'] != null) ...[
            const SizedBox(height: 6),
            _buildInfoRow("Estado SIM", info['simState'] ?? '--'),
          ],
          const SizedBox(height: 6),
          _buildInfoRow("IP", info['ip'] ?? '--'),
        ],
      );
    } else if (type == 'Ethernet') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow("Endereço IP", info['ip'] ?? '--'),
          const SizedBox(height: 6),
          _buildInfoRow("MAC Address", info['mac'] ?? '--'),
          const SizedBox(height: 6),
          _buildInfoRow("Interface", info['interface'] ?? '--'),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
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
                    "IP do servidor",
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

  /// Constrói o grid de resultados (métricas)
  Widget _buildResultsGrid({required bool isTotem}) {
    // Totem: 4 colunas (1 linha), Smart: 2 colunas (2 linhas)
    final crossAxisCount = isTotem ? 4 : 2;
    final childAspectRatio = isTotem ? 1.4 : 1.1;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: childAspectRatio,
      children: [
        _buildMetricCard(
            "Download", _downloadRate, Icons.download, Colors.green),
        _buildMetricCard("Upload", _uploadRate, Icons.upload, Colors.purple),
        _buildMetricInfo(
          "Latência",
          _latency == null
              ? "-- ms"
              : _latency == -1
                  ? "Erro"
                  : "$_latency ms",
          Icons.network_check,
          Colors.orange,
        ),
        _buildMetricInfo(
          "VPN",
          _latency != null && _latency! > 0 && _latency! < 100
              ? "Estável"
              : "Verificar",
          Icons.vpn_lock,
          Colors.blueGrey,
        ),
      ],
    );
  }

  Widget _buildMetricCard(
      String title, double value, IconData icon, Color color) {
    final isUpdating = _isTesting &&
        ((title == "Download" && _currentTestPhase.contains("download")) ||
            (title == "Upload" && _currentTestPhase.contains("upload")));

    // Separa número e unidade para destacar o número
    final valueText = value.toStringAsFixed(1);
    const unitText = " Mbps";

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: Card(
        elevation: isUpdating ? 4 : 2,
        color: isUpdating ? color.withOpacity(0.05) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side:
              isUpdating ? BorderSide(color: color, width: 2) : BorderSide.none,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, size: 35, color: color),
                if (isUpdating)
                  SizedBox(
                    width: 35,
                    height: 35,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(title,
                style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            const SizedBox(height: 4),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Row(
                key: ValueKey(value),
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    valueText,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isUpdating ? color : Colors.grey[800],
                    ),
                  ),
                  Text(
                    unitText,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                      color: isUpdating
                          ? color.withOpacity(0.7)
                          : Colors.grey[600],
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

  Widget _buildMetricInfo(
      String title, String value, IconData icon, Color color) {
    // Separa número e unidade quando possível
    final hasNumber = RegExp(r'(\d+\.?\d*)').hasMatch(value);
    String? numberPart;
    String? unitPart;

    if (hasNumber) {
      final match = RegExp(r'(\d+\.?\d*)\s*(.*)').firstMatch(value);
      if (match != null) {
        numberPart = match.group(1);
        unitPart = match.group(2)?.trim();
      }
    }

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
          numberPart != null && unitPart != null && unitPart.isNotEmpty
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      numberPart,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    Text(
                      " $unitPart",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                )
              : Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
        ],
      ),
    );
  }

  Future<void> _runTest() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        // Verifica o tipo de conexão antes de iniciar o teste
        await _loadConnectionType();

        setState(() {
          _isTesting = true;
          _downloadRate = 0;
          _uploadRate = 0;
          _latency = null;
          _testProgress = 0.0;
          _currentTestPhase = '';
        });

        // Executa o teste de velocidade primeiro
        await internetSpeedTest.startTesting(
          useFastApi: true,
          onCompleted: (download, upload) async {
            if (mounted) {
              setState(() {
                _downloadRate = double.parse(
                    (download.transferRate * _downloadRateMultiplier)
                        .toStringAsPrecision(3));
                _uploadRate =
                    double.parse(upload.transferRate.toStringAsPrecision(3));
                _testProgress = 0.66;
                _currentTestPhase = 'Etapa 3 de 3';
              });

              // Executa o teste de latência por último
              final latency = await _networkService.testLatency();
              if (mounted) {
                setState(() {
                  _latency = latency;
                  _isTesting = false;
                  _testProgress = 1.0;
                  _currentTestPhase = '';
                });
              }
            }
          },
          onProgress: (percent, data) {
            if (mounted) {
              setState(() {
                if (data.type == TestType.download) {
                  _downloadRate = double.parse(
                      (data.transferRate * _downloadRateMultiplier)
                          .toStringAsPrecision(3));
                  _currentTestPhase = 'Etapa 1 de 3';
                  _testProgress = 0.0 + (percent / 100 * 0.33);
                } else {
                  _uploadRate =
                      double.parse(data.transferRate.toStringAsPrecision(3));
                  _currentTestPhase = 'Etapa 2 de 3';
                  _testProgress = 0.33 + (percent / 100 * 0.33);
                }
              });
            }
          },
          onDefaultServerSelectionInProgress: () {
            if (mounted) {
              setState(() {
                _isServerSelectionInProgress = true;
                _testProgress = 0.05;
              });
            }
          },
          onDefaultServerSelectionDone: (client) {
            if (mounted) {
              setState(() {
                _isServerSelectionInProgress = false;
                _serverIp = client?.ip;
              });
            }
          },
          onError: (errorMessage, speedTestError) {
            if (mounted) {
              reset();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Erro no teste: $errorMessage'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          },
          onCancel: () {
            if (mounted) {
              reset();
            }
          },
        );
      } catch (e) {
        if (mounted) {
          reset();
          if (kDebugMode) {
            debugPrint('Erro ao executar teste: $e');
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao iniciar teste: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    });
  }

  void reset() {
    setState(() {
      _downloadRate = 0;
      _uploadRate = 0;
      _serverIp = null;
      _isTesting = false;
      _testProgress = 0.0;
      _currentTestPhase = '';
      _latency = null;
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
