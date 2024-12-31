extends Control

@export var items_per_page: int = 4
@export var button_size: Vector2 = Vector2(200, 200)
@export var spacing: float = 20.0

var current_page: int = 0
var total_pages: int = 0
var items: Array = []

@onready var item_container = $MarginContainer/HBoxContainer/VBoxContainer/ItemContainer
@onready var prev_button = $MarginContainer/HBoxContainer/PrevButton
@onready var next_button = $MarginContainer/HBoxContainer/NextButton
@onready var page_label = $MarginContainer/HBoxContainer/VBoxContainer/PageLabel

func _ready():
	# # Sample items - replace with your actual items
	for i in range(10):
		items.append({
			"image_path": "res://icon.svg",
			"text": "Item " + str(i + 1)
		})


	update_total_pages()
	update_page_display()
	pass

func update_total_pages():
	total_pages = ceil(float(items.size()) / items_per_page)

func append(text:String, image_path:String):
	items.append({
		"image_path": image_path,
		"text": text
	})
	update_total_pages()
	update_page_display()
	pass


func update_page_display():
	# Clear existing items
	for child in item_container.get_children():
		child.queue_free()
	
	# Calculate start and end indices for current page
	var start_idx = current_page * items_per_page
	var end_idx = min(start_idx + items_per_page, items.size())
	
	# Create buttons for current page
	for i in range(start_idx, end_idx):
		var button = TextureButton.new()
		var texture = load(items[i]["image_path"])
		button.texture_normal = texture
		button.custom_minimum_size = button_size
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_SCALE 
		
		var label = Label.new()
		label.text = items[i]["text"]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		label.custom_minimum_size = button_size
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		button.add_child(label)
		item_container.add_child(button)
	
	# Update navigation buttons and page label
	prev_button.disabled = current_page == 0
	next_button.disabled = current_page >= total_pages - 1
	page_label.text = "%d/%d" % [current_page + 1, total_pages]

func _on_prev_button_pressed():
	if current_page > 0:
		current_page -= 1
		update_page_display()

func _on_next_button_pressed():
	if current_page < total_pages - 1:
		current_page += 1
		update_page_display()
