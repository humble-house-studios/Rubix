# Cube Desk

A bite-size Rubik's cube game that sits on a desk in the
[Killin' in Comedy office](https://humble-house-studios.github.io/killin-in-comedy/office/).
Simplified from the World Record Desk artifact.

**Play:** https://humble-house-studios.github.io/rubix/

- **Watch the 2.51:** Xuanyi Geng's world record (Guangzhou Grand Open 2026) replayed
  turn by turn on a 3D cube from the official scramble and the Ruwix reconstruction,
  at real speed or slow-mo.
- **Play:** level N is scrambled N turns (1 to 8), then the real 2.51 scramble.
  Swipe a row to turn it, drag the background to look around. UNDO takes back a turn;
  HINT makes the next correct turn for you (+2 s). Stars for speed; each level
  unlocks the next.
- In the office, every solve from level 3 up pays Comp Tokens into the Loot Machine.

Tests: `godot --headless -s tests/run_tests.gd` (the record's 32 turns must solve its
scramble). Screenshots: header of `tools/screenshot.gd`. Sounds: `python3 tools/make_audio.py`.
