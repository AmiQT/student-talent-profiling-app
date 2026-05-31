"""Configuration helpers for AI assistant module."""

from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import Field


class AISettings(BaseSettings):
    """Application settings for AI assistant behaviour."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    ai_enabled: bool = Field(default=True, env="AI_ASSISTANT_ENABLED")
    
    # Google Gemini API (FREE tier with tool calling!)
    enable_gemini: bool = Field(default=True, env="AI_GEMINI_ENABLED")
    gemini_api_key: str | None = Field(default=None, env="GEMINI_API_KEY")
    
    # Multiple API keys for rotation (comma-separated)
    gemini_api_keys: str | None = Field(default=None, env="GEMINI_API_KEYS")
    
    def get_all_gemini_keys(self) -> list[str]:
        """Get all Gemini API keys (single + multiple)."""
        keys = []
        
        # Add single key if exists
        if self.gemini_api_key:
            keys.append(self.gemini_api_key)
        
        # Add multiple keys if exists
        if self.gemini_api_keys:
            # Split by comma and strip whitespace
            multi_keys = [k.strip() for k in self.gemini_api_keys.split(",") if k.strip()]
            keys.extend(multi_keys)
        
        # Remove duplicates while preserving order
        seen = set()
        unique_keys = []
        for key in keys:
            if key not in seen:
                seen.add(key)
                unique_keys.append(key)
        
        return unique_keys


@lru_cache()
def get_ai_settings() -> AISettings:
    """Return cached application settings for AI assistant."""

    return AISettings()

