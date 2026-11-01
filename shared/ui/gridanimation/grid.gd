extends Control


var mainScene
var id
var isClick = false
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func reset():
	isClick = false
	
# 按下按钮时按钮放大
func playAnim(target):
	if target.pivot_offset == Vector2(0.0,0.0):
		target.pivot_offset = target.size/2
	var tween = create_tween()
	tween.tween_property(target,"scale",Vector2(1.1,1.1),0.1)

# 松开按钮时按钮收缩回原尺寸
func playAnim2(target):
	var tween = create_tween()
	tween.tween_property(target,"scale",Vector2(1.0,1.0),0.1)
	await tween.finished

func singleGridAnimation(target=self):
	var tween = create_tween()
	# 非阻塞模式
	tween.set_parallel(true)
	tween.tween_property(target,"scale",Vector2(0.8,0.8),0.1)
	tween.tween_property(target,"scale",Vector2(1.0,1.0),0.1).set_delay(0.1)
	tween.tween_property(target,"scale",Vector2(0.9,0.9),0.1).set_delay(0.2)
	tween.tween_property(target,"scale",Vector2(1.0,1.0),0.1).set_delay(0.3)
	await get_tree().create_timer(0.05).timeout
	$AudioStreamPlayer2D.play()


func _on_texture_button_button_down() -> void:
	# print("button_down")
	playAnim($TextureButton/Panel)


func _on_texture_button_pressed() -> void:
	# print("button_pressed")
	await playAnim2($TextureButton/Panel)
	autoClick()


func autoClick():
	if not isClick:
		isClick = true
		await singleGridAnimation()
		mainScene.clickRoundGrid(id)
	
