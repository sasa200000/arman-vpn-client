package desktop

import (
	"bytes"
	"image"
	"image/png"
	"testing"
)

// Every tray state has its icon in both formats: a PNG on a transparent
// corner whose dark tile carries the shield's bright neon line in the middle,
// and an ICO.
func TestTrayIcons(t *testing.T) {
	for _, name := range []string{iconRunning, iconRunningAsleep, iconSet, iconSetAsleep, iconWaiting, iconError, iconOff} {
		data, err := trayFiles.ReadFile("tray/" + name + ".png")
		if err != nil {
			t.Fatal(err)
		}
		img, err := png.Decode(bytes.NewReader(data))
		if err != nil {
			t.Fatalf("%s: %v", name, err)
		}
		if b := img.Bounds(); b.Dx() != 32 || b.Dy() != 32 {
			t.Fatalf("%s: size %v", name, b)
		}
		if _, _, _, a := img.At(0, 0).RGBA(); a != 0 {
			t.Fatalf("%s: the corner should be transparent", name)
		}
		// The shield's neon line, bright over the tile it sits on.
		if !hasBrightLine(img) {
			t.Fatalf("%s: the middle should hold the shield's bright line", name)
		}
		ico, err := trayFiles.ReadFile("tray/" + name + ".ico")
		if err != nil || !bytes.Equal(ico[:4], []byte{0, 0, 1, 0}) {
			t.Fatalf("%s: not an ICO file: %v", name, err)
		}
		if len(trayIcon(name)) == 0 {
			t.Fatalf("%s: no icon for this system", name)
		}
	}
}

// Every state but "off" carries its own dot of color at the lower right of
// the tile, so the tray can tell the states apart at a glance.
func TestTrayDots(t *testing.T) {
	off := trayPNG(t, iconOff)
	for _, name := range []string{iconRunning, iconRunningAsleep, iconSet, iconSetAsleep, iconWaiting, iconError} {
		img := trayPNG(t, name)
		dot := 0
		for y := 16; y < 32; y++ {
			for x := 16; x < 32; x++ {
				if img.At(x, y) != off.At(x, y) {
					dot++
				}
			}
		}
		if dot == 0 {
			t.Fatalf("%s: no dot of the state's color at the lower right", name)
		}
	}
}

// Whether one opaque pixel of the icon's middle is bright enough to read as
// the neon line of the shield.
func hasBrightLine(img image.Image) bool {
	for y := 8; y < 24; y++ {
		for x := 8; x < 24; x++ {
			r, g, b, a := img.At(x, y).RGBA()
			if a != 0xffff {
				continue
			}
			hi := r >> 8
			if g>>8 > hi {
				hi = g >> 8
			}
			if b>>8 > hi {
				hi = b >> 8
			}
			if hi >= 0xe0 {
				return true
			}
		}
	}
	return false
}

func trayPNG(t *testing.T, name string) image.Image {
	t.Helper()
	data, err := trayFiles.ReadFile("tray/" + name + ".png")
	if err != nil {
		t.Fatal(err)
	}
	img, err := png.Decode(bytes.NewReader(data))
	if err != nil {
		t.Fatalf("%s: %v", name, err)
	}
	return img
}
