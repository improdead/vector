@tool
extends Node

# Reference to the editor interface
var editor_interface
var undo_redo

func _ready():
	# Get the editor interface
	editor_interface = Engine.get_singleton("EditorInterface")
	undo_redo = editor_interface.get_undo_redo()

func apply_modifications(modifications):
	# Get the current scene root
	var current_scene = editor_interface.get_edited_scene_root()

	if not current_scene:
		return {"success": false, "error": "No scene is currently open in the editor."}

	# Start the undo/redo action
	undo_redo.create_action("Vector AI Modifications")

	var success = true
	var error_message = ""

	# Apply each modification
	for modification in modifications:
		var node_path = modification.node_path
		var property_value = modification.property_value

		# Find the node
		var node = current_scene.get_node_or_null(node_path)
		if not node:
			success = false
			error_message = "Node not found: " + node_path
			continue

		# Parse the property and value
		var property_parts = property_value.split("=")
		if property_parts.size() < 2:
			success = false
			error_message = "Invalid property format: " + property_value
			continue

		var property_name = property_parts[0].strip_edges()
		var property_value_str = property_parts[1].strip_edges()

		# Convert the value to the appropriate type
		var value = _parse_value(property_value_str)

		# Check if the property exists
		if not property_name in node:
			success = false
			error_message = "Property not found: " + property_name + " in node " + node_path
			continue

		# Get the old value
		var old_value = node.get(property_name)

		# Add the undo/redo operation
		undo_redo.add_do_property(node, property_name, value)
		undo_redo.add_undo_property(node, property_name, old_value)

	# Commit the undo/redo action
	undo_redo.commit_action()

	# Return the result
	return {"success": success, "error": error_message}

func _parse_value(value_str):
	# Try to parse as a number
	if value_str.is_valid_float():
		return float(value_str)

	# Try to parse as a boolean
	if value_str.to_lower() == "true":
		return true
	if value_str.to_lower() == "false":
		return false

	# Try to parse as a Vector2
	if value_str.begins_with("(") and value_str.ends_with(")"):
		var vector_str = value_str.substr(1, value_str.length() - 2)
		var components = vector_str.split(",")
		if components.size() == 2:
			var x = float(components[0].strip_edges())
			var y = float(components[1].strip_edges())
			return Vector2(x, y)

	# Try to parse as a Color
	if value_str.begins_with("#"):
		return Color(value_str)

	# Return as string
	return value_str
