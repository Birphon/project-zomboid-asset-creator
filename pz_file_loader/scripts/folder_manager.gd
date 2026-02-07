extends Control

# Signals
signal folders_updated()
signal reload_requested()
signal closed()

# Node references - using find_child for reliability
var color_rect: ColorRect
var title_label: Label
var root_path_label: Label
var change_root_button: Button
var subfolders_label: Label
var subfolders_list: VBoxContainer
var add_subfolder_button: Button
var status_label: Label
var reload_button: Button
var close_button: Button

# Dialogs
var folder_dialog: FileDialog = null
var add_subfolder_dialog: ConfirmationDialog = null
var subfolder_input: LineEdit = null

# Common subfolders user might want to add
const COMMON_SUBFOLDERS = ["scripts", "clothing", "textures", "lua", "maps", "radio", "sound", "ui"]

func _ready() -> void:
	# Get all node references
	_get_node_references()
	
	# Setup UI text
	_setup_ui()
	
	# Connect signals
	_connect_signals()
	
	# Setup dialogs
	_setup_dialogs()
	
	# Load and display current configuration
	_refresh_ui()

func _get_node_references() -> void:
	color_rect = find_child("ColorRect", true, false)
	title_label = find_child("TitleLabel", true, false)
	root_path_label = find_child("RootPathLabel", true, false)
	change_root_button = find_child("ChangeRootButton", true, false)
	subfolders_label = find_child("SubfoldersLabel", true, false)
	subfolders_list = find_child("SubfoldersList", true, false)
	add_subfolder_button = find_child("AddSubfolderButton", true, false)
	status_label = find_child("StatusLabel", true, false)
	reload_button = find_child("ReloadButton", true, false)
	close_button = find_child("CloseButton", true, false)
	
	# Verify critical nodes exist
	if not title_label or not subfolders_list:
		push_error("FolderManager: Critical UI nodes not found!")

func _setup_ui() -> void:
	if title_label:
		title_label.text = "Folder Manager"
	if subfolders_label:
		subfolders_label.text = "Media Subfolders:"
	if change_root_button:
		change_root_button.text = "Change Root Folder"
	if add_subfolder_button:
		add_subfolder_button.text = "+ Add Subfolder"
	if reload_button:
		reload_button.text = "Reload All Files"
	if close_button:
		close_button.text = "Close"
	if status_label:
		status_label.text = ""
	if color_rect:
		color_rect.mouse_filter = Control.MOUSE_FILTER_STOP

func _connect_signals() -> void:
	if change_root_button:
		change_root_button.pressed.connect(_on_change_root_button_pressed)
	if add_subfolder_button:
		add_subfolder_button.pressed.connect(_on_add_subfolder_button_pressed)
	if reload_button:
		reload_button.pressed.connect(_on_reload_button_pressed)
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)

func _setup_dialogs() -> void:
	# Setup folder browser dialog
	folder_dialog = FileDialog.new()
	folder_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	folder_dialog.access = FileDialog.ACCESS_FILESYSTEM
	folder_dialog.title = "Select Project Zomboid Root Folder"
	folder_dialog.min_size = Vector2i(800, 600)
	folder_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	folder_dialog.dir_selected.connect(_on_folder_dialog_dir_selected)
	add_child(folder_dialog)
	
	# Setup add subfolder dialog
	add_subfolder_dialog = ConfirmationDialog.new()
	add_subfolder_dialog.title = "Add Media Subfolder"
	add_subfolder_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	add_subfolder_dialog.min_size = Vector2i(400, 200)
	
	var vbox = VBoxContainer.new()
	
	var instruction = Label.new()
	instruction.text = "Select a common subfolder or enter a custom name:"
	vbox.add_child(instruction)
	
	var option_button = OptionButton.new()
	option_button.add_item("(Select common folder)", -1)
	for subfolder in COMMON_SUBFOLDERS:
		option_button.add_item(subfolder)
	option_button.item_selected.connect(_on_common_subfolder_selected)
	vbox.add_child(option_button)
	
	var or_label = Label.new()
	or_label.text = "\nOr enter custom:"
	vbox.add_child(or_label)
	
	subfolder_input = LineEdit.new()
	subfolder_input.placeholder_text = "e.g., scripts, clothing"
	vbox.add_child(subfolder_input)
	
	add_subfolder_dialog.add_child(vbox)
	add_subfolder_dialog.confirmed.connect(_on_add_subfolder_confirmed)
	add_child(add_subfolder_dialog)

func _refresh_ui() -> void:
	# Update root folder display
	if root_path_label:
		var root = ConfigManager.get_root_folder()
		if root.is_empty():
			root_path_label.text = "[Not Set]"
			root_path_label.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
		else:
			root_path_label.text = root
			root_path_label.remove_theme_color_override("font_color")
	
	# Clear and rebuild subfolder list
	if subfolders_list:
		for child in subfolders_list.get_children():
			child.queue_free()
		
		var subfolders = ConfigManager.get_subfolders()
		if subfolders.is_empty():
			var label = Label.new()
			label.text = "No subfolders configured"
			label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			subfolders_list.add_child(label)
		else:
			for subfolder in subfolders:
				_add_subfolder_row(subfolder)
	
	_update_status()

func _add_subfolder_row(subfolder_name: String) -> void:
	if not subfolders_list:
		return
	
	var hbox = HBoxContainer.new()
	
	# Status indicator
	var status_icon = Label.new()
	var full_path = ConfigManager.get_root_folder().path_join("media").path_join(subfolder_name)
	if DirAccess.dir_exists_absolute(full_path):
		status_icon.text = "✓ "
		status_icon.add_theme_color_override("font_color", Color(0.5, 1, 0.5))
	else:
		status_icon.text = "✗ "
		status_icon.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
	hbox.add_child(status_icon)
	
	# Subfolder name
	var name_label = Label.new()
	name_label.text = subfolder_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_label)
	
	# Path
	var path_label = Label.new()
	path_label.text = "media/%s" % subfolder_name
	path_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	path_label.add_theme_font_size_override("font_size", 10)
	hbox.add_child(path_label)
	
	# Remove button
	var remove_btn = Button.new()
	remove_btn.text = "Remove"
	remove_btn.pressed.connect(_on_remove_subfolder.bind(subfolder_name))
	hbox.add_child(remove_btn)
	
	subfolders_list.add_child(hbox)

func _update_status() -> void:
	if not status_label:
		return
	
	var root = ConfigManager.get_root_folder()
	var subfolders = ConfigManager.get_subfolders()
	
	if root.is_empty():
		status_label.text = "⚠ Root folder not set"
		status_label.add_theme_color_override("font_color", Color(1, 0.7, 0))
	elif subfolders.is_empty():
		status_label.text = "⚠ No subfolders configured"
		status_label.add_theme_color_override("font_color", Color(1, 0.7, 0))
	else:
		var valid = ConfigManager.get_subfolder_paths().size()
		status_label.text = "✓ %d subfolder(s), %d valid" % [subfolders.size(), valid]
		if valid == subfolders.size():
			status_label.add_theme_color_override("font_color", Color(0.5, 1, 0.5))
		else:
			status_label.add_theme_color_override("font_color", Color(1, 0.7, 0))

# === Button Handlers ===

func _on_change_root_button_pressed() -> void:
	if folder_dialog:
		var current = ConfigManager.get_root_folder()
		if not current.is_empty() and DirAccess.dir_exists_absolute(current):
			folder_dialog.current_dir = current
		folder_dialog.popup_centered()

func _on_add_subfolder_button_pressed() -> void:
	if subfolder_input:
		subfolder_input.text = ""
	if add_subfolder_dialog:
		add_subfolder_dialog.popup_centered()

func _on_reload_button_pressed() -> void:
	reload_requested.emit()
	if status_label:
		status_label.text = "Reloading..."

func _on_close_button_pressed() -> void:
	closed.emit()
	queue_free()

# === Dialog Handlers ===

func _on_folder_dialog_dir_selected(dir: String) -> void:
	var root = _find_pz_root(dir)
	if root != "":
		ConfigManager.set_root_folder(root)
		_refresh_ui()
		folders_updated.emit()
		if status_label:
			status_label.text = "✓ Root folder updated"
			status_label.add_theme_color_override("font_color", Color(0.5, 1, 0.5))
	else:
		_show_error("Invalid folder. Could not find Project Zomboid root with media/ folder.")

func _on_common_subfolder_selected(index: int) -> void:
	if index > 0 and index <= COMMON_SUBFOLDERS.size() and subfolder_input:
		subfolder_input.text = COMMON_SUBFOLDERS[index - 1]

func _on_add_subfolder_confirmed() -> void:
	if not subfolder_input:
		return
	
	var name = subfolder_input.text.strip_edges().replace("/", "").replace("\\", "")
	if name.is_empty():
		_show_error("Please enter a subfolder name")
		return
	
	if ConfigManager.add_subfolder(name):
		_refresh_ui()
		folders_updated.emit()
		if status_label:
			status_label.text = "✓ Added: %s" % name
			status_label.add_theme_color_override("font_color", Color(0.5, 1, 0.5))
	else:
		if status_label:
			status_label.text = "Already exists: %s" % name

func _on_remove_subfolder(subfolder_name: String) -> void:
	var confirm = ConfirmationDialog.new()
	confirm.dialog_text = "Remove '%s' from configuration?\n\n(Files will not be deleted)" % subfolder_name
	confirm.title = "Confirm Removal"
	confirm.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	
	confirm.confirmed.connect(func():
		if ConfigManager.remove_subfolder(subfolder_name):
			_refresh_ui()
			folders_updated.emit()
			if status_label:
				status_label.text = "✓ Removed: %s" % subfolder_name
		confirm.queue_free()
	)
	confirm.canceled.connect(confirm.queue_free)
	
	add_child(confirm)
	confirm.popup_centered()

# === Helpers ===

func _find_pz_root(dir: String) -> String:
	var path = dir.simplify_path()
	
	for i in range(5):
		if DirAccess.dir_exists_absolute(path.path_join("media")):
			return path
		if path.get_file() == "media":
			return path.get_base_dir()
		
		var parent = path.get_base_dir()
		if parent == path:
			break
		path = parent
	
	return ""

func _show_error(message: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.dialog_text = message
	dialog.title = "Error"
	dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_close_button_pressed()
		accept_event()
