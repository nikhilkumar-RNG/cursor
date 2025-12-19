"""
Example: Create a video from a sequence of images
This is useful for creating videos from rendered frames, screenshots, or image sequences.
"""

import cv2
import os
from pathlib import Path

def create_video_from_images(image_folder, output_path='output_from_images.mp4', fps=30):
    """
    Create a video from a sequence of images in a folder.
    
    Args:
        image_folder: Path to folder containing images
        output_path: Path where the video will be saved
        fps: Frames per second
    """
    # Get all image files
    image_extensions = ['.jpg', '.jpeg', '.png', '.bmp']
    images = []
    
    for ext in image_extensions:
        images.extend(Path(image_folder).glob(f'*{ext}'))
        images.extend(Path(image_folder).glob(f'*{ext.upper()}'))
    
    if not images:
        print(f"No images found in {image_folder}")
        return
    
    # Sort images by name
    images = sorted(images)
    print(f"Found {len(images)} images")
    
    # Read first image to get dimensions
    first_image = cv2.imread(str(images[0]))
    if first_image is None:
        print(f"Could not read first image: {images[0]}")
        return
    
    height, width, layers = first_image.shape
    
    # Define codec and create VideoWriter
    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    out = cv2.VideoWriter(output_path, fourcc, fps, (width, height))
    
    # Write all images as frames
    for image_path in images:
        img = cv2.imread(str(image_path))
        if img is not None:
            # Resize if necessary
            if img.shape[:2] != (height, width):
                img = cv2.resize(img, (width, height))
            out.write(img)
        else:
            print(f"Warning: Could not read {image_path}")
    
    # Release everything
    out.release()
    print(f"Video created successfully: {output_path}")

def create_sample_images_for_demo():
    """Create sample images for demonstration."""
    import numpy as np
    
    os.makedirs('sample_images', exist_ok=True)
    
    for i in range(30):
        # Create a simple colored image
        img = np.zeros((480, 640, 3), dtype=np.uint8)
        color_value = int((i / 30) * 255)
        img[:, :] = [color_value, 255 - color_value, 128]
        
        # Add frame number
        cv2.putText(img, f"Frame {i+1}", (50, 50),
                   cv2.FONT_HERSHEY_SIMPLEX, 1, (255, 255, 255), 2)
        
        cv2.imwrite(f'sample_images/frame_{i:03d}.png', img)
    
    print("Sample images created in 'sample_images' folder")

if __name__ == "__main__":
    # Create sample images first
    create_sample_images_for_demo()
    
    # Create video from images
    create_video_from_images('sample_images', 'video_from_images.mp4', fps=10)
