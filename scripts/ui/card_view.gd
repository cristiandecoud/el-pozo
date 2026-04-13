class_name CardView
extends PanelContainer

signal card_clicked(card_view: CardView)

@export var card_data: Card = null:
	set(value):
		card_data = value
		_refresh()

@export var face_down: bool = false:
	set(value):
		face_down = value
		_refresh()

@onready var top_label: Label = $VBoxContainer/TopLabel
@onready var center_label: Label = $VBoxContainer/CenterLabel

func _ready() -> void:
	_refresh()
	gui_input.connect(_on_gui_input)

func _refresh() -> void:
	if not is_inside_tree():
		return
	if face_down or card_data == null:
		top_label.text = ""
		center_label.text = "?"
		return
	top_label.text = card_data.label()
	center_label.text = card_data.suit_symbol()
	var is_red := card_data.suit in [Card.Suit.HEARTS, Card.Suit.DIAMONDS]
	var color := Color.RED if is_red else Color(0.1, 0.1, 0.1)
	top_label.add_theme_color_override("font_color", color)
	center_label.add_theme_color_override("font_color", color)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
	   and event.button_index == MOUSE_BUTTON_LEFT:
		card_clicked.emit(self)
