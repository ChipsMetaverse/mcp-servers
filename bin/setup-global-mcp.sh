#!/bin/bash

# Global MCP Server Setup Script
# This script installs MCP servers globally and configures them for use with Cursor

set -e

# Configuration
MCP_HOME="$HOME/.mcp"
CURSOR_CONFIG="$HOME/.cursor/mcp.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
SERVERS_DIR="$REPO_ROOT/servers"

# Utility functions
print_header() {
  echo ""
  echo "===== $1 ====="
  echo ""
}

print_step() {
  echo "→ $1"
}

error_exit() {
  echo "ERROR: $1" >&2
  exit 1
}

# Check for required dependencies
check_dependencies() {
  print_header "Checking dependencies"
  
  # Check for npm
  if ! command -v npm &> /dev/null; then
    error_exit "npm is required. Please install Node.js and npm first."
  fi
  print_step "npm found: $(npm --version)"
  
  # Check for npx
  if ! command -v npx &> /dev/null; then
    error_exit "npx is required. Please update your Node.js installation."
  fi
  print_step "npx found: $(npx --version)"
  
  # Check for curl
  if ! command -v curl &> /dev/null; then
    error_exit "curl is required. Please install curl first."
  fi
  print_step "curl found: $(curl --version | head -n 1)"
  
  # Recommend jq
  if ! command -v jq &> /dev/null; then
    echo "NOTE: jq is recommended for better JSON handling but not required."
    echo "      Install with: brew install jq (macOS) or apt install jq (Ubuntu)"
  else
    print_step "jq found: $(jq --version)"
  fi
}

# Create necessary directories
setup_directories() {
  print_header "Setting up directories"
  
  mkdir -p "$MCP_HOME"
  print_step "Created $MCP_HOME"
  
  # Create directories for each server
  mkdir -p "$MCP_HOME/comfyui"
  mkdir -p "$MCP_HOME/brave-search"
  mkdir -p "$MCP_HOME/github"
  mkdir -p "$MCP_HOME/supabase"
  
  # Make sure Cursor config directory exists
  mkdir -p "$(dirname "$CURSOR_CONFIG")"
  print_step "Created Cursor config directory"
}

# Copy server run scripts to MCP home
install_server_scripts() {
  print_header "Installing server scripts"
  
  # Copy all server run scripts to their respective directories
  for server_dir in "$SERVERS_DIR"/*; do
    if [ -d "$server_dir" ]; then
      server_name=$(basename "$server_dir")
      
      # Copy run script
      if [ -f "$server_dir/run.sh" ]; then
        cp "$server_dir/run.sh" "$MCP_HOME/$server_name/"
        chmod +x "$MCP_HOME/$server_name/run.sh"
        print_step "Installed $server_name server script"
      else
        echo "Warning: No run.sh found for $server_name"
      fi
    fi
  done
}

# Setup MCP configuration for Cursor
setup_cursor_config() {
  print_header "Setting up Cursor MCP configuration"
  
  # Backup existing config if it exists
  if [ -f "$CURSOR_CONFIG" ]; then
    backup_file="$CURSOR_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$CURSOR_CONFIG" "$backup_file"
    print_step "Backed up existing config to $backup_file"
  fi
  
  # Create or update the mcp.json file
  if [ -f "$REPO_ROOT/config/mcp.json" ]; then
    cp "$REPO_ROOT/config/mcp.json" "$CURSOR_CONFIG"
    print_step "Installed template config from repository"
  else
    # If no template exists, create a basic one
    cat > "$CURSOR_CONFIG" << EOF
{
  "github": {
    "accessToken": "",
    "permissions": ["repo", "admin:org", "user", "workflow", "delete_repo"]
  },
  "braveSearch": {
    "apiKey": "",
    "enabled": true
  },
  "comfyui": {
    "command": "$MCP_HOME/comfyui/run.sh",
    "args": []
  },
  "github-mcp": {
    "command": "$MCP_HOME/github/run.sh",
    "args": []
  },
  "brave-search": {
    "command": "$MCP_HOME/brave-search/run.sh",
    "args": []
  },
  "supabase": {
    "command": "$MCP_HOME/supabase/run.sh",
    "args": []
  }
}
EOF
    print_step "Created new config file"
  fi
  
  # Update paths in the config to use the installed scripts
  if command -v jq &> /dev/null; then
    # Use jq to update the paths if available
    TMP_CONFIG=$(mktemp)
    
    jq ".\"comfyui\".command = \"$MCP_HOME/comfyui/run.sh\"" "$CURSOR_CONFIG" > "$TMP_CONFIG"
    mv "$TMP_CONFIG" "$CURSOR_CONFIG"
    
    jq ".\"github-mcp\".command = \"$MCP_HOME/github/run.sh\"" "$CURSOR_CONFIG" > "$TMP_CONFIG"
    mv "$TMP_CONFIG" "$CURSOR_CONFIG"
    
    jq ".\"brave-search\".command = \"$MCP_HOME/brave-search/run.sh\"" "$CURSOR_CONFIG" > "$TMP_CONFIG"
    mv "$TMP_CONFIG" "$CURSOR_CONFIG"
    
    jq ".\"supabase\".command = \"$MCP_HOME/supabase/run.sh\"" "$CURSOR_CONFIG" > "$TMP_CONFIG"
    mv "$TMP_CONFIG" "$CURSOR_CONFIG"
    
    print_step "Updated config paths with jq"
  else
    echo "Warning: jq not found, paths may need manual updating"
  fi
}

# Configure API keys and tokens from environment variables
configure_api_keys() {
  print_header "Configuring API keys and tokens"
  
  # Only try to update keys if jq is available
  if ! command -v jq &> /dev/null; then
    echo "jq not found. Please manually add your API keys to the config file:"
    echo "$CURSOR_CONFIG"
    return
  fi
  
  # Configure GitHub token
  if [ -n "$GITHUB_TOKEN" ]; then
    TMP_CONFIG=$(mktemp)
    jq ".github.accessToken = \"$GITHUB_TOKEN\"" "$CURSOR_CONFIG" > "$TMP_CONFIG"
    mv "$TMP_CONFIG" "$CURSOR_CONFIG"
    print_step "Added GitHub token from environment variable"
  else
    echo "NOTE: GitHub token not found in environment."
    echo "      Set GITHUB_TOKEN environment variable or edit the config file manually."
  fi
  
  # Configure Brave Search API key
  if [ -n "$BRAVE_SEARCH_API_KEY" ]; then
    TMP_CONFIG=$(mktemp)
    jq ".braveSearch.apiKey = \"$BRAVE_SEARCH_API_KEY\"" "$CURSOR_CONFIG" > "$TMP_CONFIG"
    mv "$TMP_CONFIG" "$CURSOR_CONFIG"
    print_step "Added Brave Search API key from environment variable"
  else
    echo "NOTE: Brave Search API key not found in environment."
    echo "      Set BRAVE_SEARCH_API_KEY environment variable or edit the config file manually."
  fi
  
  # Configure Supabase connection info if provided
  if [ -n "$SUPABASE_URL" ] && [ -n "$SUPABASE_KEY" ]; then
    TMP_CONFIG=$(mktemp)
    jq ".supabase.url = \"$SUPABASE_URL\" | .supabase.key = \"$SUPABASE_KEY\"" "$CURSOR_CONFIG" > "$TMP_CONFIG"
    mv "$TMP_CONFIG" "$CURSOR_CONFIG"
    print_step "Added Supabase connection info from environment variables"
  else
    echo "NOTE: Supabase connection info not found in environment."
    echo "      Set SUPABASE_URL and SUPABASE_KEY environment variables"
    echo "      or edit the config file manually."
  fi
}

# Display final instructions
show_completion_message() {
  print_header "Installation Complete"
  
  echo "MCP servers have been installed globally at $MCP_HOME"
  echo "Cursor configuration has been updated at $CURSOR_CONFIG"
  echo ""
  echo "What to do next:"
  echo "  1. Review and update your API keys in $CURSOR_CONFIG if needed"
  echo "  2. Restart Cursor or any other MCP-compatible tools"
  echo "  3. You can now use MCP tools in any project"
  echo ""
  echo "You can start individual servers manually:"
  echo "  - ComfyUI:      $MCP_HOME/comfyui/run.sh"
  echo "  - GitHub:       $MCP_HOME/github/run.sh"
  echo "  - Brave Search: $MCP_HOME/brave-search/run.sh"
  echo "  - Supabase:     $MCP_HOME/supabase/run.sh"
  echo ""
  echo "Configuration options can be edited in $CURSOR_CONFIG"
}

# Main installation flow
main() {
  print_header "MCP Global Server Installation"
  echo "This script will install MCP servers globally on your system"
  
  check_dependencies
  setup_directories
  install_server_scripts
  setup_cursor_config
  configure_api_keys
  show_completion_message
}

# Start the installation
main 