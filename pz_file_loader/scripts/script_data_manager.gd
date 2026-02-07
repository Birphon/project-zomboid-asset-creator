extends Node

# This is an Autoload/Singleton script
# Add to Project Settings -> Autoload with name "ScriptDataManager"

# Data storage structures
var script_files: Dictionary = {}  # Key: file_path, Value: ScriptFileData
var files_by_name: Dictionary = {}  # Key: file_name, Value: Array of file_paths
var all_file_paths: Array[String] = []

# Inner class to store file data
class ScriptFileData:
	var file_path: String
	var file_name: String
	var content: String
	var lines: PackedStringArray
	var metadata: Dictionary  # For storing parsed data, tags, etc.
	
	func _init(path: String, file_content: String) -> void:
		file_path = path
		file_name = path.get_file()
		content = file_content
		lines = content.split("\n")
		metadata = {}

# Signals for data changes
signal script_added(file_path: String)
signal all_scripts_cleared()
signal data_ready()

func _ready() -> void:
	print("ScriptDataManager initialized")

# Add a script file to the manager
func add_script_file(file_path: String, content: String) -> void:
	if file_path in script_files:
		push_warning("File already exists, overwriting: %s" % file_path)
	
	var script_data = ScriptFileData.new(file_path, content)
	script_files[file_path] = script_data
	all_file_paths.append(file_path)
	
	# Index by file name for quick lookup
	var file_name = file_path.get_file()
	if file_name not in files_by_name:
		files_by_name[file_name] = []
	files_by_name[file_name].append(file_path)
	
	script_added.emit(file_path)

# Clear all stored data
func clear_all() -> void:
	script_files.clear()
	files_by_name.clear()
	all_file_paths.clear()
	all_scripts_cleared.emit()
	print("All script data cleared")

# Get file data by full path
func get_file_by_path(file_path: String) -> ScriptFileData:
	if file_path in script_files:
		return script_files[file_path]
	return null

# Get file content by path
func get_file_content(file_path: String) -> String:
	var file_data = get_file_by_path(file_path)
	if file_data:
		return file_data.content
	return ""

# Get files by name (may return multiple if same name in different folders)
func get_files_by_name(file_name: String) -> Array[ScriptFileData]:
	var results: Array[ScriptFileData] = []
	
	if file_name in files_by_name:
		for path in files_by_name[file_name]:
			results.append(script_files[path])
	
	return results

# Get first file matching name
func get_first_file_by_name(file_name: String) -> ScriptFileData:
	if file_name in files_by_name and files_by_name[file_name].size() > 0:
		return script_files[files_by_name[file_name][0]]
	return null

# Search for files containing a specific string in their path
func search_files_by_path(search_term: String, case_sensitive: bool = false) -> Array[ScriptFileData]:
	var results: Array[ScriptFileData] = []
	var search_lower = search_term.to_lower()
	
	for file_path in all_file_paths:
		var compare_path = file_path if case_sensitive else file_path.to_lower()
		var compare_term = search_term if case_sensitive else search_lower
		
		if compare_term in compare_path:
			results.append(script_files[file_path])
	
	return results

# Search for files containing specific content
func search_files_by_content(search_term: String, case_sensitive: bool = false) -> Array[ScriptFileData]:
	var results: Array[ScriptFileData] = []
	var search_lower = search_term.to_lower()
	
	for file_path in all_file_paths:
		var file_data = script_files[file_path]
		var compare_content = file_data.content if case_sensitive else file_data.content.to_lower()
		var compare_term = search_term if case_sensitive else search_lower
		
		if compare_term in compare_content:
			results.append(file_data)
	
	return results

# Get all file paths
func get_all_file_paths() -> Array[String]:
	return all_file_paths.duplicate()

# Get all script file data objects
func get_all_files() -> Array[ScriptFileData]:
	var results: Array[ScriptFileData] = []
	for file_path in all_file_paths:
		results.append(script_files[file_path])
	return results

# Get total number of loaded files
func get_file_count() -> int:
	return script_files.size()

# Check if a file exists by path
func has_file(file_path: String) -> bool:
	return file_path in script_files

# Get files in a specific directory
func get_files_in_directory(dir_path: String, recursive: bool = false) -> Array[ScriptFileData]:
	var results: Array[ScriptFileData] = []
	var normalized_dir = dir_path.simplify_path()
	
	for file_path in all_file_paths:
		var file_dir = file_path.get_base_dir().simplify_path()
		
		if recursive:
			if file_dir.begins_with(normalized_dir):
				results.append(script_files[file_path])
		else:
			if file_dir == normalized_dir:
				results.append(script_files[file_path])
	
	return results

# Get file lines by path
func get_file_lines(file_path: String) -> PackedStringArray:
	var file_data = get_file_by_path(file_path)
	if file_data:
		return file_data.lines
	return PackedStringArray()

# Set metadata for a file
func set_file_metadata(file_path: String, key: String, value: Variant) -> bool:
	var file_data = get_file_by_path(file_path)
	if file_data:
		file_data.metadata[key] = value
		return true
	return false

# Get metadata from a file
func get_file_metadata(file_path: String, key: String, default: Variant = null) -> Variant:
	var file_data = get_file_by_path(file_path)
	if file_data and key in file_data.metadata:
		return file_data.metadata[key]
	return default

# Get all files with specific metadata key
func get_files_with_metadata(key: String) -> Array[ScriptFileData]:
	var results: Array[ScriptFileData] = []
	
	for file_path in all_file_paths:
		var file_data = script_files[file_path]
		if key in file_data.metadata:
			results.append(file_data)
	
	return results

# Export data to a dictionary (for saving/caching)
func export_to_dict() -> Dictionary:
	var export_data = {
		"file_count": get_file_count(),
		"files": {}
	}
	
	for file_path in all_file_paths:
		var file_data = script_files[file_path]
		export_data["files"][file_path] = {
			"content": file_data.content,
			"metadata": file_data.metadata
		}
	
	return export_data

# Import data from a dictionary (for loading cached data)
func import_from_dict(data: Dictionary) -> bool:
	if not data.has("files"):
		push_error("Invalid import data: missing 'files' key")
		return false
	
	clear_all()
	
	for file_path in data["files"]:
		var file_info = data["files"][file_path]
		if file_info.has("content"):
			add_script_file(file_path, file_info["content"])
			
			# Restore metadata if present
			if file_info.has("metadata"):
				var file_data = get_file_by_path(file_path)
				if file_data:
					file_data.metadata = file_info["metadata"]
	
	data_ready.emit()
	print("Imported %d script files" % get_file_count())
	return true

# Save cache to disk
func save_cache_to_disk(cache_path: String = "user://script_cache.dat") -> bool:
	var file = FileAccess.open(cache_path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot save cache: %s" % FileAccess.get_open_error())
		return false
	
	var export_data = export_to_dict()
	var json_string = JSON.stringify(export_data)
	file.store_string(json_string)
	file.close()
	
	print("Cache saved to: %s" % cache_path)
	return true

# Load cache from disk
func load_cache_from_disk(cache_path: String = "user://script_cache.dat") -> bool:
	if not FileAccess.file_exists(cache_path):
		push_warning("Cache file does not exist: %s" % cache_path)
		return false
	
	var file = FileAccess.open(cache_path, FileAccess.READ)
	if file == null:
		push_error("Cannot load cache: %s" % FileAccess.get_open_error())
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("Failed to parse cache JSON: %s" % json.get_error_message())
		return false
	
	var data = json.get_data()
	return import_from_dict(data)

# Debug: Print statistics
func print_statistics() -> void:
	print("=== Script Data Manager Statistics ===")
	print("Total files loaded: %d" % get_file_count())
	print("Unique file names: %d" % files_by_name.size())
	print("=====================================")
