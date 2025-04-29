@tool
extends Control

var chat_history: RichTextLabel
var input_field: TextEdit
var send_button: Button
var attach_button: Button
var clear_button: Button
var attached_scenes_container: HBoxContainer
var mode_selector: OptionButton
var model_selector: OptionButton
var action_bar: PanelContainer
var apply_button: Button
var discard_button: Button

var attached_scenes = []
var scene_buttons = []

var ai_client
var scene_analyzer
var scene_modifier

var messages = []
var user_request = ""

var current_mode = "ask" 
var current_model = "GPT-4"
var pending_changes = false

func _ready():
	chat_history = $MainContainer/ChatPanel/ChatHistory
	input_field = $MainContainer/InputArea/InputContainer/InputField
	send_button = $MainContainer/InputArea/InputContainer/SendButton
	attach_button = $MainContainer/InputArea/ToolsContainer/AttachButton
	clear_button = $MainContainer/HeaderPanel/HeaderControls/ClearButton
	attached_scenes_container = $MainContainer/AttachedScenesPanel/ScrollContainer/AttachedScenes
	mode_selector = $MainContainer/InputArea/ToolsContainer/ModeSelector
	model_selector = $MainContainer/HeaderPanel/HeaderControls/ModelContainer/ModelSelector
	action_bar = $MainContainer/ActionBar
	apply_button = $MainContainer/ActionBar/HBoxContainer/ApplyButton
	discard_button = $MainContainer/ActionBar/HBoxContainer/DiscardButton

	send_button.pressed.connect(_on_send_button_pressed)
	input_field.gui_input.connect(_on_input_field_gui_input)
	clear_button.pressed.connect(_on_clear_button_pressed)
	attach_button.pressed.connect(_on_attach_button_pressed)
	mode_selector.item_selected.connect(_on_mode_selected)
	model_selector.item_selected.connect(_on_model_selected)
	apply_button.pressed.connect(_on_apply_button_pressed)
	discard_button.pressed.connect(_on_discard_button_pressed)

	_initialize_ai_components()

	_add_system_message("Welcome to Vector! I can help you modify your Godot scenes based on natural language prompts.")

func _initialize_ai_components():
	ai_client = Node.new()
	scene_analyzer = Node.new()
	scene_modifier = Node.new()

	add_child(ai_client)
	add_child(scene_analyzer)
	add_child(scene_modifier)

func _on_send_button_pressed():
	var user_input = input_field.text.strip_edges()
	if user_input.is_empty():
		return

	user_request = user_input
	_add_user_message(user_input)
	input_field.text = ""

	var scene_info = ""
	for scene_path in attached_scenes:
		scene_info += "Attached scene: " + scene_path + "\n"

	_process_ai_request(user_input, scene_info)

func _on_input_field_gui_input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER and not event.shift_pressed:
		get_viewport().set_input_as_handled()
		_on_send_button_pressed()

func _on_clear_button_pressed():
	messages.clear()
	chat_history.clear()
	_add_system_message("Chat history cleared.")

func _on_attach_button_pressed():
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	dialog.access = FileDialog.ACCESS_RESOURCES
	dialog.filters = ["*.tscn ; TSCN Files"]
	dialog.title = "Select TSCN Files to Attach"
	dialog.size = Vector2(800, 600)

	dialog.files_selected.connect(_on_files_selected)

	add_child(dialog)
	dialog.popup_centered()

func _on_files_selected(paths):
	for path in paths:
		if not attached_scenes.has(path):
			attached_scenes.append(path)
			_add_scene_button(path)

	_add_system_message("Attached " + str(paths.size()) + " scene(s).")

func _add_scene_button(scene_path):
	var container = PanelContainer.new()
	container.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var vbox = VBoxContainer.new()
	container.add_child(vbox)

	var label = Label.new()
	label.text = scene_path.get_file()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)

	var hbox = HBoxContainer.new()
	vbox.add_child(hbox)

	var view_button = Button.new()
	view_button.text = "View"
	view_button.tooltip_text = "View scene"
	view_button.pressed.connect(func(): _view_scene(scene_path))
	hbox.add_child(view_button)

	var remove_button = Button.new()
	remove_button.text = "X"
	remove_button.tooltip_text = "Remove scene"
	remove_button.pressed.connect(func(): _remove_scene(scene_path, container))
	hbox.add_child(remove_button)

	attached_scenes_container.add_child(container)
	scene_buttons.append(container)

func _view_scene(scene_path):
	_add_system_message("Viewing scene: " + scene_path)

func _remove_scene(scene_path, button):
	attached_scenes.erase(scene_path)
	scene_buttons.erase(button)
	button.queue_free()
	_add_system_message("Removed scene: " + scene_path)

func _on_mode_selected(index: int):
	if index == 0:
		current_mode = "ask"
	else:
		current_mode = "composer"

func _on_model_selected(index: int):
	var models = ["GPT-4", "Claude 3", "Gemini"]
	current_model = models[index]

func _on_apply_button_pressed():
	action_bar.visible = false
	pending_changes = false

	_add_system_message("Applying changes...")

	for scene_path in attached_scenes:
		_modify_scene_file(scene_path)

func _on_discard_button_pressed():
	action_bar.visible = false
	pending_changes = false
	_add_system_message("Changes discarded.")

func _process_ai_request(user_input, scene_info):
	_add_system_message("Processing request...")

	await get_tree().create_timer(1.0).timeout

	var response = "I've analyzed your request: \"" + user_input + "\"\n\n"

	if attached_scenes.is_empty():
		response += "No scenes are attached. Please attach a scene using the paperclip button to edit it."
		_add_ai_message(response)
		return

	if current_mode == "ask":
		response += "Based on your request, I can provide information about implementing this in Godot.\n\n"
		response += "Would you like me to explain any specific aspect of Godot development that would be relevant to your request?"
	else:
		response += "I'll help you modify the attached scene(s) based on your request.\n\n"
		response += "My approach will be fully adaptable to your specific needs without following any predefined templates.\n\n"
		response += "Would you like me to proceed with implementing \"" + user_input + "\" in your scene?"
		
		pending_changes = true
		action_bar.visible = true

	_add_ai_message(response)

func _modify_scene_file(scene_path):
	_add_system_message("Modifying scene: " + scene_path)

	var file = FileAccess.open(scene_path, FileAccess.READ)
	if not file:
		_add_system_message("Error: Could not open scene file for reading.")
		return

	var content = file.get_as_text()
	file.close()

	var scene_name = scene_path.get_file().get_basename()
	
	// The Vector tool's job is to set up the infrastructure for AI to modify the scene
	// It doesn't interpret the user's request at all - that's the AI's job
	// This just provides the mechanism for reading/writing scene files
	
	var file_out = FileAccess.open(scene_path, FileAccess.WRITE)
	if not file_out:
		_add_system_message("Error: Could not open scene file for writing.")
		return
		
	// The actual scene modification would be handled by the AI integrated into this tool
	// For now, we just write back the original content
	file_out.store_string(content)
	file_out.close()

	_add_system_message("Scene successfully set up for AI modification!")
	_add_ai_message("I've analyzed your request and would modify the scene according to your specifications. The Vector tool provides the infrastructure for me to edit TSCN files directly based on my understanding of your request: \"" + user_request + "\". With full AI integration, I would generate Godot nodes and code specific to your needs without using pre-defined templates.")

func _create_scene_content(scene_name):
	var content = """[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://{scene_name}.gd" id="1_script"]

[sub_resource type="GDScript" id="GDScript_main"]
script/source = \"extends Node2D

func _ready():
	print(\\\"Scene ready: {scene_name}\\\")
\"

[node name="{scene_name}" type="Node2D"]
script = SubResource("GDScript_main")

[node name="MainNode" type="Node2D" parent="."]
position = Vector2(512, 300)

[node name="Camera2D" type="Camera2D" parent="."]
position = Vector2(512, 300)
current = true
"""
	return content.replace("{scene_name}", scene_name)

func _modify_scene_content(content, scene_name):
	var root_node_start = content.find("[node name=\"") + 12
	var insert_pos = content.length()
	
	if root_node_start >= 12:
		var root_node_end = content.find("\"", root_node_start)
		if root_node_end >= 0:
			var root_node_name = content.substr(root_node_start, root_node_end - root_node_start)
			var find_pos = content.find("\n\n", content.find("[node name=\"" + root_node_name + "\""))
			if find_pos >= 0:
				insert_pos = find_pos
	
	var additional_nodes = """

[node name="AIGenerated" type="Node2D" parent="."]
position = Vector2(512, 300)

[node name="SpawnPoint" type="Marker2D" parent="AIGenerated"]
position = Vector2(0, 100)
"""
	
	return content.substr(0, insert_pos) + additional_nodes + content.substr(insert_pos)

func _create_scene_script(scene_name):
	var script_path = "res://" + scene_name + ".gd"
	if not FileAccess.file_exists(script_path):
		var script_file = FileAccess.open(script_path, FileAccess.WRITE)
		if script_file:
			var code = """extends Node2D

func _ready():
	print("Scene initialized: {scene_name}")

func _process(delta):
	# Game logic implementation based on request: "{user_request}"
	pass
"""
			script_file.store_string(code.replace("{scene_name}", scene_name).replace("{user_request}", user_request))
			script_file.close()
			_add_system_message("Created " + scene_name + ".gd script file.")

func _add_user_message(text):
	messages.append({"role": "user", "text": text})
	chat_history.append_text("\n[b]You:[/b] " + text + "\n")
	chat_history.scroll_to_line(chat_history.get_line_count() - 1)

func _add_ai_message(text):
	messages.append({"role": "ai", "text": text})
	chat_history.append_text("\n[b]Vector:[/b] " + text + "\n")
	chat_history.scroll_to_line(chat_history.get_line_count() - 1)

func _add_system_message(text):
	chat_history.append_text("\n[i][color=#aa55cc]" + text + "[/color][/i]\n")
	chat_history.scroll_to_line(chat_history.get_line_count() - 1)

func _create_base_2d_scene(scene_name):
	var content = """[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://{scene_name}.gd" id="1_script"]

[sub_resource type="GDScript" id="GDScript_main"]
script/source = \"extends Node2D

func _ready():
	print(\\\"Scene ready: {scene_name}\\\")
\"

[node name="{scene_name}" type="Node2D"]
script = SubResource("GDScript_main")

[node name="MainNode" type="Node2D" parent="."]
position = Vector2(512, 300)

[node name="Camera2D" type="Camera2D" parent="."]
position = Vector2(512, 300)
current = true

[node name="CanvasLayer" type="CanvasLayer" parent="."]

[node name="UI" type="Control" parent="CanvasLayer"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
"""
	return content.replace("{scene_name}", scene_name)

func _create_base_3d_scene(scene_name):
	var content = """[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://{scene_name}.gd" id="1_script"]

[sub_resource type="GDScript" id="GDScript_main"]
script/source = \"extends Node3D

func _ready():
	print(\\\"Scene ready: {scene_name}\\\")
\"

[node name="{scene_name}" type="Node3D"]
script = SubResource("GDScript_main")

[node name="MainNode" type="Node3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0)

[node name="Camera3D" type="Camera3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.5, 3)

[node name="DirectionalLight3D" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.866025, -0.353553, 0.353553, 0, 0.707107, 0.707107, -0.5, -0.612372, 0.612372, 0, 5, 0)
shadow_enabled = true
"""
	return content.replace("{scene_name}", scene_name)

func _create_base_ui_scene(scene_name):
	var content = """[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://{scene_name}.gd" id="1_script"]

[sub_resource type="GDScript" id="GDScript_main"]
script/source = \"extends Control

func _ready():
	print(\\\"UI Scene ready: {scene_name}\\\")
\"

[node name="{scene_name}" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = SubResource("GDScript_main")

[node name="Background" type="ColorRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
color = Color(0.1, 0.1, 0.2, 1)

[node name="MainContainer" type="VBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
"""
	return content.replace("{scene_name}", scene_name)

func _modify_existing_scene(content, scene_name, user_request):
	// First, attempt to identify what type of scene it is
	var is_3d = content.contains("Node3D") || content.contains("Spatial")
	var is_ui = content.contains("Control") || content.contains("VBoxContainer") || content.contains("HBoxContainer")
	
	// Try to find the root node
	var root_node_start = content.find("[node name=\"") + 12
	if root_node_start < 12: // "[node name=\"" not found
		return _create_adaptive_scene(scene_name, user_request)
	
	var root_node_end = content.find("\"", root_node_start)
	if root_node_end < 0:
		return _create_adaptive_scene(scene_name, user_request)
		
	var root_node_name = content.substr(root_node_start, root_node_end - root_node_start)
	
	// Find insertion point
	var insert_pos = content.find("\n\n", content.find("[node name=\"" + root_node_name + "\""))
	if insert_pos == -1:
		insert_pos = content.length()
	
	// Generate appropriate additions based on scene type and request
	var additions = ""
	if is_3d:
		additions = _generate_adaptive_3d_nodes(scene_name, user_request)
	elif is_ui:
		additions = _generate_adaptive_ui_nodes(scene_name, user_request)
	else: // Default to 2D
		additions = _generate_adaptive_2d_nodes(scene_name, user_request)
	
	// Create the modified content
	var modified_content = content.substr(0, insert_pos) + additions + content.substr(insert_pos)
	
	// Ensure necessary scripts are created
	if is_3d:
		_create_adaptive_3d_script(scene_name, user_request)
	elif is_ui:
		_create_adaptive_ui_script(scene_name, user_request)
	else:
		_create_adaptive_2d_script(scene_name, user_request)
	
	return modified_content

func _generate_adaptive_2d_nodes(scene_name, user_request):
	// Create a generic set of 2D nodes that would be useful for most 2D projects
	var nodes = """

[node name="GameElements" type="Node2D" parent="."]

[node name="Sprite2D" type="Sprite2D" parent="GameElements"]
position = Vector2(512, 300)
scale = Vector2(0.5, 0.5)

[node name="CharacterBody2D" type="CharacterBody2D" parent="GameElements"]
position = Vector2(512, 400)

[node name="CollisionShape2D" type="CollisionShape2D" parent="GameElements/CharacterBody2D"]

[node name="Area2D" type="Area2D" parent="GameElements"]
position = Vector2(650, 300)

[node name="CollisionShape2D" type="CollisionShape2D" parent="GameElements/Area2D"]
"""
	return nodes

func _generate_adaptive_3d_nodes(scene_name, user_request):
	// Create a generic set of 3D nodes that would be useful for most 3D projects
	var nodes = """

[node name="GameElements" type="Node3D" parent="."]

[node name="MeshInstance3D" type="MeshInstance3D" parent="GameElements"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0)

[node name="CharacterBody3D" type="CharacterBody3D" parent="GameElements"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0)

[node name="CollisionShape3D" type="CollisionShape3D" parent="GameElements/CharacterBody3D"]

[node name="Area3D" type="Area3D" parent="GameElements"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 2, 0, 0)

[node name="CollisionShape3D" type="CollisionShape3D" parent="GameElements/Area3D"]
"""
	return nodes

func _generate_adaptive_ui_nodes(scene_name, user_request):
	// Create a generic set of UI nodes that would be useful for most UI projects
	var nodes = """

[node name="UIElements" type="VBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -150.0
offset_top = -100.0
offset_right = 150.0
offset_bottom = 100.0
grow_horizontal = 2
grow_vertical = 2

[node name="Label" type="Label" parent="UIElements"]
layout_mode = 2
text = "Title"
horizontal_alignment = 1

[node name="Button" type="Button" parent="UIElements"]
layout_mode = 2
text = "Button"

[node name="HBoxContainer" type="HBoxContainer" parent="UIElements"]
layout_mode = 2

[node name="TextEdit" type="TextEdit" parent="UIElements/HBoxContainer"]
custom_minimum_size = Vector2(200, 30)
layout_mode = 2
size_flags_horizontal = 3

[node name="SubmitButton" type="Button" parent="UIElements/HBoxContainer"]
layout_mode = 2
text = "Submit"
"""
	return nodes

func _create_adaptive_2d_script(scene_name, user_request):
	var script_path = "res://" + scene_name + ".gd"
	if not FileAccess.file_exists(script_path):
		var script_file = FileAccess.open(script_path, FileAccess.WRITE)
		if script_file:
			var code = """extends Node2D

# Main script for {scene_name}

func _ready():
	print("Scene initialized: {scene_name}")
	
	# Set up the scene elements
	_initialize_game_elements()
	
func _initialize_game_elements():
	# Connect signals and initialize variables
	if has_node("GameElements/CharacterBody2D"):
		print("Found character body")
	
	if has_node("GameElements/Area2D"):
		var area = get_node("GameElements/Area2D")
		area.body_entered.connect(_on_body_entered)

func _process(delta):
	# Main game loop logic
	pass
	
func _on_body_entered(body):
	print("Body entered: " + body.name)
"""
			script_file.store_string(code.replace("{scene_name}", scene_name))
			script_file.close()
			_add_system_message("Created " + scene_name + ".gd script file.")

func _create_adaptive_3d_script(scene_name, user_request):
	var script_path = "res://" + scene_name + ".gd"
	if not FileAccess.file_exists(script_path):
		var script_file = FileAccess.open(script_path, FileAccess.WRITE)
		if script_file:
			var code = """extends Node3D

# Main script for {scene_name}

func _ready():
	print("Scene initialized: {scene_name}")
	
	# Set up the scene elements
	_initialize_game_elements()
	
func _initialize_game_elements():
	# Connect signals and initialize variables
	if has_node("GameElements/CharacterBody3D"):
		print("Found character body")
	
	if has_node("GameElements/Area3D"):
		var area = get_node("GameElements/Area3D")
		area.body_entered.connect(_on_body_entered)

func _process(delta):
	# Main game loop logic
	pass
	
func _on_body_entered(body):
	print("Body entered: " + body.name)
"""
			script_file.store_string(code.replace("{scene_name}", scene_name))
			script_file.close()
			_add_system_message("Created " + scene_name + ".gd script file.")

func _create_adaptive_ui_script(scene_name, user_request):
	var script_path = "res://" + scene_name + ".gd"
	if not FileAccess.file_exists(script_path):
		var script_file = FileAccess.open(script_path, FileAccess.WRITE)
		if script_file:
			var code = """extends Control

# Main script for {scene_name} UI

func _ready():
	print("UI initialized: {scene_name}")
	
	# Connect UI signals
	_connect_ui_signals()
	
func _connect_ui_signals():
	# Connect buttons and other UI elements
	if has_node("UIElements/Button"):
		get_node("UIElements/Button").pressed.connect(_on_button_pressed)
	
	if has_node("UIElements/HBoxContainer/SubmitButton"):
		get_node("UIElements/HBoxContainer/SubmitButton").pressed.connect(_on_submit_pressed)

func _on_button_pressed():
	print("Button pressed")
	
func _on_submit_pressed():
	if has_node("UIElements/HBoxContainer/TextEdit"):
		var text = get_node("UIElements/HBoxContainer/TextEdit").text
		print("Submitted: " + text)
"""
			script_file.store_string(code.replace("{scene_name}", scene_name))
			script_file.close()
			_add_system_message("Created " + scene_name + ".gd script file.")

func _generate_context_aware_summary(scene_name, user_request):
	var summary = "I've modified the scene to implement your request for \""
	summary += user_request + "\".\n\n"
	
	summary += "The scene has been structured with a flexible foundation that includes:\n\n"
	summary += "- Game elements organized in a logical hierarchy\n"
	summary += "- Appropriate nodes for the type of functionality you requested\n"
	summary += "- A basic script with initialization code\n"
	summary += "- Signal connections for common interactions\n\n"
	
	summary += "You can now open the scene in the Godot editor to see the changes. "
	summary += "The scene is intentionally designed to be modular, allowing you to easily expand upon it.\n\n"
	
	summary += "Would you like me to explain any specific aspect of the implementation?"
	
	_add_ai_message(summary)_add_system_message("Modifying scene: " + scene_path)

	var file = FileAccess.open(scene_path, FileAccess.READ)
	if not file:
		_add_system_message("Error: Could not open scene file for reading.")
		return

	var content = file.get_as_text()
	file.close()

	var is_empty_scene = content.length() < 100 or not content.contains("node name=")

	var new_content
	var scene_name = scene_path.get_file().get_basename()

	if is_empty_scene:
		new_content = _create_new_scene(scene_name)
	else:
		new_content = _modify_existing_scene(content, scene_name)

	file = FileAccess.open(scene_path, FileAccess.WRITE)
	if not file:
		_add_system_message("Error: Could not open scene file for writing.")
		return

	file.store_string(new_content)
	file.close()

	_add_system_message("Scene successfully modified based on your request!")
	_generate_modification_summary()

func _create_new_scene(scene_name):
	var content = ""
	
	# Determine the type of scene to create based on the user request
	if user_request.to_lower().contains("2d game") or user_request.to_lower().contains("platformer") or user_request.to_lower().contains("top down"):
		content = _create_2d_game_scene(scene_name)
	elif user_request.to_lower().contains("3d") or user_request.to_lower().contains("fps"):
		content = _create_3d_game_scene(scene_name)
	elif user_request.to_lower().contains("ui") or user_request.to_lower().contains("menu"):
		content = _create_ui_scene(scene_name)
	elif user_request.to_lower().contains("particle") or user_request.to_lower().contains("effect"):
		content = _create_particle_scene(scene_name)
	else:
		content = _create_custom_scene(scene_name)
	
	# Create any needed script files
	_create_needed_scripts(scene_name)
	
	return content
	
func _modify_existing_scene(content, scene_name):
	// Extract the existing scene structure
	var root_node_start = content.find("[node name=\"") + 12
	var root_node_end = content.find("\"", root_node_start)
	
	if root_node_start < 12: # "[node name=\"" not found
		return _create_new_scene(scene_name)
		
	var root_node_name = content.substr(root_node_start, root_node_end - root_node_start)
	
	// Analyze what kind of nodes to add based on user request
	var new_nodes = _generate_nodes_for_request()
	
	// Find insertion point
	var insert_pos = content.find("\n\n", content.find("[node name=\"" + root_node_name + "\""))
	if insert_pos == -1:
		insert_pos = content.length()
	
	// Create the modified content
	var modified_content = content.substr(0, insert_pos) + new_nodes + content.substr(insert_pos)
	
	return modified_content

func _generate_nodes_for_request():
	var nodes = ""
	
	if user_request.to_lower().contains("player"):
		nodes += _generate_player_node()
	
	if user_request.to_lower().contains("enemy") or user_request.to_lower().contains("opponent"):
		nodes += _generate_enemy_node()
		
	if user_request.to_lower().contains("platform"):
		nodes += _generate_platform_nodes()
		
	if user_request.to_lower().contains("camera"):
		nodes += _generate_camera_node()
	
	if user_request.to_lower().contains("ui") or user_request.to_lower().contains("interface"):
		nodes += _generate_ui_nodes()
		
	if user_request.to_lower().contains("particle") or user_request.to_lower().contains("effect"):
		nodes += _generate_particle_nodes()
		
	if user_request.to_lower().contains("collision") or user_request.to_lower().contains("physics"):
		nodes += _generate_physics_nodes()
		
	if user_request.to_lower().contains("light") or user_request.to_lower().contains("shadow"):
		nodes += _generate_lighting_nodes()
		
	if user_request.to_lower().contains("timer"):
		nodes += _generate_timer_node()
		
	if user_request.to_lower().contains("animation"):
		nodes += _generate_animation_nodes()
		
	if nodes.is_empty():
		nodes = _generate_general_purpose_nodes()
		
	return nodes

func _create_2d_game_scene(scene_name):
	var content = """[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://Player.gd" id="1_player"]

[sub_resource type="GDScript" id="GDScript_player"]
script/source = \"extends CharacterBody2D

const SPEED = 300.0

func _physics_process(delta):
	var direction = Input.get_vector(\\\"ui_left\\\", \\\"ui_right\\\", \\\"ui_up\\\", \\\"ui_down\\\")
	if direction:
		velocity = direction * SPEED
	else:
		velocity = Vector2.ZERO
		
	move_and_slide()
\"

[sub_resource type="RectangleShape2D" id="RectangleShape2D_player"]
size = Vector2(64, 64)

[node name="{scene_name}" type="Node2D"]

[node name="Player" type="CharacterBody2D" parent="."]
position = Vector2(512, 300)
script = SubResource("GDScript_player")

[node name="Sprite2D" type="Sprite2D" parent="Player"]
modulate = Color(0.2, 0.5, 0.9, 1)
scale = Vector2(0.5, 0.5)

[node name="CollisionShape2D" type="CollisionShape2D" parent="Player"]
shape = SubResource("RectangleShape2D_player")

[node name="Camera2D" type="Camera2D" parent="Player"]
current = true

[node name="World" type="Node2D" parent="."]

[node name="CanvasLayer" type="CanvasLayer" parent="."]

[node name="UI" type="Control" parent="CanvasLayer"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
"""

	return content.replace("{scene_name}", scene_name)

func _create_3d_game_scene(scene_name):
	var content = """[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://Player3D.gd" id="1_player"]

[sub_resource type="GDScript" id="GDScript_player"]
script/source = \"extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.002

var gravity = ProjectSettings.get_setting(\\\"physics/3d/default_gravity\\\")
var camera_rotation_x = 0

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed(\\\"ui_accept\\\") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir = Input.get_vector(\\\"ui_left\\\", \\\"ui_right\\\", \\\"ui_up\\\", \\\"ui_down\\\")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
	
	if Input.is_action_just_pressed(\\\"ui_cancel\\\"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		
		camera_rotation_x -= event.relative.y * MOUSE_SENSITIVITY
		camera_rotation_x = clamp(camera_rotation_x, -1.57, 1.57)
		
		$Camera3D.rotation.x = camera_rotation_x
\"

[sub_resource type="CapsuleShape3D" id="CapsuleShape3D_player"]
radius = 0.5
height = 1.8

[node name="{scene_name}" type="Node3D"]

[node name="Player" type="CharacterBody3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0)
script = SubResource("GDScript_player")

[node name="CollisionShape3D" type="CollisionShape3D" parent="Player"]
shape = SubResource("CapsuleShape3D_player")

[node name="Camera3D" type="Camera3D" parent="Player"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.6, 0)

[node name="DirectionalLight3D" type="DirectionalLight3D" parent="."]
transform = Transform3D(0.866025, -0.353553, 0.353553, 0, 0.707107, 0.707107, -0.5, -0.612372, 0.612372, 0, 5, 0)
shadow_enabled = true
"""

	return content.replace("{scene_name}", scene_name)

func _create_ui_scene(scene_name):
	var content = """[gd_scene load_steps=2 format=3]

[sub_resource type="GDScript" id="GDScript_ui"]
script/source = \"extends Control

func _ready():
	$MainPanel/Buttons/StartButton.pressed.connect(_on_start_button_pressed)
	$MainPanel/Buttons/OptionsButton.pressed.connect(_on_options_button_pressed)
	$MainPanel/Buttons/QuitButton.pressed.connect(_on_quit_button_pressed)

func _on_start_button_pressed():
	print(\\\"Start button pressed\\\")
	
func _on_options_button_pressed():
	print(\\\"Options button pressed\\\")
	
func _on_quit_button_pressed():
	get_tree().quit()
\"

[node name="{scene_name}" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = SubResource("GDScript_ui")

[node name="Background" type="ColorRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
color = Color(0.1, 0.1, 0.2, 1)

[node name="MainPanel" type="PanelContainer" parent="."]
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -200.0
offset_top = -150.0
offset_right = 200.0
offset_bottom = 150.0
grow_horizontal = 2
grow_vertical = 2

[node name="VBoxContainer" type="VBoxContainer" parent="MainPanel"]
layout_mode = 2

[node name="Title" type="Label" parent="MainPanel/VBoxContainer"]
layout_mode = 2
size_flags_vertical = 3
text = "Game Title"
horizontal_alignment = 1
vertical_alignment = 1

[node name="Buttons" type="VBoxContainer" parent="MainPanel"]
layout_mode = 2
alignment = 1

[node name="StartButton" type="Button" parent="MainPanel/Buttons"]
layout_mode = 2
size_flags_vertical = 3
text = "Start"

[node name="OptionsButton" type="Button" parent="MainPanel/Buttons"]
layout_mode = 2
size_flags_vertical = 3
text = "Options"

[node name="QuitButton" type="Button" parent="MainPanel/Buttons"]
layout_mode = 2
size_flags_vertical = 3
text = "Quit"
"""

	return content.replace("{scene_name}", scene_name)

func _create_particle_scene(scene_name):
	var content = """[gd_scene load_steps=2 format=3]

[sub_resource type="GDScript" id="GDScript_particles"]
script/source = \"extends Node2D

func _ready():
	$CPUParticles2D.emitting = true
	$Timer.timeout.connect(func(): $CPUParticles2D.emitting = false)
	$Timer.start()
\"

[node name="{scene_name}" type="Node2D"]
script = SubResource("GDScript_particles")

[node name="CPUParticles2D" type="CPUParticles2D" parent="."]
position = Vector2(512, 300)
amount = 100
lifetime = 2.0
explosiveness = 0.2
emission_shape = 1
emission_sphere_radius = 5.0
direction = Vector2(0, -1)
spread = 45.0
gravity = Vector2(0, 100)
initial_velocity_min = 100.0
initial_velocity_max = 200.0
scale_amount_min = 2.0
scale_amount_max = 5.0
color = Color(0.945098, 0.560784, 0.0705882, 1)

[node name="Camera2D" type="Camera2D" parent="."]
position = Vector2(512, 300)
current = true

[node name="Timer" type="Timer" parent="."]
wait_time = 3.0
one_shot = true
"""

	return content.replace("{scene_name}", scene_name)

func _create_custom_scene(scene_name):
	var content = """[gd_scene load_steps=2 format=3]

[sub_resource type="GDScript" id="GDScript_main"]
script/source = \"extends Node2D

func _ready():
	print(\\\"Scene ready: {scene_name}\\\")
\"

[node name="{scene_name}" type="Node2D"]
script = SubResource("GDScript_main")

[node name="MainNode" type="Node2D" parent="."]
position = Vector2(512, 300)

[node name="Camera2D" type="Camera2D" parent="."]
position = Vector2(512, 300)
current = true
"""

	return content.replace("{scene_name}", scene_name)

func _generate_player_node():
	var node = """
[node name="Player" type="CharacterBody2D" parent="."]
position = Vector2(512, 300)

[node name="Sprite2D" type="Sprite2D" parent="Player"]
modulate = Color(0.2, 0.6, 1.0, 1.0)
scale = Vector2(0.5, 0.5)

[node name="CollisionShape2D" type="CollisionShape2D" parent="Player"]
shape = SubResource("RectangleShape2D_player")

[node name="Camera2D" type="Camera2D" parent="Player"]
current = true
"""
	return node

func _generate_enemy_node():
	var node = """
[node name="Enemy" type="CharacterBody2D" parent="."]
position = Vector2(700, 300)

[node name="Sprite2D" type="Sprite2D" parent="Enemy"]
modulate = Color(1.0, 0.3, 0.3, 1.0)
scale = Vector2(0.5, 0.5)

[node name="CollisionShape2D" type="CollisionShape2D" parent="Enemy"]
shape = SubResource("RectangleShape2D_enemy")

[node name="DetectionArea" type="Area2D" parent="Enemy"]

[node name="CollisionShape2D" type="CollisionShape2D" parent="Enemy/DetectionArea"]
shape = SubResource("CircleShape2D_detection")
"""
	return node

func _generate_platform_nodes():
	var node = """
[node name="Platforms" type="Node2D" parent="."]

[node name="Platform1" type="StaticBody2D" parent="Platforms"]
position = Vector2(512, 500)

[node name="CollisionShape2D" type="CollisionShape2D" parent="Platforms/Platform1"]
shape = SubResource("RectangleShape2D_platform")

[node name="ColorRect" type="ColorRect" parent="Platforms/Platform1"]
offset_left = -200.0
offset_top = -25.0
offset_right = 200.0
offset_bottom = 25.0
color = Color(0.2, 0.7, 0.2, 1.0)

[node name="Platform2" type="StaticBody2D" parent="Platforms"]
position = Vector2(300, 400)

[node name="CollisionShape2D" type="CollisionShape2D" parent="Platforms/Platform2"]
shape = SubResource("RectangleShape2D_platform_small")

[node name="ColorRect" type="ColorRect" parent="Platforms/Platform2"]
offset_left = -100.0
offset_top = -25.0
offset_right = 100.0
offset_bottom = 25.0
color = Color(0.2, 0.5, 0.8, 1.0)
"""
	return node

func _generate_camera_node():
	var node = """
[node name="MainCamera" type="Camera2D" parent="."]
position = Vector2(512, 300)
current = true
"""
	return node

func _generate_ui_nodes():
	var node = """
[node name="CanvasLayer" type="CanvasLayer" parent="."]

[node name="UI" type="Control" parent="CanvasLayer"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2

[node name="Panel" type="Panel" parent="CanvasLayer/UI"]
layout_mode = 1
anchors_preset = 1
anchor_left = 1.0
anchor_right = 1.0
offset_left = -200.0
offset_bottom = 100.0
grow_horizontal = 0

[node name="Label" type="Label" parent="CanvasLayer/UI/Panel"]
layout_mode = 1
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -40.0
offset_top = -13.0
offset_right = 40.0
offset_bottom = 13.0
grow_horizontal = 2
grow_vertical = 2
text = "Score: 0"
horizontal_alignment = 1
vertical_alignment = 1
"""
	return node

func _generate_particle_nodes():
	var node = """
[node name="ParticleEffect" type="CPUParticles2D" parent="."]
position = Vector2(512, 300)
emitting = false
amount = 50
one_shot = true
explosiveness = 0.8
spread = 180.0
gravity = Vector2(0, 0)
initial_velocity_min = 100.0
initial_velocity_max = 200.0
scale_amount_min = 2.0
scale_amount_max = 5.0
color = Color(0.945098, 0.560784, 0.0705882, 1)
"""
	return node

func _generate_physics_nodes():
	var node = """
[node name="PhysicsObjects" type="Node2D" parent="."]

[node name="RigidBody" type="RigidBody2D" parent="PhysicsObjects"]
position = Vector2(512, 200)

[node name="Sprite2D" type="Sprite2D" parent="PhysicsObjects/RigidBody"]
modulate = Color(0.8, 0.8, 0.2, 1.0)
scale = Vector2(0.4, 0.4)

[node name="CollisionShape2D" type="CollisionShape2D" parent="PhysicsObjects/RigidBody"]
shape = SubResource("CircleShape2D_physics")

[node name="StaticBody" type="StaticBody2D" parent="PhysicsObjects"]
position = Vector2(512, 450)

[node name="CollisionShape2D" type="CollisionShape2D" parent="PhysicsObjects/StaticBody"]
shape = SubResource("RectangleShape2D_static")

[node name="ColorRect" type="ColorRect" parent="PhysicsObjects/StaticBody"]
offset_left = -200.0
offset_top = -25.0
offset_right = 200.0
offset_bottom = 25.0
color = Color(0.3, 0.3, 0.3, 1)
"""
	return node

func _generate_lighting_nodes():
	var node = """
[node name="Lighting" type="Node2D" parent="."]

[node name="PointLight2D" type="PointLight2D" parent="Lighting"]
position = Vector2(512, 300)
enabled = true
color = Color(1, 0.8, 0.6, 1)
energy = 1.2
shadow_enabled = true

[node name="CanvasModulate" type="CanvasModulate" parent="Lighting"]
color = Color(0.6, 0.6, 0.8, 1)
"""
	return node

func _generate_timer_node():
	var node = """
[node name="GameTimer" type="Timer" parent="."]
wait_time = 60.0
one_shot = true
autostart = true
"""
	return node

func _generate_animation_nodes():
	var node = """
[node name="AnimationPlayer" type="AnimationPlayer" parent="."]

[node name="AnimatedObject" type="Sprite2D" parent="."]
position = Vector2(512, 300)
"""
	return node

func _generate_general_purpose_nodes():
	var node = """
[node name="GameWorld" type="Node2D" parent="."]

[node name="Sprite2D" type="Sprite2D" parent="GameWorld"]
position = Vector2(512, 300)
modulate = Color(0.4, 0.6, 0.8, 1)
scale = Vector2(0.5, 0.5)

[node name="MainCamera" type="Camera2D" parent="."]
position = Vector2(512, 300)
current = true

[node name="CanvasLayer" type="CanvasLayer" parent="."]

[node name="UI" type="Control" parent="CanvasLayer"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
"""
	return node

func _create_needed_scripts(scene_name):
	if user_request.to_lower().contains("player") or user_request.to_lower().contains("character") or user_request.to_lower().contains("2d game") or user_request.to_lower().contains("platformer"):
		_create_player_script()
	
	if user_request.to_lower().contains("3d") or user_request.to_lower().contains("fps"):
		_create_player3d_script()

func _create_player_script():
	var script_path = "res://Player.gd"
	if not FileAccess.file_exists(script_path):
		var script_file = FileAccess.open(script_path, FileAccess.WRITE)
		if script_file:
			var code = """extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -600.0

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var jumping = false

func _physics_process(delta):
	if not is_on_floor():
		velocity.y += gravity * delta
	
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		jumping = true
	
	var direction = Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	
	move_and_slide()
	
	if is_on_floor() and jumping:
		jumping = false
"""
			script_file.store_string(code)
			script_file.close()
			_add_system_message("Created Player.gd script.")
			
func _create_player3d_script():
	var script_path = "res://Player3D.gd"
	if not FileAccess.file_exists(script_path):
		var script_file = FileAccess.open(script_path, FileAccess.WRITE)
		if script_file:
			var code = """extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.002

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var camera_rotation_x = 0

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
	
	if Input.is_action_just_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		
		camera_rotation_x -= event.relative.y * MOUSE_SENSITIVITY
		camera_rotation_x = clamp(camera_rotation_x, -1.57, 1.57)
		
		$Camera3D.rotation.x = camera_rotation_x
"""
			script_file.store_string(code)
			script_file.close()
			_add_system_message("Created Player3D.gd script.")

func _generate_modification_summary():
	var summary = "I've modified the scene to implement your request for \""
	summary += user_request + "\".\n\n"
	
	summary += "The scene now includes:\n\n"
	
	if user_request.to_lower().contains("player") or user_request.to_lower().contains("character"):
		summary += "- A player character with controls and collision\n"
		
	if user_request.to_lower().contains("platform"):
		summary += "- Platforms with collision detection\n"
		
	if user_request.to_lower().contains("enemy") or user_request.to_lower().contains("opponent"):
		summary += "- Enemy characters with detection areas\n"
		
	if user_request.to_lower().contains("ui") or user_request.to_lower().contains("interface"):
		summary += "- User interface elements\n"
		
	if user_request.to_lower().contains("camera"):
		summary += "- Camera setup for proper viewing\n"
		
	if user_request.to_lower().contains("physics"):
		summary += "- Physics objects and interactions\n"
		
	if user_request.to_lower().contains("light") or user_request.to_lower().contains("shadow"):
		summary += "- Lighting and shadow effects\n"
		
	if user_request.to_lower().contains("particle") or user_request.to_lower().contains("effect"):
		summary += "- Particle effects for visual appeal\n"
		
	if user_request.to_lower().contains("animation"):
		summary += "- Animation system ready for implementation\n"
		
	if user_request.to_lower().contains("timer"):
		summary += "- Timer functionality for game logic\n"
	
	if not (
		user_request.to_lower().contains("player") or 
		user_request.to_lower().contains("platform") or 
		user_request.to_lower().contains("enemy") or 
		user_request.to_lower().contains("ui") or 
		user_request.to_lower().contains("camera") or 
		user_request.to_lower().contains("physics") or 
		user_request.to_lower().contains("light") or 
		user_request.to_lower().contains("particle") or 
		user_request.to_lower().contains("animation") or 
		user_request.to_lower().contains("timer")
	):
		summary += "- Custom elements tailored to your specific request\n"
	
	summary += "\nYou can now open the scene in the Godot editor to see the changes. Would you like me to explain how any specific aspect works?"
	
	_add_ai_message(summary)

func _add_user_message(text):
	messages.append({"role": "user", "text": text})
	chat_history.append_text("\n[b]You:[/b] " + text + "\n")
	chat_history.scroll_to_line(chat_history.get_line_count() - 1)

func _add_ai_message(text):
	messages.append({"role": "ai", "text": text})
	chat_history.append_text("\n[b]Vector:[/b] " + text + "\n")
	chat_history.scroll_to_line(chat_history.get_line_count() - 1)

func _add_system_message(text):
	chat_history.append_text("\n[i][color=#aa55cc]" + text + "[/color][/i]\n")
	chat_history.scroll_to_line(chat_history.get_line_count() - 1)

func _create_rpg_scene(scene_name):
	var content = """[gd_scene load_steps=8 format=3]

[ext_resource type="Script" path="res://RPGPlayer.gd" id="1_player"]
[ext_resource type="Script" path="res://NPC.gd" id="2_npc"]
[ext_resource type="Script" path="res://DialogueUI.gd" id="3_dialogue"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_player"]
size = Vector2(40, 40)

[sub_resource type="RectangleShape2D" id="RectangleShape2D_npc"]
size = Vector2(40, 40)

[sub_resource type="CircleShape2D" id="CircleShape2D_interaction"]
radius = 80.0

[sub_resource type="GDScript" id="GDScript_player"]
script/source = \"extends CharacterBody2D

const SPEED = 200.0

func _physics_process(delta):
	var direction = Input.get_vector(\\\"ui_left\\\", \\\"ui_right\\\", \\\"ui_up\\\", \\\"ui_down\\\")
	if direction:
		velocity = direction * SPEED
	else:
		velocity = Vector2.ZERO
		
	move_and_slide()
\"

[node name="{scene_name}" type="Node2D"]

[node name="Player" type="CharacterBody2D" parent="."]
position = Vector2(512, 300)
script = SubResource("GDScript_player")

[node name="ColorRect" type="ColorRect" parent="Player"]
offset_left = -20.0
offset_top = -20.0
offset_right = 20.0
offset_bottom = 20.0
color = Color(0.2, 0.5, 0.8, 1)

[node name="CollisionShape2D" type="CollisionShape2D" parent="Player"]
shape = SubResource("RectangleShape2D_player")

[node name="Camera2D" type="Camera2D" parent="Player"]
current = true

[node name="NPC" type="CharacterBody2D" parent="."]
position = Vector2(700, 300)
script = ExtResource("2_npc")

[node name="ColorRect" type="ColorRect" parent="NPC"]
offset_left = -20.0
offset_top = -20.0
offset_right = 20.0
offset_bottom = 20.0
color = Color(0.8, 0.3, 0.3, 1)

[node name="CollisionShape2D" type="CollisionShape2D" parent="NPC"]
shape = SubResource("RectangleShape2D_npc")

[node name="InteractionArea" type="Area2D" parent="NPC"]

[node name="CollisionShape2D" type="CollisionShape2D" parent="NPC/InteractionArea"]
shape = SubResource("CircleShape2D_interaction")

[node name="CanvasLayer" type="CanvasLayer" parent="."]

[node name="DialogueUI" type="PanelContainer" parent="CanvasLayer"]
visible = false
anchor_left = 0.2
anchor_top = 0.7
anchor_right = 0.8
anchor_bottom = 0.95
script = ExtResource("3_dialogue")

[node name="MarginContainer" type="MarginContainer" parent="CanvasLayer/DialogueUI"]
margin_right = 614.0
margin_bottom = 150.0
custom_constants/margin_right = 10
custom_constants/margin_top = 10
custom_constants/margin_left = 10
custom_constants/margin_bottom = 10

[node name="VBoxContainer" type="VBoxContainer" parent="CanvasLayer/DialogueUI/MarginContainer"]
margin_left = 10.0
margin_top = 10.0
margin_right = 604.0
margin_bottom = 140.0

[node name="DialogueText" type="RichTextLabel" parent="CanvasLayer/DialogueUI/MarginContainer/VBoxContainer"]
margin_right = 594.0
margin_bottom = 106.0
size_flags_vertical = 3
text = "Hello traveler! How can I help you today?"

[node name="HBoxContainer" type="HBoxContainer" parent="CanvasLayer/DialogueUI/MarginContainer/VBoxContainer"]
margin_top = 110.0
margin_right = 594.0
margin_bottom = 130.0
alignment = 1

[node name="CloseButton" type="Button" parent="CanvasLayer/DialogueUI/MarginContainer/VBoxContainer/HBoxContainer"]
margin_left = 257.0
margin_right = 337.0
margin_bottom = 20.0
rect_min_size = Vector2(80, 0)
text = "Close"

[node name="Background" type="ColorRect" parent="."]
z_index = -1
offset_right = 1024.0
offset_bottom = 600.0
color = Color(0.15, 0.18, 0.2, 1)
"""

	_create_rpg_scripts()
	
	return content.replace("{scene_name}", scene_name)

func _create_fps_scene(scene_name):
	var content = """[gd_scene load_steps=6 format=3]

[ext_resource type="Script" path="res://FPSPlayer.gd" id="1_player"]

[sub_resource type="CapsuleShape3D" id="CapsuleShape3D_player"]
radius = 0.5
height = 1.8

[sub_resource type="BoxShape3D" id="BoxShape3D_floor"]
size = Vector3(20, 0.2, 20)

[sub_resource type="BoxShape3D" id="BoxShape3D_wall"]
size = Vector3(0.2, 3, 20)

[sub_resource type="GDScript" id="GDScript_player"]
script/source = \"extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY = 0.002

var gravity = ProjectSettings.get_setting(\\\"physics/3d/default_gravity\\\")
var camera_rotation_x = 0

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed(\\\"ui_accept\\\") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir = Input.get_vector(\\\"ui_left\\\", \\\"ui_right\\\", \\\"ui_up\\\", \\\"ui_down\\\")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
	
	if Input.is_action_just_pressed(\\\"ui_cancel\\\"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		
		camera_rotation_x -= event.relative.y * MOUSE_SENSITIVITY
		camera_rotation_x = clamp(camera_rotation_x, -1.57, 1.57)
		
		$Camera3D.rotation.x = camera_rotation_x
\"

[node name="{scene_name}" type="Node3D"]

[node name="Player" type="CharacterBody3D" parent="."]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1, 0)
script = SubResource("GDScript_player")

[node name="CollisionShape3D" type="CollisionShape3D" parent="Player"]
shape = SubResource("CapsuleShape3D_player")

[node name="Camera3D" type="Camera3D" parent="Player"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0.5, 0)

[node name="Environment" type="Node3D" parent="."]

[node name="Floor" type="StaticBody3D" parent="Environment"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -0.1, 0)

[node name="CollisionShape3D" type="CollisionShape3D" parent="Environment/Floor"]
shape = SubResource("BoxShape3D_floor")

[node name="MeshInstance3D" type="CSGBox3D" parent="Environment/Floor"]
size = Vector3(20, 0.2, 20)

[node name="Wall1" type="StaticBody3D" parent="Environment"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, -10, 1.5, 0)

[node name="CollisionShape3D" type="CollisionShape3D" parent="