# ================================
# src/backend/main.py - FastAPI Application
# ================================

from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import create_engine, Column, Integer, String, DateTime, Text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from pydantic import BaseModel
from datetime import datetime
import os
import redis
import json
from typing import List, Optional
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Database configuration
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://pgadmin:password@localhost/pyreact_dev")
REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379")

# Create database engine
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# Redis client
try:
    redis_client = redis.from_url(REDIS_URL, decode_responses=True)
    redis_client.ping()
    logger.info("Connected to Redis successfully")
except Exception as e:
    logger.warning(f"Could not connect to Redis: {e}")
    redis_client = None

# SQLAlchemy Models
class TaskDB(Base):
    __tablename__ = "tasks"
    
    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(200), nullable=False)
    description = Column(Text)
    completed = Column(String(10), default="false")
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

# Create tables
Base.metadata.create_all(bind=engine)

# Pydantic models
class TaskCreate(BaseModel):
    title: str
    description: Optional[str] = None

class TaskUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    completed: Optional[bool] = None

class Task(BaseModel):
    id: int
    title: str
    description: Optional[str]
    completed: bool
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True

# FastAPI app
app = FastAPI(
    title="Task Management API",
    description="A simple task management API built with FastAPI",
    version="1.0.0",
    docs_url="/api/docs",
    redoc_url="/api/redoc"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify actual frontend domains
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Dependency to get DB session
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# Cache helpers
def get_cache_key(key: str) -> str:
    return f"tasks:{key}"

def get_from_cache(key: str):
    if redis_client:
        try:
            data = redis_client.get(get_cache_key(key))
            return json.loads(data) if data else None
        except Exception as e:
            logger.warning(f"Cache read error: {e}")
    return None

def set_cache(key: str, value, expiry: int = 300):
    if redis_client:
        try:
            redis_client.setex(
                get_cache_key(key), 
                expiry, 
                json.dumps(value, default=str)
            )
        except Exception as e:
            logger.warning(f"Cache write error: {e}")

def clear_cache_pattern(pattern: str):
    if redis_client:
        try:
            keys = redis_client.keys(get_cache_key(pattern))
            if keys:
                redis_client.delete(*keys)
        except Exception as e:
            logger.warning(f"Cache clear error: {e}")

# API Routes
@app.get("/")
async def root():
    return {
        "message": "Task Management API", 
        "version": "1.0.0",
        "status": "healthy"
    }

@app.get("/health")
async def health_check():
    """Health check endpoint for Kubernetes probes"""
    health_status = {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "services": {
            "database": "healthy",
            "redis": "healthy" if redis_client else "unavailable"
        }
    }
    
    # Test database connection
    try:
        db = SessionLocal()
        db.execute("SELECT 1")
        db.close()
    except Exception as e:
        health_status["services"]["database"] = f"unhealthy: {str(e)}"
        health_status["status"] = "degraded"
    
    return health_status

@app.get("/api/tasks", response_model=List[Task])
async def get_tasks(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    """Get all tasks with optional pagination"""
    cache_key = f"all:{skip}:{limit}"
    
    # Try cache first
    cached_tasks = get_from_cache(cache_key)
    if cached_tasks:
        return [Task(**task) for task in cached_tasks]
    
    # Get from database
    tasks = db.query(TaskDB).offset(skip).limit(limit).all()
    
    # Convert to dict for caching
    tasks_data = []
    for task in tasks:
        task_dict = {
            "id": task.id,
            "title": task.title,
            "description": task.description,
            "completed": task.completed == "true",
            "created_at": task.created_at,
            "updated_at": task.updated_at
        }
        tasks_data.append(task_dict)
    
    # Cache the results
    set_cache(cache_key, tasks_data, 300)  # 5 minutes
    
    return [Task(**task) for task in tasks_data]

@app.get("/api/tasks/{task_id}", response_model=Task)
async def get_task(task_id: int, db: Session = Depends(get_db)):
    """Get a specific task by ID"""
    cache_key = f"task:{task_id}"
    
    # Try cache first
    cached_task = get_from_cache(cache_key)
    if cached_task:
        return Task(**cached_task)
    
    # Get from database
    task = db.query(TaskDB).filter(TaskDB.id == task_id).first()
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    
    task_data = {
        "id": task.id,
        "title": task.title,
        "description": task.description,
        "completed": task.completed == "true",
        "created_at": task.created_at,
        "updated_at": task.updated_at
    }
    
    # Cache the result
    set_cache(cache_key, task_data, 300)
    
    return Task(**task_data)

@app.post("/api/tasks", response_model=Task, status_code=status.HTTP_201_CREATED)
async def create_task(task: TaskCreate, db: Session = Depends(get_db)):
    """Create a new task"""
    db_task = TaskDB(
        title=task.title,
        description=task.description,
        completed="false"
    )
    
    db.add(db_task)
    db.commit()
    db.refresh(db_task)
    
    # Clear cache
    clear_cache_pattern("all:*")
    
    task_data = {
        "id": db_task.id,
        "title": db_task.title,
        "description": db_task.description,
        "completed": False,
        "created_at": db_task.created_at,
        "updated_at": db_task.updated_at
    }
    
    return Task(**task_data)

@app.put("/api/tasks/{task_id}", response_model=Task)
async def update_task(task_id: int, task: TaskUpdate, db: Session = Depends(get_db)):
    """Update an existing task"""
    db_task = db.query(TaskDB).filter(TaskDB.id == task_id).first()
    if not db_task:
        raise HTTPException(status_code=404, detail="Task not found")
    
    # Update fields
    if task.title is not None:
        db_task.title = task.title
    if task.description is not None:
        db_task.description = task.description
    if task.completed is not None:
        db_task.completed = "true" if task.completed else "false"
    
    db_task.updated_at = datetime.utcnow()
    
    db.commit()
    db.refresh(db_task)
    
    # Clear cache
    clear_cache_pattern("all:*")
    clear_cache_pattern(f"task:{task_id}")
    
    task_data = {
        "id": db_task.id,
        "title": db_task.title,
        "description": db_task.description,
        "completed": db_task.completed == "true",
        "created_at": db_task.created_at,
        "updated_at": db_task.updated_at
    }
    
    return Task(**task_data)

@app.delete("/api/tasks/{task_id}")
async def delete_task(task_id: int, db: Session = Depends(get_db)):
    """Delete a task"""
    db_task = db.query(TaskDB).filter(TaskDB.id == task_id).first()
    if not db_task:
        raise HTTPException(status_code=404, detail="Task not found")
    
    db.delete(db_task)
    db.commit()
    
    # Clear cache
    clear_cache_pattern("all:*")
    clear_cache_pattern(f"task:{task_id}")
    
    return {"message": "Task deleted successfully"}

@app.get("/api/stats")
async def get_stats(db: Session = Depends(get_db)):
    """Get task statistics"""
    cache_key = "stats"
    
    # Try cache first
    cached_stats = get_from_cache(cache_key)
    if cached_stats:
        return cached_stats
    
    # Calculate stats
    total_tasks = db.query(TaskDB).count()
    completed_tasks = db.query(TaskDB).filter(TaskDB.completed == "true").count()
    pending_tasks = total_tasks - completed_tasks
    
    stats = {
        "total_tasks": total_tasks,
        "completed_tasks": completed_tasks,
        "pending_tasks": pending_tasks,
        "completion_rate": round((completed_tasks / total_tasks * 100) if total_tasks > 0 else 0, 2)
    }
    
    # Cache for 1 minute
    set_cache(cache_key, stats, 60)
    
    return stats

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)


