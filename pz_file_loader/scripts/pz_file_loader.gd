extends Node

# Node references
@onready var script_loader: Node = $ScriptLoader
@onready var ui_layer: CanvasLayer = $UI
@onready var status_label: Label = $UI/MarginContainer/CenterContainer/VBoxContainer/PanelContainer/MarginContainer/VBoxContainer/StatusLabel
@onready var progress_bar: ProgressBar = $UI/MarginContainer/CenterContainer/VBoxContainer/PanelContainer/MarginContainer/VBoxContainer/ProgressBar
@onready var select_folder_button: Button = $UI/MarginContainer/CenterContainer/VBoxContainer/PanelContainer/MarginContainer/VBoxContainer/SelectFolderButton
@onready var file_dialog: FileDialog = $FileDialog

# Action panel
@onready var actions_panel: PanelContainer = $UI/MarginContainer/CenterContainer/VBoxContainer/PanelContainer2
@onready var buttons_grid: GridContainer = $UI/MarginContainer/CenterContainer/VBoxContainer/PanelContainer2/MarginContainer/ActionsContainer/GridContainer

# Buttons - get dynamically from GridContainer
var clear_button: Button
var open_config_button: Button
var folder_manager_button: Button
var folder_selector_button: Button

# Scenes
var folder_selector_scene: PackedScene = preload("res://pz_file_loader/scenes/folder_selector.tscn")
var folder_selector_instance: Control = null
var folder_manager_scene: PackedScene = preload("res://pz_file_loader/scenes/folder_manager.tscn")
var folder_manager_instance: Control = null

# Status management
var status_timer: Timer = null
const DEFAULT_STATUS_TEXT = "Project Zomboid Asset Loader"

func _ready() -> void:
	# Get button references from the grid
	_setup_button_references()
	
	# Initial UI setup
	progress_bar.visible = false
	select_folder_button.visible = false
	actions_panel.visible = false
	status_label.text = "Searching for Project Zomboid scripts..."
	
	# Setup status timer
	status_timer = Timer.new()
	status_timer.one_shot = true
	status_timer.timeout.connect(_on_status_timer_timeout)
	add_child(status_timer)
	
	# Connect button signals
	select_folder_button.pressed.connect(_on_select_folder_button_pressed)
	file_dialog.dir_selected.connect(_on_folder_selected)
	
	if clear_button:
		clear_button.pressed.connect(_on_clear_button_pressed)
	if open_config_button:
		open_config_button.pressed.connect(_on_open_config_button_pressed)
	if folder_manager_button:
		folder_manager_button.pressed.connect(_on_folder_manager_button_pressed)
	if folder_selector_button:
		folder_selector_button.pressed.connect(_on_folder_selector_button_pressed)
	
	# Configure FileDialog
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.title = "Select Project Zomboid Root Folder"
	
	# Start loading process
	_start_loading()

func _setup_button_references() -> void:
	if not buttons_grid:
		push_error("GridContainer not found!")
		return
	
	var buttons = buttons_grid.get_children()
	print("Found %d buttons in grid" % buttons.size())
	
	if buttons.size() >= 4:
		clear_button = buttons[0] as Button
		open_config_button = buttons[1] as Button
		folder_manager_button = buttons[2] as Button
		folder_selector_button = buttons[3] as Button
		
		print("Button references set:")
		print("  clear_button: ", clear_button)
		print("  open_config_button: ", open_config_button)
		print("  folder_manager_button: ", folder_manager_button)
		print("  folder_selector_button: ", folder_selector_button)
	else:
		push_error("Expected 4 buttons in grid, found %d" % buttons.size())

# Add new function for timer management:
func _start_status_reset_timer(delay: float = 3.0) -> void:
	if status_timer:
		status_timer.start(delay)

func _on_status_timer_timeout() -> void:
	if is_instance_valid(status_label):
		status_label.text = DEFAULT_STATUS_TEXT

func _start_loading() -> void:
	# Hide action panel during loading
	actions_panel.visible = false
	
	# Connect script loader signals
	script_loader.loading_started.connect(_on_loading_started)
	script_loader.loading_progress.connect(_on_loading_progress)
	script_loader.loading_completed.connect(_on_loading_completed)
	script_loader.loading_failed.connect(_on_loading_failed)
	script_loader.folder_not_found.connect(_on_folder_not_found)
	
	# Begin auto-detection and loading
	script_loader.start_auto_load()

# Signal handlers for ScriptLoader
func _on_loading_started(file_count: int) -> void:
	status_label.text = "Loading %d script files..." % file_count
	progress_bar.visible = true
	progress_bar.max_value = file_count
	progress_bar.value = 0

func _on_loading_progress(current: int, total: int, file_name: String) -> void:
	progress_bar.value = current
	status_label.text = "Loading: %s (%d/%d)" % [file_name, current, total]

# Replace _on_loading_completed:
func _on_loading_completed(file_count: int) -> void:
	status_label.text = "Successfully loaded %d script files!" % file_count
	progress_bar.visible = false
	select_folder_button.visible = false
	
	# Show actions panel
	actions_panel.visible = true
	
	# Start timer to reset status after 5 seconds
	_start_status_reset_timer(5.0)
	
	print("Loading complete. Data ready for use.")


func _on_loading_failed(error_message: String) -> void:
	status_label.text = "Error: %s" % error_message
	progress_bar.visible = false
	select_folder_button.visible = true
	select_folder_button.text = "Retry Folder Selection"
	actions_panel.visible = false

func _on_folder_not_found() -> void:
	# Hide the main UI when showing the folder selector modal
	$UI.visible = false
	progress_bar.visible = false
	
	# Show modal folder selector
	_show_folder_selector()

# Manual folder selection
func _on_select_folder_button_pressed() -> void:
	_show_folder_selector()

func _show_folder_selector() -> void:
	if folder_selector_instance == null:
		folder_selector_instance = folder_selector_scene.instantiate()
		folder_selector_instance.folder_selected.connect(_on_manual_folder_selected)
		folder_selector_instance.selection_cancelled.connect(_on_folder_selection_cancelled)
		add_child(folder_selector_instance)
	else:
		folder_selector_instance.visible = true

func _on_manual_folder_selected(base_path: String) -> void:
	# Hide the folder selector
	if folder_selector_instance:
		folder_selector_instance.visible = false
	
	# Show main UI again
	$UI.visible = true
	
	# Save the root folder to config
	ConfigManager.set_root_folder(base_path)
	
	# Add default subfolders (scripts is essential)
	ConfigManager.add_subfolder("scripts")
	
	# Construct full path to scripts folder
	var scripts_path = base_path.path_join("media").path_join("scripts")
	
	status_label.text = "Loading from selected folder..."
	progress_bar.visible = true
	select_folder_button.visible = false
	
	# Load from manually selected path
	script_loader.load_from_path(scripts_path)

func _on_folder_selection_cancelled() -> void:
	# Hide the folder selector
	if folder_selector_instance:
		folder_selector_instance.visible = false
	
	# Show the main UI again
	$UI.visible = true
	status_label.text = "Folder selection cancelled. Click button to retry."
	select_folder_button.visible = true

func _on_folder_selected(dir: String) -> void:
	_on_manual_folder_selected(dir)

# === ACTION BUTTON HANDLERS ===

func _on_clear_button_pressed() -> void:
	var confirm = ConfirmationDialog.new()
	confirm.dialog_text = "Clear all loaded data and rescan?\n\nThis will:\n• Clear loaded script files from memory\n• Keep your folder configuration\n• Reload all files from configured folders"
	confirm.title = "Confirm Clear & Rescan"
	confirm.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	
	confirm.confirmed.connect(func():
		_perform_clear_and_rescan()
		confirm.queue_free()
	)
	
	confirm.canceled.connect(confirm.queue_free)
	
	add_child(confirm)
	confirm.popup_centered()

# Update _perform_clear_and_rescan to not show constant status:
func _perform_clear_and_rescan() -> void:
	print("\n=== Clearing and Rescanning ===")
	
	# Clear all loaded data
	ScriptDataManager.clear_all()
	
	# Hide action panel during reload
	actions_panel.visible = false
	
	# Reset UI
	status_label.text = "Rescanning folders..."
	progress_bar.visible = true
	progress_bar.value = 0
	
	# Restart loading process
	if ConfigManager.has_valid_root():
		var saved_paths = ConfigManager.get_subfolder_paths()
		if saved_paths.size() > 0:
			script_loader._load_from_multiple_paths(saved_paths)
		else:
			script_loader.start_auto_load()
	else:
		script_loader.start_auto_load()

func _on_open_config_button_pressed() -> void:
	var config_path = ProjectSettings.globalize_path("user://")
	
	print("Opening config folder: ", config_path)
	
	var result = OS.shell_open(config_path)
	
	if result == OK:
		status_label.text = "Opened config folder"
		_start_status_reset_timer(3.0)
	else:
		status_label.text = "Failed to open config folder"
		_start_status_reset_timer(3.0)
		push_error("Could not open config folder: %s" % config_path)

func _on_folder_manager_button_pressed() -> void:
	# Hide main UI and show folder manager (like folder selector)
	$UI.visible = false
	_show_folder_manager()

func _show_folder_manager() -> void:
	if folder_manager_instance == null:
		folder_manager_instance = folder_manager_scene.instantiate()
		folder_manager_instance.folders_updated.connect(_on_folders_updated)
		folder_manager_instance.reload_requested.connect(_on_reload_requested_from_manager)
		folder_manager_instance.closed.connect(_on_folder_manager_closed)
		add_child(folder_manager_instance)
	else:
		folder_manager_instance.visible = true

func _on_folders_updated() -> void:
	print("Folder configuration updated")
	# Don't update status here since UI is hidden

func _on_reload_requested_from_manager() -> void:
	# Close folder manager first
	if folder_manager_instance:
		folder_manager_instance.queue_free()
		folder_manager_instance = null
	
	# Show main UI again
	$UI.visible = true
	
	# Perform rescan
	_perform_clear_and_rescan()

func _on_folder_manager_closed() -> void:
	if folder_manager_instance:
		folder_manager_instance = null
	
	# Show main UI again
	$UI.visible = true
	
	# Update status to show current file count
	if is_instance_valid(status_label):
		var file_count = ScriptDataManager.get_file_count()
		if file_count > 0:
			status_label.text = "Successfully loaded %d script files!" % file_count
			_start_status_reset_timer(5.0)
		else:
			status_label.text = DEFAULT_STATUS_TEXT

func _on_folder_selector_button_pressed() -> void:
	# Hide main UI and show folder selector
	$UI.visible = false
	_show_folder_selector()
