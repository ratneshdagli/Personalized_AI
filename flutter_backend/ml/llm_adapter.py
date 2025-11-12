"""
LLM Adapter for Personalized AI Feed
Primary: Groq API
Fallback: Hugging Face Inference API
"""

import os
import json
import logging
from typing import Dict, List, Optional, Any
from datetime import datetime
import re

# Primary LLM: Groq
try:
    from groq import Groq
    GROQ_AVAILABLE = True
except ImportError:
    GROQ_AVAILABLE = False
    logging.warning("Groq SDK not available. Install with: pip install groq")

# Fallback: Hugging Face
try:
    import requests
    HF_AVAILABLE = True
except ImportError:
    HF_AVAILABLE = False
    logging.warning("Requests not available for Hugging Face fallback")

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class LLMAdapter:
    def __init__(self):
        self.groq_client = None
        self.groq_api_key = os.getenv("GROQ_API_KEY")
        self.hf_api_key = os.getenv("HF_API_KEY")
        
        # Initialize Groq if available
        if GROQ_AVAILABLE and self.groq_api_key:
            try:
                self.groq_client = Groq(api_key=self.groq_api_key)
                logger.info("Groq client initialized successfully")
            except Exception as e:
                logger.error(f"Failed to initialize Groq client: {e}")
                self.groq_client = None
        else:
            logger.warning("Groq not available - missing API key or SDK")
    
    def summarize(self, text: str, max_length: int = 100) -> str:
        """
        Summarize text using Groq primary, Hugging Face fallback
        """
        # Try Groq first
        if self.groq_client:
            try:
                return self._summarize_groq(text, max_length)
            except Exception as e:
                logger.warning(f"Groq summarization failed: {e}, trying fallback")
        
        # Fallback to Hugging Face
        if HF_AVAILABLE:
            try:
                return self._summarize_hf(text, max_length)
            except Exception as e:
                logger.error(f"Hugging Face summarization failed: {e}")
        
        # Final fallback: simple truncation
        return self._simple_summary(text, max_length)
    
    def extract_tasks(self, text: str) -> Dict[str, Any]:
        """
        Extract tasks from text using LLM
        Returns: {"summary": str, "tasks": [{"verb": str, "due_date": str, "text": str}]}
        """
        # Try Groq first
        if self.groq_client:
            try:
                return self._extract_tasks_groq(text)
            except Exception as e:
                logger.warning(f"Groq task extraction failed: {e}, trying fallback")
        
        # Fallback to rule-based extraction
        return self._extract_tasks_rules(text)
    
    def extract_events(self, text: str) -> Dict[str, Any]:
        """
        Extract calendar events from text using LLM
        Returns: {"summary": str, "events": [{"title": str, "start_time": str, "duration_minutes": int, "location": str}]}
        """
        # Try Groq first
        if self.groq_client:
            try:
                return self._extract_events_groq(text)
            except Exception as e:
                logger.warning(f"Groq event extraction failed: {e}, trying fallback")
        
        # Fallback to rule-based extraction
        return self._extract_events_rules(text)
    
    def _summarize_groq(self, text: str, max_length: int) -> str:
        """Summarize using Groq API"""
        prompt = f"""Summarize the following text in one concise sentence (max {max_length} characters):

Text: {text}

Summary:"""
        
        response = self.groq_client.chat.completions.create(
            model="llama3-8b-8192",  # Fast and effective model
            messages=[{"role": "user", "content": prompt}],
            max_tokens=150,
            temperature=0.3
        )
        
        summary = response.choices[0].message.content.strip()
        return summary[:max_length]
    
    def _summarize_hf(self, text: str, max_length: int) -> str:
        """Summarize using Hugging Face Inference API"""
        # Use a free summarization model
        model_url = "https://api-inference.huggingface.co/models/facebook/bart-large-cnn"
        
        headers = {}
        if self.hf_api_key:
            headers["Authorization"] = f"Bearer {self.hf_api_key}"
        
        payload = {
            "inputs": text,
            "parameters": {
                "max_length": max_length,
                "min_length": 20,
                "do_sample": False
            }
        }
        
        response = requests.post(model_url, headers=headers, json=payload, timeout=30)
        response.raise_for_status()
        
        result = response.json()
        if isinstance(result, list) and len(result) > 0:
            return result[0].get("summary_text", "")[:max_length]
        
        return self._simple_summary(text, max_length)
    
    def _extract_tasks_groq(self, text: str) -> Dict[str, Any]:
        """Extract tasks using Groq API with structured output"""
        prompt = f"""Analyze the following text and extract actionable tasks. Return a JSON response with this exact structure:

{{
    "summary": "One-line summary of the text",
    "tasks": [
        {{
            "verb": "action verb (submit, complete, attend, etc.)",
            "due_date": "YYYY-MM-DD or null if no date found",
            "text": "relevant text snippet"
        }}
    ]
}}

Text to analyze: {text}

JSON Response:"""
        
        response = self.groq_client.chat.completions.create(
            model="llama3-8b-8192",
            messages=[{"role": "user", "content": prompt}],
            max_tokens=500,
            temperature=0.1,
            response_format={"type": "json_object"}
        )
        
        result_text = response.choices[0].message.content.strip()
        
        try:
            result = json.loads(result_text)
            # Validate structure
            if "summary" not in result:
                result["summary"] = self._simple_summary(text, 100)
            if "tasks" not in result:
                result["tasks"] = []
            
            return result
        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse Groq JSON response: {e}")
            return self._extract_tasks_rules(text)
    
    def _extract_tasks_rules(self, text: str) -> Dict[str, Any]:
        """Rule-based task extraction as fallback"""
        summary = self._simple_summary(text, 100)
        tasks = []
        
        # Common task patterns
        task_patterns = [
            r'(submit|hand in|turn in|send)\s+([^.!?]*(?:assignment|homework|project|report|form|application)[^.!?]*)',
            r'(complete|finish|do)\s+([^.!?]*(?:assignment|homework|project|task)[^.!?]*)',
            r'(attend|go to|join)\s+([^.!?]*(?:meeting|event|class|session)[^.!?]*)',
            r'(register|sign up|apply)\s+([^.!?]*(?:for|to)[^.!?]*)',
            r'(pay|submit payment)\s+([^.!?]*(?:fee|bill|payment)[^.!?]*)',
            r'(review|check|read)\s+([^.!?]*(?:document|email|message)[^.!?]*)',
        ]
        
        # Date patterns
        date_patterns = [
            r'(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})',
            r'(\d{4}-\d{2}-\d{2})',
            r'(tomorrow|today|next week|next month)',
            r'(due|deadline|by)\s+([^.!?]*)',
        ]
        
        text_lower = text.lower()
        
        for pattern in task_patterns:
            matches = re.finditer(pattern, text_lower, re.IGNORECASE)
            for match in matches:
                verb = match.group(1)
                task_text = match.group(2) if len(match.groups()) > 1 else match.group(0)
                
                # Look for dates near this task
                due_date = None
                for date_pattern in date_patterns:
                    date_match = re.search(date_pattern, text_lower)
                    if date_match:
                        due_date = self._parse_date(date_match.group(1))
                        break
                
                tasks.append({
                    "verb": verb,
                    "due_date": due_date,
                    "text": task_text.strip()
                })
        
        return {
            "summary": summary,
            "tasks": tasks[:5]  # Limit to 5 tasks
        }
    
    def _simple_summary(self, text: str, max_length: int) -> str:
        """Simple fallback summary using first sentence or truncation"""
        sentences = text.split('.')
        if sentences:
            first_sentence = sentences[0].strip()
            if len(first_sentence) <= max_length:
                return first_sentence
            else:
                return first_sentence[:max_length-3] + "..."
        
        return text[:max_length-3] + "..." if len(text) > max_length else text
    
    def _extract_events_groq(self, text: str) -> Dict[str, Any]:
        """Extract calendar events using Groq API with structured output"""
        prompt = f"""Analyze the following text and extract calendar events or meetings. Return a JSON response with this exact structure:

{{
    "summary": "One-line summary of the text",
    "events": [
        {{
            "title": "event title",
            "start_time": "YYYY-MM-DD HH:MM or null if no date/time found",
            "duration_minutes": estimated duration in minutes (30, 60, 90, etc.),
            "location": "location if mentioned, else null",
            "description": "brief description"
        }}
    ]
}}

Text to analyze: {text}

JSON Response:"""
        
        response = self.groq_client.chat.completions.create(
            model="llama3-8b-8192",
            messages=[{"role": "user", "content": prompt}],
            max_tokens=500,
            temperature=0.1,
            response_format={"type": "json_object"}
        )
        
        result_text = response.choices[0].message.content.strip()
        
        try:
            result = json.loads(result_text)
            # Validate structure
            if "summary" not in result:
                result["summary"] = self._simple_summary(text, 100)
            if "events" not in result:
                result["events"] = []
            
            return result
        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse Groq JSON response: {e}")
            return self._extract_events_rules(text)
    
    def _extract_events_rules(self, text: str) -> Dict[str, Any]:
        """Rule-based event extraction as fallback"""
        summary = self._simple_summary(text, 100)
        events = []
        
        # Common event patterns
        event_patterns = [
            r'(meeting|call|appointment|session|interview)\s+([^.!?]*(?:at|on|@)[^.!?]*)',
            r'(dinner|lunch|breakfast)\s+([^.!?]*(?:with|at)[^.!?]*)',
            r'(event|conference|seminar|workshop)\s+([^.!?]*)',
        ]
        
        text_lower = text.lower()
        
        for pattern in event_patterns:
            matches = re.finditer(pattern, text_lower, re.IGNORECASE)
            for match in matches:
                event_type = match.group(1)
                context = match.group(2) if len(match.groups()) > 1 else match.group(0)
                
                # Extract time and date
                time_pattern = r'(\d{1,2}(?::\d{2})?\s*(?:AM|PM|am|pm)?|at\s+\d{1,2})'
                time_match = re.search(time_pattern, context)
                
                # Try to extract date
                start_time = None
                date_match = re.search(r'(tomorrow|today|\d{1,2}/\d{1,2}|\d{4}-\d{2}-\d{2})', text_lower)
                if date_match and time_match:
                    date_str = date_match.group(1)
                    time_str = time_match.group(1)
                    parsed_date = self._parse_date(date_str)
                    if parsed_date:
                        # Combine date and time
                        start_time = f"{parsed_date} {time_str}"
                
                events.append({
                    "title": f"{event_type.title()}: {context[:50]}",
                    "start_time": start_time,
                    "duration_minutes": 60,  # default 1 hour
                    "location": None,
                    "description": context.strip()
                })
        
        return {
            "summary": summary,
            "events": events[:3]  # Limit to 3 events
        }
    
    def _parse_date(self, date_str: str) -> Optional[str]:
        """Parse various date formats to YYYY-MM-DD"""
        try:
            # Handle relative dates
            if "tomorrow" in date_str.lower():
                tomorrow = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
                tomorrow = tomorrow.replace(day=tomorrow.day + 1)
                return tomorrow.strftime("%Y-%m-%d")
            elif "today" in date_str.lower():
                today = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
                return today.strftime("%Y-%m-%d")
            
            # Handle MM/DD/YYYY or DD/MM/YYYY
            if '/' in date_str:
                parts = date_str.split('/')
                if len(parts) == 3:
                    month, day, year = parts
                    if len(year) == 2:
                        year = '20' + year
                    return f"{year}-{month.zfill(2)}-{day.zfill(2)}"
            
            # Handle YYYY-MM-DD
            if '-' in date_str and len(date_str) == 10:
                return date_str
            
        except Exception as e:
            logger.warning(f"Failed to parse date '{date_str}': {e}")
        
        return None

# Global instance
# Global instance
llm_adapter = LLMAdapter()

def get_llm_adapter():
    """Returns the global LLM adapter instance"""
    return llm_adapter

# Module-level convenience functions for backward compatibility
def summarize(text: str, max_length: int = 100) -> str:
    """Summarize text using the global LLM adapter"""
    return llm_adapter.summarize(text, max_length)

def extract_tasks(text: str) -> Dict[str, Any]:
    """Extract tasks from text using the global LLM adapter"""
    return llm_adapter.extract_tasks(text)

def extract_events(text: str) -> Dict[str, Any]:
    """Extract events from text using the global LLM adapter"""
    return llm_adapter.extract_events(text)

def embed(text: str) -> List[float]:
    """Generate embeddings for text (placeholder implementation)"""
    # This is a placeholder - in a real implementation, you'd use a proper embedding model
    # For now, return a simple hash-based vector
    import hashlib
    hash_obj = hashlib.md5(text.encode())
    hash_bytes = hash_obj.digest()
    # Convert to float vector
    return [float(b) / 255.0 for b in hash_bytes[:8]]  # 8-dimensional vector


