import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:vision_ai/product/camera/cameraView.dart';
import 'package:vision_ai/utils/enums/sizeEnum.dart';
import 'package:provider/provider.dart';

import '../../main.dart';
import '../init/notifier/providers.dart';

mixin CameraViewMixin  {

  List<double> getCircles(BuildContext context) {
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

  Future<List<Uint8List>> cropAndCompressImage(BuildContext context, String imagePath, {int quality = 100}) async {
    final imageBytes = await File(imagePath).readAsBytes();
    final image = img.decodeImage(imageBytes)!;

    final rectWidth = (image.width * sizeEnum.croppedImageWidth.size).toInt();
    final rectHeight = (image.height * sizeEnum.croppedImageHeight.size).toInt();

    final left =  (image.width - rectWidth) ~/ 2;
    final top =   (image.height - rectHeight) ~/ 2;

    final top2 = ((image.height * sizeEnum.croppedImageHeight2.size )~/1) - (rectHeight~/2);


    final croppedImage = img.copyCrop(image, x: left, y: top, width: rectWidth, height: rectHeight);
    final croppedImage2 = img.copyCrop(image, x: left, y: top2, width: rectWidth, height: rectHeight);

    final compressedImage = img.encodeJpg(croppedImage, quality: quality);
    final compressedImage2 = img.encodeJpg(croppedImage2, quality: quality);

    Uint8List comp1 = Uint8List.fromList(compressedImage);
    Uint8List comp2 = Uint8List.fromList(compressedImage2);


    return [comp1, comp2];
  }


  void checkCircles(BuildContext context, List detections_top,  List detections_bottom,Size cameraSize) {
    final Size screenSize = MediaQuery.of(context).size;
    List circles = getCircles(context);

    final List<bool> flags = [false, false, false, false, false];


    for (int i = 0; i < detections_top.length; i++) {
      final detection = detections_top[i];

      sizeEnum.circleRadius.size;

      final widthOffset = (1 - sizeEnum.croppedImageWidth.size) / 2;
      final heightOffset = (1 - sizeEnum.croppedImageHeight.size) / 2;

      final double x = (detection[0] * screenSize.width / cameraSize.height) + screenSize.width * widthOffset;
      final double y = (detection[1] * screenSize.height / cameraSize.width) + screenSize.height * heightOffset;

      final double radius = sizeEnum.circleRadius.size;

      if (x > circles[0] - radius && x < circles[0] + radius && y > circles[1] - radius && y < circles[1] + radius) {
        context.read<ColorNotifier>().changeColorLeft(Colors.green);
        flags[0] = true;
      } else if (x > circles[2] - radius && x < circles[2] + radius && y > circles[3] - radius && y < circles[3] + radius) {
        context.read<ColorNotifier>().changeColorMiddle(Colors.green);
        flags[1] = true;
      } else if (x > circles[4] - radius && x < circles[4] + radius && y > circles[5] - radius && y < circles[5] + radius) {
        context.read<ColorNotifier>().changeColorRight(Colors.green);
        flags[2] = true;
      }
    }

    for (int i = 0; i < detections_bottom.length; i++){
      final detection = detections_bottom[i];

      sizeEnum.circleRadius.size;

      final widthOffset = (1 - sizeEnum.croppedImageWidth.size) / 2;
      final heightOffset = sizeEnum.croppedImageHeight2.size - sizeEnum.croppedImageHeight.size / 2;

      final double x = (detection[0] * screenSize.width / cameraSize.height) + screenSize.width * widthOffset;
      final double y = (detection[1] * screenSize.height / cameraSize.width) + screenSize.height * heightOffset;

      final double radius = sizeEnum.circleRadius.size;

      if (x > circles[6] - radius && x < circles[6] + radius && y > circles[7] - radius && y < circles[7] + radius) {
        context.read<ColorNotifier>().changeColorDownLeft(Colors.green);
        flags[3] = true;
      } else if (x > circles[8] - radius && x < circles[8] + radius && y > circles[9] - radius && y < circles[9] + radius) {
        context.read<ColorNotifier>().changeColorDownRight(Colors.green);
        flags[4] = true;
      }
    }




    if (!flags[0]) {
      context.read<ColorNotifier>().changeColorLeft(Colors.red);
    }
    if (!flags[1]) {
      context.read<ColorNotifier>().changeColorMiddle(Colors.red);
    }
    if (!flags[2]) {
      context.read<ColorNotifier>().changeColorRight(Colors.red);
    }
    if (!flags[3]) {
      context.read<ColorNotifier>().changeColorDownLeft(Colors.red);
    }
    if (!flags[4]) {
      context.read<ColorNotifier>().changeColorDownRight(Colors.red);
    }
  }


  List<double> getPoints() {
    double x1 = 0.6 / 6;
    double y1 = 5 / 10;
    double x2 = 1 / 2;
    double y2 = 5 / 10;
    double x3 = 5.4 / 6;
    double y3 = 5 / 10;
    double x4 = 0.6 / 6;
    double y4 = 8.1 / 10;
    double x5 = 5.4 / 6;
    double y5 = 8.1 / 10;
    double r = 0.0;

    return [x1, y1, x2, y2, x3, y3, x4, y4, x5, y5, r];
  }


}
