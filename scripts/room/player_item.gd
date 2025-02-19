extends HBoxContainer


@onready var color_rect = $PlayerAvatar/ColorRect
var uid = ""
func _ready():
    # 设置玩家头像（这里使用随机颜色作为示例）
    color_rect.color = Color(randf(), randf(), randf())

func set_player_info(player_uid, player_name,player_avatar = null):
    uid = player_uid
    $PlayerName.text = player_name
    if player_avatar:
        if color_rect: 
            color_rect.hide()
        $PlayerAvatar/TextureRect.texture = await Util.load_texture_async(player_avatar)
    pass

func getUserName():
    return $PlayerName.text

func getUserId():
    return uid

func getAvatar():   
    return $PlayerAvatar/TextureRect.texture