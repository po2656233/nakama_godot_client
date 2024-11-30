class_name ChatSystem
extends Control

# 信号
signal message_sent(content: String)
signal voice_record_started
signal voice_record_stopped(path: String)
signal file_selected(path: String)
signal emoji_selected(emoji_code: String)
signal connection_status_changed(status: String)
signal chat_join_status_changed(status: String)

# 节点引用
var scroll_container: ScrollContainer
var message_container: VBoxContainer
var input_container: HBoxContainer
var input_field: LineEdit
var send_button: Button
var emoji_button: Button
var voice_button: Button
var file_button: Button
var emoji_panel: PopupPanel
var voice_recorder: AudioStreamPlayer  # 实际应该使用 AudioStreamRecord
var recording_label: Label

# 配置
var max_messages: int = 100
var auto_scroll: bool = true
var is_recording: bool = false

# 消息管理
var messages: Dictionary = {}  # message_id: message_item
var pending_reads: Array = []  # 待确认已读的消息ID

func _init():
    # 创建主布局
    var main_container = VBoxContainer.new()
    main_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    main_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
    add_child(main_container)
    
    # 创建滚动容器
    scroll_container = ScrollContainer.new()
    scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
    main_container.add_child(scroll_container)
    
    # 创建消息容器
    message_container = VBoxContainer.new()
    message_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll_container.add_child(message_container)
    
    # 创建输入容器
    input_container = HBoxContainer.new()
    input_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    main_container.add_child(input_container)
    
    # 创建表情按钮
    emoji_button = Button.new()
    emoji_button.text = "😊"
    input_container.add_child(emoji_button)
    
    # 创建语音按钮
    voice_button = Button.new()
    voice_button.text = "🎤"
    input_container.add_child(voice_button)
    
    # 创建文件按钮
    file_button = Button.new()
    file_button.text = "📎"
    input_container.add_child(file_button)
    
    # 创建输入框
    input_field = LineEdit.new()
    input_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    input_container.add_child(input_field)
    
    # 创建发送按钮
    send_button = Button.new()
    send_button.text = "发送"
    input_container.add_child(send_button)
    
    # 创建录音标签
    recording_label = Label.new()
    recording_label.text = "正在录音..."
    recording_label.visible = false
    input_container.add_child(recording_label)
    
    # 创建表情面板
    _setup_emoji_panel()
    
    
    # 连接Nakama信号
    Network.chat_message_received.connect(_on_nakama_message_received)
    Network.chat_presence_changed.connect(_on_nakama_presence_changed)
    Network.chat_history_received.connect(_on_nakama_history_received)
    
    # 连接信号
    send_button.pressed.connect(_on_send_pressed)
    emoji_button.pressed.connect(_on_emoji_button_pressed)
    voice_button.button_down.connect(_on_voice_button_down)
    voice_button.button_up.connect(_on_voice_button_up)
    file_button.pressed.connect(_on_file_button_pressed)
    input_field.text_submitted.connect(_on_text_submitted)
    scroll_container.get_v_scroll_bar().value_changed.connect(_on_scroll_changed)

func _setup_emoji_panel():
    emoji_panel = PopupPanel.new()
    add_child(emoji_panel)
    
    var grid = GridContainer.new()
    grid.columns = 5
    emoji_panel.add_child(grid)
    
    # 添加表情按钮
    for emoji_code in ChatMessageItem.EMOJI_MAP:
        var emoji_btn = Button.new()
        emoji_btn.text = ChatMessageItem.EMOJI_MAP[emoji_code]
        emoji_btn.pressed.connect(func(): _on_emoji_selected(emoji_code))
        grid.add_child(emoji_btn)

func add_message(data: Dictionary):
    # 生成消息ID
    if not data.has("message_id"):
        data["message_id"] = str(Time.get_unix_time_from_system()) + "_" + str(randi())
    
    # 如果超过最大消息数，删除最早的消息
    if message_container.get_child_count() >= max_messages:
        var oldest_message = message_container.get_child(0)
        message_container.remove_child(oldest_message)
        oldest_message.queue_free()
    
    var message_item = ChatMessageItem.new()
    message_container.add_child(message_item)
    message_item.setup_message(data)
    
    # 存储消息引用
    messages[data["message_id"]] = message_item
    
    # 连接消息信号
    message_item.message_deleted.connect(_on_message_deleted.bind(data["message_id"]))
    message_item.message_copied.connect(_on_message_copied)
    message_item.voice_play_requested.connect(_on_voice_play_requested)
    message_item.file_download_requested.connect(_on_file_download_requested)
    
    # 处理未读消息
    if not data.get("is_self", false) and not data.get("is_read", false):
        pending_reads.append(data["message_id"])
    
    if auto_scroll:
        scroll_to_bottom()

func add_system_message(content: String):
    add_message({
        "type": ChatMessageItem.MessageType.SYSTEM,
        "content": content,
        "timestamp": Time.get_time_string_from_system()
    })

func add_image_message(image_path: String, is_self: bool = false):
    add_message({
        "type": ChatMessageItem.MessageType.IMAGE,
        "content": image_path,
        "is_self": is_self,
        "sender": "You" if is_self else "Other",
        "timestamp": Time.get_time_string_from_system()
    })

func add_voice_message(voice_path: String, duration: float, is_self: bool = true):
    add_message({
        "type": ChatMessageItem.MessageType.VOICE,
        "voice_path": voice_path,
        "duration": duration,
        "is_self": is_self,
        "sender": "You" if is_self else "Other",
        "timestamp": Time.get_time_string_from_system()
    })

func add_file_message(file_path: String, file_name: String, file_size: int, is_self: bool = true):
    add_message({
        "type": ChatMessageItem.MessageType.FILE,
        "file_path": file_path,
        "file_name": file_name,
        "file_size": file_size,
        "is_self": is_self,
        "sender": "You" if is_self else "Other",
        "timestamp": Time.get_time_string_from_system()
    })

func scroll_to_bottom():
    await get_tree().process_frame
    scroll_container.scroll_vertical = scroll_container.get_v_scroll_bar().max_value

func mark_messages_as_read():
    for message_id in pending_reads:
        if messages.has(message_id):
            messages[message_id].update_read_status(true)
    pending_reads.clear()

func _on_send_pressed():
    var text = input_field.text.strip_edges()
    if text.is_empty():
        return
    
    # 准备消息数据
    var message_data = {
        "type": ChatMessageItem.MessageType.NORMAL,
        "content": text,
        "timestamp": Time.get_time_string_from_system()
    }
    
    # 发送到Nakama
    var error = await Network.send_message(message_data)
    if error == OK:
        input_field.text = ""
    else:
        add_system_message("发送消息失败")

func _on_text_submitted(_text: String):
    _on_send_pressed()

func _on_emoji_button_pressed():
    emoji_panel.popup(Rect2i(emoji_button.global_position - Vector2(0, emoji_panel.size.y), emoji_panel.size))

func _on_emoji_selected(emoji_code: String):
    emoji_panel.hide()
    emoji_selected.emit(emoji_code)
    
    # 直接发送表情消息
    add_message({
        "type": ChatMessageItem.MessageType.EMOJI,
        "content": emoji_code,
        "is_self": true,
        "sender": "You",
        "timestamp": Time.get_time_string_from_system()
    })

func _on_voice_button_down():
    is_recording = true
    recording_label.visible = true
    voice_record_started.emit()

func _on_voice_button_up():
    if is_recording:
        is_recording = false
        recording_label.visible = false
        voice_record_stopped.emit("voice_record_path")  # 实际路径应由录音系统提供

func _on_file_button_pressed():
    var file_dialog = FileDialog.new()
    file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
    file_dialog.access = FileDialog.ACCESS_FILESYSTEM
    add_child(file_dialog)
    
    file_dialog.popup_centered(Vector2(800, 600))
    var file_path = await file_dialog.file_selected
    file_dialog.queue_free()
    
    # 上传文件到Nakama
    var result = await Network.upload_file(file_path)
    if result.has("error"):
        add_system_message("文件上传失败: " + result.error)
        return
    
    # 发送文件消息
    var message_data = {
        "type": ChatMessageItem.MessageType.FILE,
        "file_info": result
    }
    
    await Network.send_message(message_data)

func _on_message_deleted(message_id: String):
    # 处理消息撤回
    if messages.has(message_id):
        var msg = messages[message_id]
        print("消息撤回:", msg)
        # 可以在这里添加撤回动画效果
        # 可以发送撤回通知到服务器

func _on_message_copied(_content: String):
    # 可以添加复制成功的提示
    add_system_message("消息已复制到剪贴板")

func _on_voice_play_requested(voice_path: String):
    # 播放语音消息
    var stream = AudioStreamMP3.new()  # 或其他适当的音频流类型
    var error = stream.load(voice_path)
    if error == OK:
        var player = AudioStreamPlayer.new()
        add_child(player)
        player.stream = stream
        player.play()
        await player.finished
        player.queue_free()

func _on_file_download_requested(file_path: String):
    var message_item = messages.get(file_path)
    if not message_item:
        return
    
    # 开始下载进度显示
    message_item.update_download_progress(0)
    
    # 从Nakama下载文件
    var result = await Network.download_file({
        "path": file_path,
        "name": file_path.get_file()
    })
    
    if result.has("error"):
        message_item.update_download_progress(0)
        add_system_message("文件下载失败: " + result.error)
        return
    
    # 更新下载进度
    message_item.update_download_progress(100)

func _on_scroll_changed(value: float):
    var scroll_bar = scroll_container.get_v_scroll_bar()
    var threshold = 10
    if value >= scroll_bar.max_value - threshold:
        auto_scroll = true
    else:
        auto_scroll = false

func connect_to_nakama(email: String, password: String) -> Error:
    connection_status_changed.emit("连接中...")
    var error = await Network.connect_to_server(email, password)
    if error == OK:
        connection_status_changed.emit("已连接")
    else:
        connection_status_changed.emit("连接失败")
    return error

func join_chat_channel(channel_id: String) -> Error:
    chat_join_status_changed.emit("加入频道中...")
    var error = await Network.join_chat_channel(channel_id)
    if error == OK:
        chat_join_status_changed.emit("已加入频道")
        # 获取历史消息
        await Network.get_chat_history()
    else:
        chat_join_status_changed.emit("加入频道失败")
    return error

func _on_nakama_message_received(message: Dictionary):
    var content = message.content
    match content.type:
        ChatMessageItem.MessageType.NORMAL:
            add_message({
                "type": ChatMessageItem.MessageType.NORMAL,
                "content": content.content,
                "sender": message.sender,
                "is_self": message.is_self,
                "message_id": message.message_id,
                "timestamp": message.timestamp
            })
        ChatMessageItem.MessageType.FILE:
            add_file_message(
                content.file_info.path,
                content.file_info.name,
                content.file_info.size,
                message.is_self
            )
        ChatMessageItem.MessageType.VOICE:
            add_voice_message(
                content.voice_path,
                content.duration,
                message.is_self
            )

func _on_nakama_presence_changed(joins: Array, leaves: Array):
    for presence in joins:
        add_system_message(presence.username + " 加入了聊天")
    for presence in leaves:
        add_system_message(presence.username + " 离开了聊天")

func _on_nakama_history_received(messagelist: Array):
    for message in messagelist:
        _on_nakama_message_received(message)
