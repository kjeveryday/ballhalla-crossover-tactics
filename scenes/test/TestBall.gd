extends Node2D
# TestBall — Step 3 acceptance criteria verification
# Verifies Basketball state transitions and Hoop queryability.

class DummyBaller extends Node:
	var has_ball: bool = false

var _ball: Basketball
var _signal_received: bool = false
var _last_signal_state: int = -1

func _ready() -> void:
	_ball = $Basketball
	_ball.ball_state_changed.connect(_on_ball_state_changed)
	_run_tests()

func _on_ball_state_changed(new_state: int) -> void:
	_signal_received = true
	_last_signal_state = new_state

func _run_tests() -> void:
	print("=== TestBall: Step 3 Acceptance Criteria ===")
	_test_give_to_and_release()
	_test_set_in_air()
	_test_hoop_queryable()
	print("=== Tests complete ===")

func _test_give_to_and_release() -> void:
	# Use a dummy object as a stand-in baller
	var dummy := DummyBaller.new()
	dummy.set("has_ball", false)
	add_child(dummy)

	_signal_received = false
	_ball.give_to(dummy)

	var give_ok: bool = _ball.state == Basketball.BallState.HELD \
		and _ball.holder == dummy \
		and dummy.get("has_ball") == true \
		and _signal_received \
		and _last_signal_state == Basketball.BallState.HELD

	if give_ok:
		print("[PASS] give_to: state=HELD, holder set, has_ball=true, signal fired")
	else:
		print("[FAIL] give_to did not transition correctly")

	_signal_received = false
	_ball.release()

	var release_ok: bool = _ball.holder == null \
		and _ball.last_holder == dummy \
		and dummy.get("has_ball") == false

	if release_ok:
		print("[PASS] release: holder=null, last_holder set, has_ball=false")
	else:
		print("[FAIL] release did not transition correctly")

	dummy.queue_free()

func _test_set_in_air() -> void:
	var dummy := DummyBaller.new()
	dummy.set("has_ball", false)
	add_child(dummy)

	_ball.give_to(dummy)
	_signal_received = false
	_ball.set_in_air()

	var ok: bool = _ball.state == Basketball.BallState.IN_AIR \
		and _ball.holder == null \
		and _ball.last_holder == dummy \
		and dummy.get("has_ball") == false \
		and _signal_received \
		and _last_signal_state == Basketball.BallState.IN_AIR

	if ok:
		print("[PASS] set_in_air: state=IN_AIR, holder released, signal fired")
	else:
		print("[FAIL] set_in_air did not transition correctly")

	dummy.queue_free()

func _test_hoop_queryable() -> void:
	var hoops := get_tree().get_nodes_in_group("hoop")
	if hoops.is_empty():
		print("[FAIL] Hoop not found in group 'hoop'")
		return

	var hoop: Hoop = hoops[0]
	var pos := hoop.get_grid_position()

	if pos == Vector2i(4, 0):
		print("[PASS] Hoop queryable via group, grid position = (4, 0)")
	else:
		print("[FAIL] Hoop grid position: expected (4,0), got (%d,%d)" % [pos.x, pos.y])
