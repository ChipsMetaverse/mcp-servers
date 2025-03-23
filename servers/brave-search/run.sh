#!/bin/bash

# Brave Search MCP server runner
# This script starts the MCP server for Brave Search

# Configuration
MCP_DIR="$HOME/.mcp/brave-search"
CONFIG_FILE="$HOME/.cursor/mcp.json"

# Get API key from config file if available
if [ -f "$CONFIG_FILE" ]; then
  # Try to extract API key with jq if available
  if command -v jq &> /dev/null; then
    API_KEY=$(jq -r '.braveSearch.apiKey // empty' "$CONFIG_FILE")
  else
    # Fallback to grep and sed if jq is not available
    API_KEY=$(grep -o '"apiKey"[[:space:]]*:[[:space:]]*"[^"]*"' "$CONFIG_FILE" | sed 's/.*"apiKey"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
  fi
fi

# Check if we found a key
if [ -z "$API_KEY" ]; then
  echo "No Brave Search API key found in $CONFIG_FILE"
  echo "Please set your API key in the config file or provide it as an environment variable"
  echo "Example: BRAVE_SEARCH_API_KEY=your_key ./run.sh"
  
  # Check for environment variable as fallback
  if [ -n "$BRAVE_SEARCH_API_KEY" ]; then
    echo "Using API key from environment variable"
    API_KEY="$BRAVE_SEARCH_API_KEY"
  else
    exit 1
  fi
fi

# Create directory if it doesn't exist
mkdir -p "$MCP_DIR"

# Run the Brave Search MCP server from the official package
npx @modelcontextprotocol/server-brave-search serve --api-key "$API_KEY" 