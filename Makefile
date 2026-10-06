APP_NAME      := Clipshot
BUNDLE_ID     := com.egekibar.clipshot
SIGN_IDENTITY ?= Clipshot Dev
INSTALL_DIR   := $(HOME)/Applications

# CLT-only SwiftPM intermittently fails to resolve the Swift Testing macro plugin ("plugin for module
# 'TestingMacros' not found"); loading it explicitly makes `make test` deterministic. Skipped when absent.
TESTING_PLUGIN   := $(shell xcode-select -p)/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib
SWIFT_TEST_FLAGS := $(if $(wildcard $(TESTING_PLUGIN)),-Xswiftc -load-plugin-library -Xswiftc $(TESTING_PLUGIN),)

.PHONY: build test bundle install run cert reset-tcc format lint clean

build: ; swift build
# Usage: make test   |   make test FILTER='KeyCombo'   (regex on suite/test names)
test: ; @swift test $(SWIFT_TEST_FLAGS) $(if $(FILTER),--filter '$(FILTER)',)
bundle: ; swift build -c release && ./scripts/bundle.sh "$(APP_NAME)" "$(BUNDLE_ID)" "$(SIGN_IDENTITY)"
install: bundle ; ./scripts/install.sh "$(APP_NAME)" "$(INSTALL_DIR)"
run: install ; open "$(INSTALL_DIR)/$(APP_NAME).app"
# Optional: a stable self-signed identity, so the Screen Recording grant survives rebuilds.
cert: ; ./scripts/make-cert.sh "$(SIGN_IDENTITY)"
reset-tcc: ; tccutil reset ScreenCapture $(BUNDLE_ID)
format: ; xcrun swift-format format --in-place --recursive Sources Tests
lint: ; xcrun swift-format lint --strict --recursive Sources Tests
clean: ; rm -rf .build dist
