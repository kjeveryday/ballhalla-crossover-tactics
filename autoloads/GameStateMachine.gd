extends Node
# GameStateMachine — Autoload
# Central state authority for the battle scene. All systems check current_state
# before acting. All transitions go through transition_to() — never set
# current_state directly.
# Register as autoload #1 in Project Settings.

enum BattleState {
	IDLE,
	OFFENSE_START,        # Beginning of offensive possession
	SELECTING_BALLER,     # Player choosing which baller to act with
	SELECTING_ACTION,     # Player choosing which action to perform
	SELECTING_TARGET,     # Player choosing target cell/baller
	RESOLVING_ACTION,     # Action animation/resolution in progress
	SHOT_RESOLVING,       # Ball in flight, outcome pending
	REBOUND_RESOLVING,    # Missed shot — determining who gets ball
	DEFENSE_PHASE,        # Automated enemy offense
	QUARTER_END,
	HALFTIME,
	MATCH_END,
	TIMEOUT,
}

# Valid transitions: Dictionary[BattleState, Array[BattleState]]
# Any transition not listed here will print a warning.
const VALID_TRANSITIONS := {
	BattleState.IDLE:               [BattleState.OFFENSE_START],
	BattleState.OFFENSE_START:      [BattleState.SELECTING_BALLER, BattleState.DEFENSE_PHASE],
	BattleState.SELECTING_BALLER:   [BattleState.SELECTING_ACTION],
	BattleState.SELECTING_ACTION:   [BattleState.SELECTING_BALLER, BattleState.SELECTING_TARGET, BattleState.RESOLVING_ACTION],
	BattleState.SELECTING_TARGET:   [BattleState.SELECTING_ACTION, BattleState.RESOLVING_ACTION],
	BattleState.RESOLVING_ACTION:   [BattleState.SELECTING_BALLER, BattleState.SHOT_RESOLVING, BattleState.DEFENSE_PHASE, BattleState.QUARTER_END],
	BattleState.SHOT_RESOLVING:     [BattleState.REBOUND_RESOLVING, BattleState.DEFENSE_PHASE],
	BattleState.REBOUND_RESOLVING:  [BattleState.SELECTING_BALLER, BattleState.DEFENSE_PHASE],
	BattleState.DEFENSE_PHASE:      [BattleState.OFFENSE_START, BattleState.QUARTER_END, BattleState.HALFTIME, BattleState.MATCH_END],
	BattleState.QUARTER_END:        [BattleState.OFFENSE_START, BattleState.HALFTIME, BattleState.MATCH_END],
	BattleState.HALFTIME:           [BattleState.OFFENSE_START],
	BattleState.MATCH_END:          [BattleState.IDLE],
	BattleState.TIMEOUT:            [BattleState.SELECTING_BALLER, BattleState.DEFENSE_PHASE],
}

# TIMEOUT is reachable from any non-terminal state
const TIMEOUT_ALLOWED_FROM := [
	BattleState.SELECTING_BALLER,
	BattleState.SELECTING_ACTION,
	BattleState.SELECTING_TARGET,
	BattleState.DEFENSE_PHASE,
]

var current_state: BattleState = BattleState.IDLE
signal state_changed(old_state: BattleState, new_state: BattleState)

func transition_to(new_state: BattleState) -> void:
	var old := current_state
	var old_name: String = BattleState.keys()[old]
	var new_name: String = BattleState.keys()[new_state]

	# Validate transition
	var valid_targets: Array = VALID_TRANSITIONS.get(old, [])
	var timeout_ok: bool = new_state == BattleState.TIMEOUT and old in TIMEOUT_ALLOWED_FROM
	if new_state not in valid_targets and not timeout_ok:
		print("[STATE] WARNING: illegal transition %s → %s" % [old_name, new_name])

	current_state = new_state
	print("[STATE] %s → %s" % [old_name, new_name])
	state_changed.emit(old, new_state)

func is_state(s: BattleState) -> bool:
	return current_state == s
