from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Dict, Any, List
from ml.llm_adapter import llm_adapter

router = APIRouter()

class ExtractTasksRequest(BaseModel):
    text: str

class TaskItem(BaseModel):
    verb: str
    due_date: str | None
    text: str

class ExtractTasksResponse(BaseModel):
    summary: str
    tasks: List[TaskItem]

@router.post("/extract_tasks", response_model=ExtractTasksResponse)
async def extract_tasks(request: ExtractTasksRequest):
    """
    Extract actionable tasks from text using LLM (Groq primary, HF fallback)
    
    Example request:
    {
        "text": "Please submit your assignment by October 15th. Also, don't forget to attend the meeting tomorrow at 2 PM."
    }
    
    Example response:
    {
        "summary": "Assignment submission due October 15th and meeting tomorrow",
        "tasks": [
            {
                "verb": "submit",
                "due_date": "2025-10-15",
                "text": "assignment by October 15th"
            },
            {
                "verb": "attend",
                "due_date": "2025-01-XX",
                "text": "meeting tomorrow at 2 PM"
            }
        ]
    }
    """
    try:
        if not request.text or not request.text.strip():
            raise HTTPException(status_code=400, detail="Text cannot be empty")
        
        # Use LLM adapter to extract tasks
        result = llm_adapter.extract_tasks(request.text)
        
        # Convert to response model
        tasks = []
        for task in result.get("tasks", []):
            tasks.append(TaskItem(
                verb=task.get("verb", ""),
                due_date=task.get("due_date"),
                text=task.get("text", "")
            ))
        
        return ExtractTasksResponse(
            summary=result.get("summary", ""),
            tasks=tasks
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Task extraction failed: {str(e)}")

@router.get("/health")
async def health_check():
    """Health check endpoint for task extraction service"""
    return {
        "status": "healthy",
        "groq_available": llm_adapter.groq_client is not None,
        "hf_available": True  # requests is always available
    }


