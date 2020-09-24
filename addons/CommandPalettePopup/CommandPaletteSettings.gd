tool
extends WindowDialog


onready var hide_script_panel_button = $MarginContainer/VBoxContainer/SettingsVB/HideScriptPanelOnStart
onready var include_help_pages_button = $MarginContainer/VBoxContainer/SettingsVB/IncludeHelpPages
onready var adaptive_height_button = $MarginContainer/VBoxContainer/SettingsVB/AdaptiveHeight
onready var show_path_for_recent_button = $MarginContainer/VBoxContainer/SettingsVB/ShowPathForRecentFiles
onready var keyboard_shortcut_LineEdit = $MarginContainer/VBoxContainer/SettingsVB/KeyboardShortcut/LineEdit
onready var width_SpinBox = $MarginContainer/VBoxContainer/SettingsVB/WindowWidth/SpinBox
onready var max_height_SpinBox = $MarginContainer/VBoxContainer/SettingsVB/WindowMaxHeight/SpinBox
onready var keyword_goto_line_LineEdit = $MarginContainer/VBoxContainer/SettingsVB/KeywordGotoLine/LineEdit
onready var keyword_goto_method_LineEdit = $MarginContainer/VBoxContainer/SettingsVB/KeywordGotoMethod/LineEdit
onready var keyword_all_files_LineEdit = $MarginContainer/VBoxContainer/SettingsVB/KeywordAllFiles/LineEdit
onready var keyword_all_scenes_LineEdit = $MarginContainer/VBoxContainer/SettingsVB/KeywordAllScenes/LineEdit
onready var keyword_all_scripts_LineEdit = $MarginContainer/VBoxContainer/SettingsVB/KeywordAllScripts/LineEdit
onready var keyword_all_open_scenes_LineEdit = $MarginContainer/VBoxContainer/SettingsVB/KeywordOpenScenes/LineEdit
onready var keyword_editor_settings_LineEdit = $MarginContainer/VBoxContainer/SettingsVB/KeywordSettings/LineEdit
onready var keyword_folder_tree_LineEdit = $MarginContainer/VBoxContainer/SettingsVB/KeywordFileTree/LineEdit
onready var keyword_texteditor_plugin_LineEdit = $MarginContainer/VBoxContainer/SettingsVB/KeywordTexteditorPlugin/LineEdit
onready var keyword_todo_plugin_LineEdit = $MarginContainer/VBoxContainer/SettingsVB/KeywordTODOPlugin/LineEdit
onready var cancel_button := $MarginContainer/VBoxContainer/ButtonsHB/CancelButton
onready var save_button := $MarginContainer/VBoxContainer/ButtonsHB/SaveButton
onready var defaults_button := $MarginContainer/VBoxContainer/ButtonsHB/DefaultsButton
onready var shortcut_edit_button := $MarginContainer/VBoxContainer/SettingsVB/KeyboardShortcut/EditButton
onready var shortcut_file_dialog := $EnterShortcutPopup
onready var shortcut_dialog_label := $EnterShortcutPopup/MarginContainer/ShortcutLabel
onready var focus_scenedock := $MarginContainer/VBoxContainer/SettingsVB/FocusScene/LineEdit
onready var focus_inspectordock := $MarginContainer/VBoxContainer/SettingsVB/FocusInspector/LineEdit
onready var focus_nodedock := $MarginContainer/VBoxContainer/SettingsVB/FocusNode/LineEdit
onready var focus_filesystemdock := $MarginContainer/VBoxContainer/SettingsVB/FocusFileSystem/LineEdit
onready var focus_importdock := $MarginContainer/VBoxContainer/SettingsVB/FocusImport/LineEdit
onready var focus_scripteditor := $MarginContainer/VBoxContainer/SettingsVB/FocusScriptEditor/LineEdit
onready var scenedock_editbutton := $MarginContainer/VBoxContainer/SettingsVB/FocusScene/EditButton2
onready var inspector_editbutton := $MarginContainer/VBoxContainer/SettingsVB/FocusInspector/EditButton3
onready var node_editbutton := $MarginContainer/VBoxContainer/SettingsVB/FocusNode/EditButton4
onready var filesystem_editbutton := $MarginContainer/VBoxContainer/SettingsVB/FocusFileSystem/EditButton5
onready var import_editbutton := $MarginContainer/VBoxContainer/SettingsVB/FocusImport/EditButton6
onready var scripteditor_editbutton := $MarginContainer/VBoxContainer/SettingsVB/FocusScriptEditor/EditButton7
onready var moveup_editbutton := $MarginContainer/VBoxContainer/SettingsVB/MoveNodeUp/EditButton8
onready var movedown_editbutton := $MarginContainer/VBoxContainer/SettingsVB/MoveNodeDown/EditButton9
onready var context_editbutton := $MarginContainer/VBoxContainer/SettingsVB/ContextMenu/EditButton10
onready var moveup_lineedit := $MarginContainer/VBoxContainer/SettingsVB/MoveNodeUp/LineEdit
onready var movedown_lineedit := $MarginContainer/VBoxContainer/SettingsVB/MoveNodeDown/LineEdit
onready var prevscene_lineedit := $MarginContainer/VBoxContainer/SettingsVB/PrevScene/LineEdit
onready var nextscene_lineedit := $MarginContainer/VBoxContainer/SettingsVB/NextScene/LineEdit
onready var prevscene_editbutton := $MarginContainer/VBoxContainer/SettingsVB/PrevScene/EditButton11
onready var nextscene_editbutton := $MarginContainer/VBoxContainer/SettingsVB/NextScene/EditButton12
onready var context_lineedit := $MarginContainer/VBoxContainer/SettingsVB/ContextMenu/LineEdit
onready var keyword_commands_LineEdit := $MarginContainer/VBoxContainer/SettingsVB/KeywordCommandMenu/LineEdit
var currently_edited_shortcut # edit button for setting the key shortcuts


func _ready() -> void:
	load_settings()
	save_button.icon = get_icon("Save", "EditorIcons")
	cancel_button.icon = get_icon("Close", "EditorIcons")
	defaults_button.icon = get_icon("Reload", "EditorIcons")
	shortcut_file_dialog.connect("hide", self, "_on_EnterShortcutPopup_popup_hide") # connection via GUI didn't work
	shortcut_file_dialog.connect("modal_closed", self, "_on_EnterShortcutPopup_popup_hide") # connection via GUI didn't work
	
	for button in [shortcut_edit_button, scenedock_editbutton, inspector_editbutton, node_editbutton, filesystem_editbutton, \
			import_editbutton, scripteditor_editbutton, moveup_editbutton, movedown_editbutton, context_editbutton, prevscene_editbutton, nextscene_editbutton]:
		button.connect("pressed", self, "_on_ShotcutEditButton_pressed", [button])
		button.icon = get_icon("Edit", "EditorIcons")


func _unhandled_key_input(event: InputEventKey) -> void:
	if visible:
		if event.scancode == KEY_ESCAPE and event.pressed:
			if not cancel_button.has_focus():
				cancel_button.grab_focus()
			else:
				hide()
		
		# Settings page: recording keyboard input on release for shortcut setting.
		elif shortcut_file_dialog.visible and not event.pressed:
			if currently_edited_shortcut == shortcut_edit_button:
				keyboard_shortcut_LineEdit.text = event.as_text()
			else:
				var key_combo : String = event.as_text()
				if key_combo.find("Control") != -1:
					# Control is automatically added in CommandPalettePopup.gd
					key_combo.erase(0, 8) # erase "Control+"
				currently_edited_shortcut.get_parent().get_node("LineEdit").text = key_combo
			shortcut_file_dialog.hide()
		
		get_tree().set_input_as_handled()


func _on_CommandPaletteSettings_about_to_show() -> void:
	hide_script_panel_button.call_deferred("grab_focus")


func _on_SaveButton_pressed() -> void:
	save_settings()
	owner._update_popup_list()
	hide()


func _on_DefaultsButton_pressed() -> void:
	load_default_settings()


func _on_CancelButton_pressed() -> void:
	hide()


func _on_CommandPaletteSettings_popup_hide() -> void:
	load_settings()
	get_parent().filter.grab_focus()


func _on_ShotcutEditButton_pressed(button) -> void: # shortcut editor button
	if button.icon == get_icon("Edit", "EditorIcons"):
		currently_edited_shortcut = button
		button.set_deferred("icon", get_icon("DebugSkipBreakpointsOff", "EditorIcons"))
		var size = Vector2(300, 100)
		shortcut_file_dialog.rect_size = size
		shortcut_file_dialog.rect_global_position = OS.get_screen_size() / 2 - size / 2
		get_focus_owner().release_focus()
		shortcut_file_dialog.call_deferred("show_modal")


func _on_EnterShortcutPopup_popup_hide() -> void: 
	currently_edited_shortcut.icon = get_icon("Edit", "EditorIcons")
	currently_edited_shortcut.grab_focus()


func load_settings() -> void:
	var config = ConfigFile.new()
	var error = config.load("user://command_palette_settings.cfg")
	
	if error == ERR_FILE_NOT_FOUND:
		load_default_settings()
		save_settings()
	
	elif error == OK:
		width_SpinBox.value = config.get_value("Settings", "width") as int
		max_height_SpinBox.value = config.get_value("Settings", "max_height") as int
		keyboard_shortcut_LineEdit.text = config.get_value("Settings", "keyboard_shortcut")
		keyword_goto_line_LineEdit.text = config.get_value("Settings", "goto_line")
		keyword_goto_method_LineEdit.text = config.get_value("Settings", "goto_method")
		keyword_all_files_LineEdit.text = config.get_value("Settings", "keyword_all_files")
		keyword_all_scenes_LineEdit.text = config.get_value("Settings", "keyword_all_scenes")
		keyword_all_scripts_LineEdit.text = config.get_value("Settings", "keyword_all_scripts")
		keyword_all_open_scenes_LineEdit.text = config.get_value("Settings", "keyword_all_open_scenes")
		keyword_editor_settings_LineEdit.text = config.get_value("Settings", "keyword_editor_settings")
		keyword_folder_tree_LineEdit.text = config.get_value("Settings", "keyword_folder_tree")
		keyword_texteditor_plugin_LineEdit.text = config.get_value("Settings", "keyword_texteditor_plugin")
		keyword_todo_plugin_LineEdit.text = config.get_value("Settings", "keyword_todo_plugin")
		hide_script_panel_button.pressed = bool(config.get_value("Settings", "hide_script_panel"))
		include_help_pages_button.pressed = bool(config.get_value("Settings", "include_help_pages"))
		adaptive_height_button.pressed = bool(config.get_value("Settings", "adaptive_height"))
		show_path_for_recent_button.pressed = bool(config.get_value("Settings", "show_path_for_recent"))
		
		focus_scenedock.text = config.get_value("Settings", "focus_scene", "S")
		focus_inspectordock.text = config.get_value("Settings", "focus_inspector", "R")
		focus_nodedock.text = config.get_value("Settings", "focus_node", "N")
		focus_filesystemdock.text = config.get_value("Settings", "focus_filesystem", "F")
		focus_importdock.text = config.get_value("Settings", "focus_import", "I")
		focus_scripteditor.text = config.get_value("Settings", "focus_scripteditor", "Space")
		
		moveup_lineedit.text = config.get_value("Settings", "movenodeselectionup", "Up")
		movedown_lineedit.text = config.get_value("Settings", "movenodeselectiondown", "Down")
		context_lineedit.text = config.get_value("Settings", "contextmenu", "C")
		keyword_commands_LineEdit.text = config.get_value("Settings", "commands", ">")
		prevscene_lineedit.text = config.get_value("Settings", "prevscene", "Left")
		nextscene_lineedit.text = config.get_value("Settings", "nextscene", "Right")


func load_default_settings() -> void:
	width_SpinBox.value = clamp(1000, 0, OS.get_screen_size().x * 0.9) as int
	max_height_SpinBox.value = clamp(OS.get_screen_size().y / 2 + 200, 0, OS.get_screen_size().y * 0.9) as int
	keyboard_shortcut_LineEdit.text = "Command+P" if OS.get_name() == "OSX" else "Control+E"
	keyword_goto_line_LineEdit.text = "g "
	keyword_goto_method_LineEdit.text = "m "
	keyword_all_files_LineEdit.text = "a "
	keyword_all_scenes_LineEdit.text = "as "
	keyword_all_scripts_LineEdit.text = "ac "
	keyword_all_open_scenes_LineEdit.text = "s "
	keyword_editor_settings_LineEdit.text = "set "
	keyword_folder_tree_LineEdit.text = "res"
	keyword_texteditor_plugin_LineEdit.text = "f "
	keyword_todo_plugin_LineEdit.text = "td "
	hide_script_panel_button.pressed = false
	include_help_pages_button.pressed = false
	adaptive_height_button.pressed = true
	show_path_for_recent_button.pressed = false
	
	focus_scenedock.text = "S"
	focus_inspectordock.text = "R"
	focus_nodedock.text = "N"
	focus_filesystemdock.text = "F"
	focus_importdock.text = "I"
	focus_scripteditor.text = "Space"
	
	moveup_lineedit.text = "Up"
	movedown_lineedit.text = "Down"
	context_lineedit.text = "C"
	keyword_commands_LineEdit.text = ">"
	prevscene_lineedit.text = "Left"
	nextscene_lineedit.text = "Right"


func save_settings() -> void:
	var config = ConfigFile.new()
	config.set_value("Settings", "width", width_SpinBox.value)
	config.set_value("Settings", "max_height", max_height_SpinBox.value)
	config.set_value("Settings", "keyboard_shortcut", keyboard_shortcut_LineEdit.text)
	config.set_value("Settings", "goto_line", keyword_goto_line_LineEdit.text)
	config.set_value("Settings", "goto_method", keyword_goto_method_LineEdit.text)
	config.set_value("Settings", "keyword_all_files", keyword_all_files_LineEdit.text)
	config.set_value("Settings", "keyword_all_scenes", keyword_all_scenes_LineEdit.text)
	config.set_value("Settings", "keyword_all_scripts", keyword_all_scripts_LineEdit.text)
	config.set_value("Settings", "keyword_all_open_scenes", keyword_all_open_scenes_LineEdit.text)
	config.set_value("Settings", "keyword_editor_settings", keyword_editor_settings_LineEdit.text)
	config.set_value("Settings", "keyword_folder_tree", keyword_folder_tree_LineEdit.text)
	config.set_value("Settings", "keyword_texteditor_plugin", keyword_texteditor_plugin_LineEdit.text)
	config.set_value("Settings", "keyword_todo_plugin", keyword_todo_plugin_LineEdit.text)
	config.set_value("Settings", "hide_script_panel", hide_script_panel_button.pressed if hide_script_panel_button.pressed else "")
	config.set_value("Settings", "include_help_pages", include_help_pages_button.pressed if include_help_pages_button.pressed else "")
	config.set_value("Settings", "adaptive_height", adaptive_height_button.pressed if adaptive_height_button.pressed else "")
	config.set_value("Settings", "show_path_for_recent", show_path_for_recent_button.pressed if show_path_for_recent_button.pressed else "")
	
	config.set_value("Settings", "focus_scene", focus_scenedock.text)
	config.set_value("Settings", "focus_inspector", focus_inspectordock.text)
	config.set_value("Settings", "focus_node", focus_nodedock.text)
	config.set_value("Settings", "focus_filesystem", focus_filesystemdock.text)
	config.set_value("Settings", "focus_import", focus_importdock.text)
	config.set_value("Settings", "focus_scripteditor", focus_scripteditor.text)
	
	config.set_value("Settings", "movenodeselectionup", moveup_lineedit.text)
	config.set_value("Settings", "movenodeselectiondown", movedown_lineedit.text)
	config.set_value("Settings", "contextmenu", context_lineedit.text)
	config.set_value("Settings", "commands", keyword_commands_LineEdit.text)
	config.set_value("Settings", "prevscene", prevscene_lineedit.text)
	config.set_value("Settings", "nextscene", nextscene_lineedit.text)
	config.save("user://command_palette_settings.cfg")
