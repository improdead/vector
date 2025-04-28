@tool
extends Node

# Reference to the editor interface
var editor_interface
var undo_redo

func _ready():
	# Get the editor interface
	editor_interface = Engine.get_singleton("EditorInterface")
	# We'll create our own UndoRedo object
	undo_redo = UndoRedo.new()

func apply_modifications(modifications):
	# Get the current scene root
	var current_scene = editor_interface.get_edited_scene_root()

	if not current_scene:
		return {"success": false, "error": "No scene is currently open in the editor."}

	# Start the undo/redo action
	undo_redo.create_action("Vector AI Modifications")

	var success = true
	var error_message = ""
	var created_nodes = {}

	# First pass: Create nodes
	for modification in modifications:
		var node_path = modification.node_path
		var property_value = modification.property_value

		# Remove any numbering prefixes (like "1. " or "2. " or "3. ")
		if node_path.begins_with("1.") or node_path.begins_with("2.") or node_path.begins_with("3."):
			var parts = node_path.split(". ", true, 1)
			if parts.size() > 1:
				node_path = parts[1]
				modification.node_path = node_path

		# Check if this is a node creation command
		if property_value.begins_with("Type:"):
			var parent_path = node_path.get_base_dir()
			var node_name = node_path.get_file()

			# Find the parent node
			var parent_node = current_scene
			if parent_path != "":
				parent_node = current_scene.get_node_or_null(parent_path)
				if not parent_node:
					success = false
					error_message = "Parent node not found: " + parent_path
					continue

			# Parse the node type
			var node_type = property_value.replace("Type:", "").strip_edges()

			# Create the node
			var new_node
			match node_type:
				"Polygon2D":
					new_node = Polygon2D.new()
				"Sprite2D":
					new_node = Sprite2D.new()
				"Label":
					new_node = Label.new()
				"Button":
					new_node = Button.new()
				"Node2D":
					new_node = Node2D.new()
				"Control":
					new_node = Control.new()
				_:
					# Try to create a node of the specified type
					if ClassDB.class_exists(node_type):
						new_node = ClassDB.instantiate(node_type)
					else:
						success = false
						error_message = "Unknown node type: " + node_type
						continue

			# Set the node name
			new_node.name = node_name

			# Add the node to the parent
			undo_redo.add_do_method(parent_node, "add_child", new_node)
			undo_redo.add_do_method(new_node, "set_owner", current_scene)
			undo_redo.add_undo_method(parent_node, "remove_child", new_node)

			# Store the created node for later reference
			created_nodes[node_path] = new_node

	# Second pass: Set properties
	for modification in modifications:
		var node_path = modification.node_path
		var property_value = modification.property_value

		# Remove any numbering prefixes (like "1. " or "2. " or "3. ")
		if node_path.begins_with("1.") or node_path.begins_with("2.") or node_path.begins_with("3."):
			var parts = node_path.split(". ", true, 1)
			if parts.size() > 1:
				node_path = parts[1]
				modification.node_path = node_path

		# Skip node creation commands
		if property_value.begins_with("Type:"):
			continue

		# Find the node (either existing or newly created)
		var node
		if created_nodes.has(node_path):
			node = created_nodes[node_path]
		else:
			node = current_scene.get_node_or_null(node_path)

		if not node:
			success = false
			error_message = "Node not found: " + node_path
			continue

		# Parse the property and value
		var property_parts = property_value.split(":")
		if property_parts.size() < 2:
			success = false
			error_message = "Invalid property format: " + property_value
			continue

		var property_name = property_parts[0].strip_edges()
		var property_value_str = property_parts[1].strip_edges()

		# Convert the value to the appropriate type
		var value = _parse_value(property_value_str)

		# Special handling for certain properties
		if property_name == "polygon" and node is Polygon2D:
			# Parse PoolVector2Array format
			value = _parse_polygon(property_value_str)
		elif property_name == "color" and property_value_str.begins_with("Color("):
			# Parse Color format
			value = _parse_color(property_value_str)

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

func _parse_polygon(value_str):
	# Parse a PoolVector2Array from a string like "PoolVector2Array( (0, 0), (50, 0), (25, 50) )"
	var polygon = PackedVector2Array()

	# Extract the points part
	var start_idx = value_str.find("(")
	var end_idx = value_str.rfind(")")

	if start_idx != -1 and end_idx != -1:
		var points_str = value_str.substr(start_idx, end_idx - start_idx + 1)

		# Split by commas, but be careful with Vector2 commas
		var in_vector = false
		var current_point = ""

		for i in range(points_str.length()):
			var c = points_str[i]

			if c == "(":
				in_vector = true
				current_point += c
			elif c == ")":
				in_vector = false
				current_point += c

				# Parse the Vector2
				if current_point.begins_with("(") and current_point.ends_with(")"):
					var vector_str = current_point.substr(1, current_point.length() - 2)
					var components = vector_str.split(",")
					if components.size() == 2:
						var x = float(components[0].strip_edges())
						var y = float(components[1].strip_edges())
						polygon.append(Vector2(x, y))

				current_point = ""
			elif c == "," and not in_vector:
				# Skip commas between vectors
				continue
			else:
				current_point += c

	return polygon

func _parse_color(value_str):
	# Parse a Color from a string like "Color(1, 1, 1, 1)" or "Color(1, 1, 1)"
	if value_str.begins_with("Color(") and value_str.ends_with(")"):
		var components_str = value_str.substr(6, value_str.length() - 7)
		var components = components_str.split(",")

		if components.size() >= 3:
			var r = float(components[0].strip_edges())
			var g = float(components[1].strip_edges())
			var b = float(components[2].strip_edges())

			if components.size() >= 4:
				var a = float(components[3].strip_edges())
				return Color(r, g, b, a)
			else:
				return Color(r, g, b)

	return Color.WHITE
