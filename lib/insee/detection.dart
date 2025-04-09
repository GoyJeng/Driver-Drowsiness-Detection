import 'dart:async';
import 'package:driver/global_user.dart';
import 'package:driver/insee/camera.dart';
import 'package:driver/insee/root.dart';
import 'package:driver/insee/setting.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  _CameraPageState createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _cameraController;
  bool isCameraInitialized = false;
  bool isProcessing = false;
  Uint8List? detectedImage;
  int processingFrameCount = 0;
  List<Map<String, dynamic>> detectedFaces = [];
  Timer? _alertTimer;
  bool isAlertActive = false;
  int BlinkCount = 0;
  int MouthCount = 0;
  int eyesClosedDuration = 0;
  DateTime? _lastFaceDetectedTime;
  Timer? _noFaceTimer;
  DateTime? _lastNoFaceTime;
  bool _isNoFaceAlertActive = false;
  bool _hasShownFirstAlert = false;
  bool isCountdownVisible = false;
  @override
  void initState() {
    super.initState();
    initializeCamera();
    _lastFaceDetectedTime = DateTime.now();
    _hasShownFirstAlert = false;
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
//เฟรมวีดีโอ 20 เฟรมต่อวินาที
    _cameraController!.startImageStream((CameraImage image) async {
      processingFrameCount++;
      if (processingFrameCount % 3 == 0 && !isProcessing) {
        await processImage(image);
      }
    });
  }

  Future<void> processImage(CameraImage image) async {
    if (isProcessing) return;

    setState(() {
      isProcessing = true;
    });

    try {
      // แปลงภาพเป็น Uint8List เพื่อส่งไปยังเซิร์ฟเวอร์
      Uint8List? imageBytes = await convertCameraImageToBytes(image);

      if (imageBytes != null) {
        await sendImageToServer(imageBytes);
      }
    } catch (e) {
      print('Error processing image: $e');
    } finally {
      setState(() {
        isProcessing = false;
      });
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

  bool isAlerting = false;

//============================================================================================================

  final NotificationManager _notificationManager = NotificationManager();
  final NotificationNoFace _notificationNoFace = NotificationNoFace();
//ส่งภาพไปยังเซิฟเวอร์
  Future<void> sendImageToServer(Uint8List imageBytes) async {
    try {
      if (isAlertActive) return;

      const serverUrl = 'http://192.168.239.7:5000/process-video';
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

      // Debug print
      print('Server Response Status Code: ${response.statusCode}');
      print('Server Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final result = json.decode(response.body);

        if (result['processed_frame'] != null &&
            result['processed_frame'].isNotEmpty) {
          final processedFrame = result['processed_frame'][0];
          final lastBlinkCount = processedFrame['last_blink_count'] ?? 0;
          final lastMouthCount = processedFrame['last_mouth_count'] ?? 0;
          final CountBlinkCount = processedFrame['blink_count'] ?? 0;
          final CountMouthCount = processedFrame['mouth_open_count'] ?? 0;
          final CountEyesLong = processedFrame['eyes_closed_duration'] ?? 0;

          setState(() {
            BlinkCount = CountBlinkCount;
            MouthCount = CountMouthCount;
            eyesClosedDuration = CountEyesLong;
          });

          // หลับตานาน
          if (processedFrame['eye_status'] != null &&
              processedFrame['eye_status'].isNotEmpty) {
            final eyeStatus = processedFrame['eye_status'][0];
            final isContinuousEyeClosure =
                eyeStatus['continuous_eye_closure'] ?? false;
            final eyesClosedDuration = eyeStatus['eyes_closed_duration'] ?? 0.0;

            if (isContinuousEyeClosure && eyesClosedDuration >= 5) {
              await handleDrowsinessAlert('หลับตานาน');
              //'อันตราย ระดับ 3 หลับตานานเกินไป (${eyesClosedDuration
              //.toStringAsFixed(1)} วินาที)');
              return;
            }
          }

          // วิเคราะห์อาการง่วง
          final drowsinessAnalysis = analyzeDrowsiness(lastBlinkCount, lastMouthCount);
          // ถ้าตรวจพบอาการง่วงและไม่ได้กำลังแจ้งเตือนอยู่
          if (drowsinessAnalysis['isDrowsy'] && !isAlertActive) {
            await handleDrowsinessAlert(drowsinessAnalysis['cause']);
          }

          final faceDetails = processedFrame['face_details'] as List<dynamic>?;

          if (faceDetails != null && faceDetails.isNotEmpty) {
            _lastFaceDetectedTime = DateTime.now();
            _isNoFaceAlertActive = false;
            _hasShownFirstAlert = false;
            isCountdownVisible = false;
            _lastNoFaceTime = null;

            final List<Map<String, dynamic>> faces = faceDetails.map((face) {
              final bbox = face['bbox'] as Map<String, dynamic>;
              final eyePoints =
                  face.containsKey('eye_points') ? face['eye_points'] : null;
              final mouthPoints = face.containsKey('amouth_points')
                  ? face['amouth_points']
                  : null;
              return {
                "bbox": {
                  "x": (bbox['x'] as num).toDouble(),
                  "y": (bbox['y'] as num).toDouble(),
                  "width": (bbox['width'] as num).toDouble(),
                  "height": (bbox['height'] as num).toDouble(),
                },
                "confidence": (face['confidence'] as num).toDouble(),
                "eye_points": eyePoints,
                "mouth_points": mouthPoints
              };
            }).toList();

            setState(() {
              detectedFaces = faces;
            });
          } else {
            // No face detected
            final now = DateTime.now();
            if (!_isNoFaceAlertActive) {
              if (_lastNoFaceTime == null) {
                // First time no face is detected
                _lastNoFaceTime = now;
                setState(() {
                  isCountdownVisible = true; // Show countdown
                });
              }

              final timeSinceNoFace = now.difference(_lastNoFaceTime!);//ฟังก์ชั่นcheckไม่เจอใบหน้า
              if (timeSinceNoFace.inSeconds >= 3) {
                // 3 seconds have passed without a face
                setState(() {
                  isCountdownVisible = false; // Hide countdown
                });
                _isNoFaceAlertActive = true;
                await NoFaceAlert('ไม่พบใบหน้า');
                _isNoFaceAlertActive = false;
                _lastNoFaceTime = now; // Reset the timer after alert
              }
            } else {
              // Alert is not active, reset timer
              _lastNoFaceTime = now;
              setState(() {
                isCountdownVisible = false;
              });
            }

            setState(() {
              detectedFaces = [];
            });
          }
        } else {
          // หากไม่มี processed_frame
          setState(() {
            detectedFaces = [];
            BlinkCount = BlinkCount;
            MouthCount = MouthCount;
            eyesClosedDuration = eyesClosedDuration;
          });
          await NoFaceAlert('ไม่พบใบหน้า');
        }
      } else {
        print('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Detailed error sending image to server: $e');
    }
  }

//============================================================================================================

  Future<void> handleDrowsinessAlert(String cause) async {
    if (isAlertActive) return;//ส่งภาพไปยังเซิฟเวอร์
  Future<void> sendImageToServer(Uint8List imageBytes) async {
    try {
      if (isAlertActive) return;

      const serverUrl = 'http://192.168.239.7:5000/process-video';
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

      // Debug print
      print('Server Response Status Code: ${response.statusCode}');
      print('Server Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final result = json.decode(response.body);

        if (result['processed_frame'] != null &&
            result['processed_frame'].isNotEmpty) {
          final processedFrame = result['processed_frame'][0];
          final lastBlinkCount = processedFrame['last_blink_count'] ?? 0;
          final lastMouthCount = processedFrame['last_mouth_count'] ?? 0;
          final CountBlinkCount = processedFrame['blink_count'] ?? 0;
          final CountMouthCount = processedFrame['mouth_open_count'] ?? 0;
          final CountEyesLong = processedFrame['eyes_closed_duration'] ?? 0;

          setState(() {
            BlinkCount = CountBlinkCount;
            MouthCount = CountMouthCount;
            eyesClosedDuration = CountEyesLong;
          });

          // หลับตานาน
          if (processedFrame['eye_status'] != null &&
              processedFrame['eye_status'].isNotEmpty) {
            final eyeStatus = processedFrame['eye_status'][0];
            final isContinuousEyeClosure =
                eyeStatus['continuous_eye_closure'] ?? false;
            final eyesClosedDuration = eyeStatus['eyes_closed_duration'] ?? 0.0;

            if (isContinuousEyeClosure && eyesClosedDuration >= 5) {
              await handleDrowsinessAlert('อันตราย ระดับ 3 หลับตานานเกินไป');
              //'อันตราย ระดับ 3 หลับตานานเกินไป (${eyesClosedDuration.toStringAsFixed(1)} วินาที)');
              return;
            }
          }

          // วิเคราะห์อาการง่วง
          final drowsinessAnalysis =
              analyzeDrowsiness(lastBlinkCount, lastMouthCount);
          // ถ้าตรวจพบอาการง่วงและไม่ได้กำลังแจ้งเตือนอยู่
          if (drowsinessAnalysis['isDrowsy'] && !isAlertActive) {
            await handleDrowsinessAlert(drowsinessAnalysis['cause']);
          }

          final faceDetails = processedFrame['face_details'] as List<dynamic>?;

          if (faceDetails != null && faceDetails.isNotEmpty) {
            _lastFaceDetectedTime = DateTime.now();
            _isNoFaceAlertActive = false;
            _hasShownFirstAlert = false;
            isCountdownVisible = false;
            _lastNoFaceTime = null;
            final List<Map<String, dynamic>> faces = faceDetails.map((face) {
              final bbox = face['bbox'] as Map<String, dynamic>;
              final eyePoints =
                  face.containsKey('eye_points') ? face['eye_points'] : null;
              final mouthPoints = face.containsKey('amouth_points')
                  ? face['amouth_points']
                  : null;
              return {
                "bbox": {
                  "x": (bbox['x'] as num).toDouble(),
                  "y": (bbox['y'] as num).toDouble(),
                  "width": (bbox['width'] as num).toDouble(),
                  "height": (bbox['height'] as num).toDouble(),
                },
                "confidence": (face['confidence'] as num).toDouble(),
                "eye_points": eyePoints,
                "mouth_points": mouthPoints
              };
            }).toList();

            setState(() {
              detectedFaces = faces;
            });
          } else {
            // No face detected
            final now = DateTime.now();
            if (!_isNoFaceAlertActive) {
              if (_lastNoFaceTime == null) {
                // First time no face is detected
                _lastNoFaceTime = now;
                setState(() {
                  isCountdownVisible = true; // Show countdown
                });
              }

              final timeSinceNoFace = now.difference(_lastNoFaceTime!);//ฟังกฺชั่นcheckใบหน้า
              if (timeSinceNoFace.inSeconds >= 3) {
                // 3 seconds have passed without a face
                setState(() {
                  isCountdownVisible = false; // Hide countdown
                });
                _isNoFaceAlertActive = true;
                await NoFaceAlert('ไม่พบใบหน้า');
                _isNoFaceAlertActive = false;
                _lastNoFaceTime = now; // Reset the timer after alert
              }
            } else {
              // Alert is not active, reset timer
              _lastNoFaceTime = now;
              setState(() {
                isCountdownVisible = false;
              });
            }

            setState(() {
              detectedFaces = [];
            });
          }
        } else {
          // หากไม่มี processed_frame
          setState(() {
            detectedFaces = [];
            BlinkCount = BlinkCount;
            MouthCount = MouthCount;
            eyesClosedDuration = eyesClosedDuration;
          });
          await NoFaceAlert('ไม่พบใบหน้า');
        }
      } else {
        print('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Detailed error sending image to server: $e');
    }
  }
    if (!_notificationManager._canSendAlert()) {
      print('Alert skipped ');
      return;
    }
    setState(() {
      isAlertActive = true;
    });

    try {
      final DateTime now = DateTime.now();
      final String date =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final String time =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

      // ข้อมูลที่ส่งไปยัง API
      final Map<String, dynamic> notificationData = {
        'date': date,
        'time': time,
        'cause': cause,
        'userId': GlobalUser.userID,
      };

      // เรียก API สำหรับบันทึก
      final response = await http.post(
        Uri.parse('http://192.168.239.7:3000/notifications'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(notificationData),
      );

      if (response.statusCode == 201) {
        print('Notification saved successfully');
      } else {
        print('Failed to save notification: ${response.body}');
      }
    } catch (e) {
      print('Error saving notification: $e');
    }

    // แสดง AlertDialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/sounds/Alert.png',
                width: 500,
                height: 500,
              ),
              const SizedBox(height: 20),
              const Text(
                'Drowsiness Detected!',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );

    // เรียกใช้การแจ้งเตือนตามโหมดที่เลือก
    bool isLongEyesClosed = cause.contains('หลับตานานเกินไป');

    // เรียกใช้การแจ้งเตือนตามโหมดที่เลือก
    switch (globalSelectedMode) {
      case NotificationMode.safe:
        if (isLongEyesClosed) {
          await _notificationManager.playLongEyesClosedAlert();
        } else {
          await _notificationManager.playSafeAlert();
        }
        break;
      case NotificationMode.highSafety:
        if (isLongEyesClosed) {
          await _notificationManager.playLongEyesClosedHighSafetyAlert();
        } else {
          await _notificationManager.playHighSafetyAlert();
        }
        break;
      case NotificationMode.custom:
        if (isLongEyesClosed) {
          await _notificationManager.playLongEyesClosedCustomAlert();
        } else {
          await _notificationManager.playCustomAlert();
        }
        break;
      default:
        if (isLongEyesClosed) {
          await _notificationManager.playLongEyesClosedAlert();
        } else {
          await _notificationManager.playSafeAlert();
        }
    }

    if (context.mounted) {
      Navigator.of(context).pop();
    }
    _notificationManager._lastAlertTime = DateTime.now();
    setState(() {
      isAlertActive = false;
    });
  }

//============================================================================================================

  Future<void> NoFaceAlert(String cause) async {//แจ้งเตือนไม่เจอใบหน้า
    if (isAlertActive) return;
    if (!_notificationManager._canSendAlert()) {
      print('Alert skipped ');
      return;
    }
    setState(() {
      isAlertActive = true;
    });

    // แสดง AlertDialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/sounds/NoFacePic.png',
                width: 500,
                height: 500,
              ),
              const SizedBox(height: 20),
              const Text(
                'กรุณาวางใบหน้าให้อยู่ในกรอบของหน้าจอ',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );

    await _notificationNoFace.playAlertAndVibrate();

    if (context.mounted) {
      Navigator.of(context).pop();
    }
    _notificationManager._lastAlertTime = DateTime.now();
    setState(() {
      isAlertActive = false;
    });
  }

//============================================================================================================

  Map<String, dynamic> analyzeDrowsiness(int blinkCount, int yawnCount) {//กำหนดค่าเกณท์ต่างๆฟ
    // เกณฑ์การวิเคราะห์อาการง่วง
    const int blinkThreshold = 15; // กระพริบตาถี่เกิน  ครั้งต่อนาที
    const int yawnThreshold = 5; // หาวมากกว่า  ครั้งต่อนาที

    bool isFrequentBlinking = blinkCount >= blinkThreshold;
    bool isFrequentYawning = yawnCount >= yawnThreshold;

    return {
      'isDrowsy': isFrequentBlinking || isFrequentYawning,
      'cause': isFrequentBlinking && isFrequentYawning
          ? 'กระพริบตาถี่และหาวถี่' //กระพริบตาและหาว
          : isFrequentBlinking
              ? 'กระพริบตาถี่' //กระพริบตา
              : isFrequentYawning
                  ? 'หาวถี่' //หาว
                  : 'Normal',
      'blinkCount': blinkCount,
      'yawnCount': yawnCount
    };
  }

//============================================================================================================

  @override
  void dispose() {
    _notificationManager.dispose();
    _alertTimer?.cancel();
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    super.dispose();
  }

//============================================================================================================

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          const SizedBox(height: 100),
          // ส่วนกล้อง (CameraPreview + วาดกรอบ Bounding Box)
          Expanded(
            child: isCameraInitialized
                ? Stack(
                    children: [
                      // แสดง CameraPreview
                      Padding(
                        padding: const EdgeInsets.only(
                            left: 4), 
                        child: CameraPreview(_cameraController!),
                      ),

                      // วาดกรอบ Bounding Box (CustomPaint)
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
                      if (isCountdownVisible)
                        Container(
                          color: Colors.black54,
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(
                                  // ✅ วงกลมหมุน
                                  color: Colors.white,
                                  strokeWidth: 4.0, // ขนาดเส้น
                                ),
                                SizedBox(height: 20),
                                Text(
                                  'ระบบกำลังตรวจสอบใบหน้า...',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  )
                : const Center(child: CircularProgressIndicator()),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem(
                  icon: Icons.remove_red_eye,
                  label: 'Blinks',
                  value: '$BlinkCount',
                ),
                _buildStatItem(
                  icon: Icons.face,
                  label: 'Yawns',
                  value: '$MouthCount',
                ),
                _buildStatItem(
                  icon: Icons.timer,
                  label: 'Eyes Closed',
                  value: '$eyesClosedDuration',
                ),
              ],
            ),
          ),
          // ปุ่ม Start
Container(
  margin: const EdgeInsets.all(20),
  child: Center(
    child: GestureDetector(
      onTap: () async {
        // รับเฉพาะเวลาปัจจุบัน
        final now = DateTime.now();
        final stopTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
        final userId = GlobalUser.userID; // หรือวิธีเข้าถึงตัวแปร global ของคุณ
        
        // ส่งเวลาหยุดไปยังเซิร์ฟเวอร์
        try {
          final response = await http.post(
            Uri.parse('http://192.168.239.7:3000/stop'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'stoptime': stopTime,
              'userId': userId,
            }),
          );
          
          if (response.statusCode == 200) {
            print("บันทึกเวลาหยุดสำเร็จ");
          } else {
            print("ไม่สามารถบันทึกเวลาหยุดได้: ${response.statusCode}");
          }
        } catch (e) {
          print("เกิดข้อผิดพลาดในการบันทึกเวลาหยุด: $e");
        }
        
        debugPrint("Stop button clicked at $stopTime");
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const Root(
              userID: '', // ส่งค่า userID ที่เหมาะสมไปถ้าจำเป็น
            )
          ),
        );
      },
                child: Container(
                  height: 40,
                  width: 150,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                  child: const Center(
                    child: Text(
                      'Stop',
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.white,
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

class NotificationNoFace {
  Future<void> playAlertAndVibrate() async {
    //แจ้งเตือนตอนไม่เจอใบหน้า
    final AudioPlayer _audioPlayer = AudioPlayer();
    try {
      await _audioPlayer.setVolume(2.0);
      // เล่นเสียง
      await _audioPlayer.play(AssetSource('sounds/Noface1.mp3'));
      // รอให้เสียงเล่นจบ
      await _audioPlayer.onPlayerComplete.first;
    } catch (e) {
      print('Error playing safe alert: $e');
    } finally {
      await _audioPlayer.dispose();
    }
  }
}

Widget _buildStatItem({
  required IconData icon,
  required String label,
  required String value,
}) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        icon,
        color: Colors.white,
        size: 24,
      ),
      const SizedBox(height: 4),
      Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  );
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
    final paintPoint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill
      ..strokeWidth = 2.0;
    final mouthPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill
      ..strokeWidth = 5.0;

    final double scaleX = screenSize.width / previewSize.width;
    final double scaleY = screenSize.height / previewSize.height;

    for (var face in faces) {
      final bbox = face['bbox'];
      final double x = previewSize.height - (bbox['y'] + bbox['height']) - 230;
      final double y = previewSize.width - (bbox['x'] + bbox['width']) + 120;
      final rect = Rect.fromLTWH(
        x * scaleX,
        y * scaleY,
        bbox['width'] * scaleX,
        bbox['height'] * scaleY,
      );
      canvas.drawRect(rect, paint);

      if (face['eye_points'] != null) {
        final leftEyePoints = face['eye_points']['left_eye_points'] ?? [];
        final rightEyePoints = face['eye_points']['right_eye_points'] ?? [];

        // กำหนด offset ที่ต้องการ (เพิ่มหรือลดตามต้องการ) // ขยับจุดตาในแนวนอน
        final double offsetY = -240; // ขยับจุดตาในแนวตั้ง

        // วาดจุดตาซ้าย
        for (var point in leftEyePoints) {
          final double offsetX = -150;
          // คำนวณพิกัดตาใหม่
          final double eyeX =
              previewSize.height - (point['y'] * previewSize.height);
          final double eyeY = point['x'] * previewSize.width;

          // หมุน 180 องศา (กลับแกน X และ Y)
          final double rotatedEyeX = eyeX;
          final double rotatedEyeY = previewSize.height - eyeY;

          // เพิ่ม offset ให้กับจุดตา
          final double adjustedEyeX = rotatedEyeX + offsetX;
          final double adjustedEyeY = rotatedEyeY + offsetY;

          canvas.drawCircle(
              Offset(
                adjustedEyeX * (screenSize.width / previewSize.width),
                adjustedEyeY * (screenSize.height / previewSize.height),
              ),
              2.0,
              paintPoint);
        }

        // วาดจุดตาขวา
        for (var point in rightEyePoints) {
          final double offsetX = -80;
          // คำนวณพิกัดตาใหม่
          final double eyeX =
              previewSize.height - (point['y'] * previewSize.height);
          final double eyeY = point['x'] * previewSize.width;

          // หมุน 180 องศา (กลับแกน X และ Y)
          final double rotatedEyeX = eyeX;
          final double rotatedEyeY = previewSize.height - eyeY;

          // เพิ่ม offset ให้กับจุดตา
          final double adjustedEyeX = rotatedEyeX + offsetX;
          final double adjustedEyeY = rotatedEyeY + offsetY;

          canvas.drawCircle(
              Offset(
                adjustedEyeX * (screenSize.width / previewSize.width),
                adjustedEyeY * (screenSize.height / previewSize.height),
              ),
              2.0,
              paintPoint);
        }
      }
//วาดจุดปาก
      if (face['mouth_points'] != null &&
          face['mouth_points']['mouth_points'] != null) {
        print('Mouth points data: ${face['mouth_points']}');
        final mouthPoints = face['mouth_points']['mouth_points'] as List;
        for (var point in mouthPoints) {
          final double mouthX =
              previewSize.height - (point['y'] * previewSize.height) - 118;
          final double mouthY =
              previewSize.width - (point['x'] * previewSize.width) + 2;

          canvas.drawCircle(
              Offset(
                mouthX * (screenSize.width / previewSize.width),
                mouthY * (screenSize.height / previewSize.height),
              ),
              2.0,
              mouthPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

//============================================================================================================

class NotificationManager {
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _intervalTimer;
  DateTime? _lastAlertTime;
  bool _canSendAlert() {
    if (_lastAlertTime == null) return true;

    final settings = GlobalUser.notificationSettings;
    int intervalMinutes;

    switch (settings.interval) {
      case NotificationInterval.none:
        return true;
      case NotificationInterval.twoMin:
        intervalMinutes = 2;
        break;
      case NotificationInterval.fourMin:
        intervalMinutes = 4;
        break;
      case NotificationInterval.sixMin:
        intervalMinutes = 6;
        break;
      case NotificationInterval.eightMin:
        intervalMinutes = 8;
        break;
      case NotificationInterval.tenMin:
        intervalMinutes = 10;
        break;
      case NotificationInterval.custom:
        intervalMinutes = settings.customIntervalMinutes ?? 0;
        break;
      default:
        return true;
    }

    final timeSinceLastAlert = DateTime.now().difference(_lastAlertTime!);
    return timeSinceLastAlert.inMinutes >= intervalMinutes;
  }

  Future<void> playAlertAndVibrate() async {
    //แจ้งเตือนตอนไม่เจอใบหน้า
    final AudioPlayer _audioPlayer = AudioPlayer();
    try {
      await _audioPlayer.setVolume(1.0);
      // เล่นเสียง
      await _audioPlayer.play(AssetSource('sounds/Noface1.mp3'));
      // รอให้เสียงเล่นจบ
      await _audioPlayer.onPlayerComplete.first;
    } catch (e) {
      print('Error playing safe alert: $e');
    } finally {
      await _audioPlayer.dispose();
    }
  }

  Future<void> playSafeAlert() async {
    final AudioPlayer _audioPlayer = AudioPlayer();
    try {
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.play(AssetSource('sounds/alertTWO.mp3'));
      // รอให้เสียงเล่นจบ
      await _audioPlayer.onPlayerComplete.first;
    } catch (e) {
      print('Error playing safe alert: $e');
    } finally {
      await _audioPlayer.dispose(); // ปิดการใช้งาน AudioPlayer
    }
  }

  Future<void> playHighSafetyAlert() async {
    final AudioPlayer _audioPlayer = AudioPlayer();
    try {
      Vibration.vibrate(duration: 6000);
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.play(AssetSource('sounds/alertTWO.mp3'));
      // รอให้เสียงเล่นจบ
      await _audioPlayer.onPlayerComplete.first;
    } catch (e) {
      print('Error playing safe alert: $e');
    } finally {
      await _audioPlayer.dispose(); // ปิดการใช้งาน AudioPlayer
    }
  }

  Future<void> playCustomAlert() async {
    if (!_canSendAlert()) {
      print('Alert skipped due to interval restriction');
      return;
    }

    final AudioPlayer player = AudioPlayer();
    try {
      if (GlobalUser.notificationSettings.isVibrationEnabled) {
        Vibration.vibrate(duration: 4000);
      }

      // ถ้าเปิดเสียง
      if (GlobalUser.notificationSettings.isSoundEnabled) {
        await _audioPlayer.setVolume(1.0);
        await player.play(AssetSource('sounds/alertTWO.mp3'));
        await player.onPlayerComplete.first;
      }

      await Future.delayed(const Duration(milliseconds: 500));

      // Update last alert time
      _lastAlertTime = DateTime.now();
    } catch (e) {
      print('Error playing custom alert: $e');
    } finally {
      await player.dispose();
    }
  }
  ///////////////////////////////////////////////////////////////////////////////////////////////////////

  Future<void> playLongEyesClosedAlert() async {
    final AudioPlayer player = AudioPlayer();
    try {
      for (int i = 0; i < 5; i++) {
        // ใช้เสียงแจ้งเตือนพิเศษสำหรับหลับตานาน
        await player.play(AssetSource('sounds/alert.mp3'));
        await player.onPlayerComplete.first;
      }
    } catch (e) {
      print('Error playing long eyes closed alert: $e');
    } finally {
      await player.dispose();
    }
  }

  Future<void> playLongEyesClosedHighSafetyAlert() async {
    final AudioPlayer player = AudioPlayer();
    try {
      for (int i = 0; i < 5; i++) {
        Vibration.vibrate(duration: 1000); // เพิ่มระยะเวลาการสั่นเป็น 1 วินาที
        await player.play(AssetSource('sounds/alert.mp3'));
        await player.onPlayerComplete.first;
      }
    } catch (e) {
      print('Error playing long eyes closed high safety alert: $e');
    } finally {
      await player.dispose();
    }
  }

  Future<void> playLongEyesClosedCustomAlert() async {
    if (!_canSendAlert()) {
      print('Alert skipped due to interval restriction');
      return;
    }

    final AudioPlayer player = AudioPlayer();
    try {
      for (int i = 0; i < 5; i++) {
        if (GlobalUser.notificationSettings.isVibrationEnabled) {
          Vibration.vibrate(duration: 1000);
        }

        if (GlobalUser.notificationSettings.isSoundEnabled) {
          await player.play(AssetSource('sounds/alert.mp3'));
          await player.onPlayerComplete.first;
        }

        await Future.delayed(const Duration(milliseconds: 500));
      }

      _lastAlertTime = DateTime.now();
    } catch (e) {
      print('Error playing long eyes closed custom alert: $e');
    } finally {
      await player.dispose();
    }
  }

  // Method to reset interval timing
  void resetInterval() {
    _lastAlertTime = null;
  }

  // Don't forget to dispose timer
  void dispose() {
    _intervalTimer?.cancel();
    _audioPlayer.dispose();
  }
}
