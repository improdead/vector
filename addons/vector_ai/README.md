# Vector AI - AI-Driven Scene Editing for Godot

Vector AI is a Godot plugin that allows you to use AI to analyze and modify your Godot scenes, generate code, and perform project-wide refactors.

## Features

- **Direct Scene Editing**: Modify scene files directly without code execution
- **Code Generation**: Generate GDScript code for your Godot projects
- **Project Analysis**: Analyze your project structure and get suggestions for improvements
- **UndoRedo Support**: All changes can be undone with Ctrl+Z
- **Offline Scene Editing**: Edit scenes even when they're not open in the editor
- **Copyable Code Blocks**: Easily copy generated code to clipboard
- **JSON Command Processing**: Execute bulk operations with JSON commands
- **Syntax Validation**: Validate GDScript syntax before execution
- **CI/CD Integration**: Run validations in your CI/CD pipeline

## Installation

1. Copy the `addons/vector_ai` folder to your project's `addons` directory
2. Enable the plugin in Project > Project Settings > Plugins
3. The Vector AI sidebar will appear in the editor

## Usage

### Direct Scene Editing

The plugin uses a "direct scene edit" approach, which treats scene files as plaintext and modifies them directly. This avoids common issues with code execution and works even when scenes aren't open in the editor.

To modify a scene:

1. Type your request in the Vector AI sidebar, e.g., "Add a triangle to the scene"
2. The AI will analyze your request and generate modifications for the scene
3. The modifications will be applied directly to the scene file
4. The scene will be reloaded in the editor to show the changes

### Commands

- `/mode direct_scene_edit` - Switch to direct scene file editing mode (default)
- `/mode scene_modification` - Switch to scene modification mode (uses code execution)
- `/mode code_generation` - Switch to code generation mode
- `/mode project_analysis` - Switch to project analysis mode
- `/help` - Show help information
- `/json [json_commands]` - Execute JSON commands for bulk operations

### JSON Commands

You can use JSON commands to perform bulk operations:

```json
[
  {
    "action": "ADD_NODE",
    "scene_path": "res://main.tscn",
    "parent_path": ".",
    "node_type": "Sprite2D",
    "node_name": "Player",
    "properties": {
      "position": "Vector2(100, 100)",
      "texture": "res://icon.png"
    }
  },
  {
    "action": "MODIFY_NODE",
    "scene_path": "res://main.tscn",
    "node_path": "Player",
    "properties": {
      "position": "Vector2(200, 200)",
      "scale": "Vector2(2, 2)"
    }
  }
]
```

### Offline Scene Editing

You can also edit scenes offline using the command-line tool:

```bash
godot --headless --script addons/vector_ai/tools/scene_editor.gd -- add res://main.tscn Sprite2D Logo . texture=res://logo.png position=Vector2(100,100)
```

## How It Works

The plugin follows a simple "Load → Validate → Mutate → Save" workflow:

1. **Load**: The scene file is loaded as text
2. **Validate**: The AI-generated commands are validated for syntax and safety
3. **Mutate**: The scene file is modified according to the validated commands
4. **Save**: The modified scene file is saved back to disk

This approach avoids the common pitfalls of code execution, such as syntax errors and unexpected behavior.

## CI/CD Integration

You can integrate Vector AI's validation tools into your CI/CD pipeline:

```bash
# Validate all GDScript files
find . -name "*.gd" | xargs -I{} godot --headless --script addons/vector_ai/tools/validate_code.gd -- {}

# Validate all scene files
find . -name "*.tscn" | xargs -I{} godot --headless --script addons/vector_ai/tools/validate_scene.gd -- {}

# Or use the provided script to run all validations
./addons/vector_ai/tools/run_validations.sh
```

## Best Practices

- Always use version control (Git) to track changes to your scenes
- Use the UndoRedo functionality to revert unwanted changes
- Be specific in your requests to the AI
- Use the direct scene edit mode for most scene modifications
- Run validations in your CI/CD pipeline to catch errors early

## License

This plugin is released under the MIT License.

## Credits

- Developed by Vector AI
- Uses the Gemini API for AI capabilities
