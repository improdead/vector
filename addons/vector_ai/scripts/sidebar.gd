@tool
extends Control

# References to UI elements
var chat_history: RichTextLabel
var input_field: TextEdit
var send_button: Button
var settings_button: Button
var clear_button: Button

# References to other components
var gemini_client
var scene_analyzer
var scene_modifier
var code_executor

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

	# Initialize components
	gemini_client = load("res://addons/vector_ai/scripts/gemini_client.gd").new()
	scene_analyzer = load("res://addons/vector_ai/scripts/scene_analyzer.gd").new()
	scene_modifier = load("res://addons/vector_ai/scripts/scene_modifier.gd").new()
	code_executor = load("res://addons/vector_ai/scripts/code_executor.gd").new()

	add_child(gemini_client)
	add_child(scene_analyzer)
	add_child(scene_modifier)
	add_child(code_executor)

	# Initialize the chat history
	_add_system_message("Welcome to Vector AI! I can help you modify your Godot scenes based on natural language prompts. Type your request and press Enter or click Send.")

func _on_send_button_pressed():
	var user_input = input_field.text.strip_edges()
	if user_input.is_empty():
		return

	# Add user message to chat history
	_add_user_message(user_input)

	# Clear input field
	input_field.text = ""

	# Get current scene information
	var scene_info = scene_analyzer.analyze_current_scene()

	# Send request to Gemini API
	gemini_client.send_request(user_input, scene_info, _on_gemini_response)

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

func _on_gemini_response(response, error):
	if error:
		_add_system_message("Error: " + error)
		return

	# Add AI response to chat history
	_add_ai_message(response.text)

	# Extract code blocks from the response
	var code_blocks = code_executor.extract_code_from_response(response.text)

	# Execute each code block
	if code_blocks.size() > 0:
		var success = true
		var error_message = ""

		for code_block in code_blocks:
			var result = code_executor.execute_code(code_block)
			if not result.success:
				success = false
				error_message = result.error
				break

		if success:
			_add_system_message("Successfully executed code and modified the scene.")
		else:
			_add_system_message("Error executing code: " + error_message)

	# Apply modifications if requested
	elif response.has("modifications"):
		var result = scene_modifier.apply_modifications(response.modifications)
		if result.success:
			_add_system_message("Successfully applied modifications to the scene.")
		else:
			_add_system_message("Error applying modifications: " + result.error)

func _add_user_message(text):
	messages.append({"role": "user", "text": text})
	chat_history.append_text("\n[b]You:[/b] " + text + "\n")
	chat_history.scroll_to_line(chat_history.get_line_count() - 1)

func _add_ai_message(text):
	messages.append({"role": "ai", "text": text})
	chat_history.append_text("\n[b]Vector AI:[/b] " + text + "\n")
	chat_history.scroll_to_line(chat_history.get_line_count() - 1)

func _add_system_message(text):
	chat_history.append_text("\n[i][color=#888888]" + text + "[/color][/i]\n")
	chat_history.scroll_to_line(chat_history.get_line_count() - 1)
