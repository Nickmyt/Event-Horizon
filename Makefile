CC ?= cc
BUILD := build
CORE := core/wallpaper.c core/mpv.c
STRICT := -std=c11 -O2 -Wall -Wextra -Wpedantic -Werror -Wshadow -Wstrict-prototypes -Wmissing-prototypes \
	-Wcast-qual -Wundef -Wvla -Wformat=2 -Wconversion -Wunused-macros -Wnull-dereference -Wdouble-promotion
SHELLFLAGS := $(STRICT) -Wno-unused-parameter
WINLIBS := -luser32 -lcomctl32 -lshell32 -ldwmapi -lwtsapi32 -lcomdlg32 -lole32 -ladvapi32 -lgdi32
VIDEOS := $(foreach s,1920x1200 3072x1920 3840x2400,$(foreach r,30 60,media/Gargantua-$(s)-$(r)fps.mp4))
PREFIX ?= $(HOME)/.local

.PHONY: all check macos install-macos render variants linux linux-check windows windows-arm64 windows-package install-linux clean

all: check

$(BUILD):
	mkdir -p $(BUILD)

check: | $(BUILD)
	$(CC) $(STRICT) -c core/wallpaper.c -o $(BUILD)/wallpaper.o
	$(CC) $(STRICT) -c core/mpv.c -o $(BUILD)/mpv.o

macos:
	./macos/build.sh

install-macos:
	./macos/build.sh --install

render: | $(BUILD)
	swiftc -O macos/render/Render.swift -o $(BUILD)/render
	$(BUILD)/render media 7680 4800 24

variants: | $(BUILD)
	swiftc -O macos/render/Variants.swift -o $(BUILD)/variants
	$(BUILD)/variants media 3840x2400 3072x1920 1920x1200 3840x2400@30 3072x1920@30 1920x1200@30

linux: | $(BUILD)
	$(CC) $(SHELLFLAGS) linux/main.c $(CORE) -o $(BUILD)/event_horizon -lX11 -lXext -lXinerama -lm

linux-check: | $(BUILD)
	zig cc -target x86_64-linux-gnu $(SHELLFLAGS) -I/opt/homebrew/include -I/usr/include -c linux/main.c -o $(BUILD)/linux-x64.o
	zig cc -target aarch64-linux-gnu $(SHELLFLAGS) -I/opt/homebrew/include -I/usr/include -c linux/main.c -o $(BUILD)/linux-arm64.o

windows: | $(BUILD)
	mkdir -p $(BUILD)/windows-x64
	zig cc -target x86_64-windows-gnu $(SHELLFLAGS) -municode windows/main.c $(CORE) windows/app.rc \
		-o $(BUILD)/windows-x64/event_horizon.exe -Wl,--subsystem,windows $(WINLIBS)

windows-arm64: | $(BUILD)
	mkdir -p $(BUILD)/windows-arm64
	zig cc -target aarch64-windows-gnu $(SHELLFLAGS) -municode windows/main.c $(CORE) windows/app.rc \
		-o $(BUILD)/windows-arm64/event_horizon.exe -Wl,--subsystem,windows $(WINLIBS)

windows-package: windows
	cp $(VIDEOS) $(BUILD)/windows-x64/
	printf 'Put mpv.exe next to event_horizon.exe (https://mpv.io), then run event_horizon.exe.\r\n' > $(BUILD)/windows-x64/README.txt

install-linux: linux
	install -Dm755 $(BUILD)/event_horizon $(PREFIX)/bin/event_horizon
	mkdir -p $(PREFIX)/share/event_horizon
	cp $(VIDEOS) $(PREFIX)/share/event_horizon/
	mkdir -p $(HOME)/.config/autostart
	printf '[Desktop Entry]\nType=Application\nName=Event Horizon\nExec=%s/bin/event_horizon\nNoDisplay=true\nX-GNOME-Autostart-enabled=true\n' \
		"$(PREFIX)" > $(HOME)/.config/autostart/event_horizon.desktop

clean:
	rm -rf $(BUILD)
