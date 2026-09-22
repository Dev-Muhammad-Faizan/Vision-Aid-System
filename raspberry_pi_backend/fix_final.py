with open('detect-minimal.py', 'r') as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    if 'cap.set(cv2.CAP_PROP_FRAME_WIDTH' in line or 'cap.set(cv2.CAP_PROP_FRAME_HEIGHT' in line:
        new_lines.append("    if not (Picamera2 and isinstance(cap, Picamera2)):\n")
        new_lines.append("    " + line)
    else:
        new_lines.append(line)

with open('detect-minimal.py', 'w') as f:
    f.writelines(new_lines)
print("Final camera fix applied!")
