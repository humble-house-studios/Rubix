/* WR Desk: watch a world record, see its moves, then try it yourself. */
(function () {
  const $ = (sel) => document.querySelector(sel);
  const RECORDS = window.RECORDS;
  const store = {
    get(k, fallback) {
      try { const v = localStorage.getItem("wrdesk." + k); return v == null ? fallback : JSON.parse(v); } catch (e) { return fallback; }
    },
    set(k, v) { try { localStorage.setItem("wrdesk." + k, JSON.stringify(v)); } catch (e) { /* storage unavailable */ } },
  };
  const recKey = (r) => `${r.time}-${r.name.replace(/\s+/g, "")}`;
  const fmt = (s) => {
    if (s >= 60) {
      const m = Math.floor(s / 60);
      return `${m}:${(s - m * 60).toFixed(2).padStart(5, "0")}`;
    }
    return s.toFixed(2);
  };

  const state = {
    idx: store.get("selected", 0),
    step: "watch",
    solves: {}, // recKey -> {scramble, solution, official, officialScramble}
  };
  if (!RECORDS[state.idx]) state.idx = 0;
  const rec = () => RECORDS[state.idx];

  /* ---------------- clock ---------------- */
  const tickClock = () => {
    const d = new Date();
    $("#sysclock").textContent = d.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
  };
  tickClock();
  setInterval(tickClock, 15000);

  /* ---------------- record list ---------------- */
  function renderList() {
    const ol = $("#recordList");
    ol.innerHTML = "";
    RECORDS.forEach((r, i) => {
      const li = document.createElement("li");
      const pb = store.get("pb." + recKey(r), null);
      li.innerHTML = `<button class="rec ${i === state.idx ? "active" : ""}">
          <span class="rank">#${i + 1}</span>
          <span class="t">${r.time.toFixed(2)}</span>
          <span class="who"><b><span class="flag">${r.flag}</span> <span class="nm">${r.name}</span></b><small>${r.date}</small>${pb ? `<span class="pb">your best: ${fmt(pb)}</span>` : ""}</span>
        </button>`;
      li.firstElementChild.addEventListener("click", () => selectRecord(i));
      ol.appendChild(li);
    });
  }

  function renderHead() {
    const r = rec();
    $("#recHead").innerHTML = `
      <div class="big">${r.time.toFixed(2)}<small>s</small></div>
      <div class="meta">
        <b>${r.flag} ${r.name}</b>
        <div>${r.competition} · ${r.date} · #${state.idx + 1} fastest ever</div>
        <div class="note">${r.note || ""}</div>
      </div>`;
    $("#raceThem").textContent = r.name.split(" ")[0];
  }

  function selectRecord(i) {
    state.idx = i;
    store.set("selected", i);
    renderList();
    renderHead();
    renderVideo();
    stopReplay();
    resetPlay();
    if (state.step === "replay") prepareReplay();
    if (state.step === "play") preparePlay();
  }

  /* ---------------- steps ---------------- */
  function goStep(step) {
    state.step = step;
    document.querySelectorAll(".step").forEach((b) => b.classList.toggle("active", b.dataset.step === step));
    document.querySelectorAll(".view").forEach((v) => (v.hidden = v.dataset.view !== step));
    // stop the video when leaving the Watch screen so its audio doesn't follow you
    if (step !== "watch") $("#videoWrap").innerHTML = "";
    else renderVideo();
    if (step === "replay") prepareReplay();
    else stopReplay();
    if (step === "play") preparePlay();
  }
  document.querySelectorAll(".step").forEach((b) => b.addEventListener("click", () => goStep(b.dataset.step)));
  document.querySelectorAll("[data-goto]").forEach((b) => b.addEventListener("click", () => goStep(b.dataset.goto)));

  /* ---------------- step 1: video ---------------- */
  function parseYouTube(input) {
    if (!input) return null;
    const s = input.trim();
    if (/^[\w-]{11}$/.test(s)) return s;
    const m = s.match(/(?:youtu\.be\/|v=|\/embed\/|\/shorts\/|\/live\/)([\w-]{11})/);
    return m ? m[1] : null;
  }
  const videoFor = (r) => store.get("video." + recKey(r), null) || parseYouTube(r.youtube);

  const staticTexture = (() => {
    const c = document.createElement("canvas");
    c.width = c.height = 200;
    const g = c.getContext("2d");
    const img = g.createImageData(200, 200);
    for (let i = 0; i < img.data.length; i += 4) {
      const v = Math.random() * 255;
      img.data[i] = img.data[i + 1] = img.data[i + 2] = v;
      img.data[i + 3] = 255;
    }
    g.putImageData(img, 0, 0);
    return c.toDataURL();
  })();

  function renderVideo(forceForm) {
    if (state.step !== "watch") return;
    const r = rec();
    const id = videoFor(r);
    const wrap = $("#videoWrap");
    const tools = $("#videoTools");
    const searchUrl = "https://www.youtube.com/results?search_query=" +
      encodeURIComponent(`${r.name} ${r.time.toFixed(2)} Rubik's cube world record`);
    if (id && forceForm !== true) {
      const src = `https://www.youtube-nocookie.com/embed/${id}?autoplay=1&mute=1&loop=1&playlist=${id}&rel=0&playsinline=1&modestbranding=1`;
      wrap.innerHTML = `<iframe src="${src}" title="${r.name} ${r.time} world record" allow="autoplay; encrypted-media; picture-in-picture" allowfullscreen></iframe>`;
      tools.innerHTML = `<span>🔁 Looping</span>
        <a href="https://www.youtube.com/watch?v=${id}" target="_blank" rel="noopener">Open on YouTube</a>
        <button class="linkish" id="changeVideo">Use a different video</button>`;
      $("#changeVideo").onclick = () => renderVideo(true);
    } else {
      renderLinkForm(wrap, r, searchUrl);
      tools.innerHTML = id ? `<button class="linkish" id="cancelVideo">Back to the current video</button>` : `<span>No video linked yet</span>`;
      if (id) $("#cancelVideo").onclick = () => renderVideo();
    }
  }

  function renderLinkForm(wrap, r, searchUrl) {
    wrap.innerHTML = `
      <div class="no-video">
        <div class="static" style="background-image:url(${staticTexture})"></div>
        <div class="card">
          <h3>📺 Load the ${r.time.toFixed(2)} solve</h3>
          <p>Find ${r.name}'s record on YouTube, copy the link, and paste it here. It'll loop on this screen.</p>
          <a class="btn" href="${searchUrl}" target="_blank" rel="noopener">🔎 Search YouTube for it</a>
          <form class="link-form" id="linkForm">
            <input id="linkInput" placeholder="Paste a YouTube link…" autocomplete="off" />
            <button class="btn primary" type="submit">Play</button>
          </form>
          <p id="linkErr" style="color:var(--red)"></p>
        </div>
      </div>`;
    $("#linkForm").onsubmit = (e) => {
      e.preventDefault();
      const id = parseYouTube($("#linkInput").value);
      if (!id) {
        $("#linkErr").textContent = "That doesn't look like a YouTube link.";
        return;
      }
      store.set("video." + recKey(r), id);
      renderVideo();
    };
  }

  /* ---------------- solve data (scramble + solution) ---------------- */
  async function getSolve(r) {
    const key = recKey(r);
    if (state.solves[key]) return state.solves[key];
    let data;
    if (r.scramble && r.reconstruction) {
      data = { scramble: r.scramble, solution: r.reconstruction, official: true, officialScramble: true };
    } else {
      const cached = store.get("sample." + key, null);
      if (cached && (!r.scramble || cached.scramble === r.scramble)) data = cached;
      else {
        const scramble = r.scramble || (await Solver.scramble());
        const solution = await Solver.solve(scramble);
        data = { scramble, solution, official: false, officialScramble: !!r.scramble };
        store.set("sample." + key, data);
      }
    }
    state.solves[key] = data;
    return data;
  }

  /* ---------------- step 2: replay ---------------- */
  const replayCube = new CubeView($("#replayCube"), { interactive: false });
  let replayToken = 0;
  let replayRaf = 0;
  let replayData = null;

  function setReplayStatus(t) { $("#replayStatus").innerHTML = t; }

  function stopReplay() {
    replayToken++;
    cancelAnimationFrame(replayRaf);
    replayCube.finishAll();
  }

  async function prepareReplay() {
    stopReplay();
    const token = replayToken;
    const r = rec();
    $("#replayTimer").textContent = "0.00";
    $("#replayTimer").className = "timer";
    $("#replayOverlay").textContent = "";
    $("#replayOverlay").className = "stage-overlay";
    setReplayStatus("The computer is working out the moves…");
    $("#replayMoves").innerHTML = "";
    $("#replayScramble").textContent = "…";
    $("#moveCount").textContent = "";
    replayCube.reset();
    const data = await getSolve(r);
    if (token !== replayToken) return;
    replayData = data;
    stepped = -1;
    $("#replayScramble").textContent = data.scramble;
    const moves = data.solution.trim().split(/\s+/);
    $("#replayMoves").innerHTML = moves.map((m) => `<span>${m}</span>`).join(" ");
    const turns = moves.filter((m) => !/^[xyz]/.test(m)).length;
    $("#moveCount").textContent = `· ${turns} turns · ${(turns / r.time).toFixed(1)} turns/sec`;
    const src = $("#replaySource");
    if (data.official) {
      src.className = "source official";
      src.innerHTML = `<b>Official reconstruction</b>: the actual scramble and the exact moves ${r.name} made.`;
    } else {
      src.className = "source";
      src.innerHTML = `<b>${data.officialScramble ? "Official scramble" : "Practice scramble"}, computer solution.</b>
        The official move-by-move reconstruction isn't loaded for this record, so these are computer-found moves played back at exactly ${r.time.toFixed(2)} s.
        Add the real moves in <code>js/records.js</code>.`;
    }
    replayCube.applyInstant(data.scramble);
    setReplayStatus("Scrambled and ready. Press ▶ to watch it at record speed.");
  }

  function highlight(i) {
    const spans = $("#replayMoves").children;
    for (let k = 0; k < spans.length; k++) {
      spans[k].classList.toggle("on", k === i);
      spans[k].classList.toggle("past", k < i);
    }
  }

  async function playReplay(speed) {
    if (!replayData) return;
    stopReplay();
    stepped = -1;
    const token = replayToken;
    const r = rec();
    const total = r.time;
    replayCube.reset();
    replayCube.applyInstant(replayData.scramble);
    highlight(-1);
    const timer = $("#replayTimer");
    timer.className = "timer";
    timer.textContent = "0.00";
    const ov = $("#replayOverlay");
    ov.className = "stage-overlay big";
    setReplayStatus(speed === 1 ? `Real speed: the whole solve takes ${total.toFixed(2)} s` : `Slow motion: ${Math.round(1 / speed)}× slower than real life`);
    for (const t of ["3", "2", "1"]) {
      ov.textContent = t;
      await new Promise((res) => setTimeout(res, 450));
      if (token !== replayToken) return;
    }
    ov.textContent = "";
    ov.className = "stage-overlay";
    const moves = CubeNotation.parseAlg(replayData.solution);
    const per = (total * 1000) / speed / moves.length;
    const start = performance.now();
    timer.className = "timer running";
    let finished = false;
    moves.forEach((mv, i) => {
      replayCube.push(mv, {
        duration: per,
        onStart: () => token === replayToken && highlight(i),
        onDone: () => {
          if (i !== moves.length - 1 || token !== replayToken) return;
          finished = true;
          timer.className = "timer done";
          timer.textContent = total.toFixed(2);
          highlight(moves.length);
          ov.textContent = "SOLVED";
          setReplayStatus(`That's ${r.name}'s ${total.toFixed(2)}. Blink and you miss it. Now it's your turn.`);
        },
      });
    });
    const loop = (now) => {
      if (token !== replayToken || finished) return;
      timer.textContent = Math.min(total, ((now - start) / 1000) * speed).toFixed(2);
      replayRaf = requestAnimationFrame(loop);
    };
    replayRaf = requestAnimationFrame(loop);
  }

  // Step through the solution one move at a time.
  let stepped = -1; // moves applied in step mode, -1 = not stepping
  function stepReplay() {
    if (!replayData) return;
    const moves = CubeNotation.parseAlg(replayData.solution);
    if (stepped < 0 || stepped >= moves.length) {
      stopReplay();
      replayCube.reset();
      replayCube.applyInstant(replayData.scramble);
      $("#replayOverlay").textContent = "";
      $("#replayOverlay").className = "stage-overlay";
      $("#replayTimer").className = "timer";
      $("#replayTimer").textContent = "0.00";
      highlight(-1);
      if (stepped >= moves.length) {
        stepped = 0;
        setReplayStatus("Back to the scramble. Keep stepping to go move by move.");
        return;
      }
      stepped = 0;
    }
    replayCube.finishAll();
    const mv = moves[stepped];
    replayCube.push(mv, { duration: 260 });
    highlight(stepped);
    stepped++;
    $("#replayTimer").textContent = ((rec().time * stepped) / moves.length).toFixed(2);
    setReplayStatus(`Move ${stepped} of ${moves.length}: <b>${mv.name}</b>${stepped === moves.length ? " · solved!" : ""}`);
  }

  $("#btnRealSpeed").onclick = () => playReplay(1);
  $("#btnSlow").onclick = () => playReplay(0.2);
  $("#btnStep").onclick = stepReplay;

  /* ---------------- step 3: play ---------------- */
  const playCube = new CubeView($("#playCube"), { interactive: true });
  const play = { phase: "idle", start: 0, moves: 0, raf: 0, scramble: null };

  function setPlayStatus(t) { $("#playStatus").innerHTML = t; }

  function resetPlay() {
    cancelAnimationFrame(play.raf);
    play.phase = "idle";
    play.moves = 0;
    playCube.reset();
    playCube.enabled = true;
    $("#playTimer").textContent = "0.00";
    $("#playTimer").className = "timer";
    $("#playOverlay").textContent = "";
    $("#playOverlay").className = "stage-overlay";
    $("#result").hidden = true;
    $("#btnGiveUp").hidden = true;
    $("#raceThemBar").style.width = "0";
    $("#raceYouBar").style.width = "0";
    setPlayStatus(`Hit <b>Scramble</b> to get the same scramble ${rec().name} was solving. Or just mess around with the cube.`);
  }

  function preparePlay() {
    if (play.phase === "idle") resetPlay();
    // warm up the solver so Scramble is instant
    getSolve(rec()).catch(() => {});
  }

  async function scramblePlay() {
    resetPlay();
    play.phase = "scrambling";
    playCube.enabled = false;
    setPlayStatus("Scrambling…");
    const data = await getSolve(rec());
    if (play.phase !== "scrambling") return;
    play.scramble = data.scramble;
    const moves = CubeNotation.parseAlg(data.scramble);
    moves.forEach((mv, i) =>
      playCube.push(mv, {
        duration: 70,
        onDone: () => {
          if (i === moves.length - 1 && play.phase === "scrambling") {
            play.phase = "inspect";
            playCube.enabled = true;
            $("#btnGiveUp").hidden = false;
            $("#playOverlay").textContent = "INSPECT";
            setPlayStatus(`Look it over. <b>The timer starts on your first turn.</b> ${rec().name} needed ${rec().time.toFixed(2)} s.`);
          }
        },
      })
    );
  }

  function startTimer() {
    play.phase = "solving";
    play.start = performance.now();
    $("#playOverlay").textContent = "";
    $("#playTimer").className = "timer running";
    setPlayStatus("Go go go!");
    const r = rec();
    const loop = (now) => {
      if (play.phase !== "solving") return;
      const t = (now - play.start) / 1000;
      $("#playTimer").textContent = fmt(t);
      $("#raceThemBar").style.width = Math.min(100, (t / r.time) * 100) + "%";
      // your bar fills against a 60 s "goal" so there's something to chase
      $("#raceYouBar").style.width = Math.min(100, (t / Math.max(60, t * 1.05)) * 100) + "%";
      if (t >= r.time && !play.theyDone) {
        play.theyDone = true;
        setPlayStatus(`🏁 ${r.name} would already be finished. Keep going!`);
      }
      play.raf = requestAnimationFrame(loop);
    };
    play.theyDone = false;
    play.raf = requestAnimationFrame(loop);
  }

  // Every turn the player makes goes through here.
  function playerTurn(notation) {
    if (play.phase === "scrambling") return;
    const mv = CubeNotation.parseMove(notation);
    if (!mv) return;
    if (play.phase === "inspect" && !mv.isRotation) startTimer();
    if (play.phase === "solving" && !mv.isRotation) play.moves++;
    playCube.push(mv, { duration: 120, onDone: checkSolved });
  }
  playCube.onUserTurn = playerTurn;

  function checkSolved() {
    if (play.phase !== "solving" || playCube.busy || !playCube.isSolved()) return;
    const t = (performance.now() - play.start) / 1000;
    play.phase = "done";
    cancelAnimationFrame(play.raf);
    const r = rec();
    $("#playTimer").textContent = fmt(t);
    $("#playTimer").className = "timer done";
    $("#raceYouBar").style.width = "100%";
    $("#raceThemBar").style.width = "100%";
    $("#btnGiveUp").hidden = true;
    $("#playOverlay").className = "stage-overlay big";
    $("#playOverlay").textContent = "SOLVED!";
    const key = "pb." + recKey(r);
    const prev = store.get(key, null);
    const isPb = prev == null || t < prev;
    if (isPb) store.set(key, t);
    const ratio = t / r.time;
    const cubes = Math.floor(t / r.time);
    let verdict;
    if (ratio < 1) verdict = "🤯 You just beat a world record. Call the WCA.";
    else if (ratio < 2) verdict = "🔥 Within 2× of a world record. Absolutely elite.";
    else if (ratio < 5) verdict = "⚡ Seriously fast. Competition-ready.";
    else if (ratio < 20) verdict = "💪 Solid solve!";
    else if (ratio < 60) verdict = "👏 You solved it! That's more than most people can do.";
    else verdict = "🧩 Solved! Every speedcuber started right here.";
    $("#result").hidden = false;
    $("#result").innerHTML = `
      <h3>${verdict}</h3>
      <p>You: <b>${fmt(t)}</b> · ${r.name}: <b>${r.time.toFixed(2)}</b> → you were <b>${ratio < 1 ? (1 / ratio).toFixed(2) + "× faster" : ratio.toFixed(1) + "× slower"}</b></p>
      <p class="dim">${play.moves} turns (${(play.moves / t).toFixed(1)}/sec).
        ${cubes >= 2 ? `In that time ${r.name.split(" ")[0]} could have solved ${cubes} cubes.` : ""}
        ${isPb ? (prev == null ? "First solve on this record! 🎉" : `New personal best! (was ${fmt(prev)})`) : `Your best: ${fmt(prev)}`}</p>`;
    setPlayStatus("Press <b>Scramble</b> to go again.");
    renderList();
    confetti();
  }

  // "Show me": the computer finishes the cube from wherever you are.
  async function giveUp() {
    if (!(play.phase === "inspect" || play.phase === "solving")) return;
    cancelAnimationFrame(play.raf);
    play.phase = "auto";
    playCube.enabled = false;
    $("#btnGiveUp").hidden = true;
    $("#playTimer").className = "timer";
    $("#playOverlay").textContent = "";
    setPlayStatus("The computer is finishing it for you…");
    await new Promise((res) => {
      const wait = () => (playCube.busy ? requestAnimationFrame(wait) : res());
      wait();
    });
    const sol = await Solver.solveState(play.mirror.asString());
    if (play.phase !== "auto") return;
    const n = CubeNotation.parseAlg(sol).length;
    playCube.pushAlg(sol, 260);
    setPlayStatus(`The computer needs ${n} moves from here. Press <b>Scramble</b> to try again yourself.`);
    play.phase = "idle";
  }

  // A logical copy of the play cube (cube.js model) so the solver can read its state.
  play.mirror = new Cube();
  playCube.onMove = (name) => play.mirror.move(name.replace(/^([URFDLB])w/, (m, f) => f.toLowerCase()));
  const baseReset = playCube.reset.bind(playCube);
  playCube.reset = () => {
    baseReset();
    play.mirror = new Cube();
  };

  $("#btnScramble").onclick = scramblePlay;
  $("#btnReset").onclick = resetPlay;
  $("#btnGiveUp").onclick = giveUp;

  // on-screen move pad
  const PAD = ["U", "U'", "R", "R'", "F", "F'", "D", "D'", "L", "L'", "B", "B'", "M", "M'", "y", "y'", "x", "x'"];
  $("#pad").innerHTML = PAD.map((m) => `<button data-m="${m}" class="${/^[xyz]/.test(m) ? "rot" : ""}">${m}</button>`).join("");
  $("#pad").addEventListener("click", (e) => {
    const b = e.target.closest("button");
    if (b && state.step === "play") playerTurn(b.dataset.m);
  });

  // keyboard
  document.addEventListener("keydown", (e) => {
    if (e.target.closest("input, textarea")) return;
    if (e.metaKey || e.ctrlKey || e.altKey) return;
    if (state.step !== "play") return;
    if (e.code === "Space") {
      e.preventDefault();
      if (play.phase !== "scrambling") scramblePlay();
      return;
    }
    const arrows = { ArrowLeft: "y", ArrowRight: "y'", ArrowUp: "x", ArrowDown: "x'" };
    if (arrows[e.key]) {
      e.preventDefault();
      playerTurn(arrows[e.key]);
      return;
    }
    const k = e.key.toUpperCase();
    if ("UDLRFBMES".includes(k) && k.length === 1) playerTurn(k + (e.shiftKey ? "'" : ""));
    else if ("XYZ".includes(k) && k.length === 1) playerTurn(k.toLowerCase() + (e.shiftKey ? "'" : ""));
  });

  /* ---------------- confetti ---------------- */
  function confetti() {
    const box = $("#confetti");
    const colors = ["#c41e3a", "#ff6a00", "#ffffff", "#ffd500", "#00a651", "#0051ba"];
    for (let i = 0; i < 120; i++) {
      const p = document.createElement("i");
      p.style.left = Math.random() * 100 + "vw";
      p.style.background = colors[i % colors.length];
      p.style.animationDuration = 1.8 + Math.random() * 2 + "s";
      p.style.animationDelay = Math.random() * 0.6 + "s";
      p.style.transform = `rotate(${Math.random() * 360}deg)`;
      box.appendChild(p);
      setTimeout(() => p.remove(), 5000);
    }
  }

  /* ---------------- boot ---------------- */
  renderList();
  renderHead();
  goStep("watch");
  // start the solver in the background while the video plays
  Solver.ready();
})();
