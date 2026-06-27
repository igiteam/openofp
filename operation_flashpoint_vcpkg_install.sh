#!/bin/bash
# ============================================
# Operation Flashpoint - Cold War Crisis
# vcpkg Build Script for macOS
# ============================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}Operation Flashpoint - Cold War Crisis${NC}"
echo -e "${BLUE}Build Script for macOS${NC}"
echo -e "${BLUE}============================================${NC}"

# ============================================
# Step 1: Install Dependencies
# ============================================
echo -e "${YELLOW}[1/7] Installing system dependencies...${NC}"

if ! command -v brew &> /dev/null; then
    echo -e "${RED}Homebrew not found! Installing...${NC}"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

brew update
brew install cmake git

echo -e "${GREEN}✓ System dependencies installed${NC}"

# ============================================
# Step 2: Install vcpkg
# ============================================
echo -e "${YELLOW}[2/7] Installing vcpkg...${NC}"

if [ ! -d "$HOME/vcpkg" ]; then
    git clone https://github.com/Microsoft/vcpkg.git ~/vcpkg
    cd ~/vcpkg
    ./bootstrap-vcpkg.sh
else
    echo -e "${GREEN}✓ vcpkg already installed${NC}"
    cd ~/vcpkg
    git pull
    ./bootstrap-vcpkg.sh
fi

# Set VCPKG_ROOT permanently
if ! grep -q "VCPKG_ROOT" ~/.zshrc 2>/dev/null; then
    echo 'export VCPKG_ROOT=~/vcpkg' >> ~/.zshrc
    echo 'export PATH="$VCPKG_ROOT:$PATH"' >> ~/.zshrc
fi

if ! grep -q "VCPKG_ROOT" ~/.bash_profile 2>/dev/null; then
    echo 'export VCPKG_ROOT=~/vcpkg' >> ~/.bash_profile
    echo 'export PATH="$VCPKG_ROOT:$PATH"' >> ~/.bash_profile
fi

export VCPKG_ROOT=~/vcpkg
export PATH="$VCPKG_ROOT:$PATH"

echo -e "${GREEN}✓ vcpkg installed at ~/vcpkg${NC}"

# ============================================
# Step 3: Navigate to Source
# ============================================
echo -e "${YELLOW}[3/7] Locating source code...${NC}"

# Try to find the source automatically
if [ -f "CMakeLists.txt" ] && grep -q "cwr" CMakeLists.txt 2>/dev/null; then
    SOURCE_DIR="$(pwd)"
    echo -e "${GREEN}✓ Found source in current directory: $SOURCE_DIR${NC}"
else
    echo -e "${YELLOW}Please enter the path to the Operation Flashpoint source code:${NC}"
    read -p "Path: " SOURCE_DIR
    
    if [ ! -f "$SOURCE_DIR/CMakeLists.txt" ]; then
        echo -e "${RED}Error: CMakeLists.txt not found in $SOURCE_DIR${NC}"
        exit 1
    fi
fi

cd "$SOURCE_DIR"
echo -e "${GREEN}✓ Working in: $(pwd)${NC}"

# ============================================
# Step 4: Install Project Dependencies
# ============================================
echo -e "${YELLOW}[4/7] Installing project dependencies via vcpkg...${NC}"

# Check if vcpkg.json exists
if [ ! -f "vcpkg.json" ]; then
    echo -e "${RED}Error: vcpkg.json not found in $(pwd)${NC}"
    echo -e "${YELLOW}Creating default vcpkg.json...${NC}"
    
    cat > vcpkg.json << 'EOF'
{
  "name": "cwr",
  "version": "1.0",
  "dependencies": [
    "catch2",
    "cjson",
    { "name": "curl", "features": ["ssl"] },
    "glslang",
    "cli11",
    "stb",
    "mimalloc",
    "zstd",
    "sdl3",
    "openal-soft",
    "opus",
    "libogg",
    "libvorbis",
    "faudio"
  ],
  "builtin-baseline": "15cd15b0da3c48a0c7720e4c87e0b6030334feed",
  "overrides": [
    {
      "name": "catch2",
      "version": "3.5.2"
    },
    {
      "name": "cli11",
      "version": "2.4.0"
    },
    {
      "name": "mimalloc",
      "version": "2.2.4"
    }
  ]
}
EOF
    echo -e "${GREEN}✓ Created vcpkg.json${NC}"
fi

# Install dependencies
~/vcpkg/vcpkg install || {
    echo -e "${YELLOW}Retrying vcpkg install with common fixes...${NC}"
    cd ~/vcpkg
    git pull
    ./bootstrap-vcpkg.sh
    cd "$SOURCE_DIR"
    ~/vcpkg/vcpkg install
}

echo -e "${GREEN}✓ Project dependencies installed${NC}"

# ============================================
# Step 5: Configure CMake Build
# ============================================
echo -e "${YELLOW}[5/7] Configuring CMake build...${NC}"

# Clean build directory if exists
if [ -d "build" ]; then
    echo -e "${YELLOW}Build directory exists. Remove and recreate? (y/n)${NC}"
    read -p "> " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf build
    fi
fi

mkdir -p build
cd build

# Detect CPU cores for parallel build
if [[ "$OSTYPE" == "darwin"* ]]; then
    CPU_CORES=$(sysctl -n hw.ncpu)
else
    CPU_CORES=$(nproc)
fi
echo -e "${GREEN}✓ Detected $CPU_CORES CPU cores${NC}"

# Configure with vcpkg
cmake .. \
    -DCMAKE_TOOLCHAIN_FILE=~/vcpkg/scripts/buildsystems/vcpkg.cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_FLAGS="-std=c++17"

echo -e "${GREEN}✓ CMake configured${NC}"

# ============================================
# Step 6: Compile
# ============================================
echo -e "${YELLOW}[6/7] Compiling (this will take 10-30 minutes)...${NC}"

# Build everything
cmake --build . --config Release -j$CPU_CORES

echo -e "${GREEN}✓ Build complete!${NC}"

# ============================================
# Step 7: Run It
# ============================================
echo -e "${YELLOW}[7/7] Build successful!${NC}"
echo -e "${BLUE}============================================${NC}"
echo -e "${GREEN}✓ Operation Flashpoint compiled successfully!${NC}"
echo -e "${BLUE}============================================${NC}"

# Find executables
GAME_EXE=""
SERVER_EXE=""
STUDIO_EXE=""

if [ -f "apps/cwr/Game/Game" ]; then
    GAME_EXE="build/apps/cwr/Game/Game"
elif [ -f "apps/cwr/Game/Game.app/Contents/MacOS/Game" ]; then
    GAME_EXE="build/apps/cwr/Game/Game.app/Contents/MacOS/Game"
fi

if [ -f "apps/cwr/Server/Server" ]; then
    SERVER_EXE="build/apps/cwr/Server/Server"
fi

if [ -f "apps/tools/Studio/Studio" ]; then
    STUDIO_EXE="build/apps/tools/Studio/Studio"
fi

echo -e "${YELLOW}Executables:${NC}"
[ -n "$GAME_EXE" ] && echo -e "  Game:    $GAME_EXE"
[ -n "$SERVER_EXE" ] && echo -e "  Server:  $SERVER_EXE"
[ -n "$STUDIO_EXE" ] && echo -e "  Studio:  $STUDIO_EXE"
[ -z "$GAME_EXE" ] && [ -z "$SERVER_EXE" ] && [ -z "$STUDIO_EXE" ] && echo -e "  ${RED}No executables found! Check build output.${NC}"

echo -e "${BLUE}============================================${NC}"
echo -e "${YELLOW}To run the game:${NC}"
echo -e "  cd $(pwd)"
[ -n "$GAME_EXE" ] && echo -e "  ./$GAME_EXE"
echo -e "${BLUE}============================================${NC}"

# Ask if user wants to run
echo -e "${YELLOW}Run the game now? (y/n)${NC}"
read -p "> " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]] && [ -n "$GAME_EXE" ]; then
    echo -e "${GREEN}Starting Operation Flashpoint...${NC}"
    ./$GAME_EXE
fi

# ============================================
# Troubleshooting Tips
# ============================================
echo -e "${BLUE}============================================${NC}"
echo -e "${YELLOW}Troubleshooting tips:${NC}"
echo -e "1. If vcpkg fails: cd ~/vcpkg && git pull && ./bootstrap-vcpkg.sh"
echo -e "2. If CMake fails: rm -rf build && mkdir build && cd build && cmake .."
echo -e "3. If SDL3 not found: brew install sdl3"
echo -e "4. For Debug build: cmake .. -DCMAKE_BUILD_TYPE=Debug"
echo -e "5. VCPKG_ROOT is set to: $VCPKG_ROOT"
echo -e "${BLUE}============================================${NC}"