#!/bin/bash

# MCP servers global installation script
# This script installs MCP configurations globally so they can be used in any project

echo "Setting up global MCP servers..."

# Define the user's home directory and MCP config directory
HOME_DIR="$HOME"
MCP_DIR="$HOME_DIR/.mcp"
CURSOR_DIR="$HOME_DIR/.cursor"

# Create MCP directories if they don't exist
mkdir -p "$MCP_DIR"
mkdir -p "$CURSOR_DIR"

# Install required packages
echo "Installing required packages..."
npm install -g @modelcontextprotocol/server-postgres
npm install -g @modelcontextprotocol/server-brave-search
npm install -g @modelcontextprotocol/server-github

# Get script directory for reference to other files
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Copy specific server configurations
cp -r "$REPO_ROOT/servers/"* "$MCP_DIR/"

# Create or update Cursor MCP configuration
if [ -f "$CURSOR_DIR/mcp.json" ]; then
  echo "Existing Cursor MCP configuration found. Backing up..."
  cp "$CURSOR_DIR/mcp.json" "$CURSOR_DIR/mcp.json.backup"
fi

# Copy the template MCP configuration
cp "$REPO_ROOT/config/mcp.json" "$CURSOR_DIR/mcp.json"

echo "Configuring MCP servers..."

# Configure Brave Search (if API key is provided)
if [ ! -z "$BRAVE_API_KEY" ]; then
  # Use jq to update the configuration if jq is available
  if command -v jq &> /dev/null; then
    jq --arg key "$BRAVE_API_KEY" '.mcpServers.braveSearch.env.BRAVE_API_KEY = $key' \
      "$CURSOR_DIR/mcp.json" > "$CURSOR_DIR/mcp.json.tmp" && \
      mv "$CURSOR_DIR/mcp.json.tmp" "$CURSOR_DIR/mcp.json"
  else
    echo "jq not found. Please manually update your Brave API key in $CURSOR_DIR/mcp.json"
  fi
else
  echo "No BRAVE_API_KEY environment variable found. Please manually set it in $CURSOR_DIR/mcp.json"
fi

# Configure Supabase (if connection string is provided)
if [ ! -z "$SUPABASE_CONNECTION" ]; then
  if command -v jq &> /dev/null; then
    jq --arg conn "$SUPABASE_CONNECTION" '.mcpServers.supabase.args[2] = $conn' \
      "$CURSOR_DIR/mcp.json" > "$CURSOR_DIR/mcp.json.tmp" && \
      mv "$CURSOR_DIR/mcp.json.tmp" "$CURSOR_DIR/mcp.json"
  else
    echo "jq not found. Please manually update your Supabase connection in $CURSOR_DIR/mcp.json"
  fi
else
  echo "No SUPABASE_CONNECTION environment variable found. Using default local connection."
fi

# Configure GitHub (if token is provided)
if [ ! -z "$GITHUB_TOKEN" ]; then
  if command -v jq &> /dev/null; then
    jq --arg token "$GITHUB_TOKEN" '.github.access_token = $token' \
      "$CURSOR_DIR/mcp.json" > "$CURSOR_DIR/mcp.json.tmp" && \
      mv "$CURSOR_DIR/mcp.json.tmp" "$CURSOR_DIR/mcp.json"
  else
    echo "jq not found. Please manually update your GitHub token in $CURSOR_DIR/mcp.json"
  fi
else
  echo "No GITHUB_TOKEN environment variable found. Please manually set it in $CURSOR_DIR/mcp.json"
fi

echo "Installation complete! Please restart Cursor or other MCP-compatible tools."
echo "You can now use MCP tools globally in any project." 