"""Generate the game's procedural effect textures (no third-party assets).

    python tools/gen_fx_textures.py          -> assets/fx/*.png

torch_cookie.png  flashlight projector: soft hotspot, wide spill, faint reflector
                  streaks and lens dust (replaces the old banded gradient).
grime_base.png    dirt creeping up from the skirting (decal, RGBA).
water_stain.png   ceiling / wall water stain with a darker tide-line (decal, RGBA).
mould.png         speckled black mould patch (decal, RGBA).
floor_dirt.png    scuffed, trodden-in dirt patch (decal, RGBA).
cork.png          notice-board cork.  archive_box.png  file-box front face.
paan_stain.png    betel-juice splatter on stair walls (decal, RGBA).
Deterministic (fixed seeds) so re-running gives the same files.
"""
import os
import numpy as np
from PIL import Image, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "fx")
os.makedirs(OUT, exist_ok=True)


def fbm(n, octaves, seed, base=4):
    """Fractal value noise in [0,1], tileable-ish, shape (n, n)."""
    rng = np.random.default_rng(seed)
    acc = np.zeros((n, n)); amp = 1.0; tot = 0.0
    for o in range(octaves):
        cells = base * (2 ** o)
        g = rng.random((cells + 1, cells + 1))
        img = Image.fromarray((g * 255).astype(np.uint8)).resize((n, n), Image.BICUBIC)
        acc += np.asarray(img, dtype=np.float64) / 255.0 * amp
        tot += amp; amp *= 0.5
    acc /= tot
    return (acc - acc.min()) / (acc.max() - acc.min() + 1e-9)


def save_rgba(name, rgb, alpha):
    a = np.clip(alpha, 0, 1)
    img = np.dstack([np.clip(rgb, 0, 1) * 255, a * 255]).astype(np.uint8)
    Image.fromarray(img, "RGBA").save(os.path.join(OUT, name))


def torch_cookie(n=512):
    y, x = np.mgrid[0:n, 0:n] / (n - 1) * 2 - 1
    r = np.sqrt(x * x + y * y)
    ang = np.arctan2(y, x)
    hot = np.exp(-(r / 0.22) ** 2)                 # bright core
    spill = np.exp(-(r / 0.62) ** 2.2) * 0.55      # wide soft spill
    edge = np.clip(1 - (r - 0.78) / 0.2, 0, 1)     # fade before the cone edge
    rng = np.random.default_rng(7)
    # reflector imperfections: very faint angular streaks + a soft wobbly ring
    streak = 1 + 0.015 * np.sin(ang * 23 + rng.random() * 6) * np.exp(-((r - 0.35) / 0.25) ** 2)
    ring = 0.08 * np.exp(-((r - 0.42 - 0.02 * np.sin(ang * 5)) / 0.05) ** 2)
    v = (hot + spill + ring) * streak * edge
    # lens dust: a few soft dark specks
    dust = np.ones((n, n))
    for _ in range(14):
        cx, cy = rng.uniform(-0.6, 0.6, 2); rad = rng.uniform(0.02, 0.06)
        dust -= 0.12 * np.exp(-(((x - cx) ** 2 + (y - cy) ** 2) / rad ** 2))
    v = np.clip(v * dust, 0, 1) ** 0.9
    img = Image.fromarray((v * 255).astype(np.uint8), "L").filter(ImageFilter.GaussianBlur(3.0))
    img.convert("RGB").save(os.path.join(OUT, "torch_cookie.png"))


def grime_base(w=512, h=256):
    n = fbm(max(w, h), 6, 11)[:h, :w]
    rng = np.random.default_rng(3)
    cols = np.asarray(Image.fromarray((rng.random((1, 18)) * 255).astype(np.uint8))
                      .resize((w, h), Image.BICUBIC), dtype=np.float64) / 255.0   # soft per-column variation
    t = np.linspace(0, 1, h)[:, None]                # 0 = top row, 1 = bottom row (sits on the skirting)
    height = 0.25 + 0.4 * cols + 0.2 * n             # how far the dirt climbs
    a = np.clip((height - (1 - t)) / 0.3, 0, 1) * (0.4 + 0.6 * n)
    for _ in range(9):                                # a few thin drip runs from above
        cx = int(rng.uniform(0.05, 0.95) * w); top = rng.uniform(0.0, 0.45)
        xs = np.exp(-((np.arange(w) - cx) / rng.uniform(1.5, 3.5)) ** 2)[None, :]
        a = np.maximum(a, xs * np.clip((t - top) / 0.5, 0, 1) * rng.uniform(0.25, 0.5))
    a *= np.clip(np.minimum(np.linspace(0, 1, w), np.linspace(1, 0, w)) * 6, 0, 1)[None, :]   # soft ends
    rgb = np.dstack([0.16 + 0.1 * n, 0.12 + 0.07 * n, 0.08 + 0.05 * n])
    save_rgba("grime_base.png", rgb, a * 0.85)


def water_stain(n=512):
    y, x = np.mgrid[0:n, 0:n] / (n - 1) * 2 - 1
    warp = fbm(n, 5, 21) - 0.5
    r = np.sqrt(x * x + y * y) + warp * 0.45
    inner = np.clip((0.62 - r) / 0.2, 0, 1) * 0.16
    tide = np.exp(-((r - 0.62) / 0.035) ** 2) * 0.8 + np.exp(-((r - 0.48) / 0.03) ** 2) * 0.35
    a = np.clip(inner + tide, 0, 1) * np.clip((0.75 - r) / 0.1, 0, 1)
    tone = fbm(n, 4, 22)
    rgb = np.dstack([0.42 + 0.1 * tone, 0.3 + 0.06 * tone, 0.16 + 0.04 * tone])
    save_rgba("water_stain.png", rgb, a * 0.9)


def mould(n=512):
    y, x = np.mgrid[0:n, 0:n] / (n - 1) * 2 - 1
    blob = fbm(n, 6, 31)
    r = np.sqrt(x * x + y * y)
    spots = (fbm(n, 3, 32, base=24) > 0.62).astype(np.float64)
    fine = (fbm(n, 2, 33, base=64) > 0.55).astype(np.float64)
    a = np.clip((blob - 0.45 + (0.55 - r) * 0.9) / 0.25, 0, 1) * (0.15 + 0.55 * spots + 0.3 * fine)
    a = np.asarray(Image.fromarray((a * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.5)), dtype=np.float64) / 255
    rgb = np.dstack([0.03 + 0.03 * blob, 0.04 + 0.03 * blob, 0.03 + 0.02 * blob])
    save_rgba("mould.png", rgb, a * 0.9)


def floor_dirt(n=512):
    y, x = np.mgrid[0:n, 0:n] / (n - 1) * 2 - 1
    blob = fbm(n, 6, 41)
    scuff = fbm(n, 2, 42, base=40)
    r = np.sqrt((x * 0.8) ** 2 + y * y)
    a = np.clip((blob * 0.9 + (0.8 - r)) - 0.75, 0, 1) * 1.6 * (0.6 + 0.4 * scuff)
    rgb = np.dstack([0.2 + 0.08 * blob, 0.16 + 0.06 * blob, 0.12 + 0.04 * blob])
    save_rgba("floor_dirt.png", rgb, np.clip(a, 0, 0.75))


def cork(n=512):
    """Notice-board cork: warm speckled granules."""
    rng = np.random.default_rng(51)
    base = fbm(n, 5, 52)
    speck = rng.random((n, n))
    v = 0.55 + 0.25 * base + 0.2 * (speck - 0.5)
    rgb = np.dstack([0.62 * v, 0.44 * v, 0.27 * v])
    Image.fromarray((np.clip(rgb, 0, 1) * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, "cork.png"))


def archive_box(w=256, h=192):
    """Front face of a cardboard archive box: label with scrawled lines, a handle hole."""
    rng = np.random.default_rng(61)
    n = fbm(max(w, h), 5, 62)[:h, :w]
    img = np.dstack([0.66 + 0.1 * n, 0.55 + 0.08 * n, 0.38 + 0.06 * n])
    img[:6, :] *= 0.75; img[-6:, :] *= 0.75; img[:, :5] *= 0.8; img[:, -5:] *= 0.8   # worn edges
    lx0, lx1, ly0, ly1 = int(w * 0.22), int(w * 0.78), int(h * 0.18), int(h * 0.5)
    img[ly0:ly1, lx0:lx1] = np.array([0.9, 0.88, 0.8]) * (0.92 + 0.08 * n[ly0:ly1, lx0:lx1, None])
    for k in range(3):                                   # "handwriting": wobbly dark strokes
        y = ly0 + 8 + k * 11
        x = lx0 + 8
        while x < lx1 - 10 - rng.integers(0, 30):
            seg = int(rng.integers(6, 18))
            yy = y + int(rng.integers(-1, 2))
            img[yy:yy + 2, x:x + seg] = [0.12, 0.12, 0.2]
            x += seg + int(rng.integers(3, 7))
    cy, cx = int(h * 0.75), w // 2                       # handle hole
    yy, xx = np.mgrid[0:h, 0:w]
    hole = ((xx - cx) / (w * 0.13)) ** 2 + ((yy - cy) / (h * 0.07)) ** 2 < 1.0
    img[hole] = [0.08, 0.07, 0.06]
    Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, "archive_box.png"))


def paan_stain(n=512):
    """Betel-juice (paan) splatter: red-brown blots and droplets, as on every old Mumbai stair."""
    rng = np.random.default_rng(71)
    y, x = np.mgrid[0:n, 0:n] / (n - 1) * 2 - 1
    a = np.zeros((n, n))
    blob = fbm(n, 5, 72)
    r = np.sqrt((x * 1.2) ** 2 + (y + 0.15) ** 2)
    a += np.clip((0.45 - r + (blob - 0.5) * 0.5) / 0.08, 0, 1) * 0.85
    for _ in range(40):                                  # droplets flung outward
        ang = rng.uniform(-np.pi, np.pi); d = rng.uniform(0.35, 0.9); rad = rng.uniform(0.012, 0.05)
        cx, cy = np.cos(ang) * d, np.sin(ang) * d * 0.7 - 0.1
        a = np.maximum(a, np.clip(1 - ((x - cx) ** 2 + (y - cy) ** 2) / rad ** 2, 0, 1) * 0.9)
    for _ in range(4):                                   # runs dripping down
        cx = rng.uniform(-0.3, 0.3); w = rng.uniform(0.015, 0.03)
        a = np.maximum(a, np.exp(-((x - cx) / w) ** 2) * np.clip((y - 0.1) / 0.6, 0, 1) * np.clip((0.95 - y) / 0.2, 0, 1) * 0.7)
    tone = fbm(n, 3, 73)
    rgb = np.dstack([0.45 + 0.12 * tone, 0.06 + 0.04 * tone, 0.04 + 0.03 * tone])
    save_rgba("paan_stain.png", rgb, np.clip(a, 0, 1) * 0.85)


if __name__ == "__main__":
    torch_cookie(); grime_base(); water_stain(); mould(); floor_dirt()
    cork(); archive_box(); paan_stain()
    print("wrote", sorted(os.listdir(OUT)))
