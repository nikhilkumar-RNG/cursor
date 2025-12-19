# Video Creation Examples

This repository contains examples of how to create videos programmatically using Python.

## Installation

Install the required dependencies:

```bash
pip install -r requirements.txt
```

## Examples

### 1. Simple Video with OpenCV (`create_video_opencv.py`)
Creates a simple animated video with changing colors.

```bash
python create_video_opencv.py
```

### 2. Video with MoviePy (`create_video_moviepy.py`)
Creates a video with animated background and text overlays.

```bash
python create_video_moviepy.py
```

### 3. Video from Images (`create_video_from_images.py`)
Creates a video from a sequence of images in a folder.

```bash
python create_video_from_images.py
```

## Quick Start

The simplest way to create a video:

```python
import cv2
import numpy as np

# Create a video writer
fourcc = cv2.VideoWriter_fourcc(*'mp4v')
out = cv2.VideoWriter('output.mp4', fourcc, 30.0, (640, 480))

# Write frames
for i in range(150):  # 5 seconds at 30 fps
    frame = np.random.randint(0, 255, (480, 640, 3), dtype=np.uint8)
    out.write(frame)

out.release()
```

## Common Use Cases

- **Animation**: Create animated visualizations
- **Time-lapse**: Convert image sequences to videos
- **Data Visualization**: Create videos from charts/graphs
- **Video Editing**: Combine clips, add effects
- **Screen Recording**: Process screenshots into videos
