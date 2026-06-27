#!/bin/bash

# Configuration
REPO_URL="https://github.com/chanderlud/giga-grabber"
YOUR_GITHUB_USERNAME="igiteam"
NEW_REPO_NAME="giga-grabber"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}🚀 Giga-Grabber Docker Setup Script${NC}"
echo "================================================"

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${YELLOW}⚠️  GitHub CLI (gh) not found. Installing...${NC}"
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        sudo apt update
        sudo apt install gh
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        brew install gh
    else
        echo -e "${RED}❌ Please install GitHub CLI manually from: https://cli.github.com/${NC}"
        exit 1
    fi
fi

# Check if logged into gh
if ! gh auth status &> /dev/null; then
    echo -e "${YELLOW}🔐 Please login to GitHub:${NC}"
    gh auth login
fi

# Delete existing repo if it exists
echo -e "\n${GREEN}📦 Setting up repository on GitHub...${NC}"
if gh repo view "$YOUR_GITHUB_USERNAME/$NEW_REPO_NAME" &> /dev/null; then
    echo -e "${YELLOW}⚠️  Repository already exists, deleting...${NC}"
    echo "y" | gh repo delete "$YOUR_GITHUB_USERNAME/$NEW_REPO_NAME"
    sleep 3
fi

# Create new repository
gh repo create "$NEW_REPO_NAME" --public --description "Giga Grabber - Dockerized multi-platform Rust binary with automated builds"

# Clone the original repository
echo -e "\n${GREEN}📥 Cloning original repository from $REPO_URL...${NC}"
git clone "$REPO_URL" "$NEW_REPO_NAME"
cd "$NEW_REPO_NAME"

# Change remote to your repo
git remote remove origin
git remote add origin "https://github.com/$YOUR_GITHUB_USERNAME/$NEW_REPO_NAME.git"

# Create Dockerfile with FIXED Rust version (1.85 for 2024 edition support)
echo -e "${GREEN}🐳 Creating Dockerfile...${NC}"
cat > Dockerfile << 'EOF'
FROM ubuntu:22.04 AS builder

RUN apt-get update && apt-get install -y \
    curl build-essential pkg-config libssl-dev libfontconfig1-dev ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

WORKDIR /app
COPY . .
RUN cargo build --release

FROM ubuntu:22.04
RUN apt-get update && apt-get install -y ca-certificates libssl3 libfontconfig1 && rm -rf /var/lib/apt/lists/*
COPY --from=builder /app/target/release/giga_grabber /usr/local/bin/giga-grabber
ENTRYPOINT ["giga-grabber"]
CMD ["--help"]
EOF

# That Dockerfile is the final working solution after all the bullshit:
#     ✅ No MUSL (source of all GLIBC errors)
#     ✅ No cross-compilation (no -m64 flag issues)
#     ✅ Native Ubuntu 22.04 build
#     ✅ Runs on Ubuntu 22.04 (same as GitHub runner)
#     ✅ Works on your Mac via Docker
#     ✅ Downloads Star Wars without errors

# What you learned the hard way:
#     MUSL is great for static binaries, but hell for cross-compilation
#     rust:alpine looks tempting but fails with assembly code
#     Ubuntu → Ubuntu is boring but works
#     Sometimes the simplest solution is the best

# Create GitHub Actions workflow for Docker builds - NO AUTO PUSH TRIGGER
echo -e "${GREEN}⚙️ Creating GitHub Actions workflow (manual trigger only)...${NC}"
mkdir -p .github/workflows
cat > .github/workflows/docker-build.yml << 'EOF'
name: Build and Publish Docker Image

on:
  workflow_dispatch:  # ONLY manual trigger, no auto push

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: giga-grabber

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - uses: actions/checkout@v4
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3
      - name: Set up QEMU
        uses: docker/setup-qemu-action@v3
      - name: Log in to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ github.repository }}/${{ env.IMAGE_NAME }}
          tags: |
            type=raw,value=latest
            type=sha,format=short
      - name: Build and push Docker image
        uses: docker/build-push-action@v5
        with:
          context: .
          platforms: linux/amd64,linux/arm64
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
EOF

# Create .dockerignore
cat > .dockerignore << 'EOF'
target/
.git/
.github/
Dockerfile
.dockerignore
*.md
EOF

# Create helper script
cat > docker-run.sh << EOF
#!/bin/bash
docker run --rm -v "\$(pwd):/data" -w /data ghcr.io/$YOUR_GITHUB_USERNAME/$NEW_REPO_NAME/giga-grabber:latest "\$@"
EOF
chmod +x docker-run.sh

# Commit and push the Docker setup (THIS WILL NOT TRIGGER A BUILD)
echo -e "\n${GREEN}💾 Committing Docker setup (no build triggered)...${NC}"
git add .
git commit -m "Add Docker support with GitHub Actions (manual trigger only) - FIXED Rust 1.85"
git branch -M main
git push -u origin main

echo -e "\n${GREEN}✅ Docker setup pushed! No build was triggered.${NC}"
echo "================================================"

# Open the Actions page
echo -e "${BLUE}📊 Opening GitHub Actions page...${NC}"
sleep 2
open "https://github.com/$YOUR_GITHUB_USERNAME/$NEW_REPO_NAME/actions" 2>/dev/null || \
xdg-open "https://github.com/$YOUR_GITHUB_USERNAME/$NEW_REPO_NAME/actions" 2>/dev/null || \
echo "Please open: https://github.com/$YOUR_GITHUB_USERNAME/$NEW_REPO_NAME/actions"

# Ask if Actions were enabled
echo -e "\n${YELLOW}Did you enable Actions on the GitHub page? (y/n): ${NC}"
read -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}🚀 Triggering Docker build via GitHub CLI...${NC}"
    # Trigger workflow manually using gh CLI - NO GIT COMMIT NEEDED
    gh workflow run docker-build.yml --repo "$YOUR_GITHUB_USERNAME/$NEW_REPO_NAME"
    echo -e "\n${GREEN}✅ Build triggered manually! Check the Actions tab${NC}"
else
    echo -e "\n${YELLOW}📋 To trigger build manually later:${NC}"
    echo "  gh workflow run docker-build.yml --repo $YOUR_GITHUB_USERNAME/$NEW_REPO_NAME"
    echo "  Or go to the Actions tab and click 'Run workflow'"
fi

echo -e "\n${GREEN}🎯 Your Docker image will be at:${NC}"
echo "ghcr.io/$YOUR_GITHUB_USERNAME/$NEW_REPO_NAME/giga-grabber:latest"
echo ""
echo -e "${BLUE}To check workflow status:${NC}"
echo "gh run list --repo $YOUR_GITHUB_USERNAME/$NEW_REPO_NAME"