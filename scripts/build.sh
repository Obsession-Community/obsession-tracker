#!/bin/bash

# Obsession Tracker Build Script
# Automated build script for different platforms and environments

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Default values
PLATFORM="android"
BUILD_TYPE="debug"
CLEAN=false

# Function to show usage
show_usage() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  -p, --platform PLATFORM    Target platform (android, ios, web, all)"
  echo "  -t, --type TYPE            Build type (debug, release)"
  echo "  -c, --clean                Clean before building"
  echo "  -h, --help                 Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0 -p android -t release   # Build Android release APK"
  echo "  $0 -p ios -t debug -c      # Clean and build iOS debug"
  echo "  $0 -p all -t release       # Build all platforms in release mode"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
  -p | --platform)
    PLATFORM="$2"
    shift 2
    ;;
  -t | --type)
    BUILD_TYPE="$2"
    shift 2
    ;;
  -c | --clean)
    CLEAN=true
    shift
    ;;
  -h | --help)
    show_usage
    exit 0
    ;;
  *)
    print_error "Unknown option: $1"
    show_usage
    exit 1
    ;;
  esac
done

# Validate platform
case $PLATFORM in
android | ios | web | all) ;;
*)
  print_error "Invalid platform: $PLATFORM"
  print_error "Valid platforms: android, ios, web, all"
  exit 1
  ;;
esac

# Validate build type
case $BUILD_TYPE in
debug | release) ;;
*)
  print_error "Invalid build type: $BUILD_TYPE"
  print_error "Valid build types: debug, release"
  exit 1
  ;;
esac

print_status "Starting Obsession Tracker build process..."
print_status "Platform: $PLATFORM"
print_status "Build Type: $BUILD_TYPE"
print_status "Clean: $CLEAN"

# Check if Flutter is available
if ! command -v flutter &>/dev/null; then
  print_error "Flutter is not installed or not in PATH"
  exit 1
fi

# Clean if requested
if [ "$CLEAN" = true ]; then
  print_status "Cleaning project..."
  flutter clean
  flutter pub get
fi

# Run pre-build checks
print_status "Running pre-build checks..."
flutter analyze
if [ $? -ne 0 ]; then
  print_warning "Static analysis found issues, but continuing..."
fi

# Run tests
print_status "Running tests..."
flutter test
if [ $? -ne 0 ]; then
  print_warning "Some tests failed, but continuing..."
fi

# Function to build for specific platform
build_platform() {
  local platform=$1
  local build_type=$2

  print_status "Building for $platform ($build_type)..."

  case $platform in
  android)
    if [ "$build_type" = "release" ]; then
      flutter build apk --release
      print_success "Android APK built successfully"
      print_status "APK location: build/app/outputs/flutter-apk/app-release.apk"
    else
      flutter build apk --debug
      print_success "Android debug APK built successfully"
      print_status "APK location: build/app/outputs/flutter-apk/app-debug.apk"
    fi
    ;;
  ios)
    if [[ "$OSTYPE" != "darwin"* ]]; then
      print_error "iOS builds are only supported on macOS"
      return 1
    fi
    if [ "$build_type" = "release" ]; then
      flutter build ios --release --no-codesign
      print_success "iOS release build completed"
    else
      flutter build ios --debug --no-codesign
      print_success "iOS debug build completed"
    fi
    ;;
  web)
    if [ "$build_type" = "release" ]; then
      flutter build web --release
      print_success "Web release build completed"
      print_status "Web build location: build/web/"
    else
      flutter build web --debug
      print_success "Web debug build completed"
      print_status "Web build location: build/web/"
    fi
    ;;
  esac
}

# Build for requested platform(s)
if [ "$PLATFORM" = "all" ]; then
  build_platform "android" "$BUILD_TYPE"
  build_platform "web" "$BUILD_TYPE"
  if [[ "$OSTYPE" == "darwin"* ]]; then
    build_platform "ios" "$BUILD_TYPE"
  else
    print_warning "Skipping iOS build (not on macOS)"
  fi
else
  build_platform "$PLATFORM" "$BUILD_TYPE"
fi

print_success "Build process completed!"

# Show build outputs
echo ""
print_status "Build outputs:"
if [ "$PLATFORM" = "android" ] || [ "$PLATFORM" = "all" ]; then
  if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
    echo "  📱 Android APK: build/app/outputs/flutter-apk/app-release.apk"
  fi
  if [ -f "build/app/outputs/flutter-apk/app-debug.apk" ]; then
    echo "  📱 Android APK: build/app/outputs/flutter-apk/app-debug.apk"
  fi
fi

if [ "$PLATFORM" = "web" ] || [ "$PLATFORM" = "all" ]; then
  if [ -d "build/web" ]; then
    echo "  🌐 Web build: build/web/"
  fi
fi

if [ "$PLATFORM" = "ios" ] || [ "$PLATFORM" = "all" ]; then
  if [ -d "build/ios" ]; then
    echo "  🍎 iOS build: build/ios/"
  fi
fi
