tool
extends WindowDialog


onready var path = $MarginContainer/VBoxContainer/PathHB/PathLineEdit
onready var value = $MarginContainer/VBoxContainer/TypeValueHB/ValueLineEdit
onready var type = $MarginContainer/VBoxContainer/TypeValueHB/OptionButton
onready var hint = $MarginContainer/VBoxContainer/HintHintStringHB/OptionButton
onready var hint_string = $MarginContainer/VBoxContainer/HintHintStringHB/HintStringLineEdit
onready var info_label = $MarginContainer/VBoxContainer/InfoLabel
onready var prediction_list = $PredictionList


func _ready() -> void:
	info_label.add_stylebox_override("normal", get_stylebox("normal", "LineEdit"))
	info_label.text = "\"False\"/\"false\" as the value will set the setting to false. Any other non-empty string will set it to true."


func _unhandled_key_input(event: InputEventKey) -> void:
	if visible:
		get_tree().set_input_as_handled()
	


func _show() -> void:
	_update_hints()
	prediction_list.hide()
	popup_centered(Vector2(750, 350))


func _on_AddSetting_about_to_show() -> void:
	type.call_deferred("grab_focus")


func _on_AddSetting_popup_hide() -> void:
	_reset_mask()
	get_parent().filter.grab_focus()


func _reset_mask() -> void:
	path.clear()
	value.clear()
	hint_string.clear()
	hint.select(0)
	type.select(0)
	info_label.text = "\"False\"/\"false\" as the value will set the setting to false. Any other non-empty string will set it to true."


func _on_PathLineEdit_focus_entered() -> void:
	_predict_path()


func _on_PathLineEdit_focus_exited() -> void:
	prediction_list.hide()


func _on_PathLineEdit_text_changed(new_text: String) -> void:
	if new_text.ends_with("  ") and prediction_list.get_item_count() > 0:
		var pos = max(new_text.find_last("/"), 0)
		path.text = new_text.substr(0, pos) + prediction_list.get_item_text(0)
		path.caret_position = path.text.length()
	_predict_path()


func _predict_path() -> void:
	prediction_list.hide()
	prediction_list.clear()
	var search_string : String = path.text.strip_edges()
	var settings = get_parent().project_settings.keys()
	settings.sort()
	var preds = [" "]
	var max_length = 0
	for _path in settings:
		if _path.begins_with(preds[preds.size() - 1]):
			continue
		elif search_string == _path:
			prediction_list.clear()
			break
		elif _path.begins_with(search_string):
			var pos = max(search_string.find_last("/"), 0)
			var end_pos = _path.find("/", pos + 1)
			var prediction = _path.substr(pos, end_pos - pos + 1 if end_pos != -1 else -1)
			preds.push_back(_path.substr(0, end_pos))
			prediction_list.add_item(prediction)
			if max_length < prediction.length():
				max_length = prediction.length()
			prediction_list.show()
			prediction_list.rect_global_position = Vector2(path.rect_global_position.x + path.text.length() * 8, path.rect_global_position.y + path.rect_size.y)
			prediction_list.set_deferred("rect_size", Vector2(max_length * 10, prediction_list.get_item_count() * 15))


func _on_SaveButton_pressed() -> void:
	var property_info = {
	"name": path.text,
	"type": type.get_selected_id(),
	"hint": hint.get_selected_id(),
	"hint_string": hint_string.text
	}
	
	if ProjectSettings.has_setting(path.text):
		push_warning("Command Palette Plugin: The setting you wanted to create already exists.")
		hide()
		return
	
	ProjectSettings.set(path.text, _cast_value(value.text, property_info.type))
	ProjectSettings.set_initial_value(path.text, _cast_value(value.text, property_info.type))
	ProjectSettings.add_property_info(property_info)
	hide()
	get_parent().hide()


func _cast_value(text : String, type : int):
	match type:
		TYPE_BOOL:
			return false if text.strip_edges().matchn("false") or not text else true
		
		TYPE_INT:
			return text as int
		
		TYPE_REAL:
			return text as float
		
		TYPE_STRING:
			return text
		
		TYPE_VECTOR2:
			var a = text.split(" ")
			return Vector2(a[0] as float, a[1] as float)
		
		TYPE_RECT2:
			var a = text.split(" ")
			return Rect2(a[0] as float, a[1] as float, a[2] as float, a[3] as float)
		
		TYPE_VECTOR3:
			var a = text.split(" ")
			return Vector3(a[0] as float, a[1] as float, a[2] as float)
		
		TYPE_TRANSFORM2D:
			var a = text.split(" ")
			var x = Vector2(a[0] as float, a[1] as float)
			var y = Vector2(a[2] as float, a[3] as float)
			var origin = Vector2(a[4] as float, a[5] as float)
			return Transform2D(x, y, origin)
		
		TYPE_PLANE:
			var a = text.split(" ")
			return Plane(a[0] as float, a[1] as float, a[2] as float, a[3] as float)
		
		TYPE_QUAT:
			var a = text.split(" ")
			return Quat(a[0] as float, a[1] as float, a[2] as float, a[3] as float)
		
		TYPE_AABB:
			var a = text.split(" ")
			var pos = Vector3(a[0] as float, a[1] as float, a[2] as float)
			var size = Vector3(a[3] as float, a[4] as float, a[5] as float)
			return AABB(pos, size)
		
		TYPE_BASIS:
			var a = text.split(" ")
			var vec = Vector3(a[0] as float, a[1] as float, a[2] as float)
			return Basis(vec)
		
		TYPE_TRANSFORM:
			var a = text.split(" ")
			var x = Vector3(a[0] as float, a[1] as float, a[2] as float)
			var y = Vector3(a[3] as float, a[4] as float, a[5] as float)
			var z = Vector3(a[6] as float, a[7] as float, a[8] as float)
			var origin = Vector3(a[9] as float, a[10] as float, a[11] as float)
			return Transform(x, y, z, origin)
		
		TYPE_COLOR: 
			return Color(text)
		
		TYPE_NODE_PATH:
			return NodePath(text)
		
		TYPE_DICTIONARY:
			var a = text.split(" ")
			var result : Dictionary
			for pair in a:
				var tmp = pair.split(":")
				result[tmp[0] as float if tmp[0].is_valid_float() else tmp[0]] = tmp[1] as float if tmp[1].is_valid_float() else tmp[1]
			return result
		
		TYPE_ARRAY:
			var a = text.split(" ")
			return Array(a)
		
		TYPE_RAW_ARRAY:
			var a = text.split(" ")
			return PoolByteArray(Array(a))
		
		TYPE_INT_ARRAY:
			var a = text.split(" ")
			return PoolIntArray(Array(a))
		
		TYPE_REAL_ARRAY:
			var a = text.split(" ")
			return PoolRealArray(Array(a))
		
		TYPE_STRING_ARRAY:
			return text.split(" ")
		
		TYPE_VECTOR2_ARRAY:
			var a = Array(text.split(" "))
			var result : PoolVector2Array
			for i in a.size() / 2:
				result.push_back(Vector2(a.pop_front(), a.pop_front()))
			return result
		
		TYPE_VECTOR3_ARRAY:
			var a = Array(text.split(" "))
			var result : PoolVector3Array
			for i in a.size() / 3:
				result.push_back(Vector3(a.pop_front(), a.pop_front(), a.pop_front()))
			return result
		
		TYPE_COLOR_ARRAY:
			return PoolColorArray(Array(text.split(" ")))


func _on_OptionButton_item_selected(id: int) -> void: # type changed
	_update_hints()
	
	match type.get_selected_id():
		TYPE_BOOL:
			info_label.text = "\"False\"/\"false\" as the value will set the setting to false. Any other non-empty string will set it to true."
		
		TYPE_INT, TYPE_REAL, TYPE_STRING, TYPE_NODE_PATH:
			info_label.text = ""
		
		TYPE_VECTOR2:
			info_label.text = "Put the components separated by a space into the Value. Do not put brackets around them. For example: \"3 5\" (without quotes) translates to Vector2(3, 5)."
		
		TYPE_RECT2:
			info_label.text = "Put the x, y, width and height (floats) each separated by space into the Value. For example: \"1 2 3 4\" (without quotes) translates to Rect2(1, 2, 3, 4)."
		
		TYPE_VECTOR3:
			info_label.text = "Put the components separated by a space into the Value. Do not put brackets around them. For example: \"3 5 6\" (without quotes) translates to Vector3(3, 5, 6)."
		
		TYPE_TRANSFORM2D:
			info_label.text = "The Transform2D consists of an x, y and origin (Vector2s).Put the components separated by a space into the Value. Do not put brackets around them. For example: \"1 2 3 4 5 6\" (without quotes) is the Transform2D(Vector2(1, 2), Vector2(3, 4), Vector2(5, 6))."
		
		TYPE_PLANE:
			info_label.text = "The plane is created from the four parameters. The three components of the resulting plane's normal are a, b and c, and the plane has a distance of d from the origin. They need to separated by a space. For example: \"1 2 3 4\" (without quotes) translates to Plane(1, 2, 3, 4)."
		
		TYPE_QUAT:
			info_label.text = "The quaternion is defined by 4 float separated by a space. For example: \"1 2 3 4\" (without quotes) translates to Quat(1, 2, 3, 4)."
		
		TYPE_AABB:
			info_label.text = "\"1 2 3 4 5 6\" (without quotes) translates to AABB(Vector3(1, 2, 3), Vector3(4, 5, 6))."
		
		TYPE_BASIS:
			info_label.text = "\"1 2 3\" (without quotes) translates to Basis(Vector3(1, 2, 3))."
		
		TYPE_TRANSFORM:
			info_label.text = "\"1 2 3 4 5 6 7 8 9\" (without quotes) translates to Transform(Vector3(1, 2, 3), Vector3(4, 5, 6), Vector3(7, 8, 9), Vector3(7, 8, 9))"
		
		TYPE_COLOR: 
			info_label.text = "Converts string to Color. See the Color(from : String) doc."
		
		TYPE_DICTIONARY:
			info_label.text = "Key:value pairs are separated by a space. Don't put brackets around them. For example: \"a:4 b:7\" (without quotes) translates to {\"a\" : 4, \"b\" : 7}."
		
		TYPE_ARRAY:
			info_label.text = "Put the elements separated by a space into the Value. Do not put brackets around them. For example: \"1 2 3 4\" (without quotes) translates to [1, 2, 3, 4]."
		
		TYPE_RAW_ARRAY:
			info_label.text = "Converts an Array to a PoolByteArray. Put the elements separated by a space into the Value. Do not put brackets around them. For example: \"1 2 3 4\" (without quotes) translates to PoolByteArray([1, 2, 3, 4])."
		
		TYPE_INT_ARRAY:
			info_label.text = "Converts an Array to a PoolIntArray. Put the elements separated by a space into the Value. Do not put brackets around them. For example: \"1 2 3 4\" (without quotes) translates to PoolIntArray([1, 2, 3, 4])."
		
		TYPE_REAL_ARRAY:
			info_label.text = "Converts an Array to a PoolRealArray. Put the elements separated by a space into the Value. Do not put brackets around them. For example: \"1 2 3 4\" (without quotes) translates to PoolRealArray([1, 2, 3, 4])."
		
		TYPE_STRING_ARRAY:
			info_label.text = "Converts an Array to a PoolStringArray. Put the elements separated by a space into the Value. Do not put brackets around them. For example: \"1 2 3 4\" (without quotes) translates to PoolStringArray([1, 2, 3, 4])."
		
		TYPE_VECTOR2_ARRAY:
			info_label.text = "Converts an Array of Vector2s to a PoolVector2Array. Put the components separated by a space into the Value. Do not put brackets around them. For example: \"1 2 3 4\" (without quotes) translates to PoolVector2Array([Vector2(1, 2), Vector2(3, 4)])."
		
		TYPE_VECTOR3_ARRAY:
			info_label.text = "Converts an Array of Vector3s to a PoolVector3Array. Put the components separated by a space into the Value. Do not put brackets around them. For example: \"1 2 3 4 5 6\" (without quotes) translates to PoolVector3Array([Vector3(1, 2, 3), Vector3(4, 5, 6)])."
		
		TYPE_COLOR_ARRAY:
			 info_label.text = "Converts an Array of Colors to a PoolColorArray. Put the color codes separated by a space into the Value. Do not put brackets around them. For example: \"#ffb2d90a\" \"#ffb2d90a\" (without quotes) translates to PoolColorArray([Color(\"#ffb2d90a\"), Color(\"#ffb2d90a\")])."


func _update_hints() -> void:
	hint.select(0)
	
	match type.get_selected_id():
		TYPE_INT, TYPE_REAL: 
			for hint_index in hint.get_item_count():
				if hint.get_item_id(hint_index) in [PROPERTY_HINT_RANGE, PROPERTY_HINT_ENUM]:
					hint.set_item_disabled(hint_index, false)
				else:
					hint.set_item_disabled(hint_index, true)
		
		TYPE_STRING:
			for hint_index in hint.get_item_count():
				if hint.get_item_id(hint_index) in [PROPERTY_HINT_ENUM, PROPERTY_HINT_FILE, PROPERTY_HINT_GLOBAL_FILE, PROPERTY_HINT_DIR, PROPERTY_HINT_GLOBAL_DIR, PROPERTY_HINT_MULTILINE_TEXT, PROPERTY_HINT_PLACEHOLDER_TEXT]:
					hint.set_item_disabled(hint_index, false)
				else:
					hint.set_item_disabled(hint_index, true)
		
		TYPE_COLOR: 
			for hint_index in hint.get_item_count():
				if hint.get_item_id(hint_index) in [PROPERTY_HINT_COLOR_NO_ALPHA]:
					hint.set_item_disabled(hint_index, false)
				else:
					hint.set_item_disabled(hint_index, true)
		_:
		# disable all hints, TOFIXME: implement more hints
			for hint_index in hint.get_item_count():
				hint.set_item_disabled(hint_index, true)
	
	hint.set_item_disabled(0, false)


func _on_HintButton_item_selected(id: int) -> void: # hint changed
	match hint.get_selected_id():
		PROPERTY_HINT_NONE:
			info_label.text = "No hint for the edited property."
		
		PROPERTY_HINT_RANGE:
			info_label.text = "Hints that an integer or float property should be within a range specified via the hint string \"min,max\" or \"min,max,step\". The hint string can optionally include \"or_greater\" and/or \"or_lesser\" to allow manual input going respectively above the max or below the min values. Example: \"-360,360,1,or_greater,or_lesser\" (no quotes and no spaces in the hint_string)."
		
		PROPERTY_HINT_EXP_RANGE:
			info_label.text = 'Hints that an integer or float property should be within an exponential range specified via the hint string "min,max" or "min,max,step". The hint string can optionally include "or_greater" and/or "or_lesser" to allow manual input going respectively above the max or below the min values. Example: "0.01,100,0.01,or_greater".'
		
		PROPERTY_HINT_ENUM:
			info_label.text = 'Hints that an integer, float or string property is an enumerated value to pick in a list specified via a hint string such as "Hello,Something,Else" (no quotes and no spaces in the hint_string).'
		
		PROPERTY_HINT_EXP_EASING:
			info_label.text = 'Hints that a float property should be edited via an exponential easing function. The hint string can include "attenuation" to flip the curve horizontally and/or "inout" to also include in/out easing.'
		
		PROPERTY_HINT_FLAGS:
			info_label.text = 'Hints that an integer property is a bitmask with named bit flags. For example, to allow toggling bits 0, 1, 2 and 4, the hint could be something like "Bit0,Bit1,Bit2,,Bit4".'
		
		PROPERTY_HINT_LAYERS_2D_RENDER:
			info_label.text = 'Hints that an integer property is a bitmask using the optionally named 2D render layers.'
		
		PROPERTY_HINT_LAYERS_2D_PHYSICS:
			info_label.text = 'Hints that an integer property is a bitmask using the optionally named 2D physics layers.'
		
		PROPERTY_HINT_LAYERS_3D_RENDER:
			info_label.text = 'Hints that an integer property is a bitmask using the optionally named 3D render layers.'
		
		PROPERTY_HINT_LAYERS_3D_PHYSICS:
			info_label.text = 'Hints that an integer property is a bitmask using the optionally named 3D physics layers.'
		
		PROPERTY_HINT_FILE:
			info_label.text = 'Hints that a string property is a path to a file. Editing it will show a file dialog for picking the path. The hint string can be a set of filters with wildcards like "*.png,*.jpg" (no quotes in the hint_string). You can use the FileDialog after adding the setting.'
		
		PROPERTY_HINT_DIR:
			info_label.text = 'Hints that a string property is a path to a directory. Editing it will show a file dialog for picking the path. You can use the FileDialog after adding the setting.'
		
		PROPERTY_HINT_GLOBAL_FILE: 
			info_label.text = 'Hints that a string property is an absolute path to a file outside the project folder. Editing it will show a file dialog for picking the path. The hint string can be a set of filters with wildcards like "*.png,*.jpg" (no quotes in the hint_string). You can use the FileDialog after adding the setting.'
		
		PROPERTY_HINT_GLOBAL_DIR: 
			info_label.text = 'Hints that a string property is an absolute path to a directory outside the project folder. Editing it will show a file dialog for picking the path. You can use the FileDialog after adding the setting.'
		
		PROPERTY_HINT_RESOURCE_TYPE:
			info_label.text = 'Hints that a property is an instance of a Resource-derived type, optionally specified via the hint string (e.g. "Texture"). Editing it will show a popup menu of valid resource types to instantiate.'
		
		PROPERTY_HINT_MULTILINE_TEXT:
			info_label.text = 'Hints that a string property is text with line breaks. Editing it will show a text input field where line breaks can be typed.'
		
		PROPERTY_HINT_PLACEHOLDER_TEXT:
			info_label.text = 'Hints that a string property should have a placeholder text visible on its input field, whenever the property is empty. The hint string is the placeholder text to use.'
		
		PROPERTY_HINT_COLOR_NO_ALPHA:
			info_label.text = 'Hints that a color property should be edited without changing its alpha component, i.e. only R, G and B channels are edited.'
		
		PROPERTY_HINT_IMAGE_COMPRESS_LOSSY:
			info_label.text = 'Hints that an image is compressed using lossy compression.'
		
		PROPERTY_HINT_IMAGE_COMPRESS_LOSSLESS:
			info_label.text = 'Hints that an image is compressed using lossless compression.'
