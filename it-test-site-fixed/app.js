/* Входной тест по информатике: клиентская часть.
   Данные хранятся в Supabase, баллы считает база (функция submit_attempt). */
(function () {
  "use strict";

  const cfg = window.APP_CONFIG || {};
  const root = document.getElementById("app");
  let sb = null;

  // ---------- Справочники ----------
  const LETTERS = ["А", "Б", "В", "Г", "Д", "Е", "Ж", "З"];
  const PARTS = {
    knowledge: { n: 1, title: "Знания", hint: "Компьютер, сети, данные, программирование и базы данных" },
    logic: { n: 2, title: "Логика", hint: "Задачи на сообразительность: специальные знания не нужны" },
    interest: { n: 3, title: "Интересы", hint: "Правильных ответов нет, выбирай то, что ближе" },
  };
  const KIND_ORDER = ["knowledge", "logic", "interest"];
  const TOPICS = {
    pc: "Компьютер и ОС",
    net: "Сети и интернет",
    data: "Данные и двоичный код",
    code: "Программирование",
    sql: "Базы данных и SQL",
    logic: "Логика",
  };
  const TOPIC_ORDER = ["pc", "net", "data", "code", "sql", "logic"];
  const DIRS = {
    web: { short: "Веб", name: "Веб-разработка",
      desc: "Сайты и веб-приложения: всё, что люди видят на экране и нажимают.",
      start: "HTML и CSS, потом JavaScript, потом свой сайт-портфолио." },
    ml: { short: "ML и ИИ", name: "Машинное обучение и ИИ",
      desc: "Программы, которые учатся на данных: распознают, предсказывают, советуют.",
      start: "Python, вероятности и статистика, первые модели в scikit-learn." },
    data: { short: "Аналитика", name: "Аналитика данных",
      desc: "Найти в цифрах ответ на вопрос и понятно объяснить его людям.",
      start: "SQL и таблицы, потом Python и pandas, графики и выводы." },
    db: { short: "Базы данных", name: "Базы данных и бэкенд",
      desc: "Как хранить данные надёжно и доставать их быстро.",
      start: "SQL, проектирование таблиц, PostgreSQL." },
    net: { short: "Сети", name: "Сети и администрирование",
      desc: "Серверы, сети и всё, на чём держатся интернет-сервисы.",
      start: "Как устроен интернет, Linux и командная строка, Docker." },
    sec: { short: "Безопасность", name: "Кибербезопасность",
      desc: "Защищать системы и находить слабые места раньше злоумышленников.",
      start: "Сети и Linux, основы криптографии, учебные CTF-задачи." },
  };
  const DIR_ORDER = ["web", "ml", "data", "db", "net", "sec"];

  const state = {
    uid: null, profile: null, questions: null, attempt: null,
    test: null, selfTest: false, teacherTab: "students", students: null,
  };

  // ---------- Утилиты ----------
  function h(tag, attrs) {
    const el = document.createElement(tag);
    if (attrs) {
      for (const [k, v] of Object.entries(attrs)) {
        if (v == null || v === false) continue;
        if (k === "class") el.className = v;
        else if (k === "html") el.innerHTML = v; // только для своей разметки
        else if (k.startsWith("on") && typeof v === "function") el.addEventListener(k.slice(2), v);
        else el.setAttribute(k, v === true ? "" : String(v));
      }
    }
    for (let i = 2; i < arguments.length; i++) append(el, arguments[i]);
    return el;
  }
  function append(el, kid) {
    if (kid == null || kid === false) return;
    if (Array.isArray(kid)) { kid.forEach((k) => append(el, k)); return; }
    el.append(kid.nodeType ? kid : String(kid));
  }
  function esc(s) {
    return String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  }
  function pct(a, b) { return b ? Math.round((100 * a) / b) : 0; }
  function plural(n, f) {
    const m10 = n % 10, m100 = n % 100;
    if (m10 === 1 && m100 !== 11) return f[0];
    if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return f[1];
    return f[2];
  }
  function firstName(p) { return ((p && p.full_name) || "").trim().split(/\s+/)[0] || ""; }
  function fmtDate(s) {
    try { return new Date(s).toLocaleDateString("ru-RU", { day: "numeric", month: "long" }); } catch (e) { return ""; }
  }
  function fmtMin(sec) { const m = Math.max(1, Math.round((sec || 0) / 60)); return m + " " + plural(m, ["минута", "минуты", "минут"]); }
  function store(key, val) {
    try {
      if (val === undefined) localStorage.removeItem(key);
      else localStorage.setItem(key, JSON.stringify(val));
    } catch (e) { /* хранилище недоступно: не страшно */ }
  }
  function load(key) { try { return JSON.parse(localStorage.getItem(key) || "null"); } catch (e) { return null; } }
  function draftKey() { return "ittest:draft:" + state.uid; }
  function one(x) { return Array.isArray(x) ? x[0] || null : x || null; }

  function humanError(err) {
    const msg = (err && (err.message || err.error_description || String(err))) || "";
    if (/invalid login credentials/i.test(msg)) return "Неверная почта или пароль.";
    if (/email not confirmed/i.test(msg)) return "Почта не подтверждена. Попроси учителя включить Auto Confirm для твоего пользователя.";
    if (/failed to fetch|networkerror|load failed|fetch/i.test(msg)) return "Нет связи с сервером. Проверь интернет и попробуй ещё раз.";
    if (/already_submitted/.test(msg)) return "Тест уже отправлен.";
    if (/jwt|token/i.test(msg)) return "Сессия устарела. Выйди и войди заново.";
    return "Что-то пошло не так: " + msg;
  }

  function mount(view) {
    state.view = view;
    const nodes = Array.prototype.slice.call(arguments, 1);
    root.replaceChildren();
    append(root, nodes);
    window.scrollTo(0, 0);
  }

  function topBar() {
    const p = state.profile;
    const who = p
      ? h("div", { class: "who" },
          h("span", null, p.role === "teacher" ? "Учитель" : (p.full_name || p.email)),
          h("button", { class: "linkbtn", type: "button", onclick: logout }, "Выйти"))
      : null;
    return h("header", { class: "top" }, h("span", null, h("b", null, "Входной тест"), " по информатике"), who);
  }

  function renderLoading(text) {
    mount("loading", topBar(), h("div", { class: "center-msg" }, h("span", { class: "spinner" }), text || "Загрузка…"));
  }

  function renderFatal(title, text) {
    mount("fatal", topBar(), h("h1", null, title), h("p", { class: "lead" }, text));
  }

  // ---------- Подсветка Python ----------
  function highlightPy(src) {
    const re = /("[^"\n]*"|'[^'\n]*')|(#.*$)|\b(def|return|if|else|elif|for|in|while|and|or|not|True|False|None)\b|\b(print|range|len|input|int|str)\b|\b(\d+)\b/gm;
    let out = "", last = 0, m;
    while ((m = re.exec(src))) {
      out += esc(src.slice(last, m.index));
      const cls = m[1] ? "str" : m[2] ? "muted" : m[3] ? "kw" : m[4] ? "fn" : "num";
      out += '<span class="' + cls + '">' + esc(m[0]) + "</span>";
      last = m.index + m[0].length;
    }
    return out + esc(src.slice(last));
  }

  // ---------- Значки ----------
  const PEN_RING = '<svg viewBox="0 0 44 44" aria-hidden="true"><path pathLength="1" d="M24 4.5C35 4 41 12.5 40 23c-1 10.5-9.5 17-19.5 16.5C10 39 3.5 31 4.5 20.5 5.5 10.5 13 4.5 26 6"/></svg>';
  function mark(kind) {
    const s = document.createElement("span");
    if (kind === "ok") s.innerHTML = '<svg class="mk ok" viewBox="0 0 28 28" role="img" aria-label="Верно"><path d="M5 15.5l6 6L23.5 6"/></svg>';
    else if (kind === "bad") s.innerHTML = '<svg class="mk bad" viewBox="0 0 28 28" role="img" aria-label="Неверно"><path d="M7 7l14 14M21 7L7 21"/></svg>';
    else s.innerHTML = '<svg class="mk idk" viewBox="0 0 28 28" role="img" aria-label="Не знаю"><text x="8" y="22">?</text></svg>';
    return s.firstChild;
  }

  // ---------- Вход ----------
  function renderLogin(message) {
    const err = h("p", { class: "err", role: "alert" }, message || "");
    const email = h("input", { id: "email", type: "email", autocomplete: "username", required: true, inputmode: "email" });
    const pass = h("input", { id: "pass", type: "password", autocomplete: "current-password", required: true });
    const btn = h("button", { class: "btn", type: "submit" }, "Войти");
    const form = h("form", { class: "form", novalidate: true },
      h("div", { class: "field" }, h("label", { for: "email" }, "Почта"), email),
      h("div", { class: "field" }, h("label", { for: "pass" }, "Пароль"), pass),
      err,
      h("div", null, btn));
    form.addEventListener("submit", async (e) => {
      e.preventDefault();
      err.textContent = "";
      if (!email.value.trim() || !pass.value) { err.textContent = "Введи почту и пароль."; return; }
      btn.disabled = true; btn.textContent = "Вхожу…";
      try {
        const { data, error } = await sb.auth.signInWithPassword({ email: email.value.trim(), password: pass.value });
        if (error) throw error;
        await enter(data.session);
      } catch (ex) {
        err.textContent = humanError(ex);
        btn.disabled = false; btn.textContent = "Войти";
      }
    });

    mount("login",
      topBar(),
      h("h1", null, "Входной тест по информатике"),
      h("p", { class: "lead" }, "Около 25 минут. Это не экзамен и не оценка: по ответам станет понятно, с чего начать занятия и какое направление в IT тебе ближе."),
      partsList(null),
      form,
      h("p", { class: "note ink small" }, "Почту и пароль для входа выдаёт репетитор."));
    email.focus();
  }

  function partsList(counts) {
    return h("ol", { class: "parts" }, KIND_ORDER.map((k) =>
      h("li", null,
        h("span", { class: "num", "aria-hidden": "true" }, PARTS[k].n),
        h("div", null,
          h("b", null, PARTS[k].title),
          counts ? h("span", { class: "muted" }, ", " + counts[k] + " " + plural(counts[k], ["вопрос", "вопроса", "вопросов"])) : null,
          h("span", { class: "d" }, PARTS[k].hint)))));
  }

  async function logout() {
    try { await sb.auth.signOut(); } catch (e) { /* выходим локально в любом случае */ }
    Object.assign(state, { uid: null, profile: null, questions: null, attempt: null, test: null, selfTest: false, students: null });
    renderLogin();
  }

  // ---------- После входа ----------
  async function enter(session) {
    state.uid = session.user.id;
    renderLoading();
    try {
      const { data, error } = await sb.from("profiles").select("id,email,full_name,role").eq("id", state.uid).maybeSingle();
      if (error) throw error;
      if (!data) {
        return renderFatal("Профиль не найден",
          "Вход прошёл, но в базе нет профиля. Учителю: запусти файл schema.sql в Supabase (SQL Editor), он создаст профили для всех пользователей.");
      }
      state.profile = data;
      if (data.role === "teacher") return showTeacher();
      return showStudentHome();
    } catch (e) {
      renderFatal("Не удалось загрузить данные", humanError(e));
    }
  }

  async function loadQuestions() {
    if (state.questions) return state.questions;
    const { data, error } = await sb.from("questions")
      .select("id,position,kind,topic,prompt,code,multi,options").order("position");
    if (error) throw error;
    state.questions = data || [];
    return state.questions;
  }

  async function loadMyAttempt() {
    // Ученику нельзя читать таблицу attempts напрямую: в ней лежит полный
    // разбор с правильными ответами. RPC возвращает только безопасный результат.
    const { data, error } = await sb.rpc("get_my_attempt");
    if (error) throw error;
    state.attempt = data || null;
    return state.attempt;
  }

  async function showStudentHome() {
    renderLoading();
    try {
      const [att, qs] = await Promise.all([loadMyAttempt(), loadQuestions()]);
      if (!qs.length) return renderFatal("Вопросов пока нет", "Учителю: запусти файл schema.sql в Supabase, он добавит вопросы.");
      if (att) return renderResult(false);
      if (!state.profile.full_name && state.profile.role !== "teacher") return renderName();
      return renderIntro();
    } catch (e) {
      renderFatal("Не удалось загрузить тест", humanError(e));
    }
  }

  function renderName() {
    const input = h("input", { id: "nm", type: "text", autocomplete: "name", maxlength: "80", required: true });
    const err = h("p", { class: "err", role: "alert" });
    const btn = h("button", { class: "btn", type: "submit" }, "Сохранить");
    const form = h("form", { class: "form" },
      h("div", { class: "field" }, h("label", { for: "nm" }, "Имя и фамилия"), input), err, h("div", null, btn));
    form.addEventListener("submit", async (e) => {
      e.preventDefault();
      const v = input.value.trim();
      if (!v) { err.textContent = "Напиши, как тебя зовут."; return; }
      btn.disabled = true;
      const { error } = await sb.rpc("set_my_name", { p_name: v });
      if (error) { err.textContent = humanError(error); btn.disabled = false; return; }
      state.profile.full_name = v;
      renderIntro();
    });
    mount("name", topBar(), h("h1", null, "Как тебя зовут?"),
      h("p", { class: "lead" }, "Имя увидит только твой репетитор рядом с результатами."), form);
    input.focus();
  }

  function counts() {
    const c = { knowledge: 0, logic: 0, interest: 0 };
    state.questions.forEach((q) => { c[q.kind] = (c[q.kind] || 0) + 1; });
    return c;
  }

  function renderIntro() {
    const qs = state.questions;
    const draft = load(draftKey());
    const hasDraft = draft && draft.answers && Object.keys(draft.answers).length > 0;
    const name = firstName(state.profile);
    const start = h("button", { class: "btn", type: "button", onclick: () => startTest(hasDraft ? draft : null) },
      hasDraft ? "Продолжить с вопроса " + (Math.min(draft.idx || 0, qs.length - 1) + 1) : "Начать тест");
    mount("intro",
      topBar(),
      h("h1", null, state.selfTest ? "Пробное прохождение" : name ? "Привет, " + name + "!" : "Привет!"),
      h("p", { class: "lead" },
        "В тесте три части и " + qs.length + " " + plural(qs.length, ["вопрос", "вопроса", "вопросов"]) +
        ", это около 25 минут. К прошлым вопросам можно возвращаться и менять ответы, пока ты не отправишь тест."),
      partsList(counts()),
      h("p", { class: "note" }, "Не знаешь ответа — нажми «Не знаю». Угадывать не нужно: честное «не знаю» поможет точнее составить план занятий."),
      h("div", { class: "row" }, start,
        hasDraft ? h("button", { class: "linkbtn", type: "button", onclick: () => { store(draftKey()); startTest(null); } }, "Начать заново") : null,
        state.selfTest ? h("button", { class: "linkbtn", type: "button", onclick: () => { state.selfTest = false; showTeacher(); } }, "Вернуться в кабинет") : null));
  }

  // ---------- Тест ----------
  function startTest(draft) {
    state.test = draft && draft.answers
      ? { answers: draft.answers, idx: Math.min(draft.idx || 0, state.questions.length - 1), startedAt: draft.startedAt || Date.now() }
      : { answers: {}, idx: 0, startedAt: Date.now() };
    saveDraft();
    renderQuestion();
  }
  function saveDraft() { store(draftKey(), state.test); }
  function answerOf(q) { return state.test.answers[String(q.id)] || []; }
  function isAnswered(q) { return answerOf(q).length > 0; }

  function cellsBar() {
    const qs = state.questions;
    const wrap = h("nav", { class: "cells", "aria-label": "Вопросы" });
    KIND_ORDER.forEach((k) => {
      const grp = h("div", { class: "grp" });
      qs.forEach((q, i) => {
        if (q.kind !== k) return;
        const a = answerOf(q);
        const cls = [a[0] === "idk" ? "idk" : a.length ? "done" : "", i === state.test.idx ? "cur" : ""].join(" ").trim();
        grp.append(h("button", {
          type: "button", class: cls || null, "aria-label": "Вопрос " + (i + 1) + (a.length ? ", есть ответ" : ""),
          "aria-current": i === state.test.idx ? "step" : null,
          onclick: () => { state.test.idx = i; saveDraft(); renderQuestion(); },
        }));
      });
      wrap.append(grp);
    });
    return wrap;
  }

  function renderQuestion() {
    const qs = state.questions;
    const i = state.test.idx;
    const q = qs[i];
    const part = PARTS[q.kind];
    const multi = !!q.multi;
    const given = answerOf(q);
    const isIdk = given[0] === "idk";

    const next = h("button", { class: "btn", type: "button", disabled: !isAnswered(q), onclick: goNext },
      i === qs.length - 1 ? "К отправке" : "Дальше");
    const idkNote = h("p", { class: "idk-on", hidden: !isIdk }, "Ответ: «Не знаю».");

    const opts = h("fieldset", { class: "opts", role: multi ? "group" : "radiogroup", "aria-labelledby": "qtext" });
    const labels = [];
    q.options.forEach((o, j) => {
      const input = h("input", {
        type: multi ? "checkbox" : "radio", name: "q" + q.id, value: o.id,
        checked: given.indexOf(o.id) >= 0,
      });
      const lab = h("label", { class: "opt" + (multi ? " multi" : "") + (given.indexOf(o.id) >= 0 ? " on" : "") },
        input,
        h("span", { class: "let", html: esc(LETTERS[j] || String(j + 1)) + (multi ? "" : PEN_RING) }),
        h("span", { class: "txt" }, looksLikeCode(o.text) ? h("code", null, o.text) : o.text));
      input.addEventListener("change", () => {
        let cur = answerOf(q).filter((x) => x !== "idk");
        if (multi) {
          cur = input.checked ? cur.concat(o.id) : cur.filter((x) => x !== o.id);
        } else {
          cur = [o.id];
        }
        state.test.answers[String(q.id)] = cur;
        if (!cur.length) delete state.test.answers[String(q.id)];
        saveDraft();
        labels.forEach((l) => l.classList.toggle("on", l.querySelector("input").checked));
        next.disabled = !isAnswered(q);
        idkNote.hidden = true;
        refreshCells();
      });
      labels.push(lab);
      opts.append(lab);
    });

    const idkBtn = q.kind === "interest" ? null : h("button", {
      class: "linkbtn", type: "button",
      onclick: () => {
        state.test.answers[String(q.id)] = ["idk"];
        saveDraft();
        goNext();
      },
    }, "Не знаю");

    let cells = cellsBar();
    function refreshCells() { const c = cellsBar(); cells.replaceWith(c); cells = c; }

    const hints = [];
    if (q.kind === "interest") hints.push("Правильных ответов нет, выбери вариант, который ближе всего.");
    if (multi) hints.push("Можно выбрать несколько вариантов.");

    mount("question",
      topBar(),
      h("div", { class: "qmeta" },
        h("span", null, h("b", null, "Часть " + part.n + ". " + part.title)),
        h("span", null, "Вопрос " + (i + 1) + " из " + qs.length)),
      cells,
      h("p", { class: "qtext", id: "qtext" }, q.prompt),
      hints.length ? h("p", { class: "hint" }, hints.join(" ")) : null,
      q.code ? h("pre", { class: "code", html: highlightPy(q.code) }) : null,
      opts,
      idkNote,
      h("div", { class: "qnav" },
        h("button", { class: "btn ghost small", type: "button", disabled: i === 0, onclick: () => { state.test.idx = i - 1; saveDraft(); renderQuestion(); } }, "Назад"),
        h("div", { class: "right" }, idkBtn, next)));
  }

  function looksLikeCode(t) { return /^(SELECT|INSERT|DELETE|UPDATE)\b/.test(t); }

  function goNext() {
    const qs = state.questions;
    if (state.test.idx < qs.length - 1) {
      state.test.idx += 1;
      saveDraft();
      renderQuestion();
    } else {
      renderConfirm();
    }
  }

  document.addEventListener("keydown", (e) => {
    if (state.view !== "question" || e.altKey || e.ctrlKey || e.metaKey) return;
    if (e.target && /^(INPUT|TEXTAREA)$/.test(e.target.tagName) && e.target.type === "text") return;
    const n = parseInt(e.key, 10);
    if (n >= 1 && n <= 8) {
      const inputs = root.querySelectorAll(".opt input");
      if (inputs[n - 1]) { inputs[n - 1].click(); e.preventDefault(); }
    } else if (e.key === "Enter") {
      const btn = root.querySelector(".qnav .right .btn");
      if (btn && !btn.disabled && !(e.target && e.target.tagName === "BUTTON")) { btn.click(); e.preventDefault(); }
    }
  });

  function renderConfirm() {
    const qs = state.questions;
    const missing = qs.map((q, i) => ({ q, i })).filter((x) => !isAnswered(x.q));
    const idk = qs.filter((q) => answerOf(q)[0] === "idk").length;
    const back = h("button", { class: "btn ghost", type: "button", onclick: () => { renderQuestion(); } }, "Вернуться к вопросам");

    if (missing.length) {
      return mount("confirm", topBar(),
        h("h1", null, "Почти всё"),
        h("p", { class: "lead" }, "Без ответа " + missing.length + " " + plural(missing.length, ["вопрос", "вопроса", "вопросов"]) + ". Если не знаешь ответа, жми «Не знаю», это тоже ответ."),
        h("div", { class: "row" }, missing.map((x) =>
          h("button", { class: "btn ghost small", type: "button", onclick: () => { state.test.idx = x.i; saveDraft(); renderQuestion(); } }, "Вопрос " + (x.i + 1)))));
    }

    const err = h("p", { class: "err", role: "alert" });
    const send = h("button", { class: "btn", type: "button", onclick: submit }, "Отправить ответы");
    async function submit() {
      send.disabled = true; send.textContent = "Отправляю…"; err.textContent = "";
      const duration = Math.round((Date.now() - (state.test.startedAt || Date.now())) / 1000);
      const { data, error } = await sb.rpc("submit_attempt", { p_answers: state.test.answers, p_duration: duration });
      if (error) {
        if (/already_submitted/.test(error.message || "")) {
          store(draftKey());
          await loadMyAttempt();
          return renderResult(false);
        }
        err.textContent = humanError(error) + " Ответы сохранены на этом устройстве, можно попробовать ещё раз.";
        send.disabled = false; send.textContent = "Отправить ответы";
        return;
      }
      store(draftKey());
      state.attempt = { answers: state.test.answers, result: data, duration_sec: duration, created_at: new Date().toISOString() };
      state.test = null;
      renderResult(true);
    }

    mount("confirm", topBar(),
      h("h1", null, "Всё готово к отправке"),
      h("p", { class: "lead" }, "Отвечены все " + qs.length + " " + plural(qs.length, ["вопрос", "вопроса", "вопросов"]) +
        (idk ? ", из них «Не знаю» — " + idk + "." : ".") + " После отправки сразу появится результат."),
      h("p", { class: "note" }, "Изменить ответы после отправки уже не получится."),
      err,
      h("div", { class: "row" }, send, back));
  }

  // ---------- Результат ----------
  function knowledgeLevel(p) {
    if (p < 20) return { name: "стартовый", text: "Начинаем с самых основ, так и было задумано." };
    if (p < 45) return { name: "базовый", text: "Кое-что уже знакомо, на это и будем опираться." };
    if (p < 70) return { name: "уверенный", text: "Хорошая база, к практике можно переходить быстрее." };
    return { name: "продвинутый", text: "Сильная база: можно сразу браться за проекты." };
  }
  function logicLevel(p) {
    if (p < 34) return "есть куда расти";
    if (p < 67) return "хорошая";
    return "сильная";
  }
  function topicStatus(p) {
    if (p < 34) return { cls: "zero", text: "с нуля" };
    if (p < 67) return { cls: "mid", text: "подтянуть" };
    return { cls: "good", text: "уверенно" };
  }

  function radarSvg(values) {
    const R = 118, n = values.length;
    const pt = (i, r) => { const a = -Math.PI / 2 + (i * 2 * Math.PI) / n; return [r * Math.cos(a), r * Math.sin(a)]; };
    const poly = (r) => values.map((_, i) => pt(i, r).map((x) => x.toFixed(1)).join(",")).join(" ");
    let s = '<svg class="radar" viewBox="-240 -176 480 352" role="img" aria-label="Склонности по направлениям: ' +
      values.map((v) => esc(v.label) + " " + v.p + "%").join(", ") + '">';
    [0.25, 0.5, 0.75, 1].forEach((k) => { s += '<polygon class="ring" points="' + poly(R * k) + '"/>'; });
    values.forEach((_, i) => { const [x, y] = pt(i, R); s += '<line class="axis" x1="0" y1="0" x2="' + x.toFixed(1) + '" y2="' + y.toFixed(1) + '"/>'; });
    const shape = values.map((v, i) => pt(i, Math.max(4, (R * v.p) / 100)).map((x) => x.toFixed(1)).join(",")).join(" ");
    s += '<polygon class="shape" pathLength="1" points="' + shape + '"/>';
    values.forEach((v, i) => { const [x, y] = pt(i, Math.max(4, (R * v.p) / 100)); s += '<circle class="dot" r="3.5" cx="' + x.toFixed(1) + '" cy="' + y.toFixed(1) + '"/>'; });
    values.forEach((v, i) => {
      const [x, y] = pt(i, R + 20);
      const anchor = x > 8 ? "start" : x < -8 ? "end" : "middle";
      const ty = Math.abs(x) < 8 ? (y < 0 ? y - 16 : y + 6) : y - 4;
      s += '<text x="' + x.toFixed(1) + '" y="' + ty.toFixed(1) + '" text-anchor="' + anchor + '">' + esc(v.label) + "</text>";
      s += '<text class="v" x="' + x.toFixed(1) + '" y="' + (ty + 16).toFixed(1) + '" text-anchor="' + anchor + '">' + v.p + "%</text>";
    });
    return s + "</svg>";
  }

  function optionText(q, id) {
    if (id === "idk") return "«Не знаю»";
    const j = q.options.findIndex((o) => o.id === id);
    return j < 0 ? id : LETTERS[j] + ") " + q.options[j].text;
  }

  // ctx: { attempt, name, mode: "student" | "self" | "teacher", reveal, onReset, onBack }
  function resultView(ctx) {
    const att = ctx.attempt;
    const r = att.result || {};
    const qs = state.questions || [];
    const k = r.knowledge || { score: 0, max: 0 };
    const l = r.logic || { score: 0, max: 0 };
    const kp = pct(k.score, k.max), lp = pct(l.score, l.max);
    const kl = knowledgeLevel(kp);
    const dirVals = DIR_ORDER.map((c) => ({ code: c, label: DIRS[c].short, p: (r.directions || {})[c] || 0 }));
    const top = dirVals.slice().sort((a, b) => b.p - a.p).filter((d) => d.p > 0).slice(0, 2);
    const teacher = ctx.mode === "teacher";
    const name = ctx.name || "";

    const title = teacher ? (name || "Без имени")
      : ctx.mode === "self" ? "Пробный результат"
      : (firstName(state.profile) ? "Готово, " + firstName(state.profile) + "!" : "Готово!");

    const wrap = h("div", { class: ctx.reveal ? "reveal" : null });
    append(wrap, [
      ctx.onBack ? h("p", null, h("button", { class: "linkbtn", type: "button", onclick: ctx.onBack }, "← Все ученики")) : null,
      h("h1", null, title),
      h("p", { class: "lead" }, "Уровень знаний — ", h("span", { class: "hl" }, kl.name), ". ", kl.text),
      h("div", { class: "figs" },
        h("div", null, h("div", { class: "big" }, k.score, h("small", null, " из " + k.max)), h("div", { class: "cap" }, "баллов за знания")),
        h("div", null, h("div", { class: "big" }, l.score, h("small", null, " из " + l.max)), h("div", { class: "cap" }, "логика: " + logicLevel(lp))),
        h("div", null, h("div", { class: "big" }, Math.max(1, Math.round((att.duration_sec || 0) / 60)), h("small", null, " мин")),
          h("div", { class: "cap" }, att.created_at ? "тест пройден " + fmtDate(att.created_at) : "время на тест"))),
    ]);

    // направления
    append(wrap, [
      h("h2", null, teacher ? "Склонности по анкете" : "Что тебе ближе"),
      h("div", { class: "radar-wrap", html: radarSvg(dirVals) }),
      top.length
        ? h("div", { class: "dirs" }, top.map((d) => h("div", { class: "dir" },
            h("h3", null, h("span", null, DIRS[d.code].name), h("span", { class: "p" }, d.p + "%")),
            h("p", null, DIRS[d.code].desc),
            h("p", { class: "start" }, h("b", null, "С чего начать: "), DIRS[d.code].start))))
        : h("p", { class: "muted" }, "Анкета интересов не заполнена."),
      h("p", { class: "note ink small" }, teacher
        ? "Это гипотеза по 8 вопросам анкеты. Стоит перепроверить через 1–2 месяца, когда ученик попробует каждое направление руками."
        : "Это подсказка, а не приговор: интересы меняются. На занятиях мы попробуем разные направления на практике."),
    ]);

    // темы
    const topics = r.topics || {};
    append(wrap, [
      h("h2", null, "Знания по темам"),
      h("ul", { class: "bars" }, TOPIC_ORDER.filter((t) => topics[t]).map((t) => {
        const tp = pct(topics[t].score, topics[t].max);
        const st = topicStatus(tp);
        const filled = Math.round(tp / 10);
        return h("li", null,
          h("span", { class: "name" }, TOPICS[t] || t, teacher ? h("span", { class: "tag " + st.cls }, st.text) : null),
          h("span", { class: "val" }, topics[t].score + " из " + topics[t].max),
          h("span", { class: "sq", "aria-hidden": "true" }, Array.from({ length: 10 }, (_, j) => h("i", { class: j < filled ? "f" : null }))));
      })),
    ]);

    // разбор
    const review = r.review || {};
    const graded = qs.filter((q) => q.kind !== "interest" && review[String(q.id)]);
    if (graded.length) {
      append(wrap, [
        h("h2", null, "Разбор ответов"),
        h("div", { class: "review" }, graded.map((q) => {
          const rv = review[String(q.id)];
          const num = qs.indexOf(q) + 1;
          const kind = rv.ok ? "ok" : rv.idk ? "idk" : "bad";
          return h("details", { class: "rv" },
            h("summary", null, mark(kind), h("span", { class: "n" }, num), h("span", null, q.prompt)),
            h("div", { class: "body" },
              q.code ? h("pre", { class: "code", html: highlightPy(q.code) }) : null,
              h("p", null, h("b", null, teacher ? "Ответ ученика: " : "Твой ответ: "),
                (rv.given && rv.given.length ? rv.given.map((g) => optionText(q, g)).join("; ") : "нет ответа")),
              rv.ok ? null : h("p", null, h("b", null, "Правильно: "), (rv.correct || []).map((c) => optionText(q, c)).join("; ")),
              rv.explanation ? h("p", null, rv.explanation) : null));
        })),
      ]);
    }

    if (teacher) {
      const interestQs = qs.filter((q) => q.kind === "interest");
      append(wrap, [
        h("h2", null, "Ответы в анкете"),
        h("div", { class: "review" }, interestQs.map((q) => {
          const g = (review[String(q.id)] || {}).given || (att.answers || {})[String(q.id)] || [];
          return h("div", { class: "rv" },
            h("div", { class: "body", style: "padding:14px 16px" },
              h("p", { style: "margin:0" }, h("b", null, q.prompt)),
              h("p", null, g.length ? g.map((x) => optionText(q, x)).join("; ") : "нет ответа")));
        })),
      ]);
    }

    if (ctx.mode === "student") {
      append(wrap, h("p", { class: "note" }, "Результат уже у твоего репетитора. На занятии разберём его вместе и составим план."));
    }
    if (ctx.onReset) {
      append(wrap, h("div", { class: "row no-print", style: "margin-top:48px" }, resetButton(ctx.onReset, ctx.resetLabel)));
    }
    if (ctx.mode === "self") {
      append(wrap, h("div", { class: "row no-print", style: "margin-top:16px" },
        h("button", { class: "btn ghost", type: "button", onclick: () => { state.selfTest = false; showTeacher(); } }, "В кабинет учителя")));
    }
    return wrap;
  }

  function resetButton(onReset, label) {
    let armed = false;
    const btn = h("button", { class: "btn danger", type: "button" }, label || "Разрешить пересдачу");
    const msg = h("span", { class: "small muted" });
    btn.addEventListener("click", async () => {
      if (!armed) {
        armed = true; btn.classList.add("armed");
        btn.textContent = "Удалить результат";
        msg.textContent = "Результат удалится насовсем. Нажми ещё раз, чтобы подтвердить.";
        return;
      }
      btn.disabled = true; btn.textContent = "Удаляю…";
      try { await onReset(); } catch (e) { msg.textContent = humanError(e); btn.disabled = false; }
    });
    return h("div", { class: "row" }, btn, msg);
  }

  function renderResult(reveal) {
    const self = state.profile.role === "teacher";
    mount("result", topBar(), resultView({
      attempt: state.attempt,
      mode: self ? "self" : "student",
      reveal,
      onReset: self ? async () => {
        const { error } = await sb.from("attempts").delete().eq("user_id", state.uid);
        if (error) throw error;
        state.attempt = null;
        renderIntro();
      } : null,
      resetLabel: "Сбросить мою пробную попытку",
    }));
  }

  // ---------- Кабинет учителя ----------
  async function showTeacher() {
    state.selfTest = false;
    renderLoading();
    try {
      await loadQuestions();
      await loadStudents();
      renderTeacher();
    } catch (e) {
      renderFatal("Не удалось загрузить кабинет", humanError(e));
    }
  }

  async function loadStudents() {
    const { data, error } = await sb.from("profiles")
      .select("id,email,full_name,role,attempts(id,answers,result,duration_sec,created_at)")
      .eq("role", "student")
      .order("full_name", { ascending: true, nullsFirst: false });
    if (error) throw error;
    state.students = (data || []).map((s) => Object.assign({}, s, { attempt: one(s.attempts) }));
  }

  function renderTeacher() {
    const tabs = h("div", { class: "tabs", role: "tablist" },
      [["students", "Ученики"], ["key", "Ключ ответов"]].map(([id, label]) =>
        h("button", { type: "button", role: "tab", "aria-selected": state.teacherTab === id ? "true" : "false",
          onclick: () => { state.teacherTab = id; renderTeacher(); } }, label)));
    const body = state.teacherTab === "key" ? keyView() : studentsView();
    mount("teacher", topBar(), h("h1", null, "Кабинет учителя"), tabs, body);
  }

  function studentsView() {
    const list = state.students || [];
    const box = h("div");
    if (!list.length) {
      box.append(h("p", { class: "empty" }, "Учеников пока нет. Добавь ученика в Supabase: Authentication → Users → Add user, с галочкой Auto Confirm User."));
    } else {
      box.append(h("div", { class: "students" }, list.map((s) => {
        const a = s.attempt;
        let sum;
        if (a) {
          const r = a.result || {};
          const top = DIR_ORDER.slice().sort((x, y) => ((r.directions || {})[y] || 0) - ((r.directions || {})[x] || 0))[0];
          sum = h("div", { class: "sum" },
            h("span", null, "Пройден ", h("b", null, fmtDate(a.created_at)), ", " + fmtMin(a.duration_sec)),
            h("span", null, "Знания ", h("b", null, (r.knowledge || {}).score + " из " + (r.knowledge || {}).max)),
            h("span", null, "Логика ", h("b", null, (r.logic || {}).score + " из " + (r.logic || {}).max)),
            h("span", null, "Ближе всего: ", h("b", null, DIRS[top].name)));
        } else {
          sum = h("div", { class: "sum" }, h("span", null, "Тест ещё не пройден"));
        }
        return h("div", { class: "st" },
          h("div", null, h("div", { class: "nm" }, s.full_name || "Без имени"), h("div", { class: "em" }, s.email || "")),
          a ? h("button", { class: "btn small", type: "button", onclick: () => renderStudent(s) }, "Открыть") : h("span"),
          sum);
      })));
    }
    box.append(h("div", { class: "row", style: "margin-top:28px" },
      h("button", { class: "btn ghost small", type: "button", onclick: showTeacher }, "Обновить"),
      h("button", { class: "btn ghost small", type: "button", onclick: startSelfTest }, "Пройти тест самому")));
    box.append(h("p", { class: "note ink small" },
      "Новый ученик: Supabase → Authentication → Users → Add user, отметь Auto Confirm User. Профиль появится здесь сам после первого входа или сразу, если скрипт уже запущен."));
    return box;
  }

  function renderStudent(s) {
    mount("student", topBar(), resultView({
      attempt: s.attempt,
      name: s.full_name || s.email,
      mode: "teacher",
      onBack: () => renderTeacher(),
      onReset: async () => {
        const { error } = await sb.from("attempts").delete().eq("id", s.attempt.id);
        if (error) throw error;
        await showTeacher();
      },
    }));
  }

  async function startSelfTest() {
    state.selfTest = true;
    renderLoading();
    try {
      const att = await loadMyAttempt();
      if (att) return renderResult(false);
      renderIntro();
    } catch (e) {
      renderFatal("Не удалось открыть тест", humanError(e));
    }
  }

  function keyView() {
    const box = h("div");
    box.append(h("p", { class: "muted" }, "Загружаю ключ…"));
    sb.from("questions").select("id,position,kind,topic,prompt,code,multi,options,question_keys(correct,points,explanation,interest_map)")
      .order("position")
      .then(({ data, error }) => {
        box.replaceChildren();
        if (error) { box.append(h("p", { class: "err" }, humanError(error))); return; }
        let n = 0;
        KIND_ORDER.forEach((kind) => {
          const part = (data || []).filter((q) => q.kind === kind);
          if (!part.length) return;
          box.append(h("h2", null, "Часть " + PARTS[kind].n + ". " + PARTS[kind].title));
          part.forEach((q) => {
            n += 1;
            const key = one(q.question_keys) || {};
            const correct = key.correct || [];
            const imap = key.interest_map || {};
            box.append(h("div", { class: "keyq" },
              h("div", { class: "meta" }, "Вопрос " + n + (kind !== "interest" ? ", " + (TOPICS[q.topic] || q.topic) + ", " + key.points + " " + plural(key.points || 0, ["балл", "балла", "баллов"]) : "") + (q.multi ? ", несколько ответов" : "")),
              h("div", { class: "qt" }, q.prompt),
              q.code ? h("pre", { class: "code", html: highlightPy(q.code) }) : null,
              h("ul", null, q.options.map((o, j) => {
                const right = correct.indexOf(o.id) >= 0;
                const dirs = imap[o.id] ? Object.entries(imap[o.id]).map(([d, w]) => h("span", { class: "chip" }, DIRS[d] ? DIRS[d].short + " +" + w : d)) : null;
                return h("li", { class: right ? "right" : null },
                  h("span", null, right ? mark("ok") : LETTERS[j]),
                  h("span", null, h("span", { class: "t" }, o.text), dirs ? h("span", { class: "chips" }, dirs) : null));
              })),
              key.explanation ? h("p", { class: "ex" }, key.explanation) : null));
          });
        });
      });
    return box;
  }

  // ---------- Запуск ----------
  async function boot() {
    if (!window.supabase || !window.supabase.createClient) {
      return renderFatal("Не загрузилась библиотека", "Файл vendor/supabase.js не найден. Проверь, что он есть в репозитории.");
    }
    if (!cfg.SUPABASE_URL || !cfg.SUPABASE_KEY) {
      return renderFatal("Нет настроек", "Заполни config.js: адрес проекта и publishable-ключ Supabase.");
    }
    sb = window.supabase.createClient(cfg.SUPABASE_URL, cfg.SUPABASE_KEY, {
      auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: false },
    });
    sb.auth.onAuthStateChange((event) => {
      if (event === "SIGNED_OUT" && state.uid) {
        Object.assign(state, { uid: null, profile: null });
        renderLogin("Сессия завершилась, войди ещё раз.");
      }
    });
    try {
      const { data } = await sb.auth.getSession();
      if (data && data.session) await enter(data.session);
      else renderLogin();
    } catch (e) {
      renderLogin(humanError(e));
    }
  }

  boot();
})();
