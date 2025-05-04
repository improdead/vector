# Vector AI for Godot

A Godot plugin with an integrated AI assistant that can help you create and modify your games using direct file access.

## Features

- **Create Complete Games**: Generate full games from natural language descriptions
- **Direct File Access**: Reliable file editing without relying on Godot's API
- **Dark-Futuristic UI**: Custom Vector AI theme with a sleek, modern design inspired by modern code editors
- **AI Sidebar**: Integrated AI assistant that can analyze and modify your scenes
- **Gemini 2.5 Flash Integration**: Powered by Google's latest Gemini AI models
- **User-Friendly Interface**: Intuitive chat interface for interacting with the AI

## Getting Started

1. Clone this repository
2. Run the sync script to ensure test_project has the latest version:
   ```
   powershell -File sync_addons.ps1
   ```
3. Open the test project in Godot
4. Enable the Vector AI plugin in Project Settings > Plugins
5. Open the Vector AI sidebar and enter your Gemini API key in the settings
6. Start asking Vector AI to help you with your game development!

## Usage

- Type "make me a maze game" to create a complete maze game
- Type "create a platformer game" to create a platformer game
- Use `/edit_scene [path]` to create or edit a scene file
- Use `/edit_script [path]` to create or edit a script file
- Type `/help` to see all available commands

## Development

When making changes to the plugin:

1. Make your changes in the `addons/vector_ai` directory
2. Run the sync script to copy the changes to the test_project:
   ```
   powershell -File sync_addons.ps1
   ```
3. Test your changes in the test_project

## Requirements

- Godot 4.4.1 or later
- Gemini API key (for AI functionality)

## License

This project is licensed under the MIT License - see the LICENSE file for details.
