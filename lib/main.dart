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

  List<int> getSizeOfFrame() {
    final resolution = controller!.value.previewSize;
    final width = resolution!.height.toInt();
    final height = resolution!.width.toInt();

    final int x1 = width ~/ 6;
    final int y1 = height ~/ 2;
    final int x2 = (5 * width) ~/ 6;
    final int y2 = height ~/ 2;
    final int r = width ~/ 15;
    final int x3 = width ~/ 2;
    final int y3 = height ~/ 2;

    return [x1, y1, x2, y2, x3, y3, r, width, height];
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

    timer = Timer.periodic(const Duration(milliseconds: 50), (timer) async {
      if (isCapturing) return;
      isCapturing = true;

      try {
        final image = await controller!.takePicture();

        final compressedImageBytes = compressImage(image.path);
        final encodedImage = base64Encode(compressedImageBytes);

        final List<int> circles = getSizeOfFrame();

        final data = jsonEncode({
          'image': encodedImage,
          'circle1': [circles[0], circles[1], circles[6]],
          'circle2': [circles[4], circles[5], circles[6]],
          'circle3': [circles[2], circles[3], circles[6]],
        });

        channel.sink.add(data);
      } catch (e) {
        debugPrint('Error capturing image: $e');
      } finally {
        isCapturing = false;
      }
    });
  }

  void initializeWebSocket() {
    channel = IOWebSocketChannel.connect('ws://172.20.10.11:8765');
    channel.stream.listen((dynamic data) {
      debugPrint(data);
      data = jsonDecode(data);
      if (data['data'] == null) {
        debugPrint('Server error occurred in recognizing face');
        return;
      }

      if (data["status"] == true) {

        final stats = data['data'];
        statusLeft = stats[0] == 1 ? DetectionStatus.detected : DetectionStatus.notDetected;
        statusMiddle = stats[1] == 1 ? DetectionStatus.detected : DetectionStatus.notDetected;
        statusRight = stats[2] == 1 ? DetectionStatus.detected : DetectionStatus.notDetected;

        stats[0] == 1 ? context.read<ColorNotifier>().changeColorLeft(Colors.green) : context.read<ColorNotifier>().changeColorLeft(Colors.red);
        stats[1] == 1 ? context.read<ColorNotifier>().changeColorMiddle(Colors.green) : context.read<ColorNotifier>().changeColorMiddle(Colors.red);
        stats[2] == 1 ? context.read<ColorNotifier>().changeColorRight(Colors.green) : context.read<ColorNotifier>().changeColorRight(Colors.red);



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

  Uint8List compressImage(String imagePath, {int quality = 85}) {
    final image = img.decodeImage(Uint8List.fromList(File(imagePath).readAsBytesSync()))!;
    final compressedImage = img.encodeJpg(image, quality: quality); // lossless compression
    return compressedImage;
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

    final List<int> circles = getSizeOfFrame();
    final colorLeft = context.watch<ColorNotifier>().colorLeft;
    final colorRight = context.watch<ColorNotifier>().colorRight;
    final colorMiddle = context.watch<ColorNotifier>().colorMiddle;

    final color = [colorLeft, colorRight, colorMiddle];

    final screenSize = MediaQuery.of(context).size;

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
                      circles[0], circles[1], circles[6],
                      circles[2], circles[3], circles[6],
                      circles[4], circles[5], circles[6],
                      color,
                      controller!.value.previewSize,
                      screenSize
                    ),
                  ),
                ),
                Align(
                  alignment: const Alignment(0, .85),
                  child: ElevatedButton(
                    child: Text(
                      currentStatus,
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
}

class CirclePainter extends CustomPainter {
  final int x1, y1, r1;
  final int x2, y2, r2;
  final int x3, y3, r3;
  List <Color> color;
  final Size? previewSize;
  final Size? screenSize;

  CirclePainter(this.x1, this.y1, this.r1, this.x2, this.y2, this.r2, this.x3, this.y3, this.r3, this.color, this.previewSize, this.screenSize);

  @override
  void paint(Canvas canvas, Size size) {
    if (previewSize == null) return;

    final paintLeft = Paint()
      ..color = color[0]
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final paintRight = Paint()
      ..color = color[1]
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final paintMiddle = Paint()
      ..color = color[2]
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;



    // Draw circles
    //canvas.drawCircle(Offset(screenSize!.width / 4, previewSize!.height  / 2), r1.toDouble() * scaleX, paint);
    //canvas.drawCircle(Offset(3 * screenSize!.width / 4, previewSize!.height  / 2), r2.toDouble() * scaleX, paint);

    canvas.drawCircle(Offset(375 / 6, 667 / 2), 30, paintLeft);
    canvas.drawCircle(Offset(5* 375 / 6, 667 / 2), 30, paintRight);
    canvas.drawCircle(Offset(375 / 2, 667 / 2), 30, paintMiddle);



  }

  @override
  bool shouldRepaint(CirclePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.x1 != x1 || oldDelegate.y1 != y1 || oldDelegate.r1 != r1 ||
        oldDelegate.x2 != x2 || oldDelegate.y2 != y2 || oldDelegate.r2 != r2;
  }
}

class ColorNotifier extends ChangeNotifier {
  Color _colorLeft = Colors.red;
  Color get colorLeft => _colorLeft;

  Color _colorRight = Colors.red;
  Color get colorRight => _colorRight;

  Color _colorMiddle = Colors.red;
  Color get colorMiddle => _colorMiddle;

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
}
