
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';

import '../../camera/cameraView.dart';


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

  bool _stage2 = false;
  bool get stage2 => _stage2;


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


  bool checkFullDetection(){
    _stage2 = _downLeft == Colors.green && _downRight == Colors.green && _colorLeft == Colors.green && _colorMiddle == Colors.green && _colorRight == Colors.green;
    return _stage2;
  }

  void resetStage2(){
    _stage2 = false;
    notifyListeners();
  }


}

class DetectionNotifier extends ChangeNotifier{
  List _detections_top = [];
  List _detections_bottom = [];
  List get detections_bottom => _detections_bottom;
  List get detections_top => _detections_top;


  void changeDetections(List newDetectionTop, List newDetectionBottom){
    _detections_top = newDetectionTop;
    _detections_bottom = newDetectionBottom;
    notifyListeners();
  }

}



class DetectionDone extends StatefulWidget {

  final Uint8List image;

  DetectionDone({super.key, required this.image});

  @override
  State<DetectionDone> createState() => _DetectionDoneState();
}

class _DetectionDoneState extends State<DetectionDone> {

  @override
  void dispose() {
    //delete image
    File.fromRawPath(widget.image).delete();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: Stack(
        children:[
          Center(
            child: Image.memory(widget.image),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            child: ElevatedButton(
              onPressed: (){
                Navigator.push(context, MaterialPageRoute(builder: (context) => CameraView()));
              },
              child: const Text('Back'),
            ),
          )

        ]
      ),
    );
  }
}
