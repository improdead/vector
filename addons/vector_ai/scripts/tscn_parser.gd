@tool
extends Node

# This script provides a GDScript interface for parsing and modifying .tscn files
# It can be used for offline scene editing without launching the editor

# Dictionary to store scene data
var scene_data = {}
var scene_path = ""

# Load a scene file
func load_scene(path):
	scene_path = path
	
	# Check if the scene file exists
	if not FileAccess.file_exists(path):
		push_error("Scene file does not exist: " + path)
		return false
	
	# Load the scene file as text
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to open scene file: " + path)
		return false
	
	var scene_content = file.get_as_text()
	file.close()
	
	# Parse the scene content
	return _parse_scene_content(scene_content)

# Save the modified scene to a file
func save_scene(path = ""):
	if path.is_empty():
		path = scene_path
	
	if path.is_empty():
		push_error("No scene path specified")
		return false
	
	# Generate the scene content
	var scene_content = _generate_scene_content()
	
	# Save the scene file
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("Failed to write to scene file: " + path)
		return false
	
	file.store_string(scene_content)
	file.close()
	
	return true

# Add a node to the scene
func add_node(node_type, node_name, parent_path, properties = {}):
	# Validate node type
	if not ClassDB.class_exists(node_type):
		push_error("Invalid node type: " + node_type)
		return false
	
	# Validate node name
	if node_name.is_empty():
		push_error("Node name cannot be empty")
		return false
	
	# Generate a unique node ID
	var node_id = _generate_unique_node_id()
	
	# Find the parent node
	var parent_id = _find_node_id_by_path(parent_path)
	if parent_id.is_empty() and parent_path != ".":
		push_error("Parent node not found: " + parent_path)
		return false
	
	# Create the node data
	var node_data = {
		"name": node_name,
		"type": node_type,
		"parent": parent_id,
		"properties": properties
	}
	
	# Add the node to the scene data
	scene_data[node_id] = node_data
	
	return true

# Modify a node in the scene
func modify_node(node_path, properties):
	# Find the node
	var node_id = _find_node_id_by_path(node_path)
	if node_id.is_empty():
		push_error("Node not found: " + node_path)
		return false
	
	# Update the node properties
	for property_name in properties:
		scene_data[node_id].properties[property_name] = properties[property_name]
	
	return true

# Remove a node from the scene
func remove_node(node_path):
	# Find the node
	var node_id = _find_node_id_by_path(node_path)
	if node_id.is_empty():
		push_error("Node not found: " + node_path)
		return false
	
	# Remove the node and all its children
	var nodes_to_remove = [node_id]
	
	# Find all child nodes
	for id in scene_data:
		if scene_data[id].has("parent") and scene_data[id].parent == node_id:
			nodes_to_remove.append(id)
	
	# Remove the nodes
	for id in nodes_to_remove:
		scene_data.erase(id)
	
	return true

# Parse the scene content into a dictionary
func _parse_scene_content(content):
	scene_data = {}
	
	# Split the content into lines
	var lines = content.split("\n")
	
	# Parse each line
	var current_node_id = ""
	
	for line in lines:
		line = line.strip_edges()
		
		# Skip empty lines
		if line.is_empty():
			continue
		
		# Parse node declarations
		if line.begins_with("[node"):
			# Extract node information
			var name_start = line.find("name=\"") + 6
			var name_end = line.find("\"", name_start)
			var name = line.substr(name_start, name_end - name_start)
			
			var type_start = line.find("type=\"") + 6
			var type_end = line.find("\"", type_start)
			var type = line.substr(type_start, type_end - type_start)
			
			var parent = ""
			var parent_start = line.find("parent=\"")
			if parent_start != -1:
				parent_start += 8
				var parent_end = line.find("\"", parent_start)
				parent = line.substr(parent_start, parent_end - parent_start)
			
			# Generate a node ID
			current_node_id = _generate_unique_node_id()
			
			# Create the node data
			scene_data[current_node_id] = {
				"name": name,
				"type": type,
				"parent": parent,
				"properties": {}
			}
		
		# Parse property declarations
		elif current_node_id != "" and line.find("=") != -1:
			var property_parts = line.split("=", true, 1)
			if property_parts.size() >= 2:
				var property_name = property_parts[0].strip_edges()
				var property_value = property_parts[1].strip_edges()
				
				scene_data[current_node_id].properties[property_name] = property_value
	
	return true

# Generate scene content from the scene data
func _generate_scene_content():
	var content = "[gd_scene format=3]\n\n"
	
	# Add nodes
	for node_id in scene_data:
		var node = scene_data[node_id]
		
		# Add node declaration
		content += "[node name=\"" + node.name + "\" type=\"" + node.type + "\""
		
		if not node.parent.is_empty():
			content += " parent=\"" + node.parent + "\""
		
		content += "]\n"
		
		# Add properties
		for property_name in node.properties:
			content += property_name + " = " + str(node.properties[property_name]) + "\n"
		
		content += "\n"
	
	return content

# Find a node ID by its path
func _find_node_id_by_path(path):
	# If the path is ".", return the root node ID
	if path == ".":
		for node_id in scene_data:
			if scene_data[node_id].parent.is_empty():
				return node_id
		return ""
	
	# Split the path into parts
	var path_parts = path.split("/")
	
	# Start with the root node
	var current_node_id = ""
	for node_id in scene_data:
		if scene_data[node_id].parent.is_empty():
			current_node_id = node_id
			break
	
	# Traverse the path
	for i in range(path_parts.size()):
		var node_name = path_parts[i]
		
		# Skip empty parts
		if node_name.is_empty():
			continue
		
		# Find the node with this name and the current parent
		var found = false
		
		for node_id in scene_data:
			if scene_data[node_id].has("parent") and scene_data[node_id].parent == current_node_id and scene_data[node_id].name == node_name:
				current_node_id = node_id
				found = true
				break
		
		if not found:
			return ""
	
	return current_node_id

# Generate a unique node ID
func _generate_unique_node_id():
	var id = "1"
	var id_number = 1
	
	while scene_data.has(id):
		id_number += 1
		id = str(id_number)
	
	return id
