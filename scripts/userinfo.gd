extends Control

@onready var userheadLabel = $VBoxContainer/HBoxContainerHead/TR_HEAD
@onready var usernameLabel = $VBoxContainer/account
@onready var levelLabel = $VBoxContainer/TR_LEVEL
@onready var diamondLabel = $VBoxContainer/HBoxContainer/diamond
@onready var goldLabel = $VBoxContainer/HBoxContainer2/gold
@onready var douziLabel = $VBoxContainer/HBoxContainer3/douzi

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var username = ProjectSettings.get("username")
	if username:
		usernameLabel.text = username
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


