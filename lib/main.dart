import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:image/image.dart' as img;

enum DetectionStatus { detected, notDetected }

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ColorNotifier()),
        ChangeNotifierProvider(create: (context) => DetectionNotifier()),
      ],
      child: MaterialApp(
        title: 'Dot Detection Application',
        theme: ThemeData(useMaterial3: true),
        home: const CameraScreen(),
      ),
    );
  }
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? controller;
  late WebSocketChannel channel;
  DetectionStatus? statusLeft;
  DetectionStatus? statusRight;
  DetectionStatus? statusMiddle;
  Timer? timer;
  bool isCapturing = false;

  List<double> getCircles() {
    final resolution = controller!.value.previewSize;
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;


    final double x1, y1, x2, y2, x3, y3, x4, y4, x5, y5, r;

    List<double> screenRatios = getPoints();

    x1 = screenRatios[0] * width;
    y1 = screenRatios[1] * height;
    x2 = screenRatios[2] * width;
    y2 = screenRatios[3] * height;
    x3 = screenRatios[4] * width;
    y3 = screenRatios[5] * height;
    x4 = screenRatios[6] * width;
    y4 = screenRatios[7] * height;
    x5 = screenRatios[8] * width;
    y5 = screenRatios[9] * height;
    r = screenRatios[10] * width;

    return [x1, y1, x2, y2, x3, y3, x4, y4, x5, y5, r];


  }

  String get currentStatus {
    if (statusMiddle == null) {
      return "Initializing...";
    }
    String status = "Status: ";
    if (statusLeft == DetectionStatus.detected) {
      status += "Left detected";
    } else if (statusRight == DetectionStatus.detected) {
      status += "Right detected";
    } else if (statusMiddle == DetectionStatus.detected) {
      status += "Middle detected";
    } else {
      status += "No detection";
    }
    return status;

  }

  @override
  void initState() {
    super.initState();
    initializeCamera();
    initializeWebSocket();
  }

  Future<void> initializeCamera() async {
    final cameras = await availableCameras();
    final firstCamera = cameras[0]; // back 0th index & front 1st index

    controller = CameraController(
      firstCamera,
      ResolutionPreset.veryHigh,
      enableAudio: false,
    );

    controller?.setFlashMode(FlashMode.off);

    await controller!.initialize();
    setState(() {});

    timer = Timer.periodic(const Duration(milliseconds: 200), (timer) async {
      if (isCapturing) return;
      isCapturing = true;

      try {
        final image = await controller!.takePicture();

        final cropped_and_compressed_image = await cropAndCompressImage(image.path);
        final encodedImage = base64Encode(cropped_and_compressed_image);


        final data = jsonEncode({
          'image': encodedImage,
        });

        channel.sink.add(data);

      } catch (e) {
        debugPrint('Error capturing image: $e');
      } finally {
        isCapturing = false;
      }
    });
  }

  Future<Uint8List> cropAndCompressImage(String imagePath, {int quality = 85}) async {
    final imageBytes = await File(imagePath).readAsBytes();
    final image = img.decodeImage(imageBytes)!;

    final rectWidth = (image.width * 0.8).toInt();
    final rectHeight = (image.height * 0.5).toInt();
    final left = (image.width - rectWidth) ~/ 2;
    final top = (image.height - rectHeight) ~/ 2;

    final croppedImage = img.copyCrop(image, x: left, y: top, width : rectWidth, height :rectHeight);
    final compressedImage = img.encodeJpg(croppedImage, quality: quality);
    return Uint8List.fromList(compressedImage);
  }

  void initializeWebSocket() {
    channel = IOWebSocketChannel.connect('ws://172.20.10.11:8765');
    channel.stream.listen((dynamic data) {
      debugPrint(data);
      data = jsonDecode(data);
      if (!data['status']) {
        debugPrint('Server error occurred in recognizing face');
        return;
      }

      if (data["status"] == true) {


        final List detections = data['detections'];
        context.read<DetectionNotifier>().changeDetections(detections);
        checkCircles(detections, controller!.value.previewSize!);

        /*


        final stats = data['data'];
        statusLeft = stats[0] == 1 ? DetectionStatus.detected : DetectionStatus.notDetected;
        statusMiddle = stats[1] == 1 ? DetectionStatus.detected : DetectionStatus.notDetected;
        statusRight = stats[2] == 1 ? DetectionStatus.detected : DetectionStatus.notDetected;

        stats[0] == 1 ? context.read<ColorNotifier>().changeColorLeft(Colors.green) : context.read<ColorNotifier>().changeColorLeft(Colors.red);
        stats[1] == 1 ? context.read<ColorNotifier>().changeColorMiddle(Colors.green) : context.read<ColorNotifier>().changeColorMiddle(Colors.red);
        stats[2] == 1 ? context.read<ColorNotifier>().changeColorRight(Colors.green) : context.read<ColorNotifier>().changeColorRight(Colors.red);

         */


      } else {
        debugPrint('Server error occurred in recognizing dots');
      }
      setState(() {});
    }, onError: (dynamic error) {
      debugPrint('Error: $error');
    }, onDone: () {
      debugPrint('WebSocket connection closed');
    });
  }


  @override
  void dispose() {
    timer?.cancel();
    controller?.dispose();
    channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!(controller?.value.isInitialized ?? false)) {
      return const SizedBox();
    }

    final List<double> circles = getCircles();
    final colorLeft = context.watch<ColorNotifier>().colorLeft;
    final colorRight = context.watch<ColorNotifier>().colorRight;
    final colorMiddle = context.watch<ColorNotifier>().colorMiddle;
    final colorDownLeft = context.watch<ColorNotifier>().downLeft;
    final colorDownRight = context.watch<ColorNotifier>().downRight;

    final color = [colorLeft, colorRight, colorMiddle, colorDownLeft, colorDownRight];
    final screenSize = MediaQuery.of(context).size;

    final List detections = context.watch<DetectionNotifier>().detections;

    return Scaffold(
      extendBody: true,
      body: Center(
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            width: controller!.value.previewSize!.width,
            height: controller!.value.previewSize!.height,
            child: Stack(
              children: [
                Positioned.fill(child: CameraPreview(controller!)),
                Positioned.fill(
                  child: CustomPaint(
                    painter: CirclePainter(
                      circles,
                      color,
                      controller!.value.previewSize,
                      screenSize
                    ),
                  ),
                ),

                Positioned.fill(
                  child: CustomPaint(
                    painter: RectangleOverlayPainter(),
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: DetectionPainter(
                      detections,
                      controller!.value.previewSize,
                      screenSize
                    ),
                  ),
                ),
                Align(
                  alignment: const Alignment(0, .85),
                  child: ElevatedButton(
                    child: Text(
                      screenSize.width.toString() + "x" + screenSize.height.toString(),
                      style: const TextStyle(fontSize: 20),
                    ),
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void checkCircles(List detections, Size cameraSize){

    final Size screenSize = MediaQuery.of(context).size;
    List circles = getCircles();

    final List flags = [false, false , false, false, false];

    for (int i = 0; i < detections.length; i++){
      final detection = detections[i];
      final double x = (detection[0] * screenSize.width / cameraSize.height) + screenSize.width * 0.1;
      final double y = (detection[1] * screenSize.height / cameraSize.width) + screenSize.height * 0.25;

      if (x > circles[0] - 20 && x < circles[0] + 20 && y > circles[1] - 20 && y < circles[1] + 20){
        context.read<ColorNotifier>().changeColorLeft(Colors.green);
        flags[0] = true;
      } else if (x > circles[2] - 20 && x < circles[2] + 20 && y > circles[3] - 20 && y < circles[3] + 20){
        context.read<ColorNotifier>().changeColorMiddle(Colors.green);
        flags[1] = true;
      } else if (x > circles[4] - 20 && x < circles[4] + 20 && y > circles[5] - 20 && y < circles[5] + 20){
        context.read<ColorNotifier>().changeColorRight(Colors.green);
        flags[2] = true;
      } else if (x > circles[6] - 20 && x < circles[6] + 20 && y > circles[7] - 20 && y < circles[7] + 20){
        context.read<ColorNotifier>().changeColorDownLeft(Colors.green);
        flags[3] = true;
      } else if (x > circles[8] - 20 && x < circles[8] + 20 && y > circles[9] - 20 && y < circles[9] + 20){
        context.read<ColorNotifier>().changeColorDownRight(Colors.green);
        flags[4] = true;
      }
    }

    if (!flags[0]){
      context.read<ColorNotifier>().changeColorLeft(Colors.red);
    }
    if (!flags[1]){
      context.read<ColorNotifier>().changeColorMiddle(Colors.red);
    }
    if (!flags[2]){
      context.read<ColorNotifier>().changeColorRight(Colors.red);
    }
    if (!flags[3]){
      context.read<ColorNotifier>().changeColorDownLeft(Colors.red);
    }
    if (!flags[4]){
      context.read<ColorNotifier>().changeColorDownRight(Colors.red);
    }

  }

  List<double> getPoints(){

    /*
    canvas.drawCircle(Offset(width / 6, 2* height / 5), 20, paintLeft);
    canvas.drawCircle(Offset(5* width / 6, 2* height / 5), 20, paintRight);
    canvas.drawCircle(Offset(width / 2, 2* height / 5), 20, paintMiddle);
     */

    double x1 = 1/6;
    double y1 = 4/10;
    double x2 = 1/2;
    double y2 = 4/10;
    double x3 = 5/6;
    double y3 = 4/10;
    double x4 = 1/6;
    double y4 = 6.7/10;
    double x5 = 5/6;
    double y5 = 6.7/10;
    double r = 0.0;

    return [x1, y1, x2, y2, x3, y3, x4, y4, x5, y5, r];

  }

}


class RectangleOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    final rectWidth = size.width * 0.8;
    final rectHeight = size.height * 0.5;
    final left = (size.width - rectWidth) / 2;
    final top = (size.height - rectHeight) / 2;

    final rect = Rect.fromLTWH(left, top, rectWidth, rectHeight);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(rect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}


class DetectionPainter extends CustomPainter{
  final Size? previewSize;
  final Size? screenSize;
  final List detections;
  final double widthOffset;
  final double heightOffset;

  DetectionPainter(this.detections, this.previewSize, this.screenSize, {this.widthOffset = 0, this.heightOffset = 0});

  @override
  void paint(Canvas canvas, Size size) {

    final paint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    const r = 5;

    for (int i =0; i<detections.length ; i++){
      final detection = detections[i];

      //detection[0] is width of camera preview and detection[1] is height of camera preview

      final double x = detection[0] * screenSize!.width / previewSize!.height;
      final double y = detection[1] * screenSize!.height / previewSize!.width;

      canvas.drawCircle(Offset(x + (screenSize!.width * 0.1) , y + (screenSize!.height * 0.25)), r.toDouble(), paint);
    }

  }

  @override
  bool shouldRepaint(DetectionPainter oldDelegate) {
    return oldDelegate.detections != detections;
  }
}

class CirclePainter extends CustomPainter {
  List<double> circles;
  List <Color> color;
  final Size? previewSize;
  final Size? screenSize;

  CirclePainter(this.circles,this.color, this.previewSize, this.screenSize);

  @override
  void paint(Canvas canvas, Size size) {
    if (previewSize == null) return;

    final paintLeft = Paint()
      ..color = color[0]
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final paintMiddle = Paint()
      ..color = color[1]
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final paintRight = Paint()
      ..color = color[2]
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final paintDownLeft = Paint()
      ..color = color[3]
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final paintDownRight = Paint()
      ..color = color[4]
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;



    // Draw circles
    //canvas.drawCircle(Offset(screenSize!.width / 4, previewSize!.height  / 2), r1.toDouble() * scaleX, paint);
    //canvas.drawCircle(Offset(3 * screenSize!.width / 4, previewSize!.height  / 2), r2.toDouble() * scaleX, paint);

    canvas.drawCircle(Offset(circles[0], circles[1]), 20, paintLeft);
    canvas.drawCircle(Offset(circles[2], circles[3]), 20, paintMiddle);
    canvas.drawCircle(Offset(circles[4], circles[5]), 20, paintRight);
    //canvas.drawCircle(Offset(circles[6], circles[7]), 20, paintDownLeft);
    //canvas.drawCircle(Offset(circles[8], circles[9]), 20, paintDownRight);

  }

  @override
  bool shouldRepaint(CirclePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class ColorNotifier extends ChangeNotifier {
  Color _colorLeft = Colors.red;
  Color get colorLeft => _colorLeft;

  Color _colorRight = Colors.red;
  Color get colorRight => _colorRight;

  Color _colorMiddle = Colors.red;
  Color get colorMiddle => _colorMiddle;

  Color _downLeft = Colors.red;
  Color get downLeft => _downLeft;

  Color _downRight = Colors.red;
  Color get downRight => _downRight;


  void changeColorLeft(Color newColor) {
    _colorLeft = newColor;
    notifyListeners();
  }

  void changeColorRight(Color newColor) {
    _colorRight = newColor;
    notifyListeners();
  }

  void changeColorMiddle(Color newColor) {
    _colorMiddle = newColor;
    notifyListeners();
  }

  void changeColorDownLeft(Color newColor) {
    _downLeft = newColor;
    notifyListeners();
  }

  void changeColorDownRight(Color newColor) {
    _downRight = newColor;
    notifyListeners();
  }
}

class DetectionNotifier extends ChangeNotifier{
  List _detections = [];
  List get detections => _detections;

  void changeDetections(List newDetections){
    _detections = newDetections;
    notifyListeners();
  }

}
