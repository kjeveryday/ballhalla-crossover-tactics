extends Node2D
# BattleDemo — Full battle scene wiring all systems together.
#
# PRIMARY INPUT: Click ballers to select them; use the action menu that appears.
# KEYBOARD SHORTCUTS (still active for fast play):
#   ← / →       Cycle selected allied baller
#   Tab         Next available (unacted, non-exhausted) baller
#   M           Move (toward basket)  C  Cut   P  Pass   S  Shoot
#   X  Screen   T  Trash Talk         L  Leadership   I  ISO Talk
#   1-4         Call play: 1=Pick&Roll  2=Give&Go  3=ISO  4=Drive&Kick
#   Space       End selected baller's turn
#   Enter       End beat early (prompts if actions remain)
#   Ctrl+Z      Undo last move
#   D           Toggle overlay (cycle: none/zones/zones+guards/guards)
#   `           Toggle match log panel
#   ?           Show shortcut reference
#   ESC         Cancel current action / close menu

const COURT_OFFSET := Vector2(16.0, 94.0)

enum UIState { IDLE, BALLER_SELECTED, TARGET_MOVE, TARGET_CUT, TARGET_PASS, TARGET_LEADERSHIP }

var _ui_state: UIState = UIState.IDLE
var _is_animating: bool = false
var _anim_count: int = 0
var _pending_transition: Callable = Callable()

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
var _zone_overlay: Node2D
var _guard_display: Node2D
var _enemy_info_panel: Control
var _scoreboard: Control
var _active_play_banner: Control
var _baller_info_bar: Node2D
var _hype_fx: Node2D
var _transition_screen: Control
var _confirm_dialog: Control
var _log_panel: Control
var _shortcut_ref: Control
var _log_label: Label
var _match_overlay: Label

# Per-possession stats for the quarter-end screen — { display_name: {pts, ast, scr} }
var _possession_stats: Dictionary = {}

var _shot_arc: Node2D  # ShotArcOverlay
var _log_lines: Array = []
var _floating_text: Node2D  # FloatingTextSpawner

# Debug overlay mode: 0=none, 1=zones only, 2=zones+guards, 3=guards only
var _debug_mode: int = 0

# Undo support — snapshot captured before each move, cleared on irreversible events
var _undo_snapshot: Dictionary = {}
var _undo_available: bool = false

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

	# Permanent grid lines — always visible cell borders
	var court_grid := Node2D.new()
	court_grid.name = "CourtGrid"
	court_grid.set_script(load("res://scenes/battle/CourtGrid.gd"))
	_court.add_child(court_grid)

	# Zone overlay (press D to cycle debug mode)
	_zone_overlay = load("res://debug/GridOverlay.tscn").instantiate()
	_zone_overlay.visible = false
	_court.add_child(_zone_overlay)

	# Guard display — dashed lines from each enemy to their guard assignment
	_guard_display = Node2D.new()
	_guard_display.name = "GuardDisplay"
	_guard_display.set_script(load("res://scenes/battle/GuardDisplay.gd"))
	_guard_display.visible = false
	_court.add_child(_guard_display)

	# Hype milestone FX — full-court flash on hype thresholds
	_hype_fx = Node2D.new()
	_hype_fx.name = "HypeMilestoneFX"
	_hype_fx.set_script(load("res://scenes/battle/HypeMilestoneFX.gd"))
	_court.add_child(_hype_fx)

	# Shot arc overlay — dotted parabola from shooter to rim
	_shot_arc = Node2D.new()
	_shot_arc.name = "ShotArcOverlay"
	_shot_arc.set_script(load("res://scenes/battle/ShotArcOverlay.gd"))
	_court.add_child(_shot_arc)

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

	# Scoreboard panel — top-center (overlays center of shot clock; left/right remain visible)
	_scoreboard = Control.new()
	_scoreboard.name = "ScoreboardPanel"
	_scoreboard.set_script(load("res://scenes/battle/ScoreboardPanel.gd"))
	_scoreboard.position = Vector2((816 - 400) / 2, 0)
	hud.add_child(_scoreboard)

	# Active play banner — centered, just below scoreboard, hidden by default
	_active_play_banner = Control.new()
	_active_play_banner.name = "ActivePlayBanner"
	_active_play_banner.set_script(load("res://scenes/battle/ActivePlayBanner.gd"))
	_active_play_banner.position = Vector2((816 - 300) / 2, 54)
	hud.add_child(_active_play_banner)

	# Baller info bar — left-aligned, replaces status_label
	_baller_info_bar = Node2D.new()
	_baller_info_bar.name = "BallerInfoBar"
	_baller_info_bar.set_script(load("res://scenes/battle/BallerInfoBar.gd"))
	_baller_info_bar.position = Vector2(COURT_OFFSET.x, 56.0)
	hud.add_child(_baller_info_bar)

	# Action log (last 7 events, overlaid on court — left side)
	_log_label = Label.new()
	_log_label.position = Vector2(COURT_OFFSET.x + 420.0, 56.0)
	_log_label.add_theme_font_size_override("font_size", 12)
	_log_label.add_theme_color_override("font_color", Color(0.85, 0.95, 0.7))
	hud.add_child(_log_label)

	# Log toggle button — always visible, right side of screen
	var log_toggle := Button.new()
	log_toggle.text = "LOG"
	log_toggle.position = Vector2(762.0, 57.0)
	log_toggle.custom_minimum_size = Vector2(36.0, 24.0)
	log_toggle.add_theme_font_size_override("font_size", 10)
	log_toggle.pressed.connect(func(): _log_panel.visible = not _log_panel.visible)
	hud.add_child(log_toggle)

	# Control hints bar at bottom
	var hints := Label.new()
	hints.position = Vector2(COURT_OFFSET.x, COURT_OFFSET.y + GridManager.GRID_ROWS * GridManager.CELL_SIZE + 6.0)
	hints.add_theme_font_size_override("font_size", 11)
	hints.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	hints.text = "Click/Tab Select  M/C/P/S/X/T/L/I/1-4 Actions  Space EndTurn  Enter EndBeat  Ctrl+Z Undo  D Overlay  ` Log  ? Help  ESC Cancel"
	hud.add_child(hints)

	# Match-end overlay (hidden until game over)
	_match_overlay = Label.new()
	_match_overlay.position = Vector2(200.0, 280.0)
	_match_overlay.add_theme_font_size_override("font_size", 32)
	_match_overlay.add_theme_color_override("font_color", Color.YELLOW)
	_match_overlay.visible = false
	hud.add_child(_match_overlay)

	# Floating text spawner (court-space, sibling of ballers)
	_floating_text = Node2D.new()
	_floating_text.name = "FloatingTextSpawner"
	_floating_text.set_script(load("res://scenes/battle/FloatingTextSpawner.gd"))
	_court.add_child(_floating_text)

	# Action menu (screen-space, lives in HUD so it's always on top)
	_action_menu = Control.new()
	_action_menu.name = "ActionMenu"
	_action_menu.set_script(load("res://scenes/battle/ActionMenu.gd"))
	hud.add_child(_action_menu)

	# Enemy info panel (screen-space, on top of ActionMenu)
	_enemy_info_panel = Control.new()
	_enemy_info_panel.name = "EnemyInfoPanel"
	_enemy_info_panel.set_script(load("res://scenes/battle/EnemyInfoPanel.gd"))
	hud.add_child(_enemy_info_panel)

	# Transition screen — added last so it covers everything
	_transition_screen = Control.new()
	_transition_screen.name = "TransitionScreen"
	_transition_screen.set_script(load("res://scenes/battle/TransitionScreen.gd"))
	hud.add_child(_transition_screen)

	# Confirm dialog — above transition screen
	_confirm_dialog = Control.new()
	_confirm_dialog.name = "ConfirmDialog"
	_confirm_dialog.set_script(load("res://scenes/battle/ConfirmDialog.gd"))
	hud.add_child(_confirm_dialog)

	# Log panel — right side of court, toggled via ` or LOG button
	_log_panel = Control.new()
	_log_panel.name = "LogPanel"
	_log_panel.set_script(load("res://scenes/battle/LogPanel.gd"))
	_log_panel.position = Vector2(596.0, 88.0)
	hud.add_child(_log_panel)

	# Shortcut reference overlay — above everything
	_shortcut_ref = Control.new()
	_shortcut_ref.name = "ShortcutRef"
	_shortcut_ref.set_script(load("res://scenes/battle/ShortcutRef.gd"))
	hud.add_child(_shortcut_ref)

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
	QuarterManager.defense_resolved.connect(_on_defense_resolved)
	QuarterManager.quarter_break_ready.connect(_on_quarter_break_ready)
	QuarterManager.halftime_ready.connect(_on_halftime_ready)
	AbilitySystem.screen_performed.connect(func(screener): _stat_add(screener, "scr"))
	ShotSystem.shot_made.connect(func(shooter, pts): _stat_add(shooter, "pts", pts))
	AbilitySystem.turnover_occurred.connect(func(b):
		_undo_available = false
		_ball_indicator.clear_override()
		_log("TURNOVER — %s loses possession" % b.stats.display_name, "turnover"))

	# Undo snapshot invalidation — clear on any irreversible event
	BeatManager.beat_ended.connect(func(_b): _undo_available = false)
	ShotSystem.shot_made.connect(func(_s, _p): _undo_available = false)
	ShotSystem.shot_missed.connect(func(_s): _undo_available = false)
	AbilitySystem.pass_completed.connect(func(_f, _t): _undo_available = false)
	PlayManager.play_called.connect(func(pname): _log("Play called: %s" % pname, "play"))
	PlayManager.play_triggered.connect(func(pname): _log("PLAY TRIGGERED: %s!" % pname, "play"))
	PlayManager.play_expired.connect(func(pname): _log("Play expired: %s" % pname, "play"))

	# Animation signals
	MovementSystem.baller_moved.connect(_on_baller_moved)
	AbilitySystem.pass_completed.connect(_on_pass_completed)
	ShotSystem.shot_made.connect(func(_s, _p): _shot_arc.hide_arc())
	ShotSystem.shot_missed.connect(func(_s): _shot_arc.hide_arc())

	# Floating text signal wiring
	StaminaSystem.stamina_changed.connect(func(b, d): _floating_text.spawn_stamina(b.position, d))
	HypeManager.hype_changed.connect(func(b, d): _floating_text.spawn_hype(b.position, d))
	ShotSystem.shot_made.connect(func(shooter, pts): _floating_text.spawn_score(shooter.position, pts))
	ShotSystem.shot_missed.connect(func(shooter): _floating_text.spawn_miss(shooter.position))
	ShotSystem.rebound_won.connect(func(b, _off):
		if b != null: _floating_text.spawn_event(b.position, "REBOUND"))
	AbilitySystem.turnover_occurred.connect(func(b): _floating_text.spawn_event(b.position, "TURNOVER!"))

	# Action menu signals
	_action_menu.action_chosen.connect(_on_action_chosen)
	_action_menu.submenu_action_chosen.connect(_on_submenu_action_chosen)
	_action_menu.action_hovered.connect(_on_action_hovered)
	_action_menu.action_unhovered.connect(func():
		if _is_animating:
			return
		if _ui_state == UIState.BALLER_SELECTED:
			_target_overlay.show_move_range(_selected_baller())
		else:
			_target_overlay.clear_preview())

	# Enemy info panel signals
	_enemy_info_panel.closed.connect(func(): pass)  # panel self-hides; no state change needed

	# Confirm dialog — confirmed fires BeatManager.end_beat_early()
	_confirm_dialog.confirmed.connect(func(): BeatManager.end_beat_early())

	# Target overlay signals
	_target_overlay.cell_clicked.connect(_on_target_cell_clicked)
	_target_overlay.baller_clicked.connect(_on_target_baller_clicked)
	_target_overlay.cancelled.connect(_on_target_cancelled)

# ─────────────────────────────────────────────
#  UI State Machine
# ─────────────────────────────────────────────

func _set_ui_state(new_state: UIState) -> void:
	_teardown_state_input(_ui_state)
	_ui_state = new_state
	_setup_state_input(new_state)
	match new_state:
		UIState.IDLE:
			_action_menu.hide_menu()
			_target_overlay.clear()
		UIState.BALLER_SELECTED:
			_enemy_info_panel.hide_panel()
			var sel := _selected_baller()
			if sel.can_act():
				_target_overlay.show_move_range(sel)
			else:
				_target_overlay.clear()
			var screen_pos: Vector2 = _court.position + sel.position
			_action_menu.show_for_baller(sel, screen_pos, _undo_available)
		UIState.TARGET_MOVE:
			_action_menu.hide_menu()
			_target_overlay.show_move_range(_selected_baller())
		UIState.TARGET_CUT:
			_action_menu.hide_menu()
			_target_overlay.show_cut_range(_selected_baller())
		UIState.TARGET_PASS:
			_action_menu.hide_menu()
			_target_overlay.show_ally_targets(_ballers, _selected_baller())
		UIState.TARGET_LEADERSHIP:
			_action_menu.hide_menu()
			_target_overlay.show_ally_targets(_ballers, _selected_baller())

func _setup_state_input(state: UIState) -> void:
	# Future steps (19-22) attach per-state input here (D-key guard display,
	# Ctrl+Z undo, Tab cycle, Y/N confirm, etc.) instead of growing _input().
	match state:
		UIState.IDLE:
			set_process_unhandled_input(true)
		_:
			pass  # Targeting states use TargetOverlay._unhandled_input

func _teardown_state_input(_state: UIState) -> void:
	# If a state hides an animated panel, await the tween here before returning.
	# Pattern (Step 17+): await _some_panel.hide_animated()
	# Never call _set_ui_state() before the previous state's animated hide completes —
	# doing so creates a race where the new state's Enter fires before the panel closes.
	pass

# ─────────────────────────────────────────────
#  Signal handlers — beat / game events
# ─────────────────────────────────────────────

func _on_beat_started(beat_num: int) -> void:
	if beat_num == 1:
		_reset_positions()
		_reset_possession_stats()
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
	if action_type == "pass":
		_stat_add(sel, "ast")
	_set_ui_state(UIState.IDLE)
	_refresh_status()

func _on_shot_made(shooter: Node, points: int) -> void:
	_ball_indicator.clear_override()
	_log("MADE +%dpts! (%s)" % [points, shooter.stats.display_name], "score")
	_refresh_status()

func _on_shot_missed(shooter: Node) -> void:
	_ball_indicator.clear_override()
	_log("Missed shot (%s)" % shooter.stats.display_name, "miss")

func _on_rebound(baller, is_offensive: bool) -> void:
	if baller != null:
		_log("Rebound: %s (%s)" % [baller.stats.display_name, "OFF" if is_offensive else "DEF"])
	else:
		_log("Defensive rebound — possession ends")
	_refresh_status()

func _on_quarter_ended(quarter: int) -> void:
	_ball_indicator.clear_override()
	_log("=== Q%d ENDED  %d-%d ===" % [quarter, QuarterManager.allied_score, QuarterManager.enemy_score], "quarter")
	_refresh_status()

func _on_match_ended(allied: int, enemy: int) -> void:
	var winner: String = "ALLIED WINS" if allied > enemy else "ENEMY WINS"
	_match_overlay.text = "%s\n%d — %d\nPress R to restart" % [winner, allied, enemy]
	_match_overlay.visible = true
	_set_ui_state(UIState.IDLE)
	_log("MATCH OVER — %s" % winner)

func _on_defense_resolved(scored: bool, points: int, eo: float, ad: float, sf: float) -> void:
	_close_all_panels()
	if _is_animating:
		_pending_transition = func(): _show_defense_screen(scored, points, eo, ad, sf)
	else:
		_show_defense_screen(scored, points, eo, ad, sf)

func _show_defense_screen(scored: bool, points: int, eo: float, ad: float, sf: float) -> void:
	_transition_screen.show_defense_result(scored, points, eo, ad, sf)

func _on_quarter_break_ready(quarter: int, allied: int, enemy: int) -> void:
	_close_all_panels()
	_transition_screen.show_quarter_end(quarter, allied, enemy, _possession_stats)

func _on_halftime_ready(allied: int, enemy: int) -> void:
	_close_all_panels()
	_transition_screen.show_halftime(allied, enemy)

func _close_all_panels() -> void:
	_action_menu.hide_menu()
	_enemy_info_panel.hide_panel()
	_target_overlay.clear()
	_set_ui_state(UIState.IDLE)

# ─────────────────────────────────────────────
#  Undo
# ─────────────────────────────────────────────

func _capture_undo_snapshot(baller: Node) -> void:
	_undo_snapshot = {
		baller    = baller,
		col       = baller.grid_col,
		row       = baller.grid_row,
		position  = baller.position,
		stamina   = baller.current_stamina,
		actions_was = BeatManager.actions_remaining,
	}
	_undo_available = true

func _execute_undo() -> void:
	if not _undo_available:
		return
	var snap: Dictionary = _undo_snapshot
	var b: Node = snap.baller
	# Snap any in-progress move animation first
	if _is_animating:
		_snap_animations()
	# Clear current cell occupancy, then restore via place_on_grid so GridManager stays consistent
	var old_cell: GridManager.GridCell = GridManager.get_cell(b.grid_col, b.grid_row)
	if old_cell != null and old_cell.occupant == b:
		old_cell.occupant = null
	MovementSystem.set_path(b, [])  # Clear any in-flight BFS path
	b.place_on_grid(snap.col, snap.row)
	b.position            = snap.position
	var stamina_delta: int = snap.stamina - b.current_stamina
	b.current_stamina = snap.stamina
	if stamina_delta != 0:
		StaminaSystem.stamina_changed.emit(b, stamina_delta)
	b.acted_this_beat     = false
	b.is_in_motion        = false
	b.move_destination    = Vector2i(-1, -1)
	b.consecutive_actions = max(0, b.consecutive_actions - 1)
	BeatManager.actions_remaining = snap.actions_was
	_undo_available = false
	_undo_snapshot  = {}
	_set_ui_state(UIState.IDLE)
	_refresh_status()
	_log("Undo: move reversed")

# ─────────────────────────────────────────────
#  Tab cycling
# ─────────────────────────────────────────────

func _select_next_available_baller() -> void:
	var start: int = _selected_idx
	for offset in range(1, 6):
		var idx: int = (start + offset) % 5
		var b: Node = _ballers[idx]
		if not b.acted_this_beat and not b.is_exhausted:
			_selected_idx = idx
			_refresh_status()
			_set_ui_state(UIState.BALLER_SELECTED)
			return
	_log("All ballers have acted this beat")

# ─────────────────────────────────────────────
#  Signal handlers — ActionMenu
# ─────────────────────────────────────────────

func _on_action_chosen(action_id: String) -> void:
	var sel := _selected_baller()
	match action_id:
		"move":
			_set_ui_state(UIState.TARGET_MOVE)
		"cut":
			_set_ui_state(UIState.TARGET_CUT)
		"pass":
			_set_ui_state(UIState.TARGET_PASS)
		"shoot":
			_shot_arc.show_arc(sel.position, sel.grid_col)
			AbilitySystem.attempt_shot(sel)
			_refresh_status()
		"screen":
			AbilitySystem.perform_screen(sel)
			_refresh_status()
		"end_turn":
			AbilitySystem.end_turn(sel)
			_refresh_status()
		"undo":
			_execute_undo()
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
	if _ui_state == UIState.TARGET_MOVE or _ui_state == UIState.BALLER_SELECTED:
		var sel := _selected_baller()
		if sel.can_act():
			_capture_undo_snapshot(sel)
		AbilitySystem.initiate_move(sel, Vector2i(col, row))
		_refresh_status()
	elif _ui_state == UIState.TARGET_CUT:
		AbilitySystem.perform_cut(_selected_baller(), Vector2i(col, row))
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
	if _ui_state in [UIState.TARGET_MOVE, UIState.TARGET_CUT, UIState.TARGET_PASS, UIState.TARGET_LEADERSHIP]:
		_set_ui_state(UIState.BALLER_SELECTED)
	else:
		_set_ui_state(UIState.IDLE)

func _on_action_hovered(action_id: String) -> void:
	if _is_animating:
		return
	var sel := _selected_baller()
	match action_id:
		"move":
			_target_overlay.show_move_range(sel)
		"cut":
			_target_overlay.preview_cut_range(sel)
		"pass":
			_target_overlay.preview_pass_targets(sel)
		"screen":
			_target_overlay.preview_screen_target(sel)
		"trash_talk":
			_target_overlay.preview_trash_range(sel)
		_:
			_target_overlay.clear_preview()

# ─────────────────────────────────────────────
#  Animation handlers
# ─────────────────────────────────────────────

func _on_baller_moved(baller: Node, target_pos: Vector2) -> void:
	_is_animating = true
	_anim_count += 1
	var tween := create_tween()
	tween.tween_property(baller, "position", target_pos, 0.22)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.finished.connect(_on_single_anim_done, CONNECT_ONE_SHOT)

func _on_pass_completed(from_pos: Vector2, to_pos: Vector2) -> void:
	_is_animating = true
	_anim_count += 1
	var target: Vector2 = to_pos + Vector2(0.0, -28.0)  # -28 = BallIndicator.Y_OFFSET
	_ball_indicator.tween_to(target, 0.30)
	# Ball indicator's internal tween does not connect to _on_single_anim_done directly —
	# use a one-shot timer to decouple it cleanly
	get_tree().create_timer(0.30).timeout.connect(_on_single_anim_done, CONNECT_ONE_SHOT)

func _on_single_anim_done() -> void:
	_anim_count -= 1
	if _anim_count == 0:
		_finish_animation()
	elif _anim_count < 0:
		push_warning("[ANIM] _anim_count underflow — reset to 0")
		_anim_count = 0
		_finish_animation()

func _finish_animation() -> void:
	_anim_count = 0
	_is_animating = false
	if _pending_transition.is_valid():
		var c: Callable = _pending_transition
		_pending_transition = Callable()
		c.call()

func _snap_animations() -> void:
	# ESC during animation: snap all ballers to their authoritative grid positions
	for b in _ballers + _enemies:
		b.position = GridManager.grid_to_world(b.grid_col, b.grid_row)
	_ball_indicator.clear_override()
	_anim_count = 0
	_finish_animation()

# ─────────────────────────────────────────────
#  Input
# ─────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	# Restart after match end — always available
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R and _match_overlay.visible:
			get_tree().reload_current_scene()
			return

	# Ctrl+Z undo — allowed even during animation
	if event is InputEventKey and event.pressed and event.ctrl_pressed and event.keycode == KEY_Z:
		_execute_undo()
		get_viewport().set_input_as_handled()
		return

	# ESC during animation snaps all tweens to their final positions
	if _is_animating:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_snap_animations()
			get_viewport().set_input_as_handled()
		return

	# Mouse move — hover cursor over enemy tokens
	if event is InputEventMouseMotion:
		if _ui_state == UIState.IDLE or _ui_state == UIState.BALLER_SELECTED:
			var court_pos: Vector2 = event.position - _court.position
			var over_enemy: bool = false
			for enemy in _enemies:
				if court_pos.distance_to(enemy.position) <= GridManager.CELL_SIZE * 0.45:
					over_enemy = true
					break
			if over_enemy:
				Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
			else:
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)

	# LMB click — select a baller or inspect an enemy
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
			# Check enemy clicks
			for enemy in _enemies:
				if court_pos.distance_to(enemy.position) <= GridManager.CELL_SIZE * 0.45:
					_enemy_info_panel.show_for_enemy(enemy, event.position)
					if _ui_state == UIState.BALLER_SELECTED:
						_action_menu.hide_menu()
					get_viewport().set_input_as_handled()
					return
			# Clicks on non-baller/non-enemy court cells are handled by TargetOverlay
			# (in BALLER_SELECTED, cancelled signal fires → _on_target_cancelled → IDLE)
		return

	if not event is InputEventKey or not event.pressed:
		return

	# Let modal dialogs and shortcut ref handle their own keys via _unhandled_input
	if _confirm_dialog.visible or _shortcut_ref.visible:
		return

	# Suppress gameplay shortcuts while a transition screen is active
	if _transition_screen.visible:
		return

	match event.keycode:
		KEY_ESCAPE:
			if _ui_state in [UIState.TARGET_MOVE, UIState.TARGET_CUT, UIState.TARGET_PASS, UIState.TARGET_LEADERSHIP]:
				_set_ui_state(UIState.BALLER_SELECTED)
			else:
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

		KEY_TAB:
			_select_next_available_baller()

		KEY_M:
			var sel: Node = _selected_baller()
			_capture_undo_snapshot(sel)
			var dest := Vector2i(sel.grid_col, max(0, sel.grid_row - 3))
			AbilitySystem.initiate_move(sel, dest)
			_set_ui_state(UIState.IDLE)
			_refresh_status()

		KEY_C:
			var sel: Node = _selected_baller()
			var dest := Vector2i(sel.grid_col, max(0, sel.grid_row - 3))
			AbilitySystem.perform_cut(sel, dest)
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
			var sel_s: Node = _selected_baller()
			_shot_arc.show_arc(sel_s.position, sel_s.grid_col)
			AbilitySystem.attempt_shot(sel_s)
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
			_set_ui_state(UIState.IDLE)
			if BeatManager.actions_remaining > 0:
				_confirm_dialog.show_confirm(
					"End beat with %d action(s) unused?" % BeatManager.actions_remaining)
			else:
				BeatManager.end_beat_early()
			_refresh_status()

		KEY_D:
			_debug_mode = (_debug_mode + 1) % 4
			_zone_overlay.visible = _debug_mode == 1 or _debug_mode == 2
			_guard_display.visible = _debug_mode == 2 or _debug_mode == 3

		KEY_QUOTELEFT:
			_log_panel.visible = not _log_panel.visible

		KEY_QUESTION:
			_shortcut_ref.visible = not _shortcut_ref.visible
			_shortcut_ref.queue_redraw()
			get_viewport().set_input_as_handled()

# ─────────────────────────────────────────────
#  HUD helpers
# ─────────────────────────────────────────────

func _refresh_status() -> void:
	var sel: Node = _selected_baller()
	_scoreboard.refresh()
	_active_play_banner.refresh()
	_baller_info_bar.refresh(sel)
	_selection_ring.position = sel.position
	_selection_ring.queue_redraw()

func _log(msg: String, category: String = "default") -> void:
	_log_lines.append(msg)
	if _log_lines.size() > 7:
		_log_lines.pop_front()
	_log_label.text = "\n".join(_log_lines)
	_log_panel.append(msg, category)

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

func _reset_possession_stats() -> void:
	_possession_stats.clear()
	for b in _ballers:
		_possession_stats[b.stats.display_name] = {pts = 0, ast = 0, scr = 0}

func _stat_add(baller: Node, stat: String, amount: int = 1) -> void:
	var name: String = baller.stats.display_name
	if name in _possession_stats:
		_possession_stats[name][stat] += amount

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
