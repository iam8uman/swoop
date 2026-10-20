/* Swoop landing page: interactive radial-menu demo, layout catalogue, release info. */
(() => {
  "use strict";

  const REPO = "iam8uman/swoop";
  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  // ---------- Layouts (same fractions as the app) ----------
  const T = 1 / 3;
  const LAYOUTS = {
    maximize: [0, 0, 1, 1], almostMaximize: [.05, .05, .9, .9],
    leftHalf: [0, 0, .5, 1], rightHalf: [.5, 0, .5, 1], topHalf: [0, 0, 1, .5], bottomHalf: [0, .5, 1, .5],
    topLeftQuarter: [0, 0, .5, .5], topRightQuarter: [.5, 0, .5, .5],
    bottomLeftQuarter: [0, .5, .5, .5], bottomRightQuarter: [.5, .5, .5, .5],
    leftThird: [0, 0, T, 1], leftTwoThirds: [0, 0, 2 * T, 1], horizontalCenterThird: [T, 0, T, 1],
    rightTwoThirds: [T, 0, 2 * T, 1], rightThird: [2 * T, 0, T, 1],
    topThird: [0, 0, 1, T], topTwoThirds: [0, 0, 1, 2 * T], verticalCenterThird: [0, T, 1, T],
    bottomTwoThirds: [0, T, 1, 2 * T], bottomThird: [0, 2 * T, 1, T],
    center: null,
  };
  const TITLES = {
    maximize: "Maximize", almostMaximize: "Almost Maximize", center: "Centre",
    leftHalf: "Left Half", rightHalf: "Right Half", topHalf: "Top Half", bottomHalf: "Bottom Half",
    topLeftQuarter: "Top Left Quarter", topRightQuarter: "Top Right Quarter",
    bottomLeftQuarter: "Bottom Left Quarter", bottomRightQuarter: "Bottom Right Quarter",
    leftThird: "Left Third", leftTwoThirds: "Left Two Thirds", horizontalCenterThird: "Centre Third",
    rightTwoThirds: "Right Two Thirds", rightThird: "Right Third",
    topThird: "Top Third", topTwoThirds: "Top Two Thirds", verticalCenterThird: "Middle Third",
    bottomTwoThirds: "Bottom Two Thirds", bottomThird: "Bottom Third",
  };
  // Default ring, counter-clockwise from the right (matches the app).
  const DIRS = ["right", "topRight", "top", "topLeft", "left", "bottomLeft", "bottom", "bottomRight"];
  const RING = {
    center: [],
    right: ["rightHalf", "rightThird", "rightTwoThirds"],
    topRight: ["topRightQuarter"],
    top: ["maximize", "almostMaximize", "topHalf"],
    topLeft: ["topLeftQuarter"],
    left: ["leftHalf", "leftThird", "leftTwoThirds"],
    bottomLeft: ["bottomLeftQuarter"],
    bottom: ["bottomHalf", "bottomThird", "bottomTwoThirds"],
    bottomRight: ["bottomRightQuarter"],
  };
  const KEYS = {
    ArrowLeft: ["leftHalf", "leftThird", "leftTwoThirds"],
    ArrowRight: ["rightHalf", "rightThird", "rightTwoThirds"],
    ArrowUp: ["topHalf", "topThird", "topTwoThirds"],
    ArrowDown: ["bottomHalf", "bottomThird", "bottomTwoThirds"],
    Enter: ["maximize", "almostMaximize"],
    KeyC: ["center"],
    Digit1: ["topLeftQuarter"], Digit2: ["topRightQuarter"],
    Digit3: ["bottomLeftQuarter"], Digit4: ["bottomRightQuarter"],
  };

  // ---------- Layout catalogue ----------
  const GROUPS = [
    ["General", ["maximize", "almostMaximize", "center"]],
    ["Halves", ["leftHalf", "rightHalf", "topHalf", "bottomHalf"]],
    ["Quarters", ["topLeftQuarter", "topRightQuarter", "bottomLeftQuarter", "bottomRightQuarter"]],
    ["Horizontal thirds", ["leftThird", "leftTwoThirds", "horizontalCenterThird", "rightTwoThirds", "rightThird"]],
    ["Vertical thirds", ["topThird", "topTwoThirds", "verticalCenterThird", "bottomTwoThirds", "bottomThird"]],
  ];
  const catalogue = document.getElementById("catalogue");
  if (catalogue) {
    for (const [name, keys] of GROUPS) {
      const g = document.createElement("div");
      g.className = "group";
      g.innerHTML = `<h3>${name}</h3><ul></ul>`;
      const ul = g.querySelector("ul");
      for (const k of keys) {
        const u = LAYOUTS[k] || [.25, .2, .5, .6];
        const li = document.createElement("li");
        const top = 9; // the little title bar
        li.innerHTML =
          `<div class="screen-mini" aria-hidden="true"><span style="left:calc(${u[0] * 100}% + 3px);top:calc(${top + u[1] * (100 - top)}% + 3px);width:calc(${u[2] * 100}% - 6px);height:calc(${u[3] * (100 - top)}% - 6px)"></span></div>${TITLES[k]}`;
        ul.appendChild(li);
      }
      catalogue.appendChild(g);
    }
  }

  // ---------- Latest release ----------
  fetch(`https://api.github.com/repos/${REPO}/releases/latest`)
    .then((r) => (r.ok ? r.json() : null))
    .then((rel) => {
      if (!rel || !rel.tag_name) return;
      document.querySelectorAll("[data-version]").forEach((el) => {
        el.textContent = `Version ${rel.tag_name.replace(/^v/, "")}, free and open source`;
      });
    })
    .catch(() => {});

  // ---------- The demo ----------
  const stage = document.getElementById("demo");
  const display = stage && stage.querySelector(".display");
  if (!display) return;
  const desktop = display.querySelector(".desktop");
  const preview = desktop.querySelector(".preview");
  const ring = desktop.querySelector(".ring");
  const ringSvg = ring.querySelector("svg");
  const label = ring.querySelector(".ring-label");
  const ghost = desktop.querySelector(".ghost");
  const keyHint = desktop.querySelector(".keycap-hint");
  const windows = [...desktop.querySelectorAll(".win")];

  // The visible desktop area, in % of the desktop element (the Dock takes the bottom).
  const AREA = { x: 0, y: 0, w: 100, h: 86 };
  const GAP = 1.2;

  const frames = new Map();
  windows.forEach((w, i) => {
    const s = w.style;
    frames.set(w, {
      x: parseFloat(s.getPropertyValue("--x")), y: parseFloat(s.getPropertyValue("--y")),
      w: parseFloat(s.getPropertyValue("--w")), h: parseFloat(s.getPropertyValue("--h")),
    });
    w.style.zIndex = String(i + 1);
  });
  let active = windows[windows.length - 1];
  active.classList.add("active");

  function setFrame(win, f) {
    frames.set(win, f);
    win.style.setProperty("--x", f.x + "%");
    win.style.setProperty("--y", f.y + "%");
    win.style.setProperty("--w", f.w + "%");
    win.style.setProperty("--h", f.h + "%");
  }

  function raise(win) {
    let max = 0;
    windows.forEach((w) => { max = Math.max(max, +w.style.zIndex || 0); w.classList.remove("active"); });
    win.style.zIndex = String(max + 1);
    win.classList.add("active");
    active = win;
  }

  /** Target frame for an action, with equal gaps at the edges and between windows. */
  function target(action, win) {
    const cur = frames.get(win);
    if (action === "center") {
      return { x: AREA.x + (AREA.w - cur.w) / 2, y: AREA.y + (AREA.h - cur.h) / 2, w: cur.w, h: cur.h };
    }
    const u = LAYOUTS[action];
    const half = GAP / 2;
    const ax = AREA.x + half, ay = AREA.y + half * 1.6, aw = AREA.w - GAP, ah = AREA.h - GAP * 1.6;
    return {
      x: ax + aw * u[0] + half, y: ay + ah * u[1] + half * 1.6,
      w: aw * u[2] - GAP, h: ah * u[3] - GAP * 1.6,
    };
  }

  // Ring drawing ----------------------------------------------------------
  const C = 60, R_OUT = 56, R_IN = 31;
  const pt = (r, deg) => {
    const a = (deg * Math.PI) / 180;
    return `${(C + r * Math.cos(a)).toFixed(2)} ${(C - r * Math.sin(a)).toFixed(2)}`;
  };
  ringSvg.innerHTML =
    DIRS.map((d, i) => {
      const a1 = i * 45 - 22.5 + 2.2, a2 = i * 45 + 22.5 - 2.2;
      return `<path class="seg" data-dir="${d}" d="M ${pt(R_OUT, a1)} A ${R_OUT} ${R_OUT} 0 0 0 ${pt(R_OUT, a2)} L ${pt(R_IN, a2)} A ${R_IN} ${R_IN} 0 0 1 ${pt(R_IN, a1)} Z"/>`;
    }).join("") + `<circle class="hub" cx="60" cy="60" r="24"/>`;
  const segs = new Map([...ringSvg.querySelectorAll(".seg")].map((p) => [p.dataset.dir, p]));
  const hub = ringSvg.querySelector(".hub");

  // Session state ----------------------------------------------------------
  let session = null; // { win, sx, sy, dir, source, list, index, shown }
  const memory = { key: null, win: null, index: 0, frame: null };

  const sameFrame = (a, b) => a && b && ["x", "y", "w", "h"].every((k) => Math.abs(a[k] - b[k]) < 0.5);

  function local(clientX, clientY) {
    const r = desktop.getBoundingClientRect();
    return {
      x: ((clientX - r.left) / r.width) * desktop.offsetWidth,
      y: ((clientY - r.top) / r.height) * desktop.offsetHeight,
    };
  }

  function begin(x, y, win) {
    session = { win, sx: x, sy: y, dir: "center", source: null, list: [], index: 0, shown: false };
    ring.style.left = x + "px";
    ring.style.top = y + "px";
    ring.hidden = false;
    render();
  }

  function choose(source, list, advance) {
    if (!session) return;
    if (session.source === source) {
      if (advance && list.length > 1) session.index = (session.index + 1) % list.length;
    } else {
      session.source = source;
      session.list = list;
      const cont = memory.key === source && memory.win === session.win && sameFrame(memory.frame, frames.get(session.win));
      session.index = cont && list.length > 1 ? (memory.index + 1) % list.length : 0;
    }
    render();
  }

  function moveTo(x, y) {
    if (!session) return;
    const dx = x - session.sx, dy = y - session.sy;
    let dir = "center";
    if (Math.hypot(dx, dy) >= 14) {
      let deg = (Math.atan2(-dy, dx) * 180) / Math.PI;
      if (deg < 0) deg += 360;
      dir = DIRS[Math.floor((deg + 22.5) / 45) % 8];
    }
    if (dir === session.dir) return;
    session.dir = dir;
    if (dir === "center" && session.source && session.source.startsWith("key:")) return;
    choose("dir:" + dir, RING[dir], false);
  }

  function current() {
    return session && session.list.length ? session.list[session.index % session.list.length] : null;
  }

  function render() {
    if (!session) return;
    const action = current();
    const dir = session.source && session.source.startsWith("dir:") ? session.source.slice(4) : null;
    segs.forEach((p, d) => p.classList.toggle("on", d === dir));
    hub.classList.toggle("on", !!action && (dir === "center" || (session.source || "").startsWith("key:")));
    label.querySelector("b").textContent = action ? TITLES[action] : session.source ? "No action" : "Move to choose";
    label.querySelector("small").textContent =
      session.list.length > 1 ? `${session.index + 1} of ${session.list.length} · click to cycle` : "";
    if (action) {
      const f = target(action, session.win);
      if (preview.hidden) {
        const from = frames.get(session.win);
        Object.assign(preview.style, { transition: "none", left: from.x + "%", top: from.y + "%", width: from.w + "%", height: from.h + "%" });
        preview.hidden = false;
        void preview.offsetWidth; // start the grow from the window's frame
        preview.style.transition = "";
      }
      Object.assign(preview.style, { left: f.x + "%", top: f.y + "%", width: f.w + "%", height: f.h + "%" });
    } else {
      preview.hidden = true;
    }
  }

  function end(commit) {
    if (!session) return;
    const s = session;
    const action = current();
    session = null;
    ring.hidden = true;
    preview.hidden = true;
    if (!commit || !action) return;
    const f = target(action, s.win);
    raise(s.win);
    setFrame(s.win, f);
    memory.key = s.source;
    memory.win = s.win;
    memory.index = s.index;
    memory.frame = f;
  }

  // Real input ------------------------------------------------------------
  let pointer = null; // last known pointer position over the stage (client coords)
  let over = false;
  let keySession = false;
  let pointerSession = false;

  const engage = () => { stage.classList.add("engaged"); stopGhost(); };

  stage.addEventListener("pointerenter", (e) => { if (e.pointerType === "mouse") { over = true; engage(); } });
  stage.addEventListener("pointerleave", (e) => {
    if (e.pointerType !== "mouse") return;
    over = false;
    if (keySession) { end(false); keySession = false; }
    stage.classList.remove("engaged");
  });
  stage.addEventListener("pointermove", (e) => {
    pointer = { x: e.clientX, y: e.clientY };
    if (session) { const p = local(e.clientX, e.clientY); moveTo(p.x, p.y); }
  });

  desktop.addEventListener("pointerdown", (e) => {
    engage();
    const win = e.target.closest(".win");
    if (keySession) {
      // Click while holding the trigger: cycle.
      e.preventDefault();
      if (session && session.source) choose(session.source, session.list, true);
      return;
    }
    if (win) raise(win);
    // Press-and-hold works everywhere, including touch screens.
    pointerSession = true;
    desktop.setPointerCapture(e.pointerId);
    const p = local(e.clientX, e.clientY);
    begin(p.x, p.y, win || active);
  });
  desktop.addEventListener("pointermove", (e) => {
    if (pointerSession && session) { const p = local(e.clientX, e.clientY); moveTo(p.x, p.y); }
  });
  const finishPointer = (commit) => () => { if (pointerSession) { pointerSession = false; end(commit); } };
  desktop.addEventListener("pointerup", finishPointer(true));
  desktop.addEventListener("pointercancel", finishPointer(false));

  const armed = () => over || document.activeElement === display;

  window.addEventListener("keydown", (e) => {
    if (!armed()) return;
    if (e.key === "Alt") {
      e.preventDefault();
      if (!keySession && !pointerSession) {
        engage();
        keySession = true;
        let p;
        if (pointer && over) p = local(pointer.x, pointer.y);
        else { const f = frames.get(active); p = { x: ((f.x + f.w / 2) / 100) * desktop.offsetWidth, y: ((f.y + f.h / 2) / 100) * desktop.offsetHeight }; }
        begin(p.x, p.y, active);
      }
      return;
    }
    if (keySession && session) {
      if (e.key === "Escape") { e.preventDefault(); end(false); keySession = false; return; }
      const list = KEYS[e.code];
      if (list) {
        e.preventDefault();
        if (!e.repeat) choose("key:" + e.code, list, true);
      }
    }
  });
  window.addEventListener("keyup", (e) => {
    if (e.key === "Alt" && keySession) {
      e.preventDefault();
      keySession = false;
      end(true);
    }
  });
  window.addEventListener("blur", () => { if (keySession) { keySession = false; end(false); } });
  display.addEventListener("contextmenu", (e) => { if (session) { e.preventDefault(); end(false); keySession = false; pointerSession = false; } });

  // Ghost walkthrough until the visitor takes over ----------------------------
  let ghostOn = false;
  let ghostToken = 0;
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

  function stopGhost() {
    if (!ghostOn) return;
    ghostOn = false;
    ghostToken++;
    ghost.hidden = true;
    keyHint.hidden = true;
    if (!keySession && !pointerSession) end(false);
  }

  function placeGhost(x, y, instant) {
    ghost.classList.toggle("instant", !!instant);
    ghost.style.left = x + "px";
    ghost.style.top = y + "px";
  }

  async function runGhost() {
    if (reduceMotion || ghostOn) return;
    ghostOn = true;
    const token = ++ghostToken;
    const alive = () => ghostOn && token === ghostToken;
    const W = () => desktop.offsetWidth, H = () => desktop.offsetHeight;
    const script = [
      { win: 2, dir: "right", clicks: 0 },
      { win: 0, dir: "left", clicks: 1 },
      { win: 1, dir: "bottomRight", clicks: 0 },
      { win: 2, dir: "top", clicks: 0 },
      { win: 2, dir: "left", clicks: 0 },
      { win: 0, dir: "right", clicks: 0 },
    ];
    ghost.hidden = false;
    placeGhost(W() * 0.5, H() * 0.6, true);
    await sleep(500);
    let step = 0;
    while (alive()) {
      const s = script[step % script.length];
      const win = windows[s.win];
      const f = frames.get(win);
      const gx = ((f.x + f.w * 0.55) / 100) * W(), gy = ((f.y + f.h * 0.5) / 100) * H();
      placeGhost(gx, gy);
      await sleep(650); if (!alive()) return;
      raise(win);
      keyHint.hidden = false; keyHint.classList.add("down");
      begin(gx, gy, win);
      await sleep(380); if (!alive()) return;
      const i = DIRS.indexOf(s.dir), a = (i * 45 * Math.PI) / 180;
      const tx = gx + Math.cos(a) * W() * 0.07, ty = gy - Math.sin(a) * W() * 0.07;
      placeGhost(tx, ty);
      await sleep(260); if (!alive()) return;
      moveTo(tx, ty);
      await sleep(520); if (!alive()) return;
      for (let c = 0; c < s.clicks; c++) {
        ghost.animate([{ transform: "translate(-3px,-2px) scale(1)" }, { transform: "translate(-3px,-2px) scale(.8)" }, { transform: "translate(-3px,-2px) scale(1)" }], { duration: 220 });
        choose(session.source, session.list, true);
        await sleep(650); if (!alive()) return;
      }
      keyHint.classList.remove("down");
      end(true);
      await sleep(1300); if (!alive()) return;
      step++;
    }
  }

  if (!reduceMotion && "IntersectionObserver" in window) {
    const io = new IntersectionObserver((entries) => {
      for (const en of entries) {
        if (en.isIntersecting && !stage.classList.contains("engaged")) setTimeout(runGhost, 600);
        else if (!en.isIntersecting) stopGhost();
      }
    }, { threshold: 0.45 });
    io.observe(stage);
  }
})();
