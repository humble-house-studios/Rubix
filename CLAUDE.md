# Cube Desk: read before every change

A simple, friendly Rubik's cube game (watch the 2.51 world record, then a ladder
of 1-to-8-turn scrambles you watch being made, then undo, and the record scramble). It runs on its own and on a
desk in the Killin' in Comedy office. Godot 4.3, GDScript only.

Samuel builds from his phone: Claude writes and pushes the code, GitHub builds a
web version, and he playtests it in Safari. Keep replies short and in plain words,
and handle git, builds and fixes yourself.
**End every reply with the play link:** https://humble-house-studios.github.io/rubix/

## Rules shared with the other office games
- 720x1280 portrait / 1280x720 landscape, `canvas_items` + `expand`, layout by screen shape.
- Compatibility renderer, nothing web-only, touch and mouse, 88 px touch targets.
- Runs inside the office in a SubViewport: never touch the window unless
  `_owns_window()`. Input arrives as mouse events. The cube renders in its own
  `own_world_3d` SubViewport so it never mixes with the office's 3D world.
- class_names are prefixed `Cube*`; don't clash with the comedy game or Proof Hand.
- The office fetches this repo into `res://games/cube/` and reads `solves` /
  `last_level` on `scenes/main.gd`, and sets `hint_penalty` (Speed Lube relic).
  Keep those names.

## Code
- `engine/`: pure rules (`CubeModel`, `CubeMoves`, `CubeRecord`, `CubeGame`), tested headless.
- `scenes/cube_view.gd`: the 3D cube, swipe-to-turn, turn animation queue.
- `scenes/main.gd`: screens and flow. Saves stars to `user://cube_desk.cfg`.
- Record footage: WATCH plays `res://video/record.ogv` (real clip, Theora) when it
  exists, else the 3D replay. Upload a clip to `video/source/` (+ optional
  `trim.txt`, `credit.txt`); the `video.yml` workflow converts it, commits the
  .ogv + `video/credit.gd`, and starts the deploy. Only clips we have permission for.
- Controller: `scenes/cube_pad.gd` (the shared button frame) drives the menus;
  while a level is played it holds back and `cube_view.gd` takes over: D-pad
  moves a sticker cursor, hold A + direction turns that row, right stick looks,
  X undo, Y hint, B menu. Read the pad from events, never `Input` polling.
