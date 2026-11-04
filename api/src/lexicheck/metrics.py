import time

from prometheus_client import Counter, Histogram
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request

HTTP_REQUESTS = Counter(
    "lexicheck_http_requests_total", "HTTP requests", ["method", "route", "status"]
)
HTTP_LATENCY = Histogram(
    "lexicheck_http_request_duration_seconds",
    "HTTP request latency",
    ["method", "route"],
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5),
)
CHECKED_WORDS = Counter("lexicheck_checked_words_total", "Words analysed", ["language"])
FOUND_ISSUES = Counter("lexicheck_issues_total", "Misspellings found", ["language"])


class MetricsMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        start = time.perf_counter()
        response = await call_next(request)
        # Use the route template (/v1/history/{id}) to keep label cardinality bounded.
        route = getattr(request.scope.get("route"), "path", "unmatched")
        HTTP_LATENCY.labels(request.method, route).observe(time.perf_counter() - start)
        HTTP_REQUESTS.labels(request.method, route, str(response.status_code)).inc()
        return response
