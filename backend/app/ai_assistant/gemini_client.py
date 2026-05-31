"""Google Gemini API client with tool calling support."""

import json
import logging
import collections.abc
import time
import asyncio
from typing import Any, Dict, List
import google.generativeai as genai
from google.api_core.exceptions import ResourceExhausted, DeadlineExceeded

from .circuit_breaker import get_circuit_breaker, CircuitBreakerOpenError
from .cache_manager import get_ai_cache
from .monitoring import get_metrics_collector

logger = logging.getLogger(__name__)


class GeminiClient:
    """Client for Google Gemini API with function calling."""
    
    def __init__(self, api_key: str, key_rotator=None, enable_cache: bool = True, request_timeout: int = 30):
        """Initialize Gemini client."""
        self.api_key = api_key
        self.key_rotator = key_rotator  # Optional key rotator for multi-key support
        self.request_timeout = request_timeout  # Timeout for API calls
        genai.configure(api_key=api_key)
        
        # Use Gemini 2.0 Flash - best free model with tool support
        self.model = genai.GenerativeModel('gemini-2.5-flash')
        
        # Initialize circuit breaker for this client
        self.circuit_breaker = get_circuit_breaker(
            name="gemini_api",
            failure_threshold=5,
            recovery_timeout=60,
            expected_exception=Exception
        )
        
        # Initialize cache if enabled
        self.enable_cache = enable_cache
        if enable_cache:
            self.cache = get_ai_cache(max_size=1000, default_ttl=300)  # 5 min TTL
        
        # Initialize metrics collector
        self.metrics = get_metrics_collector()
        
        logger.info(f"✅ Gemini client initialized: model=gemini-2.5-flash, cache={enable_cache}, timeout={request_timeout}s")

    def _convert_repeated_composite_to_list(self, value: Any) -> Any:
        """Recursively converts protobuf RepeatedComposite to a list and maps to dicts."""
        if isinstance(value, collections.abc.Sequence) and not isinstance(value, (str, bytes)):
            return [self._convert_repeated_composite_to_list(item) for item in value]
        if isinstance(value, collections.abc.Mapping):
            return {k: self._convert_repeated_composite_to_list(v) for k, v in value.items()}
        return value
    
    def _convert_openai_type_to_gemini(self, openai_type: str) -> str:
        """Convert OpenAI JSON Schema types to Gemini format."""
        type_mapping = {
            "string": "STRING",
            "number": "NUMBER",
            "integer": "INTEGER",
            "boolean": "BOOLEAN",
            "array": "ARRAY",
            "object": "OBJECT"
        }
        return type_mapping.get(openai_type.lower(), "STRING")
    
    def _convert_schema_to_gemini(self, schema: Dict[str, Any], is_top_level: bool = False) -> Dict[str, Any]:
        """Recursively convert OpenAI JSON Schema to Gemini format."""
        gemini_schema = {}
        
        # Convert type
        if "type" in schema:
            gemini_schema["type"] = self._convert_openai_type_to_gemini(schema["type"])
        
        # Convert properties (for objects)
        if "properties" in schema:
            gemini_props = {}
            for prop_name, prop_def in schema["properties"].items():
                gemini_props[prop_name] = self._convert_schema_to_gemini(prop_def, is_top_level=False)
            gemini_schema["properties"] = gemini_props
        
        # Handle 'required' only at top level (object with properties)
        if is_top_level and "required" in schema:
            gemini_schema["required"] = schema["required"]
        
        # Copy only Gemini-supported fields (NO "default", NO "required" for nested!)
        for key in ["description", "enum", "format"]:
            if key in schema:
                gemini_schema[key] = schema[key]
        
        # Handle array items
        if "items" in schema:
            gemini_schema["items"] = self._convert_schema_to_gemini(schema["items"], is_top_level=False)
        
        return gemini_schema
    
    def _convert_protobuf_value(self, value) -> Any:
        """Convert protobuf value to Python native type."""
        try:
            # Handle different protobuf value types
            if hasattr(value, 'string_value'):
                return value.string_value
            elif hasattr(value, 'number_value'):
                return value.number_value
            elif hasattr(value, 'bool_value'):
                return value.bool_value
            elif hasattr(value, 'list_value'):
                return [self._convert_protobuf_value(item) for item in value.list_value.values]
            elif hasattr(value, 'struct_value'):
                return {k: self._convert_protobuf_value(v) for k, v in value.struct_value.fields.items()}
            elif hasattr(value, 'null_value'):
                return None
            elif hasattr(value, 'values'):
                # Handle repeated fields directly
                return [self._convert_protobuf_value(item) for item in value.values]
            elif hasattr(value, 'fields'):
                # Handle struct fields directly
                return {k: self._convert_protobuf_value(v) for k, v in value.fields.items()}
            else:
                # Fallback: try to get the actual value
                if hasattr(value, 'value'):
                    return value.value
                else:
                    # Last resort: convert to string
                    return str(value)
        except Exception as e:
            logger.warning(f"Failed to convert protobuf value: {e}, using string representation")
            return str(value)
    
    def _convert_tools_to_gemini_format(self, tools: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Convert OpenAI-style tools to Gemini format.
        
        OpenAI format:
        {
            "type": "function",
            "function": {
                "name": "query_students",
                "description": "...",
                "parameters": {"type": "object", "properties": {...}}
            }
        }
        
        Gemini format:
        {
            "name": "query_students",
            "description": "...",
            "parameters": {"type": "OBJECT", "properties": {...}}
        }
        """
        gemini_tools = []
        
        for tool in tools:
            if tool.get("type") == "function":
                function = tool["function"]
                gemini_tool = {
                    "name": function["name"],
                    "description": function["description"],
                    "parameters": self._convert_schema_to_gemini(function["parameters"], is_top_level=True)
                }
                gemini_tools.append(gemini_tool)
        
        logger.info(f"🔧 Converted {len(gemini_tools)} tools to Gemini format")
        return gemini_tools
    
    async def chat_completion(
        self,
        messages: List[Dict[str, str]],
        tools: List[Dict[str, Any]] | None = None,
        max_tokens: int = 800,
        temperature: float = 0.7,
    ) -> str | Dict[str, Any]:
        """
        Generate chat completion with optional tool calling.
        
        Returns:
            - str: Final text response
            - Dict: Tool calls if AI wants to use tools
        """
        start_time = time.time()
        
        # Check cache first (only for non-tool calls)
        if self.enable_cache and not tools:
            cache_key = self.cache.get_cache_key_for_response(
                command=messages[-1].get("content", "") if messages else "",
                context={"temperature": temperature, "max_tokens": max_tokens}
            )
            cached_response = self.cache.get(cache_key)
            if cached_response:
                duration = time.time() - start_time
                self.metrics.record_api_call(
                    duration=duration,
                    success=True,
                    cached=True
                )
                logger.info(f"💾 Cache HIT - returning cached response ({duration*1000:.0f}ms)")
                return cached_response
        
        try:
            # Use circuit breaker to wrap the actual API call
            response = await self.circuit_breaker.call_async(
                self._execute_chat_completion,
                messages, tools, max_tokens, temperature
            )
            
            # Record success metrics
            duration = time.time() - start_time
            self.metrics.record_api_call(
                duration=duration,
                success=True,
                cached=False
            )
            
            # Cache successful text responses (not tool calls)
            if self.enable_cache and not tools and isinstance(response, str):
                self.cache.set(cache_key, response, ttl=300)
            
            return response
            
        except CircuitBreakerOpenError as e:
            # Circuit breaker open - record and return fallback
            duration = time.time() - start_time
            self.metrics.record_api_call(
                duration=duration,
                success=False,
                error="circuit_breaker_open"
            )
            logger.error(f"❌ Circuit breaker OPEN: {e}")
            return "Maaf, sistem AI tidak tersedia sekarang kerana terlalu banyak kegagalan. Sila cuba lagi dalam beberapa minit. 🙏"
            
        except Exception as e:
            # Record error metrics
            duration = time.time() - start_time
            self.metrics.record_api_call(
                duration=duration,
                success=False,
                error=str(e)[:100]
            )
            raise e
    
    async def _execute_chat_completion(
        self,
        messages: List[Dict[str, str]],
        tools: List[Dict[str, Any]] | None = None,
        max_tokens: int = 800,
        temperature: float = 0.7,
    ) -> str | Dict[str, Any]:
        """Internal method that actually calls Gemini API (wrapped by circuit breaker)."""
        try:
            # Convert messages to Gemini format
            history = []
            current_message = None
            
            for msg in messages:
                role = msg["role"]
                content = msg["content"]
                
                if role == "system":
                    # Gemini doesn't have system role, prepend to first user message
                    continue
                elif role == "user":
                    # If we have a previous user message pending, add it to history
                    if current_message:
                        history.append({
                            "role": "user",
                            "parts": [current_message]
                        })
                    current_message = content
                elif role == "assistant":
                    # Add user message if pending
                    if current_message:
                        history.append({
                            "role": "user",
                            "parts": [current_message]
                        })
                        current_message = None
                    
                    # Add model response
                    if content:
                        history.append({
                            "role": "model",
                            "parts": [content]
                        })
                elif role == "tool":
                    # Tool results will be handled in agentic loop
                    continue
            
            # Ensure history doesn't end with a user message (it should be the prompt)
            # The last user message is handled separately by chat.send_message
            if current_message:
                # If there's a pending user message, it becomes the prompt
                # We don't add it to history here
                pass
            
            # Setup generation config
            generation_config = {
                "temperature": temperature,
                "max_output_tokens": max_tokens,
            }
            
            # Convert tools if provided
            gemini_tools = None
            if tools:
                gemini_tools = self._convert_tools_to_gemini_format(tools)
            
            # Create chat session
            if gemini_tools:
                # Enable function calling
                model_with_tools = genai.GenerativeModel(
                    'gemini-2.5-flash',
                    tools=gemini_tools
                )
                chat = model_with_tools.start_chat(history=history)
            else:
                chat = self.model.start_chat(history=history)
            
            # Get last user message
            last_user_message = messages[-1]["content"] if messages else ""
            
            # Generate response with retry logic for rate limits
            # Generate response with retry logic for rate limits
            # Dynamically set retries based on available keys (+ buffer)
            num_keys = len(self.key_rotator.api_keys) if self.key_rotator else 1
            max_retries = max(2, num_keys * 2) 
            base_delay = 2  # Reset to 2s since we have rotation
            
            logger.info(f"🔄 Request strategy: {max_retries} max retries with {num_keys} available keys")
            
            for attempt in range(max_retries):
                try:
                    # Call with timeout using asyncio
                    response = await asyncio.wait_for(
                        asyncio.to_thread(
                            chat.send_message,
                            last_user_message,
                            generation_config=generation_config
                        ),
                        timeout=self.request_timeout
                    )
                    break  # Success, exit retry loop
                    
                except asyncio.TimeoutError:
                    if attempt < max_retries - 1:
                        logger.warning(f"⏰ Request timeout after {self.request_timeout}s. Retrying... (attempt {attempt + 1}/{max_retries})")
                        await asyncio.sleep(2)
                    else:
                        logger.error(f"❌ Request timeout after {max_retries} attempts")
                        return f"Maaf, sistem AI mengambil masa terlalu lama untuk respond. Timeout selepas {self.request_timeout}s. Sila cuba lagi. 🙏"
                    
                except ResourceExhausted as e:
                    if attempt < max_retries - 1:
                        # Exponential backoff dengan jitter untuk elakkan thundering herd
                        wait_time = base_delay * (2 ** attempt)  # 5s, 10s
                        logger.warning(f"⏳ Rate limit hit (429). Retrying in {wait_time}s... (attempt {attempt + 1}/{max_retries})")
                        
                        # Mark current key as failed if using key rotator
                        if self.key_rotator:
                            self.key_rotator.mark_key_failed(self.api_key)
                            
                            # Try to get next available key
                            next_key = self.key_rotator.get_next_key()
                            if next_key and next_key != self.api_key:
                                logger.info(f"🔄 Switching to next API key...")
                                self.api_key = next_key
                                genai.configure(api_key=next_key)
                                # Recreate model with new key
                                if gemini_tools:
                                    model_with_tools = genai.GenerativeModel(
                                        'gemini-2.5-flash',
                                        tools=gemini_tools
                                    )
                                    chat = model_with_tools.start_chat(history=history)
                                else:
                                    self.model = genai.GenerativeModel('gemini-2.5-flash')
                                    chat = self.model.start_chat(history=history)
                                # Retry immediately with new key (no wait)
                                continue
                        
                        await asyncio.sleep(wait_time)
                    else:
                        # Mark key as failed on final attempt
                        if self.key_rotator:
                            self.key_rotator.mark_key_failed(self.api_key)
                        
                        logger.error(f"❌ Rate limit exceeded after {max_retries} attempts")
                        # Return friendly Malay error message instead of raising
                        return "Maaf, sistem AI sedang sibuk sekarang. Terlalu banyak permintaan dalam masa yang singkat. Sila cuba lagi dalam beberapa saat. 🙏"
                        
                except Exception as e:
                    # For other errors, raise immediately
                    raise e
            
            # Check if model wants to call functions
            if response.candidates and response.candidates[0].content.parts:
                part = response.candidates[0].content.parts[0]
                
                # Check for function call
                if hasattr(part, 'function_call') and part.function_call:
                    function_call = part.function_call
                    
                    logger.info(f"🔧 Gemini requested function: {function_call.name}")
                    
                    # Convert function arguments to proper JSON
                    args_dict = self._convert_repeated_composite_to_list(function_call.args) if function_call.args else {}
                    
                    # Convert to OpenAI-style tool call format
                    tool_call = {
                        "id": f"call_{function_call.name}",
                        "type": "function",
                        "function": {
                            "name": function_call.name,
                            "arguments": json.dumps(args_dict)  # ✅ Proper JSON format!
                        }
                    }
                    
                    return {
                        "type": "tool_calls",
                        "tool_calls": [tool_call],
                        "message": {
                            "role": "assistant",
                            "content": None,
                            "tool_calls": [tool_call]
                        }
                    }
            
            # Regular text response
            text = response.text
            logger.info(f"✅ Gemini text response: {len(text)} chars")
            
            return text
            
        except ResourceExhausted as e:
            # Handle rate limit gracefully with Malay message
            logger.error(f"❌ Gemini rate limit: {e}")
            return "Maaf, sistem AI mencapai had penggunaan. Sila tunggu sebentar dan cuba lagi. Terima kasih! 🙏"
            
        except Exception as e:
            logger.error(f"Gemini API error: {e}", exc_info=True)
            return f"Maaf, ada masalah dengan sistem AI: {str(e)}. Sila cuba lagi atau hubungi admin."

