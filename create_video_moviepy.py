"""
Example: Create a video using MoviePy
This script creates a video with text animation and effects.
"""

from moviepy.editor import VideoClip, TextClip, CompositeVideoClip
import numpy as np

def make_frame(t):
    """
    Generate a frame at time t.
    This creates an animated background with moving colors.
    """
    # Create a frame with animated gradient
    frame = np.zeros((480, 640, 3), dtype=np.uint8)
    
    # Animate colors based on time
    r = int(128 + 127 * np.sin(t * 2))
    g = int(128 + 127 * np.sin(t * 2 + 2))
    b = int(128 + 127 * np.sin(t * 2 + 4))
    
    frame[:, :] = [r, g, b]
    return frame

def create_video_with_moviepy(output_path='output_moviepy.mp4', duration=5):
    """
    Create a video with animated background and text using MoviePy.
    
    Args:
        output_path: Path where the video will be saved
        duration: Length of the video in seconds
    """
    # Create animated background clip
    background = VideoClip(make_frame, duration=duration)
    
    # Create text clip
    txt_clip = TextClip("Hello, World!", 
                       fontsize=70, 
                       color='white',
                       font='Arial-Bold')
    txt_clip = txt_clip.set_position('center').set_duration(duration)
    
    # Composite the clips
    video = CompositeVideoClip([background, txt_clip])
    
    # Write video file
    video.write_videofile(output_path, fps=24, codec='libx264')
    print(f"Video created successfully: {output_path}")

if __name__ == "__main__":
    create_video_with_moviepy('my_moviepy_video.mp4', duration=5)
