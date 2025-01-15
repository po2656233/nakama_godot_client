extends HBoxContainer

func _ready():
    # 设置玩家头像（这里使用随机颜色作为示例）
    var color_rect = $PlayerAvatar/ColorRect
    color_rect.color = Color(randf(), randf(), randf())
