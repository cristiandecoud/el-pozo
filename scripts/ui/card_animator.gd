class_name CardAnimator
extends CanvasLayer

const CardScene := preload("res://escenas/ui/card/card.tscn")

# Flies a ghost CardView from src_pos to dst_pos. Awaitable.
# Positions are in global screen coordinates.
func animate_move(card: Card, src_pos: Vector2, dst_pos: Vector2,
		duration: float) -> void:
	var cv: CardView = CardScene.instantiate()
	cv.card_data = card
	cv.custom_minimum_size = Vector2(PlayerAreaView.CARD_W, PlayerAreaView.CARD_H)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.position = src_pos
	add_child(cv)

	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(cv, "position", dst_pos, duration)
	await tween.finished
	cv.queue_free()
