@tool
extends Node

# Direct JSON Command Processor
# This script processes JSON commands using direct file access

# Reference to the direct file editor
var file_editor

func _ready():
	print("Direct JSON Processor initialized")
	
	# Get reference to the direct file editor
	file_editor = get_parent().get_node("DirectFileEditor")
	if not file_editor:
		push_error("Vector AI: DirectFileEditor not found!")

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
		"ADD_NODE", "MODIFY_NODE", "REMOVE_NODE":
			result = _process_scene_command(command)
		"CREATE_SCRIPT":
			result = _create_script(command)
		"MODIFY_SCRIPT":
			result = _modify_script(command)
		"CREATE_SCENE":
			result = _create_scene(command)
		"EDIT_SCENE":
			result = _edit_scene(command)
		"CREATE_GAME":
			result = _create_game(command)
		_:
			result.error = "Unknown action: " + command.action

	return result

# Process scene-related commands (ADD_NODE, MODIFY_NODE, REMOVE_NODE)
func _process_scene_command(command):
	var result = {
		"success": false,
		"error": "",
		"message": ""
	}
	
	# Validate required fields
	if not command.has("scene_path"):
		result.error = "Missing required field: scene_path"
		return result
	
	# Read the current scene file
	var read_result = file_editor.read_file(command.scene_path)
	if not read_result.success:
		# If the scene doesn't exist, create a new one
		if command.action == "ADD_NODE":
			return _create_scene_with_node(command)
		else:
			result.error = read_result.message
			return result
	
	var scene_content = read_result.content
	
	# Process the command based on the action
	match command.action:
		"ADD_NODE":
			if not _validate_fields(command, ["parent_path", "node_type", "node_name"], result):
				return result
			
			# Simple implementation: just append a new node to the scene
			# In a real implementation, you would parse the scene file and insert the node at the right place
			var node_content = "\n\n[node name=\"%s\" type=\"%s\" parent=\"%s\"]" % [command.node_name, command.node_type, command.parent_path]
			
			# Add properties if provided
			if command.has("properties") and command.properties is Dictionary:
				for property in command.properties:
					node_content += "\n%s = %s" % [property, _format_property_value(command.properties[property])]
			
			scene_content += node_content
			
			# Write the modified scene back to the file
			var write_result = file_editor.edit_file(command.scene_path, scene_content)
			if not write_result.success:
				result.error = write_result.message
				return result
			
			result.success = true
			result.message = "Added node '%s' to scene '%s'" % [command.node_name, command.scene_path]
		
		"MODIFY_NODE":
			if not _validate_fields(command, ["node_path", "properties"], result):
				return result
			
			# This is a simplified implementation
			# In a real implementation, you would parse the scene file and modify the node properties
			result.success = true
			result.message = "Modified node '%s' in scene '%s' (simplified implementation)" % [command.node_path, command.scene_path]
		
		"REMOVE_NODE":
			if not _validate_fields(command, ["node_path"], result):
				return result
			
			# This is a simplified implementation
			# In a real implementation, you would parse the scene file and remove the node
			result.success = true
			result.message = "Removed node '%s' from scene '%s' (simplified implementation)" % [command.node_path, command.scene_path]
	
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
	if not validated_code.success:
		result.error = "GDScript validation error: " + validated_code.error
		return result

	# Create the script file
	var create_result = file_editor.create_script(command.script_path, validated_code.code)
	if not create_result.success:
		result.error = create_result.message
		return result

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

	# Validate code
	var validated_code = _validate_gdscript(command.code)
	if not validated_code.success:
		result.error = "GDScript validation error: " + validated_code.error
		return result

	# Modify the script file
	var edit_result = file_editor.edit_script(command.script_path, validated_code.code)
	if not edit_result.success:
		result.error = edit_result.message
		return result

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
	if not _validate_fields(command, ["scene_path", "content"], result):
		return result

	# Validate scene path
	if not command.scene_path.begins_with("res://"):
		result.error = "Scene path must start with 'res://'"
		return result

	# Create the scene file
	var create_result = file_editor.create_scene(command.scene_path, command.content)
	if not create_result.success:
		result.error = create_result.message
		return result

	result.success = true
	result.message = "Created scene file: " + command.scene_path
	return result

# Edit an existing scene file
func _edit_scene(command):
	var result = {
		"success": false,
		"error": "",
		"message": ""
	}

	# Validate required fields
	if not _validate_fields(command, ["scene_path", "content"], result):
		return result

	# Validate scene path
	if not command.scene_path.begins_with("res://"):
		result.error = "Scene path must start with 'res://'"
		return result

	# Edit the scene file
	var edit_result = file_editor.edit_scene(command.scene_path, command.content)
	if not edit_result.success:
		result.error = edit_result.message
		return result

	result.success = true
	result.message = "Edited scene file: " + command.scene_path
	return result

# Create a complete game
func _create_game(command):
	var result = {
		"success": false,
		"error": "",
		"message": ""
	}

	# Validate required fields
	if not _validate_fields(command, ["game_type"], result):
		return result

	# Get the game generator
	var game_generator = get_parent().get_node("DirectGameGenerator")
	if not game_generator:
		result.error = "DirectGameGenerator not found!"
		return result

	# Create the game based on the type
	var game_result
	match command.game_type:
		"maze":
			game_result = game_generator.create_maze_game()
		"platformer":
			game_result = game_generator.create_platformer_game()
		_:
			# Try to create a game from description
			game_result = game_generator.create_game_from_description(command.game_type)

	if not game_result.success:
		result.error = game_result.message
		return result

	result.success = true
	result.message = game_result.message
	result.main_scene_path = game_result.main_scene_path
	return result

# Create a new scene with a node
func _create_scene_with_node(command):
	var result = {
		"success": false,
		"error": "",
		"message": ""
	}

	# Validate required fields
	if not _validate_fields(command, ["scene_path", "node_type", "node_name"], result):
		return result

	# Create a basic scene with the node
	var scene_content = """[gd_scene format=3]

[node name="%s" type="%s"]
""" % [command.node_name, command.node_type]

	# Add properties if provided
	if command.has("properties") and command.properties is Dictionary:
		for property in command.properties:
			scene_content += "\n%s = %s" % [property, _format_property_value(command.properties[property])]

	# Create the scene file
	var create_result = file_editor.create_scene(command.scene_path, scene_content)
	if not create_result.success:
		result.error = create_result.message
		return result

	result.success = true
	result.message = "Created scene file with node: " + command.scene_path
	return result

# Format a property value for use in a scene file
func _format_property_value(value):
	if value is String:
		return "\"" + value + "\""
	elif value is Vector2:
		return "Vector2(" + str(value.x) + ", " + str(value.y) + ")"
	elif value is Vector3:
		return "Vector3(" + str(value.x) + ", " + str(value.y) + ", " + str(value.z) + ")"
	elif value is Color:
		return "Color(" + str(value.r) + ", " + str(value.g) + ", " + str(value.b) + ", " + str(value.a) + ")"
	else:
		return str(value)

# Validate required fields in a command
func _validate_fields(command, required_fields, result):
	for field in required_fields:
		if not command.has(field):
			result.error = "Missing required field: " + field
			return false
	return true

# Validate GDScript code
func _validate_gdscript(code):
	var result = {
		"success": true,
		"code": code,
		"error": ""
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
	var known_variables = {}
	var function_depth = 0
	var class_depth = 0

	# First pass: identify class structure and variables
	for i in range(lines.size()):
		var line = lines[i].strip_edges()

		# Skip empty lines and comments
		if line.is_empty() or line.begins_with("#"):
			continue

		# Check for class definition
		if line.begins_with("class ") or line.begins_with("extends "):
			in_class = true
			if line.begins_with("class "):
				class_depth += 1

		# Check if we're entering a function
		if line.begins_with("func "):
			in_function = true
			function_depth = 1

		# Track function depth with braces and colons
		if in_function:
			if ":" in line:
				function_depth += 1
			if line == "pass" or line.begins_with("return"):
				function_depth -= 1
				if function_depth <= 0:
					in_function = false
					function_depth = 0

		# Track class depth
		if in_class and line.ends_with(":"):
			class_depth += 1
		if in_class and line == "pass":
			class_depth -= 1
			if class_depth <= 0:
				in_class = false
				class_depth = 0

		# Track variables that are already declared with var or const
		if line.begins_with("var ") or line.begins_with("const "):
			var var_name = line.substr(line.begins_with("var ") ? 4 : 6).strip_edges()
			if "=" in var_name:
				var_name = var_name.split("=")[0].strip_edges()
			if ":" in var_name:
				var_name = var_name.split(":")[0].strip_edges()

			known_variables[var_name] = true

	# Second pass: fix undeclared variables
	in_function = false
	in_class = false
	function_depth = 0
	class_depth = 0

	# Add a default extends if none is present
	var has_extends = false
	for line in lines:
		if line.strip_edges().begins_with("extends "):
			has_extends = true
			break

	if not has_extends:
		processed_lines.append("extends RefCounted")
		processed_lines.append("")

	for i in range(lines.size()):
		var line = lines[i]
		var stripped_line = line.strip_edges()

		# Skip empty lines
		if stripped_line.is_empty():
			processed_lines.append(line)
			continue

		# Skip comments
		if stripped_line.begins_with("#"):
			processed_lines.append(line)
			continue

		# Check for class definition
		if stripped_line.begins_with("class ") or stripped_line.begins_with("extends "):
			in_class = true
			if stripped_line.begins_with("class "):
				class_depth += 1
			processed_lines.append(line)
			continue

		# Check if we're entering a function
		if stripped_line.begins_with("func "):
			in_function = true
			function_depth = 1
			processed_lines.append(line)
			continue

		# Track function depth
		if in_function:
			if ":" in stripped_line:
				function_depth += 1
			if stripped_line == "pass" or stripped_line.begins_with("return"):
				function_depth -= 1
				if function_depth <= 0:
					in_function = false
					function_depth = 0

			# Inside functions, just add the line as is
			processed_lines.append(line)
			continue

		# Track class depth
		if in_class and stripped_line.ends_with(":"):
			class_depth += 1
		if in_class and stripped_line == "pass":
			class_depth -= 1
			if class_depth <= 0:
				in_class = false
				class_depth = 0

		# Fix undeclared variables at class level
		if in_class and not in_function:
			# Skip lines that already have var/const, comments, or other declarations
			if stripped_line.begins_with("var ") or stripped_line.begins_with("const ") or \
			   stripped_line.begins_with("#") or stripped_line.begins_with("@") or \
			   stripped_line.begins_with("signal ") or stripped_line.begins_with("enum "):
				processed_lines.append(line)
				continue

			# Check for variable assignments
			if "=" in stripped_line and not "==" in stripped_line and not "!=" in stripped_line and not "<=" in stripped_line and not ">=" in stripped_line:
				var parts = stripped_line.split("=", true, 1)
				var variable_name = parts[0].strip_edges()

				# Only consider it a variable if it's a simple identifier
				if not "." in variable_name and not "[" in variable_name and not "(" in variable_name and \
				   not variable_name.begins_with("if ") and not variable_name.begins_with("for ") and \
				   not variable_name.begins_with("while ") and not variable_name.begins_with("match "):

					# Add var declaration if not already known
					if not known_variables.has(variable_name):
						# Preserve indentation
						var indent = ""
						for j in range(line.length()):
							if line[j] == " " or line[j] == "\t":
								indent += line[j]
							else:
								break

						processed_lines.append(indent + "var " + stripped_line)
						known_variables[variable_name] = true
						continue

			# If we got here, just add the line as is
			processed_lines.append(line)

	# Make sure there's at least one function
	var has_ready = false
	for line in processed_lines:
		if line.strip_edges().begins_with("func _ready"):
			has_ready = true
			break

	if not has_ready:
		processed_lines.append("\nfunc _ready():")
		processed_lines.append("\tpass")

	result.code = "\n".join(processed_lines)
	return result
