import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:speed_test/app/shared/widgets/loading_widget.dart';
import 'package:speed_test/app/shared/helpers/dialog_helper.dart';
import '../mobx/speed_test.store.dart';

class SpeedTestPage extends StatelessWidget {
  final SpeedTestStore store;

  const SpeedTestPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 800;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final isTotem = isLargeScreen || (isLandscape && screenWidth > 600);

    return Observer(
      builder: (_) => Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: const Text("Diagnóstico de Rede - Totem"),
          backgroundColor: Colors.blueAccent,
          bottom: store.isTesting
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(60),
                  child: Container(
                    color: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Column(
                      children: [
                        _buildProgressBarWithIcons(store),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                )
              : null,
        ),
        body: store.isServerSelectionInProgress
            ? const LoadingWidget()
            : LayoutBuilder(
                builder: (context, constraints) {
                  if (isTotem) {
                    return _buildTotemLayout(context, store);
                  } else {
                    return _buildMobileLayout(context, store);
                  }
                },
              ),
      ),
    );
  }

  Widget _buildTotemLayout(BuildContext context, SpeedTestStore store) {
    return Observer(
      builder: (_) => SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 35,
              child: Column(
                children: [
                  _buildConnectionCard(context, store, compact: false),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: (store.isTesting || !store.hasConnection)
                          ? null
                          : () => _runTest(context, store),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        disabledBackgroundColor: Colors.grey[400],
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        store.hasConnection ? "INICIAR TESTE" : "SEM CONEXÃO",
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 65,
              child: Column(
                children: [
                  _buildResultsGrid(store, isTotem: true),
                  if (store.serverIp != null) ...[
                    const SizedBox(height: 10),
                    _buildServerIpCard(store),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, SpeedTestStore store) {
    return Observer(
      builder: (_) => SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _buildConnectionCard(context, store, compact: true),
            const SizedBox(height: 10),
            _buildResultsGrid(store, isTotem: false),
            if (store.serverIp != null) ...[
              const SizedBox(height: 10),
              _buildServerIpCard(store),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: (store.isTesting || !store.hasConnection)
                    ? null
                    : () => _runTest(context, store),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  disabledBackgroundColor: Colors.grey[400],
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  store.hasConnection ? "INICIAR TESTE" : "SEM CONEXÃO",
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBarWithIcons(SpeedTestStore store) {
    return Observer(
      builder: (_) => Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildPhaseIcon(
                  Icons.download, 'Download', store.testProgress > 0.0),
              const SizedBox(width: 20),
              _buildPhaseIcon(
                  Icons.upload, 'Upload', store.testProgress > 0.33),
              const SizedBox(width: 20),
              _buildPhaseIcon(Icons.network_check, 'Latência',
                  store.testProgress > 0.66),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: store.testProgress,
              minHeight: 4,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

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
            color: isActive
                ? Colors.blueAccent
                : Colors.white.withOpacity(0.5),
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

  Future<void> _openNetworkSettings(BuildContext context) async {
    try {
      if (Platform.isAndroid) {
        const AndroidIntent intent = AndroidIntent(
          action: 'android.settings.WIFI_SETTINGS',
        );
        await intent.launch();
      } else if (Platform.isIOS) {
        DialogHelper.showInfo(
          context,
          'No iOS, acesse Configurações > Wi-Fi manualmente para alterar a rede.',
        );
      }
    } catch (e) {
      DialogHelper.showWarning(
        context,
        'Não foi possível abrir as configurações. Tente abrir manualmente nas configurações do dispositivo.',
      );
    }
  }

  Widget _buildConnectionCard(
      BuildContext context, SpeedTestStore store, {bool compact = true}) {
    return Observer(
      builder: (_) {
        if (store.connectionInfo == null) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final connectionInfo = store.connectionInfo!;
        final connectionDetails = connectionInfo.connectionDetails;
        final hasTechnicalInfo = connectionDetails != null;

        String? subtitleText;
        if (connectionInfo.wifiInfo != null) {
          subtitleText = connectionInfo.wifiInfo!['ssid']?.toString();
        } else if (connectionInfo.mobileInfo != null) {
          final carrier = connectionInfo.mobileInfo!['carrier']?.toString();
          if (carrier != null &&
              carrier.isNotEmpty &&
              carrier.toLowerCase() != 'unknown' &&
              carrier.toLowerCase() != 'desconhecido') {
            subtitleText = carrier;
          } else {
            subtitleText = connectionInfo.mobileInfo!['ip']?.toString();
            if (subtitleText != null) {
              subtitleText = "IP: $subtitleText";
            }
          }
        } else if (connectionInfo.ethernetInfo != null) {
          final ip = connectionInfo.ethernetInfo!['ip']?.toString();
          if (ip != null) {
            subtitleText = "IP: $ip";
          }
        }

        if (!compact || !hasTechnicalInfo) {
          return Card(
            elevation: 3,
            color: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                          color: store.connectionColor.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(store.connectionIcon,
                            color: store.connectionColor, size: 22),
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
                              store.connectionName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: store.connectionColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings, size: 20),
                        color: Colors.grey[600],
                        tooltip: 'Abrir configurações de rede',
                        onPressed: () => _openNetworkSettings(context),
                      ),
                    ],
                  ),
                  if (hasTechnicalInfo) ...[
                    const SizedBox(height: 12),
                    _buildTechnicalInfo(connectionDetails,
                        connectionInfo.type),
                  ],
                ],
              ),
            ),
          );
        }

        return Card(
          elevation: 3,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            initiallyExpanded: store.isConnectionCardExpanded,
            onExpansionChanged: (expanded) {
              store.toggleConnectionCardExpanded();
            },
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: store.connectionColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(store.connectionIcon,
                  color: store.connectionColor, size: 20),
            ),
            title: Text(
              store.connectionName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: store.connectionColor,
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
                  onPressed: () => _openNetworkSettings(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                Icon(
                  store.isConnectionCardExpanded
                      ? Icons.expand_less
                      : Icons.expand_more,
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
                    if (hasTechnicalInfo)
                      _buildTechnicalInfo(connectionDetails, connectionInfo.type),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTechnicalInfo(
      Map<String, dynamic> info, String connectionType) {
    final hasError = info.containsKey('error');

    if (hasError) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          info['error'] ?? 'Erro ao obter informações',
          style: const TextStyle(fontSize: 13, color: Colors.red),
        ),
      );
    }

    if (connectionType == 'Wi-Fi') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow("SSID", info['ssid'] ?? '--'),
          const SizedBox(height: 6),
          _buildInfoRow("BSSID", info['bssid'] ?? '--'),
          const SizedBox(height: 6),
          _buildInfoRow("Sinal",
              info['signal'] != null ? "${info['signal']} dBm" : '--'),
          const SizedBox(height: 6),
          _buildInfoRow("Frequência",
              info['frequency'] != null ? "${info['frequency']} MHz" : '--'),
          const SizedBox(height: 6),
          _buildInfoRow("IP", info['ip'] ?? '--'),
        ],
      );
    } else if (connectionType == 'Dados Móveis') {
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
    } else if (connectionType == 'Cabo (Ethernet)') {
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

  Widget _buildServerIpCard(SpeedTestStore store) {
    return Observer(
      builder: (_) => Card(
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
                      store.isServerSelectionInProgress
                          ? "Selecionando servidor..."
                          : (store.serverIp ?? "--"),
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
      ),
    );
  }

  Widget _buildResultsGrid(SpeedTestStore store, {required bool isTotem}) {
    return Observer(
      builder: (_) {
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
            _buildMetricCard("Download", store.downloadRate, Icons.download,
                Colors.green, store),
            _buildMetricCard(
                "Upload", store.uploadRate, Icons.upload, Colors.purple, store),
            _buildMetricInfo(
              "Latência",
              store.latency == null
                  ? "-- ms"
                  : store.latency == -1
                      ? "Erro"
                      : "${store.latency} ms",
              Icons.network_check,
              Colors.orange,
            ),
            _buildMetricInfo(
              "VPN",
              store.latency != null &&
                      store.latency! > 0 &&
                      store.latency! < 100
                  ? "Estável"
                  : "Verificar",
              Icons.vpn_lock,
              Colors.blueGrey,
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard(String title, double value, IconData icon,
      Color color, SpeedTestStore store) {
    return Observer(
      builder: (_) {
        final isUpdating = store.isTesting &&
            ((title == "Download" &&
                store.currentTestPhase.contains("download")) ||
                (title == "Upload" &&
                    store.currentTestPhase.contains("upload")));

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
              side: isUpdating
                  ? BorderSide(color: color, width: 2)
                  : BorderSide.none,
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
      },
    );
  }

  Widget _buildMetricInfo(
      String title, String value, IconData icon, Color color) {
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

  Future<void> _runTest(BuildContext context, SpeedTestStore store) async {
    try {
      await store.runTest();
    } catch (e) {
      DialogHelper.showError(context, 'Erro ao executar teste: ${e.toString()}');
    }
  }
}

