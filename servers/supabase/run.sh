#!/bin/bash

# Supabase MCP server runner
# This script starts the MCP server for Supabase

# Configuration
MCP_DIR="$HOME/.mcp/supabase"
CONFIG_FILE="$HOME/.cursor/mcp.json"
SUPABASE_URL=${SUPABASE_URL:-"http://localhost:54321"}
SUPABASE_KEY=${SUPABASE_KEY:-"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0"}

# Attempt to get info from config file if available
if [ -f "$CONFIG_FILE" ]; then
  # Try to extract info with jq if available
  if command -v jq &> /dev/null; then
    CONFIG_URL=$(jq -r '.supabase.url // empty' "$CONFIG_FILE")
    CONFIG_KEY=$(jq -r '.supabase.key // empty' "$CONFIG_FILE")
    
    # Use config values if they exist
    if [ -n "$CONFIG_URL" ]; then
      SUPABASE_URL="$CONFIG_URL"
    fi
    
    if [ -n "$CONFIG_KEY" ]; then
      SUPABASE_KEY="$CONFIG_KEY"
    fi
  fi
fi

# Create directory if it doesn't exist
mkdir -p "$MCP_DIR"

# Run the Supabase MCP server from the official package
npx @modelcontextprotocol/server-postgres serve --connection-string "postgresql://postgres:postgres@localhost:54322/postgres?apikey=$SUPABASE_KEY&url=$SUPABASE_URL" 