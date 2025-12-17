import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_speed_test_plus/src/models/server_selection_response.dart';
import 'package:flutter_speed_test_plus/src/speed_test_utils.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:tuple_dart/tuple.dart';

import 'callbacks_enum.dart';
import 'flutter_speed_test_plus_platform_interface.dart';

// Constants for ramp-up discard and sample tracking
const double RAMP_UP_DISCARD_PERCENT = 0.25; // Discard first 25% of samples

/// An implementation of [FlutterInternetSpeedTestPlatform] that uses method channels.
class MethodChannelFlutterInternetSpeedTest
    extends FlutterInternetSpeedTestPlatform {
  /// The method channel used to interact with the native platform.
  final _channel =
      const MethodChannel('com.softradix.flutter_speed_test_plus/method');
  final _logger = Logger();

  // Store temporal samples for ramp-up discard (timestamp -> throughput in bps)
  final Map<int, List<MapEntry<int, double>>> _temporalSamples = {};

  Future<void> _methodCallHandler(MethodCall call) async {
    if (isLogEnabled) {
      _logger.d('arguments are ${call.arguments}');
      _logger.d('callbacks are $callbacksById');
    }

    switch (call.method) {
      case 'callListener':
        if (call.arguments["id"] as int ==
            CallbacksEnum.startDownLoadTesting.index) {
          if (call.arguments['type'] == ListenerEnum.complete.index) {
            // Calculate final result using aggregated throughput with ramp-up discard
            final callbackId = call.arguments["id"] as int;
            final samples = _temporalSamples[callbackId] ?? [];

            if (samples.isEmpty) {
              // Fallback: use the final transfer rate directly (already aggregated from native)
              final transferRateBps = call.arguments['transferRate'] as double;
              final transferRateMbps = transferRateBps / 1000000.0;
              callbacksById[callbackId]!
                  .item3(transferRateMbps, SpeedUnit.mbps);
            } else {
              // Discard ramp-up period (first 25% of samples)
              final rampUpDiscardCount =
                  (samples.length * RAMP_UP_DISCARD_PERCENT).toInt();
              final stableSamples = samples.sublist(rampUpDiscardCount);

              if (stableSamples.isEmpty) {
                // Fallback if no stable samples
                final transferRateBps =
                    call.arguments['transferRate'] as double;
                final transferRateMbps = transferRateBps / 1000000.0;
                callbacksById[callbackId]!
                    .item3(transferRateMbps, SpeedUnit.mbps);
              } else {
                // Calculate average of stable samples (these are already aggregated throughput values)
                final totalThroughput = stableSamples.fold<double>(
                    0.0, (sum, entry) => sum + entry.value);
                final averageThroughputBps =
                    totalThroughput / stableSamples.length;
                final averageThroughputMbps = averageThroughputBps / 1000000.0;

                if (isLogEnabled) {
                  _logger.d(
                      'Final download: ${stableSamples.length} stable samples (discarded $rampUpDiscardCount ramp-up)');
                  _logger.d(
                      'Average aggregated throughput: ${averageThroughputMbps.toStringAsFixed(2)} Mbps');
                }

                callbacksById[callbackId]!
                    .item3(averageThroughputMbps, SpeedUnit.mbps);
              }
            }

            // Cleanup
            _temporalSamples.remove(callbackId);
            downloadSteps = 0;
            downloadRate = 0;
            callbacksById.remove(callbackId);
          } else if (call.arguments['type'] == ListenerEnum.error.index) {
            if (isLogEnabled) {
              _logger.d('onError : ${call.arguments["speedTestError"]}');
              _logger.d('onError : ${call.arguments["errorMessage"]}');
            }
            callbacksById[call.arguments["id"]]!.item1(
                call.arguments['errorMessage'],
                call.arguments['speedTestError']);
            // Cleanup on error
            final callbackId = call.arguments["id"] as int;
            _temporalSamples.remove(callbackId);
            downloadSteps = 0;
            downloadRate = 0;
            callbacksById.remove(callbackId);
          } else if (call.arguments['type'] == ListenerEnum.progress.index) {
            // The transferRate from native is already aggregated (sum of all parallel connections)
            // Store it as a temporal sample for final calculation with ramp-up discard
            final callbackId = call.arguments["id"] as int;
            final transferRateBps = call.arguments['transferRate'] as double;
            final timestamp = DateTime.now().millisecondsSinceEpoch;

            // Initialize list if needed
            _temporalSamples[callbackId] ??= [];

            // Store sample (timestamp -> aggregated throughput in bps)
            _temporalSamples[callbackId]!
                .add(MapEntry(timestamp, transferRateBps));

            // Convert to Mbps for progress callback (this is already aggregated from native)
            final transferRateMbps = transferRateBps / 1000000.0;

            if (isLogEnabled) {
              _logger.d(
                  'Progress: ${transferRateMbps.toStringAsFixed(2)} Mbps (aggregated from all connections)');
            }

            callbacksById[callbackId]!.item2(
                call.arguments['percent'].toDouble(),
                transferRateMbps,
                SpeedUnit.mbps);
          } else if (call.arguments['type'] == ListenerEnum.cancel.index) {
            if (isLogEnabled) {
              _logger.d('onCancel : ${call.arguments["id"]}');
            }
            final callbackId = call.arguments["id"] as int;
            callbacksById[callbackId]!.item4();
            _temporalSamples.remove(callbackId);
            downloadSteps = 0;
            downloadRate = 0;
            callbacksById.remove(callbackId);
          }
        } else if (call.arguments["id"] as int ==
            CallbacksEnum.startUploadTesting.index) {
          if (call.arguments['type'] == ListenerEnum.complete.index) {
            // For upload, we still use the aggregated value from native
            // (upload can also benefit from parallel connections in the future)
            final callbackId = call.arguments["id"] as int;
            final samples = _temporalSamples[callbackId] ?? [];

            if (samples.isEmpty) {
              // Fallback: use the final transfer rate directly
              final transferRateBps = call.arguments['transferRate'] as double;
              final transferRateMbps = transferRateBps / 1000000.0;
              callbacksById[callbackId]!
                  .item3(transferRateMbps, SpeedUnit.mbps);
            } else {
              // Discard ramp-up period
              final rampUpDiscardCount =
                  (samples.length * RAMP_UP_DISCARD_PERCENT).toInt();
              final stableSamples = samples.sublist(rampUpDiscardCount);

              if (stableSamples.isEmpty) {
                final transferRateBps =
                    call.arguments['transferRate'] as double;
                final transferRateMbps = transferRateBps / 1000000.0;
                callbacksById[callbackId]!
                    .item3(transferRateMbps, SpeedUnit.mbps);
              } else {
                final totalThroughput = stableSamples.fold<double>(
                    0.0, (sum, entry) => sum + entry.value);
                final averageThroughputBps =
                    totalThroughput / stableSamples.length;
                final averageThroughputMbps = averageThroughputBps / 1000000.0;

                if (isLogEnabled) {
                  _logger.d(
                      'Final upload: ${stableSamples.length} stable samples');
                  _logger.d(
                      'Average aggregated throughput: ${averageThroughputMbps.toStringAsFixed(2)} Mbps');
                }

                callbacksById[callbackId]!
                    .item3(averageThroughputMbps, SpeedUnit.mbps);
              }
            }

            // Cleanup
            _temporalSamples.remove(callbackId);
            uploadSteps = 0;
            uploadRate = 0;
            callbacksById.remove(callbackId);
          } else if (call.arguments['type'] == ListenerEnum.error.index) {
            if (isLogEnabled) {
              _logger.d('onError : ${call.arguments["speedTestError"]}');
              _logger.d('onError : ${call.arguments["errorMessage"]}');
            }
            final callbackId = call.arguments["id"] as int;
            callbacksById[callbackId]!.item1(call.arguments['errorMessage'],
                call.arguments['speedTestError']);
            // Cleanup on error
            _temporalSamples.remove(callbackId);
          } else if (call.arguments['type'] == ListenerEnum.progress.index) {
            // Store temporal sample for upload (same as download)
            final callbackId = call.arguments["id"] as int;
            final transferRateBps = call.arguments['transferRate'] as double;
            final timestamp = DateTime.now().millisecondsSinceEpoch;

            _temporalSamples[callbackId] ??= [];
            _temporalSamples[callbackId]!
                .add(MapEntry(timestamp, transferRateBps));

            final transferRateMbps = transferRateBps / 1000000.0;

            if (isLogEnabled) {
              _logger.d(
                  'Upload progress: ${transferRateMbps.toStringAsFixed(2)} Mbps');
            }

            callbacksById[callbackId]!.item2(
                call.arguments['percent'].toDouble(),
                transferRateMbps,
                SpeedUnit.mbps);
          } else if (call.arguments['type'] == ListenerEnum.cancel.index) {
            if (isLogEnabled) {
              _logger.d('onCancel : ${call.arguments["id"]}');
            }
            final callbackId = call.arguments["id"] as int;
            callbacksById[callbackId]!.item4();
            _temporalSamples.remove(callbackId);
            uploadSteps = 0;
            uploadRate = 0;
            callbacksById.remove(callbackId);
          }
        }
        break;

      case 'callCancelListener':
        // Clear download and upload progress without starting any tests again
        if (isLogEnabled) {
          _logger.d('Cancelling both download and upload testing...');
        }

        // Clear download state (without re-starting)
        _temporalSamples.remove(CallbacksEnum.startDownLoadTesting.index);
        downloadSteps = 0;
        downloadRate = 0;
        // If there's an ongoing download callback, call the cancel function
        if (callbacksById
            .containsKey(CallbacksEnum.startDownLoadTesting.index)) {
          callbacksById[CallbacksEnum.startDownLoadTesting.index]!.item4();
        }

        // Clear upload state (without re-starting)
        _temporalSamples.remove(CallbacksEnum.startUploadTesting.index);
        uploadSteps = 0;
        uploadRate = 0;
        // If there's an ongoing upload callback, call the cancel function
        if (callbacksById.containsKey(CallbacksEnum.startUploadTesting.index)) {
          callbacksById[CallbacksEnum.startUploadTesting.index]!.item4();
        }

        // Remove the callbacks from the list
        callbacksById.remove(CallbacksEnum.startDownLoadTesting.index);
        callbacksById.remove(CallbacksEnum.startUploadTesting.index);

        break;

      default:
        if (isLogEnabled) {
          _logger.d(
              'TestFairy: Ignoring invoke from native. This normally shouldn\'t happen.');
        }
    }

    // Call cancelListening after clearing states
    _channel.invokeMethod("cancelListening", call.arguments["id"]);
  }

  Future<CancelListening> _startListening(
      Tuple4<ErrorCallback, ProgressCallback, DoneCallback, CancelCallback>
          callback,
      CallbacksEnum callbacksEnum,
      String testServer,
      {Map<String, dynamic>? args,
      int fileSize = 100000000}) async {
    _channel.setMethodCallHandler(_methodCallHandler);
    int currentListenerId = callbacksEnum.index;
    if (isLogEnabled) {
      _logger.d('test $currentListenerId');
    }
    callbacksById[currentListenerId] = callback;
    await _channel.invokeMethod(
      "startListening",
      {
        'id': currentListenerId,
        'args': args,
        'testServer': testServer,
        'fileSize': fileSize,
      },
    );
    return () {
      _channel.invokeMethod("cancelListening", currentListenerId);
      callbacksById.remove(currentListenerId);
    };
  }

  Future<void> _toggleLog(bool value) async {
    await _channel.invokeMethod(
      "toggleLog",
      {
        'value': value,
      },
    );
  }

  @override
  Future<CancelListening> startDownloadTesting(
      {required DoneCallback onDone,
      required ProgressCallback onProgress,
      required ErrorCallback onError,
      required CancelCallback onCancel,
      required fileSize,
      required String testServer}) async {
    return await _startListening(Tuple4(onError, onProgress, onDone, onCancel),
        CallbacksEnum.startDownLoadTesting, testServer,
        fileSize: fileSize);
  }

  @override
  Future<CancelListening> startUploadTesting(
      {required DoneCallback onDone,
      required ProgressCallback onProgress,
      required ErrorCallback onError,
      required CancelCallback onCancel,
      required int fileSize,
      required String testServer}) async {
    return await _startListening(Tuple4(onError, onProgress, onDone, onCancel),
        CallbacksEnum.startUploadTesting, testServer,
        fileSize: fileSize);
  }

  @override
  Future<void> toggleLog({required bool value}) async {
    logEnabled = value;
    await _toggleLog(logEnabled);
  }

  @override
  Future<ServerSelectionResponse?> getDefaultServer() async {
    try {
      if (await isInternetAvailable()) {
        const tag = 'token:"';
        var tokenUrl = Uri.parse('https://fast.com/app-a32983.js');
        var tokenResponse = await http.get(tokenUrl);
        if (tokenResponse.body.contains(tag)) {
          int start = tokenResponse.body.lastIndexOf(tag) + tag.length;
          String token = tokenResponse.body.substring(start, start + 32);
          var serverUrl = Uri.parse(
              'https://api.fast.com/netflix/speedtest/v2?https=true&token=$token&urlCount=5');
          var serverResponse = await http.get(serverUrl);
          var serverSelectionResponse = ServerSelectionResponse.fromJson(
              json.decode(serverResponse.body));
          if (serverSelectionResponse.targets?.isNotEmpty == true) {
            return serverSelectionResponse;
          }
        }
      }
    } catch (e) {
      if (logEnabled) {
        _logger.d(e);
      }
    }
    return null;
  }

  @override
  Future<bool> cancelTest() async {
    var result = false;
    try {
      result = await _channel.invokeMethod("cancelTest", {
        'id1': CallbacksEnum.startDownLoadTesting.index,
        'id2': CallbacksEnum.startUploadTesting.index,
      });
    } on PlatformException {
      result = false;
    }
    return result;
  }
}
