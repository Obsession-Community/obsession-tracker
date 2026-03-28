#!/bin/bash

# Obsession Tracker iOS Deployment Script
# Usage: ./scripts/deploy_ios.sh

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command -v flutter &> /dev/null; then
        print_error "Flutter is not installed or not in PATH"
        exit 1
    fi
    
    if ! command -v bundle &> /dev/null; then
        print_error "Bundler is not installed. Run 'gem install bundler'"
        exit 1
    fi
    
    # Check if we are in the root of the project
    if [ ! -f "pubspec.yaml" ]; then
        print_error "Please run this script from the root of the project"
        exit 1
    fi

    print_status "Prerequisites check passed"
}

# Main deployment flow
main() {
    check_prerequisites

    # 1. Flutter Clean & Get
    print_status "Cleaning and getting dependencies..."
    flutter clean
    flutter pub get

    # 2. Run Tests
    print_status "Running tests..."
    flutter test

    # 3. Calculate Build Number
    print_status "Calculating build number..."
    BUILD_NUMBER=$(git rev-list --count HEAD)
    print_status "Build number: $BUILD_NUMBER"

    # 4. Update pubspec.yaml
    print_status "Updating version in pubspec.yaml..."
    # Extract current version (e.g., 0.1.0)
    VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //' | cut -d'+' -f1)
    
    # Update pubspec.yaml with new build number (Mac compatible sed)
    sed -i '' "s/^version:.*/version: $VERSION+$BUILD_NUMBER/" pubspec.yaml
    print_status "Updated version to $VERSION+$BUILD_NUMBER"

    # 5. Run Fastlane
    print_status "Running Fastlane..."
    cd ios
    
    # Ensure gems are installed
    bundle install
    
    # Run fastlane beta
    # Note: This assumes you have your Match and App Store Connect credentials set up locally
    # or in your environment variables.
    bundle exec fastlane beta build_number:$BUILD_NUMBER
    
    cd ..

    # 6. Git Tag
    print_status "Creating git tag..."
    TAG="v$VERSION-build.$BUILD_NUMBER"
    
    # Check if tag exists
    if git rev-parse "$TAG" >/dev/null 2>&1; then
        print_warning "Tag $TAG already exists, skipping tagging"
    else
        git tag -a "$TAG" -m "TestFlight build $BUILD_NUMBER"
        # Optional: push tag
        # git push origin "$TAG"
        print_status "Created tag $TAG. Don't forget to push it: git push origin $TAG"
    fi

    print_status "🎉 iOS Deployment to TestFlight completed successfully!"
}

main "$@"
