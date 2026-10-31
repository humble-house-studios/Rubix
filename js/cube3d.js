/* A 3x3x3 Rubik's Cube rendered with three.js.
 * - Animated turns from standard notation (R U' F2 M x y' r Rw ...)
 * - Drag a sticker to turn a layer, drag empty space to look around
 * - Solved-state detection
 */
(function () {
  const HALF = Math.PI / 2;

  const FACE_COLORS = {
    px: 0xc41e3a, // R red
    nx: 0xff6a00, // L orange
    py: 0xffffff, // U white
    ny: 0xffd500, // D yellow
    pz: 0x00a651, // F green
    nz: 0x0051ba, // B blue
  };

  // name -> [axis, layers, direction of a clockwise quarter turn]
  const MOVES = {
    R: ["x", [1], -1], L: ["x", [-1], 1], M: ["x", [0], 1],
    U: ["y", [1], -1], D: ["y", [-1], 1], E: ["y", [0], 1],
    F: ["z", [1], -1], B: ["z", [-1], 1], S: ["z", [0], -1],
    r: ["x", [1, 0], -1], l: ["x", [-1, 0], 1],
    u: ["y", [1, 0], -1], d: ["y", [-1, 0], 1],
    f: ["z", [1, 0], -1], b: ["z", [-1, 0], 1],
    x: ["x", [-1, 0, 1], -1], y: ["y", [-1, 0, 1], -1], z: ["z", [-1, 0, 1], -1],
  };

  const TOKEN = /^([URFDLBMESurfdlbxyz])(w?)(\d*)('?)$/;

  function parseMove(tok) {
    let t = tok.replace(/[’`]/g, "'");
    const m = TOKEN.exec(t);
    if (!m) return null;
    let face = m[1];
    if (m[2]) {
      if (!"URFDLB".includes(face)) return null;
      face = face.toLowerCase();
    }
    let amount = m[3] ? parseInt(m[3], 10) % 4 : 1;
    if (m[4]) amount = -amount;
    if (amount === 3) amount = -1;
    if (amount === -3) amount = 1;
    if (amount === 0) return null;
    const [axis, layers, dir] = MOVES[face];
    return { name: tok, axis, layers, angle: dir * amount * HALF, isRotation: "xyz".includes(face) };
  }

  function parseAlg(str) {
    if (!str) return [];
    return str
      .replace(/\/\/[^\n]*/g, " ")
      .replace(/[()\[\]]/g, " ")
      .split(/\s+/)
      .filter(Boolean)
      .map(parseMove)
      .filter(Boolean);
  }

  // Turn a raw (axis, layer, angle) turn back into notation, for drag turns.
  function toNotation(axis, layer, angle) {
    const names = { x: { 1: "R", 0: "M", "-1": "L" }, y: { 1: "U", 0: "E", "-1": "D" }, z: { 1: "F", 0: "S", "-1": "B" } };
    const name = names[axis][layer];
    const cw = MOVES[name][2];
    const q = Math.round(angle / HALF) * cw;
    if (q === 1) return name;
    if (q === -1) return name + "'";
    return name + "2";
  }

  function roundedRectShape(size, radius) {
    const s = size / 2, r = radius;
    const shape = new THREE.Shape();
    shape.moveTo(-s + r, -s);
    shape.lineTo(s - r, -s);
    shape.quadraticCurveTo(s, -s, s, -s + r);
    shape.lineTo(s, s - r);
    shape.quadraticCurveTo(s, s, s - r, s);
    shape.lineTo(-s + r, s);
    shape.quadraticCurveTo(-s, s, -s, s - r);
    shape.lineTo(-s, -s + r);
    shape.quadraticCurveTo(-s, -s, -s + r, -s);
    return shape;
  }

  class CubeView {
    constructor(container, opts = {}) {
      this.container = container;
      this.interactive = !!opts.interactive;
      this.onMove = opts.onMove || null; // (notation, meta) after each completed turn
      this.queue = [];
      this.current = null;
      this.listeners = [];

      this.renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
      this.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
      container.appendChild(this.renderer.domElement);
      this.renderer.domElement.style.touchAction = "none";

      this.scene = new THREE.Scene();
      this.camera = new THREE.PerspectiveCamera(32, 1, 0.1, 100);
      this.camera.position.set(0, 0, 11.5);

      this.scene.add(new THREE.AmbientLight(0xffffff, 0.75));
      const key = new THREE.DirectionalLight(0xffffff, 0.55);
      key.position.set(4, 8, 6);
      this.scene.add(key);

      this.view = new THREE.Group();
      this.defaultView = new THREE.Euler(0.52, -0.62, 0, "XYZ");
      this.view.rotation.copy(this.defaultView);
      this.scene.add(this.view);

      this.cube = new THREE.Group();
      this.view.add(this.cube);
      this.pivot = new THREE.Object3D();
      this.cube.add(this.pivot);

      this.build();
      this.resize();
      this.ro = new ResizeObserver(() => this.resize());
      this.ro.observe(container);
      this.bindPointer();

      this.lastTime = performance.now();
      const loop = (now) => {
        this.tick(now);
        requestAnimationFrame(loop);
      };
      requestAnimationFrame(loop);
    }

    build() {
      const bodyGeo = new THREE.BoxGeometry(0.97, 0.97, 0.97);
      const bodyMat = new THREE.MeshLambertMaterial({ color: 0x111114 });
      const stickerGeo = new THREE.ShapeGeometry(roundedRectShape(0.84, 0.12));
      this.cubies = [];
      this.stickers = [];
      const mats = {};
      for (const k in FACE_COLORS) mats[k] = new THREE.MeshLambertMaterial({ color: FACE_COLORS[k], side: THREE.DoubleSide });
      const dirs = [
        ["px", new THREE.Vector3(1, 0, 0)], ["nx", new THREE.Vector3(-1, 0, 0)],
        ["py", new THREE.Vector3(0, 1, 0)], ["ny", new THREE.Vector3(0, -1, 0)],
        ["pz", new THREE.Vector3(0, 0, 1)], ["nz", new THREE.Vector3(0, 0, -1)],
      ];
      for (let x = -1; x <= 1; x++)
        for (let y = -1; y <= 1; y++)
          for (let z = -1; z <= 1; z++) {
            const cubie = new THREE.Group();
            cubie.position.set(x, y, z);
            cubie.add(new THREE.Mesh(bodyGeo, bodyMat));
            for (const [key, n] of dirs) {
              if ((n.x && n.x !== x) || (n.y && n.y !== y) || (n.z && n.z !== z)) continue;
              const st = new THREE.Mesh(stickerGeo, mats[key]);
              st.position.copy(n).multiplyScalar(0.492);
              st.lookAt(n.clone().multiplyScalar(2));
              st.userData = { color: key, normal: n.clone() };
              cubie.add(st);
              this.stickers.push(st);
            }
            this.cube.add(cubie);
            this.cubies.push(cubie);
          }
    }

    /* ---------- moves ---------- */

    // Queue a parsed move or notation string. opts: {duration ms, onStart, onDone, tag}
    push(move, opts = {}) {
      const list = typeof move === "string" ? parseAlg(move) : [move];
      for (const mv of list) this.queue.push(Object.assign({}, mv, opts));
    }

    pushAlg(str, durationMs, perMove) {
      parseAlg(str).forEach((mv, i) => this.queue.push(Object.assign({}, mv, { duration: durationMs }, perMove ? perMove(i, mv) : {})));
    }

    // Apply instantly, no animation.
    applyInstant(str) {
      this.finishAll();
      for (const mv of parseAlg(str)) this.applyTurn(mv.axis, mv.layers, mv.angle);
    }

    finishAll() {
      if (this.current) {
        this.pivot.rotation.set(0, 0, 0);
        this.applyTurn(this.current.axis, this.current.layers, this.current.angle, true);
        this.current = null;
      }
      this.queue.length = 0;
    }

    clearQueue() {
      this.queue.length = 0;
    }

    get busy() {
      return !!this.current || this.queue.length > 0;
    }

    selectLayer(axis, layers) {
      return this.cubies.filter((c) => layers.includes(Math.round(c.position[axis])));
    }

    // Bake a turn into cubie transforms.
    applyTurn(axis, layers, angle, alreadyAttached) {
      const group = alreadyAttached ? this.pivot.children.slice() : this.selectLayer(axis, layers);
      if (!alreadyAttached) {
        this.pivot.rotation.set(0, 0, 0);
        this.pivot.updateMatrixWorld();
        for (const c of group) this.pivot.attach(c);
      }
      this.pivot.rotation[axis] = angle;
      this.pivot.updateMatrixWorld();
      for (const c of group) {
        this.cube.attach(c);
        this.snap(c);
      }
      this.pivot.rotation.set(0, 0, 0);
    }

    snap(c) {
      c.position.set(Math.round(c.position.x), Math.round(c.position.y), Math.round(c.position.z));
      const m = new THREE.Matrix4().makeRotationFromQuaternion(c.quaternion);
      const e = m.elements;
      for (let i = 0; i < 16; i++) e[i] = Math.round(e[i]);
      c.quaternion.setFromRotationMatrix(m);
    }

    startNext() {
      const mv = this.queue.shift();
      if (!mv) return;
      this.current = mv;
      this.current.t0 = performance.now();
      this.pivot.rotation.set(0, 0, 0);
      this.pivot.updateMatrixWorld();
      for (const c of this.selectLayer(mv.axis, mv.layers)) this.pivot.attach(c);
      if (mv.onStart) mv.onStart(mv);
    }

    tick(now) {
      // chain as many instant / finished turns as needed this frame
      for (let guard = 0; guard < 200; guard++) {
        if (!this.current) {
          if (!this.queue.length) break;
          this.startNext();
        }
        const mv = this.current;
        const dur = mv.duration == null ? 160 : mv.duration;
        const t = dur <= 0 ? 1 : Math.min(1, (now - mv.t0) / dur);
        const ease = t < 1 ? 1 - Math.pow(1 - t, 3) : 1;
        this.pivot.rotation[mv.axis] = mv.angle * ease;
        if (t < 1) break;
        this.pivot.rotation.set(0, 0, 0);
        this.applyTurn(mv.axis, mv.layers, mv.angle, true);
        this.current = null;
        if (mv.onDone) mv.onDone(mv);
        if (this.onMove) this.onMove(mv.name, mv);
      }
      // ease camera back when idle-orbiting is released
      if (this.returnView && !this.orbiting) {
        const v = this.view.rotation;
        v.x += (this.defaultView.x - v.x) * 0.08;
        v.y += (this.defaultView.y - v.y) * 0.08;
        if (Math.abs(v.x - this.defaultView.x) + Math.abs(v.y - this.defaultView.y) < 0.001) this.returnView = false;
      }
      if (this.container.offsetParent !== null) this.renderer.render(this.scene, this.camera);
    }

    resize() {
      const w = this.container.clientWidth || 1;
      const h = this.container.clientHeight || 1;
      this.renderer.setSize(w, h, false);
      this.renderer.domElement.style.width = "100%";
      this.renderer.domElement.style.height = "100%";
      this.camera.aspect = w / h;
      // keep the cube fully in frame on narrow screens
      this.camera.fov = w < h ? 32 * Math.min(1.6, h / w) : 32;
      this.camera.updateProjectionMatrix();
    }

    /* ---------- state ---------- */

    reset() {
      this.finishAll();
      for (const c of this.cubies) this.cube.remove(c);
      this.build();
    }

    isSolved() {
      const seen = {};
      const n = new THREE.Vector3();
      for (const st of this.stickers) {
        n.copy(st.userData.normal).applyQuaternion(st.parent.quaternion);
        const k = `${Math.round(n.x)},${Math.round(n.y)},${Math.round(n.z)}`;
        if (seen[k] === undefined) seen[k] = st.userData.color;
        else if (seen[k] !== st.userData.color) return false;
      }
      return true;
    }

    /* ---------- pointer: drag to turn, drag background to look around ---------- */

    bindPointer() {
      const el = this.renderer.domElement;
      const ray = new THREE.Raycaster();
      const ndc = new THREE.Vector2();
      let drag = null;

      const toNdc = (e) => {
        const r = el.getBoundingClientRect();
        ndc.set(((e.clientX - r.left) / r.width) * 2 - 1, -((e.clientY - r.top) / r.height) * 2 + 1);
        return r;
      };

      const screenOf = (localPoint, rect) => {
        const p = this.cube.localToWorld(localPoint.clone()).project(this.camera);
        return new THREE.Vector2((p.x + 1) * 0.5 * rect.width, (1 - p.y) * 0.5 * rect.height);
      };

      el.addEventListener("pointerdown", (e) => {
        const rect = toNdc(e);
        el.setPointerCapture(e.pointerId);
        let hit = null;
        if (this.interactive && this.enabled !== false) {
          ray.setFromCamera(ndc, this.camera);
          hit = ray.intersectObjects(this.stickers, false)[0];
        }
        if (hit) {
          const st = hit.object;
          const normal = st.userData.normal.clone().applyQuaternion(st.parent.quaternion).round();
          drag = {
            type: "turn",
            x: e.clientX, y: e.clientY,
            normal,
            point: this.cube.worldToLocal(hit.point.clone()),
            cubie: st.parent.position.clone(),
            rect,
          };
        } else {
          drag = { type: "orbit", x: e.clientX, y: e.clientY, rx: this.view.rotation.x, ry: this.view.rotation.y };
          this.orbiting = true;
        }
      });

      el.addEventListener("pointermove", (e) => {
        if (!drag) return;
        const dx = e.clientX - drag.x, dy = e.clientY - drag.y;
        if (drag.type === "orbit") {
          this.view.rotation.y = drag.ry + dx * 0.008;
          this.view.rotation.x = Math.max(-1.3, Math.min(1.3, drag.rx + dy * 0.008));
          return;
        }
        if (drag.done || Math.hypot(dx, dy) < 12) return;
        drag.done = true;
        const d = new THREE.Vector2(dx, dy).normalize();
        const s0 = screenOf(drag.point, drag.rect);
        let best = null;
        for (const ax of ["x", "y", "z"]) {
          if (Math.abs(drag.normal[ax]) > 0.5) continue;
          const t = new THREE.Vector3();
          t[ax] = 1;
          const s1 = screenOf(drag.point.clone().add(t), drag.rect).sub(s0);
          if (s1.length() < 1e-3) continue;
          s1.normalize();
          const dot = s1.dot(d);
          if (!best || Math.abs(dot) > Math.abs(best.dot)) best = { t, dot };
        }
        if (!best) return;
        const dir = best.t.clone().multiplyScalar(Math.sign(best.dot));
        const axisVec = new THREE.Vector3().crossVectors(drag.normal, dir);
        const axis = Math.abs(axisVec.x) > 0.5 ? "x" : Math.abs(axisVec.y) > 0.5 ? "y" : "z";
        const unit = new THREE.Vector3();
        unit[axis] = 1;
        // rotating +90° about `unit` moves a surface point toward unit × normal
        const motion = new THREE.Vector3().crossVectors(unit, drag.normal);
        const angle = motion.dot(dir) > 0 ? HALF : -HALF;
        const layer = Math.round(drag.cubie[axis]);
        const name = toNotation(axis, layer, angle);
        if (this.onUserTurn) this.onUserTurn(name);
        else this.push(name, { duration: 130, user: true });
      });

      const end = () => {
        if (drag && drag.type === "orbit") {
          this.orbiting = false;
          this.returnView = true;
        }
        drag = null;
      };
      el.addEventListener("pointerup", end);
      el.addEventListener("pointercancel", end);
    }
  }

  window.CubeView = CubeView;
  window.CubeNotation = { parseAlg, parseMove, invert: invertAlg };

  function invertAlg(str) {
    return str
      .trim()
      .split(/\s+/)
      .filter(Boolean)
      .reverse()
      .map((t) => (t.endsWith("2") ? t : t.endsWith("'") ? t.slice(0, -1) : t + "'"))
      .join(" ");
  }
})();
