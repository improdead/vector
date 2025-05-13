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
		var mod_type = modification.get("type", "property")

		match mod_type:
			"property":
				var result = _apply_property_modification(current_scene, modification)
				if not result.success:
					success = false
					error_message = result.error
			"create_node":
				var result = _create_node(current_scene, modification)
				if not result.success:
					success = false
					error_message = result.error
			"delete_node":
				var result = _delete_node(current_scene, modification)
				if not result.success:
					success = false
					error_message = result.error
			"reparent_node":
				var result = _reparent_node(current_scene, modification)
				if not result.success:
					success = false
					error_message = result.error
			_:
				success = false
				error_message = "Unknown modification type: " + mod_type

	# Commit the undo/redo action
	undo_redo.commit_action()

	# Return the result
	return {"success": success, "error": error_message}

func _apply_property_modification(current_scene, modification):
	var node_path = modification.node_path
	var property_value = modification.property_value

	# Find the node
	var node = current_scene.get_node_or_null(node_path)
	if not node:
		return {"success": false, "error": "Node not found: " + node_path}

	# Parse the property and value
	var property_parts = property_value.split("=")
	if property_parts.size() < 2:
		return {"success": false, "error": "Invalid property format: " + property_value}

	var property_name = property_parts[0].strip_edges()
	var property_value_str = property_parts[1].strip_edges()

	# Convert the value to the appropriate type
	var value = _parse_value(property_value_str)

	# Check if the property exists
	if not property_name in node:
		return {"success": false, "error": "Property not found: " + property_name + " in node " + node_path}

	# Get the old value
	var old_value = node.get(property_name)

	# Add the undo/redo operation
	undo_redo.add_do_property(node, property_name, value)
	undo_redo.add_undo_property(node, property_name, old_value)

	return {"success": true}

func _create_node(current_scene, modification):
	var parent_path = modification.get("parent_path", ".")
	var node_type = modification.get("node_type", "")
	var node_name = modification.get("node_name", "NewNode")
	var properties = modification.get("properties", {})

	if node_type.is_empty():
		return {"success": false, "error": "Node type not specified"}

	# Find the parent node
	var parent_node = current_scene
	if parent_path != ".":
		parent_node = current_scene.get_node_or_null(parent_path)
		if not parent_node:
			return {"success": false, "error": "Parent node not found: " + parent_path}

	# Create the new node
	var new_node

	# Handle built-in node types
	if ClassDB.class_exists(node_type):
		new_node = ClassDB.instantiate(node_type)
	else:
		# Try to load a custom scene
		var script_path = node_type
		if ResourceLoader.exists(script_path):
			var resource = ResourceLoader.load(script_path)
			if resource is PackedScene:
				new_node = resource.instantiate()
			elif resource is Script:
				new_node = Node.new()
				new_node.set_script(resource)

	if not new_node:
		return {"success": false, "error": "Failed to create node of type: " + node_type}

	# Set the node name
	new_node.name = node_name

	# Add the node to the scene
	undo_redo.add_do_method(parent_node, "add_child", new_node)
	undo_redo.add_do_method(new_node, "set_owner", current_scene)
	undo_redo.add_undo_method(parent_node, "remove_child", new_node)

	# Set properties
	for property_name in properties:
		if property_name in new_node:
			var value = _parse_value(str(properties[property_name]))
			undo_redo.add_do_property(new_node, property_name, value)

	return {"success": true}

func _delete_node(current_scene, modification):
	var node_path = modification.node_path

	# Find the node
	var node = current_scene.get_node_or_null(node_path)
	if not node:
		return {"success": false, "error": "Node not found: " + node_path}

	# Get the parent
	var parent = node.get_parent()
	if not parent:
		return {"success": false, "error": "Cannot delete root node"}

	# Store node data for undo
	var node_index = node.get_index()
	var node_properties = {}

	# Get all properties for undo
	for property in node.get_property_list():
		var property_name = property.name
		if property.usage & PROPERTY_USAGE_STORAGE:
			node_properties[property_name] = node.get(property_name)

	# Add undo/redo operations
	undo_redo.add_do_method(parent, "remove_child", node)
	undo_redo.add_undo_method(parent, "add_child", node)
	undo_redo.add_undo_method(parent, "move_child", node, node_index)
	undo_redo.add_undo_method(node, "set_owner", current_scene)

	# Restore properties on undo
	for property_name in node_properties:
		undo_redo.add_undo_property(node, property_name, node_properties[property_name])

	return {"success": true}

func _reparent_node(current_scene, modification):
	var node_path = modification.node_path
	var new_parent_path = modification.new_parent_path

	# Find the node
	var node = current_scene.get_node_or_null(node_path)
	if not node:
		return {"success": false, "error": "Node not found: " + node_path}

	# Find the new parent
	var new_parent = current_scene.get_node_or_null(new_parent_path)
	if not new_parent:
		return {"success": false, "error": "New parent node not found: " + new_parent_path}

	# Get the current parent
	var old_parent = node.get_parent()
	if not old_parent:
		return {"success": false, "error": "Cannot reparent root node"}

	# Store node data for undo
	var node_index = node.get_index()

	# Add undo/redo operations
	undo_redo.add_do_method(old_parent, "remove_child", node)
	undo_redo.add_do_method(new_parent, "add_child", node)
	undo_redo.add_do_method(node, "set_owner", current_scene)

	undo_redo.add_undo_method(new_parent, "remove_child", node)
	undo_redo.add_undo_method(old_parent, "add_child", node)
	undo_redo.add_undo_method(old_parent, "move_child", node, node_index)
	undo_redo.add_undo_method(node, "set_owner", current_scene)

	return {"success": true}

func _parse_value(value_str):
	# Try to parse as a number
	if str(value_str).is_valid_float():
		return float(value_str)

	# Try to parse as a boolean
	if str(value_str).to_lower() == "true":
		return true
	if str(value_str).to_lower() == "false":
		return false

	# Try to parse as a Vector2
	if str(value_str).begins_with("(") and str(value_str).ends_with(")"):
		var vector_str = str(value_str).substr(1, str(value_str).length() - 2)
		var components = vector_str.split(",")
		if components.size() == 2:
			var x = float(components[0].strip_edges())
			var y = float(components[1].strip_edges())
			return Vector2(x, y)
		elif components.size() == 3:
			var x = float(components[0].strip_edges())
			var y = float(components[1].strip_edges())
			var z = float(components[2].strip_edges())
			return Vector3(x, y, z)

	# Try to parse as a Color
	if str(value_str).begins_with("#"):
		return Color(str(value_str))

	# Return as string
	return str(value_str)
