"""Agentic AI Orchestrator - Coordinates all agentic features."""

from __future__ import annotations
from typing import Dict, Any, Optional, List
import logging

from .plan_generator import PlanGenerator, ExecutionPlan
from .intent_classifier import IntentClassifier, IntentClassification
from .clarification_system import ClarificationSystem, ClarificationRequest
from .tool_selector import ToolSelector

logger = logging.getLogger(__name__)

class AgenticOrchestrator:
    """Orchestrates all agentic AI features to work together."""
    
    def __init__(self):
        self.plan_generator = PlanGenerator()
        self.intent_classifier = IntentClassifier()
        self.clarification_system = ClarificationSystem()
        self.tool_selector = ToolSelector()
    
    async def process_command(self, command: str, context: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """Process a command through all agentic components."""
        logger.info(f"Processing agentic command: {command}")
        
        # Step 1: Classify intent
        intent_result = self.intent_classifier.classify_intent(command, context)
        logger.info(f"Intent classified as: {intent_result.intent_type.value} (confidence: {intent_result.confidence})")
        
        # Step 2: Check for clarification needs
        clarification_response = self.clarification_system.generate_clarification_response(
            command, intent_result.detected_entities, intent_result.intent_type.value
        )
        
        if clarification_response:
            logger.info("Clarification needed")
            return {
                "needs_clarification": True,
                "clarification_response": clarification_response,
                "intent": intent_result.intent_type.value,
                "entities": intent_result.detected_entities,
                "agentic_processing": True
            }
        
        # Step 3: Select appropriate tools
        selected_tools = self.tool_selector.select_tools(
            intent_result.intent_type.value,
            intent_result.detected_entities
        )
        logger.info(f"Selected tools: {selected_tools}")
        
        # Step 4: Generate execution plan
        execution_plan = self.plan_generator.generate_plan(command, intent_result.detected_entities)
        logger.info(f"Generated plan with {len(execution_plan.steps)} steps")
        
        # Step 5: Generate execution plan for tools
        tool_execution_plan = self.tool_selector.get_tool_execution_plan(
            selected_tools,
            intent_result.intent_type.value,
            intent_result.detected_entities
        )
        
        # Step 6: Prepare complete response
        response = {
            "needs_clarification": False,
            "intent": intent_result.intent_type.value,
            "confidence": intent_result.confidence,
            "entities": intent_result.detected_entities,
            "selected_tools": selected_tools,
            "plan_steps_count": len(execution_plan.steps),
            "plan_steps": [
                {
                    "step_id": step.step_id,
                    "task_type": step.task_type.value,
                    "description": step.description,
                    "parameters": step.parameters,
                    "dependencies": step.dependencies,
                    "tools_needed": step.tools_needed
                } for step in execution_plan.steps
            ],
            "tool_execution_plan": [
                {
                    "tool_name": step['tool_name'],
                    "purpose": step['purpose'],
                    "parameters": step['parameters'],
                    "execution_order": step['execution_order']
                } for step in tool_execution_plan
            ],
            "agentic_processing": True,
            "original_command": command
        }
        
        logger.info(f"Agentic processing complete for command: {command}")
        return response
    
    def get_ranked_tools(self, intent: str, entities: Optional[Dict[str, Any]] = None) -> List[tuple]:
        """Get ranked list of tools for a given intent and entities."""
        return self.tool_selector.rank_tools_by_relevance(intent, entities or {})
    
    def get_intent_alternatives(self, command: str) -> List[tuple]:
        """Get alternative intents for a command with their confidence scores."""
        intent_result = self.intent_classifier.classify_intent(command)
        return [(intent_type.value, confidence) for intent_type, confidence in intent_result.alternative_intents]