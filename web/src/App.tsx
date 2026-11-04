import { useEffect, useMemo, useRef, useState } from "react";
import {
  ArrowRight,
  Check,
  ChevronDown,
  ChevronUp,
  Eraser,
  History,
  LoaderCircle,
  PenLine,
  RotateCcw,
} from "lucide-react";
import { api, type CheckResult, type Features, type HistoryItem, type Issue } from "./api";
import Rewrite from "./Rewrite";

const LANGUAGE_NAMES: Record<string, string> = {
  en: "English",
  es: "Spanish",
  fr: "French",
  de: "German",
  it: "Italian",
  pt: "Portuguese",
};

const SAMPLE =
  "Wellcome to LexiCheck. Paste a paragraph here and every speling mistake gets marked, " +
  "with sugestions you can apply in a single click.";

const MAX_CHARS = 20_000;

type Mode = "edit" | "review";

const isMac = typeof navigator !== "undefined" && /Mac|iPhone|iPad/.test(navigator.platform);

export default function App() {
  const [text, setText] = useState(SAMPLE);
  const [language, setLanguage] = useState("en");
  const [languages, setLanguages] = useState<string[]>(Object.keys(LANGUAGE_NAMES));
  const [result, setResult] = useState<CheckResult | null>(null);
  const [mode, setMode] = useState<Mode>("edit");
  const [active, setActive] = useState(0);
  const [history, setHistory] = useState<HistoryItem[]>([]);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [fixed, setFixed] = useState(0);
  const [features, setFeatures] = useState<Features | null>(null);
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  useEffect(() => {
    api
      .languages()
      .then(setLanguages)
      .catch(() => undefined);
    api
      .history()
      .then(setHistory)
      .catch(() => undefined);
    api
      .features()
      .then(setFeatures)
      .catch(() => undefined);
  }, []);

  const issues = result?.issues ?? [];
  const current = issues[Math.min(active, issues.length - 1)];

  async function runCheck() {
    if (!text.trim() || busy) return;
    setBusy(true);
    setError(null);
    try {
      const res = await api.check(text, language);
      setResult(res);
      setActive(0);
      setFixed(0);
      setMode("review");
      api
        .history()
        .then(setHistory)
        .catch(() => undefined);
    } catch {
      setError("The checker could not be reached. Your text is still here; try again in a moment.");
    } finally {
      setBusy(false);
    }
  }

  function apply(issue: Issue, replacement: string) {
    const delta = replacement.length - issue.length;
    setText((t) => t.slice(0, issue.offset) + replacement + t.slice(issue.offset + issue.length));
    setResult(
      (r) =>
        r && {
          ...r,
          issues: r.issues
            .filter((i) => i !== issue)
            .map((i) => (i.offset > issue.offset ? { ...i, offset: i.offset + delta } : i)),
        },
    );
    setFixed((n) => n + 1);
  }

  function ignore(issue: Issue) {
    setResult((r) => r && { ...r, issues: r.issues.filter((i) => i !== issue) });
  }

  function backToEditing() {
    setMode("edit");
    requestAnimationFrame(() => textareaRef.current?.focus());
  }

  // Keyboard: Cmd/Ctrl+Enter checks; in review, J/K move between marks, 1-5 apply.
  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if ((e.metaKey || e.ctrlKey) && e.key === "Enter") {
        e.preventDefault();
        void runCheck();
        return;
      }
      if (mode !== "review" || !current) return;
      if (e.target instanceof HTMLSelectElement) return;
      if (e.key === "j" || e.key === "ArrowDown")
        setActive((a) => Math.min(a + 1, issues.length - 1));
      if (e.key === "k" || e.key === "ArrowUp") setActive((a) => Math.max(a - 1, 0));
      const n = Number(e.key);
      if (n >= 1 && n <= current.suggestions.length) apply(current, current.suggestions[n - 1]);
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  });

  const wordCount = useMemo(() => text.match(/\p{L}+(?:'\p{L}+)*/gu)?.length ?? 0, [text]);

  return (
    <div className="page">
      <header className="masthead">
        <a className="wordmark" href="/" aria-label="LexiCheck home">
          <img src="/favicon.svg" alt="" width={28} height={28} />
          <span>
            Lexi<em>Check</em>
          </span>
        </a>
        <p className="tagline">Spelling, marked like a proof.</p>
      </header>

      <main className="desk">
        <div className="main-col">
          <section className="sheet" aria-label="Your text">
            <div className="sheet-bar">
              <label className="lang">
                <span className="sr-only">Language</span>
                <select
                  value={language}
                  onChange={(e) => setLanguage(e.target.value)}
                  disabled={busy}
                >
                  {languages.map((l) => (
                    <option key={l} value={l}>
                      {LANGUAGE_NAMES[l] ?? l}
                    </option>
                  ))}
                </select>
              </label>
              <span className="meter" aria-live="polite">
                <span className="num">{wordCount.toLocaleString()}</span> words
                <span className="sep" aria-hidden>
                  ·
                </span>
                <span className={`num ${text.length > MAX_CHARS ? "over" : ""}`}>
                  {text.length.toLocaleString()}
                </span>
                /{MAX_CHARS.toLocaleString()}
              </span>
            </div>

            {mode === "edit" ? (
              <textarea
                ref={textareaRef}
                className="manuscript"
                value={text}
                onChange={(e) => setText(e.target.value)}
                placeholder="Paste or type the text you want checked."
                spellCheck={false}
                aria-label="Text to check"
              />
            ) : (
              <Proof
                text={text}
                issues={issues}
                active={current}
                onSelect={(i) => setActive(issues.indexOf(i))}
              />
            )}

            <div className="sheet-foot">
              {mode === "review" ? (
                <button className="btn ghost" onClick={backToEditing}>
                  <PenLine size={16} strokeWidth={1.75} aria-hidden />
                  Edit text
                </button>
              ) : (
                <button className="btn ghost" onClick={() => setText("")} disabled={!text || busy}>
                  <Eraser size={16} strokeWidth={1.75} aria-hidden />
                  Clear
                </button>
              )}
              <button
                className="btn primary"
                onClick={runCheck}
                disabled={busy || !text.trim() || text.length > MAX_CHARS}
              >
                {busy ? (
                  <LoaderCircle size={16} strokeWidth={1.75} className="spin" aria-hidden />
                ) : mode === "review" ? (
                  <RotateCcw size={16} strokeWidth={1.75} aria-hidden />
                ) : (
                  <ArrowRight size={16} strokeWidth={1.75} aria-hidden />
                )}
                {busy ? "Checking" : mode === "review" ? "Check again" : "Check spelling"}
                <kbd>{isMac ? "⌘" : "Ctrl"} Enter</kbd>
              </button>
            </div>
            {error && (
              <p className="error" role="alert">
                {error}
              </p>
            )}
          </section>

          {features?.ai_rewrite && <Rewrite text={text} features={features} />}
        </div>

        <aside className="margin" aria-label="Corrections">
          <Corrections
            mode={mode}
            result={result}
            current={current}
            index={Math.min(active, issues.length - 1)}
            fixed={fixed}
            onApply={apply}
            onIgnore={ignore}
            onMove={(d) => setActive((a) => Math.max(0, Math.min(a + d, issues.length - 1)))}
          />

          <section className="recent">
            <h2>
              <History size={15} strokeWidth={1.75} aria-hidden /> Recent checks
            </h2>
            {history.length === 0 ? (
              <p className="quiet">Nothing checked yet.</p>
            ) : (
              <ol>
                {history.slice(0, 6).map((h) => (
                  <li key={h.id}>
                    <span className="preview">{h.preview}</span>
                    <span className="meta">
                      {LANGUAGE_NAMES[h.language] ?? h.language}
                      <span className="dot" aria-hidden>
                        ·
                      </span>
                      {h.issue_count === 0 ? "clean" : `${h.issue_count} marked`}
                    </span>
                  </li>
                ))}
              </ol>
            )}
          </section>
        </aside>
      </main>

      <footer className="colophon">
        Spell checking is dictionary-based and runs on our server.
        {features?.ai_rewrite && " AI rewrites send your text to OpenAI."}
      </footer>
    </div>
  );
}

function Proof({
  text,
  issues,
  active,
  onSelect,
}: {
  text: string;
  issues: Issue[];
  active?: Issue;
  onSelect: (i: Issue) => void;
}) {
  const parts: React.ReactNode[] = [];
  let cursor = 0;
  [...issues]
    .sort((a, b) => a.offset - b.offset)
    .forEach((issue, n) => {
      parts.push(text.slice(cursor, issue.offset));
      parts.push(
        <button
          key={`${issue.offset}-${issue.word}`}
          className={`mark ${issue === active ? "is-active" : ""}`}
          style={{ animationDelay: `${Math.min(n, 12) * 45}ms` }}
          onClick={() => onSelect(issue)}
          aria-label={`Misspelled: ${issue.word}`}
        >
          {text.slice(issue.offset, issue.offset + issue.length)}
        </button>,
      );
      cursor = issue.offset + issue.length;
    });
  parts.push(text.slice(cursor));
  return <div className="manuscript proof">{parts}</div>;
}

function Corrections({
  mode,
  result,
  current,
  index,
  fixed,
  onApply,
  onIgnore,
  onMove,
}: {
  mode: Mode;
  result: CheckResult | null;
  current?: Issue;
  index: number;
  fixed: number;
  onApply: (i: Issue, s: string) => void;
  onIgnore: (i: Issue) => void;
  onMove: (d: number) => void;
}) {
  if (mode === "edit" || !result) {
    return (
      <section className="note">
        <h2>How it works</h2>
        <p>
          Check the text and each misspelling is marked in the margin with ranked suggestions. Apply
          one with a click, or with keys <kbd>1</kbd>–<kbd>5</kbd>; move between marks with{" "}
          <kbd>J</kbd> and <kbd>K</kbd>.
        </p>
      </section>
    );
  }

  if (!current) {
    return (
      <section className="note clean">
        <Check size={22} strokeWidth={2} aria-hidden />
        <h2>Clean copy</h2>
        <p>
          {fixed > 0
            ? `${fixed} ${fixed === 1 ? "correction" : "corrections"} applied. No misspellings left.`
            : `No misspellings in ${result.word_count.toLocaleString()} words.`}
        </p>
      </section>
    );
  }

  const total = result.issues.length;
  return (
    <section className="correction" aria-live="polite">
      <div className="correction-head">
        <span className="count">
          <span className="num">{index + 1}</span> of <span className="num">{total}</span>
        </span>
        <span className="nav">
          <button
            className="icon-btn"
            onClick={() => onMove(-1)}
            disabled={index === 0}
            aria-label="Previous"
          >
            <ChevronUp size={16} strokeWidth={1.75} aria-hidden />
          </button>
          <button
            className="icon-btn"
            onClick={() => onMove(1)}
            disabled={index >= total - 1}
            aria-label="Next"
          >
            <ChevronDown size={16} strokeWidth={1.75} aria-hidden />
          </button>
        </span>
      </div>
      <p className="word">
        <s>{current.word}</s>
      </p>
      {current.suggestions.length > 0 ? (
        <ul className="suggestions">
          {current.suggestions.map((s, i) => (
            <li key={s}>
              <button className="suggestion" onClick={() => onApply(current, s)}>
                <kbd>{i + 1}</kbd>
                <span>{s}</span>
              </button>
            </li>
          ))}
        </ul>
      ) : (
        <p className="quiet">No suggestions for this word.</p>
      )}
      <button className="btn ghost small" onClick={() => onIgnore(current)}>
        Keep as written
      </button>
    </section>
  );
}
