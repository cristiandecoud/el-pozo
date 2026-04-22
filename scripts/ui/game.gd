# game.gd — Central coordinator for the game scene
#
# Responsibilities:
#   - Build and connect all sub-views (_ready).
#   - Translate raw UI events (clicks, drags, key presses) into TurnController calls.
#   - Update views in response to TurnController and GameManager signals.
#   - Manage Godot-specific concerns: pause, scene changes, node lifecycle.
#
# What it does NOT do:
#   - Own interaction state — that lives in TurnController.
#   - Decide turn flow rules (end-turn sequence, cancellation, bot orchestration).

extends Control

const PlayerAreaScene        := preload("res://escenas/ui/player_area/player_area.tscn")
const LadderScene            := preload("res://escenas/ui/ladder/ladder.tscn")
const HUDScene               := preload("res://escenas/ui/hud/hud.tscn")
const CardScene              := preload("res://escenas/ui/card/card.tscn")
const PauseMenuScene         := preload("res://escenas/ui/pause_menu/pause_menu.tscn")
const GameOverScene          := preload("res://escenas/ui/game_over/game_over.tscn")
const RivalBoardOverlayScene := preload("res://escenas/game/rival_board_overlay/rival_board_overlay.tscn")
const RivalAreaScene         := preload("res://escenas/game/rival_area/rival_area.tscn")

@onready var rivals_row:        HBoxContainer = $MainLayout/RivalsRow
@onready var human_row:         HBoxContainer = $MainLayout/HumanRow
@onready var ladders_container: HBoxContainer = $MainLayout/LaddersArea/LaddersContainer
@onready var deck_count:        Label         = $MainLayout/LaddersArea/DeckArea/DeckCard/DeckCount
@onready var main_layout:       VBoxContainer = $MainLayout

var game_manager:    GameManager
var turn_controller: TurnController
var _card_animator:  CardAnimator

var human_area: PlayerAreaView
var hud: HUDView
var _pause_menu: PauseMenu = null
var _rival_views: Dictionary = {}      # Player → RivalAreaView  (3+ bots, compact)
var _rival_areas: Array[PlayerAreaView] = []  # ordered by bot index (1–2 bots, full view)
var _rival_overlay: RivalBoardOverlay = null

# Tracks the CardView currently highlighted so we can deselect it on demand.
var _selected_card_view: CardView = null

# Drag & drop state (pure UI — no game logic)
var _drag_ghost:       CardView = null
var _drag_source_view: CardView = null
var _drag_is_end_turn: bool     = false
var _add_ladder_btn:   Button   = null

func _ready() -> void:
	game_manager = GameManager.new()
	game_manager.state_changed.connect(_refresh_all)
	game_manager.game_won.connect(_on_game_won)
	game_manager.turn_started.connect(_on_turn_started)

	_card_animator = CardAnimator.new()
	_card_animator.layer = 10
	add_child(_card_animator)

	turn_controller = TurnController.new()
	add_child(turn_controller)
	turn_controller.setup(game_manager)
	turn_controller.status_updated.connect(func(t): hud.set_status(t))
	turn_controller.action_logged.connect(func(t): hud.log_action(t))
	turn_controller.valid_ladders_changed.connect(_on_valid_ladders_changed)
	turn_controller.board_destinations_visible.connect(func(v): human_area.show_board_destinations(v))
	turn_controller.selection_cleared.connect(_on_selection_cleared)
	turn_controller.bot_thinking_started.connect(_on_bot_thinking_started)
	turn_controller.bot_thinking_ended.connect(_on_bot_thinking_ended)
	turn_controller.move_about_to_play.connect(_on_move_about_to_play)

	human_area = PlayerAreaScene.instantiate()
	human_area.show_hand = true
	human_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	human_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	human_area.card_selected.connect(_on_human_card_selected)
	human_area.card_drag_started.connect(_on_card_drag_started)
	human_area.board_dest_selected.connect(func(col): turn_controller.on_board_dest_chosen(col))
	human_row.add_child(human_area)

	hud = HUDScene.instantiate()
	hud.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud.z_index = 200
	hud.end_turn_requested.connect(func(): turn_controller.on_end_turn_requested())
	hud.pause_requested.connect(_toggle_pause)
	main_layout.add_child(hud)

	var deck_card_panel: PanelContainer = $MainLayout/LaddersArea/DeckArea/DeckCard
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1A3A5C")
	style.set_border_width_all(2)
	style.border_color = Color("#2A5A8C")
	style.set_corner_radius_all(6)
	style.set_content_margin_all(6)
	deck_card_panel.add_theme_stylebox_override("panel", style)
	deck_count.add_theme_color_override("font_color", Color("#F0EDE0"))

	var player_name: String = SaveData.session.get("player_name", "Jugador") as String
	var bot_count:   int    = SaveData.session.get("bot_count", 1) as int
	game_manager.setup(player_name, bot_count)
	_build_rival_views()
	game_manager.begin_turn()

# ── Refresh ───────────────────────────────────────────────────────────────────

func _refresh_all() -> void:
	human_area.refresh(game_manager.human_player())
	var bots := game_manager.bot_players()
	for i in range(_rival_areas.size()):
		_rival_areas[i].refresh(bots[i])
	for player in _rival_views:
		(_rival_views[player] as RivalAreaView).refresh()
	_rebuild_ladders()
	deck_count.text = str(game_manager.deck_size())
	var current := game_manager.current_player()
	hud.set_human_turn(current.is_human)
	human_area.set_active_turn(current.is_human)
	for i in range(_rival_areas.size()):
		_rival_areas[i].set_active_turn(bots[i] == current)
	for p in _rival_views:
		(_rival_views[p] as RivalAreaView).set_active(p == current)

func _rebuild_ladders() -> void:
	for child in ladders_container.get_children():
		child.queue_free()
	_add_ladder_btn = null
	for i in range(game_manager.ladder_count()):
		var lv: LadderView = LadderScene.instantiate()
		lv.ladder_data = game_manager.ladder_at(i)
		lv.ladder_index = i
		lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lv.ladder_clicked.connect(func(idx): turn_controller.on_ladder_chosen(idx))
		ladders_container.add_child(lv)
	_add_ladder_btn = Button.new()
	_add_ladder_btn.text = "+"
	_add_ladder_btn.custom_minimum_size = Vector2(50, 90)
	_add_ladder_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_add_ladder_btn.pressed.connect(func(): turn_controller.on_add_ladder_pressed())
	ladders_container.add_child(_add_ladder_btn)

# ── TurnController signal handlers ────────────────────────────────────────────

func _on_valid_ladders_changed(indices: Array[int]) -> void:
	for child in ladders_container.get_children():
		var lv := child as LadderView
		if lv != null:
			lv.set_valid_target(indices.has(lv.ladder_index))

func _on_selection_cleared() -> void:
	if _selected_card_view != null:
		_selected_card_view.set_selected(false)
		_selected_card_view = null

func _on_bot_thinking_started() -> void:
	human_area.modulate = Color(0.5, 0.5, 0.5, 1.0)
	hud.set_status("Bot is thinking...")

func _on_bot_thinking_ended() -> void:
	if game_manager.is_game_over:
		return
	if game_manager.current_player().is_human:
		human_area.modulate = Color(1.0, 1.0, 1.0, 1.0)
		_refresh_all()
		hud.set_status("Your turn")

func _on_move_about_to_play(event: CardMoveEvent) -> void:
	var duration: float = SaveData.get_setting("move_animation_duration", 0.4)

	var src_area := _get_player_area(event.player_index)
	var src_pos: Vector2
	if src_area != null:
		src_pos = src_area.get_card_global_pos(event.source, event.source_index)
		# Pre-flight: brief scale-up to signal the card is about to be picked up
		var src_view := src_area.get_card_view(event.source, event.source_index)
		if src_view != null:
			var lift := create_tween()
			lift.set_ease(Tween.EASE_OUT)
			lift.tween_property(src_view, "scale", Vector2(1.2, 1.2), 0.15)
			await lift.finished
	else:
		src_pos = get_viewport_rect().size / 2

	var dst_pos: Vector2
	if event.dest_type == CardMoveEvent.DestType.LADDER:
		var lv := _get_ladder_view(event.dest_index)
		dst_pos = lv.card_area.get_global_rect().get_center() \
				if lv != null else get_viewport_rect().size / 2
	else:
		dst_pos = src_area.board_container.get_global_rect().get_center() \
				if src_area != null else get_viewport_rect().size / 2

	await _card_animator.animate_move(event.card, src_pos, dst_pos, duration)

	# End-of-turn: briefly flash the board zone green to confirm card placement
	if event.dest_type == CardMoveEvent.DestType.BOARD and src_area != null:
		src_area.board_container.modulate = Color(0.8, 1.2, 0.8, 1.0)
		await get_tree().create_timer(0.4).timeout
		src_area.board_container.modulate = Color(1, 1, 1, 1)

	turn_controller.notify_animation_done()

func _get_player_area(player_index: int) -> PlayerAreaView:
	if player_index == 0:
		return human_area
	var bot_idx := player_index - 1
	if bot_idx < _rival_areas.size():
		return _rival_areas[bot_idx]
	return null

func _get_ladder_view(index: int) -> LadderView:
	for child in ladders_container.get_children():
		var lv := child as LadderView
		if lv != null and lv.ladder_index == index:
			return lv
	return null

# ── Turn management ───────────────────────────────────────────────────────────

func _on_turn_started(player: Player) -> void:
	human_area.set_active_turn(player.is_human)
	var bots := game_manager.bot_players()
	for i in range(_rival_areas.size()):
		_rival_areas[i].set_active_turn(bots[i] == player)
	for p in _rival_views:
		(_rival_views[p] as RivalAreaView).set_active(p == player)
	turn_controller.on_turn_started(player)

func _on_game_won(player: Player) -> void:
	hud.disable_actions()
	var go: GameOver = GameOverScene.instantiate()
	add_child(go)
	go.setup(player, game_manager.human_player().name, game_manager.turn_count, game_manager.cards_played)

# ── Input ─────────────────────────────────────────────────────────────────────

func _on_human_card_selected(source: GameManager.CardSource, index: int, card: Card) -> void:
	turn_controller.on_card_input(source, index, card)
	if turn_controller.state == TurnController.State.CARD_SELECTED:
		_selected_card_view = human_area.get_card_view(source, index)
		if _selected_card_view != null:
			_selected_card_view.set_selected(true)

func _on_card_drag_started(source: GameManager.CardSource, index: int, card: Card) -> void:
	if not game_manager.current_player().is_human:
		return
	if turn_controller.state == TurnController.State.AWAITING_BOARD_DEST:
		return

	if turn_controller.state == TurnController.State.AWAITING_BOARD_CARD:
		if source != GameManager.CardSource.HAND:
			return
		turn_controller.on_drag_started_as_end_turn(index)
		_drag_is_end_turn = true
		_drag_source_view = human_area.get_card_view(source, index)
		if _drag_source_view != null:
			_drag_source_view.modulate.a = 0.4
		_start_ghost(card)
		return

	turn_controller.on_drag_started_normal(source, index, card)
	_drag_source_view = human_area.get_card_view(source, index)
	if _drag_source_view != null:
		_drag_source_view.modulate.a = 0.4
	_start_ghost(card)

# ── Drag & drop ───────────────────────────────────────────────────────────────

func _start_ghost(card: Card) -> void:
	_drag_ghost = CardScene.instantiate()
	_drag_ghost.card_data = card
	_drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_ghost.custom_minimum_size = Vector2(180, 260)
	_drag_ghost.z_index = 100
	add_child(_drag_ghost)
	_drag_ghost.position = get_global_mouse_position() - Vector2(90, 130)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _drag_ghost != null:
			_cancel_drag()
			get_viewport().set_input_as_handled()
		else:
			turn_controller.on_escape_pressed()
			if turn_controller.state != TurnController.State.IDLE:
				get_viewport().set_input_as_handled()
		return
	if _drag_ghost == null:
		return
	if event is InputEventMouseMotion:
		_drag_ghost.position = get_global_mouse_position() - Vector2(90, 130)
	elif event is InputEventMouseButton \
		 and event.button_index == MOUSE_BUTTON_LEFT \
		 and not event.pressed:
		_end_drag()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()

func _end_drag() -> void:
	if _drag_source_view != null:
		_drag_source_view.modulate.a = 1.0
		_drag_source_view = null
	if _drag_ghost != null:
		_drag_ghost.queue_free()
		_drag_ghost = null
	_try_drop_at_mouse()

func _cancel_drag() -> void:
	if _drag_source_view != null:
		_drag_source_view.modulate.a = 1.0
		_drag_source_view = null
	if _drag_ghost != null:
		_drag_ghost.queue_free()
		_drag_ghost = null
	_drag_is_end_turn = false
	turn_controller.cancel_interaction()

func _try_drop_at_mouse() -> void:
	var mouse_pos := get_global_mouse_position()

	if _drag_is_end_turn:
		_drag_is_end_turn = false
		var col := human_area.get_board_col_at_position(mouse_pos)
		if col >= 0:
			turn_controller.on_board_dest_chosen(col)
			return
		turn_controller.on_drag_dropped_outside_board()
		return

	for child in ladders_container.get_children():
		var lv := child as LadderView
		if lv != null and lv.get_global_rect().has_point(mouse_pos):
			turn_controller.on_ladder_chosen(lv.ladder_index)
			return
	if _add_ladder_btn != null \
	   and _add_ladder_btn.get_global_rect().has_point(mouse_pos):
		turn_controller.on_add_ladder_pressed()
		return
	turn_controller.cancel_interaction()

# ── Rival views ───────────────────────────────────────────────────────────────

func _build_rival_views() -> void:
	for child in rivals_row.get_children():
		child.queue_free()
	# Remove any rival previously added to human_row (keep human_area)
	for child in human_row.get_children():
		if child != human_area:
			child.queue_free()
	for view in _rival_areas:
		if is_instance_valid(view):
			view.queue_free()
	_rival_areas.clear()
	_rival_views.clear()

	var bots := game_manager.bot_players()

	if bots.size() == 1:
		rivals_row.show()
		var view := _make_rival_top_area()
		rivals_row.add_child(view)
		_rival_areas.append(view)

	elif bots.size() == 2:
		rivals_row.show()
		var left_view  := _make_rival_top_area()
		var right_view := _make_rival_top_area()
		rivals_row.add_child(left_view)
		rivals_row.add_child(right_view)
		_rival_areas.append(left_view)
		_rival_areas.append(right_view)

	elif bots.size() == 3:
		# 4-player layout: two rivals at top, one rival at bottom-right.
		rivals_row.show()
		var top_left  := _make_rival_top_area()
		var top_right := _make_rival_top_area()
		rivals_row.add_child(top_left)
		rivals_row.add_child(top_right)
		_rival_areas.append(top_left)
		_rival_areas.append(top_right)
		var bottom_right := _make_rival_bottom_area()
		human_row.add_child(bottom_right)
		_rival_areas.append(bottom_right)

	else:
		rivals_row.show()
		for player in bots:
			var view: RivalAreaView = RivalAreaScene.instantiate()
			rivals_row.add_child(view)
			view.setup(player)
			view.inspect_requested.connect(_show_rival_board)
			_rival_views[player] = view

# Rival sitting across the table — hand fan at the top.
func _make_rival_top_area() -> PlayerAreaView:
	var view: PlayerAreaView = PlayerAreaScene.instantiate()
	view.show_hand      = false
	view.hand_at_bottom = false
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	return view

# Rival sitting beside the human (bottom row) — hand fan at the bottom, face-down.
func _make_rival_bottom_area() -> PlayerAreaView:
	var view: PlayerAreaView = PlayerAreaScene.instantiate()
	view.show_hand      = false
	view.hand_at_bottom = true
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	return view

# ── Rival board overlay ───────────────────────────────────────────────────────

func _show_rival_board(player: Player) -> void:
	if _rival_overlay != null:
		_rival_overlay.queue_free()
	_rival_overlay = RivalBoardOverlayScene.instantiate()
	add_child(_rival_overlay)
	_rival_overlay.setup(player)
	_rival_overlay.tree_exited.connect(func(): _rival_overlay = null)

# ── Pause ─────────────────────────────────────────────────────────────────────

func _toggle_pause() -> void:
	if game_manager.is_game_over:
		return
	if _pause_menu != null:
		_unpause()
		return
	get_tree().paused = true
	_pause_menu = PauseMenuScene.instantiate()
	_pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause_menu)
	_pause_menu.resume_requested.connect(_unpause)
	_pause_menu.restart_requested.connect(_restart_game)
	_pause_menu.main_menu_requested.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://escenas/ui/main_menu/main_menu.tscn"))

func _unpause() -> void:
	get_tree().paused = false
	if _pause_menu != null:
		_pause_menu.queue_free()
		_pause_menu = null

func _restart_game() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://escenas/game/game.tscn")
