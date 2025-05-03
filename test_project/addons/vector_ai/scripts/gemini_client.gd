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
		print("ERROR: API key is not set")
		callback_func.call(null, "API key is not set. Please set it in the settings.")
		return

	print("API key is set: " + api_key.substr(0, 5) + "...")

	if current_callback != null:
		print("ERROR: A request is already in progress")
		callback_func.call(null, "A request is already in progress. Please wait.")
		return

	current_callback = callback_func

	# Prepare the request URL
	var request_url = api_url + model + ":generateContent?key=" + api_key
	print("Request URL: " + request_url.replace(api_key, "API_KEY_HIDDEN"))

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

	# Set the headers
	var headers = ["Content-Type: application/json"]

	# Send the request
	print("Sending HTTP request...")
	var error = http_request.request(request_url, headers, HTTPClient.METHOD_POST, json_body)
	if error != OK:
		print("ERROR: HTTP Request Error: " + str(error))
		current_callback.call(null, "HTTP Request Error: " + str(error))
		current_callback = null
	else:
		print("HTTP request sent successfully")

# Handle the HTTP request completion
func _on_request_completed(result, response_code, headers, body):
	print("HTTP request completed with result: " + str(result) + ", response code: " + str(response_code))

	if current_callback == null:
		print("WARNING: No callback function found")
		return

	if result != HTTPRequest.RESULT_SUCCESS:
		print("ERROR: HTTP Request Failed: " + str(result))
		current_callback.call(null, "HTTP Request Failed: " + str(result))
		current_callback = null
		return

	if response_code != 200:
		print("ERROR: HTTP Error: " + str(response_code))
		current_callback.call(null, "HTTP Error: " + str(response_code))
		current_callback = null
		return

	print("Response body length: " + str(body.size()))

	# Parse the response
	var json = JSON.new()
	var error = json.parse(body.get_string_from_utf8())

	if error != OK:
		print("ERROR: JSON Parse Error: " + json.get_error_message())
		current_callback.call(null, "JSON Parse Error: " + json.get_error_message())
		current_callback = null
		return

	print("JSON parsed successfully")
	var response_data = json.get_data()

	# Extract the response text
	var response_text = ""
	if response_data.has("candidates") and response_data.candidates.size() > 0:
		print("Found " + str(response_data.candidates.size()) + " candidates")
		if response_data.candidates[0].has("content") and response_data.candidates[0].content.has("parts"):
			print("Found content with parts")
			for part in response_data.candidates[0].content.parts:
				if part.has("text"):
					response_text += part.text
	else:
		print("WARNING: No candidates found in response")
		print("Response data: " + JSON.stringify(response_data))

	if response_text.is_empty():
		print("ERROR: Empty response text")
		current_callback.call(null, "Empty response from API")
		current_callback = null
		return

	print("Response text length: " + str(response_text.length()))

	# Create the response object
	var response = {
		"text": response_text
	}

	# Call the callback
	print("Calling callback function with response")
	current_callback.call(response, null)
	current_callback = null
