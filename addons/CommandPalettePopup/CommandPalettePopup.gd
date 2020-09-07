tool
extends WindowDialog


onready var settings_adder : WindowDialog = $SettingsAdder
onready var palette_settings : WindowDialog = $CommandPaletteSettings
onready var filter = $PaletteMarginContainer/VBoxContainer/SearchFilter/MarginContainer/Filter
onready var item_list = $PaletteMarginContainer/VBoxContainer/MarginContainer/TabContainer/ItemList
onready var info_box = $PaletteMarginContainer/VBoxContainer/MarginContainer/TabContainer/RightInfoBox
onready var tabs = $PaletteMarginContainer/VBoxContainer/MarginContainer/TabContainer
enum TABS {ITEM_LIST, INFO_BOX}
onready var copy_button = $PaletteMarginContainer/VBoxContainer/SearchFilter/CopyButton
onready var current_label = $PaletteMarginContainer/VBoxContainer/HSplitContainer/CurrentLabel # meta data "Path" saves file path, "Help" saves name of doc pages
onready var last_label = $PaletteMarginContainer/VBoxContainer/HSplitContainer/LastLabel
onready var add_button = $PaletteMarginContainer/VBoxContainer/SearchFilter/AddButton
onready var context_button = $PaletteMarginContainer/VBoxContainer/SearchFilter/ContextButton
onready var switch_button = $PaletteMarginContainer/VBoxContainer/HSplitContainer/SwitchIcon
onready var settings_button = $PaletteMarginContainer/VBoxContainer/SearchFilter/SettingsButton
	
const UTIL = preload("res://addons/CommandPalettePopup/util.gd")
	
var editor_settings : Dictionary # holds all editor settings [path] : {settings_dictionary}
var project_settings : Dictionary # holds all project settings [path] : {settings_dictionary}
var scenes : Dictionary # holds all scenes; [file_path] = {icon}
var scripts : Dictionary # holds all scripts; [file_path] = {icon, resource}
var other_files : Dictionary # holds all other files; [file] = {icon}
var folders : Dictionary # holds all folders [folder_path] = {folder count, file count, folder name, parent name}
var secondary_color : Color = Color(1, 1, 1, .3) # color for 3rd column in ItemList (file paths, additional_info...)
var current_main_screen : String = ""
var script_panel_visible : bool # only updated on context button press
var old_dock_tab : Control # holds the old tab when switching dock for context menu
var old_dock_tab_was_visible : bool
var files_are_updating : bool = false
var recent_files_are_updating : bool  = false
enum FILTER {ALL_FILES, ALL_SCENES, ALL_SCRIPTS, ALL_OPEN_SCENES, ALL_OPEN_SCRIPTS, SETTINGS, GOTO_LINE, GOTO_METHOD, HELP, \
		TREE_FOLDER, FILEEDITOR, TODO}
var current_filter : int
	
var INTERFACE : EditorInterface
var BASE_CONTROL_VBOX : VBoxContainer
var EDITOR : ScriptEditor
var FILE_SYSTEM : EditorFileSystem
var EDITOR_SETTINGS : EditorSettings
var SCRIPT_PANEL : VSplitContainer
var SCRIPT_LIST : ItemList
# 3rd party plugins
var FILELIST : ItemList


func _ready() -> void:
	current_label.add_stylebox_override("normal", get_stylebox("normal", "LineEdit"))
	last_label.add_stylebox_override("normal", get_stylebox("normal", "LineEdit"))
	last_label.add_color_override("font_color", secondary_color)
	last_label.text = ""
	current_label.text = ""
	filter.right_icon = get_icon("Search", "EditorIcons")
	copy_button.icon = get_icon("ActionCopy", "EditorIcons")
	switch_button.icon = get_icon("MirrorX", "EditorIcons")
	context_button.icon = get_icon("FileList", "EditorIcons")
	settings_button.icon = get_icon("Tools", "EditorIcons")


func _unhandled_key_input(event: InputEventKey) -> void:
	var pressed = true if palette_settings.keyboard_shortcut_LineEdit.text.findn("Tab") != -1 else event.pressed # if keyboard shortcut contains tab, you cannot check pressed state
	if pressed and visible and not filter.text and filter.has_focus():
		# focus scene tree dock
		if event.as_text() == "Control+" + palette_settings.focus_scenedock.text:
			yield(get_tree(), "idle_frame") # to prevent saving the script/scene
			hide()
			var scene_dock = UTIL.get_dock("SceneTreeDock", BASE_CONTROL_VBOX)
			switch_vis_dock(scene_dock)
			var filter_lineedit : LineEdit = scene_dock.get_child(0).get_child(2)
			filter_lineedit.grab_focus()
		
		# focus filesystem dock
		elif event.as_text() == "Control+" + palette_settings.focus_filesystemdock.text:
			yield(get_tree(), "idle_frame") # to prevent other shortcut functionalities
			hide()
			var file_dock = UTIL.get_dock("FileSystemDock", BASE_CONTROL_VBOX)
			switch_vis_dock(file_dock)
			var filter_lineedit : LineEdit = file_dock.get_child(0).get_child(1).get_child(0)
			filter_lineedit.grab_focus()
		
		# focus node dock
		elif event.as_text() == "Control+" + palette_settings.focus_nodedock.text:
			yield(get_tree(), "idle_frame") # to prevent other shortcut functionalities
			hide()
			var node_dock = UTIL.get_dock("NodeDock", BASE_CONTROL_VBOX)
			switch_vis_dock(node_dock)
			var signal_button : Button = node_dock.get_child(0).get_child(0)
			signal_button.grab_focus()
		
		# focus inspector dock
		elif event.as_text() == "Control+" + palette_settings.focus_inspectordock.text:
			yield(get_tree(), "idle_frame") # to prevent other shortcut functionalities
			hide()
			var inspector_dock = UTIL.get_dock("InspectorDock", BASE_CONTROL_VBOX)
			switch_vis_dock(inspector_dock)
			var filter_lineedit : LineEdit = inspector_dock.get_child(2)
			filter_lineedit.grab_focus()
		
		# focus import dock
		elif event.as_text() == "Control+" + palette_settings.focus_importdock.text:
			yield(get_tree(), "idle_frame") # to prevent other shortcut functionalities
			hide()
			var import_dock = UTIL.get_dock("ImportDock", BASE_CONTROL_VBOX)
			switch_vis_dock(import_dock)
			var button : OptionButton = import_dock.get_child(2).get_child(0).get_child(0)
			button.grab_focus()
		
		# open script editor (useful if the script editor is already open but not focues)
		elif event.as_text() == "Control+" + palette_settings.focus_scripteditor.text:
			yield(get_tree(), "idle_frame") # to prevent other shortcut functionalities
			hide()
			INTERFACE.set_main_screen_editor("Script")
			UTIL.get_current_script_texteditor(EDITOR).grab_focus()
		
		# switch to last file
		elif event.as_text() == palette_settings.keyboard_shortcut_LineEdit.text:
			_switch_to_recent_file()
	
	# open command palette
	elif event.as_text() == palette_settings.keyboard_shortcut_LineEdit.text and pressed:
		_update_project_settings()
		_update_popup_list(true)


func switch_vis_dock(dock : Node) -> void:
	var tabcontainer : TabContainer = dock.get_parent()
	if tabcontainer.current_tab != dock.get_index():
		tabcontainer.current_tab = dock.get_index()


func _switch_to_recent_file() -> void:
		if last_label.has_meta("Path"):
			if current_main_screen in ["2D", "3D", "Script"]:
				_open_scene(last_label.get_meta("Path")) if scenes.has(last_label.get_meta("Path")) \
						else _open_script(scripts[last_label.get_meta("Path")].ScriptResource)
			else:
				_open_scene(current_label.get_meta("Path")) if scenes.has(current_label.get_meta("Path")) \
						else _open_script(scripts[current_label.get_meta("Path")].ScriptResource)
		
		elif last_label.has_meta("Help"):
			INTERFACE.set_main_screen_editor("Script")
			SCRIPT_LIST.select(last_label.get_meta("Help"), true)
			SCRIPT_LIST.emit_signal("item_selected", last_label.get_meta("Help"))
		
		hide()


func _on_scene_changed(new_root : Node) -> void:
	_update_recent_files()


func _on_script_tab_changed(tab : int) -> void:
	_update_recent_files()


func _on_main_screen_changed(new_screen : String) -> void:
	current_main_screen = new_screen
	_update_recent_files()


func _on_filesystem_changed() -> void:
	# to prevent unnecessarily updating cause the signal gets fired multiple times
	if not files_are_updating:
		files_are_updating = true
		_update_files_dictionary(FILE_SYSTEM.get_filesystem(), true)
		yield(get_tree().create_timer(0.1), "timeout")
		files_are_updating = false


func _on_SwitchIcon_pressed() -> void:
	_switch_to_recent_file()


func _on_CopyButton_pressed() -> void:
	var selection = item_list.get_selected_items()
	if selection:
		if current_filter == FILTER.SETTINGS:
			OS.clipboard = "\"" + item_list.get_item_text(selection[0]) + "\""
		
		elif _current_filter_displays_files():
			var path : String = ""
			if current_filter in [FILTER.ALL_OPEN_SCENES, FILTER.ALL_OPEN_SCRIPTS]:
				path = item_list.get_item_text(selection[0] + 1) + ("/" if not item_list.get_item_text(selection[0] + 1).ends_with("/") else "") \
						+ item_list.get_item_text(selection[0]).strip_edges()
			else:
				path = item_list.get_item_text(selection[0] - 1) + ("/" if not item_list.get_item_text(selection[0] - 1).ends_with("/") else "") \
						+ item_list.get_item_text(selection[0]).strip_edges()
			OS.clipboard = "\"" + path + "\""
		
		elif current_filter == FILTER.TREE_FOLDER:
			var path : String = filter.text.substr(palette_settings.keyword_folder_tree_LineEdit.text.length())
			while path.begins_with("/") or path.begins_with(":"):
				path.erase(0, 1)
			if path.count("/") > 0:
				path = path.rsplit("/", true, 1)[0] + "/"
				path += item_list.get_item_text(selection[0])
			else:
				path = item_list.get_item_text(selection[0])
			OS.clipboard = "\"" + "res://" + path.strip_edges() + "\""
	
	hide()


func _on_AddButton_pressed() -> void:
	if filter.text.begins_with(palette_settings.keyword_editor_settings_LineEdit.text):
		settings_adder._show()


func _on_SettingsButton_pressed() -> void:
	palette_settings.popup_centered(Vector2(1000, 800))


func _on_ContextButton_pressed() -> void:
	var selection = item_list.get_selected_items()
	if selection:
		if current_filter == FILTER.ALL_OPEN_SCRIPTS:
			if current_main_screen != "Script":
				INTERFACE.set_main_screen_editor("Script")
				yield(get_tree(), "idle_frame")
			script_panel_visible = SCRIPT_PANEL.visible
			if not script_panel_visible:
				SCRIPT_PANEL.show()
			
			yield(get_tree().create_timer(.01), "timeout")
			var selected_name = item_list.get_item_text(selection[0])
			var pos = Vector2(15, 5)
			while selected_name != SCRIPT_LIST.get_item_text(SCRIPT_LIST.get_item_at_position(pos)):
				pos.y += 5
				if pos.y > OS.get_screen_size().y:
					push_warning("Command Palette Plugin: Error getting context menu from script list.")
					return
			pos.y += 5
			hide()
			var simul_rmb = InputEventMouseButton.new()
			simul_rmb.button_index = BUTTON_RIGHT
			simul_rmb.pressed = true
			simul_rmb.position = SCRIPT_LIST.rect_global_position + pos
			Input.parse_input_event(simul_rmb)
			for child in EDITOR.get_children():
				if child is PopupMenu:
					child.allow_search = true
					yield(get_tree(), "idle_frame")
					child.call_deferred("set_position", SCRIPT_LIST.rect_global_position + Vector2(SCRIPT_LIST.rect_size.x - 25, pos.y))
					if not child.is_connected("popup_hide", self, "_on_script_context_menu_hide"):
						child.connect("popup_hide", self, "_on_script_context_menu_hide")
					break
		
		elif current_filter in [FILTER.ALL_FILES, FILTER.ALL_SCENES, FILTER.ALL_SCRIPTS, FILTER.TREE_FOLDER]:
			var path : String
			if current_filter == FILTER.TREE_FOLDER:
				path = filter.text.substr(palette_settings.keyword_folder_tree_LineEdit.text.length())
				while path.begins_with("/") or path.begins_with(":"):
					path.erase(0, 1)
				if path.count("/") > 0:
					path = path.rsplit("/", true, 1)[0] + "/"
					path += item_list.get_item_text(selection[0])
				else:
					path = item_list.get_item_text(selection[0])
				path = "res://" + path.strip_edges()
			else:
				path = item_list.get_item_text(selection[0] - 1) + ("/" if not item_list.get_item_text(selection[0] - 1) == "res://" else "") \
						+ item_list.get_item_text(selection[0])
			
			var filesystem_dock = UTIL.get_dock("FileSystemDock", BASE_CONTROL_VBOX)
			var file_tree : Tree
			var file_list : ItemList
			var file_split_view : bool
			for child in filesystem_dock.get_children():
				if child is VSplitContainer:
					file_tree = child.get_child(0)
					file_list = child.get_child(1).get_child(1)
					file_split_view = child.get_child(1).visible
			old_dock_tab = filesystem_dock.get_parent().get_current_tab_control()
			old_dock_tab_was_visible = filesystem_dock.get_parent().visible and filesystem_dock.get_parent().get_parent().visible
			var i = 0
			while filesystem_dock.get_parent().get_current_tab_control() != filesystem_dock:
				filesystem_dock.get_parent().current_tab = i
				i += 1
			INTERFACE.select_file(path)
			if not old_dock_tab_was_visible:
				filesystem_dock.get_parent().show()
				filesystem_dock.get_parent().get_parent().show()
				filesystem_dock.get_parent().get_parent().get_parent().show()
			yield(get_tree().create_timer(.01), "timeout")
			var pos = Vector2(30, 5) # x = 30 so we don't click the folding arrow
			if (file_split_view and current_filter != FILTER.TREE_FOLDER) or (current_filter == FILTER.TREE_FOLDER and not item_list.get_item_icon(selection[0])): # icon => folder
				while path.get_file() != file_list.get_item_text(file_list.get_item_at_position(pos)):
					pos.x = 5
					pos.y += 5
					if pos.y > OS.get_screen_size().y:
						push_warning("Command Palette Plugin: Error getting context menu from FileSystemDock.")
						return
				pos.y += 5
				hide()
				file_list.emit_signal("item_rmb_selected", file_list.get_selected_items()[0], pos)
			
			else:
				while path.get_file() != file_tree.get_item_at_position(pos).get_text(0):
					pos.x = 5
					pos.y += 5
					if pos.y > OS.get_screen_size().y:
						push_warning("Command Palette Plugin: Error getting context menu from FileSystemDock.")
						return
				pos.y += 5
				hide()
				file_tree.emit_signal("item_rmb_selected", pos)
			
			for child in filesystem_dock.get_children():
				if child is PopupMenu:
					child.allow_search = true
					child.call_deferred("set_position", (file_list.rect_global_position if (file_split_view and current_filter != FILTER.TREE_FOLDER) or \
							(current_filter == FILTER.TREE_FOLDER and not item_list.get_item_icon(selection[0])) else \
							file_tree.rect_global_position) + Vector2(0, pos.y + 25))
					if not child.is_connected("popup_hide", self, "_on_node_and_file_context_menu_hide"):
						child.connect("popup_hide", self, "_on_node_and_file_context_menu_hide")
					break


func _on_script_context_menu_hide() -> void:
	if not script_panel_visible:
		SCRIPT_PANEL.hide()


func _on_node_and_file_context_menu_hide() -> void:
	var i = 0
	while old_dock_tab != old_dock_tab.get_parent().get_current_tab_control():
		old_dock_tab.get_parent().current_tab = i
		i += 1
	if not old_dock_tab_was_visible:
		old_dock_tab.get_parent().hide()
		old_dock_tab.get_parent().get_parent().hide()
		if old_dock_tab.get_parent().get_parent().get_parent() != BASE_CONTROL_VBOX.get_child(1).get_child(1): 
			old_dock_tab.get_parent().get_parent().get_parent().hide() 
	old_dock_tab = null


func _on_CommandPalettePopup_popup_hide() -> void:
	filter.clear()


func _on_Filter_text_changed(new_txt : String) -> void:
	# autocompletion; double spaces because one space for jumping in item_list
	if filter.text.ends_with("  "):
		var selection = item_list.get_selected_items()
		if selection:
			if current_filter in [FILTER.ALL_FILES, FILTER.ALL_SCENES, FILTER.ALL_SCRIPTS, FILTER.SETTINGS]:
				var key = ""
				var keywords = [palette_settings.keyword_goto_line_LineEdit.text, palette_settings.keyword_goto_method_LineEdit.text, \
						palette_settings.keyword_all_files_LineEdit.text, palette_settings.keyword_all_scenes_LineEdit.text, \
						palette_settings.keyword_all_scripts_LineEdit.text, palette_settings.keyword_all_open_scenes_LineEdit.text, \
						palette_settings.keyword_editor_settings_LineEdit.text]
				for keyword in keywords:
					if filter.text.begins_with(keyword):
						key = keyword
						break
				var search_string = filter.text.substr(key.length()).strip_edges()
				var path_to_autocomplete : String = ""
				if key in [palette_settings.keyword_all_files_LineEdit.text, palette_settings.keyword_all_scenes_LineEdit.text, \
						palette_settings.keyword_all_scripts_LineEdit.text]:
					path_to_autocomplete = item_list.get_item_text(selection[0] - 1)
				elif key in [palette_settings.keyword_editor_settings_LineEdit.text]:
					path_to_autocomplete = item_list.get_item_text(selection[0])
				var start_pos = max(path_to_autocomplete.findn(search_string), 0)
				var end_pos = path_to_autocomplete.find("/", start_pos + search_string.length()) + 1
				path_to_autocomplete = path_to_autocomplete.substr(0, end_pos if end_pos else -1)
				if path_to_autocomplete == "res:/":
					path_to_autocomplete = "res://"
				filter.text = key + path_to_autocomplete
				filter.caret_position = filter.text.length()
			
			elif current_filter == FILTER.TREE_FOLDER:
				var path = filter.text.substr(palette_settings.keyword_folder_tree_LineEdit.text.length()).strip_edges().rsplit("/", true, 1)[0] \
						+ "/" if filter.text.count("/") > 0 else "://"
				filter.text = palette_settings.keyword_folder_tree_LineEdit.text + path + item_list.get_item_text(selection[0])
				filter.text += "/" if item_list.get_item_icon(selection[0]) else ""
				filter.caret_position = filter.text.length()
	
	_update_popup_list()


func _on_Filter_text_entered(new_txt : String) -> void:
	var selection = item_list.get_selected_items()
	if selection:
		_activate_item(selection[0])
	else:
		_activate_item(-1)


func _on_ItemList_item_activated(index: int) -> void:
	_activate_item(index)


func _activate_item(selected_index : int = -1) -> void:
	if current_filter == FILTER.GOTO_LINE:
		var number = filter.text.substr(palette_settings.keyword_goto_line_LineEdit.text.length()).strip_edges()
		if number.is_valid_integer():
			var max_lines = EDITOR.get_current_script().source_code.count("\n")
			EDITOR.goto_line(clamp(number as int - 1, 0, max_lines))
		selected_index = -1
	
	if selected_index == -1 or item_list.is_item_disabled(selected_index) or item_list.get_item_text(selected_index) == "" \
			or item_list.get_item_custom_fg_color(selected_index) == secondary_color or selected_index % item_list.max_columns == 0:
		hide()
		return
	
	var selected_name = item_list.get_item_text(selected_index).strip_edges()
	
	if current_filter == FILTER.GOTO_METHOD:
		var line = item_list.get_item_text(selected_index + 1).split(":")[1].strip_edges()
		EDITOR.goto_line(line as int - 1)
	
	elif _current_filter_displays_files():
		var path : String = ""
		if current_filter in [FILTER.ALL_OPEN_SCENES, FILTER.ALL_OPEN_SCRIPTS]:
			path = item_list.get_item_text(selected_index + 1) + ("/" if item_list.get_item_text(selected_index + 1) != "res://" else "") \
					+ item_list.get_item_text(selected_index).strip_edges()
		else:
			path = item_list.get_item_text(selected_index - 1) + ("/" if item_list.get_item_text(selected_index - 1) != "res://" else "") \
					+ item_list.get_item_text(selected_index).strip_edges()
		
		if current_filter == FILTER.ALL_OPEN_SCRIPTS and item_list.get_item_metadata(selected_index):
			# open docs
			INTERFACE.set_main_screen_editor("Script")
			EDITOR.get_child(0).get_child(1).get_child(0).get_child(0).get_child(1).select(item_list.get_item_metadata(selected_index), true)
			EDITOR.get_child(0).get_child(1).get_child(0).get_child(0).get_child(1).emit_signal("item_selected", item_list.get_item_metadata(selected_index))
		else:
			_open_selection(path)
	
	elif current_filter == FILTER.SETTINGS:
		var setting_path = Array(selected_name.split("/"))
		var setting_name : String
		if setting_path.size() == 4: # TODO: this may not work for settings the user added
			var tmp = setting_path.pop_back()
			setting_name = setting_path.pop_back() + "/" + tmp
		else:
			setting_name = setting_path.pop_back()
		if item_list.get_item_text(selected_index - 1).findn("Project") != -1:
			_open_settings(setting_path, setting_name, false)
		else:
			_open_settings(setting_path, setting_name)
	
	elif current_filter == FILTER.TREE_FOLDER:
		var path : String = filter.text.substr(palette_settings.keyword_folder_tree_LineEdit.text.length())
		while path.begins_with("/") or path.begins_with(":"):
			path.erase(0, 1)
		path = "res://" + (path.rsplit("/", true, 1)[0] + "/" + selected_name if path.count("/") > 0 else selected_name)
		if item_list.get_item_icon(selected_index):
			INTERFACE.select_file(path)
		else:
			_open_selection(path)
	
	elif current_filter == FILTER.FILEEDITOR:
		INTERFACE.set_main_screen_editor("File")
		for idx in FILELIST.get_item_count():
			if FILELIST.get_item_text(idx) == selected_name:
				FILELIST.select(idx)
				FILELIST.emit_signal("item_selected", FILELIST.get_selected_items()[0])
				FILELIST.get_parent().get_parent().get_child(1).get_child(0).get_child(3).grab_focus()
				break
	
	elif current_filter == FILTER.TODO:
		var todo_dock = UTIL.get_dock("TODO", BASE_CONTROL_VBOX)
		var tree = todo_dock.get_child(1).get_child(0) as Tree
		var file = tree.get_root().get_children()
		while file:
			var todo = file.get_children() as TreeItem
			while todo:
				var todoname = todo.get_text(0)
				if todoname == selected_name:
					todo.select(0)
					tree.emit_signal("item_activated")
					hide()
					return
				todo = todo.get_next()
			file = file.get_next()
	
	else:
		push_warning("Command Palette Plugin: You should not be seeing this message. Please open an issue on Github and tell me what you did to see this.")
	
	hide()


func _open_settings(setting_path : Array, setting_name : String, editor : bool = true) -> void:
	var popup : PopupMenu = BASE_CONTROL_VBOX.get_child(0).get_child(0).get_child(3 if editor else 1).get_child(0)
	yield(get_tree(), "idle_frame") # otherwise windows don't get dimmed
	popup.emit_signal("id_pressed", 59 if editor else 43)
	# settings get pushed to the last pos, if it's opened
	var SETTINGS_DIALOG = INTERFACE.get_base_control().get_child(INTERFACE.get_base_control().get_child_count() - 1) 
	var SETTINGS_TREE : Tree = SETTINGS_DIALOG.get_child(3).get_child(0).get_child(1).get_child(0).get_child(0)
	var SETTINGS_INSPECTOR = SETTINGS_DIALOG.get_child(3).get_child(0).get_child(1).get_child(1).get_child(0)
	SETTINGS_INSPECTOR.follow_focus = true
	var tree_item : TreeItem = SETTINGS_TREE.get_root()
	for i in min(setting_path.size(), 2): # Inspector sections dont count, so only max 2
		tree_item = tree_item.get_children()
		var curr_path = setting_path.pop_front().capitalize()
		while tree_item.get_text(0) != curr_path:
			tree_item = tree_item.get_next()
	tree_item.select(0)
	
	yield(get_tree().create_timer(0.01), "timeout")
	_inspector_property_editor_grab_focus(setting_name, SETTINGS_INSPECTOR.get_child(0))


func _inspector_property_editor_grab_focus(settings_name : String, node : Node = INTERFACE.get_inspector().get_child(0)): # Inpsector dock is default
	if node is EditorProperty:
		if node.get_edited_property() == settings_name:
			# TODO potentially error prone, needs a better way
			while(node.get_child(0) is Container): 
				node = node.get_child(0) 
			for child in node.get_children():
				if child.focus_mode != FOCUS_NONE:
					child.call_deferred("grab_focus")
					return
			push_warning("Command Palette Plugin: Problem grabbing focus of a property/setting. " \
					 + "Please open an issue on Github and tell me the property/setting you tried to set.")
	else:
		for child in node.get_children():
			_inspector_property_editor_grab_focus(settings_name, child)


func _open_selection(path : String) -> void:
	if scripts.has(path):
		_open_script(scripts[path].ScriptResource)
	elif scenes.has(path):
		_open_scene(path)
	else:
		_open_other_file(path)


func _open_script(script : Script) -> void:
	INTERFACE.edit_resource(script)
	
	if script.has_meta("Scene_Path"):
		INTERFACE.open_scene_from_path(script.get_meta("Scene_Path"))
		var selection = INTERFACE.get_selection()
		selection.clear()
		selection.add_node(INTERFACE.get_edited_scene_root()) # to see the "Node" dock in Script view
	yield(get_tree().create_timer(.01), "timeout")
	
	INTERFACE.call_deferred("set_main_screen_editor", "Script")


func _open_scene(path : String) -> void:
	INTERFACE.open_scene_from_path(path)
	
	var selection = INTERFACE.get_selection()
	selection.clear()
	selection.add_node(INTERFACE.get_edited_scene_root()) # to see the "Node" dock in Script view
	INTERFACE.call_deferred("set_main_screen_editor", "3D") if INTERFACE.get_edited_scene_root() is Spatial \
			else INTERFACE.call_deferred("set_main_screen_editor", "2D")


func _open_other_file(path : String) -> void:
	INTERFACE.select_file(path)
	INTERFACE.edit_resource(load(path))


func _update_popup_list(just_popupped : bool = false) -> void:
	if just_popupped:
		rect_size = Vector2(palette_settings.width_SpinBox.value as float, palette_settings.max_height_SpinBox.value as float)
		popup_centered()
		filter.grab_focus()
	
	item_list.clear()
	var search_string : String = filter.text
	
	# typing " X" at the end of the search_string jumps to the X-th item in the list
	var quickselect_line = 0
	var qs_starts_at = search_string.strip_edges().find_last(" ") if not search_string.begins_with(" ") else search_string.find_last(" ")
	if qs_starts_at != -1 and not search_string.begins_with(palette_settings.keyword_goto_line_LineEdit.text):
		quickselect_line = search_string.substr(qs_starts_at)
		if quickselect_line.strip_edges().is_valid_integer():
			search_string.erase(qs_starts_at + 1, search_string.length())
			quickselect_line = quickselect_line.strip_edges()
	
	# help page
	if search_string == "?":
		current_filter = FILTER.HELP
		tabs.current_tab = TABS.INFO_BOX
		_build_help_page()
		_setup_buttons()
		
		return
	
	tabs.current_tab = TABS.ITEM_LIST
	
	# go to line
	if search_string.begins_with(palette_settings.keyword_goto_line_LineEdit.text):
		current_filter = FILTER.GOTO_LINE
		if not current_main_screen == "Script":
			item_list.add_item("Go to \"Script\" view to goto_line.", null, false)
			item_list.set_item_disabled(item_list.get_item_count() - 1, true)
		else:
			var max_lines = EDITOR.get_current_script().source_code.count("\n")
			var number = search_string.substr(palette_settings.keyword_goto_line_LineEdit.text.length()).strip_edges()
			item_list.add_item("Enter a number between 1 and %s." % (max_lines + 1))
			if number.is_valid_integer():
				item_list.set_item_text(item_list.get_item_count() - 1, "Go to line %s of %s." % [clamp(number as int, 1, max_lines + 1), max_lines + 1])
				if search_string.ends_with(" "):
					EDITOR.goto_line(clamp(number as int - 1, 0, max_lines))
	
	# file plugin
	elif search_string.begins_with(palette_settings.keyword_texteditor_plugin_LineEdit.text):
		_set_file_list()
		if FILELIST:
			current_filter = FILTER.FILEEDITOR
			_build_item_list(search_string.substr(palette_settings.keyword_texteditor_plugin_LineEdit.text.length()))
		else:
			push_warning("Command Plugin Palette: TextEditor Integration plugin not installed.")
			return
	
	# todo plugin
	elif search_string.begins_with(palette_settings.keyword_todo_plugin_LineEdit.text):
		var todo_dock = UTIL.get_dock("TODO", BASE_CONTROL_VBOX)
		if todo_dock:
			current_filter = FILTER.TODO
			_build_todo_list(search_string.substr(palette_settings.keyword_todo_plugin_LineEdit.text.length()), todo_dock.get_child(1).get_child(0))
		else:
			push_warning("Command Plugin Palette: ToDo plugin not installed.")
			return
	
	# edit editor settings
	elif search_string.begins_with(palette_settings.keyword_editor_settings_LineEdit.text):
		current_filter = FILTER.SETTINGS
		_build_item_list(search_string.substr(palette_settings.keyword_editor_settings_LineEdit.text.length()))
	
	# folder tree view
	elif search_string.begins_with(palette_settings.keyword_folder_tree_LineEdit.text):
		current_filter = FILTER.TREE_FOLDER
		_build_folder_view(search_string.substr(palette_settings.keyword_folder_tree_LineEdit.text.length()))
	
	# methods of the current script
	elif search_string.begins_with(palette_settings.keyword_goto_method_LineEdit.text):
		current_filter = FILTER.GOTO_METHOD
		if not current_main_screen == "Script":
			item_list.add_item("Go to \"Script\" view to goto_method.", null, false)
			item_list.set_item_disabled(item_list.get_item_count() - 1, true)
		else:
			current_filter = FILTER.GOTO_METHOD
			_build_item_list(search_string.substr(palette_settings.keyword_goto_method_LineEdit.text.length()))
	
	# show all scripts and scenes
	elif search_string.begins_with(palette_settings.keyword_all_files_LineEdit.text):
		current_filter = FILTER.ALL_FILES
		_build_item_list(search_string.substr(palette_settings.keyword_all_files_LineEdit.text.length()))
	
	# show all scripts
	elif search_string.begins_with(palette_settings.keyword_all_scripts_LineEdit.text):
		current_filter = FILTER.ALL_SCRIPTS
		_build_item_list(search_string.substr(palette_settings.keyword_all_scripts_LineEdit.text.length()))
	
	# show all scenes
	elif search_string.begins_with(palette_settings.keyword_all_scenes_LineEdit.text):
		current_filter = FILTER.ALL_SCENES
		_build_item_list(search_string.substr(palette_settings.keyword_all_scenes_LineEdit.text.length()))
	
	# show open scenes
	elif search_string.begins_with(palette_settings.keyword_all_open_scenes_LineEdit.text):
		current_filter = FILTER.ALL_OPEN_SCENES
		_build_item_list(search_string.substr(palette_settings.keyword_all_open_scenes_LineEdit.text.length()))
	
	# show all open scripts
	else:
		current_filter = FILTER.ALL_OPEN_SCRIPTS
		_build_item_list(search_string)
	
	quickselect_line = clamp(quickselect_line as int, 0, item_list.get_item_count() / item_list.max_columns - 1)
	if item_list.get_item_count() >= item_list.max_columns:
		item_list.select(quickselect_line * item_list.max_columns + (1 if current_filter in [FILTER.ALL_OPEN_SCENES, FILTER.ALL_OPEN_SCRIPTS, FILTER.FILEEDITOR, \
				FILTER.GOTO_METHOD, FILTER.TREE_FOLDER] else 2))
		item_list.ensure_current_is_visible()
	
	_adapt_list_height()
	_setup_buttons()


func _build_help_page() -> void:
	rect_size = Vector2(palette_settings.width_SpinBox.value as float, palette_settings.max_height_SpinBox.value as float)
	var file = File.new()
	file.open("res://addons/CommandPalettePopup/Help.txt", File.READ)
	info_box.bbcode_text = file.get_as_text() % [palette_settings.keyword_all_open_scenes_LineEdit.text, palette_settings.keyword_all_files_LineEdit.text, \
			palette_settings.keyword_all_scenes_LineEdit.text, palette_settings.keyword_all_scripts_LineEdit.text, \
			palette_settings.keyword_editor_settings_LineEdit.text, palette_settings.keyword_folder_tree_LineEdit.text, \
			palette_settings.keyword_goto_line_LineEdit.text, palette_settings.keyword_goto_method_LineEdit.text, \
			palette_settings.focus_scenedock.text, palette_settings.focus_inspectordock.text, palette_settings.focus_nodedock.text, \
			palette_settings.focus_filesystemdock.text, palette_settings.focus_importdock.text, palette_settings.focus_scripteditor.text, palette_settings.focus_scenedock.text, \
			palette_settings.keyword_texteditor_plugin_LineEdit.text, palette_settings.keyword_todo_plugin_LineEdit.text]
	file.close()


func _build_item_list(search_string : String) -> void:
	search_string = search_string.strip_edges().replace(" ", "*")
	var name_matched_list : Array # FILE NAME matched search_string; this gets listed first
	var path_matched_list : Array # otherwise there is a match in the file path
	match current_filter:
		FILTER.ALL_FILES:
			for path in scenes:
				if search_string and not path.matchn("*" + search_string + "*") and not search_string.is_subsequence_ofi(path):
					continue
				if search_string and search_string.is_subsequence_ofi(path.get_file()):
					name_matched_list.push_back(path)
				else:
					path_matched_list.push_back(path)
			
			for path in scripts:
				if search_string and not path.matchn("*" + search_string + "*") and not search_string.is_subsequence_ofi(path):
					continue
				if search_string and search_string.is_subsequence_ofi(path.get_file()):
					name_matched_list.push_back(path)
				else:
					path_matched_list.push_back(path)
			
			for path in other_files:
				if search_string and not path.matchn("*" + search_string + "*") and not search_string.is_subsequence_ofi(path):
					continue
				if search_string and search_string.is_subsequence_ofi(path.get_file()):
					name_matched_list.push_back(path)
				else:
					path_matched_list.push_back(path)
		
		FILTER.ALL_SCRIPTS:
			for path in scripts:
				if search_string and not path.matchn("*" + search_string + "*") and not search_string.is_subsequence_ofi(path):
					continue
				if search_string and search_string.is_subsequence_ofi(path.get_file()):
					name_matched_list.push_back(path)
				else:
					path_matched_list.push_back(path)
		
		FILTER.ALL_SCENES:
			for path in scenes:
				if search_string and not path.matchn("*" + search_string + "*") and not search_string.is_subsequence_ofi(path):
					continue
				if search_string and search_string.is_subsequence_ofi(path.get_file()):
					name_matched_list.push_back(path)
				else:
					path_matched_list.push_back(path)
		
		FILTER.ALL_OPEN_SCENES:
			var open_scenes = INTERFACE.get_open_scenes()
			for path in open_scenes:
				if search_string and not path.matchn("*" + search_string + "*") and not search_string.is_subsequence_ofi(path):
					continue
				if search_string and search_string.is_subsequence_ofi(path.get_file()):
					name_matched_list.push_back(path)
				else:
					path_matched_list.push_back(path)
		
		FILTER.ALL_OPEN_SCRIPTS:
			var open_scripts = EDITOR.get_open_scripts()
			for script in open_scripts:
				var path = script.resource_path
				if search_string and not path.matchn("*" + search_string + "*") and not search_string.is_subsequence_ofi(path):
					continue
				if search_string and search_string.is_subsequence_ofi(path.get_file()):
					name_matched_list.push_back(path)
				else:
					path_matched_list.push_back(path)
		
		FILTER.GOTO_METHOD:
			var current_script = EDITOR.get_current_script()
			if current_script: # if not current_script => help page
				var method_dict : Dictionary # maps methods to their line position
				var code_editor : TextEdit = UTIL.get_current_script_texteditor(EDITOR)
				for method in current_script.get_script_method_list():
					if search_string and not search_string.is_subsequence_ofi(method.name) and not method.name.matchn("*" + search_string + "*"):
						continue
					var result = code_editor.search("func " + method.name, 0, 0, 0)
					if result: # get_script_method_list() also lists methods which aren't explicitly coded (like _init and _ready)
						var line = result[TextEdit.SEARCH_RESULT_LINE]
						method_dict[line] = method.name
				var lines = method_dict.keys() # get_script_method_list() doesnt give the path_matched_list in order of appearance in the script
				lines.sort()
				
				var counter = 0
				for line_number in lines:
					item_list.add_item(" " + String(counter) + "  :: ", null, false)
					item_list.add_item(method_dict[line_number])
					item_list.add_item(" : " + String(line_number + 1), null, false)
					item_list.set_item_disabled(item_list.get_item_count() - 1, true)
					counter += 1
				return
		
		FILTER.FILEEDITOR:
			for idx in FILELIST.get_item_count():
				var file = FILELIST.get_item_text(idx)
				if search_string and not file.matchn("*" + search_string + "*") and not search_string.is_subsequence_ofi(file):
					continue
				path_matched_list.push_back(file)
		
		FILTER.SETTINGS:
			for setting in editor_settings:
				if search_string and not setting.matchn("*" + search_string + "*") and not search_string.is_subsequence_ofi(setting):
					continue
				if search_string and search_string.is_subsequence_ofi(setting.get_file()):
					name_matched_list.push_back(setting)
				else:
					path_matched_list.push_back(setting)
			
			for setting in project_settings:
				if search_string and not setting.matchn("*" + search_string + "*") and not search_string.is_subsequence_ofi(setting):
					continue
				if search_string and search_string.is_subsequence_ofi(setting.get_file()):
					name_matched_list.push_back(setting)
				else:
					path_matched_list.push_back(setting)
	
	if _current_filter_displays_files():
		_quick_sort_by_file_name(name_matched_list, 0, name_matched_list.size() - 1) 
		_quick_sort_by_file_name(path_matched_list, 0, path_matched_list.size() - 1) 
	else:
		path_matched_list.sort()
	
	var index = 0
	for idx in name_matched_list.size():
		item_list.add_item(" " + String(index) + "  :: ", null, false)
		if current_filter in [FILTER.ALL_FILES, FILTER.ALL_SCENES, FILTER.ALL_SCRIPTS]:
			item_list.add_item(name_matched_list[idx].get_base_dir())
			item_list.set_item_custom_fg_color(item_list.get_item_count() - 1, secondary_color)
			item_list.add_item(name_matched_list[idx].get_file())
			if scenes.has(name_matched_list[idx]):
				item_list.set_item_icon(item_list.get_item_count() - 1, scenes[name_matched_list[idx]].Icon)
			elif scripts.has(name_matched_list[idx]):
				item_list.set_item_icon(item_list.get_item_count() - 1,  scripts[name_matched_list[idx]].Icon)
			elif other_files.has(name_matched_list[idx]):
				item_list.set_item_icon(item_list.get_item_count() - 1, other_files[name_matched_list[idx]].Icon)
		elif current_filter == FILTER.SETTINGS:
			item_list.add_item("Editor :: " if editor_settings.has(name_matched_list[idx]) else "Project :: ", null, false)
			item_list.set_item_disabled(item_list.get_item_count() - 1, true)
			item_list.add_item(name_matched_list[idx])
		else:
			item_list.add_item(name_matched_list[idx].get_file())
			if scenes.has(name_matched_list[idx]):
				item_list.set_item_icon(item_list.get_item_count() - 1, scenes[name_matched_list[idx]].Icon)
			elif scripts.has(name_matched_list[idx]):
				item_list.set_item_icon(item_list.get_item_count() - 1,  scripts[name_matched_list[idx]].Icon)
			elif other_files.has(name_matched_list[idx]):
				item_list.set_item_icon(item_list.get_item_count() - 1, other_files[name_matched_list[idx]].Icon)
			item_list.add_item(name_matched_list[idx].get_base_dir())
			item_list.set_item_custom_fg_color(item_list.get_item_count() - 1, secondary_color)
		index += 1
	
	for idx in path_matched_list.size():
		item_list.add_item(" " + String(index) + "  :: ", null, false)
		
		if current_filter == FILTER.SETTINGS:
			item_list.add_item("Editor :: " if editor_settings.has(path_matched_list[idx]) else "Project :: ", null, false)
			item_list.set_item_disabled(item_list.get_item_count() - 1, true)
			item_list.add_item(path_matched_list[idx])
		
		elif _current_filter_displays_files():
			if current_filter in [FILTER.ALL_FILES, FILTER.ALL_SCENES, FILTER.ALL_SCRIPTS]:
				item_list.add_item(path_matched_list[idx].get_base_dir())
				item_list.set_item_custom_fg_color(item_list.get_item_count() - 1, secondary_color)
				item_list.add_item(path_matched_list[idx].get_file())
				if scenes.has(path_matched_list[idx]):
					item_list.set_item_icon(item_list.get_item_count() - 1, scenes[path_matched_list[idx]].Icon)
				elif scripts.has(path_matched_list[idx]):
					item_list.set_item_icon(item_list.get_item_count() - 1,  scripts[path_matched_list[idx]].Icon)
				elif other_files.has(path_matched_list[idx]):
					item_list.set_item_icon(item_list.get_item_count() - 1, other_files[path_matched_list[idx]].Icon)
			else:
				item_list.add_item(path_matched_list[idx].get_file())
				if scenes.has(path_matched_list[idx]):
					item_list.set_item_icon(item_list.get_item_count() - 1, scenes[path_matched_list[idx]].Icon)
				elif scripts.has(path_matched_list[idx]):
					item_list.set_item_icon(item_list.get_item_count() - 1,  scripts[path_matched_list[idx]].Icon)
				elif other_files.has(path_matched_list[idx]):
					item_list.set_item_icon(item_list.get_item_count() - 1, other_files[path_matched_list[idx]].Icon)
				item_list.add_item(path_matched_list[idx].get_base_dir())
				item_list.set_item_custom_fg_color(item_list.get_item_count() - 1, secondary_color)
		
		elif current_filter == FILTER.FILEEDITOR:
			item_list.add_item(path_matched_list[idx])
			item_list.add_item("")
		
		index += 1
	
	if palette_settings.include_help_pages_button.pressed and current_filter == FILTER.ALL_OPEN_SCRIPTS:
		for script_index in EDITOR.get_child(0).get_child(1).get_child(0).get_child(0).get_child(1).get_item_count() - EDITOR.get_open_scripts().size():
			if EDITOR.get_child(0).get_child(1).get_child(0).get_child(0).get_child(1).get_item_text(script_index + EDITOR.get_open_scripts().size()).\
					matchn("*" + search_string + "*") or search_string.is_subsequence_ofi(EDITOR.get_child(0).get_child(1).get_child(0).get_child(0).get_child(1).\
					get_item_text(script_index + EDITOR.get_open_scripts().size())):
				item_list.add_item(" " + String(index) + "  :: ", null, false)
				item_list.add_item(EDITOR.get_child(0).get_child(1).get_child(0).get_child(0).get_child(1).get_item_text(script_index \
						+ EDITOR.get_open_scripts().size()), get_icon("Help", "EditorIcons"))
				item_list.set_item_metadata(item_list.get_item_count() - 1, script_index + EDITOR.get_open_scripts().size())
				item_list.add_item("")
				index += 1


func _build_todo_list(search_string : String, todo_dock_tree : Control) -> void:
	var counter = 0
	var file = todo_dock_tree.get_root().get_children()
	while file:
		var todo = file.get_children() as TreeItem
		while todo:
			var todoname = todo.get_text(0)
			if not search_string or todoname.matchn("*" + search_string.strip_edges().replace(" ", "*") + "*") or search_string.is_subsequence_ofi(todoname):
				item_list.add_item(" " + String(counter) + "  :: ", null, false)
				item_list.add_item(file.get_text(0), null, false)
				item_list.set_item_custom_fg_color(item_list.get_item_count() - 1, secondary_color)
				item_list.add_item(todo.get_text(0), todo.get_icon(0))
				counter += 1
			todo = todo.get_next()
		file = file.get_next()
	
	if item_list.get_item_count() == 0:
		item_list.add_item(todo_dock_tree.get_root().get_children().get_text(0)) # Nothing to do in this project/script


# folder view / traversal in tree style
func _build_folder_view(search_string : String) -> void:
	search_string = search_string.strip_edges()
	while search_string.begins_with("/") or search_string.begins_with(":"):
		search_string.erase(0, 1)
	
	var counter = 0
	for folder_path in folders:
		var folder_name = search_string.substr(search_string.get_base_dir().length() + (1 if search_string.count("/") > 0 else 0))
		if ("res://" + search_string.get_base_dir() + ("/" if search_string.count("/") != 0 else "")).to_lower() == folders[folder_path].Parent_Path.to_lower() \
				and folder_name.strip_edges().is_subsequence_ofi(folders[folder_path].Folder_Name):
			item_list.add_item(" " + String(counter) + "  :: ", null, false)
			item_list.add_item(folders[folder_path].Folder_Name, get_icon("Folder", "EditorIcons"))
			if folders[folder_path].Subdir_Count:
				item_list.add_item(" Subdirs: " + String(folders[folder_path].Subdir_Count) + \
						(" + Files: %s" % folders[folder_path].File_Count if folders[folder_path].File_Count else ""), null, false)
			else:
				item_list.add_item((" Files: %s" % folders[folder_path].File_Count) if folders[folder_path].File_Count else "", null, false)
			item_list.set_item_disabled(item_list.get_item_count() - 1, true)
			counter += 1
	
	var list : Array
	for path in scenes:
		if ("res://" + search_string.get_base_dir().to_lower() != path.get_base_dir().to_lower()) or not search_string.get_file().strip_edges().is_subsequence_ofi(path.get_file()):
			continue
		list.push_back(path)
	
	for path in scripts:
		if ("res://" + search_string.get_base_dir().to_lower() != path.get_base_dir().to_lower()) or not search_string.get_file().strip_edges().is_subsequence_ofi(path.get_file()):
			continue
		list.push_back(path)
	
	for path in other_files:
		if ("res://" + search_string.get_base_dir().to_lower() != path.get_base_dir().to_lower()) or not search_string.get_file().strip_edges().is_subsequence_ofi(path.get_file()):
			continue
		list.push_back(path)
	list.sort()
	for file_path in list:
		item_list.add_item(" " + String(counter) + "  :: ", null, false)
		item_list.add_item(file_path.get_file())
		item_list.add_item("", null, false)
		counter += 1


func _adapt_list_height() -> void:
	if palette_settings.adaptive_height_button.pressed:
		var script_icon = get_icon("Script", "EditorIcons")
		var row_height = script_icon.get_size().y + (8)
		var rows = max(item_list.get_item_count() / item_list.max_columns, 1) + 1
		var margin = filter.rect_size.y + $PaletteMarginContainer.margin_top + abs($PaletteMarginContainer.margin_bottom) \
				+ $PaletteMarginContainer/VBoxContainer/MarginContainer.get("custom_constants/margin_top") \
				+ $PaletteMarginContainer/VBoxContainer/MarginContainer.get("custom_constants/margin_bottom") \
				+ max(current_label.rect_size.y, last_label.rect_size.y)
		var height = row_height * rows + margin
		rect_size.y = clamp(height, 0, palette_settings.max_height_SpinBox.value as float)


func _setup_buttons() -> void:
	settings_button.visible = true
	match current_filter:
		FILTER.ALL_FILES, FILTER.ALL_SCENES, FILTER.ALL_SCRIPTS, FILTER.ALL_OPEN_SCENES, FILTER.ALL_OPEN_SCRIPTS, FILTER.TREE_FOLDER:
			copy_button.visible = true
			copy_button.text = "Copy File Path"
			add_button.visible = false
			context_button.visible = true if current_filter != FILTER.ALL_OPEN_SCENES else false
		
		FILTER.SETTINGS:
			copy_button.visible = true
			copy_button.text = "Copy Settings Path"
			if current_filter == FILTER.SETTINGS:
				add_button.visible = true
				add_button.icon = get_icon("MultiEdit", "EditorIcons")
			context_button.visible = false
		FILTER.GOTO_LINE, FILTER.GOTO_METHOD, FILTER.HELP, FILTER.FILEEDITOR, FILTER.TODO:
			for button in [add_button, copy_button, context_button]:
				button.visible = false
	
	if item_list.get_item_count() < item_list.max_columns:
		for button in [add_button, copy_button, context_button]:
			button.visible = false


func _quick_sort_by_file_name(array : Array, lo : int, hi : int) -> void:
	if lo < hi:
		var p = _partition(array, lo, hi)
		_quick_sort_by_file_name(array, lo, p)
		_quick_sort_by_file_name(array, p + 1, hi)
 

func _partition(array : Array, lo : int, hi : int):
	var pivot = array[(hi + lo) / 2].get_file()
	var i = lo - 1
	var j = hi + 1
	while true:
		while true:
			i += 1
			if array[i].get_file().nocasecmp_to(pivot) in [1, 0]:
				break
		while true:
			j -= 1
			if array[j].get_file().nocasecmp_to(pivot) in [-1, 0]:
				break
		if i >= j:
			return j
		var tmp = array[i]
		array[i] = array[j]
		array[j] = tmp


func _current_filter_displays_files() -> bool:
	return current_filter in [FILTER.ALL_FILES, FILTER.ALL_OPEN_SCENES, FILTER.ALL_OPEN_SCRIPTS, FILTER.ALL_SCENES, FILTER.ALL_SCRIPTS]


func _update_files_dictionary(folder : EditorFileSystemDirectory, reset : bool = false) -> void:
	if reset:
		scenes.clear()
		scripts.clear()
		other_files.clear()
		folders.clear()
	
	var script_icon = get_icon("Script", "EditorIcons")
	for file in folder.get_file_count():
		var file_path = folder.get_file_path(file)
		var file_type = FILE_SYSTEM.get_file_type(file_path)
		
		if file_type.find("Script") != -1:
			scripts[file_path] = {"Icon" : script_icon, "ScriptResource" : load(file_path)}
		
		elif file_type.find("Scene") != -1:
			scenes[file_path] = {"Icon" : null}
			
			var scene = load(file_path).instance()
			scenes[file_path].Icon = get_icon(scene.get_class(), "EditorIcons")
			var attached_script = scene.get_script()
			if attached_script:
				attached_script.set_meta("Scene_Path", file_path)
			scene.free()
		
		else:
			other_files[file_path] = {"Icon" : get_icon(file_type, "EditorIcons")}
	
	for subdir in folder.get_subdir_count():
		folders[folder.get_subdir(subdir).get_path()] = {"Subdir_Count" : folder.get_subdir(subdir).get_subdir_count(), \
				"File_Count" : folder.get_subdir(subdir).get_file_count(), "Folder_Name" : folder.get_subdir(subdir).get_name(), \
				"Parent_Path" : (folder.get_subdir(subdir).get_parent().get_path())}
		_update_files_dictionary(folder.get_subdir(subdir))


func _update_recent_files():
	# to prevent unnecessarily updating cause multiple signals call this method (for ex.: changing scripts changes scenes as well)
	if not recent_files_are_updating and current_main_screen in ["2D", "3D", "Script"]:
		recent_files_are_updating = true
		
		yield(get_tree().create_timer(.1), "timeout")
		
		if current_label.has_meta("Path"):
			last_label.text = current_label.text
			last_label.remove_meta("Help")
			last_label.set_meta("Path", current_label.get_meta("Path"))
		elif current_label.has_meta("Help") and palette_settings.include_help_pages_button.pressed:
			last_label.remove_meta("Path")
			last_label.text = current_label.text
			last_label.set_meta("Help", current_label.get_meta("Help"))
		else:
			last_label.text = current_label.text
			last_label.remove_meta("Path")
			last_label.remove_meta("Help")
		
		if current_main_screen == "Script":
			if EDITOR.get_child(0).get_child(1).get_child(0).get_child(0).get_child(1).get_selected_items() and \
					EDITOR.get_child(0).get_child(1).get_child(0).get_child(0).get_child(1).get_selected_items()[0] >= EDITOR.get_open_scripts().size():
				if palette_settings.include_help_pages_button.pressed:
					current_label.text = SCRIPT_LIST.get_item_text(SCRIPT_LIST.get_selected_items()[0])
					current_label.remove_meta("Path")
					current_label.set_meta("Help", SCRIPT_LIST.get_selected_items()[0])
			elif EDITOR.get_current_script():
				var path = EDITOR.get_current_script().resource_path
				current_label.text = path if palette_settings.show_path_for_recent_button.pressed else path.get_file()
				current_label.remove_meta("Help")
				current_label.set_meta("Path", path)
		elif current_main_screen in ["2D", "3D"] and INTERFACE.get_edited_scene_root():
			var path = INTERFACE.get_edited_scene_root().filename
			current_label.text = path if palette_settings.show_path_for_recent_button.pressed else path.get_file()
			current_label.remove_meta("Help")
			current_label.set_meta("Path", path)
		
		recent_files_are_updating = false


func _update_editor_settings() -> void: # only called during startup because editor settings can't be changed via normal means
	for setting in EDITOR_SETTINGS.get_property_list():
		# general settings only
		if setting.name and setting.name.find("/") != -1 and setting.usage & PROPERTY_USAGE_EDITOR and not setting.name.begins_with("favorite_projects/"):
			editor_settings[setting.name] = setting


func _update_project_settings() -> void:
	for setting in ProjectSettings.get_property_list():
		# generalt settings only
		if setting.name and setting.name.find("/") != -1 and setting.usage & PROPERTY_USAGE_EDITOR:
			project_settings[setting.name] = setting


# 3rd party plugin; FileEditor
func _set_file_list() -> void:
	for child in EDITOR.get_parent().get_children():
		if child.name == "FileEditor" and child.get_class() == "Control":
			FILELIST = child.get_child(0).get_child(1).get_child(0).get_child(0)
			return
		FILELIST = null
