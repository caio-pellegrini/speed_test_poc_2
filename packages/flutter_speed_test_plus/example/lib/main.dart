import 'package:flutter/material.dart';
import 'package:flutter_speed_test_plus/flutter_speed_test_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final internetSpeedTest = FlutterInternetSpeedTest()..enableLog();

  bool _testInProgress = false;
  double _downloadRate = 0;
  double _uploadRate = 0;
  String _downloadProgress = '0';
  String _uploadProgress = '0';
  int _downloadCompletionTime = 0;
  int _uploadCompletionTime = 0;
  bool _isServerSelectionInProgress = false;

  String? _ip;
  String? _asn;
  String? _isp;

  String _unitText = 'Mbps';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A237E), Color(0xFF283593), Color(0xFF3949AB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Internet Speed Test",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildInfoCard(
                        title: "IP Address",
                        value: _ip ?? '--',
                        icon: Icons.public,
                        color: Colors.blueAccent,
                      ),
                      _buildInfoCard(
                        title: "ASN",
                        value: _asn ?? '--',
                        icon: Icons.network_check,
                        color: Colors.orangeAccent,
                      ),
                      _buildInfoCard(
                        title: "ISP",
                        value: _isp ?? '--',
                        icon: Icons.wifi,
                        color: Colors.tealAccent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  if (_isServerSelectionInProgress)
                    const Text(
                      "Selecting Server...",
                      style: TextStyle(color: Colors.white70),
                    )
                  else
                    Column(
                      children: [
                        _buildProgressCard(
                          title: "Download Speed",
                          progress: _downloadProgress,
                          rate: _downloadRate,
                          unit: _unitText,
                          time: _downloadCompletionTime,
                          color: Colors.greenAccent,
                        ),
                        const SizedBox(height: 20),
                        _buildProgressCard(
                          title: "Upload Speed",
                          progress: _uploadProgress,
                          rate: _uploadRate,
                          unit: _unitText,
                          time: _uploadCompletionTime,
                          color: Colors.amberAccent,
                        ),
                      ],
                    ),
                  const SizedBox(height: 20),
                  if (!_testInProgress)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            vertical: 15, horizontal: 40),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                      ),
                      onPressed: () async {
                        reset();
                        await startTest();
                      },
                      child: const Text(
                        "Start Testing",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    )
                  else
                    Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 10),
                        TextButton.icon(
                          onPressed: () {
                            internetSpeedTest.cancelTest();
                            reset();
                          },
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          label: const Text(
                            "Cancel",
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressCard({
    required String title,
    required String progress,
    required double rate,
    required String unit,
    required int time,
    required Color color,
  }) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      shadowColor: Colors.black.withOpacity(0.3),
      elevation: 10,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 10),
            CircularProgressIndicator(
              value: double.parse(progress) / 100,
              color: color,
              backgroundColor: Colors.grey.withOpacity(0.3),
            ),
            const SizedBox(height: 10),
            Text(
              "$rate $unit",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (time > 0)
              Text(
                "Time: ${(time / 1000).toStringAsFixed(2)} sec(s)",
                style: const TextStyle(color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 6,
      shadowColor: Colors.black.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 5),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> startTest() async {
    await internetSpeedTest.startTesting(
      onStarted: () {
        setState(() => _testInProgress = true);
      },
      onCompleted: (download, upload) {
        setState(() {
          _downloadRate = download.transferRate;
          // _downloadProgress = '100';
          _downloadCompletionTime = download.durationInMillis;
          _uploadRate = upload.transferRate;
          // _uploadProgress = '100';
          _uploadCompletionTime = upload.durationInMillis;

          _testInProgress = false;
        });
      },
      onProgress: (percent, data) {
        setState(() {
          if (data.type == TestType.download) {
            _downloadRate = data.transferRate;
            _downloadProgress = percent.toStringAsFixed(2);
          } else {
            _uploadRate = data.transferRate;
            _uploadProgress = percent.toStringAsFixed(2);
          }
        });
      },
      onDefaultServerSelectionInProgress: () {
        setState(() => _isServerSelectionInProgress = true);
      },
      onDefaultServerSelectionDone: (client) {
        setState(() {
          _isServerSelectionInProgress = false;
          _ip = client?.ip;
          _asn = client?.asn;
          _isp = client?.isp;
        });
      },
      onError: (errorMessage, speedTestError) {
        reset();
      },
      onCancel: () {
        reset();
      },
    );
  }

  void reset() {
    setState(() {
      _testInProgress = false;
      _downloadRate = 0;
      _uploadRate = 0;
      _downloadProgress = '0';
      _uploadProgress = '0';
      _unitText = 'Mbps';
      _downloadCompletionTime = 0;
      _uploadCompletionTime = 0;

      _ip = null;
      _asn = null;
      _isp = null;
    });
  }
}
