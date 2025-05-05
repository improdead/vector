@tool
extends Control

# Main dock for Vector AI
# Handles user input and displays AI responses

var plugin
var gemini_client
var scene_generator
var reload_button

func _ready():
	# Initialize components
	var GeminiClient = load("res://addons/vector_ai/scripts/gemini_client.gd")
	gemini_client = GeminiClient.new()
	add_child(gemini_client)

	var SceneGenerator = load("res://addons/vector_ai/scripts/scene_generator.gd")
	scene_generator = SceneGenerator.new()
	add_child(scene_generator)

	# Note: Signals are already connected in the scene file
	# No need to connect them again here

	# Load settings
	if plugin:
		$SettingsDialog/PanelContainer/VBoxContainer/APIKeyInput.text = plugin.settings.api_key
		$SettingsDialog/PanelContainer/VBoxContainer/ModelInput.text = plugin.settings.model

		# Initialize Gemini client with settings
		gemini_client.api_key = plugin.settings.api_key
		gemini_client.model = plugin.settings.model

# Handle generate button press
func _on_generate_button_pressed():
	var user_input = $PanelContainer/VBoxContainer/InputText.text.strip_edges()
	if user_input.is_empty():
		$PanelContainer/VBoxContainer/OutputText.text = "Please enter a request."
		return

	# Update UI
	$PanelContainer/VBoxContainer/GenerateButton.disabled = true
	$PanelContainer/VBoxContainer/OutputText.text = "Generating..."

	# Process the request
	process_request(user_input)

# Process the user request
func process_request(user_input):
	# Check if this is a game creation request
	if is_game_creation_request(user_input):
		# Generate a game based on the description
		generate_game(user_input)
	else:
		# Generate code based on the description
		generate_code(user_input)

# Check if this is a game creation request
func is_game_creation_request(user_input):
	var lower_input = user_input.to_lower()
	var game_keywords = ["game", "make me a", "create a game", "build a game"]

	for keyword in game_keywords:
		if lower_input.find(keyword) != -1:
			return true

	return false

# Generate a game based on the description
func generate_game(description):
	print("Generating game based on description: " + description)

	# Remove reload button if it exists
	remove_reload_button()

	# Read the current scene content
	var current_scene = scene_generator.read_current_scene()
	print("Current scene content length: " + str(current_scene.length()))

	# Create the prompt for game generation
	var prompt = create_game_prompt(description, current_scene)
	print("Created prompt for game generation")
	print("Prompt length: " + str(prompt.length()))

	# Update UI to show we're sending the request
	$PanelContainer/VBoxContainer/OutputText.text = "Sending request to Gemini...\nThis may take a moment."

	# Send the request to Gemini
	print("Sending request to Gemini...")
	gemini_client.send_request(prompt, func(response, error):
		print("Received response from Gemini")

		if error:
			print("Error from Gemini: " + error)
			$PanelContainer/VBoxContainer/OutputText.text = "Error from Gemini: " + error

			# Add a retry button
			var retry_button = Button.new()
			retry_button.name = "RetryButton"
			retry_button.text = "Retry Request"
			retry_button.pressed.connect(func(): generate_game(description))
			$PanelContainer/VBoxContainer.add_child(retry_button)

			# Move the button to be right after the output text
			var output_text_idx = $PanelContainer/VBoxContainer.get_children().find($PanelContainer/VBoxContainer/OutputText)
			if output_text_idx != -1:
				$PanelContainer/VBoxContainer.move_child(retry_button, output_text_idx + 1)
		else:
			print("Response received successfully")

			# Check if response text exists
			if not response.has("text") or response.text.is_empty():
				print("Response object doesn't contain text or text is empty")
				$PanelContainer/VBoxContainer/OutputText.text = "Error: Received empty response from Gemini API."
				return

			print("Response text length: " + str(response.text.length()))

			# Log a snippet of the response for debugging
			var snippet_length = min(100, response.text.length())
			print("Response text snippet: " + response.text.substr(0, snippet_length) + "...")

			# Extract code from the response
			var code = extract_code_from_response(response.text)
			if code.is_empty():
				print("No code found in the response")
				$PanelContainer/VBoxContainer/OutputText.text = "No code found in the response. The API response didn't contain properly formatted code blocks.\n\nResponse snippet:\n" + response.text.substr(0, min(500, response.text.length()))
			else:
				print("Code extracted successfully, length: " + str(code.length()))
				print("Code snippet: " + code.substr(0, min(100, code.length())) + "...")

				# Create the scene with the generated code
				print("Creating scene with generated code...")
				var result = scene_generator.create_scene_with_code(code)

				if result.success:
					print("Scene created successfully!")

					# Extract only the analysis and explanation parts
					var analysis = extract_analysis(response.text)
					var explanation = extract_explanation(response.text)

					# Show only analysis and explanation, not the code
					var output_text = "[b]Game generated successfully![/b]\n\n[b]ANALYSIS:[/b]\n" + analysis + "\n\n[b]EXPLANATION:[/b]\n" + explanation

					# Add reload status information
					output_text += "\n\n[b]IMPORTANT:[/b] The scene file has been updated. To use it in Godot:"
					output_text += "\n1. Click the 'Open Scene in Godot' button below"
					output_text += "\n2. Or navigate to main.tscn in the FileSystem panel and double-click it"

					# Always add buttons for better user experience
					add_reload_button()
					add_external_editor_button()
					add_open_in_godot_button()

					# Add backup file information if available
					if result.has("backup_path"):
						output_text += "\n\n[b]BACKUP:[/b] A backup copy of the generated file is also available at: " + result.backup_path

					$PanelContainer/VBoxContainer/OutputText.text = output_text

					# Try to reload the scene if the plugin has access to the editor interface
					if plugin and plugin.get_editor_interface():
						print("Attempting to reload the current scene...")
						# This will only work if the scene is already open in the editor
						plugin.get_editor_interface().reload_scene_from_path("res://main.tscn")
				else:
					print("Error creating scene: " + result.message)
					$PanelContainer/VBoxContainer/OutputText.text = "Error creating scene: " + result.message

					# Add backup file information if available
					if result.has("backup_path"):
						$PanelContainer/VBoxContainer/OutputText.text += "\n\nA backup copy of the generated file is available at: " + result.backup_path

		# Re-enable the generate button
		$PanelContainer/VBoxContainer/GenerateButton.disabled = false
	)

# Generate code based on the description
func generate_code(description):
	# Remove reload button if it exists
	remove_reload_button()

	# Read the current scene content
	var current_scene = scene_generator.read_current_scene()

	# Create the prompt for code generation
	var prompt = create_code_prompt(description, current_scene)

	# Send the request to Gemini
	gemini_client.send_request(prompt, func(response, error):
		if error:
			$PanelContainer/VBoxContainer/OutputText.text = "Error: " + error
		else:
			# Extract code from the response
			var code = extract_code_from_response(response.text)
			if code.is_empty():
				$PanelContainer/VBoxContainer/OutputText.text = "No code found in the response."
			else:
				# Create the scene with the generated code
				var result = scene_generator.create_scene_with_code(code)
				if result.success:
					# Extract only the analysis and explanation parts
					var analysis = extract_analysis(response.text)
					var explanation = extract_explanation(response.text)

					# Show only analysis and explanation, not the code
					var output_text = "[b]Code generated successfully![/b]\n\n[b]ANALYSIS:[/b]\n" + analysis + "\n\n[b]EXPLANATION:[/b]\n" + explanation

					# Add reload status information
					output_text += "\n\n[b]IMPORTANT:[/b] The scene file has been updated. To use it in Godot:"
					output_text += "\n1. Click the 'Open Scene in Godot' button below"
					output_text += "\n2. Or navigate to main.tscn in the FileSystem panel and double-click it"

					# Always add buttons for better user experience
					add_reload_button()
					add_external_editor_button()
					add_open_in_godot_button()

					# Add backup file information if available
					if result.has("backup_path"):
						output_text += "\n\n[b]BACKUP:[/b] A backup copy of the generated file is also available at: " + result.backup_path

					$PanelContainer/VBoxContainer/OutputText.text = output_text

					# Try to reload the scene if the plugin has access to the editor interface
					if plugin and plugin.get_editor_interface():
						print("Attempting to reload the current scene...")
						# This will only work if the scene is already open in the editor
						plugin.get_editor_interface().reload_scene_from_path("res://main.tscn")
				else:
					$PanelContainer/VBoxContainer/OutputText.text = "Error creating scene: " + result.message

		# Re-enable the generate button
		$PanelContainer/VBoxContainer/GenerateButton.disabled = false
	)

# Create a prompt for game generation
func create_game_prompt(description, current_scene):
	return """
	You are Vector AI, an AI assistant that helps users create custom games in Godot.
	You can generate complete game implementations from scratch based on user descriptions.

	For custom game creation, focus on writing a COMPLETE, SELF-CONTAINED script that implements the entire game.
	The script will be embedded directly in a scene file as a GDScript resource.

	User request: """ + description + """

	Current scene content:
	```
	""" + current_scene + """
	```

	Your response MUST follow this EXACT format:

	ANALYSIS:
	[Your analysis of the game request and how you plan to implement it]

	IMPLEMENTATION:
	```gdscript
	extends Node2D

	# Game implementation here
	# Include ALL necessary code to make the game work
	# Use proper Godot 4.x syntax
	# Always declare variables with var or const
	# Include comments explaining the code
	# Create all necessary nodes in _ready()
	# Handle all game logic in this single script
	```

	EXPLANATION:
	[Explanation of how the game works and how to play it]

	CRITICAL FORMATTING REQUIREMENTS:
	1. ALWAYS declare ALL variables with 'var' or 'const' keywords
	2. Class-level variables MUST be declared with 'var' or 'const'
	   CORRECT: var tile_map = TileMap.new()
	   INCORRECT: tile_map = TileMap.new()
	3. Variables can only be assigned without 'var' inside functions
	4. Always include a class declaration (extends Node2D) at the top
	5. Follow Godot naming conventions:
	   - snake_case for variables and functions
	   - PascalCase for classes and nodes
	   - UPPER_CASE for constants
	6. EVERY variable at class level MUST start with 'var' or 'const'
	7. NEVER use bare identifiers at class level
	8. Use consistent indentation with tabs or spaces
	9. For Vector2 values, use Vector2(x, y) format, not (x, y)
	10. For colors, use Color(r, g, b) or Color.html("#hexcode") format
	11. Always use semicolons at the end of statements where appropriate
	12. Always use proper function declarations with colons: func my_function():
	13. Always properly initialize arrays and dictionaries: var my_array = []
	14. Always use proper signal connections: some_node.signal_name.connect(self._on_signal_name)

	IMPORTANT GUIDELINES:
	1. Write a COMPLETE, SELF-CONTAINED script that creates all necessary nodes programmatically
	2. Use Godot 4.x specific syntax and features
	3. Include proper error handling
	4. Add clear comments explaining complex logic
	5. Make sure the game is complete and playable
	6. Include all necessary components (player, enemies, UI, etc.)
	7. Create all nodes programmatically in _ready() function
	8. Handle all input, physics, and game logic in this single script
	9. DO NOT rely on external scene files or resources
	10. DO NOT use external scripts - put everything in this one script
	11. Make sure the script is completely self-contained
	12. The script will be embedded in a scene file and attached to a Node2D
	13. DO NOT include the script path or file name in your code
	14. DO NOT include any file operations or loading external scripts
	15. Make sure to properly handle node references and avoid null references
	16. Use proper error handling with if statements to check for null values
	17. Ensure all variables are properly declared before use
	18. Use proper Godot 4.x signal connection syntax
	19. Ensure all code is syntactically correct and will run without errors
	20. Test your code mentally to ensure it works as expected

	COMMON ERRORS TO AVOID:
	1. Undeclared variables at class level (always use var/const)
	2. Missing semicolons at the end of statements
	3. Incorrect signal connection syntax
	4. Improper function declarations (missing colons)
	5. Accessing properties of null objects (always check if objects exist)
	6. Using incorrect Godot 4.x syntax (make sure to use the latest syntax)
	7. Improper indentation or code structure
	8. Missing or incorrect extends statement
	9. Incorrect node paths or references
	10. Improper initialization of arrays, dictionaries, or other data structures

	MAZE GAME SPECIFIC GUIDELINES:
	If creating a maze game:
	1. Use a TileMap for the maze layout
	2. Create a player character that can navigate the maze
	3. Add collision detection for walls
	4. Include a goal or objective (e.g., reach the exit, collect items)
	5. Consider adding enemies or obstacles
	6. Add a UI to show score, time, or other game information
	7. Include a win condition and game over state
	8. Add visual feedback for player actions
	9. Consider adding sound effects for actions
	10. Make sure the controls are intuitive (arrow keys or WASD)

	IMPORTANT: Your response MUST include the code block with the ```gdscript marker exactly as shown above.
	The code MUST be syntactically correct Godot 4.x GDScript code.
	"""

# Create a prompt for code generation
func create_code_prompt(description, current_scene):
	return """
	You are Vector AI, an AI assistant that helps users generate GDScript code for their Godot projects.
	You can generate complete code implementations from scratch based on user descriptions.

	User request: """ + description + """

	Current scene content:
	```
	""" + current_scene + """
	```

	Your response should include:

	ANALYSIS:
	[Your analysis of the request and how you plan to implement it]

	IMPLEMENTATION:
	```gdscript
	extends Node2D

	# Code implementation here
	# Include ALL necessary code to make it work
	# Use proper Godot 4.x syntax
	# Always declare variables with var or const
	# Include comments explaining the code
	```

	EXPLANATION:
	[Explanation of how the code works and how to use it]

	CRITICAL FORMATTING REQUIREMENTS:
	1. ALWAYS declare ALL variables with 'var' or 'const' keywords
	2. Class-level variables MUST be declared with 'var' or 'const'
	   CORRECT: var tile_map = TileMap.new()
	   INCORRECT: tile_map = TileMap.new()
	3. Variables can only be assigned without 'var' inside functions
	4. Always include a class declaration (extends Node2D) at the top
	5. Follow Godot naming conventions:
	   - snake_case for variables and functions
	   - PascalCase for classes and nodes
	   - UPPER_CASE for constants
	6. EVERY variable at class level MUST start with 'var' or 'const'
	7. NEVER use bare identifiers at class level
	8. Use consistent indentation with tabs or spaces
	9. For Vector2 values, use Vector2(x, y) format, not (x, y)
	10. For colors, use Color(r, g, b) or Color.html("#hexcode") format
	11. Always use semicolons at the end of statements where appropriate
	12. Always use proper function declarations with colons: func my_function():
	13. Always properly initialize arrays and dictionaries: var my_array = []
	14. Always use proper signal connections: some_node.signal_name.connect(self._on_signal_name)

	IMPORTANT GUIDELINES:
	1. Write a COMPLETE, SELF-CONTAINED script
	2. Use Godot 4.x specific syntax and features
	3. Include proper error handling
	4. Add clear comments explaining complex logic
	5. Make sure the code is complete and functional
	6. The script will be embedded in a scene file and attached to a Node2D
	7. DO NOT include the script path or file name in your code
	8. DO NOT include any file operations or loading external scripts
	9. If creating nodes programmatically, do it in the _ready() function
	10. Make sure to handle all necessary signals and input events
	11. Make sure to properly handle node references and avoid null references
	12. Use proper error handling with if statements to check for null values
	13. Ensure all variables are properly declared before use
	14. Use proper Godot 4.x signal connection syntax
	15. Ensure all code is syntactically correct and will run without errors
	16. Test your code mentally to ensure it works as expected

	COMMON ERRORS TO AVOID:
	1. Undeclared variables at class level (always use var/const)
	2. Missing semicolons at the end of statements
	3. Incorrect signal connection syntax
	4. Improper function declarations (missing colons)
	5. Accessing properties of null objects (always check if objects exist)
	6. Using incorrect Godot 4.x syntax (make sure to use the latest syntax)
	7. Improper indentation or code structure
	8. Missing or incorrect extends statement
	9. Incorrect node paths or references
	10. Improper initialization of arrays, dictionaries, or other data structures
	"""

# Extract the analysis section from the response
func extract_analysis(response_text):
	var analysis_start = response_text.find("ANALYSIS:")
	var analysis_end = response_text.find("IMPLEMENTATION:")

	if analysis_start != -1 and analysis_end != -1:
		return response_text.substr(analysis_start + 9, analysis_end - analysis_start - 9).strip_edges()

	return "No analysis found in the response."

# Extract the explanation section from the response
func extract_explanation(response_text):
	var explanation_start = response_text.find("EXPLANATION:")
	var critical_start = response_text.find("CRITICAL FORMATTING REQUIREMENTS:")

	if explanation_start != -1 and critical_start != -1:
		return response_text.substr(explanation_start + 12, critical_start - explanation_start - 12).strip_edges()
	elif explanation_start != -1:
		# If there's no "CRITICAL FORMATTING REQUIREMENTS" section, try to get the rest of the text
		return response_text.substr(explanation_start + 12).strip_edges()

	return "No explanation found in the response."

# Extract code from the AI response
func extract_code_from_response(response_text):
	print("Extracting code from response...")

	if response_text.is_empty():
		print("ERROR: Response text is empty")
		return ""

	# Try to find code block with ```gdscript marker
	var code_start = response_text.find("```gdscript")
	if code_start == -1:
		# Try alternative markers
		code_start = response_text.find("```GDScript")
		if code_start == -1:
			code_start = response_text.find("```gd")
			if code_start == -1:
				# Try just finding any code block
				code_start = response_text.find("```")
				if code_start == -1:
					print("ERROR: No code block markers found in response")
					return ""
				else:
					print("Found generic code block marker")
					code_start += 3  # Skip past the ```
			else:
				print("Found ```gd marker")
				code_start += 5  # Skip past the ```gd
		else:
			print("Found ```GDScript marker")
			code_start += 11  # Skip past the ```GDScript
	else:
		print("Found ```gdscript marker")
		code_start += 11  # Skip past the ```gdscript

	# Find the closing code block marker
	var code_end = response_text.find("```", code_start)
	if code_end == -1:
		print("ERROR: No closing ``` marker found in response")

		# Try to extract until the end of the response as a fallback
		var code = response_text.substr(code_start).strip_edges()
		print("Fallback: Extracted code from marker to end, length: " + str(code.length()))

		# Check if the code looks valid (contains extends or func keywords)
		if code.find("extends") != -1 or code.find("func") != -1:
			print("Fallback code appears to contain valid GDScript")
			return code
		else:
			print("Fallback code doesn't appear to be valid GDScript")
			return ""

	var code = response_text.substr(code_start, code_end - code_start).strip_edges()
	print("Extracted code length: " + str(code.length()))

	# Validate that the code looks like GDScript
	if code.find("extends") == -1 and code.find("func") == -1:
		print("WARNING: Extracted code doesn't appear to contain GDScript keywords")

		# If it doesn't look like GDScript, try to find another code block
		var next_start = response_text.find("```", code_end + 3)
		if next_start != -1:
			print("Found another code block, trying that one instead")
			next_start += 3
			var next_end = response_text.find("```", next_start)
			if next_end != -1:
				var next_code = response_text.substr(next_start, next_end - next_start).strip_edges()
				if next_code.find("extends") != -1 or next_code.find("func") != -1:
					print("Found valid GDScript in second code block")
					return next_code

	# If the code doesn't start with 'extends', add it
	if not code.strip_edges().begins_with("extends") and not "extends Node2D" in code:
		print("Adding missing extends statement")
		code = "extends Node2D\n\n" + code

	return code

# Handle settings button press
func _on_settings_button_pressed():
	$SettingsDialog.popup_centered()

# Handle save button press in settings dialog
func _on_save_button_pressed():
	if plugin:
		plugin.settings.api_key = $SettingsDialog/PanelContainer/VBoxContainer/APIKeyInput.text
		plugin.settings.model = $SettingsDialog/PanelContainer/VBoxContainer/ModelInput.text
		plugin.save_settings()

		# Update Gemini client with new settings
		gemini_client.api_key = plugin.settings.api_key
		gemini_client.model = plugin.settings.model

	$SettingsDialog.hide()

# Handle settings dialog close
func _on_settings_dialog_close_requested():
	$SettingsDialog.hide()

# Add a manual reload button
func add_reload_button():
	# Remove any existing reload button first
	remove_reload_button()

	# Create a new reload button
	reload_button = Button.new()
	reload_button.name = "ReloadButton"
	reload_button.text = "Reload Scene"
	reload_button.icon = get_theme_icon("Reload", "EditorIcons") if has_theme_icon("Reload", "EditorIcons") else null
	reload_button.pressed.connect(_reload_current_scene)

	# Style the button
	reload_button.add_theme_font_size_override("font_size", 14)
	reload_button.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))
	reload_button.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1.0))

	# Add the button to the UI
	$PanelContainer/VBoxContainer.add_child(reload_button)

	# Move the button to be right after the output text
	var output_text_idx = $PanelContainer/VBoxContainer.get_children().find($PanelContainer/VBoxContainer/OutputText)
	if output_text_idx != -1:
		$PanelContainer/VBoxContainer.move_child(reload_button, output_text_idx + 1)

# Remove the reload button if it exists
func remove_reload_button():
	if reload_button and is_instance_valid(reload_button) and reload_button.get_parent():
		reload_button.get_parent().remove_child(reload_button)
		reload_button.queue_free()
		reload_button = null

	# Also check for any other reload buttons that might exist
	var existing_button = $PanelContainer/VBoxContainer.get_node_or_null("ReloadButton")
	if existing_button:
		existing_button.get_parent().remove_child(existing_button)
		existing_button.queue_free()

# Reload the current scene
func _reload_current_scene():
	if plugin and plugin.get_editor_interface():
		var editor_interface = plugin.get_editor_interface()

		# Try multiple reload methods
		print("Manual reload requested")

		# Method 1: Reload the current scene
		var current_scene_path = "res://main.tscn"
		editor_interface.reload_scene_from_path(current_scene_path)

		# Method 2: Try to get the FileSystem and scan
		var filesystem = editor_interface.get_resource_filesystem()
		if filesystem:
			print("Scanning filesystem...")
			filesystem.scan()
			filesystem.scan_sources()

		# Method 3: Try to force a resource reimport
		var resource_path = "res://main.tscn"
		if ResourceLoader.has_cached(resource_path):
			ResourceLoader.load(resource_path, "", ResourceLoader.CACHE_MODE_REPLACE)
			print("Resource cache replaced")

		# Update the output text to indicate reload attempt
		$PanelContainer/VBoxContainer/OutputText.text += "\n\nManual reload attempted. If you still don't see changes, please close and reopen the scene file."
	else:
		$PanelContainer/VBoxContainer/OutputText.text += "\n\nCannot access editor interface for manual reload. Please close and reopen the scene file."

# Add a button to open the file in an external editor
func add_external_editor_button():
	# Create a new button
	var external_editor_button = Button.new()
	external_editor_button.name = "ExternalEditorButton"
	external_editor_button.text = "Open in External Editor"
	external_editor_button.icon = get_theme_icon("ExternalLink", "EditorIcons") if has_theme_icon("ExternalLink", "EditorIcons") else null
	external_editor_button.pressed.connect(_open_in_external_editor)

	# Style the button
	external_editor_button.add_theme_font_size_override("font_size", 14)
	external_editor_button.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))
	external_editor_button.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1.0))

	# Add the button to the UI
	$PanelContainer/VBoxContainer.add_child(external_editor_button)

	# Move the button to be right after the reload button if it exists
	var reload_button_idx = -1
	for i in range($PanelContainer/VBoxContainer.get_child_count()):
		if $PanelContainer/VBoxContainer.get_child(i).name == "ReloadButton":
			reload_button_idx = i
			break

	if reload_button_idx != -1:
		$PanelContainer/VBoxContainer.move_child(external_editor_button, reload_button_idx + 1)
	else:
		# Otherwise, move it after the output text
		var output_text_idx = $PanelContainer/VBoxContainer.get_children().find($PanelContainer/VBoxContainer/OutputText)
		if output_text_idx != -1:
			$PanelContainer/VBoxContainer.move_child(external_editor_button, output_text_idx + 1)

# Open the main.tscn file in an external editor
func _open_in_external_editor():
	var project_dir = ProjectSettings.globalize_path("res://")
	var file_path = project_dir + "main.tscn"

	# Use PowerShell to open the file in the default editor
	var output = []
	var ps_command = "Invoke-Item '" + file_path + "'"

	var exit_code = OS.execute("powershell", ["-Command", ps_command], output)

	if exit_code != 0:
		$PanelContainer/VBoxContainer/OutputText.text += "\n\nFailed to open file in external editor: " + str(output)
	else:
		$PanelContainer/VBoxContainer/OutputText.text += "\n\nFile opened in external editor."

# Add a button to open the scene in Godot
func add_open_in_godot_button():
	# Create a new button
	var open_in_godot_button = Button.new()
	open_in_godot_button.name = "OpenInGodotButton"
	open_in_godot_button.text = "Open Scene in Godot"
	open_in_godot_button.icon = get_theme_icon("Load", "EditorIcons") if has_theme_icon("Load", "EditorIcons") else null
	open_in_godot_button.pressed.connect(_open_scene_in_godot)

	# Style the button
	open_in_godot_button.add_theme_font_size_override("font_size", 14)
	open_in_godot_button.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))
	open_in_godot_button.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1.0))

	# Add the button to the UI
	$PanelContainer/VBoxContainer.add_child(open_in_godot_button)

	# Move the button to be after the external editor button if it exists
	var external_editor_button_idx = -1
	for i in range($PanelContainer/VBoxContainer.get_child_count()):
		if $PanelContainer/VBoxContainer.get_child(i).name == "ExternalEditorButton":
			external_editor_button_idx = i
			break

	if external_editor_button_idx != -1:
		$PanelContainer/VBoxContainer.move_child(open_in_godot_button, external_editor_button_idx + 1)
	else:
		# Otherwise, move it after the reload button if it exists
		var reload_button_idx = -1
		for i in range($PanelContainer/VBoxContainer.get_child_count()):
			if $PanelContainer/VBoxContainer.get_child(i).name == "ReloadButton":
				reload_button_idx = i
				break

		if reload_button_idx != -1:
			$PanelContainer/VBoxContainer.move_child(open_in_godot_button, reload_button_idx + 1)
		else:
			# Otherwise, move it after the output text
			var output_text_idx = $PanelContainer/VBoxContainer.get_children().find($PanelContainer/VBoxContainer/OutputText)
			if output_text_idx != -1:
				$PanelContainer/VBoxContainer.move_child(open_in_godot_button, output_text_idx + 1)

# Open the main.tscn file in Godot
func _open_scene_in_godot():
	if plugin and plugin.get_editor_interface():
		var editor_interface = plugin.get_editor_interface()

		# Try to open the scene in the editor
		print("Opening main.tscn in Godot editor...")
		editor_interface.open_scene_from_path("res://main.tscn")

		$PanelContainer/VBoxContainer/OutputText.text += "\n\nScene opened in Godot editor."
	else:
		$PanelContainer/VBoxContainer/OutputText.text += "\n\nCannot access editor interface to open scene."
