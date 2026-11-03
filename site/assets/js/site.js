(function () {
  var body = document.body, base = body.dataset.baseurl || "";
  var sidebar = document.getElementById("sidebar");
  document.getElementById("menu-toggle").addEventListener("click", function () { body.classList.toggle("menu-open"); });

  // Theme switcher
  var root = document.documentElement, tbtn = document.getElementById("theme-toggle");
  function current() { return root.dataset.theme || (window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light"); }
  function paint() {
    var dark = current() === "dark";
    tbtn.textContent = dark ? "\u2600" : "\u263E";
    tbtn.setAttribute("aria-label", dark ? "Switch to light mode" : "Switch to dark mode");
    tbtn.title = dark ? "Switch to light mode" : "Switch to dark mode";
  }
  tbtn.addEventListener("click", function () {
    var n = current() === "dark" ? "light" : "dark"; root.dataset.theme = n;
    try { localStorage.setItem("theme", n); } catch (e) {} paint();
  });
  paint();

  // Delegated callout handling also supports nested callouts and keyboard users.
  function toggleCallout(title) {
    var callout = title.closest(".callout.is-collapsible");
    if (!callout) return;
    var collapsed = callout.classList.toggle("is-collapsed");
    title.setAttribute("aria-expanded", collapsed ? "false" : "true");
  }
  document.addEventListener("click", function (e) {
    var title = e.target.closest(".callout.is-collapsible > .callout-title");
    if (title) toggleCallout(title);
  });
  document.addEventListener("keydown", function (e) {
    var title = e.target.closest && e.target.closest(".callout.is-collapsible > .callout-title");
    if (title && (e.key === "Enter" || e.key === " ")) { e.preventDefault(); toggleCallout(title); }
  });

  // Task list items
  document.querySelectorAll("input.task-cb").forEach(function (cb) {
    var li = cb.closest("li"); if (!li) return;
    li.classList.add("task-item");
    if (cb.checked) li.classList.add("is-checked");
  });

  // Math (KaTeX)
  if (window.katex) document.querySelectorAll(".math-i,.math-d").forEach(function (el) {
    try { katex.render(el.dataset.tex, el, { displayMode: el.classList.contains("math-d"), throwOnError: false }); } catch (e) {}
  });

  // Active link + open parent folders
  var norm = function (p) { try { p = decodeURIComponent(p); } catch (e) {} return p.replace(/index\.html$/, "").replace(/\/+$/, "") || "/"; };
  var here = norm(location.pathname);
  document.querySelectorAll("#nav a").forEach(function (a) {
    if (norm(a.pathname) === here) {
      a.classList.add("active"); a.setAttribute("aria-current", "page");
      for (var el = a.parentElement; el && el !== sidebar; el = el.parentElement) if (el.tagName === "DETAILS") el.open = true;
    }
  });

  // Search: normalize punctuation/diacritics and search the complete note text.
  var input = document.getElementById("search-input"), box = document.getElementById("search-results"), nav = document.getElementById("nav");
  var index = null, loading = null;
  function normalize(value) {
    value = String(value || "").toLocaleLowerCase();
    if (value.normalize) value = value.normalize("NFD").replace(/[\u0300-\u036f]/g, "");
    return value.replace(/[^a-z0-9]+/g, " ").trim().replace(/\s+/g, " ");
  }
  function load() {
    if (!loading) loading = fetch(base + "/search.json", { credentials: "same-origin" }).then(function (r) {
      if (!r.ok) throw new Error("Search index returned " + r.status);
      return r.json();
    }).then(function (d) {
      if (!Array.isArray(d)) throw new Error("Search index has an invalid format");
      index = d; return d;
    }).catch(function (err) {
      console.error("Unable to load the note search index:", err); index = []; return index;
    });
    return loading;
  }
  function run() {
    var q = normalize(input.value);
    if (!q) { box.hidden = true; nav.hidden = false; return; }
    if (!index) return;
    var terms = q.split(" "), hits = [];
    index.forEach(function (d) {
      var title = normalize(d.t), desc = normalize(d.d), path = normalize(d.p), content = normalize(d.c), extra = normalize(d.a);
      var score = 0, matched = true;
      terms.forEach(function (w) {
        var inTitle = title.indexOf(w) !== -1, inPath = path.indexOf(w) !== -1;
        var inDesc = desc.indexOf(w) !== -1, inExtra = extra.indexOf(w) !== -1, inContent = content.indexOf(w) !== -1;
        if (!(inTitle || inPath || inDesc || inExtra || inContent)) { matched = false; return; }
        if (inTitle) score += 12; if (inPath) score += 7; if (inDesc) score += 5;
        if (inExtra) score += 4; if (inContent) score += 2;
      });
      if (!matched) return;
      if (d.k === "folder") score += 1;
      hits.push({ d: d, score: score });
    });
    hits.sort(function (a, b) { return b.score - a.score || String(a.d.t).localeCompare(String(b.d.t)); });
    box.textContent = ""; nav.hidden = true; box.hidden = false;
    if (!hits.length) {
      var n = document.createElement("p"); n.className = "no-results";
      n.textContent = "No matching notes found. Try a shorter keyword."; box.appendChild(n); return;
    }
    hits.slice(0, 30).forEach(function (h) {
      var d = h.d, a = document.createElement("a"); a.href = d.u;
      var b = document.createElement("strong"); b.textContent = (d.k === "folder" ? "📁 " : "") + (d.t || "Untitled"); a.appendChild(b);
      if (d.p) { var pp = document.createElement("em"); pp.textContent = d.p; a.appendChild(pp); }
      var source = String(d.c || d.d || ""), sourceNorm = normalize(source), pos = sourceNorm.indexOf(terms[0]);
      var snippet = pos >= 0 ? sourceNorm.slice(Math.max(0, pos - 55), pos + 115) : source.slice(0, 150);
      if (snippet) { var sp = document.createElement("span"); sp.textContent = snippet; a.appendChild(sp); }
      box.appendChild(a);
    });
  }
  input.addEventListener("focus", function () { load().then(run); });
  input.addEventListener("input", function () { load().then(run); });
  input.addEventListener("keydown", function (e) { if (e.key === "Escape") { input.value = ""; run(); input.blur(); } });

  // Table of contents (right edge, Notion style)
  var heads = [].slice.call(document.querySelectorAll("#prose h1,#prose h2,#prose h3,#prose h4,#prose h5"))
    .filter(function (h) { return h.id && !h.classList.contains("page-title"); });
  if (!heads.length) return;
  var min = Math.min.apply(null, heads.map(function (h) { return +h.tagName[1]; }));
  var toc = document.createElement("div"); toc.id = "toc";
  var handle = document.createElement("button"); handle.className = "toc-handle"; handle.setAttribute("aria-label", "Table of contents");
  heads.slice(0, 12).forEach(function (h) { var s = document.createElement("span"); s.style.width = (22 - (+h.tagName[1] - min) * 5) + "px"; handle.appendChild(s); });
  var panel = document.createElement("nav"); panel.className = "toc-panel";
  var title = document.createElement("div"); title.className = "toc-title"; title.textContent = "On this page"; panel.appendChild(title);
  var links = heads.map(function (h) {
    var a = document.createElement("a"); a.href = "#" + h.id; a.textContent = h.textContent;
    a.style.paddingLeft = (0.6 + (+h.tagName[1] - min) * 0.9) + "rem"; panel.appendChild(a); return a;
  });
  toc.appendChild(handle); toc.appendChild(panel); document.body.appendChild(toc);
  var pinned = false;
  toc.addEventListener("mouseenter", function () { toc.classList.add("open"); });
  toc.addEventListener("mouseleave", function () { if (!pinned) toc.classList.remove("open"); });
  handle.addEventListener("click", function () { pinned = !pinned; toc.classList.toggle("open", pinned); });
  panel.addEventListener("click", function (e) {
    if (e.target.tagName === "A" && window.matchMedia("(hover:none)").matches) { pinned = false; toc.classList.remove("open"); }
  });
  if ("IntersectionObserver" in window) {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (en) {
        if (en.isIntersecting) { links.forEach(function (l) { l.classList.remove("on"); }); links[heads.indexOf(en.target)].classList.add("on"); }
      });
    }, { rootMargin: "0px 0px -75% 0px" });
    heads.forEach(function (h) { io.observe(h); });
  }
})();
