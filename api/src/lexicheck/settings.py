from functools import lru_cache
from urllib.parse import quote_plus

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Runtime configuration, read from LEXI_* environment variables.

    Either set LEXI_DATABASE_URL directly (local dev), or the discrete LEXI_DB_* values.
    On ECS the user/password come from the RDS-managed secret, injected by the agent.
    """

    model_config = SettingsConfigDict(env_prefix="LEXI_", env_file=".env", extra="ignore")

    database_url: str | None = None
    db_host: str | None = None
    db_port: int = 5432
    db_name: str = "lexicheck"
    db_user: str | None = None
    db_password: str | None = None

    default_language: str = "en"
    max_text_chars: int = 20_000
    cors_origins: list[str] = ["http://localhost:5173"]
    environment: str = "local"

    @property
    def resolved_database_url(self) -> str:
        if self.database_url:
            return self.database_url
        if self.db_host and self.db_user and self.db_password:
            return (
                f"postgresql+psycopg://{quote_plus(self.db_user)}:{quote_plus(self.db_password)}"
                f"@{self.db_host}:{self.db_port}/{self.db_name}?sslmode=require"
            )
        return "sqlite:///./lexicheck.db"


@lru_cache
def get_settings() -> Settings:
    return Settings()
