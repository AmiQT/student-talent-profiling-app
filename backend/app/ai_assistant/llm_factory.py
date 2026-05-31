"""
LLM Provider Factory - Abstraction Layer for AI Models.

Supports multiple LLM providers with automatic fallback:
- Google Gemini (Cloud API)
- Ollama (Self-hosted)

Environment Variables:
    AI_PROVIDER: "gemini" or "ollama" (default: gemini)
    AI_BASE_URL: Ollama base URL (e.g., http://172.31.x.x:11434)
    AI_MODEL_NAME: Model name (e.g., gemma3:4b, gemini-2.5-flash)
    AI_TEMPERATURE: Temperature setting (default: 0.7)
    AI_TIMEOUT: Request timeout in seconds (default: 30)
"""

import logging
import os
from typing import Optional, Literal
from langchain_core.language_models.chat_models import BaseChatModel

logger = logging.getLogger(__name__)

# Type definitions
ProviderType = Literal["gemini", "ollama"]


class LLMFactory:
    """
    Factory for creating LLM instances based on provider configuration.
    
    Usage:
        # Use default provider from env
        llm = LLMFactory.create_llm()
        
        # Override provider
        llm = LLMFactory.create_llm(provider="ollama")
        
        # Custom settings
        llm = LLMFactory.create_llm(
            provider="ollama",
            model_name="gemma3:4b",
            temperature=0.5
        )
    """
    
    @staticmethod
    def create_llm(
        provider: Optional[ProviderType] = None,
        model_name: Optional[str] = None,
        temperature: Optional[float] = None,
        timeout: Optional[int] = None,
        api_key: Optional[str] = None
    ) -> BaseChatModel:
        """
        Create an LLM instance based on provider.
        
        Args:
            provider: "gemini" or "ollama" (default from AI_PROVIDER env)
            model_name: Model name (default from AI_MODEL_NAME env)
            temperature: Temperature 0-1 (default from AI_TEMPERATURE env or 0.7)
            timeout: Request timeout in seconds (default from AI_TIMEOUT env or 30)
            api_key: API key for Gemini (default from key_manager)
            
        Returns:
            BaseChatModel: Configured LLM instance
            
        Raises:
            ValueError: If provider is invalid or required config missing
            ImportError: If required package not installed
        """
        # Read from environment with defaults
        provider = provider or os.getenv("AI_PROVIDER", "gemini").lower()
        model_name = model_name or os.getenv("AI_MODEL_NAME")
        temperature = temperature if temperature is not None else float(os.getenv("AI_TEMPERATURE", "0.7"))
        timeout = timeout or int(os.getenv("AI_TIMEOUT", "30"))
        
        # Validate provider
        if provider not in ["gemini", "ollama"]:
            raise ValueError(f"Invalid AI_PROVIDER: {provider}. Must be 'gemini' or 'ollama'")
        
        # Route to appropriate factory method
        if provider == "ollama":
            return LLMFactory._create_ollama(model_name, temperature, timeout)
        else:
            return LLMFactory._create_gemini(model_name, temperature, api_key)
    
    @staticmethod
    def _create_ollama(
        model_name: Optional[str],
        temperature: float,
        timeout: int
    ) -> BaseChatModel:
        """Create Ollama LLM instance."""
        try:
            from langchain_ollama import ChatOllama
        except ImportError:
            raise ImportError(
                "langchain-ollama not installed. Run: pip install langchain-ollama"
            )
        
        # Get base URL from env
        base_url = os.getenv("AI_BASE_URL")
        if not base_url:
            raise ValueError(
                "AI_BASE_URL is required for Ollama provider. "
                "Example: http://172.31.45.67:11434"
            )
        
        # Default model if not specified
        if not model_name:
            model_name = "gemma3:4b"
            logger.warning(f"AI_MODEL_NAME not set, using default: {model_name}")
        
        logger.info(
            f"🦙 Creating Ollama LLM: model={model_name}, "
            f"base_url={base_url}, temp={temperature}, timeout={timeout}s"
        )
        
        # Custom headers for ngrok free tier (skip browser warning)
        custom_headers = {}
        if "ngrok" in base_url.lower():
            custom_headers["ngrok-skip-browser-warning"] = "true"
            logger.info("📡 Ngrok detected, adding skip-browser-warning header")
        
        return ChatOllama(
            base_url=base_url,
            model=model_name,
            temperature=temperature,
            timeout=timeout,
            # Ollama-specific configs
            num_predict=2048,  # Max tokens to generate
            top_k=40,          # Top-k sampling
            top_p=0.9,         # Top-p (nucleus) sampling
            repeat_penalty=1.1,  # Penalize repetition
            # Custom headers for ngrok
            headers=custom_headers
        )
    
    @staticmethod
    def _create_gemini(
        model_name: Optional[str],
        temperature: float,
        api_key: Optional[str]
    ) -> BaseChatModel:
        """Create Google Gemini LLM instance."""
        try:
            from langchain_google_genai import ChatGoogleGenerativeAI
            from app.core.key_manager import get_gemini_key
        except ImportError:
            raise ImportError(
                "langchain-google-genai not installed. "
                "Run: pip install langchain-google-genai"
            )
        
        # Get API key from key_manager if not provided
        if not api_key:
            api_key = get_gemini_key()
            if not api_key:
                raise ValueError(
                    "GEMINI_API_KEY or GEMINI_API_KEYS not set. "
                    "Required for Gemini provider."
                )
        
        # Default model if not specified
        if not model_name:
            model_name = "gemini-2.5-flash"
            logger.warning(f"AI_MODEL_NAME not set, using default: {model_name}")
        
        logger.info(
            f"🔮 Creating Gemini LLM: model={model_name}, temp={temperature}"
        )
        
        return ChatGoogleGenerativeAI(
            model=model_name,
            google_api_key=api_key,
            temperature=temperature,
            convert_system_message_to_human=True  # Gemini compatibility
        )
    
    @staticmethod
    def get_provider_info() -> dict:
        """
        Get current provider configuration info.
        
        Returns:
            dict: Configuration details including provider, model, base_url
        """
        provider = os.getenv("AI_PROVIDER", "gemini").lower()
        model_name = os.getenv("AI_MODEL_NAME", "Not set")
        temperature = os.getenv("AI_TEMPERATURE", "0.7")
        
        info = {
            "provider": provider,
            "model_name": model_name,
            "temperature": float(temperature),
        }
        
        if provider == "ollama":
            info["base_url"] = os.getenv("AI_BASE_URL", "Not set")
            info["timeout"] = int(os.getenv("AI_TIMEOUT", "30"))
        
        return info
    
    @staticmethod
    def validate_config() -> tuple[bool, Optional[str]]:
        """
        Validate current LLM configuration.
        
        Returns:
            tuple: (is_valid, error_message)
        """
        provider = os.getenv("AI_PROVIDER", "gemini").lower()
        
        if provider not in ["gemini", "ollama"]:
            return False, f"Invalid AI_PROVIDER: {provider}"
        
        if provider == "ollama":
            base_url = os.getenv("AI_BASE_URL")
            if not base_url:
                return False, "AI_BASE_URL is required for Ollama"
            
            model_name = os.getenv("AI_MODEL_NAME")
            if not model_name:
                return False, "AI_MODEL_NAME is required for Ollama"
        
        elif provider == "gemini":
            from app.core.key_manager import get_gemini_key
            api_key = get_gemini_key()
            if not api_key:
                return False, "GEMINI_API_KEY or GEMINI_API_KEYS not set"
        
        return True, None


# Convenience function
def create_llm(**kwargs) -> BaseChatModel:
    """
    Convenience function to create LLM.
    
    Shorthand for LLMFactory.create_llm(**kwargs)
    """
    return LLMFactory.create_llm(**kwargs)


# Example usage and testing
if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    
    print("=== LLM Factory Test ===")
    print(f"Current config: {LLMFactory.get_provider_info()}")
    
    is_valid, error = LLMFactory.validate_config()
    if not is_valid:
        print(f"❌ Configuration error: {error}")
    else:
        print("✅ Configuration is valid")
        
        try:
            llm = create_llm()
            print(f"✅ LLM created successfully: {type(llm).__name__}")
        except Exception as e:
            print(f"❌ Failed to create LLM: {e}")
