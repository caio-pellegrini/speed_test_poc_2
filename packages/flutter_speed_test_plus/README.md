# Flutter Internet Speed Test Plus
A Flutter plugin designed to measure internet download and upload speeds using widely recognized services, such as Fast.com (as the default) and Ookla's Speedtest.

# Features
1. Test download and upload speeds.
2. Default support for Fast.com API.
3. Option to use custom test server URLs.
4. Progress tracking and multiple callbacks.
5. Works on iOS and Android.
# Screenshot
![speedTest](https://github.com/user-attachments/assets/c4c3bb15-7a34-4f67-9067-538328ae8df9)

# Getting Started
Add the plugin to your pubspec.yaml file:

dependencies:

 `` flutter_internet_speed_test_plus: ^latest_version``
 
# Basic Usage
```
import 'package:flutter_internet_speed_test_plus/flutter_internet_speed_test_plus.dart';

void startSpeedTest() {
  final speedTest = FlutterInternetSpeedTest();
  speedTest.startTesting(
    useFastApi: true, // true by default, uses Fast.com API
    onStarted: () {
      print('Speed test started');
    },
    onCompleted: (TestResult download, TestResult upload) {
      print('Download Speed: ${download.speed} Mbps');
      print('Upload Speed: ${upload.speed} Mbps');
    },
    onProgress: (double percent, TestResult data) {
      print('Progress: $percent%');
    },
    onError: (String errorMessage, String speedTestError) {
      print('Error: $errorMessage');
    },
    onDownloadComplete: (TestResult data) {
      print('Download complete: ${data.speed} Mbps');
    },
    onUploadComplete: (TestResult data) {
      print('Upload complete: ${data.speed} Mbps');
    },
    onCancel: () {
      print('Test cancelled');
    },
  );
}
```
# Advanced Usage
You can customize the test by providing your own server URLs and file size:

```
import 'package:flutter_internet_speed_test_plus/flutter_internet_speed_test_plus.dart';

void startCustomSpeedTest() {
  final speedTest = FlutterInternetSpeedTest();
  speedTest.startTesting(
    useFastApi: false, // Use custom server instead of Fast.com
    downloadTestServer: 'https://your-download-server.com/testfile', // Custom download server URL
    uploadTestServer: 'https://your-upload-server.com/upload', // Custom upload server URL
    fileSize: 20, // File size in MB for testing (default is 10MB)
    onStarted: () {
      print('Speed test started');
    },
    onCompleted: (TestResult download, TestResult upload) {
      print('Download Speed: ${download.speed} Mbps');
      print('Upload Speed: ${upload.speed} Mbps');
    },
    onProgress: (double percent, TestResult data) {
      print('Progress: $percent%');
    },
    onError: (String errorMessage, String speedTestError) {
      print('Error: $errorMessage');
    },
    onDownloadComplete: (TestResult data) {
      print('Download complete: ${data.speed} Mbps');
    },
    onUploadComplete: (TestResult data) {
      print('Upload complete: ${data.speed} Mbps');
    },
    onCancel: () {
      print('Test cancelled');
    },
  );
}
```
# Configuration Options
# Default Server URLs
If no custom server URLs are provided, the plugin will use the following default URLs:

-  Download Servers:
 https://fast.com/

- Upload Servers:
 https://fast.com/

# Custom Options
You can override the default settings with custom values:

- Server URLs: Specify your own downloadTestServer and uploadTestServer.
- File Size: Set the fileSize parameter (in MB) for the test. The default is 10 MB.
# Callback Descriptions
Here’s a list of all available callbacks for handling test progress and results:

 - onStarted: Called when the speed test starts.
 - onCompleted: Called with final download and upload speeds.
 - onProgress: Called with the test progress percentage and intermediate results.
 - onError: Called if an error occurs during the test.
 - onDefaultServerSelectionInProgress: Triggered during server selection (when useFastApi is true).
 - onDefaultServerSelectionDone: Triggered when server selection is complete (when useFastApi is true).
 - onDownloadComplete: Called when the download test is completed.
 - onUploadComplete: Called when the upload test is completed.
 - onCancel: Triggered if the test is cancelled.

# Supported Platforms
 - iOS
 - Android

# Full Example

```
import 'package:flutter_internet_speed_test_plus/flutter_internet_speed_test_plus.dart';

void runFullSpeedTest() {
  final speedTest = FlutterInternetSpeedTest();
  speedTest.startTesting(
    useFastApi: true, // Use Fast.com by default
    downloadTestServer: 'https://mycustomdownloadserver.com/testfile',
    uploadTestServer: 'https://mycustomuploadserver.com/upload',
    fileSize: 50, // File size in MB
    onStarted: () {
      print('Speed test started');
    },
    onCompleted: (TestResult download, TestResult upload) {
      print('Download Speed: ${download.speed} Mbps');
      print('Upload Speed: ${upload.speed} Mbps');
    },
    onProgress: (double percent, TestResult data) {
      print('Progress: $percent%');
    },
    onError: (String errorMessage, String speedTestError) {
      print('Error: $errorMessage');
    },
    onDownloadComplete: (TestResult data) {
      print('Download completed: ${data.speed} Mbps');
    },
    onUploadComplete: (TestResult data) {
      print('Upload completed: ${data.speed} Mbps');
    },
    onCancel: () {
      print('Speed test cancelled');
    },
  );
}
```



















