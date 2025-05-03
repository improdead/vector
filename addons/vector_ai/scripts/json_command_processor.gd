@tool
extends Node

# Reference to other components
var editor_interface
var scene_file_modifier
var tscn_parser
var code_generator

# Validation tools
var gdtoolkit_validator

func _ready():
	# Get the editor interface
	editor_interface = Engine.get_singleton("EditorInterface")
	
	# Get references to other components
	scene_file_modifier = get_parent().get_node("SceneFileModifier")
	tscn_parser = get_parent().get_node("TscnParser")
	code_generator = get_parent().get_node("CodeGenerator")
	
	# Initialize GDToolkit validator if available
	_initialize_gdtoolkit()

# Process JSON commands from the AI
func process_json_commands(json_string):
	var result = {
		"success": false,
		"error": "",
		"results": []
	}
	
	# Parse the JSON string
	var json = JSON.new()
	var error = json.parse(json_string)
	
	if error != OK:
		result.error = "JSON Parse Error: " + json.get_error_message() + " at line " + str(json.get_error_line())
		return result
	
	var commands = json.get_data()
	
	# Handle both single command and array of commands
	if not commands is Array:
		commands = [commands]
	
	# Process each command
	for command in commands:
		var command_result = _process_command(command)
		result.results.append(command_result)
		
		if not command_result.success:
			result.error = "Error processing command: " + command_result.error
			result.success = false
			return result
	
	result.success = true
	return result

# Process a single command
func _process_command(command):
	var result = {
		"success": false,
		"error": "",
		"message": ""
	}
	
	# Validate command structure
	if not command is Dictionary:
		result.error = "Command must be a dictionary"
		return result
	
	if not command.has("action"):
		result.error = "Command must have an 'action' field"
		return result
	
	# Process based on action type
	match command.action:
		"ADD_NODE":
			result = _add_node(command)
		"MODIFY_NODE":
			result = _modify_node(command)
		"REMOVE_NODE":
			result = _remove_node(command)
		"CREATE_SCRIPT":
			result = _create_script(command)
		"MODIFY_SCRIPT":
			result = _modify_script(command)
		"CREATE_SCENE":
			result = _create_scene(command)
		"CREATE_RESOURCE":
			result = _create_resource(command)
		_:
			result.error = "Unknown action: " + command.action
	
	return result

# Add a node to a scene
func _add_node(command):
	var result = {
		"success": false,
		"error": "",
		"message": ""
	}
	
	# Validate required fields
	if not _validate_fields(command, ["scene_path", "parent_path", "node_type", "node_name"], result):
		return result
	
	# Validate node type
	if not ClassDB.class_exists(command.node_type):
		result.error = "Invalid node type: " + command.node_type
		return result
	
	# Get properties if provided
	var properties = {}
	if command.has("properties") and command.properties is Dictionary:
		properties = command.properties
	
	# Create the modification object
	var modification = {
		"type": "add_node",
		"parent_path": command.parent_path,
		"node_type": command.node_type,
		"node_name": command.node_name,
		"properties": properties
	}
	
	# Apply the modification
	var mod_result = scene_file_modifier.modify_scene_file(command.scene_path, [modification])
	
	if mod_result.success:
		result.success = true
		result.message = "Added node '" + command.node_name + "' of type '" + command.node_type + "' to '" + command.scene_path + "'"
	else:
		result.error = mod_result.error
	
	return result

# Modify a node in a scene
func _modify_node(command):
	var result = {
		"success": false,
		"error": "",
		"message": ""
	}
	
	# Validate required fields
	if not _validate_fields(command, ["scene_path", "node_path", "properties"], result):
		return result
	
	# Validate properties
	if not command.properties is Dictionary:
		result.error = "Properties must be a dictionary"
		return result
	
	# Create the modification object
	var modification = {
		"type": "modify_node",
		"node_path": command.node_path,
		"properties": command.properties
	}
	
	# Apply the modification
	var mod_result = scene_file_modifier.modify_scene_file(command.scene_path, [modification])
	
	if mod_result.success:
		result.success = true
		result.message = "Modified node '" + command.node_path + "' in '" + command.scene_path + "'"
	else:
		result.error = mod_result.error
	
	return result

# Remove a node from a scene
func _remove_node(command):
	var result = {
		"success": false,
		"error": "",
		"message": ""
	}
	
	# Validate required fields
	if not _validate_fields(command, ["scene_path", "node_path"], result):
		return result
	
	# Create the modification object
	var modification = {
		"type": "remove_node",
		"node_path": command.node_path
	}
	
	# Apply the modification
	var mod_result = scene_file_modifier.modify_scene_file(command.scene_path, [modification])
	
	if mod_result.success:
		result.success = true
		result.message = "Removed node '" + command.node_path + "' from '" + command.scene_path + "'"
	else:
		result.error = mod_result.error
	
	return result

# Create a new script file
func _create_script(command):
	var result = {
		"success": false,
		"error": "",
		"message": ""
	}
	
	# Validate required fields
	if not _validate_fields(command, ["script_path", "code"], result):
		return result
	
	# Validate script path
	if not command.script_path.begins_with("res://"):
		result.error = "Script path must start with 'res://'"
		return result
	
	# Validate code
	var validated_code = _validate_gdscript(command.code)
	if validated_code.has("error"):
		result.error = "GDScript validation error: " + validated_code.error
		return result
	
	# Create the script file
	var file = FileAccess.open(command.script_path, FileAccess.WRITE)
	if not file:
		result.error = "Failed to create script file: " + command.script_path
		return result
	
	file.store_string(validated_code.code)
	file.close()
	
	# Reload the script in the editor
	editor_interface.get_resource_filesystem().scan()
	
	result.success = true
	result.message = "Created script file: " + command.script_path
	return result

# Modify an existing script file
func _modify_script(command):
	var result = {
		"success": false,
		"error": "",
		"message": ""
	}
	
	# Validate required fields
	if not _validate_fields(command, ["script_path", "code"], result):
		return result
	
	# Validate script path
	if not command.script_path.begins_with("res://"):
		result.error = "Script path must start with 'res://'"
		return result
	
	# Check if the script exists
	if not FileAccess.file_exists(command.script_path):
		result.error = "Script file does not exist: " + command.script_path
		return result
	
	# Validate code
	var validated_code = _validate_gdscript(command.code)
	if validated_code.has("error"):
		result.error = "GDScript validation error: " + validated_code.error
		return result
	
	# Modify the script file
	var file = FileAccess.open(command.script_path, FileAccess.WRITE)
	if not file:
		result.error = "Failed to open script file: " + command.script_path
		return result
	
	file.store_string(validated_code.code)
	file.close()
	
	# Reload the script in the editor
	editor_interface.get_resource_filesystem().scan()
	
	result.success = true
	result.message = "Modified script file: " + command.script_path
	return result

# Create a new scene file
func _create_scene(command):
	var result = {
		"success": false,
		"error": "",
		"message": ""
	}
	
	# Validate required fields
	if not _validate_fields(command, ["scene_path", "root_node_type"], result):
		return result
	
	# Validate scene path
	if not command.scene_path.begins_with("res://"):
		result.error = "Scene path must start with 'res://'"
		return result
	
	# Validate node type
	if not ClassDB.class_exists(command.root_node_type):
		result.error = "Invalid node type: " + command.root_node_type
		return result
	
	# Get root node name
	var root_node_name = "Root"
	if command.has("root_node_name"):
		root_node_name = command.root_node_name
	
	# Create a basic scene
	var scene_content = """[gd_scene format=3]

[node name="%s" type="%s"]
"""
	scene_content = scene_content % [root_node_name, command.root_node_type]
	
	# Create the scene file
	var file = FileAccess.open(command.scene_path, FileAccess.WRITE)
	if not file:
		result.error = "Failed to create scene file: " + command.scene_path
		return result
	
	file.store_string(scene_content)
	file.close()
	
	# Reload the scene in the editor
	editor_interface.get_resource_filesystem().scan()
	
	result.success = true
	result.message = "Created scene file: " + command.scene_path
	return result

# Create a new resource file
func _create_resource(command):
	var result = {
		"success": false,
		"error": "",
		"message": ""
	}
	
	# Validate required fields
	if not _validate_fields(command, ["resource_path", "resource_type"], result):
		return result
	
	# Validate resource path
	if not command.resource_path.begins_with("res://"):
		result.error = "Resource path must start with 'res://'"
		return result
	
	# Create the resource
	var resource
	
	match command.resource_type:
		"Texture":
			# For textures, we need an image
			if not command.has("image_data"):
				result.error = "Image data required for texture resource"
				return result
			
			# Create an image from base64 data
			var image = Image.new()
			var image_data = Marshalls.base64_to_raw(command.image_data)
			var error = image.load_png_from_buffer(image_data)
			
			if error != OK:
				result.error = "Failed to load image data"
				return result
			
			resource = ImageTexture.create_from_image(image)
		
		"AudioStream":
			# For audio streams, we need audio data
			if not command.has("audio_data"):
				result.error = "Audio data required for audio stream resource"
				return result
			
			# Create an audio stream from base64 data
			var audio_data = Marshalls.base64_to_raw(command.audio_data)
			var file = FileAccess.open(command.resource_path, FileAccess.WRITE)
			
			if not file:
				result.error = "Failed to create audio file"
				return result
			
			file.store_buffer(audio_data)
			file.close()
			
			# Let the editor handle the import
			editor_interface.get_resource_filesystem().scan()
			
			result.success = true
			result.message = "Created audio file: " + command.resource_path
			return result
		
		_:
			result.error = "Unsupported resource type: " + command.resource_type
			return result
	
	# Save the resource
	var save_error = ResourceSaver.save(resource, command.resource_path)
	
	if save_error != OK:
		result.error = "Failed to save resource: " + str(save_error)
		return result
	
	# Reload the resource in the editor
	editor_interface.get_resource_filesystem().scan()
	
	result.success = true
	result.message = "Created resource file: " + command.resource_path
	return result

# Validate required fields in a command
func _validate_fields(command, required_fields, result):
	for field in required_fields:
		if not command.has(field):
			result.error = "Missing required field: " + field
			return false
	return true

# Initialize GDToolkit for syntax validation
func _initialize_gdtoolkit():
	# Check if gdtoolkit is installed
	var gdtoolkit_installer = get_parent().get_node("GdtoolkitInstaller")
	if gdtoolkit_installer:
		gdtoolkit_installer.ensure_installed()

# Validate GDScript code
func _validate_gdscript(code):
	var result = {
		"success": true,
		"code": code
	}
	
	# Basic validation
	if code.is_empty():
		result.error = "Code cannot be empty"
		result.success = false
		return result
	
	# Check for security issues
	var blacklisted_keywords = [
		"OS.execute",
		"OS.shell_open",
		"Directory.remove",
		"DirAccess.remove",
		"FileAccess.open",
		"load_resource",
		"ResourceLoader.load",
		"ProjectSettings",
		"get_tree().quit",
		"Engine.get_singleton"
	]
	
	for keyword in blacklisted_keywords:
		if code.find(keyword) != -1:
			result.error = "Security violation: Use of restricted keyword '" + keyword + "' is not allowed."
			result.success = false
			return result
	
	# Check for variable declarations
	var lines = code.split("\n")
	var processed_lines = []
	var in_function = false
	var in_class = false
	
	for i in range(lines.size()):
		var line = lines[i].strip_edges()
		
		# Skip empty lines and comments
		if line.is_empty() or line.begins_with("#"):
			processed_lines.append(lines[i])
			continue
		
		# Check if we're entering a function
		if line.begins_with("func "):
			in_function = true
		
		# Check if we're entering a class
		if line.begins_with("class "):
			in_class = true
		
		# Check if we're exiting a function or class
		if in_function and line == "}":
			in_function = false
		
		if in_class and line == "}":
			in_class = false
		
		# Check for variable assignments without var/const
		if not in_function and not in_class and "=" in line and not line.begins_with("var ") and not line.begins_with("const ") and not line.begins_with("@"):
			# This is a bare assignment outside a function, add var
			processed_lines.append("var " + lines[i])
		else:
			processed_lines.append(lines[i])
	
	result.code = "\n".join(processed_lines)
	return result
