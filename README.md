# 泓众小红屋相机全景插件

小红屋8k全景相机插件安卓端。

## 安装
```yaml
dependencies:
  flutter:
    sdk: flutter
  hz_camera: ^x.x.x
```

## 导入
```dart
import 'package:hz_camera/hz_camera.dart';
```

## 使用


* 1、使用三个stream来监听状态
```dart
  // 实时预览数据流监听
  StreamController<PreviewData> previewStream = HzCamera.previewStreamController;
  // 设备连接状态监听
  StreamController<String> connectProcess = HzCamera.connectProcessController;
  // 拍照过程状态监听
  StreamController<String> takePhotoProcess = HzCamera.takePhotoProcessController;

  // 设备信息
  String cameraInfo = '未获取相机信息';
  // 连接状态
  String connectState = '请点击连接相机';
  // 拍照状态
  String takePhotoState = "还未开始拍照";
  // 图片路径，未拍摄时为空
  String? photoPath;
```

* 2、在相机页面需要初始化HzCamera()，同时监听设备连接状态和拍照状态;
** 第一次连接相机需要初始化，大约需要30s，通过监听可以查看初始化进度，和是否连接成功
** 拍照需要经历以下几个步骤 1、测光；2、复位；3、拍摄(1/4)张照片；4、下载(1/4)照片，重复第3步;5、全部拍摄完成后拼接；6、返回拼接完成后的图像地址
```dart
 // 
  @override
    void initState() {
      super.initState();
      HzCamera(); // 初始化
      WidgetsBinding.instance?.addPostFrameCallback((timeStamp) async {
        await HzCamera.setup;
       
        // 监听设备连接状态，连接成功后获取设备信息，并开始预览
        connectProcess.stream.listen((event) async {
          this.setState(() {
            connectState = event;
          });
          if(event == "连接成功") {
            CameraInfo info =  await HzCamera.getSystemInfo;
            this.setState(() {
              cameraInfo = "电量：${info.mBatteryPercent}%  容量:${info.mMemoryFreeSpacePercent}";
            });
            await HzCamera.startPreview;
          }
        });
        // 拍照状态监听，实时显示拍照状态，拍照完成并拼接成功后，赋值图片路径
        takePhotoProcess.stream.listen((event) {
          this.setState(() {
            takePhotoState = event;
          });
          if(event == '照片拼接完成') {
            Future.delayed(Duration(milliseconds: 300), () {
              this.setState(() {
                photoPath = HzCamera.photoPath;
              });
            });
          }
        });
      });
    }

```


* 2、实时预览
** 相机传输过来的是rgb数据
** 而`BMP`格式图片是bgr格式的数据
** 我们需要将rgb转换为bgr再解析成`Uint8List BMP`格式的图片来实现预览功能
```dart
Container(
    height: 169,
    width: 125,
    color: Colors.grey,
    child: StreamBuilder(
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
      }),
    ),
    Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton(onPressed: () async {
            await HzCamera.startPreview;
          }, child: Text('获取预览流')),
          TextButton(onPressed: () async {
            await HzCamera.stopPreview;
          }, child: Text('停止预览')),
        ],
    ),
```


> 有问题联系QQ:893350431