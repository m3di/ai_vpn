#!/bin/bash

# Script to create a new release tag for the VPN project

set -e

echo "=== VPN Server Release Creator ==="
echo ""

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ This is not a git repository"
    exit 1
fi

# Check for uncommitted changes
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "⚠️  You have uncommitted changes. Please commit them first."
    echo ""
    echo "Uncommitted files:"
    git status --porcelain
    echo ""
    read -p "Do you want to commit them now? (y/N): " COMMIT_NOW
    if [[ $COMMIT_NOW =~ ^[Yy]$ ]]; then
        echo "Staging all changes..."
        git add .
        read -p "Enter commit message: " COMMIT_MSG
        git commit -m "$COMMIT_MSG"
        echo "✅ Changes committed"
    else
        echo "❌ Please commit your changes first"
        exit 1
    fi
fi

# Get the current version
CURRENT_VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
echo "Current version: $CURRENT_VERSION"

# Suggest next version
if [[ $CURRENT_VERSION =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    MAJOR=${BASH_REMATCH[1]}
    MINOR=${BASH_REMATCH[2]}
    PATCH=${BASH_REMATCH[3]}
    
    NEXT_PATCH="v$MAJOR.$MINOR.$((PATCH + 1))"
    NEXT_MINOR="v$MAJOR.$((MINOR + 1)).0"
    NEXT_MAJOR="v$((MAJOR + 1)).0.0"
    
    echo ""
    echo "Suggested versions:"
    echo "  1. $NEXT_PATCH (patch)"
    echo "  2. $NEXT_MINOR (minor)"
    echo "  3. $NEXT_MAJOR (major)"
    echo "  4. Custom version"
    echo ""
    
    read -p "Choose an option (1-4): " OPTION
    
    case $OPTION in
        1) NEW_VERSION=$NEXT_PATCH ;;
        2) NEW_VERSION=$NEXT_MINOR ;;
        3) NEW_VERSION=$NEXT_MAJOR ;;
        4) 
            read -p "Enter custom version (e.g., v1.2.3): " NEW_VERSION
            if [[ ! $NEW_VERSION =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                echo "❌ Invalid version format. Use vX.Y.Z format"
                exit 1
            fi
            ;;
        *)
            echo "❌ Invalid option"
            exit 1
            ;;
    esac
else
    echo ""
    read -p "Enter new version (e.g., v1.0.0): " NEW_VERSION
    if [[ ! $NEW_VERSION =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "❌ Invalid version format. Use vX.Y.Z format"
        exit 1
    fi
fi

echo ""
echo "Creating release: $NEW_VERSION"
echo ""

# Check if tag already exists
if git rev-parse "$NEW_VERSION" >/dev/null 2>&1; then
    echo "❌ Tag $NEW_VERSION already exists"
    exit 1
fi

# Push current changes
echo "Pushing changes to origin..."
git push origin main

# Create and push tag
echo "Creating tag: $NEW_VERSION"
git tag -a "$NEW_VERSION" -m "Release $NEW_VERSION - Docker images and VMess protocol"

echo "Pushing tag to origin..."
git push origin "$NEW_VERSION"

echo ""
echo "✅ Release $NEW_VERSION created successfully!"
echo ""
echo "🔄 GitHub Actions will now:"
echo "  - Build and push Docker images to Docker Hub"
echo "  - Create the GitHub release"
echo "  - Upload deployment files"
echo "  - Generate production documentation"
echo ""
echo "🌐 Check the release at:"
echo "  https://github.com/m3di/ai_vpn/releases/tag/$NEW_VERSION"
echo ""
echo "📥 Deployment files will be available at:"
echo "  https://github.com/m3di/ai_vpn/releases/download/$NEW_VERSION/docker-compose.server1.yml"
echo "  https://github.com/m3di/ai_vpn/releases/download/$NEW_VERSION/docker-compose.server2.yml"
echo "  https://github.com/m3di/ai_vpn/releases/download/$NEW_VERSION/test-production.sh"
echo ""
echo "🐳 Docker images will be published to:"
echo "  - m3di/ai-vpn:server1-${NEW_VERSION#v}"
echo "  - m3di/ai-vpn:server2-${NEW_VERSION#v}"
echo "  - m3di/ai-vpn:internet-${NEW_VERSION#v}"
echo "  - m3di/ai-vpn:client-${NEW_VERSION#v}"
echo ""
echo "⏳ Allow 5-10 minutes for the release to be built and published..." 