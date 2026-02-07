extends Node

# Configuration file path
const CONFIG_FILE = "user://pz_folders_config.json"

# Stored configuration
var config_data: Dictionary = {
	"project_zomboid_root": "",
	"media_subfolders": [],  # Array of subfolder names like ["scripts", "clothing", "textures"]
	"last_load_timestamp": ""
}

signal config_updated()

func _ready() -> void:
	load_config()

# Save configuration to disk
func save_config() -> bool:
	var file = FileAccess.open(CONFIG_FILE, FileAccess.WRITE)
	if file == null:
		push_error("Cannot save config: %s" % FileAccess.get_open_error())
		return false
	
	config_data["last_load_timestamp"] = Time.get_datetime_string_from_system()
	var json_string = JSON.stringify(config_data, "\t")
	file.store_string(json_string)
	file.close()
	
	print("Configuration saved to: ", CONFIG_FILE)
	config_updated.emit()
	return true

# Load configuration from disk
func load_config() -> bool:
	if not FileAccess.file_exists(CONFIG_FILE):
		print("No config file found, using defaults")
		return false
	
	var file = FileAccess.open(CONFIG_FILE, FileAccess.READ)
	if file == null:
		push_error("Cannot load config: %s" % FileAccess.get_open_error())
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("Failed to parse config JSON: %s" % json.get_error_message())
		return false
	
	config_data = json.get_data()
	print("Configuration loaded from: ", CONFIG_FILE)
	config_updated.emit()
	return true

# Set the Project Zomboid root folder
func set_root_folder(path: String) -> void:
	config_data["project_zomboid_root"] = path
	save_config()

# Get the Project Zomboid root folder
func get_root_folder() -> String:
	return config_data.get("project_zomboid_root", "")

# Add a media subfolder to track
func add_subfolder(subfolder_name: String) -> bool:
	if subfolder_name not in config_data["media_subfolders"]:
		config_data["media_subfolders"].append(subfolder_name)
		save_config()
		return true
	return false

# Remove a media subfolder
func remove_subfolder(subfolder_name: String) -> bool:
	var index = config_data["media_subfolders"].find(subfolder_name)
	if index != -1:
		config_data["media_subfolders"].remove_at(index)
		save_config()
		return true
	return false

# Get all tracked subfolders
func get_subfolders() -> Array:
	return config_data.get("media_subfolders", [])

# Get full paths to all tracked subfolders
func get_subfolder_paths() -> Array[String]:
	var paths: Array[String] = []
	var root = get_root_folder()
	
	if root.is_empty():
		return paths
	
	for subfolder in get_subfolders():
		var full_path = root.path_join("media").path_join(subfolder)
		if DirAccess.dir_exists_absolute(full_path):
			paths.append(full_path)
	
	return paths

# Check if root folder is set and valid
func has_valid_root() -> bool:
	var root = get_root_folder()
	if root.is_empty():
		return false
	
	var media_path = root.path_join("media")
	return DirAccess.dir_exists_absolute(media_path)

# Clear all configuration
func clear_config() -> void:
	config_data = {
		"project_zomboid_root": "",
		"media_subfolders": [],
		"last_load_timestamp": ""
	}
	save_config()
