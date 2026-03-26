APP_NAME   := PlainPaste
BUNDLE     := $(APP_NAME).app
SRC        := Sources/main.swift
BUILD_DIR  := build
EXECUTABLE := $(BUILD_DIR)/$(APP_NAME)
INSTALL_DIR := ~/Applications

# ── Options ──────────────────────────────────────────────────────────
# make compile              → fast debug build (no optimisation)
# make compile RELEASE=1    → optimised release build (-O, -wmo, stripped symbols)
# make compile V=1          → verbose compiler output
# make compile TIMING=1     → show where the compiler spends time
# make bundle               → creates .app with strip -x and hardened runtime codesign
SWIFTFLAGS := -framework Cocoa
ifdef RELEASE
  SWIFTFLAGS += -O -whole-module-optimization -Xlinker -S
endif
ifdef V
  SWIFTFLAGS += -v
endif
ifdef TIMING
  SWIFTFLAGS += -Xfrontend -debug-time-compilation -Xfrontend -debug-time-function-bodies
endif

# ── Version ──────────────────────────────────────────────────────────
# Reads the latest git tag (v1.2.3 → 1.2.3). Falls back to "dev".
VERSION := $(shell git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "dev")

# ── Compile ──────────────────────────────────────────────────────────
.PHONY: compile
compile:
	mkdir -p $(BUILD_DIR)
	echo 'let appVersion = "$(VERSION)"' > $(BUILD_DIR)/Version.swift
	swiftc $(SRC) $(BUILD_DIR)/Version.swift -o $(EXECUTABLE) $(SWIFTFLAGS)

# ── App bundle ───────────────────────────────────────────────────────
.PHONY: bundle
bundle: compile
	mkdir -p $(BUILD_DIR)/$(BUNDLE)/Contents/MacOS
	cp $(EXECUTABLE) $(BUILD_DIR)/$(BUNDLE)/Contents/MacOS/
	strip -x $(BUILD_DIR)/$(BUNDLE)/Contents/MacOS/$(APP_NAME)
	cp Info.plist    $(BUILD_DIR)/$(BUNDLE)/Contents/
	@sed -i '' 's/1\.0\.0/$(VERSION)/g' $(BUILD_DIR)/$(BUNDLE)/Contents/Info.plist
	codesign --force --sign - --options runtime $(BUILD_DIR)/$(BUNDLE)

	@echo ""
	@echo "✅  $(BUNDLE) built in $(BUILD_DIR)/"

# ── Install to ~/Applications ────────────────────────────────────────
.PHONY: install
install: bundle
	mkdir -p $(INSTALL_DIR)
	rm -rf $(INSTALL_DIR)/$(BUNDLE)
	cp -R $(BUILD_DIR)/$(BUNDLE) $(INSTALL_DIR)/
	@echo "✅  Installed to $(INSTALL_DIR)/$(BUNDLE)"
	@echo "    Run:  open $(INSTALL_DIR)/$(BUNDLE)"

# ── Quick run (no install) ───────────────────────────────────────────
.PHONY: run
run: compile
	$(EXECUTABLE)

# ── Clean ────────────────────────────────────────────────────────────
.PHONY: clean
clean:
	rm -rf $(BUILD_DIR)

# ── Release zip (used by CI) ─────────────────────────────────────────
.PHONY: release-zip
release-zip: bundle
	cd $(BUILD_DIR) && zip -r $(APP_NAME).zip $(BUNDLE)
	@echo "✅  $(BUILD_DIR)/$(APP_NAME).zip"
