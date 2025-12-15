class SpeedResult {
  final double downloadRate;
  final double uploadRate;
  final int? latency;
  final String? serverIp;

  SpeedResult({
    required this.downloadRate,
    required this.uploadRate,
    this.latency,
    this.serverIp,
  });

  SpeedResult copyWith({
    double? downloadRate,
    double? uploadRate,
    int? latency,
    String? serverIp,
  }) {
    return SpeedResult(
      downloadRate: downloadRate ?? this.downloadRate,
      uploadRate: uploadRate ?? this.uploadRate,
      latency: latency ?? this.latency,
      serverIp: serverIp ?? this.serverIp,
    );
  }
}

