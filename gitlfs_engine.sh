#!/bin/bash
# =========================================================
# engine_gitlfs.sh
# Unified Git LFS tracking for multiple game engines
# Ensures LFS always downloads files (--no-skip-smudge)
# Interactive selection if engine not provided
# =========================================================
# Usage: ./engine_gitlfs.sh [engine] <path-to-repo> [push]
# Engines supported: ue3 | goldsrc | source | idtech3 | idtech4 | cryengine1 | thiefdark | sithengine | ofp
# Optional third argument "push" will push commits to origin.

set -euo pipefail

ENGINE="${1:-}"
REPO_PATH="${2:-}"
DO_PUSH="${3:-}"

# ------------------ Supported engines ------------------
SUPPORTED_ENGINES=(ue3 goldsrc source idtech3 idtech4 cryengine1 thiefdark sithengine ofp)

# ------------------ Interactive engine selection ------------------
if [[ -z "$ENGINE" ]]; then
    echo "Please select a game engine to track with Git LFS:"
    for i in "${!SUPPORTED_ENGINES[@]}"; do
        echo "  $((i+1)). ${SUPPORTED_ENGINES[$i]}"
    done
    read -rp "Enter number (1-${#SUPPORTED_ENGINES[@]}): " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#SUPPORTED_ENGINES[@]} )); then
        echo "❌ Invalid selection."
        exit 1
    fi
    ENGINE="${SUPPORTED_ENGINES[$((choice-1))]}"
    echo "✅ Selected engine: $ENGINE"
fi


# ----------------------- Dependencies ------------------------
if ! command -v git >/dev/null 2>&1; then
    echo "❌ git not installed."
    exit 1
fi

if ! command -v git-lfs >/dev/null 2>&1; then
    echo "📦 Installing Git LFS..."
    sudo apt-get update -q
    sudo apt-get install -y git-lfs
fi

echo "🔧 Initializing Git LFS..."
git lfs install --force || true

# ------------------ Define engine-specific patterns ------------------
declare -A ENGINE_PATTERNS

# Unreal Engine 3
ENGINE_PATTERNS[ue3]="*.ico *.upk *.umap *.psa *.psk *.abs *.fxa *.fbx *.png *.psd *.wav *.mp4 \
*.bik *.tga *.bmp *.dds *.jpg *.jpeg *.ogg *.mp3 *.usx *.utx *.uax *.ukx *.unr *.uc *.u \
*.swf *.bin *.pak *.iso *.zip *.rar *.dll *.lib *.pdb *.exe *.sln *.vcproj *.vcxproj *.vcxitems \
*.filters *.sdf *.log *.t3d *.udk *.chtml *.max *.3ds *.mb *.ma *.blend *.ztl *.ztb *.tbx *.mtl *.obj *.stl \
*.bgeo *.abc *.ply *.gltf *.glb *.igs *.step *.stp *.x3d *.bsp *.vox *.tiff *.tif *.exr *.hdr *.pfm \
*.raw *.ies *.sbsar *.sbs *.sppr *.tx *.xcf *.mat *.cg *.cgfx *.sma *.smi *.ptx *.bvh *.c3d *.anim \
*.skel *.rig *.mc *.mcx *.phy *.udk *.ukx *.uax *.utx *.usx *.fxa *.fxp *.bik *.swf *.gtl *.gma *.pak \
*.pakchunk* *.pak.info *.umx *.uplugin *.uproject *.uasset *.uexp *.ubulk *.wav *.mp3 *.ogg *.flac *.m4a \
*.aac *.ac3 *.mov *.avi *.wmv *.flv *.mkv *.m4v *.mxf *.r3d *.7z *.tar *.gz *.lz4 *.lzma *.xz *.cab \
*.msi *.vcxproj.user *.vsconfig *.props *.targets *.filters *.hlsl *.glsl *.fx *.fxc *.bat *.sh *.cmd \
*.patch *.diff *.cmake *.mak *.vssettings *.code-workspace *.vscode/*.json"
ENGINE_PATTERNS[ue3]+=" *.idea *.iml *.ipr *.iws CMakeLists.txt *.cmake"

# GoldSrc / Half-Life 1
ENGINE_PATTERNS[goldsrc]="*.wad *.bsp *.mdl *.spr *.wav *.mp3 *.txt *.cfg *.exe *.dll *.zip *.rar \
*.sln *.vcxproj *.filters *.user *.code-workspace *.vscode/*.json"
ENGINE_PATTERNS[goldsrc]+=" *.idea *.iml *.ipr *.iws CMakeLists.txt *.cmake"

# Source Engine / Hammer
ENGINE_PATTERNS[source]="*.vmf *.vmt *.vtf *.mdl *.wav *.mp3 *.txt *.cfg *.exe *.dll *.zip *.rar \
*.sln *.vcxproj *.filters *.user *.code-workspace *.vscode/*.json"
ENGINE_PATTERNS[source]+=" *.idea *.iml *.ipr *.iws CMakeLists.txt *.cmake"

# idTech3
ENGINE_PATTERNS[idtech3]="*.pk3 *.bsp *.shader *.tga *.jpg *.png *.wav *.mp3 *.cfg *.script *.pak \
*.sln *.vcxproj *.filters *.user *.code-workspace *.vscode/*.json"
ENGINE_PATTERNS[idtech3]+=" *.idea *.iml *.ipr *.iws CMakeLists.txt *.cmake"

# idTech4
ENGINE_PATTERNS[idtech4]="*.pk4 *.map *.tga *.jpg *.png *.shader *.wav *.mp3 *.cfg *.script *.pak \
*.sln *.vcxproj *.filters *.user *.code-workspace *.vscode/*.json"
ENGINE_PATTERNS[idtech4]+=" *.idea *.iml *.ipr *.iws CMakeLists.txt *.cmake"

# CryEngine 1 / FarCry 1
ENGINE_PATTERNS[cryengine1]="*.tga *.dds *.mtl *.xml *.cgf *.chr *.skin *.anm *.caf *.wav *.ogg *.mp3 \
*.lua *.cfg *.pak *.zip *.7z *.log *.dll *.so *.exe *.sln *.vcxproj *.filters *.user *.code-workspace \
*.vscode/*.json"
ENGINE_PATTERNS[cryengine1]+=" *.idea *.iml *.ipr *.iws CMakeLists.txt *.cmake"

# Thief 1-2 Dark Engine
ENGINE_PATTERNS[thiefdark]="*.mis *.gam *.bin *.crf *.cam *.pkt *.wav *.voc *.tga *.pcx *.pal *.mat *.mot *.cal \
*.vdb *.fnm *.bin *.ms *.h *.hxz *.hx *.hk *.eq *.shock *.key *.txt *.cfg *.exe *.dll *.zip *.rar \
*.sln *.vcxproj *.filters *.user *.code-workspace *.vscode/*.json"
ENGINE_PATTERNS[thiefdark]+=" *.idea *.iml *.ipr *.iws CMakeLists.txt *.cmake"

# Jedi Knight: Dark Forces 2 (Sith Engine)
ENGINE_PATTERNS[sithengine]="*.3do *.anm *.bm *.cmp *.cfg *.dac *.dad *.dao *.mat *.md *.md3 *.pal *.pup \
*.sfx *.tga *.txt *.vox *.wav *.git *.key *.mat *.snd *.snd *.voc *.wal *.wed *.zkn *.zkp *.zkl \
*.exe *.dll *.zip *.rar *.sln *.vcxproj *.filters *.user *.code-workspace *.vscode/*.json"
ENGINE_PATTERNS[sithengine]+=" *.idea *.iml *.ipr *.iws CMakeLists.txt *.cmake"

# Operation Flashpoint: Cold War Crisis (Real Virtuality Engine 1)
ENGINE_PATTERNS[ofp]="*.pbo *.ebo *.wrp *.pac *.paa *.ogg *.wss *.fsm *.sqm *.sqs *.sqf *.ext *.bin *.cpp \
*.hpp *.rvmat *.rdy *.lip *.rtm *.mlod *.odol *.3ds *.asc *.txt *.cfg *.rpt *.log *.bik *.bisurf *.png *.jpg \
*.tga *.pboproject *.dep *.xib *.xml *.dll *.exe *.p *.ifa *.ifp *.csv *.html *.htm *.pdf *.doc *.xls *.ppt \
*.sln *.vcxproj *.filters *.user *.code-workspace *.vscode/*.json"
ENGINE_PATTERNS[ofp]+=" *.idea *.iml *.ipr *.iws CMakeLists.txt *.cmake"

# ----------------------- Find and migrate large files -----------------------
echo "🔍 Scanning for large files (>10MB)..."
find . -type f -size +10M -exec ls -lh {} \; | awk '{ print $9 ": " $5 }' 2>/dev/null || echo "No large files found or error scanning."

echo "🔄 Setting up LFS tracking for large files..."
# Safer approach - only track new files, don't migrate existing history
git lfs install --force --skip-repo || true

# ----------------------- Apply Git LFS tracking -----------------------
echo "📦 Tracking files for engine: $ENGINE"
PATTERNS=(${ENGINE_PATTERNS[$ENGINE]})
for pattern in "${PATTERNS[@]}"; do
    git lfs track "$pattern" 2>/dev/null || true
done

# ----------------------- Show .gitattributes -----------------------
echo "📄 Current .gitattributes:"
cat .gitattributes || true

# ----------------------- Commit changes -----------------------
echo "💾 Committing LFS configuration..."
git add .gitattributes

if git diff --cached --quiet; then
    echo "ℹ️ No changes to commit."
else
    git commit -m "Enable Git LFS tracking for $ENGINE assets" || true
fi

# ----------------------- Push changes if requested -----------------------
if [ "$DO_PUSH" = "push" ]; then
    echo "🚀 Pushing to remote repository..."
    
    # Push LFS objects first
    echo "📤 Pushing LFS objects..."
    git lfs push origin main --all || echo "⚠️ LFS push had issues, continuing..."
    
    # Then push regular commits
    echo "📤 Pushing Git commits..."
    git push origin main || echo "⚠️ Push failed, check remote and credentials"
else
    echo "💡 Add 'push' as third argument to automatically push changes"
    echo "💡 Manual push commands:"
    echo "   git lfs push origin main --all"
    echo "   git push origin main"
fi

echo "✅ Git LFS tracking applied successfully for $ENGINE!"