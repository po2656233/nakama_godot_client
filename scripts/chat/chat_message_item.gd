class_name ChatMessageItem
extends MarginContainer

# 消息类型枚举
enum MessageType {
    SYSTEM,
    NORMAL,
    IMAGE,
    VOICE,
    FILE,
    EMOJI,
    SELF
}

# 信号
signal message_deleted(message_id: String)
signal message_copied(content: String)
signal voice_play_requested(voice_path: String)
signal file_download_requested(file_path: String)

# 节点引用
var avatar: TextureRect
var name_label: Label
var content: RichTextLabel
var bubble: PanelContainer
var timestamp_label: Label
var image_container: TextureRect
var context_menu: PopupMenu
var voice_player: AudioStreamPlayer
var voice_button: Button
var file_container: HBoxContainer
var read_status: Label
var emoji_container: GridContainer
var download_button: Button
var progress_bar: ProgressBar

# 消息数据
var message_id: String
var message_data: Dictionary
var is_read: bool = false
var is_deleted: bool = false
var voice_duration: float = 0.0

# 配置
const AVATAR_SIZE = 40
const BUBBLE_MARGIN = 10
const MAX_BUBBLE_WIDTH = 400

# 表情映射
const EMOJI_MAP = {
    ":smile:": "😊",
    ":sad:": "😢",
    ":laugh:": "😄",
    ":heart:": "❤️",
    ":thumbsup:": "👍",
    ":thumbsdown:": "👎",
    ":angry:": "😠",
    ":surprised:": "😮",
    ":wink:": "😉",
    ":cry:": "😭"
}

func _init():
    custom_minimum_size.y = 50
    add_theme_constant_override("margin_top", 5)
    add_theme_constant_override("margin_bottom", 5)
    
    # 创建水平布局
    var h_box = HBoxContainer.new()
    h_box.add_theme_constant_override("separation", 10)
    add_child(h_box)
    
    # 创建头像
    avatar = TextureRect.new()
    avatar.custom_minimum_size = Vector2(AVATAR_SIZE, AVATAR_SIZE)
    avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    h_box.add_child(avatar)
    
    # 创建消息容器
    var message_container = VBoxContainer.new()
    message_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    h_box.add_child(message_container)
    
    # 创建名字标签
    name_label = Label.new()
    name_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
    message_container.add_child(name_label)
    
    # 创建气泡容器
    bubble = PanelContainer.new()
    message_container.add_child(bubble)
    
    # 创建富文本标签
    content = RichTextLabel.new()
    content.bbcode_enabled = true
    content.fit_content = true
    content.custom_minimum_size.x = 100
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.scroll_active = false
    bubble.add_child(content)
    
    # 创建图片容器
    image_container = TextureRect.new()
    image_container.custom_minimum_size = Vector2(200, 200)
    image_container.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    image_container.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    image_container.visible = false
    bubble.add_child(image_container)
    
    # 创建时间戳标签
    timestamp_label = Label.new()
    timestamp_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
    timestamp_label.add_theme_font_size_override("font_size", 12)
    message_container.add_child(timestamp_label)
    
    # 创建右键菜单
    context_menu = PopupMenu.new()
    add_child(context_menu)
    context_menu.add_item("复制", 0)
    context_menu.add_item("撤回", 1)
    context_menu.id_pressed.connect(_on_context_menu_pressed)
    
    # 创建语音播放器
    voice_player = AudioStreamPlayer.new()
    add_child(voice_player)
    voice_player.finished.connect(_on_voice_finished)
    
    # 创建已读状态标签
    read_status = Label.new()
    read_status.add_theme_font_size_override("font_size", 12)
    read_status.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
    message_container.add_child(read_status)

func setup_message(data: Dictionary):
    message_data = data
    message_id = data.get("message_id", "")
    
    # 设置头像
    if data.has("avatar"):
        avatar.texture = data.get("avatar")
    else:
        # 设置默认头像
        var default_avatar = PlaceholderTexture2D.new()
        default_avatar.size = Vector2(AVATAR_SIZE, AVATAR_SIZE)
        avatar.texture = default_avatar
    
    # 设置名字
    name_label.text = data.get("sender", "Unknown")
    
    # 设置时间戳
    timestamp_label.text = data.get("timestamp", Time.get_time_string_from_system())
    
    # 处理不同类型的消息
    match data.get("type", MessageType.NORMAL):
        MessageType.SYSTEM:
            _setup_system_message(data.get("content", ""))
        MessageType.IMAGE:
            _setup_image_message(data.get("content", ""))
        MessageType.VOICE:
            _setup_voice_message(data)
        MessageType.FILE:
            _setup_file_message(data)
        MessageType.EMOJI:
            _setup_emoji_message(data)
        _:
            _setup_normal_message(data.get("content", ""), data.get("is_self", false))
    
    # 设置已读状态
    update_read_status(data.get("is_read", false))

func _setup_system_message(content_text: String):
    content.visible = true
    image_container.visible = false
    content.text = "[center][color=#888888]" + content_text + "[/color][/center]"
    _setup_bubble_style(Color(0.1, 0.1, 0.1, 0.1))

func _setup_normal_message(content_text: String, is_self: bool):
    content.visible = true
    image_container.visible = false
    content.text = content_text
    
    if is_self:
        _setup_bubble_style(Color(0.2, 0.6, 1.0, 0.2))
        # 调整布局为右对齐
        var h_box = get_child(0) as HBoxContainer
        h_box.move_child(avatar, 1)
        content.text_direction = TEXT_DIRECTION_RTL 
    else:
        _setup_bubble_style(Color(0.1, 0.1, 0.1, 0.1))
        content.text_direction = TEXT_DIRECTION_LTR 

func _setup_image_message(image_path: String):
    content.visible = false
    image_container.visible = true
    
    # 加载图片
    var image = Image.new()
    var error = image.load(image_path)
    if error == OK:
        var texture = ImageTexture.create_from_image(image)
        image_container.texture = texture
    
    _setup_bubble_style(Color(0.1, 0.1, 0.1, 0.0))

func _setup_voice_message(data: Dictionary):
    content.visible = false
    
    # 创建语音按钮
    voice_button = Button.new()
    voice_button.text = "▶️ " + str(data.get("duration", 0.0)) + "s"
    voice_button.pressed.connect(_on_voice_button_pressed)
    bubble.add_child(voice_button)
    
    voice_duration = data.get("duration", 0.0)

func _setup_file_message(data: Dictionary):
    content.visible = false
    
    # 创建文件容器
    file_container = HBoxContainer.new()
    bubble.add_child(file_container)
    
    # 添加文件图标
    var file_icon = TextureRect.new()
    # 设置适当的文件图标...
    file_container.add_child(file_icon)
    
    # 添加文件信息
    var file_info = VBoxContainer.new()
    file_container.add_child(file_info)
    
    var file_name = Label.new()
    file_name.text = data.get("file_name", "Unknown file")
    file_info.add_child(file_name)
    
    var file_size = Label.new()
    file_size.text = _format_file_size(data.get("file_size", 0))
    file_info.add_child(file_size)
    
    # 添加下载按钮
    download_button = Button.new()
    download_button.text = "下载"
    download_button.pressed.connect(_on_download_button_pressed)
    file_container.add_child(download_button)
    
    # 添加进度条
    progress_bar = ProgressBar.new()
    progress_bar.visible = false
    file_container.add_child(progress_bar)

func _setup_emoji_message(data: Dictionary):
    content.visible = true
    var emoji_text = data.get("content", "")
    
    # 替换表情符号
    for key in EMOJI_MAP:
        emoji_text = emoji_text.replace(key, EMOJI_MAP[key])
    
    content.text = emoji_text

func _setup_bubble_style(color: Color):
    var style = StyleBoxFlat.new()
    style.bg_color = color
    style.corner_radius_top_left = 15
    style.corner_radius_top_right = 15
    style.corner_radius_bottom_left = 15
    style.corner_radius_bottom_right = 15
    style.content_margin_left = BUBBLE_MARGIN
    style.content_margin_right = BUBBLE_MARGIN
    style.content_margin_top = BUBBLE_MARGIN
    style.content_margin_bottom = BUBBLE_MARGIN
    bubble.add_theme_stylebox_override("panel", style)

func update_read_status(is_read_1: bool):
    self.is_read = is_read_1
    read_status.text = "已读" if is_read_1 else "未读"
    read_status.visible = message_data.get("is_self", false)

func _on_context_menu_pressed(id: int):
    match id:
        0: # 复制
            if not is_deleted:
                DisplayServer.clipboard_set(content.text)
                message_copied.emit(content.text)
        1: # 撤回
            if not is_deleted:
                is_deleted = true
                content.text = "[i][color=#888888]消息已撤回[/color][/i]"
                message_deleted.emit(message_id)

func _on_voice_button_pressed():
    if voice_player.playing:
        voice_player.stop()
        voice_button.text = "▶️ " + str(voice_duration) + "s"
    else:
        voice_play_requested.emit(message_data.get("voice_path", ""))
        voice_button.text = "⏹️ " + str(voice_duration) + "s"

func _on_voice_finished():
    voice_button.text = "▶️ " + str(voice_duration) + "s"

func _on_download_button_pressed():
    file_download_requested.emit(message_data.get("file_path", ""))

func update_download_progress(progress: float):
    if progress_bar:
        progress_bar.visible = true
        progress_bar.value = progress
        if progress >= 100:
            progress_bar.visible = false
            download_button.text = "已下载"

func _format_file_size(size_1: int) -> String:
    if size_1 < 1024:
        return str(size_1) + " B"
    elif size_1 < 1024 * 1024:
        return str(size_1 / 1024.0).pad_decimals(2) + " KB"
    else:
        return str(size_1 / 1024.0 / 1024.0).pad_decimals(2) + " MB"

func _gui_input(event: InputEvent):
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
            context_menu.popup(Rect2i(get_global_mouse_position(), Vector2i(100, 100)))
