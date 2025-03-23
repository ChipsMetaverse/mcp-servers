# Global MCP Servers

This repository contains a collection of Model Context Protocol (MCP) servers that can be installed globally on your system. These servers allow LLMs like Claude to interact with various external services.

## Included Servers

- **ComfyUI** - Interact with the ComfyUI stable diffusion interface for image generation
- **GitHub** - Perform operations on GitHub repositories, issues, and pull requests
- **Brave Search** - Search the web using the Brave Search API
- **Supabase** - Run SQL queries against a Supabase database

## Installation

To install all MCP servers globally, run:

```bash
# Clone this repository
git clone https://github.com/your-username/mcp-servers.git
cd mcp-servers

# Optional: Set environment variables for API keys
export GITHUB_TOKEN="your_github_token"
export BRAVE_SEARCH_API_KEY="your_brave_search_api_key"
export SUPABASE_URL="your_supabase_url"
export SUPABASE_KEY="your_supabase_anon_key"

# Run the setup script
./bin/setup-global-mcp.sh
```

This will:

1. Create directories for each MCP server in `~/.mcp/`
2. Copy server scripts to these directories
3. Configure Cursor to use these servers via `~/.cursor/mcp.json`
4. Set up API keys if provided as environment variables

## Requirements

- **Node.js and npm** - Required for running MCP servers
- **curl** - Used for API checks
- **jq** - Recommended for JSON manipulation (optional but recommended)

## Configuration

API keys and tokens are stored in `~/.cursor/mcp.json`. You can edit this file manually if you prefer not to use environment variables. The configuration format is:

```json
{
  "github": {
    "accessToken": "your_github_token",
    "permissions": ["repo", "admin:org", "user", "workflow", "delete_repo"]
  },
  "braveSearch": {
    "apiKey": "your_brave_search_api_key",
    "enabled": true
  },
  "comfyui": {
    "command": "~/.mcp/comfyui/run.sh",
    "args": []
  },
  "github-mcp": {
    "command": "~/.mcp/github/run.sh",
    "args": []
  },
  "brave-search": {
    "command": "~/.mcp/brave-search/run.sh",
    "args": []
  },
  "supabase": {
    "command": "~/.mcp/supabase/run.sh",
    "args": []
  }
}
```

## Running Individual Servers

You can run each server individually:

```bash
# ComfyUI MCP Server
~/.mcp/comfyui/run.sh

# GitHub MCP Server
~/.mcp/github/run.sh

# Brave Search MCP Server
~/.mcp/brave-search/run.sh

# Supabase MCP Server
~/.mcp/supabase/run.sh
```

## Using with LLMs

After installation, restart Cursor or Claude Desktop to apply the changes. MCP servers will be automatically available to LLMs that support the MCP protocol.

## Troubleshooting

- **Missing API Keys**: Make sure to set your API keys either through environment variables or by editing `~/.cursor/mcp.json`
- **Server Connectivity**: Each server has specific requirements:
  - ComfyUI: Requires the ComfyUI server to be running on http://localhost:8188
  - Supabase: Requires a running Supabase instance (local or remote)
- **Permissions**: Ensure the run scripts have execution permissions
- **Node.js Version**: MCP servers require Node.js v16 or later

## License

MIT 