@tool
extends Node

# This script provides advanced parsing and modification of .tscn files
# It can handle more complex scene structures than the basic tscn_parser

# Scene data
var scene_content = ""
var scene_path = ""
var scene_format = 3
var scene_load_steps = 0
var scene_nodes = {}
var scene_resources = {}
var scene_connections = []

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
	
	scene_content = file.get_as_text()
	file.close()
	
	# Parse the scene content
	return _parse_scene_content()

# Save the scene to a file
func save_scene(path = ""):
	if path.is_empty():
		path = scene_path
	
	if path.is_empty():
		push_error("No scene path specified")
		return false
	
	# Generate the scene content
	var content = _generate_scene_content()
	
	# Save the scene file
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("Failed to write to scene file: " + path)
		return false
	
	file.store_string(content)
	file.close()
	
	return true

# Parse the scene content
func _parse_scene_content():
	# Reset scene data
	scene_format = 3
	scene_load_steps = 0
	scene_nodes = {}
	scene_resources = {}
	scene_connections = []
	
	# Split the content into lines
	var lines = scene_content.split("\n")
	
	# Parse the header
	var header_line = lines[0]
	if header_line.begins_with("[gd_scene"):
		var format_start = header_line.find("format=") + 7
		var format_end = header_line.find(" ", format_start)
		if format_end == -1:
			format_end = header_line.find("]", format_start)
		
		if format_end != -1:
			scene_format = int(header_line.substr(format_start, format_end - format_start))
		
		var load_steps_start = header_line.find("load_steps=")
		if load_steps_start != -1:
			load_steps_start += 11
			var load_steps_end = header_line.find(" ", load_steps_start)
			if load_steps_end == -1:
				load_steps_end = header_line.find("]", load_steps_start)
			
			if load_steps_end != -1:
				scene_load_steps = int(header_line.substr(load_steps_start, load_steps_end - load_steps_start))
	
	# Parse the rest of the content
	var current_section = ""
	var current_node = ""
	var current_resource = ""
	var current_data = {}
	
	for i in range(1, lines.size()):
		var line = lines[i].strip_edges()
		
		# Skip empty lines
		if line.is_empty():
			continue
		
		# Check for section start
		if line.begins_with("["):
			# Save the current data if any
			if current_section == "node" and not current_node.is_empty():
				scene_nodes[current_node] = current_data
			elif current_section == "sub_resource" and not current_resource.is_empty():
				scene_resources[current_resource] = current_data
			
			# Reset current data
			current_data = {}
			
			# Parse the new section
			if line.begins_with("[node "):
				current_section = "node"
				current_node = _parse_node_declaration(line)
			elif line.begins_with("[sub_resource "):
				current_section = "sub_resource"
				current_resource = _parse_resource_declaration(line)
			elif line.begins_with("[connection "):
				current_section = "connection"
				var connection = _parse_connection_declaration(line)
				if connection:
					scene_connections.append(connection)
			else:
				current_section = "unknown"
		
		# Parse property assignments
		elif "=" in line:
			var property_parts = line.split("=", true, 1)
			if property_parts.size() >= 2:
				var property_name = property_parts[0].strip_edges()
				var property_value = property_parts[1].strip_edges()
				
				current_data[property_name] = property_value
	
	# Save the last section if any
	if current_section == "node" and not current_node.is_empty():
		scene_nodes[current_node] = current_data
	elif current_section == "sub_resource" and not current_resource.is_empty():
		scene_resources[current_resource] = current_data
	
	return true

# Generate scene content from the parsed data
func _generate_scene_content():
	var content = "[gd_scene"
	
	if scene_load_steps > 0:
		content += " load_steps=" + str(scene_load_steps)
	
	content += " format=" + str(scene_format) + "]\n\n"
	
	# Add resources
	for resource_id in scene_resources:
		content += "[sub_resource type=\"" + scene_resources[resource_id].type + "\" id=\"" + resource_id + "\"]\n"
		
		for property_name in scene_resources[resource_id]:
			if property_name != "type":
				content += property_name + " = " + scene_resources[resource_id][property_name] + "\n"
		
		content += "\n"
	
	# Add nodes
	for node_path in scene_nodes:
		content += "[node name=\"" + scene_nodes[node_path].name + "\" type=\"" + scene_nodes[node_path].type + "\""
		
		if scene_nodes[node_path].has("parent"):
			content += " parent=\"" + scene_nodes[node_path].parent + "\""
		
		content += "]\n"
		
		for property_name in scene_nodes[node_path]:
			if property_name != "name" and property_name != "type" and property_name != "parent":
				content += property_name + " = " + scene_nodes[node_path][property_name] + "\n"
		
		content += "\n"
	
	# Add connections
	for connection in scene_connections:
		content += "[connection signal=\"" + connection.signal + "\" from=\"" + connection.from + "\" to=\"" + connection.to + "\" method=\"" + connection.method + "\"]\n"
	
	return content

# Parse a node declaration line
func _parse_node_declaration(line):
	var node_path = ""
	
	var name_start = line.find("name=\"") + 6
	var name_end = line.find("\"", name_start)
	var node_name = line.substr(name_start, name_end - name_start)
	
	var type_start = line.find("type=\"") + 6
	var type_end = line.find("\"", type_start)
	var node_type = line.substr(type_start, type_end - type_start)
	
	var parent = ""
	var parent_start = line.find("parent=\"")
	if parent_start != -1:
		parent_start += 8
		var parent_end = line.find("\"", parent_start)
		parent = line.substr(parent_start, parent_end - parent_start)
	
	# Generate a node path
	if parent.is_empty():
		node_path = node_name
	else:
		node_path = parent + "/" + node_name
	
	# Store node data
	scene_nodes[node_path] = {
		"name": node_name,
		"type": node_type
	}
	
	if not parent.is_empty():
		scene_nodes[node_path].parent = parent
	
	return node_path

# Parse a resource declaration line
func _parse_resource_declaration(line):
	var type_start = line.find("type=\"") + 6
	var type_end = line.find("\"", type_start)
	var resource_type = line.substr(type_start, type_end - type_start)
	
	var id_start = line.find("id=\"") + 4
	var id_end = line.find("\"", id_start)
	var resource_id = line.substr(id_start, id_end - id_start)
	
	# Store resource data
	scene_resources[resource_id] = {
		"type": resource_type
	}
	
	return resource_id

# Parse a connection declaration line
func _parse_connection_declaration(line):
	var signal_start = line.find("signal=\"") + 8
	var signal_end = line.find("\"", signal_start)
	var signal_name = line.substr(signal_start, signal_end - signal_start)
	
	var from_start = line.find("from=\"") + 6
	var from_end = line.find("\"", from_start)
	var from_node = line.substr(from_start, from_end - from_start)
	
	var to_start = line.find("to=\"") + 4
	var to_end = line.find("\"", to_start)
	var to_node = line.substr(to_start, to_end - to_start)
	
	var method_start = line.find("method=\"") + 8
	var method_end = line.find("\"", method_start)
	var method_name = line.substr(method_start, method_end - method_start)
	
	return {
		"signal": signal_name,
		"from": from_node,
		"to": to_node,
		"method": method_name
	}

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
	
	# Generate a node path
	var node_path = parent_path
	if node_path != ".":
		node_path += "/"
	node_path += node_name
	
	# Create the node data
	scene_nodes[node_path] = {
		"name": node_name,
		"type": node_type
	}
	
	if parent_path != ".":
		scene_nodes[node_path].parent = parent_path
	
	# Add properties
	for property_name in properties:
		scene_nodes[node_path][property_name] = str(properties[property_name])
	
	return true

# Modify a node in the scene
func modify_node(node_path, properties):
	# Find the node
	if not scene_nodes.has(node_path):
		push_error("Node not found: " + node_path)
		return false
	
	# Update the node properties
	for property_name in properties:
		scene_nodes[node_path][property_name] = str(properties[property_name])
	
	return true

# Remove a node from the scene
func remove_node(node_path):
	# Find the node
	if not scene_nodes.has(node_path):
		push_error("Node not found: " + node_path)
		return false
	
	# Remove the node and all its children
	var nodes_to_remove = []
	
	# Find all child nodes
	for path in scene_nodes:
		if path.begins_with(node_path + "/"):
			nodes_to_remove.append(path)
	
	# Add the node itself
	nodes_to_remove.append(node_path)
	
	# Remove the nodes
	for path in nodes_to_remove:
		scene_nodes.erase(path)
	
	return true

# Add a resource to the scene
func add_resource(resource_type, resource_id, properties = {}):
	# Validate resource type
	if resource_type.is_empty():
		push_error("Resource type cannot be empty")
		return false
	
	# Validate resource ID
	if resource_id.is_empty():
		push_error("Resource ID cannot be empty")
		return false
	
	# Create the resource data
	scene_resources[resource_id] = {
		"type": resource_type
	}
	
	# Add properties
	for property_name in properties:
		scene_resources[resource_id][property_name] = str(properties[property_name])
	
	return true

# Modify a resource in the scene
func modify_resource(resource_id, properties):
	# Find the resource
	if not scene_resources.has(resource_id):
		push_error("Resource not found: " + resource_id)
		return false
	
	# Update the resource properties
	for property_name in properties:
		scene_resources[resource_id][property_name] = str(properties[property_name])
	
	return true

# Remove a resource from the scene
func remove_resource(resource_id):
	# Find the resource
	if not scene_resources.has(resource_id):
		push_error("Resource not found: " + resource_id)
		return false
	
	# Remove the resource
	scene_resources.erase(resource_id)
	
	return true

# Add a connection to the scene
func add_connection(signal_name, from_node, to_node, method_name):
	# Validate signal name
	if signal_name.is_empty():
		push_error("Signal name cannot be empty")
		return false
	
	# Validate from node
	if from_node.is_empty():
		push_error("From node cannot be empty")
		return false
	
	# Validate to node
	if to_node.is_empty():
		push_error("To node cannot be empty")
		return false
	
	# Validate method name
	if method_name.is_empty():
		push_error("Method name cannot be empty")
		return false
	
	# Create the connection
	scene_connections.append({
		"signal": signal_name,
		"from": from_node,
		"to": to_node,
		"method": method_name
	})
	
	return true

# Remove a connection from the scene
func remove_connection(signal_name, from_node, to_node, method_name):
	# Find the connection
	for i in range(scene_connections.size()):
		var connection = scene_connections[i]
		
		if connection.signal == signal_name and connection.from == from_node and connection.to == to_node and connection.method == method_name:
			# Remove the connection
			scene_connections.remove_at(i)
			return true
	
	push_error("Connection not found")
	return false
