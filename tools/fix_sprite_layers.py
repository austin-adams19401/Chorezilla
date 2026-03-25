"""
Fix sprite sheet layers for two-layer mascot rendering.

For animations with existing detail splits (in 'not pixel perfect/'):
  - If dimensions match the original: use existing details, regenerate body
  - If dimensions differ: fall back to auto-split from original

For animations without splits (wiping, grrr, walking):
  - Auto-splits by color: green-dominant pixels become body, rest become details
  - Then regenerates body with the subtraction formula for zero gaps

Outputs all pairs to sprite-sheets/{name}_body.png and {name}_details.png.
"""

import os
import numpy as np
from PIL import Image

MASCOT_DIR = os.path.join(os.path.dirname(__file__), '..', 'assets', 'mascot')
SPRITE_DIR = os.path.join(MASCOT_DIR, 'sprite-sheets')
NPP_DIR = os.path.join(MASCOT_DIR, 'not pixel perfect')

# Skip these - they are layer files, not combined animation sheets
SKIP_FILES = {'walk_body', 'walk_details'}


def dilate(mask):
    """Dilate a boolean mask by 1 pixel in 4 directions."""
    result = mask.copy()
    if mask.shape[0] > 1:
        result[1:] |= mask[:-1]
        result[:-1] |= mask[1:]
    if mask.shape[1] > 1:
        result[:, 1:] |= mask[:, :-1]
        result[:, :-1] |= mask[:, 1:]
    return result


def count_gaps(body_arr, details_arr):
    """Count gap pixels between body and details layers."""
    body_mask = body_arr[:, :, 3] > 0
    details_mask = details_arr[:, :, 3] > 0
    combined = body_mask | details_mask
    body_d = dilate(body_mask)
    details_d = dilate(details_mask)
    return int((~combined & body_d & details_d).sum())


def regenerate_body(original_arr, details_arr):
    """Generate body layer: white pixels with alpha = clamp(orig - details, 0, 255)."""
    body = np.zeros_like(original_arr)
    body[:, :, 0] = 255  # R
    body[:, :, 1] = 255  # G
    body[:, :, 2] = 255  # B
    orig_alpha = original_arr[:, :, 3].astype(np.int16)
    det_alpha = details_arr[:, :, 3].astype(np.int16)
    body[:, :, 3] = np.clip(orig_alpha - det_alpha, 0, 255).astype(np.uint8)
    return body


def auto_split_details(original_arr):
    """Split by color: green-dominant pixels go to body, rest to details."""
    r = original_arr[:, :, 0].astype(np.int16)
    g = original_arr[:, :, 1].astype(np.int16)
    b = original_arr[:, :, 2].astype(np.int16)
    a = original_arr[:, :, 3]

    # Green-dominant: G is strictly greater than both R and B, and pixel is visible
    is_green = (g > r) & (g > b) & (a > 0)

    # Details = everything that's NOT green-dominant
    details = original_arr.copy()
    details[is_green] = [0, 0, 0, 0]

    return details


def process_with_existing_details(name, orig_path, details_path):
    """Fix an animation that has an existing details split."""
    original = np.array(Image.open(orig_path))
    details_orig = np.array(Image.open(details_path))

    # If dimensions don't match, fall back to auto-split
    if original.shape[:2] != details_orig.shape[:2]:
        return None, None  # Signal to caller to use auto-split

    body = regenerate_body(original, details_orig)
    return body, details_orig


def process_auto_split(name, orig_path):
    """Auto-split an animation by color separation."""
    original = np.array(Image.open(orig_path))
    details = auto_split_details(original)
    body = regenerate_body(original, details)
    return body, details


def main():
    # Map: animation name -> (combined path, details source path or None)
    animations = {}

    # Find all combined sheets
    for f in sorted(os.listdir(SPRITE_DIR)):
        if not f.endswith('.png'):
            continue
        if f.endswith('_body.png') or f.endswith('_details.png'):
            continue
        name = f.replace('.png', '')
        if name in SKIP_FILES:
            continue

        combined_path = os.path.join(SPRITE_DIR, f)

        # Check for existing details in not-pixel-perfect folder
        npp_details = os.path.join(NPP_DIR, f'{name}_details.png')
        if os.path.exists(npp_details):
            animations[name] = (combined_path, npp_details)
        else:
            animations[name] = (combined_path, None)

    print(f'{"Animation":<22} | {"Method":<20} | {"Size":<14} | {"Gaps":>6} | {"Status"}')
    print('-' * 80)

    for name in sorted(animations.keys()):
        combined_path, details_path = animations[name]

        body_arr = None
        details_arr = None

        if details_path:
            body_arr, details_arr = process_with_existing_details(
                name, combined_path, details_path
            )
            if body_arr is not None:
                method = 'fix existing'
            else:
                # Dimensions didn't match, fall back
                body_arr, details_arr = process_auto_split(name, combined_path)
                method = 'auto (dim mismatch)'
        else:
            method = 'auto-split'
            body_arr, details_arr = process_auto_split(name, combined_path)

        gaps = count_gaps(body_arr, details_arr)
        status = 'OK' if gaps < 10 else f'WARNING ({gaps} gaps)'
        h, w = body_arr.shape[:2]

        # Save outputs
        body_img = Image.fromarray(body_arr)
        details_img = Image.fromarray(details_arr)
        body_img.save(os.path.join(SPRITE_DIR, f'{name}_body.png'))
        details_img.save(os.path.join(SPRITE_DIR, f'{name}_details.png'))

        print(f'{name:<22} | {method:<20} | {w}x{h:<8} | {gaps:>6} | {status}')

    print()
    print('Done. All body/details pairs saved to sprite-sheets/.')


if __name__ == '__main__':
    main()
