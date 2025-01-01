
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:vision_ai/product/camera/cameraView.dart';
import 'package:vision_ai/product/constants/constants.dart';
import 'package:vision_ai/product/init/notifier/providers.dart';
import 'package:vision_ai/utils/enums/sizeEnum.dart';
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
        home: const CameraView(),
      ),
    );
  }
}



