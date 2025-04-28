@tool
extends Node

# Reference to the editor interface
var editor_interface

func _ready():
	# Get the editor interface
	editor_interface = EditorInterface.get_singleton()

func analyze_current_scene():
	# Get the current scene root
	var current_scene = editor_interface.get_edited_scene_root()
	
	if not current_scene:
		return "No scene is currently open in the editor."
	
	# Analyze the scene
	var scene_info = "Scene Name: " + current_scene.name + "\n"
	scene_info += "Scene Path: " + current_scene.scene_file_path + "\n\n"
	scene_info += "Node Structure:\n"
	
	# Recursively analyze the scene
	scene_info += _analyze_node(current_scene, 0)
	
	return scene_info

func _analyze_node(node, indent_level):
	var indent = "  ".repeat(indent_level)
	var node_info = indent + "- " + node.name + " (" + node.get_class() + ")\n"
	
	# Add node properties
	var properties = _get_node_properties(node)
	if not properties.is_empty():
		node_info += indent + "  Properties:\n"
		for property in properties:
			var value = properties[property]
			node_info += indent + "    " + property + ": " + str(value) + "\n"
	
	# Recursively analyze child nodes
	for child in node.get_children():
		node_info += _analyze_node(child, indent_level + 1)
	
	return node_info

func _get_node_properties(node):
	var properties = {}
	
	# Common properties for all nodes
	properties["visible"] = node.visible
	properties["position"] = node.position if "position" in node else null
	
	# Type-specific properties
	match node.get_class():
		"Sprite2D":
			properties["texture"] = node.texture.resource_path if node.texture else null
			properties["modulate"] = node.modulate
		"Label":
			properties["text"] = node.text
			properties["font_size"] = node.get("theme_override_font_sizes/font_size") if node.has_method("get") else null
		"Button":
			properties["text"] = node.text
			properties["disabled"] = node.disabled
		"CollisionShape2D":
			properties["shape"] = node.shape.get_class() if node.shape else null
		"RigidBody2D":
			properties["mass"] = node.mass
			properties["gravity_scale"] = node.gravity_scale
		"Camera2D":
			properties["zoom"] = node.zoom
			properties["current"] = node.current
		"AnimationPlayer":
			var animations = []
			for anim in node.get_animation_list():
				animations.append(anim)
			properties["animations"] = animations
		"AudioStreamPlayer":
			properties["stream"] = node.stream.resource_path if node.stream else null
			properties["volume_db"] = node.volume_db
		"Light2D":
			properties["energy"] = node.energy
			properties["color"] = node.color
	
	# Remove null properties
	var keys_to_remove = []
	for key in properties:
		if properties[key] == null:
			keys_to_remove.append(key)
	
	for key in keys_to_remove:
		properties.erase(key)
	
	return properties
