@tool
extends EditorPlugin

var filesystem = get_editor_interface().get_resource_filesystem()

var popupFilesystem : PopupMenu

var remove_root_motion_menu_id = 10003

func _enter_tree():
	FindFilesystemPopup()

func _exit_tree():
	if popupFilesystem:
		popupFilesystem.disconnect("about_to_popup", Callable(self, "AddItemToPopup"))
		popupFilesystem.disconnect("id_pressed", Callable(self, "RemoveMixamoRootMotion"))

func FindFilesystemPopup():
	var file_system:FileSystemDock = get_editor_interface().get_file_system_dock()
	
	for child in file_system.get_children():
		var pop:PopupMenu = child as PopupMenu
		if not pop: continue
		
		popupFilesystem = pop
		popupFilesystem.connect("about_to_popup", Callable(self, "AddItemToPopup"))
		popupFilesystem.connect("id_pressed", Callable(self, "RemoveMixamoRootMotion"))

func AddItemToPopup():
	var selected_paths = get_selected_paths(get_filesystem_tree(self))
	var res_files = selected_paths.filter(func(path): return path.ends_with(".res") and _is_animation_library(path))
	
	if res_files.size() > 0:
		popupFilesystem.add_separator()
		popupFilesystem.add_item("Remove Mixamo Root Motion", remove_root_motion_menu_id)

func _is_animation_library(path: String) -> bool:
	var resource = load(path)
	if resource == null:
		return false
	return resource is AnimationLibrary

func RemoveMixamoRootMotion(id : int):
	if id == remove_root_motion_menu_id:
		var selected_paths = get_selected_paths(get_filesystem_tree(self))
		var res_files = selected_paths.filter(func(path): return path.ends_with(".res") and _is_animation_library(path))
		if res_files.size() > 0:
			_show_animation_selection_dialog(res_files)

func _show_animation_selection_dialog(res_paths: Array):
	# Collect all animations from all selected AnimationLibrary files
	var all_animations = []
	
	for res_path in res_paths:
		var resource = load(res_path)
		if not resource is AnimationLibrary:
			continue
		
		var animation_library = resource as AnimationLibrary
		for anim_name in animation_library.get_animation_list():
			var animation = animation_library.get_animation(anim_name)
			if animation != null:  # Skip null animations (missing external files)
				all_animations.append({
					"name": anim_name,
					"path": res_path,
					"animation": animation,
					"is_locomotion": _is_locomotion_animation(anim_name)
				})
	
	if all_animations.size() == 0:
		_show_error_dialog("No valid animations found in the selected AnimationLibrary files.")
		return
	
	# Create and show the selection dialog
	var dialog = AnimationSelectionDialog.new()
	get_editor_interface().get_base_control().add_child(dialog)
	dialog.setup_animations(all_animations)
	dialog.connect("animations_confirmed", Callable(self, "_process_selected_animations"))
	
	# Show the dialog
	dialog.popup_centered(Vector2i(380, 250))

func _process_selected_animations(selected_animations: Array):
	var processed_count = 0
	var files_to_save = {}
	
	print("Processing selected animations...")
	
	for anim_data in selected_animations:
		print("Processing animation: ", anim_data.name, " from ", anim_data.path)
		if _remove_root_motion_from_animation(anim_data.animation):
			processed_count += 1
			files_to_save[anim_data.path] = true
			print("  ✓ Root motion removed from: ", anim_data.name)
		else:
			print("  ⚠ No Hips track found in: ", anim_data.name)
	
	# Save modified files
	for file_path in files_to_save.keys():
		var resource = load(file_path)
		if resource is AnimationLibrary:
			ResourceSaver.save(resource, file_path)
			print("AnimationLibrary saved: ", file_path)
	
	print("Root motion removal completed!")
	print("Processed ", processed_count, " animations")
	
	# Show completion dialog
	_show_completion_dialog(processed_count, selected_animations.size())

func _show_error_dialog(message: String):
	var dialog = AcceptDialog.new()
	dialog.title = "Mixamo Root Motion Remover - Error"
	dialog.dialog_text = message
	get_editor_interface().get_base_control().add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

func _is_locomotion_animation(anim_name: String) -> bool:
	var lower_name = anim_name.to_lower()
	var locomotion_keywords = ["forward", "left", "right", "backward", "walk", "run", "jog", "sprint", "strafe"]
	for keyword in locomotion_keywords:
		if keyword in lower_name:
			return true
	return false

func _remove_root_motion_from_animation(animation: Animation) -> bool:
	var hips_track_idx = -1
	
	# Find the Hips track
	for i in range(animation.get_track_count()):
		var track_path = animation.track_get_path(i)
		if str(track_path).contains("Hips") and animation.track_get_type(i) == Animation.TYPE_POSITION_3D:
			hips_track_idx = i
			break
	
	if hips_track_idx == -1:
		return false
	
	# Modify all keyframes in the Hips track
	var keyframe_count = animation.track_get_key_count(hips_track_idx)
	
	for key_idx in range(keyframe_count):
		var time = animation.track_get_key_time(hips_track_idx, key_idx)
		var current_value = animation.track_get_key_value(hips_track_idx, key_idx)
		
		# Keep only the Y component, zero out X and Z
		var new_value = Vector3(0.0, current_value.y, 0.0)
		
		# Update the keyframe
		animation.track_set_key_value(hips_track_idx, key_idx, new_value)
	
	print("    Modified ", keyframe_count, " keyframes in Hips track")
	return true

func _show_completion_dialog(processed_count: int, total_selected: int):
	var dialog = AcceptDialog.new()
	dialog.title = "Mixamo Root Motion Remover"
	
	var status_message = ""
	if processed_count > 0:
		status_message = "✓ SUCCESS: Selected animations had their Hips X and Z positions set to 0.0"
	else:
		status_message = "⚠ WARNING: No animations were processed (no Hips tracks found)"
	
	dialog.dialog_text = "Root motion removal completed!\n\nProcessed: " + str(processed_count) + " animations\nSelected: " + str(total_selected) + " animations\n\n" + status_message
	
	get_editor_interface().get_base_control().add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

# Animation Selection Dialog Class
class AnimationSelectionDialog extends ConfirmationDialog:
	signal animations_confirmed(selected_animations: Array)
	
	var animation_data: Array = []
	var checkboxes: Array = []
	var select_all_checkbox: CheckBox
	var scroll_container: ScrollContainer
	var vbox_container: VBoxContainer
	
	func _init():
		title = "Select Animations for Root Motion Removal"
		set_flag(Window.FLAG_RESIZE_DISABLED, false)
		min_size = Vector2i(550, 450)
		# Create main container with proper margins
		var main_vbox = VBoxContainer.new()
		main_vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		main_vbox.add_theme_constant_override("separation", 8)
		add_child(main_vbox)
		
		# Create header with instructions
		var header_label = Label.new()
		header_label.text = "Select the animations you want to remove root motion from:"
		main_vbox.add_child(header_label)
		
		# Create select all checkbox
		select_all_checkbox = CheckBox.new()
		select_all_checkbox.text = "Select All / Deselect All"
		select_all_checkbox.toggled.connect(_on_select_all_toggled)
		main_vbox.add_child(select_all_checkbox)
		
		# Create scroll container for animation list
		scroll_container = ScrollContainer.new()
		scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll_container.custom_minimum_size = Vector2(0, 100)
		
		# Add background to match Godot editor theme (darker version)
		var scroll_style = StyleBoxFlat.new()
		var editor_theme = EditorInterface.get_editor_theme()
		var base_color = editor_theme.get_color("base_color", "Editor")
		scroll_style.bg_color = base_color.darkened(0.3)  # Make it 30% darker
		scroll_style.border_width_left = 1
		scroll_style.border_width_right = 1
		scroll_style.border_width_top = 1
		scroll_style.border_width_bottom = 1
		scroll_style.border_color = editor_theme.get_color("contrast_color_1", "Editor")
		scroll_container.add_theme_stylebox_override("panel", scroll_style)
		
		main_vbox.add_child(scroll_container)
		
		# Create container for checkboxes
		vbox_container = VBoxContainer.new()
		vbox_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox_container.add_theme_constant_override("separation", 4)
		scroll_container.add_child(vbox_container)
		
		# Connect dialog signals
		confirmed.connect(_on_confirmed)
		
	func setup_animations(animations: Array):
		animation_data = animations
		checkboxes.clear()
		
		# Clear existing checkboxes
		for child in vbox_container.get_children():
			child.queue_free()
		
		# Create checkboxes for each animation
		for anim_data in animation_data:
			var checkbox = CheckBox.new()
			var display_name = anim_data.name
			
			# Add indicator for locomotion animations
			if anim_data.is_locomotion:
				display_name += " (locomotion)"
				checkbox.button_pressed = true  # Auto-select locomotion animations
			
			# Debug print to see if names are correct
			print("Creating checkbox for animation: ", display_name)
			
			checkbox.text = display_name
			checkbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			checkbox.clip_contents = false
			checkbox.autowrap_mode = TextServer.AUTOWRAP_OFF
			checkbox.custom_minimum_size = Vector2(300, 20)
			checkbox.toggled.connect(_on_animation_checkbox_toggled)
			
			vbox_container.add_child(checkbox)
			checkboxes.append(checkbox)
		
		# Update select all checkbox state
		_update_select_all_state()
	
	func _on_select_all_toggled(pressed: bool):
		for checkbox in checkboxes:
			checkbox.button_pressed = pressed
	
	func _on_animation_checkbox_toggled(pressed: bool):
		_update_select_all_state()
	
	func _update_select_all_state():
		var all_selected = true
		var any_selected = false
		
		for checkbox in checkboxes:
			if checkbox.button_pressed:
				any_selected = true
			else:
				all_selected = false
		
		select_all_checkbox.set_pressed_no_signal(all_selected)
		
		# Enable/disable OK button based on selection
		get_ok_button().disabled = not any_selected
	
	func _on_confirmed():
		var selected_animations = []
		
		for i in range(checkboxes.size()):
			if checkboxes[i].button_pressed:
				selected_animations.append(animation_data[i])
		
		animations_confirmed.emit(selected_animations)
		queue_free()

# Helper functions
static func get_selected_paths(fs_tree:Tree)->Array:
	var sel_items: = tree_get_selected_items(fs_tree)
	var result: = []
	for i in sel_items:
		i = i as TreeItem
		result.push_back(i.get_metadata(0))
	return result

static func get_filesystem_tree(plugin:EditorPlugin)->Tree:
	var dock = plugin.get_editor_interface().get_file_system_dock()
	return find_node_by_class_path(dock, ['SplitContainer','Tree']) as Tree

static func tree_get_selected_items(tree:Tree)->Array:
	var res = []
	var item = tree.get_next_selected(tree.get_root())
	while true:
		if item == null: break
		res.push_back(item)
		item = tree.get_next_selected(item)
	return res

static func find_node_by_class_path(node:Node, class_path:Array)->Node:
	var res:Node

	var stack = []
	var depths = []

	var first = class_path[0]
	for c in node.get_children():
		if c.get_class() == first:
			stack.push_back(c)
			depths.push_back(0)

	if stack == null: return res
	
	var max_ = class_path.size()-1

	while stack:
		var d = depths.pop_back()
		var n = stack.pop_back()

		if d>max_:
			continue

		if d == max_:
			return n

		for c in n.get_children():
			if c.get_class() == class_path[d+1]:
				stack.push_back(c)
				depths.push_back(d+1)

	return res 
