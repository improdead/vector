@tool
extends Node

# Default settings
var default_settings = {
	"api_key": "",
	"model": "gemini-2.5-flash-preview-04-17",  # Using Gemini 2.5 Flash Preview model (not 1.5 Pro)
	"temperature": 0.7,
	"max_output_tokens": 2048,
	"dev_mode": true,
	"proxy_url": ""
}

# Current settings
var settings = {}

# Settings file path
var settings_path = "res://addons/vector_ai/settings.json"

# Signal emitted when settings are changed
signal settings_changed

func _ready():
	# Load settings
	load_settings()

# Load settings from file
func load_settings():
	print("Loading settings from: " + settings_path)
	
	# Start with default settings
	settings = default_settings.duplicate()
	
	# Try to load from file
	var settings_file = FileAccess.open(settings_path, FileAccess.READ)
	
	if settings_file:
		var settings_text = settings_file.get_as_text()
		settings_file.close()
		
		var json = JSON.new()
		var error = json.parse(settings_text)
		
		if error == OK:
			var loaded_settings = json.get_data()
			
			# Update settings with loaded values
			for key in loaded_settings:
				if key != "model":  # Don't load the model from file
					settings[key] = loaded_settings[key]
			
			# Always force the model to Gemini 2.5 Flash
			settings.model = "gemini-2.5-flash-preview-04-17"
			
			print("Settings loaded successfully. Model: " + settings.model)
		else:
			push_error("Error parsing settings JSON: " + json.get_error_message())
	else:
		push_warning("Settings file not found. Using default settings.")
		save_settings()  # Create default settings file
	
	# Emit signal
	settings_changed.emit()
	
	return settings

# Save settings to file
func save_settings():
	var settings_file = FileAccess.open(settings_path, FileAccess.WRITE)
	
	if settings_file:
		settings_file.store_string(JSON.stringify(settings, "  "))
		settings_file.close()
		print("Settings saved successfully. Model: " + settings.model)
	else:
		push_error("Failed to save settings to: " + settings_path)

# Get a setting value
func get_setting(key, default_value = null):
	if settings.has(key):
		return settings[key]
	return default_value

# Set a setting value
func set_setting(key, value):
	# Always ensure model is Gemini 2.5 Flash
	if key == "model":
		settings[key] = "gemini-2.5-flash-preview-04-17"
		print("Attempted to change model, but it's locked to Gemini 2.5 Flash")
	else:
		settings[key] = value
	
	save_settings()
	settings_changed.emit()

# Reset settings to default
func reset_to_default():
	settings = default_settings.duplicate()
	save_settings()
	settings_changed.emit()
	print("Settings reset to default. Model: " + settings.model)

# Force the model to Gemini 2.5 Flash
func force_gemini_25_flash():
	settings.model = "gemini-2.5-flash-preview-04-17"
	save_settings()
	settings_changed.emit()
	print("Model forced to Gemini 2.5 Flash: " + settings.model)
