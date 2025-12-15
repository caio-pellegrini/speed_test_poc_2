class ConnectionInfo {
  final String type;
  final int icon;
  final Map<String, dynamic>? wifiInfo;
  final Map<String, dynamic>? mobileInfo;
  final Map<String, dynamic>? ethernetInfo;

  ConnectionInfo({
    required this.type,
    required this.icon,
    this.wifiInfo,
    this.mobileInfo,
    this.ethernetInfo,
  });

  bool get hasConnection {
    return type != 'Sem Conexão' && type != 'Desconhecido';
  }

  Map<String, dynamic>? get connectionDetails {
    if (type == 'Wi-Fi') return wifiInfo;
    if (type == 'Dados Móveis') return mobileInfo;
    if (type == 'Cabo (Ethernet)') return ethernetInfo;
    return null;
  }
}

