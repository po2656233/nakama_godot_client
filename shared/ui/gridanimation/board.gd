extends Control

var gridScene = preload("res://shared/ui/gridanimation/grid.tscn")
var allGrid = []
@export var widthLen = 10
var count = 0
var missCount = 0
func _ready() -> void:
	createGrid()
	playGridAnimation()

func createGrid():
	var offset = 5
	for i in range(widthLen):
		for o in range(widthLen):
			var gz = gridScene.instantiate()
			$MarginContainer/Control.add_child(gz)
			gz.position = Vector2(i*50+i*offset,o*50+o*offset)
			allGrid.append(gz)
			gz.mainScene = self
			gz.id = allGrid.size()-1
	count = allGrid.size()
	print("创建 %d 个格子" % count)		


func getXieGridNumber(n=widthLen):
	var diagonals = []
	# 遍历对角线编号 k
	for k in range(2 * n - 1):
		var diagonal = []
		# 对角线 k 上，满足 x + y = k 的坐标 (x, y)
		for x in range(n):
			var y = k - x
			if y >= 0 and y < n:
				# 转换为一维数组的编号
				diagonal.append(x * n + y)
		diagonals.append(diagonal)
	return diagonals

func playGridAnimation():
	var interval = 0.05
	var tween = create_tween()
	# 非阻塞模式
	tween.set_parallel(true)
	var diagonal_indices = getXieGridNumber()
	for i in range(diagonal_indices.size()):
		#print("对角线 %d: %s" % [i, diagonal_indices[i]])
		for a in diagonal_indices[i]:
			var target = allGrid[a]
			tween.tween_property(target,"scale",Vector2(0.8,0.8),0.1).set_delay(interval*i)
			tween.tween_property(target,"scale",Vector2(1.0,1.0),0.1).set_delay(interval*i+0.1)
			tween.tween_property(target,"scale",Vector2(0.9,0.9),0.1).set_delay(interval*i+0.2)
			tween.tween_property(target,"scale",Vector2(1.0,1.0),0.1).set_delay(interval*i+0.3)
	pass

func clickRoundGrid(index):
	# 一维索引转二维索引
	var _index = [index%widthLen, index/widthLen]
	for _x in range(-1,2):
		for _y in range(-1,2):
			var x = _index[0]+_x
			var y = _index[1]+_y
			# 二维索引转一维索引
			if x >= 0 and y >= 0 and x < widthLen and y < widthLen:
				var _index_ = y * widthLen + x
				if allGrid.size() <= _index_:
					return
				var gz = allGrid[_index_]
				gz.autoClick()
	# print("点击了 %d" % index)
	missCount+=1
	if missCount >= count:
		missCount = 0
		for gz in allGrid:
			gz.reset();
