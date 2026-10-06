APP_NAME      := Clipshot
BUNDLE_ID     := com.egekibar.clipshot
SIGN_IDENTITY ?= Clipshot Dev
INSTALL_DIR   := $(HOME)/Applications

# CLT-only SwiftPM intermittently fails to resolve the Swift Testing macro plugin ("plugin for module
# 'TestingMacros' not found"); loading it explicitly makes `make test` deterministic. Skipped when absent.
TESTING_PLUGIN   := $(shell xcode-select -p)/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib
SWIFT_TEST_FLAGS := $(if $(wildcard $(TESTING_PLUGIN)),-Xswiftc -load-plugin-library -Xswiftc $(TESTING_PLUGIN),)

.PHONY: build test bundle dmg release cask install run cert reset-tcc format lint clean

build: ; swift build
# Usage: make test   |   make test FILTER='KeyCombo'   (regex on suite/test names)
test: ; @swift test $(SWIFT_TEST_FLAGS) $(if $(FILTER),--filter '$(FILTER)',)
bundle: ; swift build -c release && ./scripts/bundle.sh "$(APP_NAME)" "$(BUNDLE_ID)" "$(SIGN_IDENTITY)"
# dist/<App>-<version>.dmg + .sha256: what a GitHub release carries and the in-app updater installs.
dmg: bundle ; ./scripts/make-dmg.sh "$(APP_NAME)"
# Usage: make release VERSION=1.0.1 [NOTES=notes.md]   (tests, version bump, signed DMG, tag, GitHub release, cask)
release: ; ./scripts/release.sh "$(VERSION)" "$(NOTES)"
# Points the egekibar/tap cask at the published release of the current version.
cask: ; ./scripts/bump-cask.sh "$(APP_NAME)"
install: bundle ; ./scripts/install.sh "$(APP_NAME)" "$(INSTALL_DIR)"
run: install ; open "$(INSTALL_DIR)/$(APP_NAME).app"
# Once per Mac: a stable self-signed identity. Releases need it; with it the Screen Recording grant survives updates.
cert: ; ./scripts/make-cert.sh "$(SIGN_IDENTITY)"
reset-tcc: ; tccutil reset ScreenCapture $(BUNDLE_ID)
format: ; xcrun swift-format format --in-place --recursive Sources Tests
lint: ; xcrun swift-format lint --strict --recursive Sources Tests
clean: ; rm -rf .build dist
