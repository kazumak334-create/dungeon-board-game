from pathlib import Path
from PIL import Image
import numpy as np

# 使い方:
#   python split_bitmap_font.py input.png output_dir
#
# 例:
#   python split_bitmap_font.py gold_font.png out_chars
#
# 想定:
# - 背景が白/グレーの市松模様
# - 文字が 6行 × 6列（合計36文字）
# - 並び順が以下:
#   ABCDEF
#   GHIJKL
#   MNOPQR
#   STUVWX
#   YZ0123
#   456789

CHAR_ORDER = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

def find_segments_1d(values, threshold):
    segs = []
    in_seg = False
    start = 0
    for i, v in enumerate(values):
        if v > threshold and not in_seg:
            start = i
            in_seg = True
        elif in_seg and v <= threshold:
            segs.append((start, i))
            in_seg = False
    if in_seg:
        segs.append((start, len(values)))
    return segs

def merge_close_segments(segs, gap=6):
    if not segs:
        return []
    merged = [list(segs[0])]
    for s, e in segs[1:]:
        if s - merged[-1][1] <= gap:
            merged[-1][1] = e
        else:
            merged.append([s, e])
    return [tuple(x) for x in merged]

def build_mask(rgb):
    # 背景が白/灰の市松模様、文字は黒アウトライン＋色付き本体という前提。
    rgb = rgb.astype(np.int16)
    mx = rgb.max(axis=2)
    mn = rgb.min(axis=2)
    saturation = mx - mn
    # 彩度がある or 十分暗いピクセルを「文字」とみなす
    mask = (saturation > 15) | (mx < 50)
    return mask

def crop_char(arr_rgba, mask, x0, y0, x1, y1, pad=2):
    h, w = mask.shape
    x0 = max(0, x0 - pad)
    y0 = max(0, y0 - pad)
    x1 = min(w, x1 + pad)
    y1 = min(h, y1 + pad)

    sub_rgba = arr_rgba[y0:y1, x0:x1].copy()
    sub_rgb = sub_rgba[:, :, :3].astype(np.int16)

    # 透過化:
    # - 白/グレーの市松模様
    # - 文字以外
    sub_mask = build_mask(sub_rgb)
    alpha = np.where(sub_mask, 255, 0).astype(np.uint8)
    sub_rgba[:, :, 3] = alpha

    # 透過化後にさらに最小bboxで詰める
    ys, xs = np.where(alpha > 0)
    if len(xs) == 0 or len(ys) == 0:
        return None
    bx0, bx1 = xs.min(), xs.max() + 1
    by0, by1 = ys.min(), ys.max() + 1
    return Image.fromarray(sub_rgba[by0:by1, bx0:bx1], mode="RGBA")

def main():
    import sys
    if len(sys.argv) < 3:
        print("使い方: python split_bitmap_font.py input.png output_dir")
        return

    input_path = Path(sys.argv[1])
    output_dir = Path(sys.argv[2])
    output_dir.mkdir(parents=True, exist_ok=True)

    img = Image.open(input_path).convert("RGBA")
    arr_rgba = np.array(img)
    arr_rgb = arr_rgba[:, :, :3]
    mask = build_mask(arr_rgb)

    # 行検出
    row_counts = mask.sum(axis=1)
    row_segs = find_segments_1d(row_counts, threshold=20)
    row_segs = merge_close_segments(row_segs, gap=8)

    if len(row_segs) != 6:
        print(f"警告: 検出した行数 = {len(row_segs)}（期待値は6）")
        print("検出結果:", row_segs)

    char_index = 0
    saved = []

    for row_i, (ry0, ry1) in enumerate(row_segs):
        submask = mask[ry0:ry1, :]
        col_counts = submask.sum(axis=0)
        col_segs = find_segments_1d(col_counts, threshold=10)
        col_segs = merge_close_segments(col_segs, gap=8)

        if len(col_segs) != 6:
            print(f"警告: {row_i+1}行目の列数 = {len(col_segs)}（期待値は6）")
            print("検出結果:", col_segs)

        for (cx0, cx1) in col_segs:
            if char_index >= len(CHAR_ORDER):
                break
            ch = CHAR_ORDER[char_index]
            cropped = crop_char(arr_rgba, mask, cx0, ry0, cx1, ry1, pad=2)
            if cropped is None:
                print(f"スキップ: {ch}")
            else:
                out_path = output_dir / f"{ch}.png"
                cropped.save(out_path)
                saved.append(out_path.name)
            char_index += 1

    print("保存完了:")
    for name in saved:
        print(" -", name)

if __name__ == "__main__":
    main()
