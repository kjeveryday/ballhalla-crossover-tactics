extends Node2D
# BattleDemo — Full battle scene wiring all systems together.
#
# PRIMARY INPUT: Click ballers to select them; use the action menu that appears.
# KEYBOARD SHORTCUTS (still active for fast play):
#   ← / →       Cycle selected allied baller
#   M           Move (toward basket)  P  Pass  S  Shoot
#   X  Screen   T  Trash Talk         L  Leadership  I  ISO Talk
#   1-4         Call play: 1=Pick&Roll  2=Give&Go  3=ISO  4=Drive&Kick
#   Space       End selected baller's turn
#   Enter       End beat early
#   D           Toggle zone overlay
#   ESC         Cancel current action / close menu

const COURT_OFFSET := Vector2(16.0, 94.0)

enum UIState { IDLE, BALLER_SELECTED, TARGET_MOVE, TARGET_PASS, TARGET_LEADERSHIP }

var _ui_state: UIState = UIState.IDLE

# Allied baller references (filled in _spawn_ballers)
var _ballers: Array = []
var _enemies: Array = []
var _selected_idx: int = 0

# Starting positions for possession reset
const ALLIED_STARTS := [
	Vector2i(4, 9),  # PG
	Vector2i(3, 9),  # SG
	Vector2i(5, 8),  # SF
	Vector2i(2, 7),  # PF
	Vector2i(6, 7),  # C
]
const ENEMY_STARTS := [
	Vector2i(4, 5),  # PG
	Vector2i(2, 5),  # SG
	Vector2i(4, 3),  # SF
	Vector2i(2, 2),  # PF
	Vector2i(4, 1),  # C
]

# HUD / UI node references
var _court: Node2D
var _selection_ring: Node2D
var _ball_indicator: Node2D
var _action_menu: Control
var _target_overlay: Node2D
var _status_label: Label
var _log_label: Label
var _match_overlay: Label

var _log_lines: Array = []

# ─────────────────────────────────────────────
#  Setup
# ─────────────────────────────────────────────

func _ready() -> void:
	get_window().size = Vector2i(816, 716)
	get_window().title = "Ballhalla: Crossover Tactics — Battle Demo"
	_build_scene()
	_spawn_ballers()
	_wire_signals()
	QuarterManager.start_match()
	_refresh_status()

func _build_scene() -> void:
	# Dark background
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.10)
	bg.size = Vector2(816, 716)
	add_child(bg)

	# Court container (GridOverlay + ballers drawn here in court-space coords)
	_court = Node2D.new()
	_court.name = "Court"
	_court.position = COURT_OFFSET
	add_child(_court)

	# Zone overlay (press D to toggle)
	var overlay: Node2D = load("res://debug/GridOverlay.tscn").instantiate()
	_court.add_child(overlay)

	# Target overlay (move/pass/leadership highlights) — child of court so coords match
	_target_overlay = Node2D.new()
	_target_overlay.name = "TargetOverlay"
	_target_overlay.set_script(load("res://scenes/battle/TargetOverlay.gd"))
	_court.add_child(_target_overlay)

	# Selection ring (repositioned each refresh)
	_selection_ring = Node2D.new()
	_selection_ring.name = "SelectionRing"
	_selection_ring.set_script(load("res://scenes/battle/SelectionRing.gd"))
	_court.add_child(_selection_ring)

	# Ball indicator (follows ball carrier, drawn above them)
	_ball_indicator = Node2D.new()
	_ball_indicator.name = "BallIndicator"
	_ball_indicator.set_script(load("res://scenes/battle/BallIndicator.gd"))
	_court.add_child(_ball_indicator)

	# HUD CanvasLayer (always on top, unaffected by court transform)
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)

	# Shot clock bar (24 blocks)
	var clock_bar := Node2D.new()
	clock_bar.name = "ShotClockBar"
	clock_bar.set_script(load("res://scenes/battle/ShotClockBar.gd"))
	clock_bar.position = Vector2(COURT_OFFSET.x, 4.0)
	hud.add_child(clock_bar)

	# Status line (Q / Beat / Actions / Score / Selected baller info)
	_status_label = Label.new()
	_status_label.position = Vector2(COURT_OFFSET.x, 56.0)
	_status_label.add_theme_font_size_override("font_size", 13)
	_status_label.add_theme_color_override("font_color", Color.WHITE)
	hud.add_child(_status_label)

	# Action log (last 7 events, right-aligned area)
	_log_label = Label.new()
	_log_label.position = Vector2(COURT_OFFSET.x + 420.0, 56.0)
	_log_label.add_theme_font_size_override("font_size", 12)
	_log_label.add_theme_color_override("font_color", Color(0.85, 0.95, 0.7))
	hud.add_child(_log_label)

	# Control hints bar at bottom
	var hints := Label.new()
	hints.position = Vector2(COURT_OFFSET.x, COURT_OFFSET.y + GridManager.GRID_ROWS * GridManager.CELL_SIZE + 6.0)
	hints.add_theme_font_size_override("font_size", 11)
	hints.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	hints.text = "Click baller to select  |  ←/→ Cycle  M/P/S/X/T/L/I/1-4 Shortcuts  Space EndTurn  Enter EndBeat  D Overlay  ESC Cancel"
	hud.add_child(hints)

	# Match-end overlay (hidden until game over)
	_match_overlay = Label.new()
	_match_overlay.position = Vector2(200.0, 280.0)
	_match_overlay.add_theme_font_size_override("font_size", 32)
	_match_overlay.add_theme_color_override("font_color", Color.YELLOW)
	_match_overlay.visible = false
	hud.add_child(_match_overlay)

	# Action menu (screen-space, lives in HUD so it's always on top)
	_action_menu = Control.new()
	_action_menu.name = "ActionMenu"
	_action_menu.set_script(load("res://scenes/battle/ActionMenu.gd"))
	hud.add_child(_action_menu)

func _spawn_ballers() -> void:
	AlliedTeam.clear()
	EnemyTeam.clear()
	_ballers.clear()
	_enemies.clear()

	var allied_stats := [
		"res://resources/stats/allied/pg_remix.tres",
		"res://resources/stats/allied/sg_remix.tres",
		"res://resources/stats/allied/sf_remix.tres",
		"res://resources/stats/allied/pf_remix.tres",
		"res://resources/stats/allied/c_remix.tres",
	]
	var AlliedScene: PackedScene = load("res://entities/baller/AlliedBaller.tscn")
	for i in range(5):
		var b: Node = AlliedScene.instantiate()
		b.set("stats", load(allied_stats[i]))
		_court.add_child(b)
		b.place_on_grid(ALLIED_STARTS[i].x, ALLIED_STARTS[i].y)
		_ballers.append(b)

	_ballers[0].has_ball = true  # PG starts with ball

	var enemy_stats := [
		"res://resources/stats/enemy/hollywood_pg.tres",
		"res://resources/stats/enemy/hollywood_sg.tres",
		"res://resources/stats/enemy/hollywood_sf.tres",
		"res://resources/stats/enemy/hollywood_pf.tres",
		"res://resources/stats/enemy/hollywood_c.tres",
	]
	var EnemyScene: PackedScene = load("res://entities/baller/EnemyBaller.tscn")
	for i in range(5):
		var e: Node = EnemyScene.instantiate()
		e.set("stats", load(enemy_stats[i]))
		_court.add_child(e)
		e.place_on_grid(ENEMY_STARTS[i].x, ENEMY_STARTS[i].y)
		_enemies.append(e)

func _wire_signals() -> void:
	BeatManager.beat_started.connect(_on_beat_started)
	BeatManager.beat_ended.connect(_on_beat_ended)
	BeatManager.action_committed.connect(_on_action_committed)
	ShotSystem.shot_made.connect(_on_shot_made)
	ShotSystem.shot_missed.connect(_on_shot_missed)
	ShotSystem.rebound_won.connect(_on_rebound)
	QuarterManager.score_changed.connect(func(_a, _e): _refresh_status())
	QuarterManager.quarter_ended.connect(_on_quarter_ended)
	QuarterManager.match_ended.connect(_on_match_ended)
	PlayManager.play_called.connect(func(pname): _log("Play called: %s" % pname))
	PlayManager.play_triggered.connect(func(pname): _log("PLAY TRIGGERED: %s!" % pname))
	PlayManager.play_expired.connect(func(pname): _log("Play expired: %s" % pname))

	# Action menu signals
	_action_menu.action_chosen.connect(_on_action_chosen)
	_action_menu.submenu_action_chosen.connect(_on_submenu_action_chosen)

	# Target overlay signals
	_target_overlay.cell_clicked.connect(_on_target_cell_clicked)
	_target_overlay.baller_clicked.connect(_on_target_baller_clicked)
	_target_overlay.cancelled.connect(_on_target_cancelled)

# ─────────────────────────────────────────────
#  UI State Machine
# ─────────────────────────────────────────────

func _set_ui_state(new_state: UIState) -> void:
	_ui_state = new_state
	match new_state:
		UIState.IDLE:
			_action_menu.hide_menu()
			_target_overlay.clear()
		UIState.BALLER_SELECTED:
			_target_overlay.clear()
			var sel := _selected_baller()
			var screen_pos: Vector2 = _court.position + sel.position
			_action_menu.show_for_baller(sel, screen_pos)
		UIState.TARGET_MOVE:
			_action_menu.hide_menu()
			_target_overlay.show_move_range(_selected_baller())
		UIState.TARGET_PASS:
			_action_menu.hide_menu()
			_target_overlay.show_ally_targets(_ballers, _selected_baller())
		UIState.TARGET_LEADERSHIP:
			_action_menu.hide_menu()
			_target_overlay.show_ally_targets(_ballers, _selected_baller())

# ─────────────────────────────────────────────
#  Signal handlers — beat / game events
# ─────────────────────────────────────────────

func _on_beat_started(beat_num: int) -> void:
	if beat_num == 1:
		_reset_positions()
		_log("--- New possession ---")
	_log("Beat %d started (actions: %d)" % [beat_num, BeatManager.actions_remaining])
	_set_ui_state(UIState.IDLE)
	_refresh_status()

func _on_beat_ended(beat_num: int) -> void:
	_log("Beat %d ended" % beat_num)
	_set_ui_state(UIState.IDLE)
	_refresh_status()

func _on_action_committed(action_type: String) -> void:
	var sel: Node = _selected_baller()
	_log("%s: %s" % [sel.stats.display_name, action_type])
	_set_ui_state(UIState.IDLE)
	_refresh_status()

func _on_shot_made(shooter: Node, points: int) -> void:
	_log("MADE +%dpts! (%s)" % [points, shooter.stats.display_name])
	_refresh_status()

func _on_shot_missed(shooter: Node) -> void:
	_log("Missed shot (%s)" % shooter.stats.display_name)

func _on_rebound(baller, is_offensive: bool) -> void:
	if baller != null:
		_log("Rebound: %s (%s)" % [baller.stats.display_name, "OFF" if is_offensive else "DEF"])
	else:
		_log("Defensive rebound — possession ends")
	_refresh_status()

func _on_quarter_ended(quarter: int) -> void:
	_log("=== Q%d ENDED  %d-%d ===" % [quarter, QuarterManager.allied_score, QuarterManager.enemy_score])
	_refresh_status()

func _on_match_ended(allied: int, enemy: int) -> void:
	var winner: String = "ALLIED WINS" if allied > enemy else "ENEMY WINS"
	_match_overlay.text = "%s\n%d — %d\nPress R to restart" % [winner, allied, enemy]
	_match_overlay.visible = true
	_set_ui_state(UIState.IDLE)
	_log("MATCH OVER — %s" % winner)

# ─────────────────────────────────────────────
#  Signal handlers — ActionMenu
# ─────────────────────────────────────────────

func _on_action_chosen(action_id: String) -> void:
	var sel := _selected_baller()
	match action_id:
		"move":
			_set_ui_state(UIState.TARGET_MOVE)
		"pass":
			_set_ui_state(UIState.TARGET_PASS)
		"shoot":
			AbilitySystem.attempt_shot(sel)
			_refresh_status()
		"screen":
			AbilitySystem.perform_screen(sel)
			_refresh_status()
		"end_turn":
			AbilitySystem.end_turn(sel)
			_refresh_status()
		_:
			_set_ui_state(UIState.IDLE)

func _on_submenu_action_chosen(action_id: String) -> void:
	var sel := _selected_baller()
	match action_id:
		"trash_talk":
			AbilitySystem.talk_trash(sel)
			_refresh_status()
		"leadership":
			_set_ui_state(UIState.TARGET_LEADERSHIP)
		"iso_talk":
			AbilitySystem.talk_iso(sel)
			_refresh_status()
		"play:pick_and_roll":
			AbilitySystem.call_play("pick_and_roll")
			_refresh_status()
		"play:give_and_go":
			AbilitySystem.call_play("give_and_go")
			_refresh_status()
		"play:iso":
			AbilitySystem.call_play("iso")
			_refresh_status()
		"play:drive_and_kick":
			AbilitySystem.call_play("drive_and_kick")
			_refresh_status()
		_:
			_set_ui_state(UIState.IDLE)

# ─────────────────────────────────────────────
#  Signal handlers — TargetOverlay
# ─────────────────────────────────────────────

func _on_target_cell_clicked(col: int, row: int) -> void:
	if _ui_state == UIState.TARGET_MOVE:
		AbilitySystem.initiate_move(_selected_baller(), Vector2i(col, row))
		_refresh_status()
	_set_ui_state(UIState.IDLE)

func _on_target_baller_clicked(baller: Node) -> void:
	var sel := _selected_baller()
	if _ui_state == UIState.TARGET_PASS:
		AbilitySystem.attempt_pass(sel, baller)
		_refresh_status()
	elif _ui_state == UIState.TARGET_LEADERSHIP:
		AbilitySystem.talk_leadership(sel, baller)
		_refresh_status()
	_set_ui_state(UIState.IDLE)

func _on_target_cancelled() -> void:
	# Return to baller-selected menu if we were in a targeting state
	if _ui_state in [UIState.TARGET_MOVE, UIState.TARGET_PASS, UIState.TARGET_LEADERSHIP]:
		_set_ui_state(UIState.BALLER_SELECTED)
	else:
		_set_ui_state(UIState.IDLE)

# ─────────────────────────────────────────────
#  Input
# ─────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	# Restart after match end
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R and _match_overlay.visible:
			get_tree().reload_current_scene()
			return

	# LMB click — select a baller by clicking on them in the court
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _ui_state == UIState.IDLE or _ui_state == UIState.BALLER_SELECTED:
			var court_pos: Vector2 = event.position - _court.position
			for i in range(_ballers.size()):
				var b: Node = _ballers[i]
				if court_pos.distance_to(b.position) <= GridManager.CELL_SIZE * 0.45:
					_selected_idx = i
					_refresh_status()
					_set_ui_state(UIState.BALLER_SELECTED)
					get_viewport().set_input_as_handled()
					return
			# Clicked away from any baller → close menu
			if _ui_state == UIState.BALLER_SELECTED:
				_set_ui_state(UIState.IDLE)
		return

	if not event is InputEventKey or not event.pressed:
		return

	match event.keycode:
		KEY_ESCAPE:
			_set_ui_state(UIState.IDLE)

		KEY_LEFT:
			_selected_idx = (_selected_idx - 1 + 5) % 5
			_refresh_status()
			if _ui_state == UIState.BALLER_SELECTED:
				_set_ui_state(UIState.BALLER_SELECTED)

		KEY_RIGHT:
			_selected_idx = (_selected_idx + 1) % 5
			_refresh_status()
			if _ui_state == UIState.BALLER_SELECTED:
				_set_ui_state(UIState.BALLER_SELECTED)

		KEY_M:
			var sel: Node = _selected_baller()
			var dest := Vector2i(sel.grid_col, max(0, sel.grid_row - 3))
			AbilitySystem.initiate_move(sel, dest)
			_set_ui_state(UIState.IDLE)
			_refresh_status()

		KEY_P:
			var sel: Node = _selected_baller()
			var target: Node = _nearest_teammate(sel)
			if target:
				AbilitySystem.attempt_pass(sel, target)
			else:
				_log("No pass target!")
			_set_ui_state(UIState.IDLE)
			_refresh_status()

		KEY_S:
			AbilitySystem.attempt_shot(_selected_baller())
			_set_ui_state(UIState.IDLE)
			_refresh_status()

		KEY_X:
			AbilitySystem.perform_screen(_selected_baller())
			_set_ui_state(UIState.IDLE)
			_refresh_status()

		KEY_T:
			AbilitySystem.talk_trash(_selected_baller())
			_set_ui_state(UIState.IDLE)
			_refresh_status()

		KEY_L:
			var sel: Node = _selected_baller()
			var ally: Node = _lowest_hype_ally(sel)
			if ally:
				AbilitySystem.talk_leadership(sel, ally)
			_set_ui_state(UIState.IDLE)
			_refresh_status()

		KEY_I:
			AbilitySystem.talk_iso(_selected_baller())
			_set_ui_state(UIState.IDLE)
			_refresh_status()

		KEY_1:
			AbilitySystem.call_play("pick_and_roll")
			_set_ui_state(UIState.IDLE)
			_refresh_status()
		KEY_2:
			AbilitySystem.call_play("give_and_go")
			_set_ui_state(UIState.IDLE)
			_refresh_status()
		KEY_3:
			AbilitySystem.call_play("iso")
			_set_ui_state(UIState.IDLE)
			_refresh_status()
		KEY_4:
			AbilitySystem.call_play("drive_and_kick")
			_set_ui_state(UIState.IDLE)
			_refresh_status()

		KEY_SPACE:
			AbilitySystem.end_turn(_selected_baller())
			_set_ui_state(UIState.IDLE)
			_refresh_status()

		KEY_ENTER, KEY_KP_ENTER:
			BeatManager.end_beat_early()
			_set_ui_state(UIState.IDLE)
			_refresh_status()

# ─────────────────────────────────────────────
#  HUD helpers
# ─────────────────────────────────────────────

func _refresh_status() -> void:
	var sel: Node = _selected_baller()
	var hype_pct: int = int(HypeManager.get_team_hype() / 500.0 * 100.0)
	var state_name: String = GameStateMachine.BattleState.keys()[GameStateMachine.current_state]

	var ball_note: String = ""
	if sel.has_ball:
		ball_note = " [BALL]"
	elif sel.is_exhausted:
		ball_note = " [OUT]"

	var play_note: String = ""
	if PlayManager.active_play != null:
		play_note = "  PLAY: %s" % PlayManager.active_play.play_name

	_status_label.text = (
		"Q%d | Beat %d/8 | Actions %d/3 | Allied %d : Enemy %d | Hype %d%%  [%s]%s\n"
		+ "► %s  HP %d/%d  Hype %d%s"
	) % [
		QuarterManager.current_quarter,
		BeatManager.current_beat,
		BeatManager.actions_remaining,
		QuarterManager.allied_score,
		QuarterManager.enemy_score,
		hype_pct,
		state_name,
		play_note,
		sel.stats.display_name,
		sel.current_stamina,
		sel.stats.max_stamina,
		int(sel.current_hype),
		ball_note,
	]

	# Reposition selection ring over selected baller
	_selection_ring.position = sel.position
	_selection_ring.queue_redraw()

func _log(msg: String) -> void:
	_log_lines.append(msg)
	if _log_lines.size() > 7:
		_log_lines.pop_front()
	_log_label.text = "\n".join(_log_lines)

func _selected_baller() -> Node:
	return _ballers[_selected_idx]

func _nearest_teammate(from: Node) -> Node:
	var best: Node = null
	var best_dist: int = 999
	for b in _ballers:
		if b == from or b.is_exhausted:
			continue
		var d: int = GridManager.chebyshev_distance(from.grid_col, from.grid_row, b.grid_col, b.grid_row)
		if d < best_dist:
			best_dist = d
			best = b
	return best

func _lowest_hype_ally(talker: Node) -> Node:
	var best: Node = null
	var lowest: float = 999.0
	for b in _ballers:
		if b != talker and b.current_hype < lowest:
			lowest = b.current_hype
			best = b
	return best

func _reset_positions() -> void:
	for b in _ballers:
		b.has_ball = false
		b.is_in_motion = false
		b.move_destination = Vector2i(-1, -1)
	for i in range(_ballers.size()):
		_ballers[i].place_on_grid(ALLIED_STARTS[i].x, ALLIED_STARTS[i].y)
	for i in range(_enemies.size()):
		_enemies[i].place_on_grid(ENEMY_STARTS[i].x, ENEMY_STARTS[i].y)
	_ballers[0].has_ball = true
