# Rubix: WR Desk

You're sitting at a desk in an office, in front of one computer. Pick one of the 10 fastest official 3×3 Rubik's Cube world records (2.51 s down to 4.73 s), then:

1. **Watch.** The record solve loops on the screen (YouTube embed).
2. **The moves.** A 3D cube replays the solve move by move at the exact record speed. There's also slow-mo and step-by-step.
3. **Your turn.** You get the same scramble on a cube you can play. The timer starts on your first turn, and at the end you see how you compare to the record holder. Your personal bests are saved for each record.

## Run it

It's a static site with no build step:

```sh
python3 -m http.server 8000   # then open http://localhost:8000
```

You can also double-click `index.html`. That works too, but the solver then runs on the main thread, so the first load pauses for about 2 seconds.

## Controls (Your turn)

- **Mouse / touch:** drag a sticker to turn that layer. Drag empty space to look around.
- **Keyboard:** `U D L R F B` turn clockwise, `Shift` + key turns counter-clockwise, and `M E S` turn the middle slices. Arrow keys or `X Y Z` rotate the whole cube.
- `Space` scrambles. **Show me** has the computer finish the cube from wherever you are.

## Adding the real videos and moves

Everything about each record lives in `js/records.js`. Each entry takes these optional fields:

- `youtube`: a video id or URL. Players can also paste a link in-game, and it's saved in their browser.
- `scramble` + `reconstruction`: the official WCA scramble and the solver's actual moves (any standard notation, including `x y z`, `r`/`Rw`, `M E S`).
  When both are set, step 2 shows **the real solve**. Until then it shows a computer-found solution for a practice scramble, played back at the record's time, and the screen says so.

## Files

- `index.html`, `css/style.css`: the office and the computer UI
- `js/cube3d.js`: the three.js Rubik's Cube (notation parser, animated turns, drag-to-turn, solved check)
- `js/solver.js`, `js/solver-worker.js`: Kociemba two-phase solver, run in a Web Worker
- `js/main.js`: the game flow
- `vendor/`: three.js r149 (MIT) and [cube.js](https://github.com/ldez/cubejs) (MIT), bundled so the game works offline
