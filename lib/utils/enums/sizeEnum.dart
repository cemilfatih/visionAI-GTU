

enum sizeEnum{

  croppedImageWidth,
  croppedImageHeight,
  croppedImageHeight2,
  stage2_croppedImageWidth,
  stage2_croppedImageHeight,

  circleRadius;

  double get size{
    switch(this){
      case sizeEnum.croppedImageWidth:
        return 0.95;
      case sizeEnum.croppedImageHeight:
        return 0.1;
      case sizeEnum.croppedImageHeight2:
        return 8.1/10;


      case sizeEnum.circleRadius:
        return 20;
      default:
        return 0;
    }
  }


}