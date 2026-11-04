from contextlib import asynccontextmanager
from datetime import datetime
from typing import Annotated

from fastapi import Depends, FastAPI, HTTPException, Query, Response
from fastapi.middleware.cors import CORSMiddleware
from prometheus_client import CONTENT_TYPE_LATEST, generate_latest
from pydantic import BaseModel, Field
from sqlalchemy import select
from sqlalchemy.orm import Session

from lexicheck import checker, metrics, rewriter, storage
from lexicheck.settings import get_settings

settings = get_settings()
DbSession = Annotated[Session, Depends(storage.get_session)]


@asynccontextmanager
async def lifespan(_: FastAPI):
    storage.init_schema()
    yield


app = FastAPI(title="LexiCheck API", version="0.1.0", lifespan=lifespan)
app.add_middleware(metrics.MetricsMiddleware)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type"],
)


class CheckRequest(BaseModel):
    text: str = Field(min_length=1, max_length=settings.max_text_chars)
    language: str = settings.default_language


class IssueOut(BaseModel):
    word: str
    offset: int
    length: int
    suggestions: list[str]


class CheckResponse(BaseModel):
    id: int
    language: str
    word_count: int
    issues: list[IssueOut]


class HistoryItem(BaseModel):
    id: int
    language: str
    preview: str
    issue_count: int
    created_at: datetime


class RewriteRequest(BaseModel):
    text: str = Field(min_length=1, max_length=settings.rewrite_max_chars)
    style: str


class RewriteResponse(BaseModel):
    text: str
    style: str
    model: str


class StyleOut(BaseModel):
    id: str
    label: str


class Features(BaseModel):
    ai_rewrite: bool
    rewrite_max_chars: int
    styles: list[StyleOut]


# Liveness: the process is up. Used by the container/ALB health check.
@app.get("/healthz", include_in_schema=False)
def healthz() -> dict[str, str]:
    return {"status": "ok"}


# Readiness: dependencies are reachable. Useful for deploy smoke tests.
@app.get("/readyz", include_in_schema=False)
def readyz() -> dict[str, str]:
    if not storage.database_is_reachable():
        raise HTTPException(status_code=503, detail="database unavailable")
    return {"status": "ready"}


@app.get("/metrics", include_in_schema=False)
def prometheus_metrics() -> Response:
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.get("/v1/languages")
def languages() -> list[str]:
    return list(checker.SUPPORTED_LANGUAGES)


# Tells the UI whether to show the AI menu, so the app works without a key.
@app.get("/v1/features", response_model=Features)
def features() -> Features:
    return Features(
        ai_rewrite=rewriter.enabled(),
        rewrite_max_chars=settings.rewrite_max_chars,
        styles=[StyleOut(id=k, label=v[0]) for k, v in rewriter.STYLES.items()],
    )


@app.post("/v1/rewrite", response_model=RewriteResponse)
def rewrite(body: RewriteRequest) -> RewriteResponse:
    if body.style not in rewriter.STYLES:
        raise HTTPException(status_code=422, detail=f"unknown style: {body.style}")
    try:
        result = rewriter.rewrite(body.text, body.style)
    except rewriter.RewriteUnavailable as exc:
        metrics.REWRITES.labels(body.style, "disabled").inc()
        raise HTTPException(status_code=503, detail="AI rewriting is not enabled") from exc
    except rewriter.RewriteFailed as exc:
        metrics.REWRITES.labels(body.style, "error").inc()
        raise HTTPException(status_code=502, detail="The AI service did not respond") from exc
    metrics.REWRITES.labels(body.style, "ok").inc()
    metrics.AI_TOKENS.labels(result.model).inc(result.tokens)
    return RewriteResponse(text=result.text, style=result.style, model=result.model)


@app.post("/v1/check", response_model=CheckResponse)
def check(body: CheckRequest, db: DbSession) -> CheckResponse:
    try:
        issues = checker.check_text(body.text, body.language)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

    word_count = len(checker.WORD_RE.findall(body.text))
    metrics.CHECKED_WORDS.labels(body.language).inc(word_count)
    metrics.FOUND_ISSUES.labels(body.language).inc(len(issues))

    record = storage.CheckRecord(language=body.language, text=body.text, issue_count=len(issues))
    db.add(record)
    db.commit()

    return CheckResponse(
        id=record.id,
        language=body.language,
        word_count=word_count,
        issues=[IssueOut(**vars(i)) for i in issues],
    )


@app.get("/v1/history", response_model=list[HistoryItem])
def history(db: DbSession, limit: Annotated[int, Query(ge=1, le=100)] = 20) -> list[HistoryItem]:
    rows = db.scalars(
        select(storage.CheckRecord).order_by(storage.CheckRecord.id.desc()).limit(limit)
    )
    return [
        HistoryItem(
            id=r.id,
            language=r.language,
            preview=r.text[:80],
            issue_count=r.issue_count,
            created_at=r.created_at,
        )
        for r in rows
    ]
