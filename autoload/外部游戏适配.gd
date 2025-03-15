@tool
extends Node

const EXCLUDE_DIRS := ["scenes", "scripts", "assets", ".git", ".github"]

func reorganize_files(base_dir: String = ".", game_name: String = "") -> void:
    if game_name.is_empty():
        game_name = _get_parent_dir_name()
    
    var processed := PackedStringArray()
    
    # Step 1: 创建game/游戏名目录结构
    _process_top_dirs(base_dir, game_name, processed)
    
    # Step 2: 分类文件
    _classify_files(base_dir, game_name)
    
    # Step 3: 清理空目录
    _clean_empty_dirs(base_dir)

func _get_parent_dir_name() -> String:
    return ProjectSettings.globalize_path("res://").get_file()

func _process_top_dirs(base_dir: String, game_name: String, processed: PackedStringArray) -> void:
    var dir := DirAccess.open(base_dir)
    if not dir:
        push_error("无法打开目录: %s" % base_dir)
        return
    
    for entry in dir.get_directories():
        if EXCLUDE_DIRS.has(entry):
            continue
        
        var entry_path := dir.get_current_dir().path_join(entry)
        var dest_dir := entry_path.path_join("game").path_join(game_name)
        
        if DirAccess.dir_exists_absolute(dest_dir):
            continue
        
        _move_contents(entry_path, dest_dir, processed)

func _move_contents(src: String, dest: String, processed: PackedStringArray) -> void:
    var src_dir := DirAccess.open(src)
    if not src_dir:
        return
    
    DirAccess.make_dir_recursive_absolute(dest)
    
    for item in src_dir.get_directories():
        var src_path := src.path_join(item)
        var dest_path := dest.path_join(item)
        _safe_rename(src_path, dest_path)
        processed.append(src_path)
    
    for file in src_dir.get_files():
        var src_path := src.path_join(file)
        var dest_path := dest.path_join(file)
        _safe_rename(src_path, dest_path)
        processed.append(src_path)

func _classify_files(base_dir: String, game_name: String) -> void:
    var dir := DirAccess.open(base_dir)
    if not dir:
        return
    
    dir.include_hidden = false
    dir.include_navigational = false
    dir.list_dir_begin()
    
    var file := dir.get_next()
    while file != "":
        var full_path := dir.get_current_dir().path_join(file)
        if dir.current_is_dir():
            _process_subdir(full_path, base_dir, game_name)
        else:
            _handle_file(full_path, base_dir, game_name)
        file = dir.get_next()

func _process_subdir(path: String, base_dir: String, game_name: String) -> void:
    var sub_dir := DirAccess.open(path)
    if sub_dir:
        sub_dir.list_dir_begin()
        var entry := sub_dir.get_next()
        while entry != "":
            var full_path := path.path_join(entry)
            if sub_dir.current_is_dir():
                _process_subdir(full_path, base_dir, game_name)
            else:
                _handle_file(full_path, base_dir, game_name)
            entry = sub_dir.get_next()

func _handle_file(file_path: String, base_dir: String, game_name: String) -> void:
    var file_name := file_path.get_file()
    var ext := file_name.get_extension().to_lower()
    
    if _is_in_target_path(file_path, game_name):
        return
    
    match ext:
        "tscn": _move_to_category(file_path, base_dir, "scenes/game/%s" % game_name)
        "gd": _move_to_category(file_path, base_dir, "scripts/game/%s" % game_name)
        "tres": _move_to_category(file_path, base_dir, "themes/game/%s" % game_name)
        "gdshader": _move_to_category(file_path, base_dir, "shaders/game/%s" % game_name)
        "png", "jpg", "webp": _move_to_category(file_path, base_dir, "assets/game/%s/image" % game_name)
        "wav", "ogg": _move_to_category(file_path, base_dir, "assets/game/%s/sound" % game_name)
        "ttf", "otf": _move_to_category(file_path, base_dir, "assets/game/%s/font" % game_name)
        "import", "uid": _delete_file(file_path)

func _is_in_target_path(path: String, game_name: String) -> bool:
    return path.contains("scenes/game") || path.contains("assets/game/%s" % game_name)

func _move_to_category(src: String, base_dir: String, category: String) -> void:
    var rel_path := src.replace(base_dir, "")
    var parts := rel_path.split("/", false)
    
    if parts.size() > 1:
        parts.remove_at(0)
        var preserved := "/".join(parts.slice(0, parts.size() - 1))
        var dest := base_dir.path_join(category).path_join(preserved).path_join(src.get_file())
        _safe_rename(src, dest)

func _safe_rename(src: String, dest: String) -> void:
    if src == dest:
        return
    
    var dir := DirAccess.open(src.get_base_dir())
    if not dir:
        return
    
    DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
    
    if dir.dir_exists(dest) || dir.file_exists(dest):
        push_warning("目标已存在: %s" % dest)
        return
    
    var error := dir.rename(src, dest)
    if error != OK:
        push_error("移动失败: %s -> %s (错误码: %d)" % [src, dest, error])

func _clean_empty_dirs(base_dir: String) -> void:
    var dir := DirAccess.open(base_dir)
    if not dir:
        return
    
    dir.list_dir_begin()
    var entry := dir.get_next()
    while entry != "":
        var path := base_dir.path_join(entry)
        if dir.current_is_dir() && _is_dir_empty(path):
            DirAccess.remove_absolute(path)
            print("已删除空目录: ", path)
        entry = dir.get_next()

func _is_dir_empty(path: String) -> bool:
    var dir := DirAccess.open(path)
    if not dir:
        return false
    
    dir.list_dir_begin()
    var count := 0
    var entry := dir.get_next()
    while entry != "":
        count += 1
        if count > 0:
            break
        entry = dir.get_next()
    return count == 0

func _delete_file(path: String) -> void:
    var dir := DirAccess.open(path.get_base_dir())
    if dir:
        dir.remove(path)