extends Control

# Signals
signal folder_selected(base_path: String)
signal selection_cancelled()

# Node references
@onready var color_rect: ColorRect = $ColorRect
@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var message_label: RichTextLabel = $PanelContainer/MarginContainer/VBoxContainer/MessageLabel
@onready var browse_button: Button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/BrowseButton
@onready var cancel_button: Button = $PanelContainer/MarginContainer/VBoxContainer/HBoxContainer/CancelButton

# FileDialog for browsing
var file_dialog: FileDialog = null

func _ready() -> void:
	# Setup UI text
	title_label.text = "Project Zomboid Not Found"
	message_label.text = _get_instruction_text()
	
	# Setup buttons
	browse_button.text = "Browse..."
	cancel_button.text = "Cancel"
	
	# Connect button signals
	browse_button.pressed.connect(_on_browse_button_pressed)
	cancel_button.pressed.connect(_on_cancel_button_pressed)
	
	# Setup file dialog
	_setup_file_dialog()
	
	# Make color rect clickable to prevent clicks passing through
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP

func _setup_file_dialog() -> void:
	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.title = "Select Project Zomboid Installation or Media Folder"
	file_dialog.min_size = Vector2i(800, 600)
	file_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	
	# Connect signals
	file_dialog.dir_selected.connect(_on_directory_selected)
	file_dialog.canceled.connect(_on_file_dialog_cancelled)
	
	# Add to scene tree
	add_child(file_dialog)
	
	# Set default path based on OS
	var default_path = _get_default_browse_path()
	if DirAccess.dir_exists_absolute(default_path):
		file_dialog.current_dir = default_path

func _get_instruction_text() -> String:
	var text = "[center]Could not automatically locate your Project Zomboid installation.[/center]\n\n"
	text += "Please select either:\n"
	text += "  • [b]Project Zomboid root folder[/b] (recommended)\n"
	text += "  • [b]media/[/b] folder\n"
	text += "  • Any [b]media/[subfolder][/b] (scripts, clothing, etc.)\n\n"
	
	match OS.get_name():
		"Windows":
			text += "[i]Common locations:[/i]\n"
			text += "  • C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid\n"
			text += "  • D:/Steam/steamapps/common/ProjectZomboid\n"
		"Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD":
			text += "[i]Common locations:[/i]\n"
			text += "  • ~/.steam/steam/steamapps/common/ProjectZomboid\n"
			text += "  • ~/.local/share/Steam/steamapps/common/ProjectZomboid\n"
		"macOS":
			text += "[i]Common location:[/i]\n"
			text += "  • ~/Library/Application Support/Steam/steamapps/common/ProjectZomboid\n"
	
	return text

func _get_default_browse_path() -> String:
	match OS.get_name():
		"Windows":
			return "C:/Program Files (x86)/Steam/steamapps/common"
		"Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD":
			var home = OS.get_environment("HOME")
			var steam_path = home + "/.steam/steam/steamapps/common"
			if DirAccess.dir_exists_absolute(steam_path):
				return steam_path
			return home + "/.local/share/Steam/steamapps/common"
		"macOS":
			var home = OS.get_environment("HOME")
			return home + "/Library/Application Support/Steam/steamapps/common"
	
	return OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)

# Button handlers
func _on_browse_button_pressed() -> void:
	if file_dialog:
		file_dialog.popup_centered()

func _on_cancel_button_pressed() -> void:
	selection_cancelled.emit()
	queue_free()

# File dialog handlers
func _on_directory_selected(dir: String) -> void:
	# Find the root ProjectZomboid folder from selection
	var root_path = _find_project_zomboid_root(dir)
	
	if root_path != "":
		folder_selected.emit(root_path)
		queue_free()
	else:
		_show_invalid_folder_error(dir)

func _on_file_dialog_cancelled() -> void:
	# User cancelled the file dialog, but keep the modal open
	pass

# Smart path resolution
func _find_project_zomboid_root(dir_path: String) -> String:
	var current_path = dir_path.simplify_path()
	
	print("Trying to find Project Zomboid root from: ", current_path)
	
	# Traverse up the directory tree looking for the media folder or ProjectZomboid folder
	for i in range(5):  # Check up to 5 levels up
		# Check if this directory contains a "media" folder
		var media_path = current_path.path_join("media")
		
		if DirAccess.dir_exists_absolute(media_path):
			print("Found media folder at: ", current_path)
			return current_path
		
		# Check if we're inside a media folder already
		if current_path.get_file() == "media":
			var parent = current_path.get_base_dir()
			print("Currently in media folder, parent is: ", parent)
			return parent
		
		# Check if parent contains ProjectZomboid in the name
		if "ProjectZomboid" in current_path:
			var parts = current_path.split("/")
			for j in range(parts.size() - 1, -1, -1):
				if "ProjectZomboid" in parts[j]:
					var potential_root = "/".join(parts.slice(0, j + 1))
					var test_media = potential_root.path_join("media")
					if DirAccess.dir_exists_absolute(test_media):
						print("Found root via ProjectZomboid folder name: ", potential_root)
						return potential_root
					break
		
		# Move up one directory
		var parent = current_path.get_base_dir()
		if parent == current_path:  # Reached root of filesystem
			break
		current_path = parent
	
	print("Could not find Project Zomboid root!")
	return ""

func _show_invalid_folder_error(dir_path: String) -> void:
	var error_dialog = AcceptDialog.new()
	error_dialog.title = "Invalid Folder"
	error_dialog.dialog_text = "Could not locate the Project Zomboid installation from the selected folder.\n\n"
	error_dialog.dialog_text += "Selected: %s\n\n" % dir_path
	error_dialog.dialog_text += "Please select:\n"
	error_dialog.dialog_text += "  • The root ProjectZomboid folder\n"
	error_dialog.dialog_text += "  • The media/ folder\n"
	error_dialog.dialog_text += "  • Any media/[subfolder]/"
	error_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	
	error_dialog.confirmed.connect(error_dialog.queue_free)
	error_dialog.canceled.connect(error_dialog.queue_free)
	
	add_child(error_dialog)
	error_dialog.popup_centered()

# Handle ESC key to cancel
func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			_on_cancel_button_pressed()
			accept_event()
