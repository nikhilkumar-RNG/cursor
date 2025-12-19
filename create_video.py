#!/usr/bin/env python3
"""
Video Creation Script - India's World Cup Victory
Creates a video with text overlays, images, and effects
"""

from moviepy.editor import (
    VideoFileClip, ImageClip, TextClip, CompositeVideoClip,
    concatenate_videoclips, ColorClip, AudioFileClip
)
from moviepy.video.fx import resize, fadein, fadeout
from PIL import Image, ImageDraw, ImageFont
import os
from pathlib import Path


def create_text_clip(text, duration=3, fontsize=60, color='white', 
                     position=('center', 'center'), bg_color=None):
    """Create a text clip with styling"""
    txt_clip = TextClip(
        text,
        fontsize=fontsize,
        color=color,
        font='Arial-Bold',
        method='caption',
        size=(1280, None),
        align='center'
    ).set_duration(duration).set_position(position)
    
    if bg_color:
        bg = ColorClip(size=(1280, txt_clip.h + 40), color=bg_color, duration=duration)
        txt_clip = CompositeVideoClip([bg, txt_clip.set_position('center')])
    
    return txt_clip


def create_india_world_cup_video(output_path='india_world_cup_victory.mp4', 
                                  duration_per_slide=3, fps=24):
    """
    Create a video celebrating India's World Cup victory
    """
    clips = []
    
    # Title slide
    title = create_text_clip(
        "INDIA'S WORLD CUP VICTORY",
        duration=duration_per_slide,
        fontsize=80,
        color='#FF9933',  # Saffron
        bg_color='#000080'  # Navy blue
    )
    clips.append(title)
    
    # Slide 2 - Celebration
    celebration = create_text_clip(
        "🏆 CHAMPIONS 🏆",
        duration=duration_per_slide,
        fontsize=90,
        color='#FFD700'  # Gold
    )
    clips.append(celebration)
    
    # Slide 3 - Victory message
    victory = create_text_clip(
        "A Historic Victory\nThat United a Nation",
        duration=duration_per_slide,
        fontsize=60,
        color='white'
    )
    clips.append(victory)
    
    # Slide 4 - Key moments
    moments = create_text_clip(
        "Key Moments:\n• Outstanding Performance\n• Team Unity\n• National Pride",
        duration=duration_per_slide * 1.5,
        fontsize=50,
        color='#FF9933'
    )
    clips.append(moments)
    
    # Slide 5 - Final message
    final = create_text_clip(
        "Jai Hind! 🇮🇳",
        duration=duration_per_slide,
        fontsize=100,
        color='#FF9933',
        bg_color='#000080'
    )
    clips.append(final)
    
    # Add fade transitions
    clips_with_fade = []
    for i, clip in enumerate(clips):
        if i == 0:
            clip = clip.fadein(0.5)
        if i == len(clips) - 1:
            clip = clip.fadeout(0.5)
        else:
            clip = clip.fadeout(0.3)
        clips_with_fade.append(clip)
    
    # Create background (saffron, white, green tricolor effect)
    bg_clip = ColorClip(size=(1280, 720), color=(0, 0, 0), duration=sum(c.duration for c in clips))
    
    # Composite all clips
    final_video = CompositeVideoClip(
        [bg_clip] + clips_with_fade,
        size=(1280, 720)
    ).set_fps(fps)
    
    # Write the video file
    print(f"Creating video: {output_path}")
    final_video.write_videofile(
        output_path,
        fps=fps,
        codec='libx264',
        audio_codec='aac',
        preset='medium',
        bitrate='8000k'
    )
    
    print(f"Video created successfully: {output_path}")
    return output_path


def create_video_with_images(image_paths=None, output_path='india_world_cup_victory.mp4',
                             duration_per_image=3, fps=24):
    """
    Create a video using images (if provided)
    """
    clips = []
    
    # If images are provided, use them
    if image_paths and all(os.path.exists(img) for img in image_paths):
        for img_path in image_paths:
            img_clip = ImageClip(img_path).set_duration(duration_per_image)
            img_clip = img_clip.resize(height=720)
            clips.append(img_clip)
    else:
        # Otherwise, create text-based video
        return create_india_world_cup_video(output_path, duration_per_image, fps)
    
    # Add text overlays
    text_overlays = [
        ("INDIA'S WORLD CUP VICTORY", 2),
        ("🏆 CHAMPIONS 🏆", 2),
        ("Jai Hind! 🇮🇳", 2)
    ]
    
    final_clips = []
    for i, clip in enumerate(clips):
        if i < len(text_overlays):
            text, text_duration = text_overlays[i]
            txt = create_text_clip(text, duration=min(text_duration, clip.duration), 
                                  fontsize=60, color='white')
            txt = txt.set_position(('center', 'bottom')).set_start(0)
            clip = CompositeVideoClip([clip, txt])
        final_clips.append(clip)
    
    # Concatenate all clips
    final_video = concatenate_videoclips(final_clips, method="compose")
    final_video = final_video.set_fps(fps)
    
    print(f"Creating video with images: {output_path}")
    final_video.write_videofile(
        output_path,
        fps=fps,
        codec='libx264',
        audio_codec='aac',
        preset='medium',
        bitrate='8000k'
    )
    
    print(f"Video created successfully: {output_path}")
    return output_path


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='Create a video about India\'s World Cup victory')
    parser.add_argument('-o', '--output', default='india_world_cup_victory.mp4',
                       help='Output video file path')
    parser.add_argument('-i', '--images', nargs='+', help='Image paths to include in video')
    parser.add_argument('-d', '--duration', type=float, default=3,
                       help='Duration per slide/image in seconds')
    parser.add_argument('-f', '--fps', type=int, default=24, help='Frames per second')
    
    args = parser.parse_args()
    
    if args.images:
        create_video_with_images(args.images, args.output, args.duration, args.fps)
    else:
        create_india_world_cup_video(args.output, args.duration, args.fps)
