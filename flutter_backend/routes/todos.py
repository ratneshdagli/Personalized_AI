"""
Todos API Routes

Provides endpoints for managing AI-extracted todos from notifications.
"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
from datetime import datetime
import logging

from app.core.nosql import store

logger = logging.getLogger(__name__)

router = APIRouter()


class TodoItem(BaseModel):
    """Todo item model"""
    id: Optional[int] = None
    title: str
    verb: str
    due_date: Optional[str] = None
    description: Optional[str] = None
    priority: int = 1
    completed: bool = False
    source: str = "ai_extracted"  # ai_extracted, manual, whatsapp, etc.
    source_id: Optional[str] = None  # ID of the feed item it came from
    user_id: int = 1
    created_at: Optional[float] = None
    completed_at: Optional[float] = None


@router.get("/todos")
async def get_todos(user_id: int = 1, completed: Optional[bool] = None):
    """Get all todos for a user"""
    try:
        todos = store.tasks.search(lambda t: t.get("user_id") == user_id and not t.get("deleted"))
        
        # Filter by completed status if specified
        if completed is not None:
            todos = [t for t in todos if t.get("completed") == completed]
        
        # Sort by created_at desc
        todos.sort(key=lambda t: t.get("created_at") or 0, reverse=True)
        
        return {"todos": todos, "total": len(todos)}
        
    except Exception as e:
        logger.error(f"Error getting todos: {e}")
        raise HTTPException(status_code=500, detail=f"Error getting todos: {str(e)}")


@router.post("/todos")
async def create_todo(todo: TodoItem):
    """Create a new todo"""
    try:
        todo_dict = todo.dict()
        todo_dict["created_at"] = datetime.now().timestamp()
        todo_dict["deleted"] = False
        
        todo_id = store.insert("tasks", todo_dict)
        todo_dict["id"] = todo_id
        
        return {"message": "Todo created", "todo": todo_dict}
        
    except Exception as e:
        logger.error(f"Error creating todo: {e}")
        raise HTTPException(status_code=500, detail=f"Error creating todo: {str(e)}")


@router.put("/todos/{todo_id}")
async def update_todo(todo_id: int, todo: TodoItem):
    """Update a todo"""
    try:
        todos = store.tasks.search(lambda t: t.get("id") == todo_id)
        if not todos:
            raise HTTPException(status_code=404, detail="Todo not found")
        
        todo_dict = todo.dict()
        todo_dict["id"] = todo_id
        
        if todo.completed and not todos[0].get("completed"):
            todo_dict["completed_at"] = datetime.now().timestamp()
        
        store.upsert("tasks", todo_dict, key="id")
        
        return {"message": "Todo updated", "todo": todo_dict}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating todo: {e}")
        raise HTTPException(status_code=500, detail=f"Error updating todo: {str(e)}")


@router.delete("/todos/{todo_id}")
async def delete_todo(todo_id: int):
    """Soft delete a todo"""
    try:
        todos = store.tasks.search(lambda t: t.get("id") == todo_id)
        if not todos:
            raise HTTPException(status_code=404, detail="Todo not found")
        
        todo = dict(todos[0])
        todo["deleted"] = True
        store.upsert("tasks", todo, key="id")
        
        return {"message": "Todo deleted"}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting todo: {e}")
        raise HTTPException(status_code=500, detail=f"Error deleting todo: {str(e)}")


@router.post("/todos/{todo_id}/complete")
async def complete_todo(todo_id: int):
    """Mark a todo as completed"""
    try:
        todos = store.tasks.search(lambda t: t.get("id") == todo_id)
        if not todos:
            raise HTTPException(status_code=404, detail="Todo not found")
        
        todo = dict(todos[0])
        todo["completed"] = True
        todo["completed_at"] = datetime.now().timestamp()
        store.upsert("tasks", todo, key="id")
        
        return {"message": "Todo completed", "todo": todo}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error completing todo: {e}")
        raise HTTPException(status_code=500, detail=f"Error completing todo: {str(e)}")
