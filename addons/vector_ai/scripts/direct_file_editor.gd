@tool
extends Node

# Direct File Editor
# This script provides direct file editing capabilities for Vector AI
# It allows creating and editing files directly without relying on Godot's API

# Signal emitted when a file is edited
signal file_edited(path)

# Create a new file with the given content
func create_file(path, content):
	var result = {
		"success": false,
		"message": ""
	}
	
	# Make sure the directory exists
	var dir = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	
	# Create the file
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()
		
		result.success = true
		result.message = "File created successfully: " + path
		print("Vector AI: Created file: " + path)
		
		# Emit signal
		file_edited.emit(path)
	else:
		result.success = false
		result.message = "Failed to create file: " + path
		push_error("Vector AI: Failed to create file: " + path)
	
	return result

# Edit an existing file by replacing its content
func edit_file(path, content):
	var result = {
		"success": false,
		"message": ""
	}
	
	# Check if the file exists
	if not FileAccess.file_exists(path):
		result.success = false
		result.message = "File does not exist: " + path
		push_error("Vector AI: File does not exist: " + path)
		return result
	
	# Create a backup of the file
	var backup_path = path + ".bak"
	var original_content = ""
	
	var original_file = FileAccess.open(path, FileAccess.READ)
	if original_file:
		original_content = original_file.get_as_text()
		original_file.close()
		
		var backup_file = FileAccess.open(backup_path, FileAccess.WRITE)
		if backup_file:
			backup_file.store_string(original_content)
			backup_file.close()
	
	# Edit the file
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()
		
		result.success = true
		result.message = "File edited successfully: " + path
		print("Vector AI: Edited file: " + path)
		
		# Emit signal
		file_edited.emit(path)
	else:
		result.success = false
		result.message = "Failed to edit file: " + path
		push_error("Vector AI: Failed to edit file: " + path)
		
		# Restore from backup if edit failed
		if FileAccess.file_exists(backup_path):
			var restore_file = FileAccess.open(path, FileAccess.WRITE)
			if restore_file:
				restore_file.store_string(original_content)
				restore_file.close()
	
	return result

# Read a file and return its content
func read_file(path):
	var result = {
		"success": false,
		"content": "",
		"message": ""
	}
	
	# Check if the file exists
	if not FileAccess.file_exists(path):
		result.success = false
		result.message = "File does not exist: " + path
		push_error("Vector AI: File does not exist: " + path)
		return result
	
	# Read the file
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		result.content = file.get_as_text()
		file.close()
		
		result.success = true
		result.message = "File read successfully: " + path
	else:
		result.success = false
		result.message = "Failed to read file: " + path
		push_error("Vector AI: Failed to read file: " + path)
	
	return result

# Create a new scene file with the given content
func create_scene(path, content):
	# Just a wrapper around create_file for semantic clarity
	return create_file(path, content)

# Edit an existing scene file by replacing its content
func edit_scene(path, content):
	# Just a wrapper around edit_file for semantic clarity
	return edit_file(path, content)

# Create a new script file with the given content
func create_script(path, content):
	# Just a wrapper around create_file for semantic clarity
	return create_file(path, content)

# Edit an existing script file by replacing its content
func edit_script(path, content):
	# Just a wrapper around edit_file for semantic clarity
	return edit_file(path, content)

# Create a complete game from a template
func create_game(main_scene_path, main_script_path, scene_content, script_content):
	var result = {
		"success": false,
		"message": ""
	}
	
	# Create the main script
	var script_result = create_script(main_script_path, script_content)
	if not script_result.success:
		result.success = false
		result.message = "Failed to create main script: " + script_result.message
		return result
	
	# Create the main scene
	var scene_result = create_scene(main_scene_path, scene_content)
	if not scene_result.success:
		result.success = false
		result.message = "Failed to create main scene: " + scene_result.message
		return result
	
	result.success = true
	result.message = "Game created successfully!"
	
	return result
