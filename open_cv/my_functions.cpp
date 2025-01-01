#include <opencv2/opencv.hpp>
#include <vector>
#include <chrono>

using namespace cv;
using namespace std;

#ifdef __ANDROID__
#include <android/log.h>
#define LOG_TAG "FFI Logger"
#define LOG(...) __android_log_print(ANDROID_LOG_VERBOSE, LOG_TAG, __VA_ARGS__)
#else
#define LOG(...) printf(__VA_ARGS__)
#endif

extern "C" {

struct DetectionResult {
    int x;
    int y;
    int radius;
};

__attribute__((visibility("default"))) __attribute__((used))
const char *getOpenCVVersion() {
    return CV_VERSION;
}

__attribute__((visibility("default"))) __attribute__((used))
void convertImageToGrayImage(const char *inputImagePath, const char *outputPath) {
    LOG("Input Path: %s", inputImagePath);
    Mat img = imread(inputImagePath);
    if (img.empty()) {
        LOG("Failed to load image at path: %s", inputImagePath);
        return;
    }

    Mat graymat;
    cvtColor(img, graymat, COLOR_BGR2GRAY);
    LOG("Output Path: %s", outputPath);
    imwrite(outputPath, graymat);
}

__attribute__((visibility("default"))) __attribute__((used))
vector<Vec3f> detectCircles(const char* imagePath) {
    Mat image = imread(imagePath, IMREAD_COLOR);
    if (image.empty()) {
        LOG("Failed to load image for circle detection: %s", imagePath);
        return {};
    }

    Mat gray;
    cvtColor(image, gray, COLOR_BGR2GRAY);
    GaussianBlur(gray, gray, Size(5, 5), 0);

    vector<Vec3f> circles;
    HoughCircles(gray, circles, HOUGH_GRADIENT, 1.2, 70, 100, 80, 10, 70);

    LOG("Detected %zu circles", circles.size());
    return circles; // Each circle is a Vec3f: x, y, radius
}

__attribute__((visibility("default"))) __attribute__((used))
DetectionResult* getDetections(const char* imagePath, int* count) {
    Mat image = imread(imagePath, IMREAD_COLOR);
    if (image.empty()) {
        LOG("Failed to load image for detection: %s", imagePath);
        *count = 0;
        return nullptr;
    }

    Mat gray;
    cvtColor(image, gray, COLOR_BGR2GRAY);
    GaussianBlur(gray, gray, Size(5, 5), 0);

    vector<Vec3f> circles;
    HoughCircles(gray, circles, HOUGH_GRADIENT, 1.2, 70, 100, 80, 10, 70);

    *count = circles.size();
    DetectionResult* results = new DetectionResult[*count];
    for (size_t i = 0; i < circles.size(); i++) {
        results[i] = { (int)circles[i][0], (int)circles[i][1], (int)circles[i][2] };
    }

    LOG("Returning %d detections", *count);
    return results;
}
}

bool isCross(Vec4i line1, Vec4i line2) {
    auto [x1, y1, x2, y2] = line1;
    auto [x3, y3, x4, y4] = line2;

    auto ccw = [](Point A, Point B, Point C) {
        return (C.y - A.y) * (B.x - A.x) > (B.y - A.y) * (C.x - A.x);
    };

    return ccw(Point(x1, y1), Point(x3, y3), Point(x4, y4)) != ccw(Point(x2, y2), Point(x3, y3), Point(x4, y4))
           && ccw(Point(x1, y1), Point(x2, y2), Point(x3, y3)) != ccw(Point(x1, y1), Point(x2, y2), Point(x4, y4));
}
