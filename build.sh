#!/bin/bash

# DaVinci Transcript Processor Build Script
# Created on 2025-06-09 23:04:05 (UTC)
# For user: markobosko-git

# Output formatting
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Project Configuration - all relative to current directory
APP_NAME="DaVinci Transcript Processor"
VERSION="1.0.0"
BUILD_DIR="./build"
PRODUCT_DIR="$BUILD_DIR/Products"
APP_DIR="$PRODUCT_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
LOG_FILE="$BUILD_DIR/build_log.txt"

# Print banner
echo -e "${BLUE}=====================================================${NC}"
echo -e "${BLUE}    DaVinci Transcript Processor - Build Script      ${NC}"
echo -e "${BLUE}=====================================================${NC}"
echo -e "${BLUE}Date: 2025-06-09 23:04:05 (UTC)${NC}"
echo -e "${BLUE}User: markobosko-git${NC}"
echo -e "${BLUE}Version: $VERSION${NC}"
echo -e "${BLUE}Architecture: Apple Silicon (arm64)${NC}"
echo -e "${BLUE}=====================================================${NC}"
echo ""

# Function to display success message
success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to display error message and exit
error() {
    echo -e "${RED}✗ $1${NC}"
    echo -e "${YELLOW}For detailed error information, check: $LOG_FILE${NC}"
    exit 1
}

# Function to display info message
info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

# Progress indicator function
show_progress() {
    local percent=$1
    local width=30
    local num=$((width * percent / 100))
    local bar=$(printf "%${num}s" | tr ' ' '=')
    local empty=$(printf "%$((width - num))s" | tr ' ' ' ')
    echo -ne "\r${YELLOW}[${bar}${empty}] ${percent}%${NC}"
}

# Step 1: Clean and prepare build directory
echo -e "${YELLOW}[1/6] Preparing build environment...${NC}"
if [ -d "$BUILD_DIR" ]; then
    echo "Cleaning previous build artifacts..."
    rm -rf "$BUILD_DIR"
fi
mkdir -p "$BUILD_DIR"
mkdir -p "$PRODUCT_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"
success "Build directory prepared!"

# Step 2: Find Swift files from current directory structure
echo -e "${YELLOW}[2/6] Finding Swift files...${NC}"

# Find all Swift files in the directory structure
find_result=$(find . -name "*.swift" -type f -not -path "./build/*" | sort)

# If no files were found, exit with error
if [ -z "$find_result" ]; then
    error "No Swift files found! Make sure you're in the correct directory."
fi

# Save the list of files to a file for later use
echo "$find_result" > "$BUILD_DIR/swift_files.txt"

# Count the number of files
SWIFT_FILE_COUNT=$(wc -l < "$BUILD_DIR/swift_files.txt")

# Report success
success "Found $SWIFT_FILE_COUNT Swift files!"

# Step 3: Check file structure
echo -e "${YELLOW}[3/6] Analyzing code structure...${NC}"

# Display directory structure for verification
echo "Directory structure:"
directories=$(find . -type d -not -path "*/\.*" -not -path "*/build*" | sort)

# Count directories at the top level (App, Models, Views, etc.)
top_dirs=$(echo "$directories" | grep -E "^\./[^/]+$" | wc -l)
echo "Found $top_dirs top-level directories"

# Count files in each category
app_files=$(grep "/App/" "$BUILD_DIR/swift_files.txt" | wc -l)
model_files=$(grep "/Models/" "$BUILD_DIR/swift_files.txt" | wc -l)
view_files=$(grep "/Views/" "$BUILD_DIR/swift_files.txt" | wc -l)

# Display file counts by category
echo "Swift files by category:"
echo "- App: $app_files"
echo "- Models: $model_files"
echo "- Views: $view_files"

# Check for import statements
echo "Checking import statements..."
grep -r "import " --include="*.swift" . | grep -v "/build/" | sort | uniq > "$BUILD_DIR/import_statements.txt"

success "Code analysis complete!"

# Step 4: Build application
echo -e "${YELLOW}[4/6] Building application...${NC}"
echo "This may take a few moments..."

# Get path to Swift SDK
SWIFT_SDK_PATH=$(xcrun --show-sdk-path --sdk macosx)

# Create a build log header
echo "======== BUILD LOG ========" > "$LOG_FILE"
echo "Date: $(date)" >> "$LOG_FILE"
echo "Swift Files: $SWIFT_FILE_COUNT" >> "$LOG_FILE"
echo "SDK Path: $SWIFT_SDK_PATH" >> "$LOG_FILE"
echo "==========================" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# Process each file for type checking with progress reporting
echo "Phase 1: Type checking files"
total_files=$SWIFT_FILE_COUNT
current=0
success_count=0
typechecking_errors=0

while read -r file; do
    ((current++))
    percent=$((current * 100 / total_files))
    show_progress $percent
    
    # Extract just the filename for the log
    filename=$(basename "$file")
    echo "Checking: $filename" >> "$LOG_FILE"
    
    # Type check the file (fixed the redirection syntax)
    xcrun swiftc -typecheck "$file" -sdk "$SWIFT_SDK_PATH" >> "$LOG_FILE" 2>&1
    if [ $? -eq 0 ]; then
        ((success_count++))
    else
        ((typechecking_errors++))
        echo "Error in file: $filename" >> "$LOG_FILE"
    fi
    
    # Brief pause to make progress visible
    sleep 0.01
done < "$BUILD_DIR/swift_files.txt"
echo -e "\r${GREEN}Type checking complete: $success_count/$total_files files passed${NC}"

if [ $typechecking_errors -gt 0 ]; then
    error "Type checking failed for $typechecking_errors files. Check the log for details."
fi

# Extract all Swift files into a variable
SWIFT_FILES=$(cat "$BUILD_DIR/swift_files.txt")

# Show progress for compilation phase
echo "Phase 2: Compiling application..."
show_progress 0
echo "" >> "$LOG_FILE"
echo "Starting main compilation..." >> "$LOG_FILE"

# Run the Swift compiler with comprehensive settings (fixed the redirection syntax)
xcrun swiftc -o "$MACOS_DIR/DaVinciTranscriptProcessor" \
    $SWIFT_FILES \
    -target arm64-apple-macosx12.0 \
    -sdk "$SWIFT_SDK_PATH" \
    -F "$SWIFT_SDK_PATH/System/Library/Frameworks" \
    -module-name DaVinciTranscriptProcessor \
    -emit-executable \
    -Onone \
    -g >> "$LOG_FILE" 2>&1 &

# Track compilation progress with a simple animation
pid=$!
progress=0
while kill -0 $pid 2>/dev/null; do
    if [ $progress -lt 90 ]; then
        progress=$((progress + 1))
    fi
    show_progress $progress
    sleep 0.2
done

# Check if the build was successful
if ! wait $pid || [ ! -f "$MACOS_DIR/DaVinciTranscriptProcessor" ]; then
    show_progress 100
    echo ""
    error "Build failed! Check the log for details."
fi

# Show 100% when complete
show_progress 100
echo ""
success "Application built successfully!"

# Step 5: Create app bundle
echo -e "${YELLOW}[5/6] Creating app bundle...${NC}"

# Try to find Info.plist in various locations
info_plist_locations=("./Resources/Info.plist" "./Info.plist")
info_plist_found=false

for location in "${info_plist_locations[@]}"; do
    if [ -f "$location" ]; then
        echo "Found Info.plist at $location"
        cp "$location" "$CONTENTS_DIR/Info.plist"
        info_plist_found=true
        break
    fi
done

# Create a default Info.plist if not found
if [ "$info_plist_found" = false ]; then
    echo "Creating default Info.plist"
    cat > "$CONTENTS_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>DaVinciTranscriptProcessor</string>
    <key>CFBundleIdentifier</key>
    <string>com.markobosko-git.DaVinciTranscriptProcessor</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.video</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
</dict>
</plist>
EOF
fi

# Copy resource files
resource_dirs=("./Resources" "./Assets")
for res_dir in "${resource_dirs[@]}"; do
    if [ -d "$res_dir" ]; then
        echo "Copying resources from $res_dir"
        find "$res_dir" -type f -not -name "*.swift" -not -name "Info.plist" -exec cp {} "$RESOURCES_DIR/" \;
    fi
done

# Create Assets directory structure if not present
mkdir -p "$RESOURCES_DIR/Assets.xcassets/AppIcon.appiconset"

# Add PkgInfo file
echo "APPL????" > "$CONTENTS_DIR/PkgInfo"

# Make executable
chmod +x "$MACOS_DIR/DaVinciTranscriptProcessor"

success "App bundle created!"

# Step 6: Package the app
echo -e "${YELLOW}[6/6] Creating distribution package...${NC}"

# Create a zip file
echo -ne "${YELLOW}Creating zip archive...${NC}"
(cd "$PRODUCT_DIR" && zip -r -q -y "$BUILD_DIR/$APP_NAME-$VERSION-arm64.zip" "./$APP_NAME.app")

if [ $? -ne 0 ]; then
    error "Failed to create zip package!"
fi
echo -e "\r${GREEN}Zip archive created!                  ${NC}"

# Final summary
echo ""
echo -e "${BLUE}=====================================================${NC}"
echo -e "${GREEN}Build completed successfully!${NC}"
echo -e "${BLUE}----------------------------------------------------${NC}"
echo -e "App location: $APP_DIR"
echo -e "Zip package: $BUILD_DIR/$APP_NAME-$VERSION-arm64.zip"
echo -e "Build log: $LOG_FILE"
echo -e "${BLUE}=====================================================${NC}"

echo -e "${YELLOW}Note:${NC} This build is specifically for Apple Silicon Macs."
echo -e "To run the app, you may need to:"
echo -e "1. Right-click the app and select \"Open\""
echo -e "2. Confirm opening the app when prompted"
echo -e "${BLUE}=====================================================${NC}"

exit 0