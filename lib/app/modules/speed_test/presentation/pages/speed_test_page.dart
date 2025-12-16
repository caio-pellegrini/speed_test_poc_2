import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:speed_test/app/shared/widgets/loading_widget.dart';
import 'package:speed_test/app/shared/helpers/dialog_helper.dart';
import '../mobx/speed_test.store.dart';

class SpeedTestPage extends StatelessWidget {
  final SpeedTestStore store;
  static const Color primaryColor = Color(0xFFFF6600);

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
          title: const Text("Diagnóstico de Rede"),
          backgroundColor: primaryColor,
          bottom: store.isTesting
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(60),
                  child: Container(
                    color: primaryColor,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    return _buildTotemLayout(context, store, constraints);
                  } else {
                    return _buildMobileLayout(context, store);
                  }
                },
              ),
      ),
    );
  }

  Widget _buildTotemLayout(
      BuildContext context, SpeedTestStore store, BoxConstraints constraints) {
    return Observer(
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 35,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildConnectionCard(context, store, compact: false),
                  const SizedBox(height: 20),
                  _buildTestButton(context, store),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              flex: 65,
              child: LayoutBuilder(
                builder: (context, rightConstraints) {
                  return Column(
                    children: [
                      Expanded(
                        child: _buildResultsGrid(
                          store,
                          isTotem: true,
                          availableHeight: constraints.maxHeight,
                          availableWidth: rightConstraints.maxWidth,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildServerIpCard(store),
                    ],
                  );
                },
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
            _buildTestButton(context, store),
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
              _buildPhaseIcon(
                  Icons.network_check, 'Latência', store.testProgress > 0.66),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: _AnimatedProgressBar(
              progress: store.testProgress,
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
            color: isActive ? primaryColor : Colors.white.withOpacity(0.5),
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

  Widget _buildConnectionCard(BuildContext context, SpeedTestStore store,
      {bool compact = true}) {
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
                    _buildTechnicalInfo(connectionDetails, connectionInfo.type),
                  ],
                ],
              ),
            ),
          );
        }

        return Card(
          elevation: 3,
          color: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
            ),
            child: ExpansionTile(
              initiallyExpanded: store.isConnectionCardExpanded,
              onExpansionChanged: (expanded) {
                store.toggleConnectionCardExpanded();
              },
              tilePadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              childrenPadding: EdgeInsets.zero,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
              collapsedShape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
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
                        _buildTechnicalInfo(
                            connectionDetails, connectionInfo.type),
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

  Widget _buildTechnicalInfo(Map<String, dynamic> info, String connectionType) {
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
          _buildInfoRow(
              "Sinal", info['signal'] != null ? "${info['signal']} dBm" : '--'),
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
                  color: primaryColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.language, color: primaryColor, size: 22),
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
                        color: primaryColor,
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

  Widget _buildResultsGrid(SpeedTestStore store,
      {required bool isTotem,
      double? availableHeight,
      double? availableWidth}) {
    return Observer(
      builder: (_) {
        if (isTotem) {
          // Grid 2x2 para totem
          final crossAxisCount = 2;
          // Calcula o aspect ratio baseado na altura e largura disponíveis
          // Considera o espaçamento do grid (10px entre itens) e o card do servidor
          final serverCardHeight =
              80.0; // altura aproximada do card do servidor
          final padding = 20.0 * 2; // padding top e bottom do layout
          final spacing =
              10.0; // espaçamento entre linhas (2 linhas = 1 espaço)
          final spacingBetweenGridAndCard =
              10.0; // espaçamento entre grid e card do servidor
          final gridHeight = ((availableHeight ?? 400) -
                  padding -
                  serverCardHeight -
                  spacing -
                  spacingBetweenGridAndCard)
              .clamp(
                  100.0,
                  double
                      .infinity); // mínimo de 100px para evitar valores muito pequenos
          final itemHeight = ((gridHeight / 2) - (spacing / 2))
              .clamp(50.0, double.infinity); // mínimo de 50px por item
          final itemWidth = (((availableWidth ?? 400) - spacing) / 2)
              .clamp(50.0, double.infinity); // mínimo de 50px por item
          final childAspectRatio = (itemWidth / itemHeight)
              .clamp(0.5, 2.0); // aspect ratio entre 0.5 e 2.0

          return GridView.count(
            shrinkWrap: false,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: childAspectRatio,
            children: [
              _buildMetricCard("Download", store.downloadRate, Icons.download,
                  Colors.green, store),
              _buildMetricCard("Upload", store.uploadRate, Icons.upload,
                  Colors.purple, store),
              _buildLatencyCard(store),
              _buildQualityCard(store),
            ],
          );
        } else {
          // Layout mobile mantém como estava
          final crossAxisCount = 2;
          final childAspectRatio = 1.1;

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
              _buildMetricCard("Upload", store.uploadRate, Icons.upload,
                  Colors.purple, store),
              _buildLatencyCard(store),
              _buildQualityCard(store),
            ],
          );
        }
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

  Widget _buildLatencyCard(SpeedTestStore store) {
    return Observer(
      builder: (_) {
        final latencyValue = store.latency;
        final value = latencyValue == null
            ? "-- ms"
            : latencyValue == -1
                ? "Erro"
                : "${latencyValue} ms";

        return _buildMetricInfo(
          "Latência",
          value,
          Icons.network_check,
          Colors.blue,
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

  Widget _buildQualityCard(SpeedTestStore store) {
    return Observer(
      builder: (_) {
        final quality = _calculateConnectionQuality(
          store.isTesting,
          store.downloadRate,
          store.uploadRate,
          store.latency,
        );

        final qualityText = quality['text'] as String;
        final qualityColor = quality['color'] as Color;
        final qualityIcon = quality['icon'] as IconData;

        return Card(
          elevation: 2,
          color: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(qualityIcon, size: 35, color: qualityColor),
              const SizedBox(height: 8),
              Text(
                "Qualidade",
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                qualityText,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: qualityColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Map<String, dynamic> _calculateConnectionQuality(
    bool isTesting,
    double downloadRate,
    double uploadRate,
    int? latency,
  ) {
    // Se o teste está em andamento, sempre mostra "Aguardando"
    if (isTesting) {
      return {
        'text': 'Aguardando',
        'color': Colors.grey,
        'icon': Icons.hourglass_empty,
      };
    }

    // Se não há resultados de teste ainda (após o teste ter terminado)
    if (downloadRate == 0 && uploadRate == 0 && latency == null) {
      return {
        'text': 'Aguardando',
        'color': Colors.grey,
        'icon': Icons.hourglass_empty,
      };
    }

    // Se há erro na latência
    if (latency == -1) {
      return {
        'text': 'Sem Conexão',
        'color': Colors.red,
        'icon': Icons.error_outline,
      };
    }

    int score = 0;
    int maxScore = 0;

    // Avalia Download (0-40 pontos)
    // Para TEF e reconhecimento facial, precisamos de pelo menos 2 Mbps
    maxScore += 40;
    if (downloadRate >= 10) {
      score += 40; // Excelente
    } else if (downloadRate >= 5) {
      score += 30; // Bom
    } else if (downloadRate >= 2) {
      score += 20; // Mínimo aceitável
    } else if (downloadRate >= 1) {
      score += 10; // Insuficiente
    }
    // downloadRate < 1 = 0 pontos

    // Avalia Upload (0-30 pontos)
    // Para upload de fotos AWS, precisamos de pelo menos 1 Mbps
    maxScore += 30;
    if (uploadRate >= 5) {
      score += 30; // Excelente
    } else if (uploadRate >= 2) {
      score += 20; // Bom
    } else if (uploadRate >= 1) {
      score += 15; // Mínimo aceitável
    } else if (uploadRate >= 0.5) {
      score += 8; // Insuficiente
    }
    // uploadRate < 0.5 = 0 pontos

    // Avalia Latência (0-30 pontos)
    // Para TEF, latência baixa é crítica
    maxScore += 30;
    if (latency != null) {
      if (latency < 50) {
        score += 30; // Excelente
      } else if (latency < 100) {
        score += 25; // Muito bom
      } else if (latency < 200) {
        score += 15; // Aceitável
      } else if (latency < 500) {
        score += 8; // Ruim
      }
      // latency >= 500 = 0 pontos
    }

    // Calcula porcentagem
    final percentage = maxScore > 0 ? (score / maxScore) * 100 : 0;

    // Define qualidade baseada na porcentagem
    if (percentage >= 80) {
      return {
        'text': 'Excelente',
        'color': Colors.green.shade700,
        'icon': Icons.check_circle,
      };
    } else if (percentage >= 60) {
      return {
        'text': 'Boa',
        'color': Colors.lightGreen,
        'icon': Icons.check_circle_outline,
      };
    } else if (percentage >= 40) {
      return {
        'text': 'Regular',
        'color': Colors.orange,
        'icon': Icons.warning_amber_rounded,
      };
    } else if (percentage >= 20) {
      return {
        'text': 'Ruim',
        'color': Colors.deepOrange,
        'icon': Icons.error_outline,
      };
    } else {
      return {
        'text': 'Insuficiente',
        'color': Colors.red,
        'icon': Icons.cancel,
      };
    }
  }

  Widget _buildTestButton(BuildContext context, SpeedTestStore store) {
    return Observer(
      builder: (_) => SizedBox(
        width: double.infinity,
        height: 55,
        child: ElevatedButton(
          onPressed: (store.isTesting || !store.hasConnection)
              ? null
              : () => _runTest(context, store),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            disabledBackgroundColor: Colors.grey[400],
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text(
            !store.hasConnection
                ? "SEM CONEXÃO"
                : store.hasTestResults
                    ? "INICIAR NOVO TESTE"
                    : "INICIAR TESTE",
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
      ),
    );
  }

  Future<void> _runTest(BuildContext context, SpeedTestStore store) async {
    try {
      await store.runTest();
    } catch (e) {
      DialogHelper.showError(
          context, 'Erro ao executar teste: ${e.toString()}');
    }
  }
}

class _AnimatedProgressBar extends StatefulWidget {
  final double progress;

  const _AnimatedProgressBar({
    required this.progress,
  });

  @override
  State<_AnimatedProgressBar> createState() => _AnimatedProgressBarState();
}

class _AnimatedProgressBarState extends State<_AnimatedProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _previousProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _animation = Tween<double>(
      begin: 0.0,
      end: widget.progress,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    _previousProgress = widget.progress;
    _controller.value = widget.progress;
  }

  @override
  void didUpdateWidget(_AnimatedProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _previousProgress = oldWidget.progress;
      _animation = Tween<double>(
        begin: _previousProgress,
        end: widget.progress,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ));
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return LinearProgressIndicator(
          value: _animation.value.clamp(0.0, 1.0),
          minHeight: 4,
          backgroundColor: Colors.white.withOpacity(0.3),
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
        );
      },
    );
  }
}
