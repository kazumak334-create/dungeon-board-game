#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Slime sprite sheet processor
Extracts 7x2 grid sprites, removes background, and resizes to 48x48
"""
from PIL import Image
import numpy as np
from pathlib import Path

# Configuration
INPUT_PATH = Path(__file__).parent.parent.parent / 'assets' / 'sprites' / 'unit' / 'raw' / 'slime_sheet.png'
OUTPUT_DIR = Path(__file__).parent.parent.parent / 'assets' / 'sprites' / 'unit'
BG_COLOR = (10, 22, 40)  # #0a1628
COLOR_TOLERANCE = 30
TARGET_SIZE = (48, 48)

# Sprite names in order (7x2 grid)
SPRITE_NAMES = [
    # Row 1
    ['slime', 'amoeba', 'jelfix', 'barbzel', 'mudblob', 'plagzel', 'sparkblob'],
    # Row 2
    ['crystel', 'glitzel', 'granob', 'venpool', 'silenzel', 'voidblob', 'kinglob']
]

def remove_background(img_array, bg_color, tolerance):
    """
    Remove background color using flood fill approach
    Returns RGBA array with transparent background
    """
    # Convert to RGBA if needed
    if img_array.shape[2] == 3:
        rgba = np.zeros((*img_array.shape[:2], 4), dtype=np.uint8)
        rgba[:, :, :3] = img_array
        rgba[:, :, 3] = 255
        img_array = rgba

    # Calculate color distance from background
    r, g, b = bg_color
    distance = np.sqrt(
        (img_array[:, :, 0].astype(float) - r) ** 2 +
        (img_array[:, :, 1].astype(float) - g) ** 2 +
        (img_array[:, :, 2].astype(float) - b) ** 2
    )

    # Set alpha to 0 where color is close to background
    mask = distance <= tolerance
    img_array[:, :, 3][mask] = 0

    return img_array

def detect_label_height(img):
    """
    Detect label row height by finding first significant color change
    Assumes labels are at the top with different background
    """
    img_array = np.array(img)
    height = img_array.shape[0]

    # Sample middle column
    mid_col = img_array.shape[1] // 2

    # Find first row with background color
    bg_r, bg_g, bg_b = BG_COLOR
    for y in range(height):
        pixel = img_array[y, mid_col, :3]
        distance = np.sqrt(
            (pixel[0] - bg_r) ** 2 +
            (pixel[1] - bg_g) ** 2 +
            (pixel[2] - bg_b) ** 2
        )
        if distance <= COLOR_TOLERANCE:
            print(f"  Label height detected: {y}px")
            return y

    print("  Warning: Could not detect label height, assuming 0")
    return 0

def extract_sprites(img, rows=2, cols=7, skip_label=True):
    """
    Extract sprites from grid
    Returns list of PIL Images
    """
    width, height = img.size

    # Detect and skip label row
    label_height = 0
    if skip_label:
        label_height = detect_label_height(img)

    # Calculate cell dimensions
    usable_height = height - label_height
    cell_width = width // cols
    cell_height = usable_height // rows

    print(f"  Grid dimensions: {cols}x{rows}")
    print(f"  Cell size: {cell_width}x{cell_height}px")
    print(f"  Label offset: {label_height}px\n")

    sprites = []
    for row in range(rows):
        for col in range(cols):
            x = col * cell_width
            y = label_height + (row * cell_height)

            cell = img.crop((x, y, x + cell_width, y + cell_height))
            sprites.append(cell)

    return sprites

def process_sprite(sprite_img, name):
    """
    Process single sprite: remove background, resize to 48x48
    """
    # Convert to numpy array
    img_array = np.array(sprite_img)

    # Remove background
    rgba_array = remove_background(img_array, BG_COLOR, COLOR_TOLERANCE)

    # Convert back to PIL Image
    processed = Image.fromarray(rgba_array, 'RGBA')

    # Resize to 48x48 using Nearest Neighbor
    resized = processed.resize(TARGET_SIZE, Image.Resampling.NEAREST)

    return resized

def main():
    print("=" * 60)
    print("Slime Sprite Sheet Processor")
    print("=" * 60)
    print()

    # Check input file
    if not INPUT_PATH.exists():
        print(f"ERROR: Input file not found: {INPUT_PATH}")
        print("Please place slime_sheet.png in assets/sprites/units/raw/")
        return

    print(f"Input: {INPUT_PATH}")
    print(f"Output: {OUTPUT_DIR}\n")

    # Load sheet
    print("Loading sprite sheet...")
    sheet = Image.open(INPUT_PATH)
    print(f"  Sheet size: {sheet.size[0]}x{sheet.size[1]}px\n")

    # Extract sprites
    print("Extracting sprites from grid...")
    sprites = extract_sprites(sheet, rows=2, cols=7, skip_label=True)
    print(f"  Extracted {len(sprites)} sprites\n")

    # Create output directory
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # Process and save each sprite
    print("Processing sprites...")
    for idx, sprite in enumerate(sprites):
        row = idx // 7
        col = idx % 7
        name = SPRITE_NAMES[row][col]

        # Process sprite
        processed = process_sprite(sprite, name)

        # Save
        output_path = OUTPUT_DIR / f"{name}.png"
        processed.save(output_path, 'PNG')

        print(f"  [{idx + 1:2d}/14] {name:12s} -> {output_path.name}")

    print()
    print("=" * 60)
    print("Processing complete!")
    print(f"Output: {len(sprites)} sprites saved to {OUTPUT_DIR}")
    print("=" * 60)

if __name__ == '__main__':
    main()
