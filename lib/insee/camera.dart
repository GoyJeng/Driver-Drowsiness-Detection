import 'dart:convert';
import 'dart:typed_data';
import 'package:driver/insee/detection.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:driver/global_user.dart';
import 'package:image/image.dart' as img;


class StartCamera extends StatefulWidget {
  final bool isVisible;
  const StartCamera({super.key, required this.isVisible});

  @override
  _StartCameraState createState() => _StartCameraState();
}

class _StartCameraState extends State<StartCamera> with WidgetsBindingObserver {
  CameraController? _cameraController;
  bool isCameraInitialized = false;
  bool isProcessing = false;
   bool _isActive = true;
  List<Map<String, dynamic>> detectedFaces = [];
  int processingFrameCount = 0;
  DateTime? _faceDetectedTime;
  bool _isButtonEnabled = false;
  Timer? _faceDetectionTimer;
  int countdownTime = 3; // ตั้งค่าเวลาเริ่มต้น 3 วินาที
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _isActive = true;
    _isButtonEnabled = false;
    WidgetsBinding.instance.addObserver(this);
    initializeCamera();
  }
  @override
  void didUpdateWidget(StartCamera oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isVisible != widget.isVisible) {
      if (!widget.isVisible) {
        stopProcessing();
        stopCameraAndDispose();
      } else if (!_isActive) {
        setState(() {
          _isActive = true;
        });
        initializeCamera();
      }
    }
  }
  
  Future<void> initializeCamera() async {
    var cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
    );

    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.medium,
    );

    await _cameraController?.initialize();
    setState(() {
      isCameraInitialized = true;
    });

    startImageStream();
  }

    void startImageStream() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    _cameraController!.startImageStream((CameraImage image) async {
      if (!mounted) return;
      processingFrameCount++;
      if (processingFrameCount % 3 == 0 && !isProcessing &&_isActive) {
        await processImage(image);
      }
    });
  }

void stopCameraAndDispose() {
  _isActive = false;
  if (_cameraController != null) {
    if (_cameraController!.value.isStreamingImages) {
      _cameraController!.stopImageStream();
    }
    _cameraController!.dispose();
    _cameraController = null;
  }
  if (mounted) {
    setState(() {
      isCameraInitialized = false;
    });
  }
} 

@override
void didChangeDependencies() {
  super.didChangeDependencies();
  final bool isVisible = ModalRoute.of(context)?.isCurrent ?? false;
  
  if (!isVisible && _isActive) {
    stopProcessing();
    stopCameraAndDispose();
  } else if (isVisible && !_isActive && mounted) {
    setState(() {
      _isActive = true;
    });
    initializeCamera();
  }
}

void startCountdown() {
  countdownTime = 3;
  _countdownTimer?.cancel(); // ยกเลิก Timer เก่าถ้ามี
  _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
    if (countdownTime > 0) {
      setState(() {
        countdownTime--;
      });
    } else {
      timer.cancel();
    }
  });
}

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      stopProcessing(); // หยุดการประมวลผลเมื่อแอพไม่ active
      stopCameraAndDispose();
    }
  }

    void stopProcessing() {
    setState(() {
      _isActive = false;
      isProcessing = false;
      detectedFaces = [];
    });
  }

    @override
  void deactivate() {
    stopProcessing(); // หยุดการประมวลผลก่อนหยุดกล้อง
    stopCameraAndDispose();
    super.deactivate();
  }

  Future<void> processImage(CameraImage image) async {
    if (isProcessing|| !_isActive) return;

    setState(() {
      isProcessing = true;
    });

    try {
      // แปลงภาพเป็น Uint8List เพื่อส่งไปยังเซิร์ฟเวอร์
      Uint8List? imageBytes = await convertCameraImageToBytes(image);

      if (imageBytes != null && _isActive) {
        await sendImageToServer(imageBytes);
      }
    } catch (e) {
      print('Error processing image: $e');
    }  finally {
      if (mounted) { // เช็คว่า widget ยังอยู่ไหม
        setState(() {
          isProcessing = false;
        });
      }
    }
  }

    Future<Uint8List?> convertCameraImageToBytes(CameraImage image) async {
    try {
      // ตรวจสอบความถูกต้องของภาพ
      if (image.planes.isEmpty || image.planes[0].bytes.isEmpty) {
        print('Invalid image data');
        return null;
      }

      final img.Image convertedImage = _convertYUV420ToImage(image);

      if (convertedImage == null) {
        print('Image conversion failed');
        return null;
      }

      // แปลงภาพเป็น JPEG
      Uint8List encodedImage =
          Uint8List.fromList(img.encodeJpg(convertedImage, quality: 70));

      return encodedImage;
    } catch (e) {
      print('Image conversion error: $e');
      return null;
    }
  }

    img.Image _convertYUV420ToImage(CameraImage image) {
    final int width = image.width;
    final int height = image.height;

    final img.Image convertedImage = img.Image(width, height);

    final Plane yPlane = image.planes[0];
    final Plane uPlane = image.planes[1];
    final Plane vPlane = image.planes[2];

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int uvIndex = (y >> 1) * (image.planes[1].bytesPerRow) + (x >> 1);
        final int yIndex = y * image.planes[0].bytesPerRow + x;

        final int yValue = yPlane.bytes[yIndex];
        final int uValue = uPlane.bytes[uvIndex];
        final int vValue = vPlane.bytes[uvIndex];

        final r = (yValue + (1.370705 * (vValue - 128))).clamp(0, 255).toInt();
        final g =
            (yValue - (0.698001 * (vValue - 128)) - (0.337633 * (uValue - 128)))
                .clamp(0, 255)
                .toInt();
        final b = (yValue + (1.732446 * (uValue - 128))).clamp(0, 255).toInt();

        convertedImage.setPixel(x, y, img.getColor(r, g, b));
      }
    }
    return convertedImage;
  }



  Future<void> sendImageToServer(Uint8List imageBytes) async {
    try {
      const serverUrl = 'http://192.168.239.7:5000/process-faces-only';
      String base64Image = base64Encode(imageBytes);
      final requestBody = {
        "frames": [base64Image],
        "thresholds": {"EAR_THRESH": 0.20, "WAIT_TIME": 1.5}
      };

      final response = await http.post(
        Uri.parse(serverUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);

        if (result['processed_frame'] != null &&
            result['processed_frame'].isNotEmpty) {
          final processedFrame = result['processed_frame'][0];
          final faceDetails = processedFrame['face_details'] as List<dynamic>?;

        if (faceDetails != null && faceDetails.isNotEmpty) {
          if (_faceDetectedTime == null) {
            // Start countdown when face is first detected
            _faceDetectedTime = DateTime.now();
            startCountdown();
            _faceDetectionTimer?.cancel();
            _faceDetectionTimer = Timer(const Duration(seconds: 3), () {
              if (mounted) {
                setState(() {
                  _isButtonEnabled = true;
                });
              }
            });
          }

            final List<Map<String, dynamic>> faces = faceDetails.map((face) {
              final bbox = face['bbox'] as Map<String, dynamic>;
              return {
                "bbox": {
                  "x": (bbox['x'] as num).toDouble(),
                  "y": (bbox['y'] as num).toDouble(),
                  "width": (bbox['width'] as num).toDouble(),
                  "height": (bbox['height'] as num).toDouble(),
                },
                "confidence": (face['confidence'] as num).toDouble(), 
              };
            }).toList();

            setState(() {
              detectedFaces = faces;
            });
          } else {
          // No face detected, reset everything
          _faceDetectedTime = null;
          _faceDetectionTimer?.cancel();
          _countdownTimer?.cancel();
          
          setState(() {
            detectedFaces = [];
            _isButtonEnabled = false;
            countdownTime = 3; // Reset countdown
          });
        }
      }
    }
    } catch (e) {
      print('Detailed error sending image to server: $e');
    }
  }



 
  @override
  void dispose() {
    _faceDetectionTimer?.cancel();
    stopProcessing();
    WidgetsBinding.instance.removeObserver(this);
    stopCameraAndDispose();
    super.dispose();
  }

 


  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
Expanded(
  child: isCameraInitialized
      ? Stack(
          children: [
            // ขยับตำแหน่งกล้องไปทางขวานิดหน่อย
            Transform.translate(
              offset: Offset(5, 0), // เลื่อนภาพกล้องไปทางขวา 20 พิกเซล
              child: CameraPreview(_cameraController!),
            ),
            CustomPaint(
              size: Size(
                size.width,
                size.height,
              ),
              painter: FaceBoundingBoxPainter(
                faces: detectedFaces,
                previewSize: Size(
                  _cameraController!.value.previewSize!.height,
                  _cameraController!.value.previewSize!.width,
                ),
                screenSize: size,
              ),
            ),
          ],
        )
      : const Center(child: CircularProgressIndicator()),
)
,
                if (detectedFaces.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'ไม่พบใบหน้าบนหน้าจอ',
                      style: TextStyle(
                        color: Colors.red[300],
                        fontSize: 15,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                else if (countdownTime > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      '$countdownTime',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 15,
                      ),
                      textAlign: TextAlign.center,            
                    ),
                  ),
          Container(
            margin: const EdgeInsets.all(20),
            child: Center(
              child: GestureDetector(
                onTap: _isButtonEnabled
                    ? () async {
                      final now = DateTime.now();
                      final starttime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
                      final userId = GlobalUser.userID;
                        await http.get(Uri.parse('http://192.168.239.7:5000/reset-drowsiness'));
                    try {
                      print("กำลังส่ง: userId=${userId}, starttime=${starttime}");
                      final response = await http.post(
                        Uri.parse('http://192.168.239.7:3000/start'),
                        headers: {'Content-Type': 'application/json'},
                        body: json.encode({
                          'userId': userId,
                          'starttime': starttime,
                          
                        }),
                      );
                      
                      if (response.statusCode == 201) {
                        print("บันทึกเวลาเริ่มต้นสำเร็จ");
                      } else {
                        print("ไม่สามารถบันทึกเวลาเริ่มต้นได้: ${response.statusCode}");
                      }
                    } catch (e) {
                      print("เกิดข้อผิดพลาดในการบันทึกเวลาเริ่มต้น: $e");
                    }
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CameraPage()),
                        );
                        debugPrint("Start button clicked");
                      }
                    : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 40,
                  width: 150,
                  decoration: BoxDecoration(
                    color: _isButtonEnabled ? Colors.green : Colors.grey,
                    borderRadius: const BorderRadius.all(Radius.circular(20)),
                  ),
                  child: Center(
                    child: Text(
                      'Start',
                      style: TextStyle(
                        fontSize: 20,
                        color: _isButtonEnabled ? Colors.white : Colors.black38,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FaceBoundingBoxPainter extends CustomPainter {
  final List<Map<String, dynamic>> faces;
  final Size previewSize;
  final Size screenSize;

  FaceBoundingBoxPainter({
    required this.faces,
    required this.previewSize,
    required this.screenSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final double scaleX = screenSize.width / previewSize.width;
    final double scaleY = screenSize.height / previewSize.height;

    for (var face in faces) {
      final bbox = face['bbox'];
      final double x = previewSize.height - (bbox['y'] + bbox['height']) - 230;
      final double y = previewSize.width - (bbox['x'] + bbox['width']) + 130;
      final rect = Rect.fromLTWH(
        x * scaleX,
        y * scaleY,
        bbox['width'] * scaleX,
        bbox['height'] * scaleY,
      );
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
