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
			_process_animation_libraries(res_files)

func _process_animation_libraries(res_paths: Array) -> void:
	for res_path in res_paths:
		_process_animation_library_file(res_path)

func _process_animation_library_file(file_path: String) -> void:
	print("Processing AnimationLibrary: ", file_path)
	
	var resource = load(file_path)
	if not resource is AnimationLibrary:
		print("Error: File is not an AnimationLibrary: ", file_path)
		return
	
	var animation_library = resource as AnimationLibrary
	var processed_count = 0
	var total_animations = animation_library.get_animation_list().size()
	
	print("Analyzing ", total_animations, " animations...")
	
	for anim_name in animation_library.get_animation_list():
		var animation = animation_library.get_animation(anim_name)
		
		# Controlla se l'animazione è valida
		if animation == null:
			print("  ⚠ Animation '", anim_name, "' is null (external file missing)")
			continue
		
		# Controlla se il nome dell'animazione contiene parole chiave di locomozione
		if _is_locomotion_animation(anim_name):
			print("Processing locomotion animation: ", anim_name)
			if _remove_root_motion_from_animation(animation):
				processed_count += 1
				print("  ✓ Root motion removed from: ", anim_name)
			else:
				print("  ⚠ No Hips track found in: ", anim_name)
		else:
			print("Skipping non-locomotion animation: ", anim_name)
	
	print("Root motion removal completed!")
	print("Processed ", processed_count, "/", total_animations, " locomotion animations")
	
	# Salva le modifiche
	if processed_count > 0:
		ResourceSaver.save(animation_library, file_path)
		print("AnimationLibrary saved: ", file_path)
	elif total_animations == 0:
		print("⚠ No animations found in AnimationLibrary")
	else:
		print("⚠ No locomotion animations processed (may have missing external files)")
	
	# Mostra un dialogo di conferma
	_show_completion_dialog(processed_count, total_animations, file_path)

func _is_locomotion_animation(anim_name: String) -> bool:
	var lower_name = anim_name.to_lower()
	var locomotion_keywords = ["forward", "left", "right", "backward"]
	for keyword in locomotion_keywords:
		if keyword in lower_name:
			return true
	return false

func _remove_root_motion_from_animation(animation: Animation) -> bool:
	var hips_track_idx = -1
	
	# Trova la traccia Hips
	for i in range(animation.get_track_count()):
		var track_path = animation.track_get_path(i)
		if str(track_path).contains("Hips") and animation.track_get_type(i) == Animation.TYPE_POSITION_3D:
			hips_track_idx = i
			break
	
	if hips_track_idx == -1:
		return false
	
	# Modifica tutti i keyframe nella traccia Hips
	var keyframe_count = animation.track_get_key_count(hips_track_idx)
	
	for key_idx in range(keyframe_count):
		var time = animation.track_get_key_time(hips_track_idx, key_idx)
		var current_value = animation.track_get_key_value(hips_track_idx, key_idx)
		
		# Mantieni solo la componente Y, azzera X e Z
		var new_value = Vector3(0.0, current_value.y, 0.0)
		
		# Aggiorna il keyframe
		animation.track_set_key_value(hips_track_idx, key_idx, new_value)
	
	print("    Modified ", keyframe_count, " keyframes in Hips track")
	return true

func _show_completion_dialog(processed_count: int, total_animations: int, file_path: String):
	var dialog = AcceptDialog.new()
	dialog.title = "Mixamo Root Motion Remover"
	var file_info = "File: " + file_path.get_file() + "\n\n"
	
	var status_message = ""
	if processed_count > 0:
		status_message = "✓ SUCCESS: Locomotion animations had their Hips X and Z positions set to 0.0"
	elif total_animations == 0:
		status_message = "⚠ WARNING: No animations found in AnimationLibrary"
	else:
		status_message = "⚠ WARNING: No locomotion animations were processed.\nThis may be due to missing external animation files."
	
	dialog.dialog_text = "Root motion removal completed!\n\n" + file_info + "Processed: " + str(processed_count) + " locomotion animations\nTotal animations: " + str(total_animations) + "\n\n" + status_message
	
	# Aggiungi il dialogo alla scena temporaneamente
	get_editor_interface().get_base_control().add_child(dialog)
	dialog.popup_centered()
	
	# Rimuovi il dialogo quando viene chiuso
	dialog.confirmed.connect(func(): dialog.queue_free())

# Helper functions copiato da mixamo_animation_retargeter
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