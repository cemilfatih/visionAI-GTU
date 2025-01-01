import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';
import 'package:vision_ai/product/constants/constants.dart';
import 'package:vision_ai/utils/enums/sizeEnum.dart';
import '../../main.dart';
import '../../utils/painters/painters.dart';
import '../init/notifier/providers.dart';
import 'cameraMixin.dart';


abstract class CameraViewInit {
  CameraController get controller;
  ScreenshotController get screenshotController;
  WebSocketChannel get channel;
  Timer? get timer;
  bool get isCapturing;
  bool isNavigating = false;
  Uint8List get ss_image;

  set timer(Timer? timer);
  set isCapturing(bool isCapturing);
  set ss_image(Uint8List ss_image);

}


class CameraView extends StatefulWidget {
  const CameraView({super.key});

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> with CameraViewMixin implements CameraViewInit {

  @override
  ScreenshotController screenshotController = ScreenshotController();
  CameraController? _controller;
  @override
  late WebSocketChannel channel;
  @override
  Timer? timer;
  @override
  bool isCapturing = false;
  @override
  bool isNavigating = false;
  @override
  late Uint8List ss_image;


  @override
  CameraController get controller => _controller!;

  @override
  void initState() {
    super.initState();
    initializeCamera(context);
    initializeWebSocket();
  }

  Future<void> initializeCamera(BuildContext context) async {
    final cameras = await availableCameras();
    final firstCamera = cameras[0];

    _controller = CameraController(
      firstCamera,
      ResolutionPreset.veryHigh,
      enableAudio: false,
    );

    _controller?.setFlashMode(FlashMode.off);

    await _controller!.initialize();
    setState(() {});

    timer = Timer.periodic(const Duration(milliseconds: 300), (timer) async {
      if (isCapturing) return;
      isCapturing = true;

      try {
        final image = await _controller!.takePicture();

        final List<Uint8List> cropped_compressed_list = await cropAndCompressImage(context, image.path);

        //make sure image is deleted after use
        File(image.path).delete();

        final encodedImage1 = base64Encode(cropped_compressed_list[0]);
        final encodedImage2 = base64Encode(cropped_compressed_list[1]);
        
        final data = jsonEncode({
          'image1': encodedImage1,
          'image2': encodedImage2,
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
    channel = IOWebSocketChannel.connect(constants.ip);
    channel.stream.listen((dynamic data) {
      debugPrint(data);
      data = jsonDecode(data);
      if (!data['status']) {
        debugPrint('Server error occurred in recognizing face');
        return;
      }

      if (data["status"] == true) {
        final List detections_top = data['detections_top'];
        final List detections_bottom = data['detections_bottom'];


        context.read<DetectionNotifier>().changeDetections(detections_top, detections_bottom);
        checkCircles(context, detections_top,detections_bottom, controller.value.previewSize!);
        final bool ss_capture = context.read<ColorNotifier>().checkFullDetection();
        final stage2 = context.read<ColorNotifier>().stage2;

        if (ss_capture && stage2 && !isNavigating) {
          isNavigating = true;
          context.read<ColorNotifier>().resetStage2();
          isNavigating = false;
          screenshotController.capture().then((Uint8List? image) {
            if (image != null) {
              ss_image = image;
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => DetectionDone(image: ss_image)),
              ).then((_){
                isNavigating = false;
              });
            }
          });
        }
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
    _controller?.dispose();
    channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!(_controller?.value.isInitialized ?? false)) {
      return const SizedBox();
    }

    final List<double> circles = getCircles(context);
    final colorLeft = context.watch<ColorNotifier>().colorLeft;
    final colorRight = context.watch<ColorNotifier>().colorRight;
    final colorMiddle = context.watch<ColorNotifier>().colorMiddle;
    final colorDownLeft = context.watch<ColorNotifier>().downLeft;
    final colorDownRight = context.watch<ColorNotifier>().downRight;

    final color = [colorLeft, colorRight, colorMiddle, colorDownLeft, colorDownRight];
    final screenSize = MediaQuery.of(context).size;

    final List detections_top = context.watch<DetectionNotifier>().detections_top;
    final List detections_bottom = context.watch<DetectionNotifier>().detections_bottom;

    return Screenshot(
      controller: screenshotController,
      child: Scaffold(
        extendBody: true,
        body: Center(
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: controller.value.previewSize!.width,
              height: controller.value.previewSize!.height,
              child: Stack(
                children: [
                  Positioned.fill(child: CameraPreview(controller)),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: CirclePainter(
                        circles,
                        color,
                        controller.value.previewSize,
                        screenSize,
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
                        detections_top,
                        detections_bottom,
                        controller.value.previewSize,
                        screenSize,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

}

