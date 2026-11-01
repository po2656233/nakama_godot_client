class_name TetrisTypes
extends RefCounted

## 俄罗斯方块公开类型（不引用任何资源，避免与 .tres 形成循环依赖）。
## 说明：TetrisShared 需要 preload 资源，若类型定义放在 TetrisShared 会导致
##       tetris_shared -> *.tres -> piece_data.gd -> TetrisShared 的循环依赖。

enum Tetromino {
	I,
	O,
	T,
	J,
	L,
	S,
	Z,
}
