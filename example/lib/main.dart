import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:hz_camera/hz_camera.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // 实时预览数据流监听
  StreamController<PreviewData> previewStream = HzCamera.previewStreamController;
  // 设备连接状态监听
  StreamController<String> connectProcess = HzCamera.connectProcessController;
  // 拍照过程状态监听
  StreamController<String> takePhotoProcess = HzCamera.takePhotoProcessController;
  // 图片路径，为拍摄时为空
  String? photoPath;
  // 相机状态默认值
  String cameraInfo = '未获取相机信息';
  String takePhotoState = "还未开始拍照";
  String connectState = '请点击连接相机';

  @override
  void initState() {
    super.initState();
    HzCamera(); // 初始化
    initPlatformState();
    WidgetsBinding.instance?.addPostFrameCallback((timeStamp) {

      // 监听设备连接状态，连接成功后获取设备信息，并开始预览
      connectProcess.stream.listen((event) async {
        this.setState(() {
          connectState = event;
        });
        if(event == "连接成功") {
          CameraInfo info =  await HzCamera.getSystemInfo;
          this.setState(() {
            cameraInfo = "电量：${info.mBatteryPercent}%  容量:${info.freeMemorySpaceWithUnitG}";
          });
          // HzCamera.startPreview();
        }
      });
      // 拍照状态监听，实时显示拍照状态，拍照完成并拼接成功后，赋值图片路径
      takePhotoProcess.stream.listen((event) {
        if(event == '照片拼接完成') {
          Future.delayed(Duration(milliseconds: 300), () {
            this.setState(() {
              photoPath = HzCamera.photoPath;
            });
          });
        } else {
          this.setState(() {
            takePhotoState = event;
          });
        }
      });

    });
  }

  @override
  void dispose() {
    super.dispose();
    previewStream.close();
    connectProcess.close();
    takePhotoProcess.close();
  }

  Future<void> initPlatformState() async {
    var setup = await HzCamera.setup;
    print(setup);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('小红屋相机demo'),
        ),
        body: SingleChildScrollView(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(onPressed: () async {
                    await HzCamera.connectCamera;
                }, child: Text('连接相机')),
                Text(connectState),
                TextButton(onPressed: () async {
                  CameraInfo info =  await HzCamera.getSystemInfo;
                  this.setState(() {
                    cameraInfo = "电量：${info.mBatteryPercent}%  容量:${info.freeMemorySpaceWithUnitG}";
                  });
                }, child: Text('重新获取相机状态')),
                Text(cameraInfo),
                SizedBox(height: 20,),
                Container(
                  height: 338,
                  width: 250,
                  color: Colors.grey,
                  child:
                  StreamBuilder(
                    stream: previewStream.stream,
                    builder: (ctx, AsyncSnapshot<PreviewData> db) {
                      if(db.hasData) {
                        PreviewData? data = db.data;
                        int w = data?.width ?? 0;
                        int h = data?.height ?? 0;
                        Uint8List f = data?.frameData ?? Uint8List(0);
                        List<int> ff = [];
                        for(int i = 0; i<f.length/3; i++) {
                          ff.add(f[i*3+2]);
                          ff.add(f[i*3+1]);
                          ff.add(f[i*3]);
                        }

                        BMPHeader header = BMPHeader(w, h);
                        Uint8List bmp = header.appendBitmap(Uint8List.fromList(ff));
                        return Image.memory(
                          bmp,
                          excludeFromSemantics: true,
                          gaplessPlayback: true,
                        );
                      }
                      return Center(child: Text('没数据'));
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(onPressed: () {
                      HzCamera.startPreview();
                    }, child: Text('获取预览流')),
                    TextButton(onPressed: () {
                      HzCamera.stopPreview();
                    }, child: Text('停止预览')),
                  ],
                ),
                Container(
                  height: 150,
                  width: 300,
                  color: Colors.grey,
                  child: photoPath != null ? Image.file(File(photoPath!), height: 150, width: 300,) : Center(child: Text('点击下方拍照')),
                ),
                TextButton(onPressed: () async {
                  HzCamera.takePhoto();
                }, child: Text('拍摄图片')),
                Text(takePhotoState)
              ],
            ),
          ),
        ),
      ),
    );
  }
}
