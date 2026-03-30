#!/bin/bash

# Obsession Tracker Development Setup Script
# This script helps set up the development environment

set -e

echo "🏗️  Setting up Obsession Tracker development environment..."

# Check if Flutter is installed
if ! command -v flutter &>/dev/null; then
  echo "❌ Flutter is not installed. Please install Flutter first:"
  echo "   https://docs.flutter.dev/get-started/install"
  exit 1
fi

# Check Flutter version
echo "📱 Checking Flutter version..."
flutter --version

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
  echo "❌ pubspec.yaml not found. Please run this script from the project root."
  exit 1
fi

# Clean any existing builds
echo "🧹 Cleaning previous builds..."
flutter clean

# Get dependencies
echo "📦 Getting Flutter dependencies..."
flutter pub get

# Check for .env file
if [ ! -f ".env" ]; then
  echo "📝 Creating .env file from .env.example..."
  cp .env.example .env
  echo "✅ .env file created. Please review and configure as needed."
else
  echo "✅ .env file already exists."
fi

# Create necessary directories
echo "📁 Creating required directories..."
mkdir -p assets/icons
mkdir -p assets/images
mkdir -p assets/icons/waypoints
mkdir -p assets/icons/markers
mkdir -p assets/icons/ui
mkdir -p assets/audio
mkdir -p assets/animations
mkdir -p fonts

# Create assets placeholder files
touch assets/icons/.gitkeep
touch assets/images/.gitkeep
touch assets/icons/waypoints/.gitkeep
touch assets/icons/markers/.gitkeep
touch assets/icons/ui/.gitkeep
touch assets/audio/.gitkeep
touch assets/animations/.gitkeep
touch fonts/.gitkeep

# Run code generation (if applicable)
echo "🔧 Running code generation..."
flutter packages pub run build_runner build --delete-conflicting-outputs || echo "No code generation needed yet."

# Check for platform-specific setup
echo "🔍 Checking platform requirements..."

# Android setup
if [ -d "android" ]; then
  echo "✅ Android platform detected"
else
  echo "⚠️  Android platform not found. You may need to add it with:"
  echo "   flutter create --platforms android ."
fi

# iOS setup (only on macOS)
if [[ "$OSTYPE" == "darwin"* ]]; then
  if [ -d "ios" ]; then
    echo "✅ iOS platform detected"
  else
    echo "⚠️  iOS platform not found. You may need to add it with:"
    echo "   flutter create --platforms ios ."
  fi
else
  echo "ℹ️  iOS development only available on macOS"
fi

# Run doctor to check setup
echo "🩺 Running Flutter doctor..."
flutter doctor

# Run analyzer
echo "🔍 Running static analysis..."
flutter analyze || echo "⚠️  Some analysis issues found. Please review."

# Run tests
echo "🧪 Running tests..."
flutter test || echo "⚠️  Some tests failed. Please review."

echo ""
echo "🎉 Setup complete! Your Obsession Tracker development environment is ready."
echo ""
echo "Next steps:"
echo "1. Review and configure your .env file"
echo "2. Add any required assets to the assets/ directories"
echo "3. Install fonts in the fonts/ directory"
echo "4. Run 'flutter run' to start development"
echo ""
echo "Useful commands:"
echo "  flutter run          - Run the app in debug mode"
echo "  flutter test         - Run all tests"
echo "  flutter analyze      - Run static analysis"
echo "  flutter build apk    - Build APK for Android"
echo "  flutter build ios    - Build for iOS (macOS only)"
echo ""
