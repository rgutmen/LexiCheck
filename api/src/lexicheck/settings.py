from functools import lru_cache
from urllib.parse import quote_plus

from pydantic import Field
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

    # AI rewrite (optional). Without a key the feature is simply hidden.
    # OPENAI_* names are read as-is so the same .env works everywhere.
    openai_api_key: str | None = Field(default=None, validation_alias="OPENAI_API_KEY")
    openai_model: str = Field(default="gpt-4o-mini", validation_alias="OPENAI_MODEL")
    openai_max_output_tokens: int = 300
    rewrite_max_chars: int = 1_000

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
