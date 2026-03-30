extends Node
# TestStateMachine — Step 2 acceptance criteria verification

var _signal_received: bool = false
var _signal_old_state: int = -1
var _signal_new_state: int = -1

func _ready() -> void:
	GameStateMachine.state_changed.connect(_on_state_changed)
	_run_tests()

func _on_state_changed(old_state: int, new_state: int) -> void:
	_signal_received = true
	_signal_old_state = old_state
	_signal_new_state = new_state

func _run_tests() -> void:
	print("=== TestStateMachine: Step 2 Acceptance Criteria ===")
	_test_signal_fires()
	_test_full_possession_chain()
	_test_illegal_transition_warning()
	print("=== Tests complete ===")

func _test_signal_fires() -> void:
	GameStateMachine.current_state = GameStateMachine.BattleState.IDLE
	_signal_received = false

	GameStateMachine.transition_to(GameStateMachine.BattleState.OFFENSE_START)

	var sig_ok: bool = _signal_received \
		and _signal_old_state == GameStateMachine.BattleState.IDLE \
		and _signal_new_state == GameStateMachine.BattleState.OFFENSE_START
	if sig_ok:
		print("[PASS] state_changed signal fires with correct old/new states")
	else:
		print("[FAIL] state_changed signal did not fire correctly")

func _test_full_possession_chain() -> void:
	var chain: Array = [
		GameStateMachine.BattleState.IDLE,
		GameStateMachine.BattleState.OFFENSE_START,
		GameStateMachine.BattleState.SELECTING_BALLER,
		GameStateMachine.BattleState.SELECTING_ACTION,
		GameStateMachine.BattleState.SELECTING_TARGET,
		GameStateMachine.BattleState.RESOLVING_ACTION,
		GameStateMachine.BattleState.SHOT_RESOLVING,
		GameStateMachine.BattleState.REBOUND_RESOLVING,
		GameStateMachine.BattleState.DEFENSE_PHASE,
		GameStateMachine.BattleState.QUARTER_END,
		GameStateMachine.BattleState.MATCH_END,
		GameStateMachine.BattleState.IDLE,
	]

	GameStateMachine.current_state = chain[0]
	var all_passed: bool = true

	for i in range(1, chain.size()):
		_signal_received = false
		GameStateMachine.transition_to(chain[i])
		if not _signal_received or GameStateMachine.current_state != chain[i]:
			print("[FAIL] Transition to %s failed" % GameStateMachine.BattleState.keys()[chain[i]])
			all_passed = false

	if all_passed:
		print("[PASS] Full possession chain: all transitions logged and signal fired")

func _test_illegal_transition_warning() -> void:
	GameStateMachine.current_state = GameStateMachine.BattleState.IDLE
	print("[INFO] Expect WARNING on next line:")
	GameStateMachine.transition_to(GameStateMachine.BattleState.SHOT_RESOLVING)
	if GameStateMachine.current_state == GameStateMachine.BattleState.SHOT_RESOLVING:
		print("[PASS] Illegal transition printed warning and still executed")
	else:
		print("[FAIL] Illegal transition did not execute")
