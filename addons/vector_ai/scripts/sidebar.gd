@tool
extends Control

# References to UI elements
var chat_history: RichTextLabel
var input_field: TextEdit
var send_button: Button
var settings_button: Button
var clear_button: Button

# References to other components
var editor_interface
var gemini_client
var scene_analyzer
var scene_modifier
var scene_file_modifier
var code_executor
var project_analyzer
var context_manager
var tscn_parser
var template_manager
var gdtoolkit_installer
var advanced_tscn_parser
var code_generator
var project_refactor
var json_command_processor

# Chat history
var messages = []

# Current mode
var current_mode = "direct_scene_edit"  # Changed default to direct scene edit
var mode_options = ["direct_scene_edit", "scene_modification", "code_generation", "project_analysis"]

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
	gemini_client = load("res://addons/vector_ai/scripts/gemini_client.gd").new()
	scene_analyzer = load("res://addons/vector_ai/scripts/scene_analyzer.gd").new()
	scene_modifier = load("res://addons/vector_ai/scripts/scene_modifier.gd").new()
	scene_file_modifier = load("res://addons/vector_ai/scripts/scene_file_modifier.gd").new()
	code_executor = load("res://addons/vector_ai/scripts/code_executor.gd").new()
	project_analyzer = load("res://addons/vector_ai/scripts/project_analyzer.gd").new()
	context_manager = load("res://addons/vector_ai/scripts/context_manager.gd").new()
	tscn_parser = load("res://addons/vector_ai/scripts/tscn_parser.gd").new()
	template_manager = load("res://addons/vector_ai/scripts/template_manager.gd").new()
	gdtoolkit_installer = load("res://addons/vector_ai/scripts/gdtoolkit_installer.gd").new()
	advanced_tscn_parser = load("res://addons/vector_ai/scripts/advanced_tscn_parser.gd").new()
	code_generator = load("res://addons/vector_ai/scripts/code_generator.gd").new()
	project_refactor = load("res://addons/vector_ai/scripts/project_refactor.gd").new()
	json_command_processor = load("res://addons/vector_ai/scripts/json_command_processor.gd").new()

	add_child(gemini_client)
	add_child(scene_analyzer)
	add_child(scene_modifier)
	add_child(scene_file_modifier)
	add_child(code_executor)
	add_child(project_analyzer)
	add_child(context_manager)
	add_child(tscn_parser)
	add_child(template_manager)
	add_child(gdtoolkit_installer)
	add_child(advanced_tscn_parser)
	add_child(code_generator)
	add_child(project_refactor)
	add_child(json_command_processor)

	# Apply iOS-like styling
	_apply_ios_styling()

	# Initialize the chat history
	_add_system_message("Welcome to Vector AI! I can help you modify your Godot scenes, generate code, and analyze your project. Type your request and press Enter or click Send.")
	_add_system_message("You're in direct scene edit mode by default, which allows direct modification of scene files without code execution.")
	_add_system_message("Type /help to see available commands and modes.")

func _on_send_button_pressed():
	var user_input = input_field.text.strip_edges()
	if user_input.is_empty():
		return

	# Add user message to chat history
	_add_user_message(user_input)

	# Clear input field
	input_field.text = ""

	# Check for mode switching commands
	if user_input.begins_with("/mode "):
		var requested_mode = user_input.substr(6).strip_edges()
		if mode_options.has(requested_mode):
			current_mode = requested_mode
			_add_system_message("Switched to " + current_mode + " mode.")
		else:
			_add_system_message("Unknown mode. Available modes: " + str(mode_options))
		return
	elif user_input == "/help":
		_show_help()
		return
	elif user_input == "/templates":
		_show_templates()
		return
	elif user_input.begins_with("/create_game "):
		var template_name = user_input.substr(13).strip_edges()
		_create_game_from_template(template_name)
		return
	elif user_input.begins_with("/json "):
		var json_string = user_input.substr(6).strip_edges()
		_process_json_commands(json_string)
		return

	# Get context information based on the current mode
	var context_info = ""
	var actual_mode = current_mode

	# IMPORTANT: For ANY scene-related requests, always use direct_scene_edit mode
	# This completely bypasses the code execution path
	if _is_scene_modification_request(user_input):
		if current_mode != "direct_scene_edit":
			_add_system_message("Detected scene-related request. Using direct scene editing to avoid code execution errors.")
		actual_mode = "direct_scene_edit"
		context_info = scene_analyzer.analyze_current_scene()
	else:
		match current_mode:
			"scene_modification", "direct_scene_edit":
				context_info = scene_analyzer.analyze_current_scene()
				# Force direct_scene_edit mode for all scene-related operations
				actual_mode = "direct_scene_edit"
			"code_generation":
				# Get the currently edited script
				var editor = editor_interface.get_script_editor()
				var current_script = editor.get_current_script()
				if current_script:
					var script_path = current_script.resource_path
					var file = FileAccess.open(script_path, FileAccess.READ)
					if file:
						context_info = "Current script: " + script_path + "\n\n"
						context_info += file.get_as_text()
						file.close()
				else:
					context_info = "No script is currently open in the editor."
			"project_analysis":
				context_info = project_analyzer.analyze_project()

	# Send request to Gemini API with the appropriate mode
	_add_system_message("DEBUG: Using mode: " + actual_mode + " for this request")
	gemini_client.send_request(user_input, context_info, _on_gemini_response, actual_mode)

# Helper function to determine if a request is for scene modification
func _is_scene_modification_request(request):
	var scene_keywords = ["add", "create", "insert", "place", "put", "modify", "change", "update", "remove", "delete", "move", "position", "rotate", "scale", "node", "scene", "object", "sprite", "label", "button", "control", "shape", "polygon", "triangle", "rectangle", "circle"]

	request = request.to_lower()
	for keyword in scene_keywords:
		if request.find(keyword) != -1:
			return true

	return false

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
/mode direct_scene_edit - Switch to direct scene file editing mode (DEFAULT)
/mode scene_modification - Switch to scene modification mode (uses code execution)
/mode code_generation - Switch to code generation mode
/mode project_analysis - Switch to project analysis mode
/help - Show this help message
/templates - Show available game templates
/create_game [template_name] - Create a new game from a template
/json [json_commands] - Execute JSON commands for bulk operations

Game Creation:
You can simply ask for a game to be created with natural language:
- "Make me a maze game" - Creates a game using the maze template
- "Create a parkour game" - Creates a game using the parkour template
- "Build me a card game" - Creates a custom game from scratch (no template)

Current mode: %s

In direct scene edit mode (RECOMMENDED), you can:
- Directly modify .tscn files
- Add, modify, or remove nodes without executing code
- Make changes to scenes even when they're not open in the editor
- Avoid common code execution errors

In scene modification mode, you can:
- Modify properties of existing nodes
- Create new nodes
- Delete nodes
- Reparent nodes
- Execute custom GDScript code
- Note: This mode may cause syntax errors with code execution

In code generation mode, you can:
- Generate new GDScript code with syntax validation
- Get help with implementing features
- Refactor existing code
- Extract methods and classes
- Rename nodes, properties, and methods across the project

In project analysis mode, you can:
- Analyze your project structure
- Get suggestions for improvements
- Find potential issues
- Perform project-wide refactoring

Game Templates:
- Use /templates to see available game templates
- Use /create_game [template_name] to create a new game from a template

JSON Commands:
- Use /json to execute bulk operations with JSON commands
- Example: /json {"action":"ADD_NODE","scene_path":"res://main.tscn","parent_path":".","node_type":"Sprite2D","node_name":"Player"}
- Supports: ADD_NODE, MODIFY_NODE, REMOVE_NODE, CREATE_SCRIPT, MODIFY_SCRIPT, etc.
""" % current_mode

	_add_system_message(help_text)

func _show_templates():
	var templates = template_manager.list_templates()

	if templates.size() == 0:
		_add_system_message("No game templates found.")
		return

	var templates_text = "Available Game Templates:\n\n"

	for template in templates:
		var info = template_manager.get_template_info(template)
		templates_text += "- " + info.name + ": " + info.description + "\n"
		templates_text += "  Use: /create_game " + template + "\n\n"

	_add_system_message(templates_text)

func _create_game_from_template(template_name):
	_add_system_message("Creating game from template: " + template_name)

	var result = template_manager.create_game_from_template(template_name)

	if result.success:
		_add_system_message("Successfully created game from template: " + template_name)
		_add_system_message("You can now modify the game using Vector AI.")

		# Open the main scene
		var main_scene_path = "res://main.tscn"
		if FileAccess.file_exists(main_scene_path):
			editor_interface.open_scene_from_path(main_scene_path)
			_add_system_message("Opened main scene: " + main_scene_path)
	else:
		_add_system_message("Error creating game from template: " + result.error)

# Create a basic scene file content
func _create_basic_scene(scene_name):
	var content = """[gd_scene load_steps=2 format=3]

[sub_resource type="GDScript" id="GDScript_main"]
script/source = \"extends Node2D

# This is a basic scene created by Vector AI
# You can modify it to suit your needs

func _ready():
	print(\\\"Scene ready: %s\\\")
\"

[node name="%s" type="Node2D"]
script = SubResource("GDScript_main")

[node name="MainNode" type="Node2D" parent="."]
position = Vector2(512, 300)

[node name="Camera2D" type="Camera2D" parent="."]
position = Vector2(512, 300)
"""
	return content % [scene_name, scene_name]

# Preprocess GDScript code to fix common syntax issues
func _preprocess_gdscript_code(code):
	var lines = code.split("\n")
	var processed_lines = []
	var in_function = false
	var in_class = false
	var known_variables = {}
	var function_depth = 0

	# First pass: identify class structure and variables
	for i in range(lines.size()):
		var line = lines[i].strip_edges()

		# Skip empty lines and comments
		if line.is_empty() or line.begins_with("#"):
			continue

		# Check for class definition
		if line.begins_with("class ") or line.begins_with("extends "):
			in_class = true

		# Check if we're entering a function
		if line.begins_with("func "):
			in_function = true
			function_depth = 1

		# Track function depth with braces
		if in_function:
			if ":" in line:
				function_depth += 1
			if line == "pass" or line == "return" or line == "return null" or line == "return false" or line == "return true":
				function_depth -= 1
				if function_depth <= 0:
					in_function = false
					function_depth = 0

		# Track variables that are already declared with var or const
		if line.begins_with("var ") or line.begins_with("const "):
			var var_name = line.substr(line.begins_with("var ") ? 4 : 6).strip_edges()
			if "=" in var_name:
				var_name = var_name.split("=")[0].strip_edges()
			if ":" in var_name:
				var_name = var_name.split(":")[0].strip_edges()

			known_variables[var_name] = true

	# Second pass: fix undeclared variables
	in_function = false
	in_class = false
	function_depth = 0

	# Add a default extends if none is present
	var has_extends = false
	for line in lines:
		if line.strip_edges().begins_with("extends "):
			has_extends = true
			break

	if not has_extends:
		processed_lines.append("extends Node")
		processed_lines.append("")

	for i in range(lines.size()):
		var line = lines[i]
		var stripped_line = line.strip_edges()

		# Skip empty lines
		if stripped_line.is_empty():
			processed_lines.append(line)
			continue

		# Skip comments
		if stripped_line.begins_with("#"):
			processed_lines.append(line)
			continue

		# Check for class definition
		if stripped_line.begins_with("class ") or stripped_line.begins_with("extends "):
			in_class = true
			processed_lines.append(line)
			continue

		# Check if we're entering a function
		if stripped_line.begins_with("func "):
			in_function = true
			function_depth = 1
			processed_lines.append(line)
			continue

		# Track function depth
		if in_function:
			if ":" in stripped_line:
				function_depth += 1
			if stripped_line == "pass" or stripped_line == "return" or stripped_line == "return null" or stripped_line == "return false" or stripped_line == "return true":
				function_depth -= 1
				if function_depth <= 0:
					in_function = false
					function_depth = 0

			# Inside functions, just add the line as is
			processed_lines.append(line)
			continue

		# Fix undeclared variables at class level
		if in_class and not in_function:
			# Skip lines that already have var/const, comments, or other declarations
			if stripped_line.begins_with("var ") or stripped_line.begins_with("const ") or \
			   stripped_line.begins_with("#") or stripped_line.begins_with("@") or \
			   stripped_line.begins_with("signal ") or stripped_line.begins_with("enum "):
				processed_lines.append(line)
				continue

			# Check for variable assignments
			if "=" in stripped_line and not "==" in stripped_line and not "!=" in stripped_line and not "<=" in stripped_line and not ">=" in stripped_line:
				var parts = stripped_line.split("=", true, 1)
				var variable_name = parts[0].strip_edges()

				# Only consider it a variable if it's a simple identifier
				if not "." in variable_name and not "[" in variable_name and not "(" in variable_name and \
				   not variable_name.begins_with("if ") and not variable_name.begins_with("for ") and \
				   not variable_name.begins_with("while ") and not variable_name.begins_with("match "):

					# Add var declaration if not already known
					if not known_variables.has(variable_name):
						# Preserve indentation
						var indent = ""
						for j in range(line.length()):
							if line[j] == " " or line[j] == "\t":
								indent += line[j]
							else:
								break

						processed_lines.append(indent + "var " + stripped_line)
						known_variables[variable_name] = true
						continue

			# If we got here, just add the line as is
			processed_lines.append(line)

	# Make sure there's at least one function
	var has_ready = false
	for line in processed_lines:
		if line.strip_edges().begins_with("func _ready"):
			has_ready = true
			break

	if not has_ready:
		processed_lines.append("\nfunc _ready():")
		processed_lines.append("\tpass")

	return "\n".join(processed_lines)

func _process_json_commands(json_string):
	_add_system_message("Processing JSON commands...")

	var result = json_command_processor.process_json_commands(json_string)

	if result.success:
		_add_system_message("Successfully processed JSON commands.")

		# If there are results, show them
		if result.has("results"):
			for command_result in result.results:
				if command_result.has("message"):
					_add_system_message(command_result.message)
	else:
		_add_system_message("Error processing JSON commands: " + result.error)

# Apply iOS-like styling to the UI
func _apply_ios_styling():
	# Load the iOS style script
	var ios_style_script_path = "res://addons/vector_ai/resources/ios_chat_style.gd"
	var ios_style_script = load(ios_style_script_path) if ResourceLoader.exists(ios_style_script_path) else null

	if not ios_style_script:
		print("iOS style script not found at: " + ios_style_script_path)
		return

	# Load the iOS theme
	var ios_theme_path = "res://addons/vector_ai/resources/ios_theme.tres"
	var ios_theme = load(ios_theme_path) if ResourceLoader.exists(ios_theme_path) else null

	if ios_theme:
		# Apply theme to the sidebar
		theme = ios_theme

	# Update the chat history container
	if chat_history:
		# Set background color
		chat_history.add_theme_color_override("background_color", Color(0.95, 0.95, 0.95))

		# Apply styling to existing messages
		for i in range(chat_history.get_child_count()):
			var message_container = chat_history.get_child(i)
			if message_container is HBoxContainer:
				for child in message_container.get_children():
					if child is PanelContainer and child.get_child_count() > 0:
						var label = child.get_child(0)
						if label is RichTextLabel:
							# Determine if it's a user message
							var is_user_message = message_container.alignment == BoxContainer.ALIGNMENT_END
							var is_system_message = not is_user_message and label.text.begins_with("System: ")

							# Apply iOS styling
							ios_style_script.apply_to_rich_text_label(label, is_user_message, is_system_message)

	# Update the input field
	if input_field:
		input_field.add_theme_font_size_override("font_size", 14)

		# Load the iOS font
		var font_path = "res://addons/vector_ai/resources/sf_pro_display_regular.tres"
		var font = load(font_path) if ResourceLoader.exists(font_path) else null

		if font:
			input_field.add_theme_font_override("font", font)

		# Set placeholder text color
		input_field.add_theme_color_override("placeholder_color", Color(0.5, 0.5, 0.5))

		# Set cursor color
		input_field.add_theme_color_override("caret_color", Color(0, 0.48, 1.0))

	# Update buttons
	if send_button:
		send_button.add_theme_font_size_override("font_size", 14)
		send_button.add_theme_color_override("font_color", Color(0, 0.48, 1.0))
		send_button.add_theme_color_override("font_hover_color", Color(0, 0.6, 1.0))

	if settings_button:
		settings_button.add_theme_font_size_override("font_size", 14)
		settings_button.add_theme_color_override("font_color", Color(0, 0.48, 1.0))
		settings_button.add_theme_color_override("font_hover_color", Color(0, 0.6, 1.0))

	if clear_button:
		clear_button.add_theme_font_size_override("font_size", 14)
		clear_button.add_theme_color_override("font_color", Color(0, 0.48, 1.0))
		clear_button.add_theme_color_override("font_hover_color", Color(0, 0.6, 1.0))

func _on_gemini_response(response, error):
	if error:
		_add_system_message("Error: " + error)
		return

	# Check if response is valid
	if not response or not response.has("text") or response.text.is_empty():
		_add_system_message("Error: Received empty or invalid response from API")
		return

	# Add AI response to chat history
	_add_ai_message(response.text)

	# Extract code blocks from the response
	var code_blocks = code_executor.extract_code_from_response(response.text)

	if code_blocks.size() > 0:
		for i in range(code_blocks.size()):
			var code = code_blocks[i]
			if not code.strip_edges().is_empty():
				# Preprocess the code to fix common syntax issues
				var processed_code = _preprocess_gdscript_code(code)

				# Validate the code using GDToolkit
				var validation_result = gdtoolkit_installer.validate_gdscript(processed_code)
				if not validation_result.success:
					# Fix the code if there are errors
					processed_code = gdtoolkit_installer.fix_gdscript_syntax(processed_code)
					_add_system_message("Fixed syntax issues in the code.")

				# Create a unique ID for this code block
				var code_id = "code_block_" + str(i+1) + "_" + str(randi())

				# Display the code with a copyable block
				_add_copyable_code_block(code_id, processed_code)

				# Store the processed code for potential insertion
				context_manager.generated_code = processed_code

				# Get the currently edited script if any
				var editor = editor_interface.get_script_editor()
				var current_script = editor.get_current_script()

				if current_script:
					# Get the script path
					var script_path = current_script.resource_path
					context_manager.target_script = script_path

					# Ask the user if they want to insert the code
					_add_system_message("Would you like to:\n1. Insert at cursor (reply with '1')\n2. Replace current script (reply with '2')\n3. Do nothing (reply with '3')")
				else:
					_add_system_message("No script is currently open in the editor. You can copy the code using the Copy button.")
	else:
		# Check for JSON commands in the response
		var json_commands = _extract_json_commands(response.text)
		if not json_commands.is_empty():
			# Create a unique ID for this JSON block
			var json_id = "json_block_" + str(randi())

			# Display the JSON with a copyable block
			_add_copyable_code_block(json_id, json_commands, "json")

			# Ask if the user wants to execute the JSON commands
			_add_system_message("JSON commands found. Would you like to execute them? (reply with 'yes' or 'no')")

			# Store the JSON commands for later execution
			context_manager.generated_code = json_commands
			context_manager.target_script = "json_commands"
		else:
			_add_system_message("No code blocks or JSON commands found in the response.")



# Helper function to check if response contains scene modification
func _contains_scene_modification(text):
	# Check for code blocks or modification sections
	if text.find("```gdscript") != -1 or text.find("CODE:") != -1:
		return true
	if text.find("MODIFICATIONS:") != -1 or text.find("CREATE_NODE:") != -1 or text.find("ADD_NODE:") != -1:
		return true

	# Check for common scene modification terms
	var scene_terms = ["node", "scene", "add", "create", "modify", "position", "rotation", "scale", "property"]
	for term in scene_terms:
		if text.find(term) != -1:
			return true

	return false

func _handle_scene_modification_response(response):
	# IMPORTANT: We're completely removing the old code execution path
	# Instead, we'll redirect all scene modification requests to the direct scene edit handler
	_add_system_message("NOTICE: Scene modification mode is deprecated. Using direct scene editing for reliability.")
	_add_system_message("Direct scene editing modifies .tscn files directly without executing code, avoiding syntax errors.")
	_handle_direct_scene_edit_response(response)

func _handle_direct_file_writing(response):
	# Extract file paths and content from the response
	var file_paths = []
	var file_contents = []

	# First, look for GDScript code blocks
	var code_blocks = code_executor.extract_code_from_response(response.text)

	# Look for file path indicators in the response
	var file_path_indicators = [
		"SCENE_PATH:", "FILE_PATH:", "SCRIPT_PATH:",
		"Save this to", "Create a file at", "Write to",
		"main.tscn", "main.gd", "player.gd", "game.gd"
	]

	# Extract file paths from the response text
	for indicator in file_path_indicators:
		var path_start = response.text.find(indicator)
		if path_start != -1:
			var path_end = response.text.find("\n", path_start)
			if path_end != -1:
				var line = response.text.substr(path_start, path_end - path_start).strip_edges()

				# Extract the file path from the line
				var file_path = ""
				if indicator.ends_with(":"):
					# Format: INDICATOR: path
					file_path = line.substr(indicator.length()).strip_edges()
				elif line.find(":") != -1:
					# Format: something: path
					file_path = line.substr(line.find(":") + 1).strip_edges()
				elif line.find(" ") != -1:
					# Format: something path
					file_path = line.substr(line.find(" ") + 1).strip_edges()
				else:
					# Just use the indicator itself if it's a filename
					if indicator.ends_with(".tscn") or indicator.ends_with(".gd"):
						file_path = indicator

				# Clean up the file path
				if file_path.begins_with("\"") and file_path.ends_with("\""):
					file_path = file_path.substr(1, file_path.length() - 2)
				if file_path.begins_with("'") and file_path.ends_with("'"):
					file_path = file_path.substr(1, file_path.length() - 2)

				# Add res:// prefix if needed
				if not file_path.begins_with("res://") and not file_path.begins_with("/"):
					file_path = "res://" + file_path

				# Add to the list if it's not empty and not already in the list
				if not file_path.is_empty() and not file_paths.has(file_path):
					file_paths.append(file_path)

	# If no file paths were found, try to use the currently open scene or main.tscn
	if file_paths.is_empty():
		var current_scene = editor_interface.get_edited_scene_root()
		if current_scene:
			file_paths.append(current_scene.scene_file_path)
			_add_system_message("No file path specified. Using currently open scene: " + current_scene.scene_file_path)
		elif FileAccess.file_exists("res://main.tscn"):
			file_paths.append("res://main.tscn")
			_add_system_message("No file path specified. Using main.tscn as fallback.")
		else:
			_add_system_message("Error: No file path specified and no scene is currently open in the editor.")
			return

	# Now, extract content for each file path
	for file_path in file_paths:
		var file_extension = file_path.get_extension().to_lower()
		var content = ""

		# For .gd files, use code blocks if available
		if file_extension == "gd" and code_blocks.size() > 0:
			content = code_blocks[0]
			# Remove the first code block so we can use the next one for the next file
			code_blocks.remove_at(0)
		# For .tscn files, look for scene content
		elif file_extension == "tscn":
			# Look for scene content markers
			var scene_markers = [
				"[gd_scene", "[node name=", "SCENE_CONTENT:"
			]

			for marker in scene_markers:
				var content_start = response.text.find(marker)
				if content_start != -1:
					var content_end = -1

					# If it's a specific marker, find the end of that section
					if marker == "SCENE_CONTENT:":
						content_start += marker.length()
						content_end = response.text.find("\n\n", content_start)
						if content_end == -1:
							content_end = response.text.length()
					else:
						# For scene file content, try to extract the whole scene
						content_end = response.text.find("\n\n\n", content_start)
						if content_end == -1:
							content_end = response.text.length()

					if content_end != -1:
						content = response.text.substr(content_start, content_end - content_start).strip_edges()
						break

			# If no scene content was found, create a basic scene
			if content.is_empty():
				content = _create_basic_scene(file_path.get_file().get_basename())

		# If we have content, add it to the list
		if not content.is_empty():
			file_contents.append(content)
		else:
			_add_system_message("Warning: No content found for file: " + file_path)
			file_paths.erase(file_path)

	# Now write the content to the files
	for i in range(file_paths.size()):
		if i >= file_contents.size():
			break

		var file_path = file_paths[i]
		var content = file_contents[i]

		# Make sure the directory exists
		var dir = DirAccess.open("res://")
		var dir_path = file_path.get_base_dir()
		if not dir_path.is_empty() and not dir.dir_exists(dir_path):
			dir.make_dir_recursive(dir_path)

		# Write the content to the file
		var file = FileAccess.open(file_path, FileAccess.WRITE)
		if file:
			file.store_string(content)
			file.close()
			_add_system_message("Successfully wrote content to file: " + file_path)
		else:
			_add_system_message("Error: Failed to write to file: " + file_path)

	if file_paths.size() > 0:
		_add_system_message("Direct file writing completed successfully.")

		# If any of the files are scenes, try to open them in the editor
		for file_path in file_paths:
			if file_path.ends_with(".tscn"):
				editor_interface.open_scene_from_path(file_path)
				_add_system_message("Opened scene: " + file_path)
				break
	else:
		_add_system_message("No files were written. Try rephrasing your request to include file paths and content.")

func _handle_code_generation_response(response):
	# Extract code blocks from the response
	var code_blocks = code_executor.extract_code_from_response(response.text)

	if code_blocks.size() > 0 and not code_blocks[0].strip_edges().is_empty():
		# Get the currently edited script
		var editor = editor_interface.get_script_editor()
		var current_script = editor.get_current_script()

		if current_script:
			# Get the script path
			var script_path = current_script.resource_path

			# Clean up the code for display
			var display_code = code_blocks[0]
			if display_code.length() > 100:
				display_code = display_code.substr(0, 100) + "..."

			# Ask the user if they want to insert the code
			_add_system_message("Code generated (" + str(code_blocks[0].length()) + " characters). Preview:\n```\n" + display_code + "\n```\n\nWould you like to:\n1. Insert at cursor (reply with '1')\n2. Replace current script (reply with '2')\n3. Do nothing (reply with '3')")

			# Store the code blocks for later use
			context_manager.generated_code = code_blocks[0]
			context_manager.target_script = script_path
		else:
			_add_system_message("No script is currently open in the editor. Please open a script to insert the generated code.")
	else:
		_add_system_message("No code was generated. Try rephrasing your request or providing more details.")

func _add_user_message(text):
	messages.append({"role": "user", "text": text})

	# Create a message container with iOS-like styling
	var message_container = HBoxContainer.new()
	message_container.alignment = BoxContainer.ALIGNMENT_END
	message_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var message_label = RichTextLabel.new()
	message_label.fit_content = true
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_label.bbcode_enabled = true
	message_label.text = text
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Apply iOS styling
	var ios_style_script_path = "res://addons/vector_ai/resources/ios_chat_style.gd"
	var ios_style_script = load(ios_style_script_path) if ResourceLoader.exists(ios_style_script_path) else null

	if ios_style_script:
		ios_style_script.apply_to_rich_text_label(message_label, true, false)

	panel.add_child(message_label)
	message_container.add_child(panel)
	chat_history.add_child(message_container)

	chat_history.scroll_to_line(chat_history.get_line_count() - 1)

	# Check for code insertion responses
	if context_manager.generated_code.length() > 0 and context_manager.target_script.length() > 0:
		if text == "1":
			var result = context_manager.insert_code_at_cursor(context_manager.target_script)
			if result.success:
				_add_system_message("Code inserted at cursor position.")
			else:
				_add_system_message("Error inserting code: " + result.error)

			# Clear the stored code
			context_manager.generated_code = ""
			context_manager.target_script = ""
		elif text == "2":
			var result = context_manager.replace_script_content(context_manager.target_script)
			if result.success:
				_add_system_message("Script content replaced.")
			else:
				_add_system_message("Error replacing script content: " + result.error)

			# Clear the stored code
			context_manager.generated_code = ""
			context_manager.target_script = ""
		elif text == "3":
			_add_system_message("Code insertion cancelled.")

			# Clear the stored code
			context_manager.generated_code = ""
			context_manager.target_script = ""
		# Handle JSON command execution
		elif context_manager.target_script == "json_commands" and (text.to_lower() == "yes" or text.to_lower() == "y"):
			_add_system_message("Executing JSON commands...")
			var result = json_command_processor.process_json_commands(context_manager.generated_code)

			if result.success:
				_add_system_message("Successfully executed JSON commands.")

				# If there are results, show them
				if result.has("results"):
					for command_result in result.results:
						if command_result.has("message"):
							_add_system_message(command_result.message)
			else:
				_add_system_message("Error executing JSON commands: " + result.error)

			# Clear the stored code
			context_manager.generated_code = ""
			context_manager.target_script = ""
		elif context_manager.target_script == "json_commands" and (text.to_lower() == "no" or text.to_lower() == "n"):
			_add_system_message("JSON command execution cancelled.")

			# Clear the stored code
			context_manager.generated_code = ""
			context_manager.target_script = ""

func _add_ai_message(text):
	messages.append({"role": "ai", "text": text})

	# Create a message container with iOS-like styling
	var message_container = HBoxContainer.new()
	message_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	message_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var message_label = RichTextLabel.new()
	message_label.fit_content = true
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_label.bbcode_enabled = true
	message_label.text = text
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Apply iOS styling
	var ios_style_script_path = "res://addons/vector_ai/resources/ios_chat_style.gd"
	var ios_style_script = load(ios_style_script_path) if ResourceLoader.exists(ios_style_script_path) else null

	if ios_style_script:
		ios_style_script.apply_to_rich_text_label(message_label, false, false)

	panel.add_child(message_label)
	message_container.add_child(panel)
	chat_history.add_child(message_container)

	chat_history.scroll_to_line(chat_history.get_line_count() - 1)

func _add_system_message(text):
	# Create a message container with iOS-like styling
	var message_container = HBoxContainer.new()
	message_container.alignment = BoxContainer.ALIGNMENT_CENTER
	message_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var message_label = RichTextLabel.new()
	message_label.fit_content = true
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_label.bbcode_enabled = true
	message_label.text = "System: " + text
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Apply iOS styling
	var ios_style_script_path = "res://addons/vector_ai/resources/ios_chat_style.gd"
	var ios_style_script = load(ios_style_script_path) if ResourceLoader.exists(ios_style_script_path) else null

	if ios_style_script:
		ios_style_script.apply_to_rich_text_label(message_label, false, true)

	message_container.add_child(message_label)
	chat_history.add_child(message_container)

	chat_history.scroll_to_line(chat_history.get_line_count() - 1)

# Add a copyable code block to the chat history
func _add_copyable_code_block(block_id, code, language = "gdscript"):
	# Create a message container
	var message_container = HBoxContainer.new()
	message_container.alignment = BoxContainer.ALIGNMENT_CENTER
	message_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Create a panel for the code block
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Create a vertical container for the code and buttons
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Create a header with language and copy button
	var header = HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var language_label = Label.new()
	language_label.text = language.capitalize()
	language_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var copy_button = Button.new()
	copy_button.text = "Copy"
	copy_button.tooltip_text = "Copy code to clipboard"
	copy_button.size_flags_horizontal = Control.SIZE_SHRINK_END

	# Connect the copy button
	copy_button.pressed.connect(_on_copy_code_button_pressed.bind(block_id))

	header.add_child(language_label)
	header.add_child(copy_button)

	# Create the code text edit
	var code_edit = TextEdit.new()
	code_edit.name = block_id
	code_edit.text = code
	code_edit.editable = false
	code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	code_edit.custom_minimum_size = Vector2(0, 200)  # Set a minimum height

	# Set syntax highlighting based on language
	if language == "gdscript":
		code_edit.syntax_highlighter = _create_gdscript_syntax_highlighter()
	elif language == "json":
		code_edit.syntax_highlighter = _create_json_syntax_highlighter()

	# Add components to the container
	vbox.add_child(header)
	vbox.add_child(code_edit)

	panel.add_child(vbox)
	message_container.add_child(panel)

	# Add to chat history
	chat_history.add_child(message_container)
	chat_history.scroll_to_line(chat_history.get_line_count() - 1)

# Handle copy code button press
func _on_copy_code_button_pressed(block_id):
	var code_edit = chat_history.find_child(block_id, true, false)
	if code_edit and code_edit is TextEdit:
		DisplayServer.clipboard_set(code_edit.text)
		_add_system_message("Code copied to clipboard.")

# Create a GDScript syntax highlighter
func _create_gdscript_syntax_highlighter():
	var syntax_highlighter = SyntaxHighlighter.new()
	# In a real implementation, we would configure the syntax highlighter
	# But for now, we'll just return a basic one
	return syntax_highlighter

# Create a JSON syntax highlighter
func _create_json_syntax_highlighter():
	var syntax_highlighter = SyntaxHighlighter.new()
	# In a real implementation, we would configure the syntax highlighter
	# But for now, we'll just return a basic one
	return syntax_highlighter

# Extract JSON commands from response
func _extract_json_commands(response_text):
	var json_start = response_text.find("```json")
	if json_start == -1:
		json_start = response_text.find("```JSON")

	if json_start != -1:
		var json_end = response_text.find("```", json_start + 6)
		if json_end != -1:
			return response_text.substr(json_start + 7, json_end - json_start - 7).strip_edges()

	return ""
