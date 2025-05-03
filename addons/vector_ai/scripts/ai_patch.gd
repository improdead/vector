@tool
extends EditorPlugin

# This script provides a tool menu item for applying AI patches to scenes
# It uses the UndoRedo system to make changes undoable

var undo_redo = null
var json_command_processor = null

func _enter_tree():
	# Get the UndoRedo object
	undo_redo = get_undo_redo()

	# Add a tool menu item
	add_tool_menu_item("Vector AI ► Apply Patch", self, "_on_apply_patch_menu_item")

	# Initialize the JSON command processor
	json_command_processor = load("res://addons/vector_ai/scripts/json_command_processor.gd").new()
	add_child(json_command_processor)

func _exit_tree():
	# Remove the tool menu item
	remove_tool_menu_item("Vector AI ► Apply Patch")

	# Clean up
	if json_command_processor:
		json_command_processor.queue_free()

func _on_apply_patch_menu_item():
	# Get the current scene root
	var current_scene = get_editor_interface().get_edited_scene_root()
	if not current_scene:
		push_error("No scene is currently open in the editor.")
		return

	# Show a dialog to enter JSON commands
	var dialog = AcceptDialog.new()
	dialog.title = "Vector AI - Apply Patch"
	dialog.size = Vector2(800, 600)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialog.add_child(vbox)

	var label = Label.new()
	label.text = "Enter JSON commands to apply to the current scene:"
	vbox.add_child(label)

	var text_edit = TextEdit.new()
	text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_edit.syntax_highlighter = _create_json_syntax_highlighter()
	text_edit.text = _get_example_json_command()
	vbox.add_child(text_edit)

	var apply_button = Button.new()
	apply_button.text = "Apply Patch"
	apply_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	vbox.add_child(apply_button)

	# Connect the apply button
	apply_button.pressed.connect(_on_apply_patch_button_pressed.bind(dialog, text_edit))

	# Show the dialog
	get_editor_interface().get_base_control().add_child(dialog)
	dialog.popup_centered()

func _on_apply_patch_button_pressed(dialog, text_edit):
	var json_string = text_edit.text

	# Process the JSON commands
	var result = json_command_processor.process_json_commands(json_string)

	if result.success:
		# Show a success message
		var success_dialog = AcceptDialog.new()
		success_dialog.title = "Vector AI - Patch Applied"
		success_dialog.dialog_text = "Successfully applied patch to the scene."
		get_editor_interface().get_base_control().add_child(success_dialog)
		success_dialog.popup_centered()

		# Close the patch dialog
		dialog.queue_free()
	else:
		# Show an error message
		var error_dialog = AcceptDialog.new()
		error_dialog.title = "Vector AI - Error"
		error_dialog.dialog_text = "Error applying patch: " + result.error
		get_editor_interface().get_base_control().add_child(error_dialog)
		error_dialog.popup_centered()

# Create a JSON syntax highlighter
func _create_json_syntax_highlighter():
	var syntax_highlighter = SyntaxHighlighter.new()
	# In a real implementation, we would configure the syntax highlighter
	# But for now, we'll just return a basic one
	return syntax_highlighter

# Get an example JSON command
func _get_example_json_command():
	return """[
	{
		"action": "ADD_NODE",
		"scene_path": "res://main.tscn",
		"parent_path": ".",
		"node_type": "Sprite2D",
		"node_name": "Player",
		"properties": {
			"position": "Vector2(100, 100)",
			"texture": "res://icon.png"
		}
	}
]"""
