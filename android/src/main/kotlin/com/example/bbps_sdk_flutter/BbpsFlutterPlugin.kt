package com.example.bbps_sdk_flutter

import androidx.fragment.app.FragmentActivity
import android.content.Intent
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import `in`.org.npci.bbps.BBPSAgentInterface
import `in`.org.npci.bbps.BBPSService
import org.json.JSONObject

/** BbpsFlutterPlugin */
class BbpsFlutterPlugin : FlutterPlugin, MethodCallHandler, ActivityAware, EventChannel.StreamHandler {
    private lateinit var methodChannel: MethodChannel
    private var eventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    
    private var binding: ActivityPluginBinding? = null
    private var bbpsService: BBPSService? = null
    private var clientId: String? = null
    private var currentResult: Result? = null

    companion object {
        const val TAG = "BBPSFlutter"
    }

    inner class BBPSAgent(private val context: FragmentActivity) : BBPSAgentInterface {
        
        fun do_payment(billDetails: JSONObject?) {
            Log.d(TAG, "do_payment: $billDetails")
            eventSink?.success(mapOf(
                "event" to "DO_PAYMENT",
                "payload" to billDetails?.toString()
            ))
        }

        fun set_txn_status(txnStatus: JSONObject?) {
            Log.d(TAG, "set_txn_status: $txnStatus")
            eventSink?.success(mapOf(
                "event" to "SET_TXN_STATUS",
                "payload" to txnStatus?.toString()
            ))
            val intent = Intent("CLOSE_PAYMENT_ACTIVITY")
            context.sendBroadcast(intent)
        }

        override fun initiate_result(payload: JSONObject?) {
            Log.d(TAG, "initiate_result: $payload")
            eventSink?.success(mapOf(
                "event" to "INITIATE_RESULT",
                "payload" to payload?.toString()
            ))
            currentResult?.success(payload?.toString())
            currentResult = null
        }

        override fun process_result(payload: JSONObject?) {
            Log.d(TAG, "process_result: $payload")
            try {
                val event = payload?.optString("event", "")
                val processPayload = payload?.optJSONObject("payload")
                
                eventSink?.success(mapOf(
                    "event" to event,
                    "payload" to processPayload?.toString()
                ))
                
                when (event) {
                    "DO_PAYMENT" -> do_payment(processPayload)
                    "SET_BBPS_TXN_STATUS" -> {
                        set_txn_status(processPayload)
                        val intent = Intent(context, context::class.java)
                        intent.flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                        context.startActivity(intent)
                    }
                    "USER_EXIT" -> Log.i(TAG, "User exited BBPS flow")
                    "PROCESS_RESULT" -> {
                        val intent = Intent(context, context::class.java)
                        intent.flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                        context.startActivity(intent)
                        currentResult?.success(payload.toString())
                        currentResult = null
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error in process_result", e)
                eventSink?.success(mapOf("event" to "ERROR", "error" to e.message))
            }
        }

        override fun refresh_auth(payload: JSONObject?) {
            Log.d(TAG, "refresh_auth: $payload")
            eventSink?.success(mapOf(
                "event" to "REFRESH_AUTH",
                "payload" to payload?.toString()
            ))
        }
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "bbps_sdk_flutter")
        methodChannel.setMethodCallHandler(this)
        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "bbps_sdk_flutter_events")
        eventChannel?.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "createService" -> createService(call.argument<String>("clientId"), result)
            "initiate" -> initiate(call.argument<Map<String, Any>>("params"), result)
            "process" -> process(call.argument<String>("action"), call.argument<Map<String, Any>>("params"), result)
            "terminate" -> terminate(result)
            "onBackPressed" -> result.success(bbpsService?.onBackPressed() ?: false)
            "getPlatformVersion" -> result.success("Android ${android.os.Build.VERSION.RELEASE}")
            else -> result.notImplemented()
        }
    }

    private fun createService(clientId: String?, result: Result) {
        
        val fragmentActivity = binding?.activity as? FragmentActivity
        if (fragmentActivity !is FragmentActivity) {
            Log.e(TAG, "MainActivity should extend FlutterFragmentActivity instead of FlutterActivity!")
            result.error("INIT_ERROR", "FragmentActivity is null, cannot proceed", "Make sure MainActivity extends FlutterFragmentActivity")
            return
        }
        
        if (clientId.isNullOrEmpty()) {
            result.error("INIT_ERROR", "clientId cannot be null or empty", null)
            return
        }
        
        try {
            this.clientId = clientId
            this.bbpsService = BBPSService(fragmentActivity, BBPSAgent(fragmentActivity), clientId)
            Log.i(TAG, "BBPS Service created successfully with clientId: $clientId")
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Error creating BBPS Service", e)
            result.error("INIT_ERROR", "Failed to create BBPS Service: ${e.message}", null)
        }
    }

    private fun initiate(params: Map<String, Any>?, result: Result) {
        val fragmentActivity = binding?.activity as? FragmentActivity
        if (fragmentActivity !is FragmentActivity) {
            Log.e(TAG, "MainActivity should extend FlutterFragmentActivity instead of FlutterActivity!")
            result.error("INIT_ERROR", "FragmentActivity is null, cannot proceed", "Make sure MainActivity extends FlutterFragmentActivity")
            return
        }
        
        if (bbpsService == null) {
            result.error("NOT_INITIALIZED", "BBPS Service not initialized. Call createService first.", null)
            return
        }
        
        currentResult = result
        try {
            val payload = JSONObject()
            payload.put("action", "initiate")
            payload.put("clientId", clientId)
            payload.put("agentId", params?.get("agentId") ?: "")
            payload.put("mobile", params?.get("mobile") ?: "")
            payload.put("deviceId", params?.get("deviceId") ?: "")
            params?.forEach { (key, value) -> if (!payload.has(key)) payload.put(key, value) }
            bbpsService?.initiate(fragmentActivity, payload)
        } catch (e: Exception) {
            Log.e(TAG, "Error initiating BBPS", e)
            currentResult = null
            result.error("INITIATE_ERROR", e.message, null)
        }
    }

    private fun process(action: String?, params: Map<String, Any>?, result: Result) {
        if (bbpsService == null) {
            result.error("NOT_INITIALIZED", "BBPS Service not initialized. Call createService first.", null)
            return
        }
        
        val fragmentActivity = binding?.activity as? FragmentActivity
        if (fragmentActivity !is FragmentActivity) {
            result.error("NO_ACTIVITY", "FragmentActivity is null, cannot process", null)
            return
        }
        
        currentResult = result
        try {
            val payload = JSONObject()
            payload.put("action", action)
            params?.forEach { (key, value) -> payload.put(key, value) }
            bbpsService?.process(fragmentActivity, payload)
        } catch (e: Exception) {
            Log.e(TAG, "Error processing BBPS action", e)
            currentResult = null
            result.error("PROCESS_ERROR", e.message, null)
        }
    }

    private fun terminate(result: Result) {
        try {
            bbpsService?.terminate()
            bbpsService = null
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "Error terminating BBPS", e)
            result.error("TERMINATE_ERROR", e.message, null)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel?.setStreamHandler(null)
        bbpsService?.terminate()
        bbpsService = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        Log.i(TAG, "onAttachedToActivity called")
        this.binding = binding
    }

    override fun onDetachedFromActivityForConfigChanges() {
        Log.i(TAG, "onDetachedFromActivityForConfigChanges called")
        this.binding = null
    }
    
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        Log.i(TAG, "onReattachedToActivityForConfigChanges called")
        this.binding = binding
    }
    
    override fun onDetachedFromActivity() {
        Log.i(TAG, "onDetachedFromActivity called")
        this.binding = null
    }
    
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { 
        eventSink = events 
    }
    
    override fun onCancel(arguments: Any?) { 
        eventSink = null 
    }
}
