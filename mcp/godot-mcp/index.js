#!/usr/bin/env node

/**
 * Godot MCP Server
 *
 * GodotのEditorPluginが提供するHTTPエンドポイントと連携し、
 * Claude CodeがGodot Editorを操作できるようにするMCPサーバー
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';

const GODOT_HTTP_URL = 'http://localhost:6789';

/**
 * HTTPリクエストを送信するヘルパー関数
 */
async function httpRequest(method, path, body = null) {
  const url = `${GODOT_HTTP_URL}${path}`;
  const options = {
    method,
    headers: {
      'Content-Type': 'application/json',
    },
  };

  if (body) {
    options.body = JSON.stringify(body);
  }

  try {
    const response = await fetch(url, options);
    const data = await response.json();
    return data;
  } catch (error) {
    throw new Error(`Godot HTTP request failed: ${error.message}`);
  }
}

/**
 * MCPサーバー初期化
 */
const server = new Server(
  {
    name: 'godot-mcp-server',
    version: '1.0.0',
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

/**
 * ツール一覧を返すハンドラー
 */
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      {
        name: 'godot_health_check',
        description: 'Godot Editor MCPサーバーの接続確認を行います。',
        inputSchema: {
          type: 'object',
          properties: {},
        },
      },
      {
        name: 'godot_screenshot',
        description: '現在開いているGodot Editorのビューポートのスクリーンショットを取得します。PNG形式でbase64エンコードされた画像データを返します。',
        inputSchema: {
          type: 'object',
          properties: {},
        },
      },
      {
        name: 'godot_get_scene',
        description: '現在開いているシーンのノードツリー構造をJSON形式で取得します。シーン全体の階層構造を確認できます。',
        inputSchema: {
          type: 'object',
          properties: {},
        },
      },
      {
        name: 'godot_get_node',
        description: '指定したノードのプロパティ一覧を取得します。ノードの詳細情報を確認できます。',
        inputSchema: {
          type: 'object',
          properties: {
            node_path: {
              type: 'string',
              description: 'ノードのパス（例: "Player"、"UI/HealthBar"）',
            },
          },
          required: ['node_path'],
        },
      },
      {
        name: 'godot_set_property',
        description: '指定したノードのプロパティを変更します。UI要素の配置・サイズ・色などを編集できます。',
        inputSchema: {
          type: 'object',
          properties: {
            node_path: {
              type: 'string',
              description: 'ノードのパス（例: "Player"、"UI/HealthBar"）',
            },
            property: {
              type: 'string',
              description: 'プロパティ名（例: "position"、"size"、"modulate"）',
            },
            value: {
              description: 'プロパティの新しい値（型はプロパティに応じて自動判定）',
            },
          },
          required: ['node_path', 'property', 'value'],
        },
      },
      {
        name: 'godot_call_method',
        description: '指定したノードのメソッドを呼び出します。ボタンクリック・シーン遷移などのゲーム操作ができます。',
        inputSchema: {
          type: 'object',
          properties: {
            node_path: {
              type: 'string',
              description: 'ノードのパス（例: "StartButton"、"SceneManager"）',
            },
            method: {
              type: 'string',
              description: 'メソッド名（例: "pressed"、"change_scene"）',
            },
            args: {
              type: 'array',
              description: 'メソッドの引数（配列形式、省略可）',
              items: {},
            },
          },
          required: ['node_path', 'method'],
        },
      },
      {
        name: 'godot_open_scene',
        description: '指定したシーンファイルをGodot Editorで開きます。複数シーンの評価時に使用します。',
        inputSchema: {
          type: 'object',
          properties: {
            scene_path: {
              type: 'string',
              description: 'シーンファイルのパス（例: "res://scenes/Main.tscn"）',
            },
          },
          required: ['scene_path'],
        },
      },
    ],
  };
});

/**
 * ツール実行ハンドラー
 */
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    switch (name) {
      case 'godot_health_check': {
        const result = await httpRequest('GET', '/health');
        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify(result, null, 2),
            },
          ],
        };
      }

      case 'godot_screenshot': {
        const result = await httpRequest('GET', '/screenshot');

        if (!result.success) {
          throw new Error('Screenshot capture failed');
        }

        // base64データを返す
        return {
          content: [
            {
              type: 'text',
              text: `Screenshot captured successfully (${result.width}x${result.height})`,
            },
            {
              type: 'image',
              data: result.data,
              mimeType: 'image/png',
            },
          ],
        };
      }

      case 'godot_get_scene': {
        const result = await httpRequest('GET', '/scene');

        if (!result.success) {
          throw new Error('Failed to get scene structure');
        }

        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify(result.scene, null, 2),
            },
          ],
        };
      }

      case 'godot_get_node': {
        const { node_path } = args;

        if (!node_path) {
          throw new Error('node_path parameter is required');
        }

        const result = await httpRequest('GET', `/node?path=${encodeURIComponent(node_path)}`);

        if (!result.success) {
          throw new Error(`Failed to get node: ${result.error || 'Unknown error'}`);
        }

        return {
          content: [
            {
              type: 'text',
              text: JSON.stringify(result.node, null, 2),
            },
          ],
        };
      }

      case 'godot_set_property': {
        const { node_path, property, value } = args;

        if (!node_path || !property || value === undefined) {
          throw new Error('node_path, property, and value are required');
        }

        const result = await httpRequest('POST', '/property', {
          path: node_path,
          property,
          value,
        });

        if (!result.success) {
          throw new Error(`Failed to set property: ${result.error || 'Unknown error'}`);
        }

        return {
          content: [
            {
              type: 'text',
              text: `Property "${property}" of node "${node_path}" has been updated to: ${JSON.stringify(value)}`,
            },
          ],
        };
      }

      case 'godot_call_method': {
        const { node_path, method, args: method_args = [] } = args;

        if (!node_path || !method) {
          throw new Error('node_path and method are required');
        }

        const result = await httpRequest('POST', '/call_method', {
          path: node_path,
          method,
          args: method_args,
        });

        if (!result.success) {
          throw new Error(`Failed to call method: ${result.error || 'Unknown error'}`);
        }

        return {
          content: [
            {
              type: 'text',
              text: `Method "${method}" called successfully on node "${node_path}". Result: ${JSON.stringify(result.result)}`,
            },
          ],
        };
      }

      case 'godot_open_scene': {
        const { scene_path } = args;

        if (!scene_path) {
          throw new Error('scene_path parameter is required');
        }

        const result = await httpRequest('POST', '/open_scene', {
          scene_path,
        });

        if (!result.success) {
          throw new Error(`Failed to open scene: ${result.error || 'Unknown error'}`);
        }

        return {
          content: [
            {
              type: 'text',
              text: `Scene "${scene_path}" has been opened in Godot Editor`,
            },
          ],
        };
      }

      default:
        throw new Error(`Unknown tool: ${name}`);
    }
  } catch (error) {
    return {
      content: [
        {
          type: 'text',
          text: `Error: ${error.message}`,
        },
      ],
      isError: true,
    };
  }
});

/**
 * サーバー起動
 */
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error('Godot MCP Server started');
}

main().catch((error) => {
  console.error('Fatal error:', error);
  process.exit(1);
});
