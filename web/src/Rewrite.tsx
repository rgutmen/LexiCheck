import { useState } from "react";
import { Check, Copy, LoaderCircle, Sparkles } from "lucide-react";
import { api, ApiError, type Features, type RewriteResult } from "./api";

// Separate from the spell checker on purpose: this one calls an LLM, costs money
// per request, and is rate limited at the edge.
export default function Rewrite({ text, features }: { text: string; features: Features }) {
  const [style, setStyle] = useState(features.styles[0]?.id ?? "poem");
  const [result, setResult] = useState<RewriteResult | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);

  const tooLong = text.length > features.rewrite_max_chars;

  async function run() {
    setBusy(true);
    setError(null);
    setCopied(false);
    try {
      setResult(await api.rewrite(text, style));
    } catch (e) {
      const status = e instanceof ApiError ? e.status : 0;
      setError(
        status === 403 || status === 429
          ? "That's a lot of rewrites. Give it a minute and try again."
          : status === 503
            ? "AI rewriting is switched off on this server."
            : "The AI service didn't answer. Try again in a moment.",
      );
    } finally {
      setBusy(false);
    }
  }

  async function copy() {
    if (!result) return;
    await navigator.clipboard.writeText(result.text);
    setCopied(true);
    setTimeout(() => setCopied(false), 1500);
  }

  return (
    <section className="rewrite" aria-label="Rewrite with AI">
      <div className="rewrite-bar">
        <h2>
          <Sparkles size={16} strokeWidth={1.75} aria-hidden /> Rewrite with AI
        </h2>
        <div className="rewrite-controls">
          <label>
            <span className="sr-only">Style</span>
            <select value={style} onChange={(e) => setStyle(e.target.value)} disabled={busy}>
              {features.styles.map((s) => (
                <option key={s.id} value={s.id}>
                  {s.label}
                </option>
              ))}
            </select>
          </label>
          <button className="btn accent" onClick={run} disabled={busy || !text.trim() || tooLong}>
            {busy ? (
              <LoaderCircle size={16} strokeWidth={1.75} className="spin" aria-hidden />
            ) : (
              <Sparkles size={16} strokeWidth={1.75} aria-hidden />
            )}
            {busy ? "Writing" : "Rewrite"}
          </button>
        </div>
      </div>

      {tooLong && (
        <p className="quiet small">
          AI rewrites take up to {features.rewrite_max_chars.toLocaleString()} characters.
        </p>
      )}
      {error && (
        <p className="error" role="alert">
          {error}
        </p>
      )}

      {result && !error && (
        <figure className="rewrite-out" aria-live="polite">
          <blockquote>{result.text}</blockquote>
          <figcaption>
            <span>Fixed and rewritten by {result.model}</span>
            <button className="btn ghost small" onClick={copy}>
              {copied ? (
                <Check size={14} strokeWidth={2} aria-hidden />
              ) : (
                <Copy size={14} strokeWidth={1.75} aria-hidden />
              )}
              {copied ? "Copied" : "Copy"}
            </button>
          </figcaption>
        </figure>
      )}
    </section>
  );
}
