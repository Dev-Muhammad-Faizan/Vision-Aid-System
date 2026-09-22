from flask import Flask, jsonify, request, Response
import threading
import importlib
import time

# Import the detection module
detect_minimal = importlib.import_module("detect-minimal")
run = detect_minimal.run
CONFIG = detect_minimal.CONFIG
speak = detect_minimal.speak

app = Flask(__name__)

# ---------------------------------------------------------------
# Global frame buffer — updated by the detection thread,
# read by the /video_feed stream.  Only ONE camera thread ever runs.
# ---------------------------------------------------------------
_latest_frame = None        # bytes of the latest MJPEG frame
_frame_lock   = threading.Lock()
_camera_thread = None

def _detection_loop():
    """
    Runs YOLO continuously, writing every encoded frame into _latest_frame.
    This is the ONLY place the webcam is opened.
    """
    global _latest_frame
    CONFIG["IS_RUNNING"] = True
    try:
        for frame in run(weights='yolov5s.pt', source='0', conf_thres=0.50):
            if not CONFIG["IS_RUNNING"]:
                break
            with _frame_lock:
                _latest_frame = frame   # caretaker view reads this
    finally:
        CONFIG["IS_RUNNING"] = False
        with _frame_lock:
            _latest_frame = None
        print("Camera released.")

def _start_detection():
    """Start the detection thread if not already running."""
    global _camera_thread
    if _camera_thread and _camera_thread.is_alive():
        return False   # already running
    _camera_thread = threading.Thread(target=_detection_loop, daemon=True)
    _camera_thread.start()
    return True

# ---------------------------------------------------------------
# API Endpoints
# ---------------------------------------------------------------

@app.route('/status', methods=['GET'])
def get_status():
    return jsonify({
        "status": "online",
        "camera_active": CONFIG["IS_RUNNING"],
        "config": CONFIG
    }), 200


@app.route('/start', methods=['POST'])
def start_camera():
    """
    Called by 'Headless Run' button.
    Starts the camera + detection.  Stream is always available via /video_feed.
    """
    if CONFIG["IS_RUNNING"]:
        return jsonify({"message": "Detection already running"}), 400
    started = _start_detection()
    if started:
        return jsonify({"message": "Detection started"}), 200
    return jsonify({"message": "Failed to start"}), 500


@app.route('/stop', methods=['POST'])
def stop_camera():
    """
    Stops detection and releases the camera.
    Waits up to 3 s for the thread to exit.
    """
    CONFIG["IS_RUNNING"] = False
    if _camera_thread:
        _camera_thread.join(timeout=3)
    return jsonify({"message": "Detection stopped"}), 200


@app.route('/video_feed')
def video_feed():
    """
    Caretaker live view — pure MJPEG stream.
    Just reads _latest_frame; does NOT touch the camera.
    If detection is not running, returns a 503 so the app can show a message.
    """
    if not CONFIG["IS_RUNNING"]:
        return jsonify({"error": "Detection not running. Press Headless Run first."}), 503

    def generate():
        while CONFIG["IS_RUNNING"]:
            with _frame_lock:
                frame = _latest_frame
            if frame:
                yield frame
            else:
                time.sleep(0.03)

    return Response(generate(), mimetype='multipart/x-mixed-replace; boundary=frame')


@app.route('/speak', methods=['POST'])
def trigger_speech():
    data = request.json
    message = data.get("text", "")
    if message:
        speak(message)
        return jsonify({"message": f"Speaking: {message}"}), 200
    return jsonify({"error": "No text provided"}), 400


@app.route('/config', methods=['POST'])
def update_config():
    data = request.json

    if "COLOR_ENABLED" in data:
        CONFIG["COLOR_ENABLED"] = bool(data["COLOR_ENABLED"])
        speak("Color detection " + ("enabled" if CONFIG["COLOR_ENABLED"] else "disabled"))

    if "DISTANCE_THRESH_NEAR" in data:
        CONFIG["DISTANCE_THRESH_NEAR"] = float(data["DISTANCE_THRESH_NEAR"])

    if "POSITION_DELAY" in data:
        CONFIG["POSITION_DELAY"] = float(data["POSITION_DELAY"])

    if "LANGUAGE" in data:
        CONFIG["LANGUAGE"] = data["LANGUAGE"]
        speak("Language updated")

    return jsonify({"message": "Config updated", "config": CONFIG}), 200


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, threaded=True)
