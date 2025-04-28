@tool
extends EditorPlugin

const VectorAISidebar = preload("res://addons/vector_ai/scenes/sidebar.tscn")
var sidebar_instance

func _enter_tree():
	# Initialize the sidebar
	sidebar_instance = VectorAISidebar.instantiate()
	
	# Add the sidebar to the editor
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, sidebar_instance)
	
	# Register keyboard shortcut (Ctrl+L)
	var shortcut = Shortcut.new()
	var input_event = InputEventKey.new()
	input_event.keycode = KEY_L
	input_event.ctrl_pressed = true
	shortcut.events = [input_event]
	
	# Add a button next to the inspector
	var button = Button.new()
	button.text = "Vector AI"
	button.tooltip_text = "Open Vector AI Sidebar (Ctrl+L)"
	button.shortcut = shortcut
	button.pressed.connect(_on_vector_ai_button_pressed)
	add_control_to_container(CONTAINER_INSPECTOR_BOTTOM, button)

func _exit_tree():
	# Clean up the sidebar
	if sidebar_instance:
		remove_control_from_docks(sidebar_instance)
		sidebar_instance.queue_free()

func _on_vector_ai_button_pressed():
	# Make the sidebar visible
	if sidebar_instance:
		sidebar_instance.visible = true
