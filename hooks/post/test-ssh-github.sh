#!/bin/sh

echo "Running post-apply hook: test-ssh-github.sh..."

# Test SSH connection to GitHub
ssh_output=$(ssh -T git@github.com 2>&1)
ssh_exit_code=$?

if [ $ssh_exit_code -eq 1 ] && echo "$ssh_output" | grep -q "successfully authenticated"; then
    echo "✅ SSH connection to GitHub successful!"
    echo "$ssh_output"
    exit 0
elif echo "$ssh_output" | grep -q "Permission denied"; then
    echo "❌ SSH connection failed: Permission denied"
    echo "This usually means:"
    echo "  - SSH key is not added to your GitHub account"
    echo "  - SSH key is not loaded in your SSH agent"
    echo "  - SSH key file permissions are incorrect"
    echo ""
    echo "See: https://docs.github.com/en/authentication/troubleshooting-ssh/error-permission-denied-publickey"
    echo ""
    echo "Full output:"
    echo "$ssh_output"
    exit 1
elif echo "$ssh_output" | grep -q "Could not resolve hostname"; then
    echo "❌ SSH connection failed: Network issue"
    echo "Check your internet connection"
    echo "Full output:"
    echo "$ssh_output"
    exit 1
else
    echo "❌ SSH connection failed with unexpected error"
    echo "Full output:"
    echo "$ssh_output"
    exit 1
fi