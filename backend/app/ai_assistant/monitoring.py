"""Metrics collection dan monitoring untuk AI module."""

import time
import logging
from typing import Dict, Any, List, Optional
from datetime import datetime, timedelta
from collections import defaultdict, deque
from dataclasses import dataclass, field

logger = logging.getLogger(__name__)


@dataclass
class APICallMetric:
    """Single API call metric."""
    timestamp: float
    duration: float
    success: bool
    error: Optional[str] = None
    tool_name: Optional[str] = None
    cached: bool = False


@dataclass
class PerformanceMetrics:
    """Aggregated performance metrics."""
    total_calls: int = 0
    successful_calls: int = 0
    failed_calls: int = 0
    total_duration: float = 0.0
    min_duration: float = float('inf')
    max_duration: float = 0.0
    cached_responses: int = 0
    
    def add_call(self, duration: float, success: bool, cached: bool = False):
        """Add a call to metrics."""
        self.total_calls += 1
        if success:
            self.successful_calls += 1
        else:
            self.failed_calls += 1
        
        if cached:
            self.cached_responses += 1
        else:
            self.total_duration += duration
            self.min_duration = min(self.min_duration, duration)
            self.max_duration = max(self.max_duration, duration)
    
    @property
    def avg_duration(self) -> float:
        """Calculate average duration."""
        non_cached = self.total_calls - self.cached_responses
        if non_cached == 0:
            return 0.0
        return self.total_duration / non_cached
    
    @property
    def success_rate(self) -> float:
        """Calculate success rate percentage."""
        if self.total_calls == 0:
            return 0.0
        return (self.successful_calls / self.total_calls) * 100
    
    @property
    def cache_hit_rate(self) -> float:
        """Calculate cache hit rate percentage."""
        if self.total_calls == 0:
            return 0.0
        return (self.cached_responses / self.total_calls) * 100


class AIMetricsCollector:
    """
    Collects dan tracks metrics untuk AI system.
    
    Features:
    - API call tracking (latency, success rate, errors)
    - Tool usage statistics
    - Cache hit rate monitoring
    - Circuit breaker status
    - Rate limit tracking
    - Time-series data (last N minutes)
    """
    
    def __init__(self, history_window: int = 3600):
        """
        Initialize metrics collector.
        
        Args:
            history_window: How long to keep metrics history (seconds)
        """
        self.history_window = history_window
        
        # Metrics storage
        self.api_calls: deque[APICallMetric] = deque()
        self.tool_usage: Dict[str, int] = defaultdict(int)
        self.error_counts: Dict[str, int] = defaultdict(int)
        
        # Aggregated metrics
        self.overall_metrics = PerformanceMetrics()
        self.hourly_metrics: Dict[str, PerformanceMetrics] = defaultdict(PerformanceMetrics)
        
        # System start time
        self.start_time = time.time()
        
        logger.info(f"📊 Metrics collector initialized (history: {history_window}s)")
    
    def record_api_call(
        self,
        duration: float,
        success: bool,
        error: Optional[str] = None,
        tool_name: Optional[str] = None,
        cached: bool = False
    ):
        """
        Record an API call.
        
        Args:
            duration: Call duration in seconds
            success: Whether call succeeded
            error: Error message if failed
            tool_name: Tool name if tool call
            cached: Whether response was cached
        """
        # Create metric
        metric = APICallMetric(
            timestamp=time.time(),
            duration=duration,
            success=success,
            error=error,
            tool_name=tool_name,
            cached=cached
        )
        
        # Add to history
        self.api_calls.append(metric)
        
        # Update overall metrics
        self.overall_metrics.add_call(duration, success, cached)
        
        # Update hourly metrics
        hour_key = datetime.now().strftime("%Y-%m-%d %H:00")
        self.hourly_metrics[hour_key].add_call(duration, success, cached)
        
        # Track tool usage
        if tool_name:
            self.tool_usage[tool_name] += 1
        
        # Track errors
        if error:
            self.error_counts[error] += 1
        
        # Cleanup old metrics
        self._cleanup_old_metrics()
        
        # Log slow calls
        if not cached and duration > 5.0:
            logger.warning(f"⏱️  Slow API call detected: {duration:.2f}s")
    
    def _cleanup_old_metrics(self):
        """Remove metrics older than history window."""
        cutoff_time = time.time() - self.history_window
        
        # Remove old API calls
        while self.api_calls and self.api_calls[0].timestamp < cutoff_time:
            self.api_calls.popleft()
        
        # Remove old hourly metrics (keep last 24 hours)
        cutoff_hour = (datetime.now() - timedelta(hours=24)).strftime("%Y-%m-%d %H:00")
        old_hours = [h for h in self.hourly_metrics.keys() if h < cutoff_hour]
        for hour in old_hours:
            del self.hourly_metrics[hour]
    
    def get_recent_metrics(self, minutes: int = 60) -> PerformanceMetrics:
        """
        Get metrics for recent time period.
        
        Args:
            minutes: Number of minutes to look back
            
        Returns:
            PerformanceMetrics for time period
        """
        cutoff_time = time.time() - (minutes * 60)
        metrics = PerformanceMetrics()
        
        for call in self.api_calls:
            if call.timestamp >= cutoff_time:
                metrics.add_call(call.duration, call.success, call.cached)
        
        return metrics
    
    def get_tool_usage_stats(self) -> List[Dict[str, Any]]:
        """Get tool usage statistics."""
        total_calls = sum(self.tool_usage.values())
        
        stats = []
        for tool_name, count in sorted(
            self.tool_usage.items(),
            key=lambda x: x[1],
            reverse=True
        ):
            percentage = (count / total_calls * 100) if total_calls > 0 else 0
            stats.append({
                "tool_name": tool_name,
                "calls": count,
                "percentage": round(percentage, 2)
            })
        
        return stats
    
    def get_error_stats(self) -> List[Dict[str, Any]]:
        """Get error statistics."""
        total_errors = sum(self.error_counts.values())
        
        stats = []
        for error, count in sorted(
            self.error_counts.items(),
            key=lambda x: x[1],
            reverse=True
        )[:10]:  # Top 10 errors
            percentage = (count / total_errors * 100) if total_errors > 0 else 0
            stats.append({
                "error": error[:100],  # Truncate long errors
                "count": count,
                "percentage": round(percentage, 2)
            })
        
        return stats
    
    def get_hourly_trend(self, hours: int = 24) -> List[Dict[str, Any]]:
        """Get hourly trend data."""
        trend = []
        
        # Get last N hours
        for i in range(hours):
            hour_time = datetime.now() - timedelta(hours=i)
            hour_key = hour_time.strftime("%Y-%m-%d %H:00")
            
            metrics = self.hourly_metrics.get(hour_key, PerformanceMetrics())
            
            trend.append({
                "hour": hour_key,
                "total_calls": metrics.total_calls,
                "successful_calls": metrics.successful_calls,
                "failed_calls": metrics.failed_calls,
                "avg_duration": round(metrics.avg_duration, 3),
                "success_rate": round(metrics.success_rate, 2),
                "cache_hit_rate": round(metrics.cache_hit_rate, 2)
            })
        
        return list(reversed(trend))  # Oldest to newest
    
    def get_system_health(self) -> Dict[str, Any]:
        """
        Get overall system health status.
        
        Returns:
            Health status with metrics
        """
        recent_metrics = self.get_recent_metrics(minutes=5)
        
        # Determine health status
        health = "healthy"
        if recent_metrics.success_rate < 50:
            health = "critical"
        elif recent_metrics.success_rate < 80:
            health = "degraded"
        elif recent_metrics.failed_calls > 0:
            health = "warning"
        
        uptime = time.time() - self.start_time
        
        return {
            "status": health,
            "uptime_seconds": round(uptime, 0),
            "uptime_hours": round(uptime / 3600, 2),
            "recent_5min": {
                "total_calls": recent_metrics.total_calls,
                "success_rate": round(recent_metrics.success_rate, 2),
                "avg_duration": round(recent_metrics.avg_duration, 3),
                "cache_hit_rate": round(recent_metrics.cache_hit_rate, 2)
            },
            "overall": {
                "total_calls": self.overall_metrics.total_calls,
                "success_rate": round(self.overall_metrics.success_rate, 2),
                "avg_duration": round(self.overall_metrics.avg_duration, 3),
                "cache_hit_rate": round(self.overall_metrics.cache_hit_rate, 2)
            }
        }
    
    def get_full_report(self) -> Dict[str, Any]:
        """Get comprehensive metrics report."""
        return {
            "system_health": self.get_system_health(),
            "recent_60min": self.get_recent_metrics(60).__dict__,
            "tool_usage": self.get_tool_usage_stats(),
            "top_errors": self.get_error_stats(),
            "hourly_trend": self.get_hourly_trend(hours=24)
        }
    
    def reset(self):
        """Reset all metrics."""
        self.api_calls.clear()
        self.tool_usage.clear()
        self.error_counts.clear()
        self.overall_metrics = PerformanceMetrics()
        self.hourly_metrics.clear()
        self.start_time = time.time()
        logger.info("📊 Metrics reset")


# Global metrics collector
_metrics_collector: Optional[AIMetricsCollector] = None


def get_metrics_collector(history_window: int = 3600) -> AIMetricsCollector:
    """Get or create global metrics collector."""
    global _metrics_collector
    if _metrics_collector is None:
        _metrics_collector = AIMetricsCollector(history_window=history_window)
    return _metrics_collector
