import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';


class HzCamera {
  static const MethodChannel _channel = const MethodChannel('hz_camera');
  static const EventChannel _eventChannel = const EventChannel('HzCamera_event');

  // 相机状态监听
  static StreamController<String> connectProcessController = StreamController.broadcast();
  // 实时预览流
  static StreamController<PreviewData> previewStreamController = StreamController.broadcast();
  // 拍摄过程
  static StreamController<String> takePhotoProcessController = StreamController.broadcast();
  // 照片路径
  static String? photoPath;

  HzCamera() {
    initEvent();
  }

  /// stream Code 的值
  /// 0：wifi状态
  /// 1：实时预览流数据
  /// 2：相机拍摄状态
  /// 3：相片合成结果返回

  initEvent() {
    _eventChannel
      .receiveBroadcastStream()
      .listen((event) async {
        var e = StreamData.fromJson(event);
        switch(e.code) {
          case 0: {
            connectProcessController.add(e.data);
          }
          break;
          case 1: {
            PreviewData data = PreviewData.fromJson(e.data);
            previewStreamController.add(data);
          }
          break;
          case 2: {
            takePhotoProcessController.add(e.data);
          }
          break;
          case 3: {
            photoPath = e.data;
          }
          break;
        }
    }, onError: (dynamic error) {
        print(error);
    },cancelOnError: true);
  }

  static Future<bool> get setup async {
    return await _channel.invokeMethod('setup');
  }

  static Future<dynamic> get connectCamera async {
    return await _channel.invokeMethod('connectCamera');
  }

  static Future<CameraInfo> get getSystemInfo async {
    var info = await _channel.invokeMethod('getSystemInfo');
    return CameraInfo.fromJson(info);
  }

  static void startPreview() async {
    return await _channel.invokeMethod('startPreview');
  }
  static void stopPreview() async {
    return await _channel.invokeMethod('stopPreview');
  }

  static void takePhoto() async {
    return await _channel.invokeMethod('takePhoto');
  }

}

class PreviewData {
  Uint8List? frameData;
  int? width;
  int? height;

  PreviewData(this.frameData,this.width,this.height);

  PreviewData.fromJson(json) :
    frameData = json["frameData"],
    width = json["width"],
    height = json["height"];
}

class StreamData {
  int code;
  dynamic data;

  StreamData(this.code, this.data);

  StreamData.fromJson(json) :
    code = json["code"],
    data = json["data"];
}

class CameraInfo {
  late int mBatteryPercent;
  late String mChargingState;
  late String freeMemorySpaceWithUnitG;

  CameraInfo(this.mBatteryPercent, this.mChargingState, this.freeMemorySpaceWithUnitG);

  CameraInfo.fromJson(json) {

      mBatteryPercent = json["mBatteryPercent"];
      mChargingState = json["mChargingState"];
      freeMemorySpaceWithUnitG = json["freeMemorySpaceWithUnitG"];

  }
}

enum ConnectErrorType {
  kNormal,
  kHotspotInvalid,
  kExceptionOccurs,
  kRemoteError,
  kNoKeepAlivePacketReceived,
  kUnknown
}

class BMPHeader {
  int _width;
  int _height;

  late Uint8List _bmp;
  late int _headerSize;

  BMPHeader(this._width, this._height) : assert(_width & 3 == 0) {
    _headerSize = 54;
    int fileLength = _headerSize + _width * _height * 3; // header + bitmap
    _bmp = new Uint8List(fileLength);
    ByteData bd = _bmp.buffer.asByteData();
    bd.setUint8(0, 0x42);
    bd.setUint8(1, 0x4d);
    bd.setUint32(2, fileLength, Endian.little); // file length
    bd.setUint32(10, _headerSize, Endian.little); // start of the bitmap
    bd.setUint32(14, 40, Endian.little); // info header size
    bd.setUint32(18, _width, Endian.little);
    bd.setUint32(22, -_height, Endian.little);
    bd.setUint32(26, 1, Endian.little); // 水平分辨率
    bd.setUint32(28, 24, Endian.little); // bpp
    bd.setUint32(34, _width * _height, Endian.little); // bitmap size
  }

  Uint8List appendBitmap(Uint8List bitmap) {
    int size = _width * _height * 3;
    assert(bitmap.length == size);
    _bmp.setRange(_headerSize, _headerSize + size, bitmap);
    return _bmp;
  }
}
