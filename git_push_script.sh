#!/bin/bash

# Script to push current directory and subfolders to GitHub repository
# This script will delete everything in the repository and start fresh

# Repository details
REPO_NAME="Davinchi-Intelliscript-Processor"
USER_NAME="markobosko-git"
REPO_URL="https://github.com/$USER_NAME/$REPO_NAME.git"

echo "Starting script to push to GitHub repository: $REPO_URL"
echo "WARNING: This will delete all content in the repository and replace it with local files."

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo "Git is not installed. Please install git and try again."
    exit 1
fi

# Initialize git repository in current directory if not already a git repository
if [ ! -d .git ]; then
    echo "Initializing git repository in current directory..."
    git init
else
    echo "Git repository already exists in current directory."
fi

# Configure git user if not already configured
if [ -z "$(git config --get user.name)" ]; then
    echo "Setting git user name to $USER_NAME..."
    git config user.name "$USER_NAME"
fi

if [ -z "$(git config --get user.email)" ]; then
    echo "Setting git user email..."
    read -p "Please enter your email address: " email
    git config user.email "$email"
fi

# Add remote repository
echo "Setting remote repository..."
if git remote | grep -q "origin"; then
    git remote set-url origin "$REPO_URL"
else
    git remote add origin "$REPO_URL"
fi

# Add all files to staging
echo "Adding files to staging..."
git add .

# Commit changes
echo "Committing changes..."
read -p "Enter commit message (default: 'Fresh start with local files'): " commit_message
commit_message=${commit_message:-"Fresh start with local files"}
git commit -m "$commit_message"

# Force push to overwrite everything in remote repository
echo "Force pushing to remote repository to replace all content..."
git push -f origin master

echo "Done! Your local directory has been pushed to $REPO_URL, replacing all previous content."