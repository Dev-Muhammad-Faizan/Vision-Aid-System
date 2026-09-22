with open('detect-minimal.py', 'r') as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    # Fix cap.isOpened()
    if 'if not cap.isOpened():' in line:
        new_lines.append("    # Picamera2 is always opened if it started\n")
        new_lines.append("    if not (Picamera2 and isinstance(cap, Picamera2)) and not cap.isOpened():\n")
    else:
        new_lines.append(line)

with open('detect-minimal.py', 'w') as f:
    f.writelines(new_lines)
print("IsOpened check fixed!")
