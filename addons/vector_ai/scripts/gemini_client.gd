@tool
extends Node

# Gemini API configuration
var api_key = ""
var model = "gemini-2.5-flash-preview-04-17"
var temperature = 0.7
var max_output_tokens = 2048

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
			if settings.has("temperature"):
				temperature = settings.temperature
			if settings.has("max_output_tokens"):
				max_output_tokens = settings.max_output_tokens
	else:
		# Create default settings file
		_save_settings()

func _save_settings():
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

func send_request(user_input, scene_info, callback):
	if api_key.is_empty():
		callback(null, "API key not set. Please set it in the settings.")
		return

	current_callback = callback

	# Prepare the prompt
	var system_prompt = """
	You are Vector AI, an AI assistant that helps users modify their Godot scenes based on natural language prompts.
	You have access to the current scene structure and can suggest modifications to it.

	You can respond in two ways:

	1. For simple property changes, use the following format:

	ANALYSIS:
	[Your analysis of the current scene and what needs to be changed]

	MODIFICATIONS:
	[List of specific modifications to make, including node paths, property names, and new values]

	EXPLANATION:
	[Explanation of why these modifications were made and how they address the user's request]

	2. For more complex changes like creating new nodes, use GDScript code blocks:

	ANALYSIS:
	[Your analysis of the current scene and what needs to be changed]

	CODE:
	```gdscript
	# Write executable GDScript code here that will modify the scene
	# You have access to the current_scene variable which is the root of the scene
	# Example:
	# var player = CharacterBody2D.new()
	# player.name = "Player"
	# current_scene.add_child(player)
	# player.owner = current_scene
	```

	EXPLANATION:
	[Comprehensive explanation of how your code works and how it addresses the user's request]
	"""

	var scene_prompt = """
	Current scene structure:
	""" + scene_info

	# Prepare the request body
	var contents = [
		{
			"role": "system",
			"parts": [{"text": system_prompt}]
		},
		{
			"role": "user",
			"parts": [{"text": scene_prompt}]
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

	# Send the request
	var headers = ["Content-Type: application/json"]
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)

	if error != OK:
		callback(null, "HTTP Request Error: " + str(error))

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

			# Parse the modification
			var parts = line.split(":")
			if parts.size() >= 2:
				var node_path = parts[0].strip_edges()
				var property_value = parts[1].strip_edges()

				modifications.append({
					"node_path": node_path,
					"property_value": property_value
				})

	return modifications
