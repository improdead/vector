@tool
extends Node

# Gemini API Client
# Handles communication with the Gemini API

var api_key = ""
var model = "gemini-2.5-flash-preview-04-17"
var api_url = "https://generativelanguage.googleapis.com/v1beta/models/"
var current_callback = null

# HTTP request node
var http_request

func _ready():
	# Create HTTP request node
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)

# Send a request to the Gemini API
func send_request(prompt, callback_func):
	print("Sending request to Gemini API...")

	if api_key.is_empty():
		print("API key is not set")
		callback_func.call(null, "API key is not set. Please set it in the settings.")
		return

	current_callback = callback_func

	# Prepare the request URL
	var request_url = api_url + model + ":generateContent?key=" + api_key
	print("Using model: " + model)
	print("Request URL: " + request_url)

	# Prepare the request body
	var body = {
		"contents": [
			{
				"role": "user",
				"parts": [
					{
						"text": prompt
					}
				]
			}
		],
		"generationConfig": {
			"temperature": 0.7,
			"topK": 40,
			"topP": 0.95,
			"maxOutputTokens": 8192
		}
	}

	# Convert the body to JSON
	var json_body = JSON.stringify(body)
	print("Request body length: " + str(json_body.length()))
	print("Request prompt length: " + str(prompt.length()))

	# Truncate prompt if it's too long (Gemini has input token limits)
	if prompt.length() > 30000:  # Approximate token limit
		print("WARNING: Prompt is very long, truncating to 30000 characters")
		var truncated_prompt = prompt.substr(0, 30000)
		body.contents[0].parts[0].text = truncated_prompt
		json_body = JSON.stringify(body)

	# Set the headers
	var headers = ["Content-Type: application/json"]

	# Print request details for debugging
	print("Sending request with headers: " + str(headers))

	# Send the request
	print("Sending HTTP request...")
	var error = http_request.request(request_url, headers, HTTPClient.METHOD_POST, json_body)
	if error != OK:
		print("HTTP Request Error: " + str(error))
		current_callback.call(null, "HTTP Request Error: " + str(error))
		current_callback = null

# Handle the HTTP request completion
func _on_request_completed(result, response_code, headers, body):
	if current_callback == null:
		return

	if result != HTTPRequest.RESULT_SUCCESS:
		print("HTTP Request Failed: " + str(result))
		current_callback.call(null, "HTTP Request Failed: " + str(result))
		current_callback = null
		return

	if response_code != 200:
		print("HTTP Error: " + str(response_code))
		# Print the response body for debugging
		print("Response body: " + body.get_string_from_utf8())
		current_callback.call(null, "HTTP Error: " + str(response_code))
		current_callback = null
		return

	# Parse the response
	var json = JSON.new()
	var response_string = body.get_string_from_utf8()
	print("Raw response length: " + str(response_string.length()))

	if response_string.is_empty():
		print("Empty response body received from API")
		current_callback.call(null, "Empty response body received from API")
		current_callback = null
		return

	var error = json.parse(response_string)

	if error != OK:
		print("JSON Parse Error: " + json.get_error_message() + " at line " + str(json.get_error_line()))
		print("Response snippet: " + response_string.substr(0, min(100, response_string.length())))
		current_callback.call(null, "JSON Parse Error: " + json.get_error_message())
		current_callback = null
		return

	var response_data = json.get_data()
	print("Response data structure: " + str(response_data.keys()))

	# Extract the response text
	var response_text = ""
	if response_data.has("candidates") and response_data.candidates.size() > 0:
		print("Found candidates: " + str(response_data.candidates.size()))
		if response_data.candidates[0].has("content") and response_data.candidates[0].content.has("parts"):
			print("Found content parts: " + str(response_data.candidates[0].content.parts.size()))
			for part in response_data.candidates[0].content.parts:
				if part.has("text"):
					response_text += part.text
	elif response_data.has("error"):
		# Handle API error response
		print("API returned an error: " + str(response_data.error))
		if response_data.error.has("message"):
			current_callback.call(null, "API Error: " + response_data.error.message)
		else:
			current_callback.call(null, "API Error: " + str(response_data.error))
		current_callback = null
		return

	if response_text.is_empty():
		print("Empty response text extracted from API response")
		print("Full response data: " + str(response_data))

		# Try to generate a fallback response for debugging
		var fallback_response = "extends Node2D\n\nfunc _ready():\n\tprint(\"Fallback response - API returned empty content\")\n\t# Create a label to show this is a fallback response\n\tvar label = Label.new()\n\tlabel.text = \"Vector AI - API returned empty content. Please try again.\"\n\tlabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER\n\tlabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER\n\tlabel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)\n\n\tvar canvas_layer = CanvasLayer.new()\n\tcanvas_layer.add_child(label)\n\tadd_child(canvas_layer)"

		# Decide whether to use fallback or return error
		var use_fallback = false  # Set to true to use fallback code instead of error

		if use_fallback:
			print("Using fallback response code")
			var response = {
				"text": "ANALYSIS:\nAPI returned an empty response. Using fallback code.\n\nIMPLEMENTATION:\n```gdscript\n" + fallback_response + "\n```\n\nEXPLANATION:\nThis is a fallback response because the API returned empty content."
			}
			current_callback.call(response, null)
		else:
			current_callback.call(null, "Empty response from API")

		current_callback = null
		return

	# Create the response object
	var response = {
		"text": response_text
	}

	print("Successfully extracted response text, length: " + str(response_text.length()))

	# Call the callback
	current_callback.call(response, null)
	current_callback = null
