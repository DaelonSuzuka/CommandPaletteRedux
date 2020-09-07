tool
extends EditorPlugin


var command_palette_popup : WindowDialog


func _enter_tree() -> void:
	connect("resource_saved", self, "_on_resource_saved")
	_init_palette()


func _exit_tree() -> void:
	_cleanup_palette()


func _on_resource_saved(resource : Resource) -> void:
	# reload "plugin" if you save it. Doesn't work for changes made in the inspector
	var rname = resource.resource_path.get_file()
	if rname.begins_with("CommandPalette"):
		_cleanup_palette()
		_init_palette()


func _init_palette() -> void:
	command_palette_popup = load("res://addons/CommandPalettePopup/CommandPalettePopup.tscn").instance()
	command_palette_popup.INTERFACE = get_editor_interface()
	command_palette_popup.BASE_CONTROL_VBOX = get_editor_interface().get_base_control().get_child(1)
	command_palette_popup.EDITOR = get_editor_interface().get_script_editor()
	command_palette_popup.FILE_SYSTEM = get_editor_interface().get_resource_filesystem()
	command_palette_popup.EDITOR_SETTINGS = get_editor_interface().get_editor_settings()
	command_palette_popup.SCRIPT_PANEL = get_editor_interface().get_script_editor().get_child(0).get_child(1).get_child(0)
	command_palette_popup.SCRIPT_LIST = get_editor_interface().get_script_editor().get_child(0).get_child(1).get_child(0).get_child(0).get_child(1)
	add_control_to_container(EditorPlugin.CONTAINER_TOOLBAR, command_palette_popup)
	
	connect("main_screen_changed", command_palette_popup, "_on_main_screen_changed")
	connect("scene_changed", command_palette_popup, "_on_scene_changed")
	get_editor_interface().get_resource_filesystem().connect("filesystem_changed", command_palette_popup, "_on_filesystem_changed")
	get_editor_interface().get_script_editor().get_child(0).get_child(1).get_child(1).connect("tab_changed", command_palette_popup, "_on_script_tab_changed")
	get_editor_interface().get_editor_settings().connect("settings_changed", command_palette_popup, "_update_editor_settings")
	
	yield(get_tree().create_timer(0.2), "timeout")
	command_palette_popup._update_editor_settings()
	command_palette_popup._update_files_dictionary(get_editor_interface().get_resource_filesystem().get_filesystem())
	if command_palette_popup.palette_settings.hide_script_panel_button.pressed:
		command_palette_popup.SCRIPT_PANEL.hide() 


func _cleanup_palette() -> void:
	remove_control_from_container(EditorPlugin.CONTAINER_TOOLBAR, command_palette_popup)
	command_palette_popup.queue_free()
