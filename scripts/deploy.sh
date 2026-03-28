#!/bin/bash

# Obsession Tracker Deployment Script
# Deploys iOS, Android, and/or macOS with synchronized build numbers
#
# Usage:
#   ./scripts/deploy.sh                    # Deploy all platforms (iOS, Android, macOS)
#   ./scripts/deploy.sh ios                # Deploy iOS only
#   ./scripts/deploy.sh android            # Deploy Android only
#   ./scripts/deploy.sh macos              # Deploy macOS only
#   ./scripts/deploy.sh mobile             # Deploy iOS and Android only
#   ./scripts/deploy.sh --no-test          # Skip tests
#   ./scripts/deploy.sh --dry-run          # Show what would be done without deploying
#   ./scripts/deploy.sh --skip-release-notes  # Skip release notes check

set -e

# Load shell environment for rbenv/nvm/etc (needed for correct Ruby version)
# Only source .zshenv (not .zshrc which may contain zsh-specific interactive commands)
if [ -f "$HOME/.zshenv" ]; then
    source "$HOME/.zshenv" 2>/dev/null || true
fi

# Initialize rbenv if available (sets up shims and shell function)
if command -v rbenv &> /dev/null; then
    eval "$(rbenv init - bash 2>/dev/null || true)"
fi

# Get the project root (where pubspec.yaml is)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

# Note: fastlane/.env is automatically loaded by Fastlane when it runs

# Configuration
PLATFORM=""
SKIP_TESTS=false
DRY_RUN=false
SKIP_RELEASE_NOTES=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --no-test|--skip-tests)
            SKIP_TESTS=true
            ;;
        --dry-run)
            DRY_RUN=true
            ;;
        --skip-release-notes)
            SKIP_RELEASE_NOTES=true
            ;;
        ios|android|macos|mobile|all)
            PLATFORM=$arg
            ;;
    esac
done

# Default platform if not specified
if [ -z "$PLATFORM" ]; then
    PLATFORM="all"
fi

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Get the project root (where pubspec.yaml is)
get_project_root() {
    # Navigate to script directory, then up to project root
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
    echo "$PROJECT_ROOT"
}

# Read current version and build number from pubspec.yaml
get_current_version() {
    grep '^version:' pubspec.yaml | sed 's/version: //'
}

get_version_name() {
    get_current_version | cut -d'+' -f1
}

get_build_number() {
    get_current_version | cut -d'+' -f2
}

# Increment build number and update pubspec.yaml
# Sets BUILD_NUMBER global variable
increment_build_number() {
    local current_build=$(get_build_number)
    BUILD_NUMBER=$((current_build + 1))
    local version_name=$(get_version_name)

    print_info "Incrementing build number: $current_build → $BUILD_NUMBER"

    if [ "$DRY_RUN" = true ]; then
        print_warning "DRY RUN: Would update pubspec.yaml to version: $version_name+$BUILD_NUMBER"
    else
        # Update pubspec.yaml (Mac compatible sed)
        sed -i '' "s/^version:.*/version: $version_name+$BUILD_NUMBER/" pubspec.yaml
        print_status "Updated pubspec.yaml to version: $version_name+$BUILD_NUMBER"
    fi
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."

    if ! command -v flutter &> /dev/null; then
        print_error "Flutter is not installed or not in PATH"
        exit 1
    fi

    if [ "$PLATFORM" = "ios" ] || [ "$PLATFORM" = "mobile" ] || [ "$PLATFORM" = "all" ]; then
        if ! command -v bundle &> /dev/null; then
            print_error "Bundler is not installed. Run 'gem install bundler'"
            exit 1
        fi
    fi

    # Check if we are in the root of the project
    if [ ! -f "pubspec.yaml" ]; then
        print_error "Please run this script from the root of the project (obsession-tracker/)"
        exit 1
    fi

    print_status "Prerequisites check passed"
}

# Check if release notes have been updated since last release
check_release_notes() {
    if [ "$SKIP_RELEASE_NOTES" = true ]; then
        print_warning "Skipping release notes check (--skip-release-notes flag)"
        return 0
    fi

    print_status "Checking release notes..."

    local ios_notes="fastlane/metadata/en-US/release_notes.txt"
    local android_notes="fastlane/metadata/android/en-US/changelogs/default.txt"

    # Find the last "Bump build number" commit (indicates last release)
    local last_release_commit=$(git log --oneline --grep="Bump build number" -1 --format="%H" 2>/dev/null)

    if [ -z "$last_release_commit" ]; then
        # No previous release found, check if files exist
        if [ ! -f "$ios_notes" ]; then
            print_error "iOS release notes not found: $ios_notes"
            exit 1
        fi
        if [ ! -f "$android_notes" ]; then
            print_error "Android release notes not found: $android_notes"
            exit 1
        fi
        print_status "First release - release notes found"
        return 0
    fi

    # Check if release notes were modified since last release
    # Include both committed changes AND uncommitted working directory changes
    local ios_changed=$(git diff --name-only "$last_release_commit" HEAD -- "$ios_notes" 2>/dev/null)
    local ios_uncommitted=$(git diff --name-only -- "$ios_notes" 2>/dev/null)
    if [ -n "$ios_uncommitted" ]; then
        ios_changed="$ios_uncommitted"
    fi

    local android_changed=$(git diff --name-only "$last_release_commit" HEAD -- "$android_notes" 2>/dev/null)
    local android_uncommitted=$(git diff --name-only -- "$android_notes" 2>/dev/null)
    if [ -n "$android_uncommitted" ]; then
        android_changed="$android_uncommitted"
    fi

    local missing_updates=""

    # iOS/macOS share release notes (Universal Purchase)
    if [ -z "$ios_changed" ] && [ "$PLATFORM" != "android" ]; then
        missing_updates="iOS/macOS"
    fi

    if [ -z "$android_changed" ] && [ "$PLATFORM" != "ios" ] && [ "$PLATFORM" != "macos" ]; then
        if [ -n "$missing_updates" ]; then
            missing_updates="$missing_updates and Android"
        else
            missing_updates="Android"
        fi
    fi

    if [ -n "$missing_updates" ]; then
        echo ""
        print_error "Release notes have NOT been updated since last release!"
        echo ""
        print_info "Please update the following before deploying:"
        if [[ "$missing_updates" == *"iOS"* ]]; then
            print_info "  • $ios_notes (≤4000 chars) - shared by iOS and macOS"
        fi
        if [[ "$missing_updates" == *"Android"* ]]; then
            print_info "  • $android_notes (≤500 chars)"
        fi
        echo ""
        print_info "Last release commit: $(git log --oneline -1 $last_release_commit)"
        echo ""
        exit 1
    fi

    # Check Android changelog length (must be ≤500 chars)
    if [ "$PLATFORM" != "ios" ] && [ "$PLATFORM" != "macos" ]; then
        local android_length=$(wc -c < "$android_notes" | tr -d ' ')
        if [ "$android_length" -gt 500 ]; then
            print_error "Android changelog is too long: ${android_length} chars (max 500)"
            print_info "File: $android_notes"
            exit 1
        fi
    fi

    print_status "Release notes are up to date"
}

# Run Flutter tests
run_tests() {
    if [ "$SKIP_TESTS" = true ]; then
        print_warning "Skipping tests (--no-test flag)"
        return 0
    fi

    print_status "Running Flutter tests..."

    if [ "$DRY_RUN" = true ]; then
        print_warning "DRY RUN: Would run 'flutter test'"
    else
        flutter test
        print_status "All tests passed"
    fi
}

# Prepare Flutter build
prepare_build() {
    print_status "Preparing Flutter build..."

    if [ "$DRY_RUN" = true ]; then
        print_warning "DRY RUN: Would run 'flutter pub get'"
    else
        # Note: flutter clean is handled by each Fastlane lane
        # This allows lanes to be run independently with expected behavior
        flutter pub get
        print_status "Flutter dependencies ready"
    fi
}

# Deploy iOS
deploy_ios() {
    local build_number=$1

    print_status "Deploying iOS (build $build_number)..."

    if [ "$DRY_RUN" = true ]; then
        print_warning "DRY RUN: Would deploy iOS build $build_number to TestFlight"
        return 0
    fi

    # Ensure gems are installed (includes CocoaPods and Fastlane)
    print_info "Installing Ruby gems..."
    bundle install

    # Run pod install using bundled CocoaPods to avoid Ruby version conflicts
    # Uses git-based specs repo (configured in Podfile) instead of CDN for reliability
    print_info "Running pod install via Bundler..."
    bundle exec pod install --project-directory=ios

    # Run fastlane ios beta with the build number (from project root)
    print_info "Running Fastlane..."
    bundle exec fastlane ios beta build_number:$build_number

    print_status "iOS deployment completed"
}

# Check Android signing is configured
check_android_signing() {
    if [ ! -f "android/key.properties" ]; then
        print_error "android/key.properties not found"
        print_info "Create it with:"
        print_info "  storePassword=your_password"
        print_info "  keyPassword=your_password"
        print_info "  keyAlias=your_alias"
        print_info "  storeFile=/full/path/to/fastlane/obsessiontracker.jks"
        return 1
    fi
    return 0
}

# Deploy Android
deploy_android() {
    local build_number=$1
    local version_name=$(get_version_name)

    print_status "Deploying Android (build $build_number)..."

    if [ "$DRY_RUN" = true ]; then
        print_warning "DRY RUN: Would build Android AAB and upload to Google Play internal track"
        return 0
    fi

    # Check Android signing is configured
    if ! check_android_signing; then
        exit 1
    fi

    # Check if Google Play credentials are configured
    if [ ! -f "fastlane/google-play-key.json" ] && [ -z "$SUPPLY_JSON_KEY" ]; then
        print_warning "Google Play credentials not found. Building locally only."

        # Build Android release with Flutter
        flutter build appbundle --release --build-number=$build_number --build-name=$version_name
        print_status "Android App Bundle built: build/app/outputs/bundle/release/app-release.aab"

        # Also build APK for testing
        flutter build apk --release --build-number=$build_number --build-name=$version_name
        print_status "Android APK built: build/app/outputs/flutter-apk/app-release.apk"

        print_warning "To enable automatic upload, add google-play-key.json to fastlane/"
        print_info "Get credentials from: Google Play Console → Setup → API access → Service account"
    else
        # Use Fastlane for build and upload
        print_info "Running Fastlane for Android..."
        bundle exec fastlane android beta build_number:$build_number
    fi

    print_status "Android deployment completed"
}

# Deploy macOS
deploy_macos() {
    local build_number=$1
    local version_name=$(get_version_name)

    print_status "Deploying macOS (build $build_number)..."

    if [ "$DRY_RUN" = true ]; then
        print_warning "DRY RUN: Would deploy macOS build $build_number to TestFlight"
        return 0
    fi

    # Ensure gems are installed
    print_info "Installing Ruby gems..."
    bundle install

    print_info "Building macOS release..."
    flutter build macos --release

    # Archive with xcodebuild
    local archive_path="build/macos/ObsessionTracker.xcarchive"

    print_info "Archiving macOS app..."
    xcodebuild \
        -workspace macos/Runner.xcworkspace \
        -scheme Runner \
        -configuration Release \
        -archivePath "$archive_path" \
        -allowProvisioningUpdates \
        archive

    # Fix malformed framework symlink (ITMS-90291)
    # sqlite3arm64macos.framework has Resources -> Versions/A/Resources
    # but Apple requires Resources -> Versions/Current/Resources
    local framework_path="$archive_path/Products/Applications/obsession_tracker.app/Contents/Frameworks/sqlite3arm64macos.framework"
    if [ -d "$framework_path" ]; then
        local resources_link="$framework_path/Resources"
        if [ -L "$resources_link" ]; then
            local current_target=$(readlink "$resources_link")
            if [[ "$current_target" == *"Versions/A/"* ]]; then
                print_info "Fixing sqlite3arm64macos.framework symlink..."
                rm "$resources_link"
                ln -s "Versions/Current/Resources" "$resources_link"
                print_status "Fixed Resources symlink: now points to Versions/Current/Resources"
            fi
        fi
    fi

    # Create export options plist for App Store upload
    local export_plist="build/macos/ExportOptions.plist"
    cat > "$export_plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>destination</key>
    <string>upload</string>
    <key>teamID</key>
    <string>686BSNR73Z</string>
</dict>
</plist>
EOF

    print_info "Exporting and uploading to TestFlight..."
    xcodebuild \
        -exportArchive \
        -archivePath "$archive_path" \
        -exportOptionsPlist "$export_plist" \
        -allowProvisioningUpdates

    print_status "macOS deployment completed"
}

# Create git tag
create_git_tag() {
    local build_number=$1
    local version_name=$(get_version_name)
    local tag="v$version_name-build.$build_number"

    if [ "$DRY_RUN" = true ]; then
        print_warning "DRY RUN: Would create git tag: $tag"
        return 0
    fi

    # Check if tag exists
    if git rev-parse "$tag" >/dev/null 2>&1; then
        print_warning "Tag $tag already exists, skipping tagging"
    else
        git add pubspec.yaml
        git commit -m "Bump build number to $build_number" || true  # May fail if no changes
        git tag -a "$tag" -m "Release build $build_number"
        print_status "Created tag $tag"
        print_info "Push with: git push origin main && git push origin $tag"
    fi
}

# Main deployment flow
main() {
    echo ""
    echo "🚀 Obsession Tracker Deployment"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Change to project root
    cd "$(get_project_root)"

    print_info "Platform: $PLATFORM"
    print_info "Skip tests: $SKIP_TESTS"
    print_info "Skip release notes check: $SKIP_RELEASE_NOTES"
    print_info "Dry run: $DRY_RUN"
    print_info "Current version: $(get_current_version)"
    echo ""

    check_prerequisites

    # Check release notes are updated (aborts if not)
    check_release_notes

    # Increment build number (sets BUILD_NUMBER global variable)
    increment_build_number

    # Run tests
    run_tests

    # Prepare build
    prepare_build

    # Deploy based on platform
    case $PLATFORM in
        "ios")
            deploy_ios $BUILD_NUMBER
            ;;
        "android")
            deploy_android $BUILD_NUMBER
            ;;
        "macos")
            deploy_macos $BUILD_NUMBER
            ;;
        "mobile")
            deploy_ios $BUILD_NUMBER
            # Skip flutter clean for Android since iOS already cleaned
            export SKIP_FLUTTER_CLEAN=true
            deploy_android $BUILD_NUMBER
            ;;
        "all")
            deploy_ios $BUILD_NUMBER
            # Skip flutter clean for subsequent builds
            export SKIP_FLUTTER_CLEAN=true
            deploy_android $BUILD_NUMBER
            deploy_macos $BUILD_NUMBER
            ;;
        *)
            print_error "Invalid platform: $PLATFORM"
            print_warning "Valid options: ios, android, macos, mobile, all"
            exit 1
            ;;
    esac

    # Create git tag
    create_git_tag $BUILD_NUMBER

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_status "🎉 Deployment completed successfully!"
    echo ""
    print_info "Version: $(get_version_name)"
    print_info "Build: $BUILD_NUMBER"
    echo ""
}

main "$@"
