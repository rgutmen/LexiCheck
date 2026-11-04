from collections.abc import Iterator
from datetime import UTC, datetime

from sqlalchemy import DateTime, Integer, String, Text, create_engine, text
from sqlalchemy.engine import Engine
from sqlalchemy.orm import DeclarativeBase, Mapped, Session, mapped_column, sessionmaker

from lexicheck.settings import get_settings


class Base(DeclarativeBase):
    pass


class CheckRecord(Base):
    __tablename__ = "check_records"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    language: Mapped[str] = mapped_column(String(8))
    text: Mapped[str] = mapped_column(Text)
    issue_count: Mapped[int] = mapped_column(Integer)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(UTC)
    )


def build_engine(url: str) -> Engine:
    if url.startswith("sqlite"):
        return create_engine(url, connect_args={"check_same_thread": False})
    # pool_pre_ping survives RDS failovers and idle connection drops.
    return create_engine(url, pool_pre_ping=True, pool_size=5, max_overflow=10)


engine = build_engine(get_settings().resolved_database_url)
SessionFactory = sessionmaker(bind=engine, expire_on_commit=False)


def init_schema() -> None:
    Base.metadata.create_all(engine)


def get_session() -> Iterator[Session]:
    with SessionFactory() as session:
        yield session


def database_is_reachable() -> bool:
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        return True
    except Exception:
        return False
