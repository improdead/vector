@tool
extends Control

# Main dock for Vector AI
# Handles user input and displays AI responses

var plugin
var gemini_client
var scene_generator

func _ready():
	# Initialize components
	gemini_client = preload("res://addons/vector_ai/scripts/gemini_client.gd").new()
	add_child(gemini_client)

	scene_generator = preload("res://addons/vector_ai/scripts/scene_generator.gd").new()
	add_child(scene_generator)

	# Note: Signals are already connected in the scene file
	# No need to connect them again here

	# Load settings
	if plugin:
		$SettingsDialog/VBoxContainer/APIKeyInput.text = plugin.settings.api_key
		$SettingsDialog/VBoxContainer/ModelInput.text = plugin.settings.model

		# Initialize Gemini client with settings
		gemini_client.api_key = plugin.settings.api_key
		gemini_client.model = plugin.settings.model

# Handle generate button press
func _on_generate_button_pressed():
	var user_input = $VBoxContainer/InputText.text.strip_edges()
	if user_input.is_empty():
		$VBoxContainer/OutputText.text = "Please enter a request."
		return

	# Update UI
	$VBoxContainer/GenerateButton.disabled = true
	$VBoxContainer/OutputText.text = "Generating..."

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

	# Read the current scene content
	var current_scene = scene_generator.read_current_scene()
	print("Current scene content length: " + str(current_scene.length()))

	# Create the prompt for game generation
	var prompt = create_game_prompt(description, current_scene)
	print("Created prompt for game generation")

	# Send the request to Gemini
	print("Sending request to Gemini...")
	gemini_client.send_request(prompt, func(response, error):
		print("Received response from Gemini")

		if error:
			print("Error from Gemini: " + error)
			$VBoxContainer/OutputText.text = "Error: " + error
		else:
			print("Response received successfully")

			# Extract code from the response
			var code = extract_code_from_response(response.text)
			if code.is_empty():
				print("No code found in the response")
				$VBoxContainer/OutputText.text = "No code found in the response."
			else:
				print("Code extracted successfully, length: " + str(code.length()))

				# Create the scene with the generated code
				print("Creating scene with generated code...")
				var result = scene_generator.create_scene_with_code(code)

				if result.success:
					print("Scene created successfully!")

					# Extract only the analysis and explanation parts
					var analysis = extract_analysis(response.text)
					var explanation = extract_explanation(response.text)

					# Show only analysis and explanation, not the code
					$VBoxContainer/OutputText.text = "[b]Game generated successfully![/b]\n\n[b]ANALYSIS:[/b]\n" + analysis + "\n\n[b]EXPLANATION:[/b]\n" + explanation
				else:
					print("Error creating scene: " + result.message)
					$VBoxContainer/OutputText.text = "Error creating scene: " + result.message

		# Re-enable the generate button
		$VBoxContainer/GenerateButton.disabled = false
	)

# Generate code based on the description
func generate_code(description):
	# Read the current scene content
	var current_scene = scene_generator.read_current_scene()

	# Create the prompt for code generation
	var prompt = create_code_prompt(description, current_scene)

	# Send the request to Gemini
	gemini_client.send_request(prompt, func(response, error):
		if error:
			$VBoxContainer/OutputText.text = "Error: " + error
		else:
			# Extract code from the response
			var code = extract_code_from_response(response.text)
			if code.is_empty():
				$VBoxContainer/OutputText.text = "No code found in the response."
			else:
				# Create the scene with the generated code
				var result = scene_generator.create_scene_with_code(code)
				if result.success:
					# Extract only the analysis and explanation parts
					var analysis = extract_analysis(response.text)
					var explanation = extract_explanation(response.text)

					# Show only analysis and explanation, not the code
					$VBoxContainer/OutputText.text = "[b]Code generated successfully![/b]\n\n[b]ANALYSIS:[/b]\n" + analysis + "\n\n[b]EXPLANATION:[/b]\n" + explanation
				else:
					$VBoxContainer/OutputText.text = "Error creating scene: " + result.message

		# Re-enable the generate button
		$VBoxContainer/GenerateButton.disabled = false
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

	Your response should include:

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

	var code_start = response_text.find("```gdscript")
	if code_start == -1:
		print("ERROR: No ```gdscript marker found in response")
		return ""

	var code_end = response_text.find("```", code_start + 11)
	if code_end == -1:
		print("ERROR: No closing ``` marker found in response")
		return ""

	var code = response_text.substr(code_start + 11, code_end - code_start - 11).strip_edges()
	print("Extracted code length: " + str(code.length()))

	return code

# Handle settings button press
func _on_settings_button_pressed():
	$SettingsDialog.popup_centered()

# Handle save button press in settings dialog
func _on_save_button_pressed():
	if plugin:
		plugin.settings.api_key = $SettingsDialog/VBoxContainer/APIKeyInput.text
		plugin.settings.model = $SettingsDialog/VBoxContainer/ModelInput.text
		plugin.save_settings()

		# Update Gemini client with new settings
		gemini_client.api_key = plugin.settings.api_key
		gemini_client.model = plugin.settings.model

	$SettingsDialog.hide()

# Handle settings dialog close
func _on_settings_dialog_close_requested():
	$SettingsDialog.hide()
