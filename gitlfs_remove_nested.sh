#!/bin/bash

# Script to find and fix nested Git repositories
# Fully automatic version

echo "=== Finding and fixing nested Git repositories ==="

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: This is not a git repository"
    exit 1
fi

# Check for Git LFS
if git lfs env | grep -q "git-lfs"; then
    echo "✓ Git LFS is available"
    LFS_AVAILABLE=true
else
    echo "⚠ Git LFS is not available"
    LFS_AVAILABLE=false
fi

found_nested=0
fixed_count=0

find . -name ".git" -type d | while read gitdir; do
    dirpath=$(dirname "$gitdir")
    
    # Skip the main .git folder and common exclusions
    if [ "$dirpath" = "." ] || [[ "$dirpath" == *"/.git/"* ]] || [[ "$dirpath" == *"/node_modules/"* ]] || [[ "$dirpath" == *"/build/"* ]]; then
        continue
    fi

    ((found_nested++))
    echo ""
    echo "Found nested repo: $dirpath"
    
    # Check if this might be a Git LFS pointer issue
    if [ "$LFS_AVAILABLE" = true ]; then
        lfs_files=$(find "$dirpath" -type f -exec file {} \; | grep -i "git lfs" | wc -l)
        if [ $lfs_files -gt 0 ]; then
            echo "  ⚠ Contains $lfs_files Git LFS pointer files"
        fi
    fi
    
    # Count files in the directory
    file_count=$(find "$dirpath" -type f | wc -l)
    echo "  📁 Contains $file_count files"
    
    # Automatically choose option 1: Remove the .git folder
    echo "  Automatically removing .git folder..."
    rm -rf "$gitdir"
    # Also remove .gitignore if it exists
    rm -f "$dirpath/.gitignore"
    git add "$dirpath"
    ((fixed_count++))
    echo "  ✓ Removed .git folder from $dirpath"
done

# Wait for the find loop to complete
wait

echo ""
echo "=== Summary ==="
echo "Found $found_nested nested repositories"
echo "Fixed $fixed_count nested repositories"

# Show status
echo ""
echo "=== Current status ==="
git status

# Automatically commit if there are changes
if [ $found_nested -gt 0 ] && [ $fixed_count -gt 0 ]; then
    echo ""
    echo "Automatically committing changes..."
    git commit -m "Fix nested repositories: removed $fixed_count nested .git folders"
    echo "✓ Changes committed"
    
    echo "Automatically pushing changes..."
    git push
    echo "✓ Changes pushed"
else
    echo "No nested repositories found or fixed"
fi

# Ask if user wants to commit
read -p "Do you want to commit these changes? (y/n): " commit_choice
if [ "$commit_choice" = "y" ] || [ "$commit_choice" = "Y" ]; then
    git commit -m "Fix nested repositories and ensure all files are tracked"
    echo "✓ Changes committed"
    
    read -p "Do you want to push? (y/n): " push_choice
    if [ "$push_choice" = "y" ] || [ "$push_choice" = "Y" ]; then
        git push
        echo "✓ Changes pushed"
    fi
else
    echo "⚠ Changes staged but not committed"
fi

echo "Done!"