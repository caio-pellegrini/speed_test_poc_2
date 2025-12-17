package com.softradix.flutter_speed_test_plus

import android.app.Activity
import android.content.Context
import fr.bmartel.speedtest.SpeedTestReport
import fr.bmartel.speedtest.SpeedTestSocket
import fr.bmartel.speedtest.inter.IRepeatListener
import fr.bmartel.speedtest.inter.ISpeedTestListener
import fr.bmartel.speedtest.model.SpeedTestError
import fr.bmartel.speedtest.model.SpeedTestMode
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicLong
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit as ConcurrentTimeUnit

/** FlutterInternetSpeedTestPlugin */
class FlutterInternetSpeedTestPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    private val defaultFileSizeInBytes: Int = 20 * 1024 * 1024 //10 MB
    private val defaultTestTimeoutInMillis: Int = TimeUnit.SECONDS.toMillis(20).toInt()
    private val defaultResponseDelayInMillis: Int = TimeUnit.MILLISECONDS.toMillis(500).toInt()

    private var result: Result? = null
    private var speedTestSocket: SpeedTestSocket = SpeedTestSocket()
    
    // Multi-threading support for parallel connections
    private val NUM_PARALLEL_CONNECTIONS = 4
    private val RAMP_UP_DISCARD_PERCENT = 0.25 // Discard first 25% of samples
    private val PROGRESS_UPDATE_INTERVAL_MS = 500L // Update interval for aggregated throughput
    
    // Active test state
    private val activeSockets = ConcurrentHashMap<Int, MutableList<SpeedTestSocket>>()
    private val activeSchedulers = ConcurrentHashMap<Int, ScheduledExecutorService>()
    private val activeTestListeners = ConcurrentHashMap<Int, TestListener>()
    private val aggregatedThroughput = ConcurrentHashMap<Int, MutableList<Pair<Long, Double>>>() // timestamp -> aggregatedThroughputBps
    private val socketThroughput = ConcurrentHashMap<Int, ConcurrentHashMap<Int, Double>>() // testId -> socketIndex -> currentThroughputBps
    private val isTestActive = ConcurrentHashMap<Int, AtomicInteger>() // 0 = inactive, >0 = active

    private lateinit var methodChannel: MethodChannel
    private var activity: Activity? = null
    private var applicationContext: Context? = null

    private val logger = Logger()

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = flutterPluginBinding.applicationContext
        methodChannel =
            MethodChannel(flutterPluginBinding.binaryMessenger, "com.softradix.flutter_speed_test_plus/method")
        methodChannel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        print("FlutterInternetSpeedTestPlugin: onMethodCall: ${call.method}")
        this.result = result
        when (call.method) {
            "startListening" -> mapToCall(result, call.arguments)
            "cancelListening" -> cancelListening(call.arguments, result)
            "toggleLog" -> toggleLog(call.arguments)
            "cancelTest" -> cancelTasks(call.arguments, result)
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        activity = null
        applicationContext = null
        methodChannel.setMethodCallHandler(null)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    private fun mapToCall(result: Result, arguments: Any?) {
        val argsMap = arguments as Map<*, *>

        val fileSize =
            if (argsMap.containsKey("fileSize")) argsMap["fileSize"] as Int else defaultFileSizeInBytes
        when (val args = argsMap["id"] as Int) {
            CallbacksEnum.START_DOWNLOAD_TESTING.ordinal -> startListening(args,
                result,
                "startDownloadTesting",
                argsMap["testServer"] as String,
                fileSize)
            CallbacksEnum.START_UPLOAD_TESTING.ordinal -> startListening(args,
                result,
                "startUploadTesting",
                argsMap["testServer"] as String,
                fileSize)
        }
    }

    private fun toggleLog(arguments: Any?) {
        val argsMap = arguments as Map<*, *>

        if (argsMap.containsKey("value")) {
            val logValue = argsMap["value"] as Boolean
            logger.enabled = logValue
        }
    }

    private val callbackById: MutableMap<Int, Runnable> = mutableMapOf()

    private fun startListening(
        args: Any,
        result: Result,
        methodName: String,
        testServer: String,
        fileSize: Int,
    ) {
        // Get callback id
        logger.print("test starting")
        val currentListenerId = args as Int
        val runnable = Runnable {
            if (callbackById.containsKey(currentListenerId)) {
                val argsMap: MutableMap<String, Any> = mutableMapOf()
                argsMap["id"] = currentListenerId
                logger.print("test listener Id: $currentListenerId")
                when (methodName) {
                    "startDownloadTesting" -> {
                        testDownloadSpeed(object : TestListener {
                            override fun onComplete(transferRate: Double) {
                                argsMap["transferRate"] = transferRate
                                argsMap["type"] = ListenerEnum.COMPLETE.ordinal
                                activity!!.runOnUiThread {
                                    methodChannel.invokeMethod("callListener", argsMap)
                                }
                            }

                            override fun onError(speedTestError: String, errorMessage: String) {
                                argsMap["speedTestError"] = speedTestError
                                argsMap["errorMessage"] = errorMessage
                                argsMap["type"] = ListenerEnum.ERROR.ordinal
                                activity!!.runOnUiThread {
                                    methodChannel.invokeMethod("callListener", argsMap)
                                }
                            }

                            override fun onProgress(percent: Double, transferRate: Double) {
                                logger.print("onProgress $percent, $transferRate")
                                argsMap["percent"] = percent
                                argsMap["transferRate"] = transferRate
                                argsMap["type"] = ListenerEnum.PROGRESS.ordinal
                                activity!!.runOnUiThread {
                                    methodChannel.invokeMethod("callListener", argsMap)
                                }
                            }
                        }, testServer, fileSize)
                    }
                    "startUploadTesting" -> {
                        testUploadSpeed(object : TestListener {
                            override fun onComplete(transferRate: Double) {
                                argsMap["transferRate"] = transferRate
                                argsMap["type"] = ListenerEnum.COMPLETE.ordinal
                                activity!!.runOnUiThread {
                                    methodChannel.invokeMethod("callListener", argsMap)
                                }
                            }

                            override fun onError(speedTestError: String, errorMessage: String) {
                                argsMap["speedTestError"] = speedTestError
                                argsMap["errorMessage"] = errorMessage
                                argsMap["type"] = ListenerEnum.ERROR.ordinal
                                activity!!.runOnUiThread {
                                    methodChannel.invokeMethod("callListener", argsMap)
                                }
                            }

                            override fun onProgress(percent: Double, transferRate: Double) {
                                argsMap["percent"] = percent
                                argsMap["transferRate"] = transferRate
                                argsMap["type"] = ListenerEnum.PROGRESS.ordinal
                                activity!!.runOnUiThread {
                                    methodChannel.invokeMethod("callListener", argsMap)
                                }
                            }
                        }, testServer, fileSize)
                    }
                }
                // Send some value to callback

            }
        }
        val thread = Thread(runnable)
        callbackById[currentListenerId] = runnable
        thread.start()
        // Return immediately
        result.success(null)
    }

    private fun testUploadSpeed(testListener: TestListener, testServer: String, fileSize: Int) {
        // add a listener to wait for speedtest completion and progress
        logger.print("Testing Testing")
        speedTestSocket.addSpeedTestListener(object : ISpeedTestListener {
            override fun onCompletion(report: SpeedTestReport) {
//                // called when download/upload is complete
//                logger.print("[COMPLETED] rate in octet/s : " + report.transferRateOctet)
//                logger.print("[COMPLETED] rate in bit/s   : " + report.transferRateBit)
//                testListener.onComplete(report.transferRateBit.toDouble())
            }

            override fun onError(speedTestError: SpeedTestError, errorMessage: String) {
                // called when a download/upload error occur
                logger.print("OnError: ${speedTestError.name}, $errorMessage")
                testListener.onError(errorMessage, speedTestError.name)
            }

            override fun onProgress(percent: Float, report: SpeedTestReport) {
//                // called to notify download/upload progress
//                logger.print("[PROGRESS] progress : $percent%")
//                logger.print("[PROGRESS] rate in octet/s : " + report.transferRateOctet)
//                logger.print("[PROGRESS] rate in bit/s   : " + report.transferRateBit)
//                testListener.onProgress(percent.toDouble(), report.transferRateBit.toDouble())
            }
        })
//        speedTestSocket.startFixedUpload(testServer, 10000000, 20000, 100)
        speedTestSocket.startUploadRepeat(testServer,
            defaultTestTimeoutInMillis,
            defaultResponseDelayInMillis,
            fileSize,
            object : IRepeatListener {
                override fun onCompletion(report: SpeedTestReport) {
                    // called when download/upload is complete
                    logger.print("[COMPLETED] rate in octet/s : " + report.transferRateOctet)
                    logger.print("[COMPLETED] rate in bit/s   : " + report.transferRateBit)
                    testListener.onComplete(report.transferRateBit.toDouble())
                }

                override fun onReport(report: SpeedTestReport) {
                    // called to notify download/upload progress
                    logger.print("[PROGRESS] progress : ${report.progressPercent}%")
                    logger.print("[PROGRESS] rate in octet/s : " + report.transferRateOctet)
                    logger.print("[PROGRESS] rate in bit/s   : " + report.transferRateBit)
                    testListener.onProgress(report.progressPercent.toDouble(),
                        report.transferRateBit.toDouble())
                }
            })
        logger.print("After Testing")
    }

    private fun testDownloadSpeed(testListener: TestListener, testServer: String, fileSize: Int) {
        logger.print("Starting multi-threaded download test with $NUM_PARALLEL_CONNECTIONS connections")
        
        val testId = System.identityHashCode(testListener)
        activeTestListeners[testId] = testListener
        activeSockets[testId] = mutableListOf()
        aggregatedThroughput[testId] = mutableListOf()
        socketThroughput[testId] = ConcurrentHashMap()
        isTestActive[testId] = AtomicInteger(1)
        
        val startTime = System.currentTimeMillis()
        val sockets = mutableListOf<SpeedTestSocket>()
        val completedSockets = AtomicInteger(0)
        var hasError = AtomicInteger(0)
        val testCompleted = AtomicInteger(0) // Flag to prevent multiple completions
        
        // Create multiple sockets for parallel connections
        for (i in 0 until NUM_PARALLEL_CONNECTIONS) {
            val socket = SpeedTestSocket()
            sockets.add(socket)
            activeSockets[testId]!!.add(socket)
            
            socket.addSpeedTestListener(object : ISpeedTestListener {
                override fun onCompletion(report: SpeedTestReport) {
                    // Not used - completion handled by IRepeatListener
                }

                override fun onError(speedTestError: SpeedTestError, errorMessage: String) {
                    logger.print("[Socket $i ERROR] ${speedTestError.name}: $errorMessage")
                    if (hasError.compareAndSet(0, 1)) {
                        cleanupTest(testId)
                        testListener.onError(errorMessage, speedTestError.name)
                    }
                }

                override fun onProgress(percent: Float, report: SpeedTestReport) {
                    // Store current throughput for this socket (in bits per second)
                    socketThroughput[testId]!![i] = report.transferRateBit.toDouble()
                    
                    // Log detailed progress for each socket
                    logger.print("[Socket $i ISpeedTestListener PROGRESS] progress: $percent%")
                    logger.print("[Socket $i ISpeedTestListener PROGRESS] rate in octet/s: ${report.transferRateOctet}")
                    logger.print("[Socket $i ISpeedTestListener PROGRESS] rate in bit/s: ${report.transferRateBit}")
                }
            })
            
            // Start download on this socket
            socket.startDownloadRepeat(testServer,
                defaultTestTimeoutInMillis,
                defaultResponseDelayInMillis,
                object : IRepeatListener {
                    override fun onCompletion(report: SpeedTestReport) {
                        logger.print("[Socket $i REPEAT COMPLETED] rate in bit/s: ${report.transferRateBit}")
                        // Update final throughput for this socket
                        socketThroughput[testId]!![i] = report.transferRateBit.toDouble()
                        
                        val completed = completedSockets.incrementAndGet()
                        logger.print("[Socket $i] Completed count: $completed/$NUM_PARALLEL_CONNECTIONS")
                        
                        // Don't finalize immediately - wait for timeout or all sockets to complete naturally
                        // The scheduler will handle finalization after timeout
                    }

                    override fun onReport(report: SpeedTestReport) {
                        // Update socket throughput (in bits per second)
                        socketThroughput[testId]!![i] = report.transferRateBit.toDouble()
                        
                        // Log detailed progress for each socket (similar to upload)
                        logger.print("[Socket $i PROGRESS] progress: ${report.progressPercent}%")
                        logger.print("[Socket $i PROGRESS] rate in octet/s: ${report.transferRateOctet}")
                        logger.print("[Socket $i PROGRESS] rate in bit/s: ${report.transferRateBit}")
                    }
                })
        }
        
        // Start periodic aggregation of throughput from all sockets
        val scheduler = Executors.newScheduledThreadPool(1)
        activeSchedulers[testId] = scheduler
        
        // Schedule finalization after timeout
        scheduler.schedule({
            if (isTestActive[testId]?.get() != 0 && testCompleted.compareAndSet(0, 1)) {
                logger.print("[TIMEOUT REACHED] Finalizing test after ${defaultTestTimeoutInMillis}ms")
                // Stop all sockets before calculating result
                activeSockets[testId]?.forEach { socket ->
                    try {
                        if (socket.speedTestMode != SpeedTestMode.NONE) {
                            socket.forceStopTask()
                        }
                    } catch (e: Exception) {
                        logger.print("Error stopping socket on timeout: ${e.message}")
                    }
                }
                // Wait a bit for sockets to stop
                Thread.sleep(100)
                calculateFinalResult(testId, startTime, testListener)
            }
        }, defaultTestTimeoutInMillis.toLong(), ConcurrentTimeUnit.MILLISECONDS)
        
        scheduler.scheduleAtFixedRate({
            if (isTestActive[testId]?.get() == 0) {
                return@scheduleAtFixedRate
            }
            
            val currentTime = System.currentTimeMillis()
            val elapsed = currentTime - startTime
            
            // Check if we've exceeded timeout
            if (elapsed >= defaultTestTimeoutInMillis && testCompleted.compareAndSet(0, 1)) {
                logger.print("[TIMEOUT IN SCHEDULER] Finalizing test")
                activeSockets[testId]?.forEach { socket ->
                    try {
                        if (socket.speedTestMode != SpeedTestMode.NONE) {
                            socket.forceStopTask()
                        }
                    } catch (e: Exception) {
                        logger.print("Error stopping socket: ${e.message}")
                    }
                }
                Thread.sleep(100)
                calculateFinalResult(testId, startTime, testListener)
                return@scheduleAtFixedRate
            }
            
            // Aggregate throughput from all active sockets (SUM, not average)
            val socketThroughputs = socketThroughput[testId] ?: ConcurrentHashMap()
            val aggregatedThroughputBps = socketThroughputs.values.sum()
            
            // Log aggregated throughput
            logger.print("[AGGREGATED PROGRESS] elapsed: ${elapsed}ms/${defaultTestTimeoutInMillis}ms, aggregated throughput: ${aggregatedThroughputBps / 1_000_000.0} Mbps")
            socketThroughputs.forEach { (socketIndex, throughput) ->
                logger.print("[AGGREGATED PROGRESS] Socket $socketIndex: ${throughput / 1_000_000.0} Mbps")
            }
            
            // Store sample for final calculation with ramp-up discard
            synchronized(aggregatedThroughput[testId]!!) {
                aggregatedThroughput[testId]!!.add(Pair(currentTime, aggregatedThroughputBps))
            }
            
            // Report progress (already in bits per second, aggregated from all sockets)
            val progressPercent = (elapsed.toDouble() / defaultTestTimeoutInMillis * 100).coerceAtMost(99.0)
            testListener.onProgress(progressPercent, aggregatedThroughputBps)
        }, PROGRESS_UPDATE_INTERVAL_MS, PROGRESS_UPDATE_INTERVAL_MS, ConcurrentTimeUnit.MILLISECONDS)
        
        logger.print("Multi-threaded download test started (timeout: ${defaultTestTimeoutInMillis}ms)")
    }
    
    private fun calculateFinalResult(testId: Int, startTime: Long, testListener: TestListener) {
        try {
            logger.print("[CALCULATING FINAL RESULT] Starting calculation...")
            
            // Mark test as inactive before cleanup to prevent scheduler from continuing
            isTestActive[testId]?.set(0)
            
            val samples = aggregatedThroughput[testId] ?: mutableListOf()
            if (samples.isEmpty()) {
                testListener.onError("No samples collected", "INSUFFICIENT_DATA")
                return
            }
            
            // Sort by timestamp
            val sortedSamples = samples.sortedBy { it.first }
            val totalDuration = sortedSamples.last().first - sortedSamples.first().first
            
            // Discard ramp-up period (first 25% of samples)
            val rampUpDiscardCount = (sortedSamples.size * RAMP_UP_DISCARD_PERCENT).toInt()
            val stableSamples = sortedSamples.subList(rampUpDiscardCount, sortedSamples.size)
            
            if (stableSamples.isEmpty()) {
                testListener.onError("No stable samples after ramp-up discard", "INSUFFICIENT_DATA")
                return
            }
            
            // Calculate average of stable samples (these are already aggregated throughput values in bps)
            val totalThroughput = stableSamples.sumOf { it.second }
            val averageThroughputBps = totalThroughput / stableSamples.size
            
            // Already in bits per second, no conversion needed
            val finalThroughputBits = averageThroughputBps
            
            logger.print("[FINAL RESULT] Average aggregated throughput: ${finalThroughputBits / 1_000_000.0} Mbps")
            logger.print("[FINAL RESULT] Samples used: ${stableSamples.size} out of ${sortedSamples.size}")
            logger.print("[FINAL RESULT] Total test duration: ${System.currentTimeMillis() - startTime}ms")
            
            // Cleanup after calculating result
            cleanupTest(testId)
            
            testListener.onComplete(finalThroughputBits.toDouble())
        } catch (e: Exception) {
            logger.print("Error calculating final result: ${e.message}")
            cleanupTest(testId)
            testListener.onError(e.message ?: "Unknown error", "CALCULATION_ERROR")
        }
    }
    
    private fun cleanupTest(testId: Int) {
        logger.print("[CLEANUP] Starting cleanup for testId: $testId")
        
        isTestActive[testId]?.set(0)
        
        // Stop all sockets
        activeSockets[testId]?.forEachIndexed { index, socket ->
            try {
                if (socket.speedTestMode != SpeedTestMode.NONE) {
                    logger.print("[CLEANUP] Stopping socket $index")
                    socket.forceStopTask()
                    socket.clearListeners()
                }
            } catch (e: Exception) {
                logger.print("Error stopping socket $index: ${e.message}")
            }
        }
        
        // Shutdown scheduler
        try {
            activeSchedulers[testId]?.shutdown()
            logger.print("[CLEANUP] Scheduler shut down")
        } catch (e: Exception) {
            logger.print("Error shutting down scheduler: ${e.message}")
        }
        
        // Cleanup
        activeSockets.remove(testId)
        activeSchedulers.remove(testId)
        activeTestListeners.remove(testId)
        aggregatedThroughput.remove(testId)
        socketThroughput.remove(testId)
        isTestActive.remove(testId)
        
        logger.print("[CLEANUP] Cleanup completed for testId: $testId")
    }

    private fun cancelListening(args: Any, result: Result) {
        // Get callback id
        val currentListenerId = args as Int
        // Remove callback
        callbackById.remove(currentListenerId)
        // Do additional stuff if required to cancel the listener
        result.success(null)
    }

    private fun cancelTasks(arguments: Any?, result: Result) {
        Thread(Runnable {
            arguments?.let { args ->
                val argsMap = args as Map<*, *>
                try {
                    var cancelled = false
                    
                    // Cancel old single socket if active
                    if (speedTestSocket.speedTestMode != SpeedTestMode.NONE) {
                        speedTestSocket.forceStopTask()
                        speedTestSocket.clearListeners()
                        speedTestSocket = SpeedTestSocket()
                        cancelled = true
                    }
                    
                    // Cancel all active multi-threaded tests
                    activeSockets.keys.forEach { testId ->
                        cleanupTest(testId)
                        cancelled = true
                    }
                    
                    if (cancelled) {
                        result.success(true)

                        if (argsMap.containsKey("id1")) {
                            val id1 = argsMap["id1"] as Int
                            val map: MutableMap<String, Any> = mutableMapOf()
                            map["id"] = id1
                            map["type"] = ListenerEnum.CANCEL.ordinal
                            activity!!.runOnUiThread {
                                methodChannel.invokeMethod("callListener", map)
                            }
                        }
                        if (argsMap.containsKey("id2")) {
                            val id2 = argsMap["id2"] as Int
                            val map: MutableMap<String, Any> = mutableMapOf()
                            map["id"] = id2
                            map["type"] = ListenerEnum.CANCEL.ordinal
                            activity!!.runOnUiThread {
                                methodChannel.invokeMethod("callListener", map)
                            }
                        }
                        return@Runnable
                    }
                } catch (e: Exception) {
                    e.localizedMessage?.let { logger.print(it) }
                }
                result.success(false)
            } ?: kotlin.run {
                result.success(false)
            }
        }).start()
    }
}

