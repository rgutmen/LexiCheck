export interface Issue {
  word: string;
  offset: number;
  length: number;
  suggestions: string[];
}

export interface CheckResult {
  id: number;
  language: string;
  word_count: number;
  issues: Issue[];
}

export interface HistoryItem {
  id: number;
  language: string;
  preview: string;
  issue_count: number;
  created_at: string;
}

// Same-origin by default: CloudFront (prod) or the Vite proxy (dev) routes /api to the API.
const BASE = import.meta.env.VITE_API_BASE ?? "/api";

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`${BASE}${path}`, {
    headers: { "Content-Type": "application/json" },
    ...init,
  });
  if (!res.ok) throw new Error(`${res.status} ${res.statusText}`);
  return res.json() as Promise<T>;
}

export const api = {
  languages: () => request<string[]>("/v1/languages"),
  history: () => request<HistoryItem[]>("/v1/history?limit=10"),
  check: (text: string, language: string) =>
    request<CheckResult>("/v1/check", {
      method: "POST",
      body: JSON.stringify({ text, language }),
    }),
};
