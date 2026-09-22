import argparse
import time
import subprocess
import torch
import cv2
try:
    from picamera2 import Picamera2
except ImportError:
    Picamera2 = None
import numpy as np
import os
import threading
import queue

from models.common import DetectMultiBackend
from utils.general import check_img_size, non_max_suppression, scale_boxes
from utils.torch_utils import select_device, smart_inference_mode
from ultralytics.utils.plotting import Annotator

# ---------------------- Configuration ----------------------

# Global Config State (can be modified by app.py)
CONFIG = {
    "POSITION_DELAY": 3.0,
    "DISTANCE_THRESH_NEAR": 0.35,
    "DISTANCE_THRESH_FAR": 0.15,
    "NO_COLOR_CLASSES": ["person"],
    "COLOR_ENABLED": False,
    "IS_RUNNING": False,
    "FILTER_CLASSES": [],      # Empty means detect all
    "LANGUAGE": "English",    # 'English' or 'Urdu'
    "MIN_BOX_AREA_PCT": 0.03, # Bounding box must be ≥3% of frame area to count
    "STABILITY_FRAMES": 2     # Object must appear this many frames in a row before speaking
}

# --- Urdu Translations ---
URDU_MAP = {
    "person": "Aadmi", "car": "Gaari", "motorcycle": "Motorcycle", "bus": "Bus",
    "truck": "Truck", "bicycle": "Cycle", "cell phone": "Mobile", "door": "Darwaza",
    "chair": "Kursi", "desk": "Mez", "table": "Mez", "bottle": "Bottle", "cup": "Cup",
    # positions
    "on the left": "Bayein taraf",
    "in the center": "Samnay",
    "on the right": "Dayein taraf",
    # distances
    "near": "Qareeb",
    "medium": "Kuch faslay par",
    "far": "Door",
    # colors
    "red": "Laal", "blue": "Neela", "green": "Sabz", 
    "yellow": "Peela", "white": "Sufaid", "black": "Kaala",
}

# ── Class Name Remapping ─────────────────────────────────────────────────────
# YOLOv5/COCO lacks many items (pen, pencil, etc.).
# This gives honest display names for known mismatched labels.
CLASS_REMAP = {
    "toothbrush": "pen or small object",
    "knife":      "sharp object",
    "scissors":   "scissors",
    "remote":     "remote or phone",
    "hair drier": "handheld device",
    "teddy bear": "soft toy",
}

# ---------------------- TTS Worker ----------------------
# Using subprocess TTS — avoids all pyttsx3 COM threading issues on Windows.
# On Windows: PowerShell .NET SpeechSynthesizer (human voice, always works)
# On Linux/Pi: espeak-ng
tts_queue = queue.Queue()

def _speak_subprocess(msg: str):
    """Fires a TTS subprocess and waits for it to finish."""
    # Sanitize the message to avoid shell injection
    safe_msg = msg.replace('"', '').replace("'", "").replace('\n', ' ')
    try:
        if os.name == 'nt':  # Windows
            ps_cmd = (
                "Add-Type -AssemblyName System.Speech; "
                f"$s = New-Object System.Speech.Synthesis.SpeechSynthesizer; "
                f"$s.Rate = 1; "
                f"$s.Speak('{safe_msg}')"
            )
            subprocess.run(
                ["powershell", "-NoProfile", "-NonInteractive", "-Command", ps_cmd],
                timeout=15, check=False,
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
            )
        else:  # Linux / Raspberry Pi
            subprocess.run(
                ["espeak-ng", "-s", "145", safe_msg],
                timeout=15, check=False,
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
            )
    except Exception as e:
        print(f"TTS Error: {e}")

def tts_worker():
    while True:
        task = tts_queue.get()
        if task is None:
            break
        _lang, msg = task
        _speak_subprocess(msg)
        tts_queue.task_done()

threading.Thread(target=tts_worker, daemon=True).start()

def speak(msg):
    """Queue a speech message. Drops new messages if one is already being spoken."""
    if tts_queue.empty():
        tts_queue.put((CONFIG["LANGUAGE"], msg))


def format_announcement(color, class_name, distance, position):
    """Formats the sentence according to the grammatical rules of the selected language"""
    if CONFIG["LANGUAGE"] == "Urdu":
        ur_color = f"{URDU_MAP.get(color, color)} " if color else ""
        ur_cls = URDU_MAP.get(class_name, class_name)
        ur_dist = URDU_MAP.get(distance, distance)
        ur_pos = URDU_MAP.get(position, position)
        
        # Grammatical order: "Samnay qareeb laal gaari hai"
        return f"{ur_pos} {ur_dist} {ur_color}{ur_cls} hai"
    else:
        # Default English
        en_color = f"{color} " if color else ""
        return f"{en_color}{class_name} is {distance} {position}"

# ---------------------- Color Detection Logic ----------------------
def get_color(img_crop):
    """Detects the dominant color in the center of a cropped image using HSV ranges."""
    if img_crop.size == 0:
        return ""
    
    # Crop the center 50% of the bounding box to avoid background pixels
    h, w = img_crop.shape[:2]
    ch, cw = int(h * 0.5), int(w * 0.5)
    ymin, ymax = (h - ch) // 2, (h + ch) // 2
    xmin, xmax = (w - cw) // 2, (w + cw) // 2
    
    center_crop = img_crop[ymin:ymax, xmin:xmax]
    if center_crop.size == 0:
        center_crop = img_crop
        
    hsv = cv2.cvtColor(center_crop, cv2.COLOR_BGR2HSV)
    
    # Define color ranges (H, S, V)
    colors = {
        "red": ([0, 50, 50], [10, 255, 255]),
        "blue": ([100, 50, 50], [130, 255, 255]),
        "green": ([36, 50, 50], [89, 255, 255]),
        "yellow": ([25, 50, 50], [35, 255, 255]),
        "white": ([0, 0, 200], [180, 30, 255]),
        "black": ([0, 0, 0], [180, 255, 30]),
    }
    
    max_pixels = 0
    detected_color = ""
    
    for name, (lower, upper) in colors.items():
        mask = cv2.inRange(hsv, np.array(lower), np.array(upper))
        count = cv2.countNonZero(mask)
        if count > max_pixels:
            max_pixels = count
            detected_color = name
            
    return detected_color

# ---------------------- Distance Detection ----------------------
def estimate_distance(xyxy, frame_width):
    # TODO: In the future, integrate the UL53DKL TOF sensor or Ultrasonic sensor reading here
    x1, y1, x2, y2 = map(int, xyxy)
    box_width = x2 - x1
    fraction = box_width / frame_width
    if fraction >= CONFIG["DISTANCE_THRESH_NEAR"]:
        return "near"
    elif fraction <= CONFIG["DISTANCE_THRESH_FAR"]:
        return "far"
    else:
        return "medium"

# ---------------------- Main Detection ----------------------
@smart_inference_mode()
def run(weights='yolov5s.pt', source='0', imgsz=640, conf_thres=0.50,
        iou_thres=0.45, device='', line_thickness=2, show_window=True):
    """
    Generator function that runs YOLOv5 with direct cv2.VideoCapture.
    Yields MJPEG frames for Flask streaming.
    Shows a local window on the server so the wearer can see the feed.
    """
    # Auto-disable show_window if no display is detected (e.g. headless Raspberry Pi)
    if show_window and os.name != 'nt' and not os.environ.get('DISPLAY'):
        print("No display detected. Disabling local window (Headless Mode).")
        show_window = False

    CONFIG["IS_RUNNING"] = True
    speak("Object Detection started.")

    # ── Load Model ──────────────────────────────────────────────────────────
    dev = select_device(device)
    model = DetectMultiBackend(weights, device=dev)
    stride, names, pt = model.stride, model.names, model.pt
    imgsz_hw = check_img_size((imgsz, imgsz), s=stride)
    model.warmup(imgsz=(1, 3, *imgsz_hw))

    # ── Open Camera with direct cv2.VideoCapture ─────────────────────────────
    cam_index = int(source) if str(source).isnumeric() else source
    if Picamera2:
        cap = Picamera2()
        config = cap.create_video_configuration(main={"format": "RGB888", "size": (640, 480)})
        cap.configure(config)
        cap.start()
    else:
        cap = cv2.VideoCapture(cam_index)
    if not (Picamera2 and isinstance(cap, Picamera2)):
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
    if not (Picamera2 and isinstance(cap, Picamera2)):
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)

    # Picamera2 is always opened if it started
    if not (Picamera2 and isinstance(cap, Picamera2)) and not cap.isOpened():
        speak("Camera could not be opened.")
        CONFIG["IS_RUNNING"] = False
        return

    last_spoken = {}
    stability_counter = {}  # tracks consecutive-frame count per class

    try:
        while CONFIG["IS_RUNNING"]:
            if Picamera2 and isinstance(cap, Picamera2):
                frame = cap.capture_array()
                ret = True
            else:
                ret, frame = cap.read()
            if not ret:
                print("Camera: failed to grab frame, retrying...")
                time.sleep(0.05)
                continue

            im0 = frame.copy()
            h, w, _ = im0.shape

            # ── Pre-process frame for model ──────────────────────────────────
            img = cv2.resize(im0, imgsz_hw)
            img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
            img = img.transpose(2, 0, 1)               # HWC → CHW
            img = np.ascontiguousarray(img)
            img_tensor = torch.from_numpy(img).to(dev).float() / 255.0
            if img_tensor.ndim == 3:
                img_tensor = img_tensor[None]           # add batch dim

            # ── Inference ────────────────────────────────────────────────────
            pred = model(img_tensor)
            pred = non_max_suppression(pred, conf_thres, iou_thres)

            # ── Draw annotations ─────────────────────────────────────────────
            annotator = Annotator(im0, line_width=line_thickness, example=str(names))
            speak_list = []

            for det in pred:
                if len(det):
                    det[:, :4] = scale_boxes(img_tensor.shape[2:], det[:, :4], im0.shape).round()

                    for *xyxy, conf, cls in reversed(det):
                        c = int(cls)
                        raw_class   = names[c]
                        # Remap confusing COCO labels to honest names
                        class_name  = CLASS_REMAP.get(raw_class, raw_class)
                        current_time = time.time()

                        # ── Size filter: ignore tiny background detections ──
                        x1, y1, x2, y2 = map(int, xyxy)
                        box_area = (x2 - x1) * (y2 - y1)
                        frame_area = w * h
                        if box_area < CONFIG["MIN_BOX_AREA_PCT"] * frame_area:
                            stability_counter.pop(class_name, None)
                            continue

                        # Filter by class whitelist
                        if CONFIG["FILTER_CLASSES"] and class_name not in CONFIG["FILTER_CLASSES"]:
                            continue

                        # ── Stability: only speak after N consecutive frames ──
                        stability_counter[class_name] = stability_counter.get(class_name, 0) + 1
                        if stability_counter[class_name] < CONFIG["STABILITY_FRAMES"]:
                            annotator.box_label(xyxy, f"{class_name}? {conf:.2f}", color=(128, 128, 128))
                            continue

                        # Position
                        obj_cx = (xyxy[0] + xyxy[2]) / 2
                        if obj_cx < w / 3:
                            position = "on the left"
                        elif obj_cx < 2 * w / 3:
                            position = "in the center"
                        else:
                            position = "on the right"

                        distance = estimate_distance(xyxy, w)

                        # Color
                        detected_color = ""
                        if CONFIG["COLOR_ENABLED"] and class_name not in CONFIG["NO_COLOR_CLASSES"]:
                            x1, y1 = max(0, int(xyxy[0])), max(0, int(xyxy[1]))
                            x2, y2 = min(w, int(xyxy[2])), min(h, int(xyxy[3]))
                            crop = im0[y1:y2, x1:x2]
                            detected_color = get_color(crop)

                        full_desc = f"{detected_color} {class_name}".strip() if detected_color else class_name

                        # TTS throttle
                        unique_id = full_desc
                        if (current_time - last_spoken.get(unique_id, 0)) > CONFIG["POSITION_DELAY"]:
                            last_spoken[unique_id] = current_time
                            speak_list.append(
                                format_announcement(detected_color, class_name, distance, position)
                            )

                        # Draw
                        annotator.box_label(xyxy, f"{full_desc} {conf:.2f}", color=(0, 255, 0))

            if speak_list:
                speak(", ".join(set(speak_list)))

            # ── Draw zone lines ───────────────────────────────────────────────
            cv2.line(im0, (w // 3, 0), (w // 3, h), (255, 255, 255), 1)
            cv2.line(im0, (2 * w // 3, 0), (2 * w // 3, h), (255, 255, 255), 1)
            status = f"Color: {'ON' if CONFIG['COLOR_ENABLED'] else 'OFF'}  Lang: {CONFIG['LANGUAGE']}"
            cv2.putText(im0, status, (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.65, (0, 200, 255), 2)

            # ── Show window on the server (laptop / Pi) ───────────────────────
            if show_window:
                cv2.imshow("Vision Assistant", im0)
                key = cv2.waitKey(1) & 0xFF
                if key == ord('q'):
                    CONFIG["IS_RUNNING"] = False
                    break
                elif key in [ord('l'), ord('L')]:
                    CONFIG["COLOR_ENABLED"] = not CONFIG["COLOR_ENABLED"]
                    state = "enabled" if CONFIG["COLOR_ENABLED"] else "disabled"
                    speak(f"Color detection {state}")

            # ── Yield MJPEG frame for Flask ───────────────────────────────────
            ret2, buffer = cv2.imencode('.jpg', im0)
            if ret2:
                yield (b'--frame\r\n'
                       b'Content-Type: image/jpeg\r\n\r\n' + buffer.tobytes() + b'\r\n')

    finally:
        cap.release()
        CONFIG["IS_RUNNING"] = False
        if show_window:
            cv2.destroyAllWindows()
        print("Camera released cleanly.")

    speak("Camera deactivated.")

# ---------------------- Main ----------------------
if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('--weights',    type=str,   default='yolov5s.pt')
    parser.add_argument('--source',     type=str,   default='0')
    parser.add_argument('--imgsz',      type=int,   default=640)
    parser.add_argument('--conf-thres', type=float, default=0.30)
    opt = parser.parse_args()
    # Consume the generator so it actually runs when called directly
    for _ in run(**vars(opt)):
        pass

