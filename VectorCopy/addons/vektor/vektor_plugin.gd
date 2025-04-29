@tool
extends EditorPlugin

const VectorSidebar = preload("res://addons/vektor/scenes/vektor_sidebar.tscn")
var sidebar_instance

func _enter_tree():
	print("Loading Vector sidebar...")

	# Initialize the sidebar
	sidebar_instance = VectorSidebar.instantiate()

	# Add the sidebar to the editor - using RIGHT side
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, sidebar_instance)

	# Register keyboard shortcut (Ctrl+L)
	var shortcut = Shortcut.new()
	var input_event = InputEventKey.new()
	input_event.keycode = KEY_L
	input_event.ctrl_pressed = true
	shortcut.events = [input_event]

	# Add a button with different text
	var button = Button.new()
	button.text = "Vector"
	button.tooltip_text = "Open Vector Sidebar (Ctrl+L)"
	button.shortcut = shortcut
	button.pressed.connect(_on_vector_button_pressed)
	add_control_to_container(CONTAINER_INSPECTOR_BOTTOM, button)

	print("Vector sidebar initialized!")

func _exit_tree():
	# Clean up the sidebar
	if sidebar_instance:
		remove_control_from_docks(sidebar_instance)
		sidebar_instance.queue_free()

func _on_vector_button_pressed():
	# Make the sidebar visible
	if sidebar_instance:
		sidebar_instance.visible = true
