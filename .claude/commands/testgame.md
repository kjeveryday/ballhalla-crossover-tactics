# /testgame — Launch Godot for Playtesting

Open the Ballhalla project in Godot so the user can manually test recent changes.

## Step 1 — Pick a scene

Present this choice to the user:

"Which scene do you want to open?
  1. BattleDemo — full playable match (default)
  2. TestGrid — grid rendering and cell inspection
  3. TestBeatManager — beat/possession flow
  4. TestAbilitiesV2 — ability actions and stamina
  5. TestEnemyAI — enemy movement and targeting
  6. TestQuarterManager — quarter/halftime flow
  7. Other test scene (I'll list them)"

If the user picks 7, list all scenes from `scenes/test/` and let them choose.

Map the choice to the scene path:
- 1 → `res://scenes/battle/BattleDemo.tscn`
- 2 → `res://scenes/test/TestGrid.tscn`
- 3 → `res://scenes/test/TestBeatManager.tscn`
- 4 → `res://scenes/test/TestAbilitiesV2.tscn`
- 5 → `res://scenes/test/TestEnemyAI.tscn`
- 6 → `res://scenes/test/TestQuarterManager.tscn`

## Step 2 — Launch the editor

Use `mcp__godot__get_project_info` to confirm the project is reachable.

Then use `mcp__godot__launch_editor` to open Godot.

Then use `mcp__godot__run_project` with the chosen scene path.

## Step 3 — Tell the user what to look for

Based on which mechanics were most recently worked on (check the Done table in
`docs/roadmap.md`), give the user 2–3 specific things to verify in-game. For example,
if `occupant-tracking` was just done: "Try moving a baller onto another's cell — they
should no longer stack."

## Step 4 — Hand back control

Say: "Game is running. Play around and come back whenever — just say 'back to work'
or name the next thing you want to do."

Do not continue any previous workflow until the user returns.
