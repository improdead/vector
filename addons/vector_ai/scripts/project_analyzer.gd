@tool
extends Node

# Reference to the editor interface
var editor_interface
var file_system

func _ready():
	# Get the editor interface
	editor_interface = Engine.get_singleton("EditorInterface")
	file_system = editor_interface.get_resource_filesystem()

# Analyze the project structure
func analyze_project():
	var project_info = "Project Structure:\n"
	
	# Get the project root directory
	var root_dir = "res://"
	
	# Recursively analyze the project
	project_info += _analyze_directory(root_dir, 0)
	
	return project_info

# Recursively analyze a directory
func _analyze_directory(dir_path, indent_level):
	var indent = "  ".repeat(indent_level)
	var dir_info = ""
	
	# Open the directory
	var dir = DirAccess.open(dir_path)
	if not dir:
		return indent + "Error opening directory: " + dir_path + "\n"
	
	# List all files and directories
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		# Skip hidden files and directories
		if not file_name.begins_with("."):
			var full_path = dir_path.path_join(file_name)
			
			if dir.current_is_dir():
				# Add directory to the info
				dir_info += indent + "📁 " + file_name + "/\n"
				
				# Recursively analyze subdirectory
				dir_info += _analyze_directory(full_path, indent_level + 1)
			else:
				# Add file to the info with its type
				var file_type = _get_file_type(file_name)
				dir_info += indent + "📄 " + file_name + " (" + file_type + ")\n"
		
		# Get the next file/directory
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	return dir_info

# Get the type of a file based on its extension
func _get_file_type(file_name):
	var extension = file_name.get_extension().to_lower()
	
	match extension:
		"gd":
			return "GDScript"
		"tscn":
			return "Scene"
		"tres":
			return "Resource"
		"import":
			return "Import"
		"png", "jpg", "jpeg", "webp":
			return "Image"
		"wav", "mp3", "ogg":
			return "Audio"
		"ttf", "otf":
			return "Font"
		"shader":
			return "Shader"
		"json":
			return "JSON"
		"txt":
			return "Text"
		"csv":
			return "CSV"
		"md":
			return "Markdown"
		_:
			return extension

# Search for files in the project
func search_files(search_term, file_extension = ""):
	var results = []
	
	# Get the project root directory
	var root_dir = "res://"
	
	# Recursively search the project
	_search_directory(root_dir, search_term, file_extension, results)
	
	return results

# Recursively search a directory
func _search_directory(dir_path, search_term, file_extension, results):
	# Open the directory
	var dir = DirAccess.open(dir_path)
	if not dir:
		return
	
	# List all files and directories
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		# Skip hidden files and directories
		if not file_name.begins_with("."):
			var full_path = dir_path.path_join(file_name)
			
			if dir.current_is_dir():
				# Recursively search subdirectory
				_search_directory(full_path, search_term, file_extension, results)
			else:
				# Check if the file matches the search criteria
				if (file_extension.is_empty() or file_name.get_extension() == file_extension) and file_name.findn(search_term) != -1:
					results.append(full_path)
		
		# Get the next file/directory
		file_name = dir.get_next()
	
	dir.list_dir_end()

# Analyze a GDScript file
func analyze_script(script_path):
	# Load the script
	var script = load(script_path)
	if not script or not script is GDScript:
		return "Not a valid GDScript file."
	
	var script_info = "Script Analysis: " + script_path + "\n\n"
	
	# Get script properties
	script_info += "Base Class: " + script.get_instance_base_type() + "\n"
	
	# Get script source code
	var file = FileAccess.open(script_path, FileAccess.READ)
	if file:
		var source_code = file.get_as_text()
		file.close()
		
		# Extract class name, methods, and properties
		script_info += _extract_script_elements(source_code)
	
	return script_info

# Extract elements from script source code
func _extract_script_elements(source_code):
	var info = ""
	var lines = source_code.split("\n")
	
	var class_name = ""
	var extends_class = ""
	var methods = []
	var properties = []
	var signals = []
	
	for line in lines:
		line = line.strip_edges()
		
		# Skip empty lines and comments
		if line.is_empty() or line.begins_with("#"):
			continue
		
		# Extract class name
		if line.begins_with("class_name "):
			class_name = line.substr(11).strip_edges()
			if class_name.find(" ") != -1:
				class_name = class_name.substr(0, class_name.find(" "))
		
		# Extract extends
		if line.begins_with("extends "):
			extends_class = line.substr(8).strip_edges()
		
		# Extract methods
		if line.begins_with("func "):
			var method_name = line.substr(5).strip_edges()
			if method_name.find("(") != -1:
				method_name = method_name.substr(0, method_name.find("("))
			methods.append(method_name)
		
		# Extract properties
		if line.begins_with("var ") or line.begins_with("const "):
			var property_line = line.substr(line.begins_with("var ") ? 4 : 6).strip_edges()
			var property_name = property_line
			if property_name.find(" ") != -1:
				property_name = property_name.substr(0, property_name.find(" "))
			if property_name.find("=") != -1:
				property_name = property_name.substr(0, property_name.find("=")).strip_edges()
			if property_name.find(":") != -1:
				property_name = property_name.substr(0, property_name.find(":")).strip_edges()
			properties.append(property_name)
		
		# Extract signals
		if line.begins_with("signal "):
			var signal_name = line.substr(7).strip_edges()
			if signal_name.find("(") != -1:
				signal_name = signal_name.substr(0, signal_name.find("("))
			signals.append(signal_name)
	
	# Build the info string
	if not class_name.is_empty():
		info += "Class Name: " + class_name + "\n"
	
	if not extends_class.is_empty():
		info += "Extends: " + extends_class + "\n"
	
	if signals.size() > 0:
		info += "\nSignals:\n"
		for signal_name in signals:
			info += "  - " + signal_name + "\n"
	
	if properties.size() > 0:
		info += "\nProperties:\n"
		for property_name in properties:
			info += "  - " + property_name + "\n"
	
	if methods.size() > 0:
		info += "\nMethods:\n"
		for method_name in methods:
			info += "  - " + method_name + "\n"
	
	return info

# Analyze a scene file
func analyze_scene(scene_path):
	# Load the scene
	var scene = load(scene_path)
	if not scene or not scene is PackedScene:
		return "Not a valid scene file."
	
	var scene_info = "Scene Analysis: " + scene_path + "\n\n"
	
	# Instantiate the scene to analyze its structure
	var instance = scene.instantiate()
	if not instance:
		return scene_info + "Failed to instantiate scene."
	
	# Analyze the scene structure
	scene_info += "Node Structure:\n"
	scene_info += _analyze_node(instance, 0)
	
	# Clean up
	instance.queue_free()
	
	return scene_info

# Analyze a node (similar to scene_analyzer.gd)
func _analyze_node(node, indent_level):
	var indent = "  ".repeat(indent_level)
	var node_info = indent + "- " + node.name + " (" + node.get_class() + ")\n"
	
	# Recursively analyze child nodes
	for child in node.get_children():
		node_info += _analyze_node(child, indent_level + 1)
	
	return node_info
