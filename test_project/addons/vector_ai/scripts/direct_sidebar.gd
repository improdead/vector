@tool
extends Control

# References to UI elements
var chat_history: RichTextLabel
var input_field: TextEdit
var send_button: Button
var settings_button: Button
var clear_button: Button

# References to other components
var editor_interface = null
var gemini_client = null
var direct_file_editor = null
var direct_game_generator = null
var direct_json_processor = null

# Chat history
var messages = []

func _ready():
	# Get references to UI elements
	chat_history = $VBoxContainer/ChatHistory
	input_field = $VBoxContainer/InputContainer/InputField
	send_button = $VBoxContainer/InputContainer/SendButton
	settings_button = $VBoxContainer/TopBar/SettingsButton
	clear_button = $VBoxContainer/TopBar/ClearButton

	# Connect signals
	send_button.pressed.connect(_on_send_button_pressed)
	input_field.gui_input.connect(_on_input_field_gui_input)
	settings_button.pressed.connect(_on_settings_button_pressed)
	clear_button.pressed.connect(_on_clear_button_pressed)

	# Get the editor interface
	editor_interface = Engine.get_singleton("EditorInterface")

	# Initialize components
	# We need to use a different approach to create script instances
	gemini_client = Node.new()
	gemini_client.set_script(load("res://addons/vector_ai/scripts/gemini_client.gd"))

	direct_file_editor = Node.new()
	direct_file_editor.set_script(load("res://addons/vector_ai/scripts/direct_file_editor.gd"))

	direct_game_generator = Node.new()
	direct_game_generator.set_script(load("res://addons/vector_ai/scripts/direct_game_generator.gd"))

	direct_json_processor = Node.new()
	direct_json_processor.set_script(load("res://addons/vector_ai/scripts/direct_json_processor.gd"))

	# Add components as children
	add_child(gemini_client)
	add_child(direct_file_editor)
	add_child(direct_game_generator)
	add_child(direct_json_processor)

	# Set up references between components
	direct_game_generator.file_editor = direct_file_editor
	direct_json_processor.file_editor = direct_file_editor

	# Apply iOS-like styling
	_apply_ios_styling()

	# Initialize the chat history
	_add_system_message("Welcome to Vector AI! I can help you create and modify Godot games using direct file access.")
	_add_system_message("You can ask me to create a game, modify a scene, or generate code.")
	_add_system_message("Type /help to see available commands.")

func _on_send_button_pressed():
	var user_input = input_field.text.strip_edges()
	if user_input.is_empty():
		return

	# Add user message to chat history
	_add_user_message(user_input)

	# Clear input field
	input_field.text = ""

	# Check for commands
	if user_input == "/help":
		_show_help()
		return
	elif user_input.begins_with("/create_game "):
		var game_type = user_input.substr(13).strip_edges()
		_create_game(game_type)
		return
	elif user_input.begins_with("/json "):
		var json_string = user_input.substr(6).strip_edges()
		_process_json_commands(json_string)
		return
	elif user_input.begins_with("/edit_scene "):
		var scene_path = user_input.substr(12).strip_edges()
		_edit_scene(scene_path)
		return
	elif user_input.begins_with("/edit_script "):
		var script_path = user_input.substr(13).strip_edges()
		_edit_script(script_path)
		return

	# Check for game creation requests
	if _is_game_creation_request(user_input):
		_create_game_from_description(user_input)
		return

	# Get context information
	var context_info = _get_context_info(user_input)

	# Send request to Gemini API
	gemini_client.send_request(user_input, context_info, _on_gemini_response)

# Handle response from Gemini API
func _on_gemini_response(response, error):
	if error:
		_add_system_message("Error: " + error)
		return

	# Process the response
	var ai_response = response.candidates[0].content.parts[0].text

	# Check if the response contains JSON commands
	if ai_response.find("```json") != -1:
		var json_start = ai_response.find("```json") + 7
		var json_end = ai_response.find("```", json_start)

		if json_end != -1:
			var json_string = ai_response.substr(json_start, json_end - json_start).strip_edges()

			# Extract the JSON commands
			_add_ai_message(ai_response.replace("```json\n" + json_string + "\n```", ""))

			# Process the JSON commands
			_process_json_commands(json_string)
			return

	# Add AI response to chat history
	_add_ai_message(ai_response)

	# Check if the response contains a scene or script creation request
	if _contains_file_creation(ai_response):
		_handle_file_creation(ai_response)

# Check if the response contains a file creation request
func _contains_file_creation(response):
	return response.find("```gdscript") != -1 or response.find("```tscn") != -1

# Handle file creation from AI response
func _handle_file_creation(response):
	# Check for GDScript code
	if response.find("```gdscript") != -1:
		var code_start = response.find("```gdscript") + 11
		var code_end = response.find("```", code_start)

		if code_end != -1:
			var code = response.substr(code_start, code_end - code_start).strip_edges()

			# Ask the user if they want to create a script with this code
			_add_system_message("I've generated some GDScript code. Would you like me to create a script file with this code? Reply with /edit_script [path] to create the file.")

	# Check for scene content
	if response.find("```tscn") != -1:
		var scene_start = response.find("```tscn") + 7
		var scene_end = response.find("```", scene_start)

		if scene_end != -1:
			var scene_content = response.substr(scene_start, scene_end - scene_start).strip_edges()

			# Ask the user if they want to create a scene with this content
			_add_system_message("I've generated a scene file. Would you like me to create a scene with this content? Reply with /edit_scene [path] to create the file.")

# Helper function to determine if a request is for game creation
func _is_game_creation_request(request):
	request = request.to_lower()
	return (
		request.begins_with("create") or
		request.begins_with("make") or
		request.begins_with("build") or
		request.begins_with("generate")
	) and (
		request.find("game") != -1 or
		request.find("project") != -1
	)

# Get context information based on the user input
func _get_context_info(user_input):
	var context_info = ""

	# Get information about the current scene
	var current_scene = editor_interface.get_edited_scene_root()
	if current_scene:
		context_info += "Current scene: " + current_scene.scene_file_path + "\n"

	# Get information about the current script
	var editor = editor_interface.get_script_editor()
	var current_script = editor.get_current_script()
	if current_script:
		var script_path = current_script.resource_path
		var file = FileAccess.open(script_path, FileAccess.READ)
		if file:
			context_info += "Current script: " + script_path + "\n\n"
			context_info += file.get_as_text()
			file.close()

	return context_info

func _on_input_field_gui_input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER and not event.shift_pressed:
		# Prevent default behavior (newline)
		get_viewport().set_input_as_handled()
		# Send message
		_on_send_button_pressed()

func _on_settings_button_pressed():
	# Show settings dialog
	var settings_dialog = load("res://addons/vector_ai/scenes/settings_dialog.tscn").instantiate()
	add_child(settings_dialog)
	settings_dialog.popup_centered()

func _on_clear_button_pressed():
	# Clear chat history
	messages.clear()
	chat_history.clear()
	_add_system_message("Chat history cleared.")

func _show_help():
	var help_text = """
Vector AI Help:

Commands:
/help - Show this help message
/create_game [type] - Create a new game (maze, platformer, etc.)
/json [json_commands] - Execute JSON commands for bulk operations
/edit_scene [path] - Create or edit a scene file
/edit_script [path] - Create or edit a script file

Game Creation:
You can simply ask for a game to be created with natural language:
- "Make me a maze game" - Creates a maze game
- "Create a platformer game" - Creates a platformer game
- "Build me a game with coins to collect" - Creates a custom game

Direct File Access:
Vector AI now uses direct file access to create and modify files, which:
- Avoids code execution errors
- Works with any file type
- Provides more reliable results
- Allows creating complete games from scratch

JSON Commands:
- Use /json to execute bulk operations with JSON commands
- Example: /json {"action":"CREATE_SCENE","scene_path":"res://main.tscn","content":"[gd_scene format=3]\\n\\n[node name=\\"Root\\" type=\\"Node2D\\"]"}
- Supports: CREATE_SCENE, EDIT_SCENE, CREATE_SCRIPT, MODIFY_SCRIPT, CREATE_GAME
"""

	_add_system_message(help_text)

func _create_game(game_type):
	_add_system_message("Creating " + game_type + " game...")

	var result = direct_game_generator.create_game_from_description(game_type)

	if result.success:
		_add_system_message("Successfully created " + game_type + " game!")

		# Open the main scene
		if result.has("main_scene_path"):
			editor_interface.open_scene_from_path(result.main_scene_path)
			_add_system_message("Opened main scene: " + result.main_scene_path)
	else:
		_add_system_message("Error creating game: " + result.message)

func _create_game_from_description(description):
	_add_system_message("Creating game based on your description...")

	var result = direct_game_generator.create_game_from_description(description)

	if result.success:
		_add_system_message("Successfully created game based on your description!")

		# Open the main scene
		if result.has("main_scene_path"):
			editor_interface.open_scene_from_path(result.main_scene_path)
			_add_system_message("Opened main scene: " + result.main_scene_path)
	else:
		_add_system_message("Error creating game: " + result.message)

func _process_json_commands(json_string):
	_add_system_message("Processing JSON commands...")

	var result = direct_json_processor.process_json_commands(json_string)

	if result.success:
		_add_system_message("Successfully processed JSON commands.")

		# If there are results, show them
		if result.has("results"):
			for command_result in result.results:
				if command_result.has("message"):
					_add_system_message(command_result.message)
	else:
		_add_system_message("Error processing JSON commands: " + result.error)

func _edit_scene(scene_path):
	# Check if the scene path is valid
	if not scene_path.begins_with("res://"):
		scene_path = "res://" + scene_path

	if not scene_path.ends_with(".tscn"):
		scene_path += ".tscn"

	_add_system_message("Editing scene: " + scene_path)

	# Check if the scene exists
	if FileAccess.file_exists(scene_path):
		# Read the scene file
		var read_result = direct_file_editor.read_file(scene_path)
		if read_result.success:
			_add_system_message("Scene file loaded. You can now modify it.")

			# Open the scene in the editor
			editor_interface.open_scene_from_path(scene_path)
		else:
			_add_system_message("Error reading scene file: " + read_result.message)
	else:
		# Create a new scene file
		var scene_content = _create_basic_scene(scene_path.get_file().get_basename())
		var create_result = direct_file_editor.create_scene(scene_path, scene_content)

		if create_result.success:
			_add_system_message("Created new scene file: " + scene_path)

			# Open the scene in the editor
			editor_interface.open_scene_from_path(scene_path)
		else:
			_add_system_message("Error creating scene file: " + create_result.message)

func _edit_script(script_path):
	# Check if the script path is valid
	if not script_path.begins_with("res://"):
		script_path = "res://" + script_path

	if not script_path.ends_with(".gd"):
		script_path += ".gd"

	_add_system_message("Editing script: " + script_path)

	# Check if the script exists
	if FileAccess.file_exists(script_path):
		# Read the script file
		var read_result = direct_file_editor.read_file(script_path)
		if read_result.success:
			_add_system_message("Script file loaded. You can now modify it.")

			# Open the script in the editor
			var script = load(script_path)
			editor_interface.edit_script(script)
		else:
			_add_system_message("Error reading script file: " + read_result.message)
	else:
		# Create a new script file
		var script_content = _create_basic_script(script_path.get_file().get_basename())
		var create_result = direct_file_editor.create_script(script_path, script_content)

		if create_result.success:
			_add_system_message("Created new script file: " + script_path)

			# Open the script in the editor
			var script = load(script_path)
			editor_interface.edit_script(script)
		else:
			_add_system_message("Error creating script file: " + create_result.message)

# Create a basic scene file content
func _create_basic_scene(scene_name):
	var content = """[gd_scene load_steps=2 format=3]

[sub_resource type="GDScript" id="GDScript_main"]
script/source = "extends Node2D

# This is a basic scene created by Vector AI
# You can modify it to suit your needs

func _ready():
	print(\\\"Scene ready: %s\\\")
"

[node name="%s" type="Node2D"]
script = SubResource("GDScript_main")

[node name="MainNode" type="Node2D" parent="."]
position = Vector2(512, 300)

[node name="Camera2D" type="Camera2D" parent="."]
position = Vector2(512, 300)
"""
	return content % [scene_name, scene_name]

# Create a basic script file content
func _create_basic_script(script_name):
	var content = """extends Node

# %s script created by Vector AI
# You can modify this script to suit your needs

func _ready():
	print("Script ready: %s")
"""
	return content % [script_name, script_name]

# Add a user message to the chat history
func _add_user_message(message):
	messages.append({"role": "user", "content": message})

	var formatted_message = "[color=#ffffff][b]You:[/b][/color]\n" + message + "\n\n"
	chat_history.append_text(formatted_message)

	# Scroll to the bottom
	chat_history.scroll_to_line(chat_history.get_line_count())

# Add an AI message to the chat history
func _add_ai_message(message):
	messages.append({"role": "assistant", "content": message})

	var formatted_message = "[color=#4CAF50][b]Vector AI:[/b][/color]\n" + message + "\n\n"
	chat_history.append_text(formatted_message)

	# Scroll to the bottom
	chat_history.scroll_to_line(chat_history.get_line_count())

# Add a system message to the chat history
func _add_system_message(message):
	var formatted_message = "[color=#FFC107][b]System:[/b][/color]\n" + message + "\n\n"
	chat_history.append_text(formatted_message)

	# Scroll to the bottom
	chat_history.scroll_to_line(chat_history.get_line_count())

# Apply iOS-like styling to the UI
func _apply_ios_styling():
	# Set chat history styling
	chat_history.bbcode_enabled = true

	# Set input field styling
	input_field.syntax_highlighter = null

	# Set button styling
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.2, 0.6, 1.0)
	normal_style.corner_radius_top_left = 8
	normal_style.corner_radius_top_right = 8
	normal_style.corner_radius_bottom_left = 8
	normal_style.corner_radius_bottom_right = 8

	send_button.add_theme_stylebox_override("normal", normal_style)
	send_button.add_theme_color_override("font_color", Color(1, 1, 1))
	send_button.add_theme_color_override("font_hover_color", Color(1, 1, 1))

	# Set overall styling
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.15, 0.15, 0.15)
	add_theme_stylebox_override("panel", panel_style)
