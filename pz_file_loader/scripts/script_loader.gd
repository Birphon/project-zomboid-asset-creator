extends Node

# Signals
signal loading_started(file_count: int)
signal loading_progress(current: int, total: int, file_name: String)
signal loading_completed(file_count: int)
signal loading_failed(error_message: String)
signal folder_not_found()

# Configuration
const TARGET_FOLDER_RELATIVE = "../steamapps/common/ProjectZomboid/media/scripts/"
const VALID_EXTENSIONS = [".txt", ".script"]  # Add other extensions if needed

# Internal state
var script_files: Array[String] = []
var current_loading_index: int = 0
var is_loading: bool = false

func start_auto_load() -> void:
	print("\n=== Script Loader: Starting Auto-Load ===")
	
	# Strategy 1: Check saved configuration with multiple subfolders
	if ConfigManager.has_valid_root():
		print("Configuration found, checking subfolders...")
		var saved_paths = ConfigManager.get_subfolder_paths()
		
		if saved_paths.size() > 0:
			print("✓ Using %d configured subfolder(s)" % saved_paths.size())
			_load_from_multiple_paths(saved_paths)
			return
		else:
			print("⚠ Configuration exists but no valid subfolders found")
	
	# Strategy 2: Try auto-detection
	print("Attempting auto-detection...")
	var found_path = _find_scripts_folder()
	
	if found_path.is_empty():
		print("❌ Auto-detection failed - manual selection required\n")
		folder_not_found.emit()
		return
	
	print("✓ Auto-detection successful\n")
	load_from_path(found_path)
	
func _load_from_multiple_paths(folder_paths: Array[String]) -> void:
	if is_loading:
		push_warning("Loading already in progress")
		return
	
	is_loading = true
	script_files.clear()
	current_loading_index = 0
	
	# Scan all provided folders
	for folder_path in folder_paths:
		if DirAccess.dir_exists_absolute(folder_path):
			print("Scanning: ", folder_path)
			_scan_directory(folder_path)
		else:
			push_warning("Folder does not exist: %s" % folder_path)
	
	if script_files.is_empty():
		is_loading = false
		loading_failed.emit("No script files found in configured folders")
		return
	
	loading_started.emit(script_files.size())
	_load_next_file()

func load_from_path(folder_path: String) -> void:
	if is_loading:
		push_warning("Loading already in progress")
		return
	
	# Validate folder exists
	if not DirAccess.dir_exists_absolute(folder_path):
		loading_failed.emit("Folder does not exist: %s" % folder_path)
		return
	
	is_loading = true
	script_files.clear()
	current_loading_index = 0
	
	# Scan for all script files
	_scan_directory(folder_path)
	
	if script_files.is_empty():
		is_loading = false
		loading_failed.emit("No script files found in: %s" % folder_path)
		return
	
	# Notify start of loading
	loading_started.emit(script_files.size())
	
	# Begin loading files
	_load_next_file()

func _find_scripts_folder() -> String:
	print("=== Starting Project Zomboid Auto-Detection ===")
	debug_print_search_paths()  # Add this line for debugging
	
	# Strategy 0: Check saved configuration first
	if ConfigManager.has_valid_root():
		var root = ConfigManager.get_root_folder()
		var scripts_path = root.path_join("media").path_join("scripts")
		if DirAccess.dir_exists_absolute(scripts_path):
			print("Found via saved config: ", scripts_path)
			return scripts_path
	
	# Strategy 1: Check relative to executable
	var exe_path = OS.get_executable_path().get_base_dir()
	print("Executable path: ", exe_path)
	
	var potential_path = exe_path.path_join(TARGET_FOLDER_RELATIVE).simplify_path()
	if DirAccess.dir_exists_absolute(potential_path):
		print("Found via relative path: ", potential_path)
		return potential_path
	
	# Strategy 2: Search all possible Steam library locations
	var steam_paths = _get_all_steam_library_paths()
	print("Checking %d potential Steam library locations..." % steam_paths.size())
	
	for steam_path in steam_paths:
		var scripts_path = steam_path.path_join("steamapps/common/ProjectZomboid/media/scripts")
		print("  Checking: ", scripts_path)
		if DirAccess.dir_exists_absolute(scripts_path):
			print("✓ Found via Steam library: ", scripts_path)
			# Save this for next time
			var root = steam_path.path_join("steamapps/common/ProjectZomboid")
			ConfigManager.set_root_folder(root)
			ConfigManager.add_subfolder("scripts")
			return scripts_path
	
	# Strategy 3: Search common game installation directories
	var game_paths = _get_common_game_paths()
	print("Checking %d common game installation paths..." % game_paths.size())
	
	for game_path in game_paths:
		var scripts_path = game_path.path_join("ProjectZomboid/media/scripts")
		print("  Checking: ", scripts_path)
		if DirAccess.dir_exists_absolute(scripts_path):
			print("✓ Found via game path: ", scripts_path)
			var root = game_path.path_join("ProjectZomboid")
			ConfigManager.set_root_folder(root)
			ConfigManager.add_subfolder("scripts")
			return scripts_path
	
	# Strategy 4: Deep search of drives (Windows only, limited)
	if OS.get_name() == "Windows":
		print("Performing deep search on common drives...")
		var found = _deep_search_windows_drives()
		if not found.is_empty():
			print("✓ Found via deep search: ", found)
			return found
	
	print("❌ Could not auto-detect Project Zomboid folder")
	return ""

func _get_all_steam_library_paths() -> Array[String]:
	var paths: Array[String] = []
	
	match OS.get_name():
		"Windows":
			# Default Steam installations
			paths.append("C:/Program Files (x86)/Steam")
			paths.append("C:/Program Files/Steam")
			
			# Check all drive letters for Steam libraries
			for drive_letter in ["C", "D", "E", "F", "G", "H", "I", "J"]:
				paths.append("%s:/Steam" % drive_letter)
				paths.append("%s:/SteamLibrary" % drive_letter)
				paths.append("%s:/Games/Steam" % drive_letter)
				paths.append("%s:/Program Files (x86)/Steam" % drive_letter)
				paths.append("%s:/Program Files/Steam" % drive_letter)
			
			# Read Steam's libraryfolders.vdf to find all library locations
			var steam_config_paths = [
				"C:/Program Files (x86)/Steam/steamapps/libraryfolders.vdf",
				"C:/Program Files/Steam/steamapps/libraryfolders.vdf"
			]
			
			for config_path in steam_config_paths:
				var library_paths = _parse_steam_library_folders(config_path)
				paths.append_array(library_paths)
		
		"Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD":
			var home = OS.get_environment("HOME")
			
			# Standard Steam locations
			paths.append(home + "/.steam/steam")
			paths.append(home + "/.local/share/Steam")
			paths.append(home + "/.steam/debian-installation")
			
			# Flatpak Steam
			paths.append(home + "/.var/app/com.valvesoftware.Steam/.local/share/Steam")
			paths.append(home + "/.var/app/com.valvesoftware.Steam/data/Steam")
			
			# Snap Steam
			paths.append(home + "/snap/steam/common/.steam/steam")
			paths.append(home + "/snap/steam/common/.local/share/Steam")
			
			# Parse libraryfolders.vdf
			var config_locations = [
				home + "/.steam/steam/steamapps/libraryfolders.vdf",
				home + "/.local/share/Steam/steamapps/libraryfolders.vdf",
				home + "/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/libraryfolders.vdf"
			]
			
			for config_path in config_locations:
				var library_paths = _parse_steam_library_folders(config_path)
				paths.append_array(library_paths)
		
		"macOS":
			var home = OS.get_environment("HOME")
			paths.append(home + "/Library/Application Support/Steam")
			
			# Parse libraryfolders.vdf
			var config_path = home + "/Library/Application Support/Steam/steamapps/libraryfolders.vdf"
			var library_paths = _parse_steam_library_folders(config_path)
			paths.append_array(library_paths)
	
	# Remove duplicates and non-existent paths
	var unique_paths: Array[String] = []
	for path in paths:
		if path not in unique_paths and DirAccess.dir_exists_absolute(path):
			unique_paths.append(path)
	
	return unique_paths

func _parse_steam_library_folders(vdf_path: String) -> Array[String]:
	var library_paths: Array[String] = []
	
	if not FileAccess.file_exists(vdf_path):
		return library_paths
	
	print("  Parsing Steam library config: ", vdf_path)
	
	var file = FileAccess.open(vdf_path, FileAccess.READ)
	if file == null:
		return library_paths
	
	var content = file.get_as_text()
	file.close()
	
	# Parse VDF format to find library paths
	# Looking for lines like: "path"		"D:\\SteamLibrary"
	var regex = RegEx.new()
	regex.compile("\"path\"\\s+\"([^\"]+)\"")
	
	for result in regex.search_all(content):
		var path = result.get_string(1)
		# Convert Windows path format
		path = path.replace("\\\\", "/")
		
		if DirAccess.dir_exists_absolute(path):
			library_paths.append(path)
			print("    Found Steam library: ", path)
	
	return library_paths

func _get_common_game_paths() -> Array[String]:
	var paths: Array[String] = []
	
	match OS.get_name():
		"Windows":
			# Epic Games Store
			paths.append("C:/Program Files/Epic Games")
			
			# GOG Galaxy
			paths.append("C:/GOG Games")
			paths.append("C:/Program Files (x86)/GOG Galaxy/Games")
			
			# Xbox Game Pass
			paths.append("C:/XboxGames")
			
			# Generic game folders
			for drive in ["C", "D", "E", "F"]:
				paths.append("%s:/Games" % drive)
				paths.append("%s:/Program Files/Games" % drive)
		
		"Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD":
			var home = OS.get_environment("HOME")
			paths.append(home + "/Games")
			paths.append(home + "/.wine/drive_c/Program Files (x86)")
		
		"macOS":
			var home = OS.get_environment("HOME")
			paths.append(home + "/Applications")
			paths.append("/Applications")
	
	return paths

func _deep_search_windows_drives() -> String:
	# Only search common drives with reasonable depth limit
	var drives_to_check = ["C", "D", "E", "F"]
	
	for drive in drives_to_check:
		var drive_root = "%s:/" % drive
		if not DirAccess.dir_exists_absolute(drive_root):
			continue
		
		# Check common folder names that might contain games
		var common_folders = [
			"Steam",
			"SteamLibrary", 
			"Games",
			"Program Files (x86)/Steam",
			"Program Files/Steam"
		]
		
		for folder in common_folders:
			var search_path = drive_root.path_join(folder).path_join("steamapps/common/ProjectZomboid/media/scripts")
			if DirAccess.dir_exists_absolute(search_path):
				var root = drive_root.path_join(folder).path_join("steamapps/common/ProjectZomboid")
				ConfigManager.set_root_folder(root)
				ConfigManager.add_subfolder("scripts")
				return search_path
	
	return ""

func _get_common_steam_paths() -> Array[String]:
	var paths: Array[String] = []
	
	match OS.get_name():
		"Windows":
			paths.append("C:/Program Files (x86)/Steam")
			paths.append("C:/Program Files/Steam")
			paths.append("D:/Steam")
			paths.append("E:/Steam")
			# Add more drive letters if needed
			for drive in ["F", "G", "H"]:
				paths.append("%s:/Steam" % drive)
				paths.append("%s:/SteamLibrary" % drive)
		
		"Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD":
			var home = OS.get_environment("HOME")
			paths.append(home + "/.steam/steam")
			paths.append(home + "/.local/share/Steam")
			paths.append(home + "/.var/app/com.valvesoftware.Steam/.local/share/Steam")  # Flatpak
		
		"macOS":
			var home = OS.get_environment("HOME")
			paths.append(home + "/Library/Application Support/Steam")
	
	return paths

func _scan_directory(dir_path: String, recursive: bool = true) -> void:
	var dir = DirAccess.open(dir_path)
	
	if dir == null:
		push_error("Failed to open directory: %s" % dir_path)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var full_path = dir_path.path_join(file_name)
		
		if dir.current_is_dir():
			# Recursively scan subdirectories
			if recursive and file_name != "." and file_name != "..":
				_scan_directory(full_path, recursive)
		else:
			# Check if file has valid extension
			if _is_valid_script_file(file_name):
				script_files.append(full_path)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

func _is_valid_script_file(file_name: String) -> bool:
	# Accept files with valid extensions or no extension
	var extension = file_name.get_extension().to_lower()
	
	if extension.is_empty():
		return true  # Files without extension
	
	return ("." + extension) in VALID_EXTENSIONS

func _load_next_file() -> void:
	if current_loading_index >= script_files.size():
		# All files loaded
		_finalize_loading()
		return
	
	var file_path = script_files[current_loading_index]
	var file_name = file_path.get_file()
	
	# Emit progress
	loading_progress.emit(current_loading_index + 1, script_files.size(), file_name)
	
	# Read file content
	var content = _read_file(file_path)
	
	if content != null:
		# Store in global data manager
		ScriptDataManager.add_script_file(file_path, content)
	else:
		push_warning("Failed to read file: %s" % file_path)
	
	current_loading_index += 1
	
	# Continue loading next frame to avoid blocking
	_load_next_file.call_deferred()

func _read_file(file_path: String) -> String:
	var file = FileAccess.open(file_path, FileAccess.READ)
	
	if file == null:
		push_error("Cannot open file: %s (Error: %s)" % [file_path, FileAccess.get_open_error()])
		return ""
	
	var content = file.get_as_text()
	file.close()
	
	return content

func _finalize_loading() -> void:
	is_loading = false
	loading_completed.emit(script_files.size())
	print("Successfully loaded %d script files" % script_files.size())

# Public API for querying loaded files
func get_loaded_file_count() -> int:
	return script_files.size()

func get_loaded_file_paths() -> Array[String]:
	return script_files.duplicate()

func is_currently_loading() -> bool:
	return is_loading

func debug_print_search_paths() -> void:
	print("\n=== Debug: All Search Paths ===")
	print("Steam Libraries:")
	for path in _get_all_steam_library_paths():
		print("  ", path)
	print("\nGame Paths:")
	for path in _get_common_game_paths():
		print("  ", path)
	print("===============================\n")
