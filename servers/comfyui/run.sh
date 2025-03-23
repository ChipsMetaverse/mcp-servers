#!/bin/bash

# ComfyUI MCP server runner
# This script checks if ComfyUI is running and starts the MCP server

# Configuration
COMFYUI_PORT=8188
MCP_DIR="$HOME/.mcp/comfyui"

# Check if ComfyUI is running
if ! curl -s "http://localhost:$COMFYUI_PORT/system_stats" > /dev/null; then
  echo "ComfyUI is not running on port $COMFYUI_PORT"
  echo "Please start ComfyUI before running this script"
  exit 1
fi

# Create directory if it doesn't exist
mkdir -p "$MCP_DIR"

# Check if the source code exists
if [ ! -f "$MCP_DIR/index.js" ]; then
  echo "ComfyUI MCP server not found. Installing..."
  
  # Download the latest version
  if [ -d "$MCP_DIR" ]; then
    # Install dependencies
    cd "$MCP_DIR"
    npm init -y
    npm install node-fetch zod
    
    # Create server file
    cat > "$MCP_DIR/index.js" << 'EOL'
const fetch = require('node-fetch');
const { z } = require('zod');

console.log("ComfyUI MCP Server");
console.log("=====================");

// Base URL for ComfyUI API
const baseUrl = 'http://localhost:8188';

// Function to check status of ComfyUI server
async function getStatus() {
  try {
    const response = await fetch(`${baseUrl}/system_stats`);
    if (!response.ok) {
      throw new Error(`Failed to get system status: ${response.statusText}`);
    }
    return await response.json();
  } catch (error) {
    console.error('Error getting ComfyUI status:', error);
    throw error;
  }
}

// Function to get models
async function getModels() {
  try {
    const response = await fetch(`${baseUrl}/object_info`);
    if (!response.ok) {
      throw new Error(`Failed to get models: ${response.statusText}`);
    }
    const data = await response.json();
    
    // Extract checkpoint models
    const checkpoints = data.CheckpointLoaderSimple?.input?.required?.ckpt_name?.[0]?.choices || [];
    
    // Extract samplers
    const samplers = data.KSampler?.input?.required?.sampler_name?.[0]?.choices || [];
    
    // Extract schedulers
    const schedulers = data.KSampler?.input?.required?.scheduler?.[0]?.choices || [];
    
    // Extract VAE models
    const vaes = data.VAELoader?.input?.required?.vae_name?.[0]?.choices || [];

    // Extract LoRA models
    const loras = data.LoraLoader?.input?.required?.lora_name?.[0]?.choices || [];
    
    return {
      checkpoints,
      samplers,
      schedulers,
      vaes,
      loras
    };
  } catch (error) {
    console.error('Error getting ComfyUI models:', error);
    throw error;
  }
}

// Function to generate an image
async function generateImage(params) {
  try {
    // Default values
    const {
      prompt,
      negativePrompt = "",
      width = 512,
      height = 512,
      steps = 20,
      cfgScale = 7,
      sampler = "euler_ancestral",
      seed = Math.floor(Math.random() * 2147483647),
      model = "dreamshaper_5" // This would need to be a model that exists in your ComfyUI installation
    } = params;

    // Create a basic text-to-image workflow
    const workflow = {
      "3": {
        "inputs": {
          "seed": seed,
          "steps": steps,
          "cfg": cfgScale,
          "sampler_name": sampler,
          "scheduler": "normal",
          "denoise": 1,
          "model": ["4", 0],
          "positive": ["6", 0],
          "negative": ["7", 0],
          "latent_image": ["5", 0]
        },
        "class_type": "KSampler"
      },
      "4": {
        "inputs": {
          "ckpt_name": model
        },
        "class_type": "CheckpointLoaderSimple"
      },
      "5": {
        "inputs": {
          "width": width,
          "height": height,
          "batch_size": 1
        },
        "class_type": "EmptyLatentImage"
      },
      "6": {
        "inputs": {
          "text": prompt,
          "clip": ["4", 1]
        },
        "class_type": "CLIPTextEncode"
      },
      "7": {
        "inputs": {
          "text": negativePrompt,
          "clip": ["4", 1]
        },
        "class_type": "CLIPTextEncode"
      },
      "8": {
        "inputs": {
          "samples": ["3", 0],
          "vae": ["4", 2]
        },
        "class_type": "VAEDecode"
      },
      "9": {
        "inputs": {
          "filename_prefix": "ComfyUI",
          "images": ["8", 0]
        },
        "class_type": "SaveImage"
      }
    };

    // Queue the prompt
    const promptResponse = await fetch(`${baseUrl}/prompt`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        prompt: workflow,
      }),
    });

    if (!promptResponse.ok) {
      throw new Error(`Failed to queue prompt: ${promptResponse.statusText}`);
    }

    const promptData = await promptResponse.json();
    const promptId = promptData.prompt_id;

    // Poll for completion
    let output = null;
    const startTime = Date.now();
    const timeout = 300000; // 5 minutes
    const pollingInterval = 1000; // 1 second
    
    while (!output && Date.now() - startTime < timeout) {
      // Wait for the polling interval
      await new Promise(resolve => setTimeout(resolve, pollingInterval));
      
      // Check history endpoint
      const historyResponse = await fetch(`${baseUrl}/history/${promptId}`);
      if (!historyResponse.ok) {
        if (historyResponse.status === 404) {
          // Prompt not found in history, still processing
          continue;
        }
        throw new Error(`Failed to get history: ${historyResponse.statusText}`);
      }
      
      const historyData = await historyResponse.json();
      
      // Check if there's output
      if (historyData && Object.keys(historyData).length > 0) {
        const nodeOutputs = historyData[promptId]?.outputs || {};
        
        // Look for SaveImage node output (node 9 in our workflow)
        if (nodeOutputs['9']?.images?.length > 0) {
          const imageMeta = nodeOutputs['9'].images[0];
          output = {
            imageUrl: `${baseUrl}/view?filename=${imageMeta.filename}&subfolder=${imageMeta.subfolder || ''}`,
            type: imageMeta.type,
            filename: imageMeta.filename,
            subfolder: imageMeta.subfolder
          };
        }
      }
    }
    
    if (!output) {
      throw new Error('Image generation timed out or failed');
    }
    
    // Return the image URL
    return {
      imageUrl: output.imageUrl
    };
  } catch (error) {
    console.error('Error generating image:', error);
    throw error;
  }
}

// Define our tools
const tools = {
  'generate-image': async (input) => {
    try {
      const result = await generateImage(input);
      return { imageUrl: result.imageUrl };
    } catch (error) {
      console.error('Error generating image:', error);
      throw new Error(`Failed to generate image: ${error.message}`);
    }
  },
  
  'list-models': async () => {
    try {
      return await getModels();
    } catch (error) {
      console.error('Error listing models:', error);
      throw new Error(`Failed to list models: ${error.message}`);
    }
  },
  
  'list-workflows': async () => {
    try {
      // ComfyUI doesn't have a direct API for workflows, we could scan a workflows directory
      // For now, return a placeholder response
      return ["default", "text-to-image", "image-to-image", "inpainting"];
    } catch (error) {
      console.error('Error listing workflows:', error);
      throw new Error(`Failed to list workflows: ${error.message}`);
    }
  },
  
  'server-status': async () => {
    try {
      return await getStatus();
    } catch (error) {
      console.error('Error getting server status:', error);
      throw new Error(`Failed to get server status: ${error.message}`);
    }
  }
};

// MCP protocol implementation
// Handle incoming requests
const handleRequest = async (request) => {
  const { id, method, params } = request;
  
  // Basic response structure
  const response = {
    jsonrpc: '2.0',
    id
  };
  
  try {
    // Check if we're handling a tool execution request
    if (method === 'executeFunction') {
      const { name, arguments: args } = params;
      
      // Check if the tool exists
      if (!tools[name]) {
        throw new Error(`Unknown tool: ${name}`);
      }
      
      // Execute the tool
      const result = await tools[name](args);
      response.result = result;
    } 
    // Add other methods as needed (e.g., listFunctions, getSchema)
    else if (method === 'listFunctions') {
      response.result = {
        functions: [
          {
            name: 'generate-image',
            description: 'Generate an image using ComfyUI',
            parameters: {
              type: 'object',
              properties: {
                prompt: {
                  type: 'string',
                  description: 'Text prompt describing the image to generate'
                },
                negativePrompt: {
                  type: 'string',
                  description: 'Text prompt describing what to avoid in the image'
                },
                width: {
                  type: 'number',
                  description: 'Width of the generated image',
                  default: 512
                },
                height: {
                  type: 'number',
                  description: 'Height of the generated image',
                  default: 512
                },
                steps: {
                  type: 'number',
                  description: 'Number of sampling steps',
                  default: 20
                },
                cfgScale: {
                  type: 'number',
                  description: 'CFG scale (how closely to follow the prompt)',
                  default: 7
                },
                sampler: {
                  type: 'string',
                  description: 'Sampling method to use'
                },
                seed: {
                  type: 'number',
                  description: 'Random seed for generation'
                },
                model: {
                  type: 'string',
                  description: 'Model to use for generation'
                }
              },
              required: ['prompt']
            }
          },
          {
            name: 'list-models',
            description: 'List available models in ComfyUI'
          },
          {
            name: 'list-workflows',
            description: 'List available workflows in ComfyUI'
          },
          {
            name: 'server-status',
            description: 'Get the status of the ComfyUI server'
          }
        ]
      };
    } else {
      throw new Error(`Unknown method: ${method}`);
    }
  } catch (error) {
    response.error = {
      code: -32000,
      message: error.message || 'Unknown error'
    };
  }
  
  return response;
};

// Set up stdin/stdout communication
process.stdin.setEncoding('utf8');

let buffer = '';

process.stdin.on('data', async (chunk) => {
  buffer += chunk;
  
  // Process complete JSON messages (may be multiple or partial)
  let newlineIndex;
  while ((newlineIndex = buffer.indexOf('\n')) !== -1) {
    const line = buffer.slice(0, newlineIndex);
    buffer = buffer.slice(newlineIndex + 1);
    
    if (line.trim() === '') continue;
    
    try {
      const request = JSON.parse(line);
      const response = await handleRequest(request);
      
      // Send response back through stdout
      process.stdout.write(JSON.stringify(response) + '\n');
    } catch (error) {
      console.error('Error processing request:', error);
      
      // Send error response
      const errorResponse = {
        jsonrpc: '2.0',
        id: null,
        error: {
          code: -32700,
          message: `Parse error: ${error.message}`
        }
      };
      
      process.stdout.write(JSON.stringify(errorResponse) + '\n');
    }
  }
});

// Start by checking the ComfyUI server status
console.log("Connecting to ComfyUI server...");
getStatus()
  .then(status => {
    console.log(`Connected to ComfyUI version ${status.system.comfyui_version}`);
    console.log(`Using ${status.devices[0].type} device: ${status.devices[0].name}`);
    console.log("Server is running. Connect to this process via stdio in Claude Desktop.");
    
    // Keep the process running
    console.log("Press Ctrl+C to exit.");
  })
  .catch(error => {
    console.error("Failed to connect to ComfyUI server:", error);
    console.error("Make sure your ComfyUI server is running on http://localhost:8188");
    console.error("Exiting...");
    process.exit(1);
  });
EOL
  fi
fi

# Run the server
cd "$MCP_DIR"
node index.js 