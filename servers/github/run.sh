#!/bin/bash

# GitHub MCP server runner
# This script starts the MCP server for GitHub

# Configuration
MCP_DIR="$HOME/.mcp/github"
CONFIG_FILE="$HOME/.cursor/mcp.json"

# Attempt to get token from config file if available
if [ -f "$CONFIG_FILE" ]; then
  # Try to extract token with jq if available
  if command -v jq &> /dev/null; then
    TOKEN=$(jq -r '.github.accessToken // empty' "$CONFIG_FILE")
  else
    # Fallback to grep and sed if jq is not available
    TOKEN=$(grep -o '"accessToken"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | sed 's/.*"accessToken"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
  fi
fi

# Check if we found a token
if [ -z "$TOKEN" ]; then
  echo "No GitHub access token found in $CONFIG_FILE"
  echo "Please set your access token in the config file or provide it as an environment variable"
  echo "Example: GITHUB_TOKEN=your_token ./run.sh"
  
  # Check for environment variable as fallback
  if [ -n "$GITHUB_TOKEN" ]; then
    echo "Using access token from environment variable"
    TOKEN="$GITHUB_TOKEN"
  else
    exit 1
  fi
fi

# Create directory if it doesn't exist
mkdir -p "$MCP_DIR"

# Run the GitHub MCP server from the official package
npx @modelcontextprotocol/server-github serve --token "$TOKEN" 