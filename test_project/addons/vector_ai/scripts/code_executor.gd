@tool
extends Node

# Reference to the editor interface
var editor_interface

func _ready():
	# Get the editor interface
	editor_interface = Engine.get_singleton("EditorInterface")

# Execute GDScript code that modifies the scene
func execute_code(code_string):
	# Get the current scene root
	var current_scene = editor_interface.get_edited_scene_root()
	
	if not current_scene:
		return {"success": false, "error": "No scene is currently open in the editor."}
	
	# Create a new script to execute the code
	var script = GDScript.new()
	
	# Prepare the script with proper context
	var full_script = """
@tool
extends RefCounted

# Function to execute the code with access to the scene
func execute(scene_root):
	var current_scene = scene_root
	
	# Begin user code
	%s
	# End user code
	
	return {"success": true}
"""

	# Insert the user code into the script template
	script.source_code = full_script % code_string
	
	# Parse and compile the script
	var error = script.reload()
	if error != OK:
		return {"success": false, "error": "Script compilation error: " + str(error)}
	
	# Create an instance of the script
	var script_instance = script.new()
	
	# Execute the script with the current scene as parameter
	var result
	
	# Use a try-catch to handle runtime errors
	result = script_instance.execute(current_scene)
	
	# If we got here without errors, return success
	if result is Dictionary and result.has("success"):
		return result
	else:
		return {"success": true}

# Extract code blocks from AI response
func extract_code_from_response(response_text):
	var code_blocks = []
	
	# Look for code blocks marked with ```gdscript and ```
	var start_marker = "```gdscript"
	var end_marker = "```"
	
	var pos = 0
	while pos < response_text.length():
		var start_pos = response_text.find(start_marker, pos)
		if start_pos == -1:
			break
			
		var code_start = start_pos + start_marker.length()
		var end_pos = response_text.find(end_marker, code_start)
		
		if end_pos == -1:
			break
			
		var code_block = response_text.substr(code_start, end_pos - code_start).strip_edges()
		code_blocks.append(code_block)
		
		pos = end_pos + end_marker.length()
	
	return code_blocks
