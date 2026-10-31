/* Runs the Kociemba two-phase solver (cube.js by Petri Lehtinen) off the main thread. */
importScripts("../vendor/cubejs-cube.js", "../vendor/cubejs-solve.js");
Cube.initSolver();
self.onmessage = (e) => {
  const { id, cmd, scramble, state } = e.data;
  try {
    let result;
    if (cmd === "scramble") result = Cube.scramble();
    else if (cmd === "solve") {
      const c = state ? Cube.fromString(state) : new Cube().move(scramble);
      result = c.solve();
    }
    self.postMessage({ id, result });
  } catch (err) {
    self.postMessage({ id, error: String(err) });
  }
};
self.postMessage({ id: 0, result: "ready" });
