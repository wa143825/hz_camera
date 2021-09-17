import Flutter
import UIKit
import CoreLocation
import CoreTelephony
import HZCameraSDK
import Foundation

public class SwiftHzCameraPlugin: NSObject, FlutterPlugin, HZCameraSocketDelegate{
    
	var cllocationManager: CLLocationManager!
  var eventSink:FlutterEventSink?
	var mPrevivew: HZDisplayView = HZDisplayView()
	public static let instance: SwiftHzCameraPlugin = SwiftHzCameraPlugin()
	
	// 数据流监听
	class SwiftStreamHandler: NSObject, FlutterStreamHandler {
		func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
			instance.eventSink = events
			return nil
		}

		func onCancel(withArguments arguments: Any?) -> FlutterError? {
			instance.eventSink = nil
			return nil
		}
	}
    
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "hz_camera", binaryMessenger: registrar.messenger())
    let eventChannel = FlutterEventChannel(name: "HzCamera_event", binaryMessenger: registrar.messenger())
		eventChannel.setStreamHandler(SwiftStreamHandler())

    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch (call.method) {
//	1、设备初始化
    case "setup":
			setup(result: result)
    case "connectCamera":
			connectCamera()
    case "getSystemInfo":
			getSystemInfo(result: result)
		case "takePhoto":
			takePhoto()
		case "startPreview":
			startPreview()
		case "stopPreview":
			NSLog("停止预览流")
			mPrevivew.stop()
		case "needUpdate":
			NSLog("是否需要更新固件")
			mPrevivew.stop()
    default:
        result("nothing")
    }
  }
	
	func setup (result: @escaping FlutterResult) {
		CTCellularData().cellularDataRestrictionDidUpdateNotifier = { (state) in
			if state == CTCellularDataRestrictedState.restrictedStateUnknown {
				DispatchQueue.main.async {
					self.requestWLANAuth()
				}
			}
			else if state == CTCellularDataRestrictedState.restricted {
					DispatchQueue.main.async {
							self.requestWLANAuth()
					}
			}
			result(true)
		}
		self.cllocationManager = CLLocationManager();
		if CLLocationManager.authorizationStatus() == CLAuthorizationStatus.notDetermined {
				self.cllocationManager.requestWhenInUseAuthorization()
		}
		
		else if CLLocationManager.authorizationStatus() == CLAuthorizationStatus.denied {
				
				DispatchQueue.main.async {
						let alert = UIAlertController.init(title: "提示", message: "没有定位权限，无法获取小红屋相机Wi-Fi名称，请在设置页面打开Demo的定位权限！", preferredStyle: UIAlertController.Style.alert)
						let alertAction = UIAlertAction.init(title: "确定", style: UIAlertAction.Style.default, handler: { (action) in
						})
						alert.addAction(alertAction)
				}
		}
		
	}
	
	func requestWLANAuth() -> Void {
		let alert = UIAlertController.init(title: "提示", message: "没有wlan访问权限", preferredStyle: UIAlertController.Style.alert)
		let alertAction = UIAlertAction.init(title: "确定", style: UIAlertAction.Style.default, handler: { (action) in
				let url = URL.init(string: "https://www.xiaohongwu.com/")
				let task = URLSession.shared.dataTask(with: url!)
				task.resume()
		})
		alert.addAction(alertAction)
	}
    
//	 2、连接相机
  func connectCamera() {
		NSLog("连接相机")
		do {
        try HZCameraConnector.default().connectToCameraError()
    } catch let error {
			print(error)
			self.eventSink!([
				"code": 0,
				"data": "连接失败",
			] as [String: Any])
    }
		setUpCamera()
  }

	// 3、相机连接状态改变的时候执行
	public func cameraConnectionStateChange(_ state: E_SOCKET_STATE) {
		print("camera connection change \(state.self)")
		if E_SOCKET_STATE_CONNECTED != state {
			NSLog("相机已断开")
		} else {
			NSLog("相机已连接")
			setUpCamera()
		}
	}
	

  // 4、相机初始化
	func setUpCamera() {
		HZCameraMedia.default().setupCamera(
			completion: {
				self.eventSink!([
					"code": 0,
					"data": "连接成功",
				] as [String: Any])
			},
			fail: {(err) in
				self.eventSink!([
					"code": 0,
					"data": "连接失败\(err.localizedDescription)",
				] as [String: Any])
			},
			progress: {(process) in
				self.eventSink!([
					"code": 0,
					"data": "初始化：\(process)%",
				] as [String: Any])
			}
		)
	}

	// 5、拍摄照片
	func takePhoto() {
		self.eventSink!([
			"code": 2,
			"data": "相机正在拍摄 ...",
		] as [String: Any])
		
		HZCameraMedia.default().onlyTakePhoto() { (picAddress) in
			NSLog("照片地址：", picAddress)
			self.genPanoramaPhoto(path: picAddress)
		} cameraStatus: { (status: E_TURN_STATUS) in
			var stat: String = ""
			switch status {
				case E_TURN_RESET_POSITION:
					stat = "相机正在复位..."
				case E_TURN_METERING_POSITION_ZERO:
					stat = "相机正在测光..."
				case E_TURN_CAPTURING_POSITION_ZERO:
					stat = "相机正在拍照..."
				case E_TURN_CAPTURING_POSITION_270:
					stat = "照片拍摄完成"
				default:
					stat = "相机正在准备..."
			}
			
			self.eventSink!([
				"code": 2,
				"data": stat,
			] as [String: Any])
		} fail: { (err) in
			self.eventSink!([
				"code": 2,
				"data": "拍摄失败，错误码 \(err)",
			] as [String: Any])
		}
	}

	//6拼接照片
	func genPanoramaPhoto(path: String) {
		let homedDirectory = NSHomeDirectory()+"/Documents/"
		
		HZCameraFileManager.default().setAlbumLocalAddress(homedDirectory)
		HZCameraFileManager.default().getPhotoWithName(path) { (img) in
			if FileManager.default.isWritableFile(atPath: homedDirectory) {
				do {
					try img.write(to: URL(fileURLWithPath: homedDirectory + path))
				} catch let err {
					NSLog("拼接错误")
					NSLog(err.localizedDescription)
				}
				
			}
			self.eventSink!([
				"code": 2,
				"data": "照片拼接完成",
			] as [String: Any])

			self.eventSink!([
				"code": 3,
				"data": homedDirectory + path,
			] as [String: Any])
		} fail: { (err) in
			print(err.localizedDescription)
		} progress: { (process) in
			self.eventSink!([
				"code": 2,
				"data": "相片正在拼接: \(process)%",
			] as [String: Any])
		}
	}

	// 获取相机参数
	func getSystemInfo(result: @escaping  FlutterResult) {
		HZCameraSettings.default().getCameraMemoryInfo {(info) in
			result([
				"mBatteryPercent": info.chargeInfo,
				"mChargingState": info.batteryStatus == E_BATTERY_CHARGING ? "充电中" : "未充电",
				"freeMemorySpaceWithUnitG": String(format: "%.2f", Float(info.memoryFreeStorage)/1000),
			] as [String: Any])
		} fail: { (err) in
			print(err)
		}
	}
    
	func startPreview() {
		mPrevivew.startGetRgbData({ (data: Data, w: Int32, h: Int32) in
			self.eventSink!([
				"code": 1,
				"data": [
					"frameData": FlutterStandardTypedData(bytes: data),
					"width": w,
					"height": h
				],
			] as [String: Any])
		}, fail: { (err) in
			NSLog(err.localizedDescription)
		})
	}
	
	// 是否需要更新固件
}


