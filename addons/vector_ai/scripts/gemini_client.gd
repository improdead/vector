@tool
extends Node

# Gemini API configuration
var api_key = ""
var model = "gemini-2.5-flash-preview-04-17"  # Using Gemini 2.5 Flash Preview model (not 1.5 Pro)
var temperature = 0.7
var max_output_tokens = 2048

# Reference to settings manager
var settings_manager

# HTTP request
var http_request

# Callback for response
var current_callback = null

func _ready():
	# Create HTTP request node
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)

	# Load API key from settings
	_load_settings()

func _load_settings():
	# Get the settings manager
	settings_manager = get_node("/root/SettingsManager")
	if not settings_manager:
		# Try to find it in the parent
		settings_manager = get_parent().get_node("SettingsManager")

	if settings_manager:
		# Load settings from the manager
		var settings = settings_manager.settings

		# Apply settings
		if settings.has("api_key"):
			api_key = settings.api_key
		if settings.has("model"):
			model = settings.model
			print("Gemini client loaded model: " + model)
		if settings.has("temperature"):
			temperature = settings.temperature
		if settings.has("max_output_tokens"):
			max_output_tokens = settings.max_output_tokens

		# Connect to settings changed signal
		if not settings_manager.settings_changed.is_connected(_on_settings_changed):
			settings_manager.settings_changed.connect(_on_settings_changed)
	else:
		# Fall back to direct file loading
		_load_settings_from_file()

# Fallback method for loading settings directly from file
func _load_settings_from_file():
	var settings_path = "res://addons/vector_ai/settings.json"
	var settings_file = FileAccess.open(settings_path, FileAccess.READ)

	if settings_file:
		var settings_text = settings_file.get_as_text()
		settings_file.close()

		var json = JSON.new()
		var error = json.parse(settings_text)

		if error == OK:
			var settings = json.get_data()
			if settings.has("api_key"):
				api_key = settings.api_key
			if settings.has("model"):
				model = settings.model
				print("Gemini client loaded model from file: " + model)
			if settings.has("temperature"):
				temperature = settings.temperature
			if settings.has("max_output_tokens"):
				max_output_tokens = settings.max_output_tokens
	else:
		# Create default settings file
		_save_settings_to_file()

# Handle settings changed event
func _on_settings_changed():
	if settings_manager:
		# Reload settings
		var settings = settings_manager.settings

		# Apply settings
		if settings.has("api_key"):
			api_key = settings.api_key
		if settings.has("model"):
			model = settings.model
			print("Gemini client updated model: " + model)
		if settings.has("temperature"):
			temperature = settings.temperature
		if settings.has("max_output_tokens"):
			max_output_tokens = settings.max_output_tokens

func _save_settings():
	if settings_manager:
		# Save settings using the manager
		settings_manager.set_setting("api_key", api_key)
		settings_manager.set_setting("model", model)
		settings_manager.set_setting("temperature", temperature)
		settings_manager.set_setting("max_output_tokens", max_output_tokens)

		print("Gemini client saved settings via manager. Model: " + model)
	else:
		# Fall back to direct file saving
		_save_settings_to_file()

# Fallback method for saving settings directly to file
func _save_settings_to_file():
	var settings = {
		"api_key": api_key,
		"model": model,
		"temperature": temperature,
		"max_output_tokens": max_output_tokens
	}

	var settings_path = "res://addons/vector_ai/settings.json"
	var settings_file = FileAccess.open(settings_path, FileAccess.WRITE)

	if settings_file:
		settings_file.store_string(JSON.stringify(settings, "  "))
		settings_file.close()

		print("Gemini client saved settings to file. Model: " + model)

func send_request(user_input, scene_info, callback, prompt_type = "direct_scene_edit"):
	if api_key.is_empty():
		callback(null, "API key not set. Please set it in the settings.")
		return

	# Check for game creation requests
	var game_request = _detect_game_creation_request(user_input)
	if game_request.is_game_request:
		if game_request.custom_game:
			# Handle custom game creation (no template)
			var custom_prompt = _create_custom_game_prompt(game_request.description, game_request.game_type)

			# Set up a special callback for custom game creation
			var original_callback = current_callback
			current_callback = func(response, error):
				if error:
					original_callback.call(null, error)
					return

				# Process the custom game creation response
				_process_custom_game_creation(response, original_callback, game_request)

			# Send a special request to generate a custom game
			var system_prompt = _get_system_prompt("custom_game_creation")
			var context_prompt = "Game request: " + game_request.description

			# Prepare the request body
			var contents = [
				{
					"role": "system",
					"parts": [{"text": system_prompt}]
				},
				{
					"role": "user",
					"parts": [{"text": context_prompt}]
				}
			]

			var body = {
				"contents": contents,
				"generationConfig": {
					"temperature": temperature,
					"maxOutputTokens": max_output_tokens,
					"topP": 0.95,
					"topK": 64
				}
			}

			# Convert body to JSON
			var json_body = JSON.stringify(body)

			# Prepare the request URL
			var url = "https://generativelanguage.googleapis.com/v1/models/" + model + ":generateContent?key=" + api_key

			# Send the request
			var headers = ["Content-Type: application/json"]
			var error = http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)

			if error != OK:
				callback(null, "HTTP Request Error: " + str(error))

			return
		else:
			# Handle template-based game creation
			var template_manager = get_parent().get_node("TemplateManager")
			if template_manager:
				var result = template_manager.create_game_from_template(game_request.template_name)

				if result.success:
					callback({
						"text": "I've created a " + game_request.game_type + " game for you using the " + game_request.template_name + " template. You can now modify it using Vector AI.",
						"mode": "direct_scene_edit"
					}, null)
				else:
					callback(null, "Error creating game: " + result.error)
				return

	current_callback = callback

	# Prepare the prompt based on the prompt type
	var system_prompt = _get_system_prompt(prompt_type)
	var context_prompt = _get_context_prompt(prompt_type, scene_info)

	# Prepare the request body
	var contents = [
		{
			"role": "system",
			"parts": [{"text": system_prompt}]
		},
		{
			"role": "user",
			"parts": [{"text": context_prompt}]
		},
		{
			"role": "user",
			"parts": [{"text": user_input}]
		}
	]

	var body = {
		"contents": contents,
		"generationConfig": {
			"temperature": temperature,
			"maxOutputTokens": max_output_tokens,
			"topP": 0.95,
			"topK": 64
		}
	}

	# Convert body to JSON
	var json_body = JSON.stringify(body)

	# Prepare the request URL
	var url = "https://generativelanguage.googleapis.com/v1/models/" + model + ":generateContent?key=" + api_key

	# Log the model being used
	print("Sending request using model: " + model)

	# Send the request
	var headers = ["Content-Type: application/json"]
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)

	if error != OK:
		callback(null, "HTTP Request Error: " + str(error))

# Create a custom game prompt
func _create_custom_game_prompt(description, game_type):
	return "Create a " + game_type + " game based on this description: " + description

# Process the custom game creation response
func _process_custom_game_creation(response, callback, game_request):
	if not response or not response.has("text"):
		callback.call(null, "Invalid response from API")
		return

	var response_text = response.text

	# Extract JSON commands if present
	var json_commands = _extract_json_commands(response_text)
	if not json_commands.is_empty():
		# Process JSON commands
		var json_processor = get_parent().get_node("JsonCommandProcessor")
		if json_processor:
			var result = json_processor.process_json_commands(json_commands)
			if result.success:
				callback.call({
					"text": "I've created a custom " + game_request.game_type + " game for you. You can now modify it using Vector AI.",
					"mode": "direct_scene_edit"
				}, null)
			else:
				callback.call(null, "Error creating custom game: " + result.error)
			return

	# If no JSON commands, try to extract code blocks
	var code_blocks = _extract_code_blocks(response_text)
	if code_blocks.size() > 0:
		# Process code blocks
		var code_generator = get_parent().get_node("CodeGenerator")
		if code_generator:
			var main_script_path = "res://main.gd"
			var result = code_generator.generate_script(main_script_path, code_blocks[0])
			if result.success:
				callback.call({
					"text": "I've created a custom " + game_request.game_type + " game for you. The main script has been saved to " + main_script_path + ". You can now modify it using Vector AI.",
					"mode": "code_generation"
				}, null)
			else:
				callback.call(null, "Error creating custom game script: " + result.error)
			return

	# If no code blocks or JSON commands, just return the response
	callback.call({
		"text": response_text,
		"mode": "direct_scene_edit"
	}, null)

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

# Extract code blocks from response
func _extract_code_blocks(response_text):
	var code_blocks = []
	var code_start = response_text.find("```gdscript")

	while code_start != -1:
		var code_end = response_text.find("```", code_start + 11)
		if code_end != -1:
			var code_block = response_text.substr(code_start + 11, code_end - code_start - 11).strip_edges()
			code_blocks.append(code_block)
			code_start = response_text.find("```gdscript", code_end + 3)
		else:
			break

	return code_blocks

# Get the system prompt based on the prompt type
func _get_system_prompt(prompt_type):
	match prompt_type:
		"custom_game_creation":
			return """
			You are Vector AI, an AI assistant that helps users create custom games in Godot.
			You can generate complete game implementations based on user descriptions.

			For custom game creation, you should provide:

			1. A complete main.gd script that implements the game
			2. Any additional scripts needed for game entities
			3. Scene structure recommendations

			Your response should include:

			ANALYSIS:
			[Your analysis of the game request and how you plan to implement it]

			GAME_STRUCTURE:
			[Description of the game structure, including scenes, nodes, and scripts]

			IMPLEMENTATION:
			```gdscript
			# Main game script (main.gd)
			extends Node2D

			# Game implementation here
			# Include all necessary code to make the game work
			# Use proper Godot 4.x syntax
			# Always declare variables with var or const
			# Include comments explaining the code
			```

			ADDITIONAL_SCRIPTS:
			```gdscript
			# Additional script name (e.g., player.gd)
			extends CharacterBody2D

			# Script implementation here
			```

			JSON_COMMANDS:
			```json
			[
				{
					"action": "CREATE_SCRIPT",
					"script_path": "res://main.gd",
					"code": "extends Node2D\\n\\n# Game implementation here\\n..."
				},
				{
					"action": "CREATE_SCRIPT",
					"script_path": "res://player.gd",
					"code": "extends CharacterBody2D\\n\\n# Player implementation here\\n..."
				},
				{
					"action": "ADD_NODE",
					"scene_path": "res://main.tscn",
					"parent_path": ".",
					"node_type": "Node2D",
					"node_name": "Main"
				}
			]
			```

			EXPLANATION:
			[Explanation of how the game works and how to play it]

			IMPORTANT GUIDELINES:
			1. Always use valid GDScript syntax
			2. ALWAYS declare ALL variables with 'var' or 'const' keywords
			3. Use Godot 4.x specific syntax and features
			4. Include proper error handling
			5. Add clear comments explaining complex logic
			6. Structure your code with proper indentation
			7. Make sure the game is complete and playable
			8. Include all necessary components (player, enemies, UI, etc.)
			9. Provide JSON commands for creating scripts and scenes
			10. Make sure all node paths and references are correct
			"""
		"scene_modification":
			return """
			You are Vector AI, an AI assistant that helps users modify their Godot projects based on natural language prompts.
			You have access to the current scene structure and can suggest modifications to it.

			You can respond in three ways:

			1. For simple property changes, use the following format:

			ANALYSIS:
			[Your analysis of the current scene and what needs to be changed]

			MODIFICATIONS:
			[List of specific modifications to make, including node paths, property names, and new values]
			Format: node_path: property_name = value
			Example: Player: position = (100, 200)
			Example: Camera2D: zoom = (0.5, 0.5)

			EXPLANATION:
			[Explanation of why these modifications were made and how they address the user's request]

			2. For creating new nodes, use the following format:

			ANALYSIS:
			[Your analysis of the current scene and what needs to be changed]

			MODIFICATIONS:
			[List of node creation operations]
			Format: CREATE_NODE: parent_path, node_type, node_name, {property1: value1, property2: value2}
			Example: CREATE_NODE: ., Sprite2D, Background, {texture: res://icon.png, position: (100, 100)}
			Example: CREATE_NODE: Player, CollisionShape2D, Collision, {shape: RectangleShape2D, position: (0, 0)}

			EXPLANATION:
			[Explanation of why these nodes were created and how they address the user's request]

			3. For more complex changes, use GDScript code blocks:

			ANALYSIS:
			[Your analysis of the current scene and what needs to be changed]

			CODE:
			```gdscript
			# All code will be executed inside a function, so you don't need to worry about class-level variables
			# Create a new player node
			var player = CharacterBody2D.new()
			player.name = "Player"
			current_scene.add_child(player)
			player.owner = current_scene
			player.position = Vector2(100, 100)

			# Add a sprite to the player
			var sprite = Sprite2D.new()
			sprite.name = "Sprite"
			player.add_child(sprite)
			sprite.owner = current_scene
			sprite.texture = preload("res://icon.png")
			```

			EXPLANATION:
			[Comprehensive explanation of how your code works and how it addresses the user's request]

			IMPORTANT GUIDELINES:
			1. Always use valid GDScript syntax
			2. ALWAYS declare ALL variables with 'var' or 'const' keywords before using them
			   CORRECT: var player = CharacterBody2D.new()
			   INCORRECT: player = CharacterBody2D.new()
			3. Your code will be executed inside a function, so you don't need to define functions
			4. When creating nodes with code, always set the owner to current_scene
			5. Make sure to use the correct node paths
			6. For Vector2 values, use Vector2(x, y) format, not (x, y)
			7. For colors, use Color(r, g, b) or Color.html("#hexcode") format
			8. Always check if nodes exist before modifying them
			9. Keep your code simple and focused on the user's request
			10. NEVER use bare identifiers without declaring them first with 'var'
			"""
		"direct_scene_edit":
			return """
			You are Vector AI, an AI assistant that helps users modify their Godot projects by directly editing scene files.
			You have access to the current scene structure and can suggest modifications to it.

			IMPORTANT: The system ONLY supports direct scene editing. Code execution has been completely disabled.
			All modifications must be done through the ADD_NODE, MODIFY_NODE, and REMOVE_NODE commands.

			Format your response as follows:

			ANALYSIS:
			[Your analysis of the current scene and what needs to be changed]

			SCENE_PATH:
			[Path to the scene file to modify, e.g., res://scenes/main.tscn]

			MODIFICATIONS:
			[List of modifications to make to the scene file]
			Format for adding nodes: ADD_NODE: parent_path, node_type, node_name, {property1: value1, property2: value2}
			Example: ADD_NODE: ., Sprite2D, Background, {texture: res://icon.png, position: Vector2(100, 100)}
			Example: ADD_NODE: Player, CollisionShape2D, Collision, {shape: RectangleShape2D, position: Vector2(0, 0)}

			Format for modifying nodes: MODIFY_NODE: node_path, {property1: value1, property2: value2}
			Example: MODIFY_NODE: Player, {position: Vector2(100, 200), scale: Vector2(2, 2)}
			Example: MODIFY_NODE: Camera2D, {zoom: Vector2(0.5, 0.5)}

			Format for removing nodes: REMOVE_NODE: node_path
			Example: REMOVE_NODE: Player/Sprite

			GDSCRIPT SYNTAX RULES:
			1. When writing GDScript code for nodes, ALWAYS declare ALL variables with 'var' or 'const'
			2. Class-level variables MUST be declared with 'var' or 'const'
			   CORRECT: var tile_map = TileMap.new()
			   INCORRECT: tile_map = TileMap.new()
			3. Variables can only be assigned without 'var' inside functions
			4. For Vector2 values, always use Vector2(x, y) format, not (x, y)

			EXPLANATION:
			[Explanation of why these modifications were made and how they address the user's request]

			IMPORTANT GUIDELINES:
			1. DO NOT generate GDScript code - it will not be executed
			2. Always use the ADD_NODE, MODIFY_NODE, or REMOVE_NODE commands for all modifications
			3. Always specify the scene path at the beginning of your response
			4. If no scene path is specified, the currently open scene will be used
			5. Make sure to use the correct node paths
			6. For Vector2 values, use Vector2(x, y) format, not (x, y)
			7. For colors, use Color(r, g, b) or Color.html("#hexcode") format
			8. Keep your modifications simple and focused on the user's request
			9. Parent paths should be relative to the scene root (use "." for the root node)
			10. Node paths should be the full path from the root node (e.g., "Player/Sprite")
			11. Property values should be valid GDScript literals (e.g., Vector2(100, 100), Color(1, 0, 0), true, 42)
			12. For complex shapes like triangles, use the Polygon2D node with a polygon property
			"""
		"code_generation":
			return """
			You are Vector AI, an AI assistant that helps users generate GDScript code for their Godot projects.
			You have access to the current project structure and can suggest code implementations.

			Please respond with well-structured, efficient, and commented GDScript code that follows Godot best practices.
			Make sure your code is compatible with Godot 4.x and GDScript 2.0.

			Format your response as follows:

			ANALYSIS:
			[Your analysis of the requirements and how you plan to implement them]

			CODE:
			```gdscript
			# Write your GDScript code here with proper syntax
			# Make sure ALL variables are properly declared with var or const
			```

			EXPLANATION:
			[Comprehensive explanation of how your code works and how it addresses the user's requirements]

			CRITICAL SYNTAX REQUIREMENTS:
			1. ALWAYS declare ALL variables with 'var' or 'const' keywords before using them
			   CORRECT: var player = CharacterBody2D.new()
			   INCORRECT: player = CharacterBody2D.new()
			2. Class-level variables MUST be declared with 'var' or 'const'
			   CORRECT: var tile_map = TileMap.new()
			   INCORRECT: tile_map = TileMap.new()
			3. Variables can only be assigned without 'var' inside functions
			4. Always include a class declaration (extends Node) and _ready() function
			5. Follow Godot naming conventions:
			   - snake_case for variables and functions
			   - PascalCase for classes and nodes
			   - UPPER_CASE for constants
			6. EVERY variable at class level MUST start with 'var' or 'const'
			7. NEVER use bare identifiers at class level

			IMPORTANT GUIDELINES:
			1. Include ALL necessary code, not just snippets
			2. Include proper error handling
			3. Add clear comments explaining complex logic
			4. Structure your code with proper indentation
			5. Use Godot 4.x specific syntax and features
			6. Make sure your code is complete and can be directly copied into Godot
			7. NEVER use bare identifiers without declaring them first with 'var'
			"""
		"project_analysis":
			return """
			You are Vector AI, an AI assistant that helps users analyze their Godot projects.
			You have access to the current project structure and can provide insights and suggestions.

			Please analyze the project structure and provide helpful insights, suggestions for improvements,
			and best practices that could be applied.

			Format your response as follows:

			PROJECT OVERVIEW:
			[High-level overview of the project structure and organization]

			STRENGTHS:
			[List of good practices and well-structured aspects of the project]

			IMPROVEMENT OPPORTUNITIES:
			[List of areas that could be improved, with specific suggestions]

			RECOMMENDATIONS:
			[Concrete recommendations for improving the project structure, code organization, or implementation]

			IMPORTANT GUIDELINES:
			1. Focus on Godot-specific best practices
			2. Consider project organization, code structure, and resource management
			3. Provide specific, actionable recommendations
			4. Highlight potential performance issues or bottlenecks
			5. Suggest ways to improve code reusability and maintainability
			6. Consider scalability for future development
			7. Mention any missing important directories or files
			8. Suggest appropriate design patterns for the project type
			"""
		_:
			return """
			You are Vector AI, an AI assistant that helps users with their Godot projects.
			You can provide guidance, suggestions, and code examples to help users implement their ideas.

			Please provide clear, concise, and helpful responses that address the user's specific needs.

			You can help with:
			1. Explaining Godot concepts and features
			2. Providing code examples for common tasks
			3. Suggesting approaches to game development problems
			4. Offering tips and best practices for Godot development
			5. Helping debug issues in Godot projects

			Always focus on Godot 4.x and GDScript 2.0 unless otherwise specified.
			"""

# Get the context prompt based on the prompt type
func _get_context_prompt(prompt_type, context_info):
	match prompt_type:
		"scene_modification":
			return """
			Current scene structure:
			""" + context_info
		"direct_scene_edit":
			return """
			Current scene structure:
			""" + context_info
		"code_generation":
			return """
			Current project context:
			""" + context_info
		"project_analysis":
			return """
			Current project structure:
			""" + context_info
		_:
			return context_info

func _on_request_completed(result, response_code, headers, body):
	if current_callback == null:
		return

	if result != HTTPRequest.RESULT_SUCCESS:
		current_callback(null, "HTTP Request Failed: " + str(result))
		current_callback = null
		return

	if response_code != 200:
		current_callback(null, "HTTP Error: " + str(response_code))
		current_callback = null
		return

	# Parse the response
	var json = JSON.new()
	var error = json.parse(body.get_string_from_utf8())

	if error != OK:
		current_callback(null, "JSON Parse Error: " + json.get_error_message())
		current_callback = null
		return

	var response_data = json.get_data()

	# Extract the response text
	var response_text = ""
	if response_data.has("candidates") and response_data.candidates.size() > 0:
		if response_data.candidates[0].has("content") and response_data.candidates[0].content.has("parts"):
			for part in response_data.candidates[0].content.parts:
				if part.has("text"):
					response_text += part.text

	if response_text.is_empty():
		current_callback(null, "Empty response from API")
		current_callback = null
		return

	# Parse modifications from the response
	var modifications = _parse_modifications(response_text)

	# Create the response object
	var response = {
		"text": response_text,
		"modifications": modifications
	}

	# Call the callback
	current_callback.call(response, null)
	current_callback = null

# Detect if the user is requesting a game creation
func _detect_game_creation_request(user_input):
	var result = {
		"is_game_request": false,
		"game_type": "",
		"template_name": "",
		"custom_game": false,
		"description": ""
	}

	# Convert to lowercase for easier matching
	var input_lower = user_input.to_lower()

	# Check for common game creation phrases
	var create_phrases = [
		"make me a", "create a", "build a", "generate a",
		"make a", "create me a", "build me a", "i want a",
		"can you make a", "can you create a", "can you build a"
	]

	var is_creation_request = false
	for phrase in create_phrases:
		if input_lower.find(phrase) != -1:
			is_creation_request = true
			break

	if not is_creation_request:
		return result

	# Check for game types with templates
	var game_types = {
		"maze": "maze_game",
		"parkour": "parkour_game",
		"platformer": "parkour_game",  # Map to parkour for now
		"racing": "parkour_game",      # Map to parkour for now
		"shooter": "parkour_game",     # Map to parkour for now
		"puzzle": "maze_game"          # Map to maze for now
	}

	# Check if it's a game request
	var is_game_request = false
	if input_lower.find("game") != -1:
		is_game_request = true

	# Check for specific game types
	var found_template = false
	for game_type in game_types:
		if input_lower.find(game_type) != -1:
			result.is_game_request = true
			result.game_type = game_type
			result.template_name = game_types[game_type]
			found_template = true
			break

	# If it's a game request but no template matches, mark as custom game
	if is_game_request and not found_template:
		result.is_game_request = true
		result.custom_game = true
		result.description = user_input

		# Try to extract the game type from the request
		for phrase in create_phrases:
			if input_lower.find(phrase) != -1:
				var start_idx = input_lower.find(phrase) + phrase.length()
				var end_idx = input_lower.find("game", start_idx)
				if end_idx != -1:
					var game_type = input_lower.substr(start_idx, end_idx - start_idx).strip_edges()
					if not game_type.is_empty():
						result.game_type = game_type
						break

		# If we couldn't extract a specific type, use "custom"
		if result.game_type.is_empty():
			result.game_type = "custom"

	return result

func _parse_modifications(response_text):
	var modifications = []

	# Look for the MODIFICATIONS section
	var modifications_start = response_text.find("MODIFICATIONS:")
	var modifications_end = response_text.find("EXPLANATION:")

	if modifications_start != -1 and modifications_end != -1:
		var modifications_text = response_text.substr(modifications_start + 14, modifications_end - modifications_start - 14).strip_edges()
		var lines = modifications_text.split("\n")

		for line in lines:
			line = line.strip_edges()
			if line.is_empty() or line.begins_with("-") or line.begins_with("*"):
				continue

			# Check for CREATE_NODE format
			if line.begins_with("CREATE_NODE:"):
				var create_info = line.substr(12).strip_edges()
				var create_parts = create_info.split(",")

				if create_parts.size() >= 3:
					var parent_path = create_parts[0].strip_edges()
					var node_type = create_parts[1].strip_edges()
					var node_name = create_parts[2].strip_edges()

					var properties = {}
					if create_parts.size() >= 4:
						# Parse properties dictionary
						var props_str = create_parts[3].strip_edges()
						if props_str.begins_with("{") and props_str.ends_with("}"):
							props_str = props_str.substr(1, props_str.length() - 2)
							var prop_pairs = props_str.split(",")

							for prop_pair in prop_pairs:
								var key_value = prop_pair.split(":")
								if key_value.size() >= 2:
									var key = key_value[0].strip_edges()
									var value = key_value[1].strip_edges()
									properties[key] = value

					modifications.append({
						"type": "create_node",
						"parent_path": parent_path,
						"node_type": node_type,
						"node_name": node_name,
						"properties": properties
					})
			# Check for DELETE_NODE format
			elif line.begins_with("DELETE_NODE:"):
				var node_path = line.substr(12).strip_edges()

				modifications.append({
					"type": "delete_node",
					"node_path": node_path
				})
			# Check for REPARENT_NODE format
			elif line.begins_with("REPARENT_NODE:"):
				var reparent_info = line.substr(14).strip_edges()
				var reparent_parts = reparent_info.split(",")

				if reparent_parts.size() >= 2:
					var node_path = reparent_parts[0].strip_edges()
					var new_parent_path = reparent_parts[1].strip_edges()

					modifications.append({
						"type": "reparent_node",
						"node_path": node_path,
						"new_parent_path": new_parent_path
					})
			# Standard property modification
			else:
				var parts = line.split(":")
				if parts.size() >= 2:
					var node_path = parts[0].strip_edges()
					var property_value = parts[1].strip_edges()

					# Check if this is a valid property assignment
					if property_value.find("=") != -1:
						modifications.append({
							"type": "property",
							"node_path": node_path,
							"property_value": property_value
						})
					else:
						# This might be a bullet point or other text, skip it
						continue

	# Look for CODE section and extract code blocks
	var code_blocks = []
	var code_start = response_text.find("CODE:")

	if code_start != -1:
		# Use the code_executor to extract code blocks
		var code_executor = get_parent().get_node("CodeExecutor")
		if code_executor:
			code_blocks = code_executor.extract_code_from_response(response_text)

			# Also try to extract modifications from the code
			var code_modifications = code_executor.parse_modifications_from_code(response_text)
			modifications.append_array(code_modifications)

	return modifications
