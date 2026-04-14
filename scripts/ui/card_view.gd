# CardView — Visual representation of a single playing card
#
# Why it exists:
#   The game logic works with Card objects (Resources) that have no knowledge of
#   how to display themselves. CardView bridges that data layer and Godot's node
#   tree. Every card the player sees — in hand, board, or well — is an instance
#   of this scene.
#
# What it does:
#   - Shows the card value top-left (ValueLabel) and suit symbol top-right (SuitSmall),
#     plus a large suit symbol centered vertically (SuitBig).
#   - Applies red color for hearts/diamonds, dark for spades/clubs.
#   - Supports face-down state: navy blue background with "?" instead of card data.
#   - Highlights with a golden border on mouse hover.
#   - Exposes set_selected() for game.gd to mark the currently chosen card.
#   - Emits card_clicked when the user clicks, without knowing what the parent does.
#
# Design:
#   Styles are built in code (StyleBoxFlat) rather than relying solely on the theme,
#   so each card can switch between normal / selected / face-down independently.
#   _apply_style() is the single place that decides which StyleBox is active.
#   _refresh() calls _apply_style() and then updates label text and colors.
#   Both setters (card_data, face_down) guard with is_inside_tree() so they are
#   safe to call before _ready() fires.

class_name CardView
extends PanelContainer

signal card_clicked(card_view: CardView)
signal card_drag_started(card_view: CardView)

const DRAG_THRESHOLD := 8.0

var _press_position: Vector2 = Vector2.ZERO
var _dragging: bool = false

@export var card_data: Card = null:
	set(v):
		card_data = v
		_refresh()

@export var face_down: bool = false:
	set(v):
		face_down = v
		_refresh()

var _is_selected: bool = false

@onready var value_label: Label = $MarginContainer/VBoxContainer/Top/ValueLabel
@onready var suit_small: Label  = $MarginContainer/VBoxContainer/Top/SuitSmall
@onready var suit_big: Label    = $MarginContainer/VBoxContainer/SuitBig

var _style_normal: StyleBoxFlat
var _style_selected: StyleBoxFlat
var _style_face_down: StyleBoxFlat

func _ready() -> void:
	_build_styles()
	_refresh()
	mouse_entered.connect(_on_hover_enter)
	mouse_exited.connect(_on_hover_exit)
	gui_input.connect(_on_gui_input)

# Build the three StyleBoxes once. Duplicating from _style_normal keeps
# shared properties (corners, margins) consistent.
func _build_styles() -> void:
	_style_normal = StyleBoxFlat.new()
	_style_normal.bg_color = Color("#F8F4E3")
	_style_normal.set_border_width_all(2)
	_style_normal.border_color = Color("#C8B88A")
	_style_normal.set_corner_radius_all(8)
	_style_normal.set_content_margin_all(10)

	_style_selected = _style_normal.duplicate()
	_style_selected.border_color = Color("#F5C518")
	_style_selected.set_border_width_all(3)

	_style_face_down = _style_normal.duplicate()
	_style_face_down.bg_color = Color("#1A3A5C")
	_style_face_down.border_color = Color("#2A5A8C")

# Called by game.gd to mark this card as the currently selected one.
func set_selected(selected: bool) -> void:
	_is_selected = selected
	_apply_style()

# Picks and applies the correct StyleBox based on current state.
func _apply_style() -> void:
	if face_down or card_data == null:
		add_theme_stylebox_override("panel", _style_face_down)
	elif _is_selected:
		add_theme_stylebox_override("panel", _style_selected)
	else:
		add_theme_stylebox_override("panel", _style_normal)

# Syncs labels and colors with current card_data / face_down state.
func _refresh() -> void:
	if not is_inside_tree():
		return
	_apply_style()
	if face_down or card_data == null:
		value_label.text = ""
		suit_small.text  = ""
		suit_big.text    = "?"
		suit_big.add_theme_color_override("font_color", Color("#4A6A8C"))
		return
	value_label.text = card_data.display_value()
	suit_small.text  = card_data.suit_symbol()
	suit_big.text    = card_data.suit_symbol()
	var is_red := card_data.suit in [Card.Suit.HEARTS, Card.Suit.DIAMONDS]
	var color  := Color("#CC2222") if is_red else Color("#111111")
	value_label.add_theme_color_override("font_color", color)
	suit_small.add_theme_color_override("font_color", color)
	suit_big.add_theme_color_override("font_color", color)

# Hover: golden border to signal interactivity, without moving the card
# (position offsets break HBoxContainer layout).
func _on_hover_enter() -> void:
	if face_down or card_data == null:
		return
	var style := (_style_selected if _is_selected else _style_normal).duplicate()
	style.border_color = Color("#F5C518")
	style.set_border_width_all(3)
	add_theme_stylebox_override("panel", style)

func _on_hover_exit() -> void:
	_apply_style()

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_position = event.global_position
			_dragging = false
		else:
			if not _dragging:
				card_clicked.emit(self)
			_dragging = false
	elif event is InputEventMouseMotion \
		 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if not _dragging:
			if event.global_position.distance_to(_press_position) > DRAG_THRESHOLD:
				_dragging = true
				card_drag_started.emit(self)
