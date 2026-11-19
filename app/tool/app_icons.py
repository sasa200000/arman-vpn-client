"""Makes every icon of the program from the V2RVPN mark (assets/v2r-source.jpg):
a neon shield, purple and cyan, with a yellow bolt through it.

The source art is a 512 px square: the shield from y=88 to y=290 and the name
under it. This script cuts the shield out of its near-black field, keeping the
neon glow, and composes it on the tiles the platforms want:

- Android (android/app/src/main/res): an adaptive icon for Android 8+ (the
  shield as the foreground layer over black, 108 dp each) and ic_launcher.png
  for older Android. The status bar icon (res/drawable/ic_stat_logo.xml) is a
  plain white mask, drawn by hand.
- Android TV banner (res/drawable-xhdpi/banner.png, 320 x 180): the shield and
  the name on the app's night navy.
- macOS (macos/Runner/Assets.xcassets/AppIcon.appiconset): the shield on the
  black tile in Apple's grid, 824 of 1024 with room for its shadow.
- Windows (windows/runner/resources/app_icon.ico): the tile in every size
  Explorer and the taskbar use.
- The core (core/internal/desktop/appicon.ico) and the web dashboard
  (core/internal/service/web/icon.png).
- The app's own logo (assets/logo.png), beside its name.
- The tray icons (assets/tray, core/internal/desktop/tray): the shield small
  over a dark tile, with a dot of the state's color.

Run from app/ after changing the source art (needs Pillow):

    python tool/app_icons.py
"""
import os

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.join(HERE, '..')
CORE = os.path.join(APP, '..', 'core')
RES = os.path.join(APP, 'android', 'app', 'src', 'main', 'res')

# The shield's side as a share of the 108 dp canvas. Launchers show about the
# middle 72 dp, so 0.52 makes it about 78% of the tile they crop to.
ART = 0.62
BLACK = (0, 0, 0, 255)
DENSITY = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
WINDOWS_SIZES = [16, 20, 24, 32, 40, 48, 64, 128, 256]
MACOS_SIZES = [16, 32, 64, 128, 256, 512, 1024]
TRAY_SIZES = [16, 20, 24, 32, 48, 64]
TRAY_TILE = (26, 26, 30, 255)

ADAPTIVE = '''<?xml version="1.0" encoding="utf-8"?>
<!-- The launcher icon on Android 8+: the V2RVPN shield over black; the
     launcher crops both layers to its own shape. Made by
     tool/app_icons.py. -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
'''

SOURCE = os.path.join(APP, 'assets', 'v2r-source.jpg')

# The shield's rows in the source art; the name sits under them.
SHIELD = (66, 86, 436, 292)


def cut(box):
    """The art in box on transparent: the neon shield with its glow, the
    near-black field around it made transparent.

    The field is a flat dark grey with faint diagonal streaks, so a pixel stays
    where it is clearly lighter than that field, its alpha fading with the
    distance from it; the glow keeps its halo instead of ending in a cut.
    """
    src = Image.open(SOURCE).convert('RGB').crop(box)
    w, h = src.size
    px = src.load()
    out = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    dst = out.load()
    # The field's brightness: its darkest corner.
    corners = [px[2, 2], px[w - 3, 2], px[2, h - 3], px[w - 3, h - 3]]
    base = min(sum(c) / 3.0 for c in corners)
    fade = 24.0
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            v = (r + g + b) / 3.0
            if v <= base + 2:
                continue
            a = (v - base) / fade
            dst[x, y] = (r, g, b, 255 if a >= 1 else round(255 * a))
    return out.crop(out.getchannel('A').getbbox())


def art_layer(art, size, share):
    """The art's visible part, its larger side share of size, centered."""
    scale = size * share / max(art.size)
    w, h = max(1, round(art.width * scale)), max(1, round(art.height * scale))
    layer = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    layer.alpha_composite(art.resize((w, h), Image.LANCZOS), ((size - w) // 2, (size - h) // 2))
    return layer


def tile_art(shield):
    """The tile (512 px): a black rounded square of 412 px, the shield in its
    middle."""
    size, body = 512, 412
    out = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    off = (size - body) // 2
    ImageDraw.Draw(out).rounded_rectangle(
        [off, off, off + body - 1, off + body - 1],
        radius=round(body * 0.2), fill=BLACK)
    out.alpha_composite(art_layer(shield, body, 0.80), (off, off))
    return out


def tile(glyph, size):
    """The visible middle of the adaptive icon, rounded."""
    canvas = round(size * 108 / 72)
    full = Image.new('RGBA', (canvas, canvas), BLACK)
    full.alpha_composite(art_layer(glyph, canvas, ART))
    cut_ = (canvas - size) // 2
    square = full.crop((cut_, cut_, cut_ + size, cut_ + size))
    mask = Image.new('L', (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size - 1, size - 1], radius=size // 5, fill=255)
    out = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    out.paste(square, (0, 0), mask)
    return out


def android(glyph):
    for dpi, k in DENSITY.items():
        folder = os.path.join(RES, 'mipmap-' + dpi)
        os.makedirs(folder, exist_ok=True)
        px = round(108 * k)
        art_layer(glyph, px, ART).save(os.path.join(folder, 'ic_launcher_foreground.png'), optimize=True)
        Image.new('RGBA', (px, px), BLACK).save(os.path.join(folder, 'ic_launcher_background.png'), optimize=True)
        tile(glyph, round(48 * k)).save(os.path.join(folder, 'ic_launcher.png'), optimize=True)
    folder = os.path.join(RES, 'mipmap-anydpi-v26')
    os.makedirs(folder, exist_ok=True)
    with open(os.path.join(folder, 'ic_launcher.xml'), 'w', newline='\n') as f:
        f.write(ADAPTIVE)


def tv_banner(glyph):
    """Android TV's banner, which its home screen shows in the apps row: the
    shield and the name, 320 x 180 px, on the app's night navy."""
    from PIL import ImageFont
    w, h = 320, 180
    top, bottom = (0x26, 0x30, 0x6B), (0x14, 0x1B, 0x3D)
    out = Image.new('RGBA', (w, h))
    for y in range(h):
        t = y / (h - 1)
        out.paste(tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)) + (255,), (0, y, w, y + 1))
    art = art_layer(glyph, 100, 1.0)
    font = ImageFont.truetype(os.path.join(APP, 'assets', 'fonts', 'Vazirmatn-Bold.ttf'), 36)
    name = 'V2RVPN'
    draw = ImageDraw.Draw(out)
    left, top_, right, bottom_ = draw.textbbox((0, 0), name, font=font)
    gap = 16
    x = (w - (art.width + gap + right - left)) // 2
    out.alpha_composite(art, (x, (h - art.height) // 2))
    draw.text((x + art.width + gap - left, (h - (bottom_ - top_)) // 2 - top_), name,
              font=font, fill=(255, 255, 255, 255))
    folder = os.path.join(RES, 'drawable-xhdpi')
    os.makedirs(folder, exist_ok=True)
    out.save(os.path.join(folder, 'banner.png'), optimize=True)


def crisp(art, size):
    """A small size: shrunk from the full art, then sharpened and given a
    little more contrast and color, which a few pixels otherwise lose."""
    image = art_layer(art, size, 1.0)
    alpha = image.getchannel('A')
    rgb = image.convert('RGB').filter(
        ImageFilter.UnsharpMask(radius=0.6 if size <= 24 else 0.8, percent=130, threshold=0))
    rgb = ImageEnhance.Color(ImageEnhance.Contrast(rgb).enhance(1.05)).enhance(1.08)
    out = rgb.convert('RGBA')
    out.putalpha(alpha)
    return out


def write_ico(path, art):
    # Each size drawn from the full art; up to 48 px sharpened.
    images = [crisp(art, n) if n <= 48 else art_layer(art, n, 1.0) for n in WINDOWS_SIZES]
    images[-1].save(path, format='ICO', sizes=[(n, n) for n in WINDOWS_SIZES], append_images=images[:-1])


def macos_icon(glyph):
    """The 1024 px macOS icon: the black tile, 824 px with rounded corners,
    over a soft shadow, the shield in its middle."""
    size, body = 1024, 824
    off = (size - body) // 2
    mask = Image.new('L', (body, body), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, body - 1, body - 1], radius=round(body * 0.225), fill=255)
    shadow = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    shadow.paste((0, 0, 0, 90), (off, off + 12), mask)
    out = shadow.filter(ImageFilter.GaussianBlur(14))
    face = Image.new('RGBA', (body, body), BLACK)
    face.alpha_composite(art_layer(glyph, body, 0.80))
    out.paste(face, (off, off), mask)
    return out


def macos(glyph):
    folder = os.path.join(APP, 'macos', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')
    big = macos_icon(glyph)
    for n in MACOS_SIZES:
        big.resize((n, n), Image.LANCZOS).save(os.path.join(folder, 'app_icon_%d.png' % n), optimize=True)


def app_logo(square):
    art_layer(square, 256, 1.0).save(os.path.join(APP, 'assets', 'logo.png'), optimize=True)


def windows(square):
    write_ico(os.path.join(APP, 'windows', 'runner', 'resources', 'app_icon.ico'), square)


def core(square):
    desktop = os.path.join(CORE, 'internal', 'desktop')
    write_ico(os.path.join(desktop, 'appicon.ico'), square)
    art_layer(square, 192, 1.0).save(os.path.join(CORE, 'internal', 'service', 'web', 'icon.png'), optimize=True)


# The tray's state colors: green while connected, red on an error, and the
# core's own: blue while Windows' system proxy points at the proxy, faded
# while asleep.
DOT_GOOD, DOT_BAD = (63, 225, 176), (226, 40, 80)
DOT_SET = (96, 165, 250)


def asleep(color):
    return tuple(round(c * 0.45 + g * 0.55) for c, g in zip(color, (150, 160, 158)))


def tray_icon(glyph, dot=None):
    """A tray icon (80 px): the shield on a dark rounded tile, with a dot of
    color dot (RGB) in the lower right."""
    n = 320
    img = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, n - 1, n - 1], radius=round(n * 0.22), fill=TRAY_TILE)
    art = art_layer(glyph, round(n * 0.88), 1.0)
    off = (n - art.width) // 2
    img.alpha_composite(art, (off, off))
    if dot:
        r = n * 0.155
        x, y = n - r - n * 0.045, n - r - n * 0.045
        d.ellipse([x - r - 4, y - r - 4, x + r + 4, y + r + 4], fill=TRAY_TILE)
        d.ellipse([x - r, y - r, x + r, y + r], fill=dot + (255,))
    return img.resize((80, 80), Image.LANCZOS)


def save_ico(path, big):
    images = [big.resize((n, n), Image.LANCZOS) for n in TRAY_SIZES]
    images[-1].save(path, format='ICO', sizes=[(n, n) for n in TRAY_SIZES], append_images=images[:-1])


def tray(glyph):
    app = os.path.join(APP, 'assets', 'tray')
    for old in os.listdir(app):
        os.remove(os.path.join(app, old))
    icons = {
        'off': tray_icon(glyph),
        'on': tray_icon(glyph, dot=DOT_GOOD),
        'idle': tray_icon(glyph, dot=DOT_GOOD),
        'error': tray_icon(glyph, dot=DOT_BAD),
    }
    # Connecting: the dot brightens frame by frame.
    for frame in range(1, 5):
        shade = [0x20, 0x3C, 0x5E, 0x8C][frame - 1]
        icons['busy%d' % frame] = tray_icon(glyph, dot=(shade, min(255, shade + 50), min(255, shade + 110)))
    for name, big in icons.items():
        save_ico(os.path.join(app, name + '.ico'), big)
        # Linux (AppIndicator) takes a .png; 64 px stays sharp when scaled.
        big.resize((64, 64), Image.LANCZOS).save(os.path.join(app, name + '.png'), optimize=True)
    # The core's tray: an .ico for Windows, a 32 px .png elsewhere.
    folder = os.path.join(CORE, 'internal', 'desktop', 'tray')
    os.makedirs(folder, exist_ok=True)
    states = {
        'running': tray_icon(glyph, dot=DOT_GOOD),
        'set': tray_icon(glyph, dot=DOT_SET),
        'running-asleep': tray_icon(glyph, dot=asleep(DOT_GOOD)),
        'set-asleep': tray_icon(glyph, dot=asleep(DOT_SET)),
        'waiting': tray_icon(glyph, dot=(0x8C, 0x64, 0xE8)),
        'error': tray_icon(glyph, dot=DOT_BAD),
        'off': tray_icon(glyph),
    }
    for name, big in states.items():
        save_ico(os.path.join(folder, name + '.ico'), big)
        big.resize((32, 32), Image.LANCZOS).save(os.path.join(folder, name + '.png'), optimize=True)


def main():
    shield = cut(SHIELD)
    print('shield', shield.size)
    square = tile_art(shield)
    android(shield)
    tv_banner(shield)
    macos(shield)
    windows(square)
    core(square)
    app_logo(square)
    tray(shield)
    print('icons written')


if __name__ == '__main__':
    main()