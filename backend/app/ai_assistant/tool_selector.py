"""Tool Selection System for Agentic AI."""

from __future__ import annotations
from typing import Dict, List, Any, Optional, Set
import logging
from dataclasses import dataclass

logger = logging.getLogger(__name__)

@dataclass
class ToolSpec:
    """Specification for an available tool."""
    name: str
    description: str
    required_parameters: List[str]
    optional_parameters: List[str]
    purpose: str  # What type of tasks this tool is good for
    complexity_level: int  # 1-5, how complex the tool is


class ToolSelector:
    """System for selecting appropriate tools based on intent and context."""
    
    def __init__(self):
        # Define available tools
        self.available_tools = {
            'supabase_direct_query': ToolSpec(
                name='supabase_direct_query',
                description='Execute direct SQL queries on Supabase database',
                required_parameters=['query'],
                optional_parameters=['params', 'return_format'],
                purpose='database queries and complex data retrieval',
                complexity_level=3
            ),
            'student_search': ToolSpec(
                name='student_search',
                description='Search for students with various filters',
                required_parameters=[],
                optional_parameters=['department', 'min_cgpa', 'year', 'limit', 'profile_complete'],
                purpose='student-related queries',
                complexity_level=2
            ),
            'event_manager': ToolSpec(
                name='event_manager',
                description='Manage and query events',
                required_parameters=[],
                optional_parameters=['date_range', 'location', 'organizer', 'limit'],
                purpose='event-related queries and management',
                complexity_level=2
            ),
            'analytics_engine': ToolSpec(
                name='analytics_engine',
                description='Perform complex analytics and aggregations',
                required_parameters=['analysis_type'],
                optional_parameters=['filters', 'group_by', 'time_period'],
                purpose='analytics and insights',
                complexity_level=4
            ),
            'report_generator': ToolSpec(
                name='report_generator',
                description='Generate various types of reports',
                required_parameters=['report_type'],
                optional_parameters=['format', 'filters', 'time_period', 'include_charts'],
                purpose='report generation',
                complexity_level=3
            ),
            'notification_system': ToolSpec(
                name='notification_system',
                description='Send notifications and messages',
                required_parameters=['message', 'recipients'],
                optional_parameters=['delivery_method', 'priority', 'schedule_time'],
                purpose='communication tasks',
                complexity_level=2
            ),
            'data_updater': ToolSpec(
                name='data_updater',
                description='Update data in the system',
                required_parameters=['table', 'updates'],
                optional_parameters=['conditions', 'validation'],
                purpose='data modification',
                complexity_level=4
            ),
            'system_stats': ToolSpec(
                name='system_stats',
                description='Get system-wide statistics',
                required_parameters=[],
                optional_parameters=['include_breakdown', 'time_period'],
                purpose='system information queries',
                complexity_level=1
            )
        }
        
        # Map intents to appropriate tools
        self.intent_to_tools = {
            'STUDENT_QUERY': ['student_search', 'supabase_direct_query'],
            'EVENT_QUERY': ['event_manager', 'supabase_direct_query'],
            'ACHIEVEMENT_QUERY': ['supabase_direct_query', 'analytics_engine'],
            'ANALYTICS_QUERY': ['analytics_engine', 'supabase_direct_query'],
            'REPORT_GENERATION': ['report_generator', 'analytics_engine', 'supabase_direct_query'],
            'COMMUNICATION_TASK': ['notification_system'],
            'DATA_MANIPULATION': ['data_updater', 'supabase_direct_query'],
            'SYSTEM_QUERY': ['system_stats', 'supabase_direct_query'],
            'MULTI_INTENT': ['student_search', 'event_manager', 'analytics_engine', 'notification_system'],
            'UNCLEAR': ['system_stats']  # Default tool for unclear intents
        }
        
        # Define tool compatibility matrix
        self.tool_dependencies = {
            'report_generator': ['analytics_engine', 'supabase_direct_query'],  # Reports often need analytics/data
            'notification_system': ['student_search', 'event_manager']  # Need to identify recipients
        }

    def select_tools(self, intent: str, entities: Optional[Dict[str, Any]] = None, 
                    required_parameters: Optional[Set[str]] = None) -> List[str]:
        """Select appropriate tools based on intent and entities."""
        entities = entities or {}
        required_parameters = required_parameters or set()
        
        logger.info(f"Selecting tools for intent: {intent}, entities: {entities}")
        
        # Get tools based on intent
        candidate_tools = self.intent_to_tools.get(intent, ['supabase_direct_query'])
        
        # Filter tools based on available entities and required parameters
        selected_tools = []
        
        for tool_name in candidate_tools:
            if self._is_tool_appropriate(tool_name, entities, required_parameters):
                selected_tools.append(tool_name)
        
        # Add dependent tools if needed
        final_tools = set(selected_tools)
        for tool in selected_tools:
            if tool in self.tool_dependencies:
                final_tools.update(self.tool_dependencies[tool])
        
        logger.info(f"Selected tools: {list(final_tools)}")
        
        return list(final_tools)
    
    def _is_tool_appropriate(self, tool_name: str, entities: Dict[str, Any], 
                           required_parameters: Set[str]) -> bool:
        """Check if a tool is appropriate given the entities and requirements."""
        if tool_name not in self.available_tools:
            return False
        
        tool_spec = self.available_tools[tool_name]
        
        # Check if tool can handle the required parameters
        if required_parameters:
            # Check if tool can provide or work with required parameters
            all_params = set(tool_spec.required_parameters + tool_spec.optional_parameters)
            if not (required_parameters & all_params):  # No overlap
                return False
        
        # Specialized checks for different tools
        if tool_name == 'student_search':
            # More likely to use if student-related entities are present
            student_related = ['department', 'min_cgpa', 'year', 'limit']
            if any(key in entities for key in student_related):
                return True
            return False
        
        elif tool_name == 'event_manager':
            # More likely to use if event-related entities are present
            event_related = ['date_range', 'location', 'organizer']
            if any(key in entities for key in event_related):
                return True
            return False
        
        elif tool_name == 'analytics_engine':
            # More likely to use if analytics-related entities are present
            analytics_related = ['analysis_type', 'group_by', 'time_period']
            if any(key in entities for key in analytics_related):
                return True
            return False
        
        elif tool_name == 'report_generator':
            # More likely to use if report-related entities are present
            report_related = ['report_type', 'format', 'include_charts']
            if any(key in entities for key in report_related):
                return True
            return False
        
        elif tool_name == 'notification_system':
            # More likely to use if communication-related entities are present
            comm_related = ['message', 'recipients', 'delivery_method']
            if any(key in entities for key in comm_related):
                return True
            return False
        
        elif tool_name == 'data_updater':
            # More likely to use if update-related entities are present
            update_related = ['table', 'updates', 'conditions']
            if any(key in entities for key in update_related):
                return True
            return False
        
        # For general tools like supabase_direct_query, system_stats - they're always potentially relevant
        elif tool_name in ['supabase_direct_query', 'system_stats']:
            return True
        
        return True  # Default to True for other cases
    
    def get_tool_requirements(self, tool_name: str) -> Dict[str, Any]:
        """Get requirements and parameters for a specific tool."""
        if tool_name not in self.available_tools:
            raise ValueError(f"Unknown tool: {tool_name}")
        
        tool_spec = self.available_tools[tool_name]
        
        return {
            'name': tool_spec.name,
            'description': tool_spec.description,
            'required_parameters': tool_spec.required_parameters,
            'optional_parameters': tool_spec.optional_parameters,
            'purpose': tool_spec.purpose,
            'complexity_level': tool_spec.complexity_level
        }
    
    def rank_tools_by_relevance(self, intent: str, entities: Optional[Dict[str, Any]] = None) -> List[Tuple[str, float]]:
        """Rank tools by relevance to the current intent and entities."""
        entities = entities or {}
        
        rankings = []
        
        for tool_name in self.available_tools:
            relevance = self._calculate_tool_relevance(tool_name, intent, entities)
            if relevance > 0:  # Only include tools with positive relevance
                rankings.append((tool_name, relevance))
        
        # Sort by relevance in descending order
        rankings.sort(key=lambda x: x[1], reverse=True)
        
        return rankings
    
    def _calculate_tool_relevance(self, tool_name: str, intent: str, entities: Dict[str, Any]) -> float:
        """Calculate how relevant a tool is to the current request."""
        relevance = 0.0
        
        # Base relevance based on intent matching
        if tool_name in self.intent_to_tools.get(intent, []):
            relevance += 0.5  # Base score for intent match
        
        # Boost for parameter matches
        tool_spec = self.available_tools[tool_name]
        all_tool_params = set(tool_spec.required_parameters + tool_spec.optional_parameters)
        entity_keys = set(entities.keys())
        
        param_matches = all_tool_params & entity_keys
        if param_matches:
            relevance += len(param_matches) * 0.1  # Boost for each matching parameter
        
        # Specialized boosts based on tool type and entities
        if tool_name == 'student_search':
            student_boost_params = ['department', 'min_cgpa', 'student_id', 'year']
            if any(param in entity_keys for param in student_boost_params):
                relevance += 0.3
        
        elif tool_name == 'event_manager':
            event_boost_params = ['date_range', 'location', 'event_type']
            if any(param in entity_keys for param in event_boost_params):
                relevance += 0.3
        
        elif tool_name == 'analytics_engine':
            analytics_boost_params = ['analysis_type', 'group_by', 'time_period']
            if any(param in entity_keys for param in analytics_boost_params):
                relevance += 0.3
        
        elif tool_name == 'report_generator':
            report_boost_params = ['report_type', 'format', 'include_charts']
            if any(param in entity_keys for param in report_boost_params):
                relevance += 0.3
        
        # Adjust for complexity - prefer simpler tools when possible
        complexity_penalty = (tool_spec.complexity_level - 1) * 0.05
        relevance = max(0, relevance - complexity_penalty)
        
        return relevance
    
    def get_tool_execution_plan(self, tools: List[str], intent: str, 
                               entities: Optional[Dict[str, Any]] = None) -> List[Dict[str, Any]]:
        """Generate an execution plan for the selected tools."""
        entities = entities or {}
        
        execution_plan = []
        
        for tool_name in tools:
            if tool_name not in self.available_tools:
                continue
            
            tool_spec = self.available_tools[tool_name]
            
            # Determine execution parameters based on entities
            execution_params = self._build_execution_params(tool_name, entities)
            
            execution_plan.append({
                'tool_name': tool_name,
                'description': tool_spec.description,
                'purpose': f"Handle {intent}-related tasks using {tool_name}",
                'parameters': execution_params,
                'execution_order': self._determine_execution_order(tool_name, intent),
                'dependencies': self._get_tool_dependencies(tool_name)
            })
        
        # Sort by execution order
        execution_plan.sort(key=lambda x: x['execution_order'])
        
        return execution_plan
    
    def _build_execution_params(self, tool_name: str, entities: Dict[str, Any]) -> Dict[str, Any]:
        """Build execution parameters for a tool based on entities."""
        tool_spec = self.available_tools[tool_name]
        
        params = {}
        
        # Match entity keys to tool parameters
        for param_name in tool_spec.required_parameters + tool_spec.optional_parameters:
            if param_name in entities:
                params[param_name] = entities[param_name]
        
        # Add any missing required parameters with defaults
        for param_name in tool_spec.required_parameters:
            if param_name not in params:
                # Set default values based on parameter type
                if param_name == 'query':
                    params[param_name] = "SELECT * FROM users LIMIT 10"  # Default query
                elif param_name == 'report_type':
                    params[param_name] = "summary"
                elif param_name == 'analysis_type':
                    params[param_name] = "basic"
                else:
                    params[param_name] = None
        
        return params
    
    def _determine_execution_order(self, tool_name: str, intent: str) -> int:
        """Determine the execution order for a tool."""
        # Define execution priorities
        execution_order = {
            'system_stats': 1,    # System info first
            'supabase_direct_query': 2,  # Direct queries next
            'student_search': 2,   # Student queries
            'event_manager': 2,    # Event queries
            'analytics_engine': 3, # Analytics after data retrieval
            'report_generator': 4, # Reports after analytics
            'notification_system': 5, # Notifications last
            'data_updater': 5      # Updates after other operations
        }
        
        return execution_order.get(tool_name, 3)
    
    def _get_tool_dependencies(self, tool_name: str) -> List[str]:
        """Get dependencies for a tool."""
        return self.tool_dependencies.get(tool_name, [])


# Example usage:
if __name__ == "__main__":
    selector = ToolSelector()
    
    # Example entities from intent classification
    entities = {
        'departments': ['Computer Science'],
        'min_cgpa': 3.5,
        'limit': 5,
        'original_command': 'Show me top 5 students in Computer Science with CGPA above 3.5'
    }
    
    # Test with different intents
    test_cases = [
        ('STUDENT_QUERY', entities),
        ('ANALYTICS_QUERY', {'analysis_type': 'department_stats', 'group_by': 'department'}),
        ('REPORT_GENERATION', {'report_type': 'student_summary', 'format': 'pdf'}),
        ('COMMUNICATION_TASK', {'message': 'Hello', 'recipients': 'students'})
    ]
    
    for intent, ent in test_cases:
        print(f"\nIntent: {intent}")
        print(f"Entities: {ent}")
        
        # Select tools
        tools = selector.select_tools(intent, ent)
        print(f"Selected tools: {tools}")
        
        # Rank tools by relevance
        ranked_tools = selector.rank_tools_by_relevance(intent, ent)
        print(f"Ranked tools: {ranked_tools[:3]}")  # Top 3
        
        # Show tool requirements
        for tool in tools[:2]:  # First two tools
            requirements = selector.get_tool_requirements(tool)
            print(f"Tool '{tool}' requirements: {requirements['required_parameters']}")
        
        # Generate execution plan
        plan = selector.get_tool_execution_plan(tools, intent, ent)
        print(f"Execution plan: {[(p['tool_name'], p['execution_order']) for p in plan]}")
