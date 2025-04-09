import math
import cv2
import mediapipe as mp
import numpy as np
from flask import Flask, request, jsonify, Response
import io
from PIL import Image
import base64
import time

app = Flask(__name__)

mp_face_detection = mp.solutions.face_detection#ตั้งค่าmediapipe
mp_facemesh = mp.solutions.face_mesh
face_detection = mp_face_detection.FaceDetection(min_detection_confidence=0.7,)
facemesh = mp_facemesh.FaceMesh(
    static_image_mode=False, 
    max_num_faces=1, 
    min_detection_confidence=0.7,
    min_tracking_confidence=0.7 
)
mp_drawing = mp.solutions.drawing_utils

# จุดดวงตา
LEFT_EYE_POINTS = [33, 160, 158, 133, 153, 144]
RIGHT_EYE_POINTS = [362, 385, 387, 263, 373, 380]
#จุดปาก
MOUTH_POINTS = [78, 191, 80, 81, 82, 13, 312, 311, 310, 415, 308, 324, 318, 402, 317, 14, 87, 178, 88, 95]

#เกณท์ต่างๆ
EAR_THRESHOLD = 0.20
MOUTH_OPEN_THRESHOLD = 0.05
CLOSED_EYE_FRAMES = 5
CLOSED_EYE_TIME_THRESHOLD = 2.0


def calculate_distance(point1, point2):
    return math.sqrt((point1[0] - point2[0])**2 + (point1[1] - point2[1])**2)

def calculate_ear(eye_points, landmarks, image_width, image_height):
        # คำนวณอัตราส่วนการเปิดตา (EAR)
    p1 = (int(landmarks[eye_points[1]].x * image_width), int(landmarks[eye_points[1]].y * image_height))
    p2 = (int(landmarks[eye_points[5]].x * image_width), int(landmarks[eye_points[5]].y * image_height))
    p3 = (int(landmarks[eye_points[2]].x * image_width), int(landmarks[eye_points[2]].y * image_height))
    p4 = (int(landmarks[eye_points[4]].x * image_width), int(landmarks[eye_points[4]].y * image_height))
    p5 = (int(landmarks[eye_points[0]].x * image_width), int(landmarks[eye_points[0]].y * image_height))
    p6 = (int(landmarks[eye_points[3]].x * image_width), int(landmarks[eye_points[3]].y * image_height))

        
    vertical_1 = calculate_distance(p1, p2)
    vertical_2 = calculate_distance(p3, p4)
    horizontal = calculate_distance(p5, p6)
    return (vertical_1 + vertical_2) / (2.0 * horizontal)

#==============================================================================================================
#ตัวแปรสถานะ
blink_count = 0
mouth_count = 0
mouth_last_open = False  # ติดตามสถานะปากในเฟรมก่อนหน้า
blink_last_open = False  # ติดตามสถานะตาในเฟรมก่อนหน้า
last_blink_count = 0
last_mouth_count = 0 
ResetCount = time.time()
ResetDrow = time.time()
Start_resetdrow = False
eyes_closed_start = None

def get_mouth_points(face_landmarks):#ตำแหน่งจุดปาก
    mouth_points = {
        "mouth_points": []
    }

    important_points = [13, 14] 

    for point in important_points:
        landmarks_point = face_landmarks.landmark[point]
        mouth_points["mouth_points"].append({
            "x": landmarks_point.x,
            "y": landmarks_point.y
        })

    return mouth_points


def get_eye_points(face_landmarks):#ตำแหน่งจุดตา
    eye_points = {
        "left_eye_points": [],
        "right_eye_points": []
    }
    LEFT = [160, 158, 153, 144]
    RIGHT = [ 385, 387, 373, 380]

    for point in LEFT:
        landmarks_point = face_landmarks.landmark[point]
        eye_points["left_eye_points"].append({
            "x": landmarks_point.x,
            "y": landmarks_point.y
        })


    for point in RIGHT:
        landmarks_point = face_landmarks.landmark[point]
        eye_points["right_eye_points"].append({
            "x": landmarks_point.x,
            "y": landmarks_point.y
        })
    
    return eye_points

@app.route('/reset-drowsiness', methods=['GET'])#รีเซ็ทค่าความง่วง
def reset_drowsiness():
    reset_drowsiness_tracking()
    return jsonify({"status": "reset"})

def reset_drowsiness_tracking():
    global blink_count, mouth_count, eyes_closed_start, last_blink_count, last_mouth_count,ResetCount,Start_resetdrow,ResetDrow
    current_time = time.time()
    last_blink_count = blink_count
    last_mouth_count = mouth_count
    Start_resetdrow = True 
    ResetDrow = current_time
    blink_count = 0
    mouth_count = 0
    ResetCount = current_time
    

def analyze_drowsiness(frame, face_landmarks):#ฟังก์ชั่นวิเคราะห์ความง่วง
    global last_mouth_count,eyes_closed_start,last_blink_count,Start_resetdrow,ResetCount,ResetDrow,blink_count, mouth_count, blink_last_open, mouth_last_open
   
    ih, iw, _ = frame.shape
    drowsiness_detected = False
    current_time = time.time()
    
    
    if current_time - ResetCount >= 30:#รีเซ็ทเวลา
        last_blink_count = blink_count
        last_mouth_count = mouth_count
        Start_resetdrow = True 
        ResetDrow = current_time
        blink_count = 0
        mouth_count = 0
        blink_last_open = False
        mouth_last_open = False
        ResetCount = current_time
        
    if Start_resetdrow and (current_time - ResetDrow >= 5):
        last_blink_count = 0
        last_mouth_count = 0
        ResetDrow = current_time

    
    # Eye detection
    left_ear = calculate_ear(LEFT_EYE_POINTS, face_landmarks.landmark, iw, ih)
    right_ear = calculate_ear(RIGHT_EYE_POINTS, face_landmarks.landmark, iw, ih)
    avg_ear = (left_ear + right_ear) / 2
    eyes_closed = avg_ear < EAR_THRESHOLD

    if eyes_closed:
        if eyes_closed_start is None:
            eyes_closed_start = current_time
        elif current_time - eyes_closed_start >= CLOSED_EYE_TIME_THRESHOLD:
            drowsiness_detected = True
    else:
        if not eyes_closed and eyes_closed_start is not None:
            eyes_closed_start = None

    if eyes_closed and not blink_last_open:
        blink_count += 1
        
    blink_last_open = eyes_closed

    # Mouth detection
    upper_lip = face_landmarks.landmark[13]
    lower_lip = face_landmarks.landmark[14]
    distance = calculate_distance(
        (int(upper_lip.x * iw), int(upper_lip.y * ih)),
        (int(lower_lip.x * iw), int(lower_lip.y * ih)),
    )
    normalized_distance = distance / ih
    mouth_open = normalized_distance > MOUTH_OPEN_THRESHOLD

    if mouth_open and not mouth_last_open:
        if eyes_closed:
            mouth_count += 1
    mouth_last_open = mouth_open

    return {
        "drowsiness_detected": drowsiness_detected,
        "blink_count": blink_count,
        "mouth_open_count": mouth_count,
        "blink_last_open": blink_last_open,
        "mouth_last_open": mouth_last_open,
        "start_time": ResetCount,
        "eyes_closed_duration": int(current_time - eyes_closed_start )if eyes_closed_start else 0,
        "continuous_eye_closure": eyes_closed_start is not None and (current_time - eyes_closed_start >= CLOSED_EYE_TIME_THRESHOLD)
    }

#=============================================================================================================
@app.route('/detect_face', methods=['POST'])
def detect_face():
    try:
        if 'image' in request.files:
            file = request.files['image']
            img_bytes = file.read()
            image = Image.open(io.BytesIO(img_bytes))
        elif 'image' in request.json:
            base64_image = request.json['image']
            img_bytes = base64.b64decode(base64_image)
            image = Image.open(io.BytesIO(img_bytes))
        else:
            return jsonify({"error": "No image received"}), 400

        frame = np.array(image)
        frame = cv2.flip(frame, 1)
        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

        results = face_detection.process(rgb_frame)

        response_data = {
            "faces_detected": 0,
            "face_details": []
        }

        if results.detections:
            response_data["faces_detected"] = len(results.detections)
            
            for detection in results.detections:

                bbox = detection.location_data.relative_bounding_box
                h, w, _ = frame.shape
                
                face_details = {
                    "confidence": float(detection.score[0]),
                    "bbox": {
                        "x": float(bbox.xmin * w),
                        "y": float(bbox.ymin * h),
                        "width": float(bbox.width * w),
                        "height": float(bbox.height * h)
                    }
                }
                response_data["face_details"].append(face_details)

                # วาดกรอบใบหน้า
                mp_drawing.draw_detection(frame, detection)

            # แปลงภาพกลับเป็น BGR เพื่อบันทึก
            result_image = cv2.cvtColor(frame, cv2.COLOR_RGB2BGR)

            # เข้ารหัสภาพ
            _, img_encoded = cv2.imencode('.jpg', result_image)
            img_bytes = img_encoded.tobytes()

            # ส่งทั้งภาพและข้อมูลการตรวจจับ
            return jsonify({
                "image": base64.b64encode(img_bytes).decode('utf-8'),
                "detection_results": response_data
            })
        else:
            return jsonify({
                "image": None,
                "detection_results": response_data
            }), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500

##----------------------------------------------------------------------------------------------------------

@app.route('/process-video', methods=['POST'])
def process_video():
    try:
        data = request.json

        # ตรวจสอบว่าในข้อมูลมี 'frames' หรือไม่
        if 'frames' not in data:
            return jsonify({"error": "No frames received"}), 400

        processed_frames = []

        # ประมวลผลทุกเฟรมที่ได้รับ
        for base64_frame in data['frames']:
            img_bytes = base64.b64decode(base64_frame)
            image = Image.open(io.BytesIO(img_bytes))
            frame = np.array(image)
            rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

            # ใช้ face_detection เพื่อตรวจจับใบหน้า
            results = face_detection.process(rgb_frame)

            frame_data = {
                "faces_detected": 0,
                "alarm": False,
                "face_details": [],
                "eye_status": []
            }

            if results.detections:
                frame_data["faces_detected"] = len(results.detections)
                face_mesh_results = facemesh.process(rgb_frame)

                if face_mesh_results.multi_face_landmarks:
                    for face_landmarks in face_mesh_results.multi_face_landmarks:
                        mouth_points = get_mouth_points(face_landmarks)
                        print("Mouth points being sent to Flutter:", mouth_points)
                        eye_points = get_eye_points(face_landmarks)
                        analysis = analyze_drowsiness(frame, face_landmarks)

                        for detection in results.detections:
                            bbox = detection.location_data.relative_bounding_box
                            h, w, _ = frame.shape

                            face_details = {
                                "confidence": float(detection.score[0]),
                                "bbox": {
                                    "x": float(bbox.xmin * w),
                                    "y": float(bbox.ymin * h),
                                    "width": float(bbox.width * w),
                                    "height": float(bbox.height * h)
                                },
                                "amouth_points": mouth_points,
                                "eye_points": eye_points,
                            }
                            frame_data["face_details"].append(face_details)

                            if analysis["drowsiness_detected"]:
                                frame_data["alarm"] = True
                                frame_data["eye_status"].append({
                                    "blink_count": analysis["blink_count"],
                                    "mouth_open_count": analysis["mouth_open_count"],
                                    "eyes_closed_duration": analysis["eyes_closed_duration"],
                                    "continuous_eye_closure": analysis["continuous_eye_closure"]
                                })

                        frame_data["last_blink_count"] = last_blink_count
                        frame_data["last_mouth_count"] = last_mouth_count
                        frame_data["blink_count"] = analysis["blink_count"]
                        frame_data["mouth_open_count"] = analysis["mouth_open_count"]
                        frame_data["eyes_closed_duration"] = analysis["eyes_closed_duration"]

            processed_frames.append(frame_data)

        return jsonify({"processed_frame": processed_frames})

    except Exception as e:
        return jsonify({"error": str(e)}), 500



@app.route('/process-faces-only', methods=['POST'])
def process_faces_only():
    try:
        data = request.json

        if 'frames' not in data:
            return jsonify({"error": "No frames received"}), 400

        processed_frames = []

        for base64_frame in data['frames']:
            img_bytes = base64.b64decode(base64_frame)
            image = Image.open(io.BytesIO(img_bytes))
            frame = np.array(image)
            rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

            # ใช้ face_detection เพื่อตรวจจับใบหน้า
            results = face_detection.process(rgb_frame)

            frame_data = {
                "faces_detected": 0,
                "face_details": []
            }

            if results.detections:
                frame_data["faces_detected"] = len(results.detections)

                for detection in results.detections:
                    bbox = detection.location_data.relative_bounding_box
                    h, w, _ = frame.shape

                    face_details = {
                        "confidence": float(detection.score[0]),
                        "bbox": {
                            "x": float(bbox.xmin * w),
                            "y": float(bbox.ymin * h),
                            "width": float(bbox.width * w),
                            "height": float(bbox.height * h)
                        }
                    }
                    frame_data["face_details"].append(face_details)

            processed_frames.append(frame_data)

        return jsonify({
            "processed_frame": processed_frames
        })

    except Exception as e:
        return jsonify({"error": str(e)}), 500


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)