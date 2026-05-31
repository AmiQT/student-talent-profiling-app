"""Template Management System for Agentic AI Assistant."""

from __future__ import annotations
from typing import Dict, List, Any, Optional
import json
import logging
from datetime import datetime
from dataclasses import dataclass, asdict
from enum import Enum

logger = logging.getLogger(__name__)

class TemplateCategory(Enum):
    """Categories for organizing templates."""
    GREETING = "greeting"
    QUERY_RESPONSE = "query_response"
    ERROR_HANDLING = "error_handling"
    CLARIFICATION = "clarification"
    CONFIRMATION = "confirmation"
    ANALYTICS = "analytics"
    STUDENT_DATA = "student_data"
    EVENT_DATA = "event_data"
    ACHIEVEMENT_DATA = "achievement_data"
    MULTI_STEP = "multi_step"
    SYSTEM_MESSAGE = "system_message"
    CUSTOM = "custom"


@dataclass
class Template:
    """Represents a response template with metadata."""
    template_id: str
    name: str
    content: str
    category: TemplateCategory
    version: str = "1.0"
    is_active: bool = True
    tags: List[str] = None
    variables: List[str] = None  # Variables that can be substituted
    created_at: datetime = None
    updated_at: datetime = None
    created_by: str = "system"
    priority: int = 0  # Higher priority = more likely to be selected
    weight: float = 1.0  # Weight for selection probability
    
    def __post_init__(self):
        if self.created_at is None:
            self.created_at = datetime.now()
        if self.updated_at is None:
            self.updated_at = self.created_at
        if self.tags is None:
            self.tags = []
        if self.variables is None:
            self.variables = []


class TemplateManager:
    """Manages templates for AI responses with CRUD operations."""
    
    def __init__(self):
        self._templates: Dict[str, Template] = {}
        self._templates_by_category: Dict[TemplateCategory, List[str]] = {}
        self._template_names: Dict[str, str] = {}  # name -> template_id mapping
        
        # Initialize with default templates
        self._initialize_default_templates()
    
    def _initialize_default_templates(self):
        """Initialize with default templates."""
        default_templates = [
            Template(
                template_id="greeting_basic",
                name="Basic Greeting",
                content="Hai! Apa khabar? {user_name}, saya AI assistant UTHM sedia nak tolong.",
                category=TemplateCategory.GREETING,
                tags=["friendly", "welcoming"],
                variables=["user_name", "time_of_day"],
                priority=1
            ),
            Template(
                template_id="greeting_enthusiastic",
                name="Enthusiastic Greeting",
                content="Wah bestnya jumpa awak! 😊 Saya AI assistant UTHM, ready to help.",
                category=TemplateCategory.GREETING,
                tags=["enthusiastic", "helpful"],
                variables=["user_name"],
                priority=1
            ),
            Template(
                template_id="student_query_result",
                name="Student Query Result",
                content="Wah bestnya! 🎉 Saya jumpa **{result_count} students** mengikut permintaan awak!",
                category=TemplateCategory.STUDENT_DATA,
                tags=["results", "positive"],
                variables=["result_count", "department", "criteria"],
                priority=2
            ),
            Template(
                template_id="event_query_result", 
                name="Event Query Result",
                content="Jumpa **{result_count} events** untuk awak! Ni detailsnya: 📅",
                category=TemplateCategory.EVENT_DATA,
                tags=["results", "events"],
                variables=["result_count", "event_type", "time_frame"],
                priority=2
            ),
            Template(
                template_id="analytics_result",
                name="Analytics Result",
                content="Wah bestnya! Ni analytics yang awak nak. Saya buatkan analysis yang detailed untuk awak.",
                category=TemplateCategory.ANALYTICS,
                tags=["detailed", "analytics"],
                variables=["analysis_type", "key_insights", "data_points"],
                priority=2
            ),
            Template(
                template_id="clarification_needed",
                name="Clarification Request",
                content="Wah, sorry lah! Saya perlukan sedikit maklumat tambahan untuk bantu awak.",
                category=TemplateCategory.CLARIFICATION,
                tags=["apologetic", "requesting_info"],
                variables=["missing_info", "suggestion"],
                priority=3
            ),
            Template(
                template_id="error_generic",
                name="Generic Error Response",
                content="Ups! Ada sedikit masalah dengan permintaan awak. Boleh cuba dalam format lain tak?",
                category=TemplateCategory.ERROR_HANDLING,
                tags=["apologetic", "helpful"],
                variables=["error_type", "suggestion"],
                priority=1
            ),
            Template(
                template_id="confirmation_success",
                name="Success Confirmation",
                content="Wah bestnya! Saya dah proses permintaan awak. Sure lah! Saya dah faham.",
                category=TemplateCategory.CONFIRMATION,
                tags=["positive", "confirming"],
                variables=["action_performed", "result_summary"],
                priority=1
            )
        ]
        
        for template in default_templates:
            self.add_template(template)
    
    def add_template(self, template: Template) -> bool:
        """Add a new template or update existing one."""
        if not template.is_active:
            logger.info(f"Adding inactive template: {template.name}")
        
        # Check for duplicate name
        if template.name in self._template_names and self._template_names[template.name] != template.template_id:
            logger.warning(f"Template name '{template.name}' already exists with different ID")
            return False
        
        # Add or update the template
        self._templates[template.template_id] = template
        self._template_names[template.name] = template.template_id
        
        # Add to category index
        if template.category not in self._templates_by_category:
            self._templates_by_category[template.category] = []
        if template.template_id not in self._templates_by_category[template.category]:
            self._templates_by_category[template.category].append(template.template_id)
        
        logger.info(f"Added/updated template: {template.name} (ID: {template.template_id})")
        return True
    
    def get_template(self, template_id: str) -> Optional[Template]:
        """Get a template by ID."""
        return self._templates.get(template_id)
    
    def get_template_by_name(self, name: str) -> Optional[Template]:
        """Get a template by name."""
        template_id = self._template_names.get(name)
        if template_id:
            return self.get_template(template_id)
        return None
    
    def get_templates_by_category(self, category: TemplateCategory) -> List[Template]:
        """Get all templates in a category."""
        template_ids = self._templates_by_category.get(category, [])
        return [self._templates[tid] for tid in template_ids if tid in self._templates]
    
    def get_templates_by_tag(self, tag: str) -> List[Template]:
        """Get all templates with a specific tag."""
        matching = []
        for template in self._templates.values():
            if tag in template.tags:
                matching.append(template)
        return matching
    
    def search_templates(self, search_term: str) -> List[Template]:
        """Search templates by name, content, or tags."""
        matching = []
        search_term_lower = search_term.lower()
        
        for template in self._templates.values():
            if (search_term_lower in template.name.lower() or
                search_term_lower in template.content.lower() or
                any(search_term_lower in tag.lower() for tag in template.tags)):
                matching.append(template)
        
        return matching
    
    def update_template(self, template_id: str, **kwargs) -> bool:
        """Update template properties."""
        if template_id not in self._templates:
            return False
        
        template = self._templates[template_id]
        
        # Update provided fields
        for key, value in kwargs.items():
            if hasattr(template, key):
                setattr(template, key, value)
        
        # Update timestamps
        template.updated_at = datetime.now()
        
        # If category changed, update indexes
        if 'category' in kwargs:
            old_category = next((cat for cat, ids in self._templates_by_category.items() if template_id in ids), None)
            if old_category and template_id in self._templates_by_category[old_category]:
                self._templates_by_category[old_category].remove(template_id)
            
            if kwargs['category'] not in self._templates_by_category:
                self._templates_by_category[kwargs['category']] = []
            if template_id not in self._templates_by_category[kwargs['category']]:
                self._templates_by_category[kwargs['category']].append(template_id)
        
        logger.info(f"Updated template: {template.name}")
        return True
    
    def delete_template(self, template_id: str) -> bool:
        """Delete a template."""
        if template_id not in self._templates:
            return False
        
        template = self._templates[template_id]
        
        # Remove from indexes
        del self._templates[template_id]
        self._template_names = {k: v for k, v in self._template_names.items() if v != template_id}
        
        # Remove from category index
        for category, template_ids in self._templates_by_category.items():
            if template_id in template_ids:
                template_ids.remove(template_id)
        
        logger.info(f"Deleted template: {template.name}")
        return True
    
    def get_all_categories(self) -> List[TemplateCategory]:
        """Get all template categories that have templates."""
        return [cat for cat in TemplateCategory if self._templates_by_category.get(cat)]
    
    def get_all_tags(self) -> List[str]:
        """Get all unique tags across all templates."""
        all_tags = set()
        for template in self._templates.values():
            all_tags.update(template.tags)
        return sorted(list(all_tags))
    
    def get_templates_by_priority(self, category: TemplateCategory, max_priority: int = None) -> List[Template]:
        """Get templates by category, ordered by priority."""
        templates = self.get_templates_by_category(category)
        templates.sort(key=lambda t: t.priority, reverse=True)
        
        if max_priority is not None:
            templates = [t for t in templates if t.priority <= max_priority]
        
        return templates
    
    def get_random_template_by_category(self, category: TemplateCategory, 
                                      exclude_template_ids: List[str] = None) -> Optional[Template]:
        """Get a random template from a category, excluding specified IDs."""
        templates = self.get_templates_by_category(category)
        
        if exclude_template_ids:
            templates = [t for t in templates if t.template_id not in exclude_template_ids]
        
        if not templates:
            return None
        
        # Use weighted selection based on priority and weight
        total_weight = sum(t.priority * t.weight for t in templates)
        if total_weight <= 0:
            # If all priorities are 0 or negative, pick randomly
            import random
            return random.choice(templates)
        
        # Weighted random selection
        import random
        rand_val = random.uniform(0, total_weight)
        cumulative_weight = 0
        
        for template in templates:
            cumulative_weight += template.priority * template.weight
            if rand_val <= cumulative_weight:
                return template
        
        # Fallback
        return templates[-1] if templates else None
    
    def render_template(self, template: Template, context: Dict[str, Any] = None) -> str:
        """Render template with context variables."""
        content = template.content
        context = context or {}
        
        # Replace variables in content
        for var_name in template.variables:
            placeholder = f"{{{var_name}}}"
            if var_name in context:
                content = content.replace(placeholder, str(context[var_name]))
            elif placeholder in content:
                # If variable not in context but placeholder exists, replace with default
                content = content.replace(placeholder, f"[{var_name}]")
        
        return content
    
    def get_statistics(self) -> Dict[str, Any]:
        """Get statistics about templates."""
        category_counts = {}
        total_templates = len(self._templates)
        active_templates = len([t for t in self._templates.values() if t.is_active])
        
        for category, template_ids in self._templates_by_category.items():
            category_counts[category.value] = len([tid for tid in template_ids if tid in self._templates])
        
        return {
            "total_templates": total_templates,
            "active_templates": active_templates,
            "inactive_templates": total_templates - active_templates,
            "categories": category_counts,
            "tags_count": len(self.get_all_tags())
        }


# Singleton instance
template_manager = TemplateManager()


class AdvancedResponseGenerator:
    """Advanced response generator using template management system."""
    
    def __init__(self, template_mgr: TemplateManager = None):
        self.template_manager = template_mgr or template_manager
        self.used_templates_per_session = {}  # session_id -> [template_ids]
        self.min_reuse_distance = 3
    
    def generate_response(self, category: TemplateCategory, context: Dict[str, Any] = None,
                         session_id: str = "", exclude_recent: bool = True) -> str:
        """Generate response using template from category."""
        exclude_template_ids = []
        
        if session_id and exclude_recent:
            # Get recently used templates for this session
            recent = self.used_templates_per_session.get(session_id, [])[-self.min_reuse_distance:]
            exclude_template_ids.extend(recent)
        
        # Get a template from category
        template = self.template_manager.get_random_template_by_category(
            category, exclude_template_ids
        )
        
        if not template:
            # Fallback to generic category
            template = self.template_manager.get_random_template_by_category(
                TemplateCategory.GENERIC, exclude_template_ids
            )
        
        if not template:
            # Ultimate fallback
            return "Sure lah! Saya dah proses permintaan awak. Tqvm! 😊"
        
        # Render the template
        response = self.template_manager.render_template(template, context)
        
        # Record template usage
        if session_id:
            if session_id not in self.used_templates_per_session:
                self.used_templates_per_session[session_id] = []
            self.used_templates_per_session[session_id].append(template.template_id)
        
        return response
    
    def generate_by_intent(self, intent: str, context: Dict[str, Any] = None, 
                          session_id: str = "") -> str:
        """Generate response based on intent."""
        category_mapping = {
            'greeting': TemplateCategory.GREETING,
            'student_query': TemplateCategory.STUDENT_DATA,
            'event_query': TemplateCategory.EVENT_DATA,
            'analytics_query': TemplateCategory.ANALYTICS,
            'multi_intent': TemplateCategory.MULTI_STEP,
            'clarification_needed': TemplateCategory.CLAIRIFICATION,
            'error': TemplateCategory.ERROR_HANDLING,
            'confirmation': TemplateCategory.CONFIRMATION
        }
        
        category = category_mapping.get(intent, TemplateCategory.GENERIC)
        return self.generate_response(category, context, session_id)
    
    def clear_session_history(self, session_id: str):
        """Clear template usage history for a session."""
        if session_id in self.used_templates_per_session:
            del self.used_templates_per_session[session_id]


if __name__ == "__main__":
    # Example usage
    print("Template Management System Demo")
    print("="*40)
    
    # Show statistics
    stats = template_manager.get_statistics()
    print("Template Statistics:", stats)
    
    # Show available categories
    print("\nAvailable Categories:")
    for cat in template_manager.get_all_categories():
        print(f"  - {cat.value}")
    
    # Show tags
    print(f"\nAvailable Tags: {template_manager.get_all_tags()}")
    
    # Create and use advanced response generator
    generator = AdvancedResponseGenerator()
    
    # Generate responses with context
    print(f"\nGreeting: {generator.generate_by_intent('greeting', {'user_name': 'Ali'})}")
    print(f"Student Query: {generator.generate_by_intent('student_query', {'result_count': 5})}")
    print(f"Analytics: {generator.generate_by_intent('analytics_query', {'analysis_type': 'CGPA trends'})}")
    
    # Generate same type multiple times to show variation
    print(f"\nSame intent, different responses:")
    for i in range(3):
        resp = generator.generate_by_intent('greeting', {'user_name': 'Ahmad'})
        print(f"  {i+1}. {resp}")