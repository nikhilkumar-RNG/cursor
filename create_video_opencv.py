"""
Example: Create a video using OpenCV
This script creates a simple animated video with colored frames.
"""

import cv2
import numpy as np

def create_simple_video(output_path='output_video.mp4', duration_seconds=5, fps=30):
    """
    Create a simple animated video with changing colors.
    
    Args:
        output_path: Path where the video will be saved
        duration_seconds: Length of the video in seconds
        fps: Frames per second
    """
    # Video properties
    width, height = 640, 480
    total_frames = duration_seconds * fps
    
    # Define codec and create VideoWriter
    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    out = cv2.VideoWriter(output_path, fourcc, fps, (width, height))
    
    for frame_num in range(total_frames):
        # Create a frame with changing colors
        # Cycle through colors based on frame number
        hue = int((frame_num / total_frames) * 180)  # HSV hue value
        
        # Create colored frame
        frame = np.zeros((height, width, 3), dtype=np.uint8)
        frame[:, :] = [hue, 255, 255]  # HSV color
        frame = cv2.cvtColor(frame, cv2.COLOR_HSV2BGR)
        
        # Add some text
        text = f"Frame {frame_num + 1}/{total_frames}"
        cv2.putText(frame, text, (50, 50), 
                   cv2.FONT_HERSHEY_SIMPLEX, 1, (255, 255, 255), 2)
        
        # Write frame
        out.write(frame)
    
    # Release everything
    out.release()
    print(f"Video created successfully: {output_path}")

if __name__ == "__main__":
    create_simple_video('my_video.mp4', duration_seconds=5, fps=30)
