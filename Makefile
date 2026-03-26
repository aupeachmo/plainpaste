APP_NAME   := PlainPaste
BUNDLE     := $(APP_NAME).app
SRC        := Sources/main.swift
BUILD_DIR  := build
EXECUTABLE := $(BUILD_DIR)/$(APP_NAME)
INSTALL_DIR := ~/Applications

# ── Compile ──────────────────────────────────────────────────────────
.PHONY: compile
compile:
	mkdir -p $(BUILD_DIR)
	swiftc $(SRC) -o $(EXECUTABLE) -framework Cocoa -O

# ── App bundle ───────────────────────────────────────────────────────
.PHONY: bundle
bundle: compile
	mkdir -p $(BUILD_DIR)/$(BUNDLE)/Contents/MacOS
	cp $(EXECUTABLE) $(BUILD_DIR)/$(BUNDLE)/Contents/MacOS/
	cp Info.plist    $(BUILD_DIR)/$(BUNDLE)/Contents/

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
