from fastapi import FastAPI
from routes.feed import router as feed_router

app = FastAPI(title="Personal AI Feed Backend")

# Include the feed router
app.include_router(feed_router, prefix="/api")

# Root endpoint
@app.get("/")
def root():
    return {"message": "Welcome to Personal AI Feed Backend!"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
