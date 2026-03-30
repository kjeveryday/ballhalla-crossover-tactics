extends Node2D
# TestBeatManager — Step 6 acceptance criteria verification
#
# Keyboard controls (interactive):
#   1     — spend one "move" action
#   E     — end beat early
#   Space — start new possession
#   R     — reset / start new possession

func _ready() -> void:
	print("=== TestBeatManager: Step 6 Acceptance Criteria ===")
	_run_tests()
	print("=== Automated tests complete ===")
	print("--- Interactive: 1=spend action  E=end early  Space/R=new possession ---")
	# Wire shot clock to UI label if one is present
	ShotClock.clock_updated.connect(_on_clock_updated)

func _run_tests() -> void:
	_test_possession_start()
	_test_action_spend()
	_test_beat_advance()
	_test_early_end()
	_test_possession_end()

# --- Automated tests ---

func _test_possession_start() -> void:
	BeatManager.start_possession()
	_assert(BeatManager.current_beat == 1, "Beat starts at 1")
	_assert(BeatManager.actions_remaining == 3, "Actions start at 3")
	_assert(ShotClock.time_remaining == 24, "Clock starts at 24")

func _test_action_spend() -> void:
	BeatManager.start_possession()
	var committed_types: Array = []
	BeatManager.action_committed.connect(func(t: String): committed_types.append(t))
	BeatManager.spend_action("move")
	_assert(BeatManager.actions_remaining == 2, "Actions remaining after 1 spend: 2")
	_assert(committed_types.size() == 1 and committed_types[0] == "move",
		"action_committed fires with correct type on spend")
	BeatManager.spend_action("pass")
	_assert(BeatManager.actions_remaining == 1, "Actions remaining after 2 spends: 1")

func _test_beat_advance() -> void:
	BeatManager.start_possession()
	var beat_ended_nums: Array = []
	var beat_started_nums: Array = []
	BeatManager.beat_ended.connect(func(n: int): beat_ended_nums.append(n))
	BeatManager.beat_started.connect(func(n: int): beat_started_nums.append(n))
	BeatManager.spend_action("move")
	BeatManager.spend_action("pass")
	BeatManager.spend_action("shoot")  # 3rd action — auto-ends beat
	_assert(BeatManager.current_beat == 2, "Beat advances to 2 after 3 actions")
	_assert(BeatManager.actions_remaining == 3, "Actions reset to 3 at beat start")
	_assert(ShotClock.time_remaining == 21, "Clock decrements to 21 after beat 1")
	_assert(beat_ended_nums.size() >= 1 and beat_ended_nums[0] == 1,
		"beat_ended(1) fires")
	_assert(beat_started_nums.size() >= 1 and beat_started_nums[0] == 2,
		"beat_started(2) fires")

func _test_early_end() -> void:
	BeatManager.start_possession()
	BeatManager.spend_action("move")
	BeatManager.end_beat_early()
	_assert(BeatManager.current_beat == 2, "Early end advances beat to 2")
	_assert(BeatManager.actions_remaining == 3, "Actions reset after early end")
	_assert(ShotClock.time_remaining == 21, "Clock decrements on early end")

func _test_possession_end() -> void:
	var ended: Array = [false]
	BeatManager.possession_ended.connect(func(): ended[0] = true)
	BeatManager.start_possession()
	for _i in range(24):  # 8 beats × 3 actions
		BeatManager.spend_action("move")
	_assert(ended[0], "possession_ended fires after 8 beats")
	_assert(ShotClock.time_remaining == 0, "Clock reaches 0 at possession end")

# --- Interactive keyboard controls ---

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	match event.keycode:
		KEY_1:
			if BeatManager.actions_remaining > 0:
				BeatManager.spend_action("move")
				BeatManager.action_resolved.emit()
			else:
				print("[BEAT] No actions remaining — start a new possession (Space)")
		KEY_E:
			BeatManager.end_beat_early()
		KEY_SPACE, KEY_R:
			BeatManager.start_possession()
			print("[BEAT] New possession started interactively")

# --- Helpers ---

func _on_clock_updated(seconds_left: int) -> void:
	print("[CLOCK] Display: %d" % seconds_left)

func _assert(condition: bool, label: String, expected = null, actual = null) -> void:
	if condition:
		print("[PASS] %s" % label)
	else:
		if expected != null:
			print("[FAIL] %s — expected %s, got %s" % [label, str(expected), str(actual)])
		else:
			print("[FAIL] %s" % label)
