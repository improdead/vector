@tool
extends Node

# This script handles direct modification of .tscn files
# It allows for adding, modifying, and removing nodes without using the scene tree API

# Reference to the editor interface
var editor_interface
var undo_redo

# Dictionary to store scene backups for undo operations
var scene_backups = {}

func _ready():
	# Get the editor interface
	editor_interface = Engine.get_singleton("EditorInterface")

	# Get the UndoRedo object
	if editor_interface:
		undo_redo = editor_interface.get_undo_redo()

	if not undo_redo:
		push_warning("UndoRedo not available. Changes will not be undoable.")

	# Connect to the settings_changed signal to track potential scene changes
	editor_interface.get_editor_settings().settings_changed.connect(_on_settings_changed)

func _on_settings_changed():
	# This is a workaround to detect scene changes since the scene_changed signal
	# is not directly accessible in GDScript
	var current_scene = editor_interface.get_edited_scene_root()
	if current_scene:
		# Update our reference to the current scene
		pass

func modify_scene_file(scene_path, modifications):
	# Result object
	var result = {
		"success": false,
		"error": ""
	}

	# Check if the scene path is valid
	if scene_path.is_empty():
		result.error = "Scene path is empty"
		return result

	# Make sure the scene path has the .tscn extension
	if not scene_path.ends_with(".tscn"):
		scene_path += ".tscn"

	# Check if the scene file exists
	if not FileAccess.file_exists(scene_path):
		result.error = "Scene file does not exist: " + scene_path
		return result

	# Validate all modifications before applying them
	var validation_result = _validate_modifications(modifications)
	if not validation_result.success:
		result.error = validation_result.error
		return result

	# Create a backup of the scene for undo operations
	var backup_content = _backup_scene(scene_path)
	if backup_content.is_empty():
		result.error = "Failed to create backup of scene file: " + scene_path
		return result

	# Store the backup in our dictionary
	scene_backups[scene_path] = backup_content

	# Use UndoRedo to make the changes if available
	if undo_redo:
		undo_redo.create_action("AI: Modify Scene")

		# The do method applies the modifications
		undo_redo.add_do_method(self, "_apply_and_save_modifications", scene_path, modifications)

		# The undo method restores the backup
		undo_redo.add_undo_method(self, "_restore_scene_backup", scene_path)

		# Commit the action
		undo_redo.commit_action()
	else:
		# If UndoRedo is not available, apply the modifications directly
		_apply_and_save_modifications(scene_path, modifications)

	# The actual modification is done in the _apply_and_save_modifications method
	# which is called by the UndoRedo system

	result.success = true
	return result

# Apply modifications and save the scene file
func _apply_and_save_modifications(scene_path, modifications):
	# Load the scene file as text
	var file = FileAccess.open(scene_path, FileAccess.READ)
	if not file:
		push_error("Failed to open scene file: " + scene_path)
		return

	var scene_content = file.get_as_text()
	file.close()

	# Apply modifications to the scene content
	var modified_content = _apply_modifications(scene_content, modifications)

	# Save the modified scene file
	file = FileAccess.open(scene_path, FileAccess.WRITE)
	if not file:
		push_error("Failed to write to scene file: " + scene_path)
		return

	file.store_string(modified_content)
	file.close()

	# Reload the scene in the editor
	_reload_scene_in_editor(scene_path)

	# Print a debug message
	print("Successfully modified scene: " + scene_path)

# Restore a scene backup
func _restore_scene_backup(scene_path):
	if not scene_backups.has(scene_path):
		push_error("No backup found for scene: " + scene_path)
		return

	var backup_content = scene_backups[scene_path]

	# Save the backup content to the scene file
	var file = FileAccess.open(scene_path, FileAccess.WRITE)
	if not file:
		push_error("Failed to write backup to scene file: " + scene_path)
		return

	file.store_string(backup_content)
	file.close()

	# Reload the scene in the editor
	_reload_scene_in_editor(scene_path)

	# Print a debug message
	print("Successfully restored scene backup: " + scene_path)

# Create a backup of a scene file
func _backup_scene(scene_path):
	var file = FileAccess.open(scene_path, FileAccess.READ)
	if not file:
		return ""

	var content = file.get_as_text()
	file.close()

	return content

# Validate modifications before applying them
func _validate_modifications(modifications):
	var result = {
		"success": true,
		"error": ""
	}

	var used_names = {}

	for modification in modifications:
		# Check if the modification has a valid type
		if not modification.has("type"):
			result.success = false
			result.error = "Modification missing 'type' field"
			return result

		match modification.type:
			"add_node":
				# Check if the node type is valid
				if not modification.has("node_type"):
					result.success = false
					result.error = "Add node modification missing 'node_type' field"
					return result

				var node_type = modification.node_type
				if not ClassDB.class_exists(node_type):
					result.success = false
					result.error = "Invalid node type: " + node_type
					return result

				# Check if the node name is valid
				if not modification.has("node_name"):
					result.success = false
					result.error = "Add node modification missing 'node_name' field"
					return result

				var node_name = modification.node_name
				if node_name.is_empty():
					result.success = false
					result.error = "Node name cannot be empty"
					return result

				# Check for duplicate node names
				if used_names.has(node_name):
					# Auto-append a number to make the name unique
					var base_name = node_name
					var counter = 1
					while used_names.has(node_name):
						node_name = base_name + "_" + str(counter)
						counter += 1

					# Update the modification with the new name
					modification.node_name = node_name

				used_names[node_name] = true

				# Validate properties
				if modification.has("properties"):
					for property_name in modification.properties:
						if property_name.is_empty():
							result.success = false
							result.error = "Property name cannot be empty"
							return result

			"modify_node":
				# Check if the node path is valid
				if not modification.has("node_path"):
					result.success = false
					result.error = "Modify node modification missing 'node_path' field"
					return result

				var node_path = modification.node_path
				if node_path.is_empty():
					result.success = false
					result.error = "Node path cannot be empty"
					return result

				# Validate properties
				if modification.has("properties"):
					for property_name in modification.properties:
						if property_name.is_empty():
							result.success = false
							result.error = "Property name cannot be empty"
							return result

			"remove_node":
				# Check if the node path is valid
				if not modification.has("node_path"):
					result.success = false
					result.error = "Remove node modification missing 'node_path' field"
					return result

				var node_path = modification.node_path
				if node_path.is_empty():
					result.success = false
					result.error = "Node path cannot be empty"
					return result

			_:
				result.success = false
				result.error = "Invalid modification type: " + modification.type
				return result

	return result

func _apply_modifications(scene_content, modifications):
	var modified_content = scene_content

	for modification in modifications:
		match modification.type:
			"add_node":
				modified_content = _add_node(modified_content, modification)
			"modify_node":
				modified_content = _modify_node(modified_content, modification)
			"remove_node":
				modified_content = _remove_node(modified_content, modification)

	return modified_content

func _add_node(scene_content, modification):
	# Extract required information from the modification
	var parent_path = modification.parent_path
	var node_type = modification.node_type
	var node_name = modification.node_name
	var properties = modification.properties

	# Generate a unique node ID
	var node_id = _generate_unique_node_id(scene_content)

	# Find the parent node in the scene content
	var parent_id = _find_node_id_by_path(scene_content, parent_path)
	if parent_id.is_empty():
		# If parent path is ".", use the root node
		if parent_path == ".":
			parent_id = _find_root_node_id(scene_content)
		else:
			return scene_content  # Parent not found, return unmodified content

	# Create the new node entry
	var node_entry = "[node name=\"" + node_name + "\" type=\"" + node_type + "\" parent=\"" + parent_id + "\"]\n"

	# Add properties to the node entry
	for property_name in properties:
		var property_value = properties[property_name]
		node_entry += property_name + " = " + str(property_value) + "\n"

	# Find the last node section in the scene content
	var last_node_position = 0
	var next_node_position = scene_content.find("[node", 0)

	while next_node_position != -1:
		last_node_position = next_node_position
		next_node_position = scene_content.find("[node", last_node_position + 1)

	# Find the end of the last node section
	var last_node_end = scene_content.find("\n[", last_node_position)
	if last_node_end == -1:
		last_node_end = scene_content.length()

	# Insert the new node entry after the last node section
	var modified_content = scene_content.substr(0, last_node_end) + "\n" + node_entry + scene_content.substr(last_node_end)
	return modified_content

func _modify_node(scene_content, modification):
	# Extract required information from the modification
	var node_path = modification.node_path
	var properties = modification.properties

	# Find the node in the scene content
	var node_id = _find_node_id_by_path(scene_content, node_path)
	if node_id.is_empty():
		return scene_content  # Node not found, return unmodified content

	# Find the node section in the scene content
	var node_section_start = scene_content.find("[node name=\"", 0)
	while node_section_start != -1:
		var node_section_end = scene_content.find("[node", node_section_start + 1)
		if node_section_end == -1:
			node_section_end = scene_content.length()

		var node_section = scene_content.substr(node_section_start, node_section_end - node_section_start)

		# Check if this is the node we're looking for
		if node_section.find("\"" + node_id + "\"") != -1:
			# Modify the properties in the node section
			var modified_node_section = node_section

			for property_name in properties:
				var property_value = properties[property_name]

				# Check if the property already exists in the node section
				var property_pattern = property_name + " = "
				var property_start = modified_node_section.find(property_pattern)

				if property_start != -1:
					# Property exists, modify it
					var property_end = modified_node_section.find("\n", property_start)
					if property_end == -1:
						property_end = modified_node_section.length()

					var old_property_line = modified_node_section.substr(property_start, property_end - property_start)
					var new_property_line = property_name + " = " + str(property_value)

					modified_node_section = modified_node_section.replace(old_property_line, new_property_line)
				else:
					# Property doesn't exist, add it
					modified_node_section += property_name + " = " + str(property_value) + "\n"

			# Replace the old node section with the modified one
			var modified_content = scene_content.substr(0, node_section_start) + modified_node_section + scene_content.substr(node_section_end)
			return modified_content

		node_section_start = scene_content.find("[node name=\"", node_section_end)

	return scene_content  # Node not found, return unmodified content

func _remove_node(scene_content, modification):
	# Extract required information from the modification
	var node_path = modification.node_path

	# Find the node in the scene content
	var node_id = _find_node_id_by_path(scene_content, node_path)
	if node_id.is_empty():
		return scene_content  # Node not found, return unmodified content

	# Find the node section in the scene content
	var node_section_start = scene_content.find("[node name=\"", 0)
	while node_section_start != -1:
		var node_section_end = scene_content.find("[node", node_section_start + 1)
		if node_section_end == -1:
			node_section_end = scene_content.length()

		var node_section = scene_content.substr(node_section_start, node_section_end - node_section_start)

		# Check if this is the node we're looking for
		if node_section.find("\"" + node_id + "\"") != -1:
			# Remove the node section
			var modified_content = scene_content.substr(0, node_section_start) + scene_content.substr(node_section_end)
			return modified_content

		node_section_start = scene_content.find("[node name=\"", node_section_end)

	return scene_content  # Node not found, return unmodified content

func _find_node_id_by_path(scene_content, node_path):
	# If the path is ".", return the root node ID
	if node_path == ".":
		return _find_root_node_id(scene_content)

	# Split the path into parts
	var path_parts = node_path.split("/")

	# Start with the root node
	var current_node_id = _find_root_node_id(scene_content)

	# Traverse the path
	for i in range(path_parts.size()):
		var node_name = path_parts[i]

		# Skip empty parts
		if node_name.is_empty():
			continue

		# Find the node with this name and the current parent
		var found = false
		var node_section_start = scene_content.find("[node name=\"", 0)

		while node_section_start != -1 and not found:
			var node_section_end = scene_content.find("[node", node_section_start + 1)
			if node_section_end == -1:
				node_section_end = scene_content.length()

			var node_section = scene_content.substr(node_section_start, node_section_end - node_section_start)

			# Check if this node has the right name and parent
			if node_section.find("name=\"" + node_name + "\"") != -1 and node_section.find("parent=\"" + current_node_id + "\"") != -1:
				# Extract the node ID
				var id_start = node_section.find("@") + 1
				var id_end = node_section.find("\"", id_start)
				current_node_id = node_section.substr(id_start, id_end - id_start)
				found = true

			node_section_start = scene_content.find("[node name=\"", node_section_end)

		if not found:
			return ""  # Node not found

	return current_node_id

func _find_root_node_id(scene_content):
	# Find the first node in the scene content
	var node_start = scene_content.find("[node name=\"")
	if node_start == -1:
		return ""  # No nodes found

	var node_end = scene_content.find("\n", node_start)
	if node_end == -1:
		node_end = scene_content.length()

	var node_line = scene_content.substr(node_start, node_end - node_start)

	# Check if this is the root node (no parent attribute)
	if node_line.find("parent=") == -1:
		# Extract the node ID
		var id_start = node_line.find("@") + 1
		var id_end = node_line.find("\"", id_start)
		return node_line.substr(id_start, id_end - id_start)

	return ""  # Root node not found

func _generate_unique_node_id(scene_content):
	# Find all node IDs in the scene content
	var node_ids = []
	var node_start = scene_content.find("[node")

	while node_start != -1:
		var node_end = scene_content.find("\n", node_start)
		if node_end == -1:
			node_end = scene_content.length()

		var node_line = scene_content.substr(node_start, node_end - node_start)

		# Extract the node ID
		var id_start = node_line.find("@") + 1
		var id_end = node_line.find("\"", id_start)

		if id_start != 0 and id_end != -1:
			var node_id = node_line.substr(id_start, id_end - id_start)
			node_ids.append(node_id)

		node_start = scene_content.find("[node", node_end)

	# Generate a unique ID
	var unique_id = "1"
	var id_number = 1

	while node_ids.has(unique_id):
		id_number += 1
		unique_id = str(id_number)

	return unique_id

func _reload_scene_in_editor(scene_path):
	# Get the editor interface
	if not editor_interface:
		return

	# Check if the scene is currently open in the editor
	var current_scene = editor_interface.get_edited_scene_root()
	if current_scene and current_scene.scene_file_path == scene_path:
		# Save the current scene
		editor_interface.save_scene()

		# Reload the scene
		editor_interface.reload_scene_from_path(scene_path)
	else:
		# Open the scene in the editor
		editor_interface.open_scene_from_path(scene_path)
