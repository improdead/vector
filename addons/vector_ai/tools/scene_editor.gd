#!/usr/bin/env -S godot --headless --script
extends SceneTree

# This script provides a command-line interface for editing scene files
# It can be used for offline scene editing without launching the editor
# Usage: godot --headless --script scene_editor.gd -- [command] [args]

func _init():
	# Parse command line arguments
	var args = OS.get_cmdline_args()
	
	# Find the -- separator
	var separator_index = args.find("--")
	if separator_index == -1:
		print_help()
		quit()
		return
	
	# Get the arguments after the separator
	args = args.slice(separator_index + 1)
	
	if args.size() == 0:
		print_help()
		quit()
		return
	
	# Get the command
	var command = args[0]
	
	# Execute the command
	match command:
		"add":
			if args.size() < 5:
				print("Error: Not enough arguments for 'add' command")
				print_help()
				quit()
				return
			
			var scene_path = args[1]
			var node_type = args[2]
			var node_name = args[3]
			var parent_path = args[4]
			
			var properties = {}
			for i in range(5, args.size()):
				var property_parts = args[i].split("=")
				if property_parts.size() >= 2:
					properties[property_parts[0]] = property_parts[1]
			
			add_node(scene_path, node_type, node_name, parent_path, properties)
		
		"modify":
			if args.size() < 3:
				print("Error: Not enough arguments for 'modify' command")
				print_help()
				quit()
				return
			
			var scene_path = args[1]
			var node_path = args[2]
			
			var properties = {}
			for i in range(3, args.size()):
				var property_parts = args[i].split("=")
				if property_parts.size() >= 2:
					properties[property_parts[0]] = property_parts[1]
			
			modify_node(scene_path, node_path, properties)
		
		"remove":
			if args.size() < 3:
				print("Error: Not enough arguments for 'remove' command")
				print_help()
				quit()
				return
			
			var scene_path = args[1]
			var node_path = args[2]
			
			remove_node(scene_path, node_path)
		
		"help":
			print_help()
		
		_:
			print("Error: Unknown command: " + command)
			print_help()
	
	quit()

# Print help information
func print_help():
	print("Scene Editor - Command-line tool for editing Godot scene files")
	print("")
	print("Usage:")
	print("  godot --headless --script scene_editor.gd -- [command] [args]")
	print("")
	print("Commands:")
	print("  add [scene_path] [node_type] [node_name] [parent_path] [property=value ...]")
	print("    Add a node to a scene")
	print("")
	print("  modify [scene_path] [node_path] [property=value ...]")
	print("    Modify a node in a scene")
	print("")
	print("  remove [scene_path] [node_path]")
	print("    Remove a node from a scene")
	print("")
	print("  help")
	print("    Show this help information")
	print("")
	print("Examples:")
	print("  godot --headless --script scene_editor.gd -- add res://main.tscn Sprite2D Logo . texture=res://logo.png position=Vector2(100,100)")
	print("  godot --headless --script scene_editor.gd -- modify res://main.tscn Logo position=Vector2(200,200)")
	print("  godot --headless --script scene_editor.gd -- remove res://main.tscn Logo")

# Add a node to a scene
func add_node(scene_path, node_type, node_name, parent_path, properties):
	# Create a parser
	var parser = load("res://addons/vector_ai/scripts/tscn_parser.gd").new()
	
	# Load the scene
	if not parser.load_scene(scene_path):
		print("Error: Failed to load scene: " + scene_path)
		return
	
	# Add the node
	if not parser.add_node(node_type, node_name, parent_path, properties):
		print("Error: Failed to add node")
		return
	
	# Save the scene
	if not parser.save_scene():
		print("Error: Failed to save scene")
		return
	
	print("Successfully added node " + node_name + " to " + scene_path)

# Modify a node in a scene
func modify_node(scene_path, node_path, properties):
	# Create a parser
	var parser = load("res://addons/vector_ai/scripts/tscn_parser.gd").new()
	
	# Load the scene
	if not parser.load_scene(scene_path):
		print("Error: Failed to load scene: " + scene_path)
		return
	
	# Modify the node
	if not parser.modify_node(node_path, properties):
		print("Error: Failed to modify node")
		return
	
	# Save the scene
	if not parser.save_scene():
		print("Error: Failed to save scene")
		return
	
	print("Successfully modified node " + node_path + " in " + scene_path)

# Remove a node from a scene
func remove_node(scene_path, node_path):
	# Create a parser
	var parser = load("res://addons/vector_ai/scripts/tscn_parser.gd").new()
	
	# Load the scene
	if not parser.load_scene(scene_path):
		print("Error: Failed to load scene: " + scene_path)
		return
	
	# Remove the node
	if not parser.remove_node(node_path):
		print("Error: Failed to remove node")
		return
	
	# Save the scene
	if not parser.save_scene():
		print("Error: Failed to save scene")
		return
	
	print("Successfully removed node " + node_path + " from " + scene_path)
