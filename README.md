# Video Creation Script - India's World Cup Victory

A Python script to create a celebratory video about India's World Cup victory using MoviePy.

## Installation

Install the required dependencies:

```bash
pip install -r requirements.txt
```

**Note:** MoviePy requires FFmpeg to be installed on your system:
- **Linux**: `sudo apt-get install ffmpeg` (Ubuntu/Debian) or `sudo yum install ffmpeg` (CentOS/RHEL)
- **macOS**: `brew install ffmpeg`
- **Windows**: Download from https://ffmpeg.org/download.html

## Usage

### Basic Usage (Text-only video)

Create a simple text-based video:

```bash
python create_video.py
```

This will create `india_world_cup_victory.mp4` with celebratory text slides.

### Custom Output Path

```bash
python create_video.py -o my_video.mp4
```

### With Images

If you have images to include:

```bash
python create_video.py -i image1.jpg image2.jpg image3.jpg -o output.mp4
```

### Custom Duration

Change the duration per slide/image:

```bash
python create_video.py -d 5  # 5 seconds per slide
```

### Custom FPS

Set frames per second:

```bash
python create_video.py -f 30  # 30 fps
```

## Features

- Text overlays with Indian flag colors (saffron, white, green)
- Fade in/out transitions
- Support for image inputs
- Customizable duration and FPS
- High-quality video output (H.264 codec)

## Example

```bash
# Create a basic video
python create_video.py

# Create video with custom settings
python create_video.py -o victory.mp4 -d 4 -f 30

# Create video with images
python create_video.py -i photo1.jpg photo2.jpg -o celebration.mp4
```

## Output

The script generates an MP4 video file with:
- Title slide: "INDIA'S WORLD CUP VICTORY"
- Celebration slide: "🏆 CHAMPIONS 🏆"
- Victory message
- Key moments highlights
- Final message: "Jai Hind! 🇮🇳"

All slides use Indian flag colors and include smooth fade transitions.
