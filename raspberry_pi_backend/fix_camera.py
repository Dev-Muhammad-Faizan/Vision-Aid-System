import sys

with open('detect-minimal.py', 'r') as f:
    lines = f.readlines()

new_lines = []
skip = False
for line in lines:
    if 'import cv2' in line:
        new_lines.append(line)
        new_lines.append('try:\n    from picamera2 import Picamera2\nexcept ImportError:\n    Picamera2 = None\n')
        continue
    
    if 'cap = cv2.VideoCapture' in line:
        new_lines.append('    if Picamera2:\n        cap = Picamera2()\n        config = cap.create_video_configuration(main={"format": "RGB888", "size": (640, 480)})\n        cap.configure(config)\n        cap.start()\n    else:\n        cap = cv2.VideoCapture(cam_index)\n')
        skip = False
        continue
    
    if 'ret, frame = cap.read()' in line:
        new_lines.append('            if Picamera2 and isinstance(cap, Picamera2):\n                frame = cap.capture_array()\n                ret = True\n            else:\n                ret, frame = cap.read()\n')
        continue

    new_lines.append(line)

with open('detect-minimal.py', 'w') as f:
    f.writelines(new_lines)
print("Camera code updated to support Picamera2!")
