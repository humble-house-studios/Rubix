/* Promise-based wrapper around the cube solver.
 * Uses a Web Worker when served over http(s); falls back to the main thread
 * when the game is opened straight from disk (file://), where workers are blocked. */
(function () {
  let worker = null;
  let nextId = 1;
  const pending = new Map();
  let readyPromise = null;

  function initMainThread() {
    return new Promise((resolve) => {
      // let the page paint first – initSolver blocks for ~2 s
      setTimeout(() => {
        Cube.initSolver();
        resolve();
      }, 50);
    });
  }

  function ready() {
    if (readyPromise) return readyPromise;
    if (location.protocol !== "file:" && window.Worker) {
      readyPromise = new Promise((resolve) => {
        try {
          worker = new Worker("js/solver-worker.js");
        } catch (e) {
          worker = null;
          return initMainThread().then(resolve);
        }
        worker.onmessage = (e) => {
          const { id, result, error } = e.data;
          if (id === 0) return resolve();
          const p = pending.get(id);
          if (!p) return;
          pending.delete(id);
          error ? p.reject(new Error(error)) : p.resolve(result);
        };
        worker.onerror = () => {
          worker = null;
          initMainThread().then(resolve);
        };
      });
    } else {
      readyPromise = initMainThread();
    }
    return readyPromise;
  }

  function call(cmd, scramble, state) {
    return ready().then(() => {
      if (!worker) {
        if (cmd === "scramble") return Cube.scramble();
        const c = state ? Cube.fromString(state) : new Cube().move(scramble);
        return c.solve();
      }
      return new Promise((resolve, reject) => {
        const id = nextId++;
        pending.set(id, { resolve, reject });
        worker.postMessage({ id, cmd, scramble, state });
      });
    });
  }

  window.Solver = {
    ready,
    scramble: () => call("scramble"),
    solve: (scramble) => call("solve", scramble),
    // state: a cubejs facelet string (Cube#asString)
    solveState: (state) => call("solve", null, state),
  };
})();
