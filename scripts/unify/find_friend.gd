extends Control
@onready var _search_box: LineEdit = $Panel/LineEdit_find
@onready var _list: ItemList = $Panel/ScrollContainer/ItemList

@export var placeholder_text: String = "提示文本"
@export var isClub: bool = false

# signal search_club(String)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_search_box.placeholder_text = placeholder_text
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass



func _on_line_edit_find_text_submitted(new_text:String):
	_list.clear()
	if isClub:
		var result = await Network.search_groups(new_text)
		print("俱乐部搜索",result)
		# emit_signal("search_club",new_text)
	else:
		var result = await Network.search_users(new_text)
		print("好友搜索",result)
		if result == null:
			_list.add_item("没有找到")
			return
		for user in result.users:
			if user.avatar_url:
				var texture = await load_texture_async(user.avatar_url)
				if texture:
					_list.add_item(user.username,texture)
			else:
				_list.add_item(user.username)
			print('信息',user.id,user.username,user.display_name,user.avatar_url)
		# emit_signal("search_room",new_text)
	pass # Replace with function body.


# 异步加载 Texture2D
func load_texture_async(url: String) -> Texture2D:
	var request = HTTPRequest.new()
	add_child(request)
    
	request.request(url)
	var result = await request.request_completed
    
	if result[0] != HTTPRequest.RESULT_SUCCESS:
		request.queue_free()
		return null
    
	var image = Image.new()

	var error = image.load_png_from_buffer(result[3])
	if error != OK:
		request.queue_free()
		return null
    
	image.resize(20,15)
	request.queue_free()
	return ImageTexture.create_from_image(image)