
import 'package:flutter/material.dart';
import 'package:vision_ai/utils/enums/sizeEnum.dart';



class RectangleOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    final rectWidth = size.width * sizeEnum.croppedImageWidth.size;
    final rectHeight = size.height * sizeEnum.croppedImageHeight.size;
    final left = (size.width - rectWidth) / 2;
    final top = (size.height - rectHeight) / 2;
    
    final left2 = (size.width - rectWidth) / 2;
    final top2 = ((size.height * sizeEnum.croppedImageHeight2.size ) - (rectHeight~/2))*1.0;




    final rect = Rect.fromLTWH(left, top, rectWidth, rectHeight);
    
    final rect2 = Rect.fromLTWH(left2, top2, rectWidth,rectHeight);

    
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(rect)
      ..addRect(rect2)
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
  final List detections_top;
  final List detections_bottom;



  DetectionPainter(this.detections_top,this.detections_bottom, this.previewSize, this.screenSize);


  @override
  void paint(Canvas canvas, Size size) {

    final paint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    const r = 10;

    for (int i =0; i<detections_top.length ; i++){
      final detection = detections_top[i];

      //detection[0] is width of camera preview and detection[1] is height of camera preview

      final double widthOffset = (1-sizeEnum.croppedImageWidth.size)/2;
      final double heightOffset = (1-sizeEnum.croppedImageHeight.size)/2;

      final double x = detection[0] * screenSize!.width / previewSize!.height;
      final double y = detection[1] * screenSize!.height / previewSize!.width;

      final double final_x = x + (screenSize!.width * widthOffset);
      final double final_y = y + (screenSize!.height * heightOffset);

      canvas.drawLine(Offset(final_x-r, final_y), Offset(final_x+r, final_y), paint);
      canvas.drawLine(Offset(final_x, final_y+r), Offset(final_x, final_y-r), paint);

    }

    for (int i = 0; i<detections_bottom.length; i++){
      final detection = detections_bottom[i];

      final double widthOffset = (1-sizeEnum.croppedImageWidth.size)/2;
      final double heightOffset = sizeEnum.croppedImageHeight2.size - sizeEnum.croppedImageHeight.size/2;

      final double x = detection[0] * screenSize!.width / previewSize!.height;
      final double y = detection[1] * screenSize!.height / previewSize!.width;

      final double final_x = x + (screenSize!.width * widthOffset);
      final double final_y = y + (screenSize!.height * heightOffset);

      canvas.drawLine(Offset(final_x-r, final_y), Offset(final_x+r, final_y), paint);
      canvas.drawLine(Offset(final_x, final_y+r), Offset(final_x, final_y-r), paint);
    }

  }

  @override
  bool shouldRepaint(DetectionPainter oldDelegate) {
    return oldDelegate.detections_bottom != detections_bottom || oldDelegate.detections_top != detections_top;
  }
}
class CirclePainter extends CustomPainter {
  final List<double> circles;
  final List<Color> colors;
  final Size? previewSize;
  final Size? screenSize;

  CirclePainter(this.circles, this.colors, this.previewSize, this.screenSize);

  @override
  void paint(Canvas canvas, Size size) {
    if (previewSize == null || screenSize == null || circles.length < 10) return;

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..maskFilter = MaskFilter.blur(BlurStyle.solid, 1);


    final double r = sizeEnum.circleRadius.size; // Circle radius from your enum

    // Loop through each circle's coordinates and colors
    for (int i = 0; i < circles.length; i += 2) {
      paint.color = colors[i ~/ 2];  // Divide by 2 to match colors length
      canvas.drawCircle(Offset(circles[i], circles[i + 1]), r, paint);
    }
  }

  @override
  bool shouldRepaint(CirclePainter oldDelegate) {
    return oldDelegate.colors != colors || oldDelegate.circles != circles;
  }
}
