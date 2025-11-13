.PHONY: build run test clean install release help

# Default target
.DEFAULT_GOAL := help

# Build configuration
BUILD_CONFIG ?= debug
SWIFT_BUILD_FLAGS ?=

# Paths
BUILD_DIR = .build/$(BUILD_CONFIG)
EXECUTABLE = mcp-zedchat

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## Build the project in debug mode
	@echo "Building $(EXECUTABLE)..."
	swift build $(SWIFT_BUILD_FLAGS)

release: ## Build the project in release mode
	@echo "Building $(EXECUTABLE) in release mode..."
	swift build -c release $(SWIFT_BUILD_FLAGS)

run: build ## Build and run the server
	@echo "Running $(EXECUTABLE)..."
	swift run $(EXECUTABLE)

test: ## Run all tests
	@echo "Running tests..."
	swift test

test-verbose: ## Run tests with verbose output
	@echo "Running tests (verbose)..."
	swift test --verbose

test-parallel: ## Run tests in parallel
	@echo "Running tests in parallel..."
	swift test --parallel

clean: ## Clean build artifacts
	@echo "Cleaning build artifacts..."
	swift package clean
	rm -rf .build

resolve: ## Resolve package dependencies
	@echo "Resolving dependencies..."
	swift package resolve

update: ## Update package dependencies
	@echo "Updating dependencies..."
	swift package update

format: ## Format code (requires swift-format)
	@echo "Formatting code..."
	@if command -v swift-format >/dev/null 2>&1; then \
		find Sources Tests -name "*.swift" -exec swift-format -i {} \; ; \
	else \
		echo "swift-format not found. Install with: brew install swift-format"; \
	fi

lint: ## Lint code (requires SwiftLint)
	@echo "Linting code..."
	@if command -v swiftlint >/dev/null 2>&1; then \
		swiftlint; \
	else \
		echo "SwiftLint not found. Install with: brew install swiftlint"; \
	fi

install: release ## Install the executable to /usr/local/bin
	@echo "Installing $(EXECUTABLE) to /usr/local/bin..."
	install -d /usr/local/bin
	install $(BUILD_DIR)/$(EXECUTABLE) /usr/local/bin/$(EXECUTABLE)
	@echo "Installed successfully!"

uninstall: ## Uninstall the executable from /usr/local/bin
	@echo "Uninstalling $(EXECUTABLE)..."
	rm -f /usr/local/bin/$(EXECUTABLE)
	@echo "Uninstalled successfully!"

xcode: ## Generate Xcode project
	@echo "Generating Xcode project..."
	swift package generate-xcodeproj

inspector: build ## Run with MCP Inspector
	@echo "Running with MCP Inspector..."
	@if command -v mcp-inspector >/dev/null 2>&1; then \
		mcp-inspector swift run $(EXECUTABLE); \
	else \
		echo "MCP Inspector not found. Install with: npm install -g @modelcontextprotocol/inspector"; \
	fi

deps-install: ## Install development dependencies (SwiftLint, swift-format)
	@echo "Installing development dependencies..."
	@if command -v brew >/dev/null 2>&1; then \
		brew install swiftlint swift-format; \
	else \
		echo "Homebrew not found. Please install manually."; \
	fi

check: test lint ## Run tests and linting

all: clean resolve build test ## Clean, resolve, build, and test

.PHONY: version
version: ## Show version information
	@echo "MCP-ZedChat Server"
	@echo "Version: 1.0.0"
	@echo ""
	@swift --version