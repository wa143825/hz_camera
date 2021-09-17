package com.plugin.hz_camera

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.net.wifi.WifiInfo
import android.net.wifi.WifiManager
import android.os.Build
import android.util.Log
import androidx.core.app.ActivityCompat.requestPermissions
import androidx.core.content.ContextCompat
import com.hozo.camera.library.cameramanager.*
import com.hozo.camera.library.previewer.HZCameraPreviewer
import com.hznovi.camera.photoprocessor.HZPhotoProcessor

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import java.io.File


import java.util.ArrayList

class HzCameraPlugin: FlutterPlugin, MethodCallHandler, ActivityAware{
  private val _tag: String = HzCameraPlugin::class.java.simpleName
  private lateinit var channel : MethodChannel
  private lateinit var activity: Activity
  private lateinit var mPreviewer: HZCameraPreviewer
  private lateinit var context: Context
  private var wifiName = ""
  // 事件派发对象
  private var eventSink: EventChannel.EventSink? = null

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    context = binding.applicationContext
    channel = MethodChannel(binding.binaryMessenger, "hz_camera")
    channel.setMethodCallHandler(this)

    // 初始化事件
    val eventChannel = EventChannel(binding.binaryMessenger, "HzCamera_event")
    eventChannel.setStreamHandler(
      object : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
          eventSink = events
        }
        override fun onCancel(arguments: Any?) {
          eventSink = null
        }
      }
    )

    HZCameraConnector.sharedConnector().setCallback(object : HZCameraConnector.ICallback {
      override fun onCameraConnected() {
        activity.runOnUiThread{
          eventSink?.success(hashMapOf(
            "code" to 0,
            "data" to "连接成功"
          ))
        }
        switchToCamera()
      }

      override fun onCameraConnectFailed(errType: HZCameraConnector.ErrorType) {
        activity.runOnUiThread{
          eventSink?.success(hashMapOf(
            "code" to 0,
            "data" to "相机连接失败"
          ))
        }
      }

      override fun onCameraDisconnected(errType: HZCameraConnector.ErrorType) {
        Log.d(_tag, errType.name)
        activity.runOnUiThread{
          eventSink?.success(hashMapOf(
            "code" to 0,
            "data" to "相机断开连接"
          ))
        }
      }
    })

    // 初始化预览
    mPreviewer = HZCameraPreviewer(context) { _, _ , _, _ -> }
    mPreviewer.setCalibratedFrameCallback { frameData, width, height ->
      activity.runOnUiThread{
        eventSink?.success(hashMapOf(
          "code" to 1,
          "data" to hashMapOf(
            "frameData" to frameData,
            "width" to width,
            "height" to height,
          )
        ))
      }
    }

  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "setup" -> setup(result)
      "connectCamera" -> connectCamera()
      "getSystemInfo" -> getSystemInfo(result)
      "startPreview" -> mPreviewer.startPreview()
      "stopPreview" -> mPreviewer.stopPreview()
      "takePhoto" -> takePhoto()
      else -> result.notImplemented()
    }
  }

  // 1. SDK初始化
  private fun setup(result: Result) {
    println("setup")
    checkPermission()
    HZCameraEnv.setup(activity.application)
    result.success(true)
  }

  // 2. 连接相机
  private fun connectCamera() {
    val wifiManager = activity.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
    val wifiInfo: WifiInfo = wifiManager.connectionInfo
    wifiName = wifiInfo.ssid.replace("\"", "")
    HZCameraConnector.sharedConnector().connectCamera(wifiName)
  }

  // 3. 切换相机环境
  private fun switchToCamera() {
    Log.d("switchToCamera", wifiName)
    HZCameraEnv.sharedEnv().switchToCamera(wifiName, object: HZCameraEnv.ISwitchCameraDelegate {
      override  fun onSwitchToCameraSucceed(p0: String) {
        Log.d("switchToCamera", "切换相机成功")
      }
      override  fun onSwitchToCameraFailed(p0: String) {
        Log.d("switchToCamera", "切换相机失败")
      }
      // 需要初始化相机
      override  fun onNeedInitCamera(p0: String, p1: Boolean) {
        Log.d("switchToCamera", "需要初始化相机")
        startInit()
      }
    })
  }

  // 4. 初始化相机
  private fun startInit () {
    Log.i("startInit", "初始化相机")
    HZCameraEnv.sharedEnv().initCamera(object: HZCameraEnv.IInitProgressDelegate {
      override fun onInitStart() {
        activity.runOnUiThread {
          eventSink?.success(hashMapOf(
            "code" to 0,
            "data" to "此过程大约需要30秒，请不要关闭APP"
          ))
        }
      }

      override fun onInitProgress(progress: Int) {
        activity.runOnUiThread {
          eventSink?.success(hashMapOf(
            "code" to 0,
            "data" to "初始化中：$progress%"
          ))
        }
      }
      override fun onInitSucceed() {
        activity.runOnUiThread {
          eventSink?.success(hashMapOf(
            "code" to 0,
            "data" to "初始化成功"
          ))
          connectCamera()
        }
      }
      override fun onInitFailed(p0: Int) {
        activity.runOnUiThread {
          eventSink?.success(hashMapOf(
            "code" to 0,
            "data" to "初始化失败，请稍后重试。错误码：$p0"
          ))
        }

      }
    })
  }

  // 5. 拍摄照片
  private fun takePhoto() {
    if (!HZCameraConnector.sharedConnector().isConnected) return
    HZCameraManager.sharedManager().takePhoto(
      HZCameraStateModel.HZTakePhotoDelayInterval.kDelaySec5,
      object : HZCameraManager.HZITakePhotoProgressDelegate{
        private var mPhotoName: String? = ""

        override fun onFailed(event: HZCameraEvent?, errorCode: Int) {
          println(errorCode)
          if (errorCode == HZICameraStatus.kDeviceInCharging) {
            activity.runOnUiThread {
              eventSink?.success(hashMapOf(
                "code" to 2,
                "data" to "相机充电中，暂时无法拍照"
              ))
            }
          }
        }
        /**
         * 开始拍照回调
         */
        override fun onTakePhotoStart() {
          activity.runOnUiThread {
            eventSink?.success(hashMapOf(
              "code" to 2,
              "data" to "相机正在测光 ..."
            ))
          }
        }

        /**
         * 拍摄的照片已在相机中处理完成，可进行下一步操作
         *
         * photoResName: 照片资源名称，拍摄一次，会产生一组照片资源，每组资源包含4张照片
         * photoFileIndex: 照片按照顺序进行编号
         * isSaved: 照片存储状态，true 表示可用，可以下载使用；false 表示存储失败，为无效照片，无法使用，需要重新拍摄
         */
        override fun onCapture(photoResName: String, photoFileIndex: Int, isSaved: Boolean) {
          println(photoFileIndex)
          println(isSaved)
          mPhotoName = photoResName
          if(isSaved) {

          }
        }

        /**
         * 拍照完成
         */
        override fun onTakePhotoEnd() {
          val photoName = mPhotoName
          if (photoName != null) {
            requestPhotoResFile(PhotoInfo(photoName, 0))
          }
        }

        /**
         * 测光过程回调
         * position: 相机角度，相机会先逆时针旋转进行测光，然后再顺时针旋转进行拍摄，此回调函数会在相机旋转的每个角度回调
         */
        override fun onValidateLight(position: HZCameraSettings.HZSteeringEnginePosition?) {
          if (position == HZCameraSettings.HZSteeringEnginePosition.kPosition4) {
            activity.runOnUiThread {
              eventSink?.success(hashMapOf(
                "code" to 2,
                "data" to "相机正在拍摄 ..."
              ))
            }
          }
        }

      }
    )
  }

  //6. 下载照片
  private data class PhotoInfo(var name: String, var index: Int)
  private fun requestPhotoResFile(photo: PhotoInfo) {
    val fileDir: String? = getPublicImageCacheDir(context)

    HZCameraManager.sharedManager().requestPhotoRes(
      photo.name,
      fileDir,
      object : HZICommandWithTimeoutResultCallback {

        override fun onTimeout(event: HZCameraEvent?) {
          println(event.toString())
        }

        override fun onSucceed(event: HZCameraEvent) {
//          activity.runOnUiThread {
//            eventSink?.success(hashMapOf(
//              "code" to 2,
//              "data" to "照片 ${photo.index + 1}/4 拍摄完成"
//            ))
//          }
//          if(photo.index == 3) {
            getPublicImageCacheDir(context).let {
              val path = "${it}/${photo.name}/"
              genPanoramaPhoto(path)
            }
            activity.runOnUiThread {
              eventSink?.success(hashMapOf(
                "code" to 2,
                "data" to "照片拍摄完成"
              ))
            }
//          }
        }

        override fun onFailed(event: HZCameraEvent?, errorCode: Int) {
          println(event.toString())
        }
      }
    )
  }

  // 7. 拼接照片
  private fun genPanoramaPhoto(path: String) {
    HZPhotoProcessor.sharedProcessor().genPanoramaPhoto(
      path,
      object : HZPhotoProcessor.IProcessorStitchPhotoResult{
        override fun onStitchSucceed(photoPath: String?) {
          activity.runOnUiThread {
            eventSink?.success(hashMapOf(
              "code" to 2,
              "data" to "照片拼接完成",
            ))
            eventSink?.success(hashMapOf(
              "code" to 3,
              "data" to photoPath,
            ))
          }
        }

        override fun onStitchProgress(progress: Int) {
          activity.runOnUiThread {
            eventSink?.success(hashMapOf(
              "code" to 2,
              "data" to "相片正在拼接: $progress%"
            ))
          }
        }

        override fun onStitchFailed(p0: Int) {

        }
        
      }
    )
  }

  //8. 获取相机参数
  private fun getSystemInfo(result: Result) {
    HZCameraSettings.sharedSettings().getSystemInfo(
      object : HZCameraSettings.HZIReadSystemInfoCallback{
        override fun onSystemInfoReceived(systemInfo: HZSystemInfoModel) {
          activity.runOnUiThread {
            result.success(hashMapOf(
              "mBatteryPercent" to systemInfo.mBatteryPercent,
              "mChargingState" to systemInfo.mChargingState.name,
              "freeMemorySpaceWithUnitG" to systemInfo.freeMemorySpaceWithUnitG.toString(),
            ))
          }
        }

        override fun onSucceed(p0: HZCameraEvent?) {
        }

        override fun onFailed(p0: HZCameraEvent?, p1: Int) {
        }
      }
    )
  }


  // 检查wifi权限
  private fun checkPermission() {
    val permissionArr = ArrayList<String>()
    if (Build.VERSION.SDK_INT > Build.VERSION_CODES.M) {
      // 获取热点SS_ID时需要此权限
      val accessFineLocation = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION)
      if ( accessFineLocation != PackageManager.PERMISSION_GRANTED) {
        permissionArr.add(Manifest.permission.ACCESS_FINE_LOCATION)
      }
    }
    // 存储图片时需要此权限
    val writeExternalStorage = ContextCompat.checkSelfPermission(context, Manifest.permission.WRITE_EXTERNAL_STORAGE)
    if (writeExternalStorage != PackageManager.PERMISSION_GRANTED) {
      permissionArr.add(Manifest.permission.WRITE_EXTERNAL_STORAGE)
    }
    if (permissionArr.size > 0) run {
      requestPermissions(activity, permissionArr.toTypedArray(), 100)
    }
  }


  private fun getPublicImageCacheDir(context: Context): String? {
    val pictureFile: String? = context.getExternalFilesDir(null)?.absolutePath
    val fileName = "cache"
    return if (pictureFile != null) {
      File(pictureFile, fileName).path
    } else null
  }


  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }



  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
  }

  override fun onDetachedFromActivityForConfigChanges() {
  }

  override fun onDetachedFromActivity() {
  }

}
