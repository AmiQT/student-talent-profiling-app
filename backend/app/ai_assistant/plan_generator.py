"""Agentic AI Plan Generator - Generate execution plans for complex tasks."""

from __future__ import annotations
from typing import Dict, List, Any, Optional
from enum import Enum
from dataclasses import dataclass
import re
import logging

logger = logging.getLogger(__name__)

class TaskType(Enum):
    QUERY_DATA = "query_data"
    ANALYTICS = "analytics"
    REPORT_GENERATION = "report_generation"
    COMMUNICATION = "communication"
    DATA_MANIPULATION = "data_manipulation"
    MULTI_STEP = "multi_step"


@dataclass
class TaskStep:
    """Represents a single step in an execution plan."""
    step_id: str
    task_type: TaskType
    description: str
    parameters: Dict[str, Any]
    dependencies: List[str]  # IDs of steps that must complete before this one
    tools_needed: List[str]  # List of tools required for this step


@dataclass
class ExecutionPlan:
    """Complete execution plan for a complex task."""
    original_command: str
    intent: str
    steps: List[TaskStep]
    context: Dict[str, Any]


class PlanGenerator:
    """Generate execution plans for complex AI tasks."""
    
    def __init__(self):
        self.intent_keywords = {
            TaskType.QUERY_DATA: [
                'who', 'what', 'list', 'show', 'find', 'search', 'tunjuk', 'cari',
                'students', 'pelajar', 'events', 'acara', 'users', 'pengguna'
            ],
            TaskType.ANALYTICS: [
                'analytics', 'analyze', 'analysis', 'trend', 'pattern', 'statistik',
                'best', 'top', 'highest', 'lowest', 'ranking', 'performance'
            ],
            TaskType.REPORT_GENERATION: [
                'report', 'generate', 'create', 'buat', 'hasilkan', 'summary',
                'ringkasan', 'hasil'
            ],
            TaskType.COMMUNICATION: [
                'send', 'email', 'message', 'hantar', 'email', 'mesej', 'notify',
                'beritahu', 'maklumkan'
            ],
            TaskType.DATA_MANIPULATION: [
                'update', 'modify', 'change', 'kemaskini', 'ubah', 'tukar'
            ]
        }
        
        # Complex task phrase patterns
        self.complex_task_patterns = [
            # Multi-step patterns
            r'(first.*then|show.*then|find.*and|cari.*kemudian|tunjuk.*dan|list.*then)',
            # Sequence patterns
            r'(after.*do|before.*do|once.*do|selepas.*buat|sebelum.*buat|setelah.*buat)',
            # Conditional patterns
            r'(if.*then|kalau.*maka|jika.*maka|if.*also|kalau.*juga|jika.*juga)'
        ]

    def generate_plan(self, command: str, context: Optional[Dict[str, Any]] = None) -> ExecutionPlan:
        """Generate an execution plan for the given command."""
        logger.info(f"Generating plan for command: {command}")
        
        # Determine intent
        intent = self._classify_intent(command)
        
        # Check if this is a complex multi-step task
        if self._is_complex_task(command):
            plan = self._generate_multi_step_plan(command, intent)
        else:
            plan = self._generate_single_step_plan(command, intent)
        
        logger.info(f"Generated plan with {len(plan.steps)} steps")
        return plan
    
    def _classify_intent(self, command: str) -> TaskType:
        """Classify the main intent of the command."""
        command_lower = command.lower()
        
        # Check for each intent type
        for task_type, keywords in self.intent_keywords.items():
            if any(keyword in command_lower for keyword in keywords):
                return task_type
        
        # Default to query if unsure
        return TaskType.QUERY_DATA
    
    def _is_complex_task(self, command: str) -> bool:
        """Check if the command requires multiple steps."""
        command_lower = command.lower()
        
        # Check for complex patterns
        for pattern in self.complex_task_patterns:
            if re.search(pattern, command_lower):
                return True
        
        # Check for multiple commands in one (separated by 'and', 'then', 'kemudian', etc.)
        multi_command_indicators = [
            ' and ', ' then ', ' and then ', ' kemudian ', ' dan ', 
            ' dan kemudian ', ' lepas tu ', ' after that ', ' once done '
        ]
        
        for indicator in multi_command_indicators:
            if indicator in command_lower:
                # Count occurrences - more than one might indicate multiple tasks
                if command_lower.count(indicator) > 0:
                    return True
        
        # Check for complex request patterns
        complex_indicators = [
            'first', 'next', 'finally', 'lastly', 'pertama', 'kemudian', 'akhirnya',
            'show me.*and.*also', 'find.*then.*update', 'list.*and.*email'
        ]
        
        for indicator in complex_indicators:
            if re.search(indicator, command_lower):
                return True
        
        return False
    
    def _generate_single_step_plan(self, command: str, intent: TaskType) -> ExecutionPlan:
        """Generate a plan for a single-step task."""
        step = TaskStep(
            step_id="step_1",
            task_type=intent,
            description=f"Execute {intent.value} task: {command}",
            parameters=self._extract_parameters(command, intent),
            dependencies=[],
            tools_needed=self._get_required_tools(intent)
        )
        
        return ExecutionPlan(
            original_command=command,
            intent=intent.value,
            steps=[step],
            context={}
        )
    
    def _generate_multi_step_plan(self, command: str, intent: TaskType) -> ExecutionPlan:
        """Generate a plan for a multi-step task."""
        # Parse the command into sub-commands based on connectors
        sub_commands = self._parse_multi_step_command(command)
        steps = []
        
        for i, sub_cmd in enumerate(sub_commands):
            step_intent = self._classify_intent(sub_cmd)
            step = TaskStep(
                step_id=f"step_{i+1}",
                task_type=step_intent,
                description=f"Execute {step_intent.value} task: {sub_cmd}",
                parameters=self._extract_parameters(sub_cmd, step_intent),
                dependencies=[f"step_{i}"] if i > 0 else [],  # Each step depends on the previous
                tools_needed=self._get_required_tools(step_intent)
            )
            steps.append(step)
        
        return ExecutionPlan(
            original_command=command,
            intent="multi_step",
            steps=steps,
            context={}
        )
    
    def _parse_multi_step_command(self, command: str) -> List[str]:
        """Parse a multi-step command into individual steps."""
        # Split by common connectors
        connectors = [
            r'\s+and\s+|\s+then\s+',  # 'and', 'then'
            r'\s+kemudian\s+|\s+dan\s+kemudian\s+',  # 'kemudian', 'dan kemudian'
            r'\s+dan\s+|\s+lepas\s+tu\s+',  # 'dan', 'lepas tu'
            r'\s+after\s+that\s+|\s+once\s+done\s+'  # 'after that', 'once done'
        ]
        
        # Create a regex pattern that matches all connectors
        pattern = '|'.join(connectors)
        
        # Split the command and clean up
        parts = re.split(pattern, command)
        
        # Clean up each part by removing connector words that might remain
        cleaned_parts = []
        for part in parts:
            # Remove connector phrases more thoroughly
            clean_part = re.sub(r'\b(first|next|finally|lastly|pertama|kemudian|akhirnya)\b\s*', '', part, flags=re.IGNORECASE)
            clean_part = clean_part.strip()
            if clean_part:
                cleaned_parts.append(clean_part)
        
        # If splitting didn't work well, return the original command as one step
        if len(cleaned_parts) < 2:
            return [command]
        
        return cleaned_parts
    
    def _extract_parameters(self, command: str, task_type: TaskType) -> Dict[str, Any]:
        """Extract parameters from command based on task type."""
        params = {"original_query": command}
        
        command_lower = command.lower()
        
        # Extract number specifications (e.g., "top 5", "first 3")
        number_match = re.search(r'(top|first|last|bottom|best|top\s*(\d+)|first\s*(\d+)|last\s*(\d+)|bottom\s*(\d+)|best\s*(\d+))', command_lower)
        if number_match:
            number_text = number_match.group(0)
            # Extract just the number if present
            num_match = re.search(r'\d+', number_text)
            if num_match:
                params['limit'] = int(num_match.group(0))
            else:
                params['special_limit'] = number_text
        
        # Extract department/jurusan
        dept_matches = re.findall(r'(fsktm|computer science|information technology|software engineering|data science|electrical|civil|mechanical|fakulti|faculty|department|kursus|course)', command_lower)
        if dept_matches:
            params['departments'] = dept_matches
        
        # Extract CGPA specifications
        cgpa_match = re.search(r'cgpa\s*([<>]?\s*[\d.]+)', command_lower)
        if cgpa_match:
            cgpa_value = cgpa_match.group(1).strip()
            if cgpa_value.startswith('>') or cgpa_value.startswith('>'):
                params['min_cgpa'] = float(cgpa_value[1:].strip())
            elif cgpa_value.startswith('<') or cgpa_value.startswith('<'):
                params['max_cgpa'] = float(cgpa_value[1:].strip())
            else:
                params['exact_cgpa'] = float(cgpa_value)
        
        # Extract date specifications
        date_match = re.search(r'(\d{4}-\d{2}-\d{2})|(\d{2}/\d{2}/\d{4})', command)
        if date_match:
            params['date'] = date_match.group(0)
        
        # Add task-specific parameters
        if task_type == TaskType.QUERY_DATA:
            params['query_type'] = 'search'
        elif task_type == TaskType.ANALYTICS:
            params['analysis_type'] = 'aggregated'
        elif task_type == TaskType.REPORT_GENERATION:
            params['report_format'] = 'summary'
        elif task_type == TaskType.COMMUNICATION:
            params['communication_type'] = 'message'
        elif task_type == TaskType.DATA_MANIPULATION:
            params['operation_type'] = 'update'
        
        return params
    
    def _get_required_tools(self, task_type: TaskType) -> List[str]:
        """Get list of tools required for a specific task type."""
        tool_mapping = {
            TaskType.QUERY_DATA: ["supabase_bridge", "database_query"],
            TaskType.ANALYTICS: ["supabase_bridge", "analytics_engine"],
            TaskType.REPORT_GENERATION: ["report_generator", "template_engine", "supabase_bridge"],
            TaskType.COMMUNICATION: ["notification_system", "email_service"],
            TaskType.DATA_MANIPULATION: ["supabase_bridge", "data_updater"],
            TaskType.MULTI_STEP: ["plan_executor", "step_manager"]
        }
        
        return tool_mapping.get(task_type, ["supabase_bridge"])


# Example usage:
if __name__ == "__main__":
    generator = PlanGenerator()
    
    # Test various commands
    test_commands = [
        "Show me the top 5 students in Computer Science",
        "First find students with CGPA above 3.5, then list their achievements",
        "Show me top students and then email them about the event",
        "Find students with incomplete profiles and update their status",
        "List all events, and then show analytics for event participation"
    ]
    
    for cmd in test_commands:
        print(f"\nCommand: {cmd}")
        plan = generator.generate_plan(cmd)
        print(f"Intent: {plan.intent}")
        print(f"Steps: {len(plan.steps)}")
        for step in plan.steps:
            print(f"  - {step.step_id}: {step.task_type.value} - {step.description}")