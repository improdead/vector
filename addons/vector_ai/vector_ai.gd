@tool
extends EditorPlugin

# Vector AI Plugin
# A simple AI-powered code generation plugin for Godot

var dock
var settings = {
	"api_key": "",
	"model": "gemini-2.5-flash-preview-04-17"
}
var settings_path = "res://addons/vector_ai/settings.json"

func _enter_tree():
	# Initialize the plugin
	print("Vector AI Plugin initialized")

	# Load settings
	load_settings()

	# Create the main dock
	dock = preload("res://addons/vector_ai/scenes/main_dock.tscn").instantiate()
	dock.plugin = self
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)

func _exit_tree():
	# Clean up the plugin
	remove_control_from_docks(dock)
	dock.queue_free()

# Load settings from file
func load_settings():
	if FileAccess.file_exists(settings_path):
		var file = FileAccess.open(settings_path, FileAccess.READ)
		var json_string = file.get_as_text()
		file.close()

		var json = JSON.new()
		var error = json.parse(json_string)
		if error == OK:
			var data = json.get_data()
			if data is Dictionary:
				if data.has("api_key"):
					settings.api_key = data.api_key
				if data.has("model"):
					settings.model = data.model

		print("Settings loaded successfully. Model: " + settings.model)
	else:
		# Create default settings file
		save_settings()

	# Force model to Gemini 2.5 Flash
	# settings.model = "gemini-2.5-flash-preview-04-17"
	# print("Model forced to Gemini 2.5 Flash: " + settings.model)
	# save_settings()

# Save settings to file
func save_settings():
	var dir = DirAccess.open("res://addons/vector_ai")
	if not dir:
		DirAccess.make_dir_recursive_absolute("res://addons/vector_ai")

	var file = FileAccess.open(settings_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(settings, "  "))
	file.close()

	print("Settings saved successfully. Model: " + settings.model)

# Get the current editor scene
func get_current_scene():
	var editor_interface = get_editor_interface()
	if editor_interface:
		var edited_scene_root = editor_interface.get_edited_scene_root()
		if edited_scene_root:
			return edited_scene_root
	return null

# Get the path to the current scene
func get_current_scene_path():
	var editor_interface = get_editor_interface()
	if editor_interface:
		var edited_scene_root = editor_interface.get_edited_scene_root()
		if edited_scene_root:
			return edited_scene_root.scene_file_path
	return "res://main.tscn"  # Default to main.tscn if no scene is open
