class_name CardPresentation
extends RefCounted

enum ContentState { EMPTY, FACE_DOWN, FACE_UP }

const FACE_DOWN_SYMBOL := "?"
const FACE_DOWN_COLOR := Color("#4A6A8C")
const RED_SUIT_COLOR := Color("#CC2222")
const DARK_SUIT_COLOR := Color("#111111")

var state: ContentState
var value_text: String
var suit_small_text: String
var suit_big_text: String
var font_color: Color

func _init(
	p_state: ContentState = ContentState.EMPTY,
	p_value_text: String = "",
	p_suit_small_text: String = "",
	p_suit_big_text: String = "",
	p_font_color: Color = FACE_DOWN_COLOR
) -> void:
	state = p_state
	value_text = p_value_text
	suit_small_text = p_suit_small_text
	suit_big_text = p_suit_big_text
	font_color = p_font_color

static func from_card(card: Card, is_face_down: bool) -> CardPresentation:
	if card == null:
		return CardPresentation.new()
	if is_face_down:
		return CardPresentation.new(
			ContentState.FACE_DOWN,
			"",
			"",
			FACE_DOWN_SYMBOL,
			FACE_DOWN_COLOR
		)
	var font_color := RED_SUIT_COLOR if card.is_red() else DARK_SUIT_COLOR
	var suit_symbol := card.suit_symbol()
	return CardPresentation.new(
		ContentState.FACE_UP,
		card.display_value(),
		suit_symbol,
		suit_symbol,
		font_color
	)
