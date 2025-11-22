from fastapi import APIRouter, HTTPException, BackgroundTasks
from fastapi.responses import FileResponse
from typing import List, Optional, Dict, Any
import os
import logging
import json
import hashlib
import httpx
from pathlib import Path
from pydantic import BaseModel
from huggingface_hub import hf_hub_download

# Constants
ALLOWLIST_PATH = Path(__file__).parent.parent / 'config' / 'model_allowlist.json'
ALLOWLIST: List[Dict[str, Any]] = []  # This will store the loaded allowlist

# --- Setup & Logging ---
router = APIRouter(prefix="/models", tags=["models"])
logger = logging.getLogger(__name__)

# --- Environment Variable (CRITICAL) ---
# Load the Hugging Face token from environment
HF_TOKEN = "" 
if not HF_TOKEN:
    logger.warning("HUGGINGFACEHUB_API_TOKEN environment variable not set. Downloads may fail.")

# --- File Paths ---
# Create a 'models' directory at the root of your backend project
MODELS_DIR = Path(__file__).parent.parent / 'models'
MODELS_DIR.mkdir(exist_ok=True)

# Load allowlist
try:
    # Try multiple possible locations for the allowlist file
    possible_paths = [
        Path(__file__).parent.parent / 'config' / 'model_allowlist.json',  # Primary location
        Path(__file__).parent.parent.parent / 'Edge Galelry(LLM)' / 'gallery-main' / 'model_allowlist.json',
        Path(__file__).parent.parent / 'model_allowlist.json',
        Path(__file__).parent / 'model_allowlist.json'
    ]
    
    ALLOWLIST_FILE = None
    for path in possible_paths:
        logger.info(f"Checking for model_allowlist.json at: {path}")
        if path.exists():
            ALLOWLIST_FILE = path
            logger.info(f"Using model_allowlist.json from: {path}")
            break
            
    if not ALLOWLIST_FILE:
        raise FileNotFoundError("Could not find model_allowlist.json in any expected location")
        
    with open(ALLOWLIST_FILE, 'r', encoding='utf-8') as f:
        MODEL_DATA = json.load(f)
    SAMPLE_MODELS = MODEL_DATA.get('models', [])
    
    if not SAMPLE_MODELS:
        raise ValueError("No models found in the allowlist file")
        
    logger.info(f'Successfully loaded {len(SAMPLE_MODELS)} models from {ALLOWLIST_FILE}')
    
    # Log the loaded model IDs for debugging
    for model in SAMPLE_MODELS:
        logger.info(f"Loaded model: {model.get('name')} (ID: {model.get('modelId')})")
    
except Exception as e:
    logger.error(f'FATAL: Failed to load models from {ALLOWLIST_FILE if ALLOWLIST_FILE else "allowlist file"}: {str(e)}')
    raise RuntimeError(f"Failed to load models. Check path: {ALLOWLIST_FILE}")

# --- Pydantic Models ---
class ModelInfo(BaseModel):
    id: str  # The unique ID from the allowlist
    displayName: str
    hfRepoId: str
    fileName: str  # This matches the 'modelFile' in model_allowlist.json
    sizeInBytes: int
    description: Optional[str] = None
    version: Optional[str] = None
    
    # We only need these fields for the /models endpoint
    @classmethod
    def from_allowlist(cls, model_data: dict):
        # Debug log the incoming model data
        logger.debug(f"Processing model data: {json.dumps(model_data, indent=2)}")
        

class PrepareRequest(BaseModel):
    hfRepoId: str
    fileName: str

class PrepareResponse(BaseModel):
    filename: str
    sizeBytes: int
    sha256: str
    downloadUrl: str

# --- Helper Functions ---
async def load_allowlist():
    """Load the model allowlist from local file."""
    global ALLOWLIST
    try:
        if not ALLOWLIST_PATH.exists():
            logger.error(f"Allowlist file not found at {ALLOWLIST_PATH}")
            ALLOWLIST = []
            return
            
        with open(ALLOWLIST_PATH, 'r', encoding='utf-8') as f:
            data = json.load(f)
            # Extract the models list from the data
            ALLOWLIST = data.get('models', [])
            logger.info(f"Successfully loaded {len(ALLOWLIST)} models from local allowlist")
    except Exception as e:
        logger.error(f"Failed to load allowlist from {ALLOWLIST_PATH}: {e}")
        ALLOWLIST = []

def get_model_from_allowlist(repo_id: str, filename: str) -> Optional[dict]:
    """Checks if the requested model is in the allowlist."""
    for model in ALLOWLIST:
        if model.get('modelId') == repo_id and model.get('modelFile') == filename:
            return model
    return None

def calculate_sha256(file_path: Path) -> str:
    sha256_hash = hashlib.sha256()
    with open(file_path, "rb") as f:
        for byte_chunk in iter(lambda: f.read(4096), b""):
            sha256_hash.update(byte_chunk)
    return sha256_hash.hexdigest()

def get_safe_filename(repo_id: str, filename: str) -> str:
    safe_repo = repo_id.replace('/', '--')
    return f"{safe_repo}--{filename}"

# --- Lifespan Event ---
@router.on_event("startup")
async def startup_event():
    """Load the allowlist when the server starts."""
    await load_allowlist()

# --- Endpoints ---
@router.get("/", response_model=List[ModelInfo])
async def list_models():
    """
    List all available models from the allowlist.
    """
    if not ALLOWLIST:
        logger.error("Allowlist is empty. Cannot serve models.")
        raise HTTPException(status_code=503, detail="Model allowlist is not loaded. Check server logs.")
        
    logger.info(f"Listing all {len(ALLOWLIST)} models from allowlist")
        
    try:
        models = [
            ModelInfo(
                id=model.get('modelId', ''),
                displayName=model.get('name', 'Unnamed Model'),
                hfRepoId=model.get('modelId', ''),
                fileName=model.get('modelFile', ''),
                sizeInBytes=model.get('sizeInBytes', 0),
                description=model.get('description'),
                version=model.get('version')
            )
            for model in ALLOWLIST
        ]
        return models
    except Exception as e:
        logger.error(f"Error formatting models: {str(e)}")
        raise HTTPException(status_code=500, detail="Failed to process model list")

@router.post("/prepare", response_model=PrepareResponse)
async def prepare_model(request: PrepareRequest):
    """
    Validates, downloads, and prepares a model from Hugging Face.
    """
    logger.info(f"Prepare request received for: {request.hfRepoId} / {request.fileName}")

    if not HF_TOKEN:
        logger.error("HUGGINGFACEHUB_API_TOKEN is not set. Cannot download model.")
        raise HTTPException(status_code=500, detail="Server is missing API token")

    allowed_model = get_model_from_allowlist(request.hfRepoId, request.fileName)
    if not allowed_model:
        logger.warning(f"Rejected: Model not in allowlist: {request.hfRepoId} / {request.fileName}")
        raise HTTPException(status_code=403, detail="Model not in allowlist")

    safe_filename = get_safe_filename(request.hfRepoId, request.fileName)
    local_file_path = MODELS_DIR / safe_filename
    
    if local_file_path.exists():
        try:
            size_bytes = local_file_path.stat().st_size
            sha256 = calculate_sha256(local_file_path)
            logger.info(f"Model already cached: {safe_filename}")
            return PrepareResponse(
                filename=safe_filename,
                sizeBytes=size_bytes,
                sha256=sha256,
                downloadUrl=f"/api/v1/models/download/{safe_filename}"
            )
        except Exception as e:
            logger.warning(f"Failed to verify cache for {safe_filename}: {e}. Redownloading.")
            
    logger.info(f"Downloading model from Hugging Face to {local_file_path}...")
    try:
        hf_hub_download(
            repo_id=request.hfRepoId,
            filename=request.fileName,
            local_dir=MODELS_DIR,
            local_dir_use_symlinks=False,
            token=HF_TOKEN,
            local_files_only=False
        )
        
        downloaded_path = MODELS_DIR / request.fileName
        
        if downloaded_path.exists():
            downloaded_path.rename(local_file_path)
            logger.info(f"Download complete and saved to: {local_file_path}")
        else:
            raise FileNotFoundError(f"Failed to find downloaded file at {downloaded_path}")

    except Exception as e:
        logger.error(f"Hugging Face download failed: {str(e)}")
        if local_file_path.exists():
            local_file_path.unlink()
        raise HTTPException(status_code=500, detail=f"Hugging Face download error: {str(e)}")

    try:
        size_bytes = local_file_path.stat().st_size
        sha256 = calculate_sha256(local_file_path)
    except Exception as e:
        logger.error(f"Failed to calculate metadata for {local_file_path}: {str(e)}")
        if local_file_path.exists():
            local_file_path.unlink()
        raise HTTPException(status_code=500, detail="Failed to process file after download")

    return PrepareResponse(
        filename=safe_filename,
        sizeBytes=size_bytes,
        sha256=sha256,
        downloadUrl=f"/api/v1/models/download/{safe_filename}"
    )

@router.get("/download/{filename}", response_class=FileResponse)
async def download_file(filename: str):
    """
    Serves the prepared model file from the local 'models' directory.
    """
    local_file_path = MODELS_DIR / filename
    
    if not local_file_path.is_file():
        logger.error(f"File not found for download: {local_file_path}")
        raise HTTPException(status_code=404, detail="File not found. Run /models/prepare first.")
    
    logger.info(f"Serving file: {local_file_path}")
    return FileResponse(
        path=local_file_path,
        media_type="application/octet-stream",
        filename=filename
    )

@router.post("/api/v1/models/{model_id}/download")
async def download_model(model_id: str):
    """
    Prepare a model for download.
    In a real implementation, this would initiate a download from Hugging Face.
    """
    try:
        import urllib.parse
        
        def normalize_model_id(model_id: str) -> str:
            """Normalize model ID for comparison"""
            model_id = model_id.lower().strip()
            if '/' in model_id:
                model_id = model_id.split('/')[-1]
            for suffix in ['-int4', '-int8', '-fp16', '.task', '.bin', '.safetensors']:
                if model_id.endswith(suffix):
                    model_id = model_id[:-len(suffix)]
            return model_id
        
        available_models = [
            f"{m.get('modelId')} (name: {m.get('name')})" 
            for m in ALLOWLIST
        ]
        logger.info(f"Looking for model: {model_id}")
        logger.info(f"Available models: {available_models}")
        
        # Normalize the input model_id for comparison
        model_id_lower = model_id.lower()
        model_id_last_part = model_id.split('/')[-1].lower()
        
        # Try different matching strategies
        for m in SAMPLE_MODELS:
            # Get all possible identifiers for this model
            identifiers = [
                m.get('modelId', ''),
                m.get('hfRepoId', ''),
                m.get('name', ''),
                m.get('modelId', '').split('/')[-1],
                m.get('hfRepoId', '').split('/')[-1] if m.get('hfRepoId') else '',
                m.get('name', '').lower().replace(' ', '-')  # Try name with hyphens
            ]
            
            # Remove empty strings and normalize
            identifiers = [id for id in identifiers if id]
            
            # Check for matches
            for identifier in identifiers:
                # Exact match
                if identifier == model_id:
                    logger.info(f"Found exact match: {m.get('modelId')}")
                    model = m
                    break
                    
                # Case-insensitive match
                if identifier.lower() == model_id_lower:
                    logger.info(f"Found case-insensitive match: {m.get('modelId')}")
                    model = m
                    break
                    
                # Match last part (after last slash)
                if identifier.split('/')[-1].lower() == model_id_last_part:
                    logger.info(f"Found match by last part: {m.get('modelId')}")
                    model = m
                    break
                    
                # Match with normalized IDs
                if normalize_model_id(identifier.split('/')[-1].lower()) == normalize_model_id(model_id_last_part):
                    logger.info(f"Found match by normalized ID: {m.get('modelId')}")
                    model = m
                    break
                    
            if model:
                break
        
        # Try URL decoding the model_id in case it's encoded
        if not model:
            try:
                decoded_id = urllib.parse.unquote(model_id)
                if decoded_id != model_id:
                    logger.info(f"Trying URL decoded ID: {decoded_id}")
                    return await download_model(decoded_id)
            except Exception as e:
                logger.warning(f"Error URL decoding model_id: {e}")
        
        if not model:
            available_models = [
                f"{m.get('name')} (ID: {m.get('modelId')})" 
                for m in SAMPLE_MODELS
            ]
            error_msg = f"Model not found: {model_id}\nAvailable models:\n" + "\n".join(available_models)
            logger.error(error_msg)
            
            # Try to find similar models
            similar_models = []
            model_id_lower = model_id.lower()
            for m in SAMPLE_MODELS:
                if (model_id_lower in m.get('modelId', '').lower() or 
                    model_id_lower in m.get('name', '').lower()):
                    similar_models.append(f"- {m.get('name')} (ID: {m.get('modelId')})")
            
            detail = {
                "error": "Model not found",
                "requested_id": model_id,
                "available_models": [m['modelId'] for m in SAMPLE_MODELS],
            }
            
            if similar_models:
                detail["suggestions"] = similar_models
                
            raise HTTPException(status_code=404, detail=detail)
            
        logger.info(f"Found model: {model}")
        
        # In a real implementation, you would start the download process here
        # and return a download URL or initiate a WebSocket connection for progress updates
        
        return {
            "status": "preparing",
            "model_id": model.get('modelId'),
            "model_name": model.get('name'),
            "download_url": f"/api/v1/models/{urllib.parse.quote(model.get('modelId'))}/download/file",
            "sizeBytes": model.get('sizeInBytes', 0),
            "model_file": model.get('modelFile')
        }
        
    except Exception as e:
        logger.error(f"Error preparing model {model_id} for download: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to prepare model for download: {str(e)}")

@router.get("/api/v1/models/{model_id}/download/file")
async def download_model_file(model_id: str):
    """
    Download the model file.
    This will ensure the model is downloaded from Hugging Face and then serve it.
    """
    try:
        # URL decode the model_id
        import urllib.parse
        decoded_id = urllib.parse.unquote(model_id)
        
        # Find the model
        model = None
        for m in ALLOWLIST:
            if m.get('modelId') == decoded_id or m.get('hfRepoId') == decoded_id:
                model = m
                break
                
        if not model:
            # Try to find by partial match or name if exact match failed
            for m in ALLOWLIST:
                if m.get('modelId').endswith(decoded_id):
                    model = m
                    break
            
        if not model:
            raise HTTPException(status_code=404, detail=f"Model not found: {decoded_id}")
            
        logger.info(f"Request to download model: {model.get('name')} ({model.get('modelId')})")
        
        # Ensure model is downloaded
        repo_id = model.get('hfRepoId') or model.get('modelId')
        filename = model.get('modelFile')
        
        if not repo_id or not filename:
             raise HTTPException(status_code=500, detail="Model configuration error: missing repo_id or filename")

        try:
            logger.info(f"Ensuring model is available: {repo_id} / {filename}")
            # This will download if not cached, or return path if cached
            # We use the default cache dir or the one specified in env
            model_path = hf_hub_download(
                repo_id=repo_id,
                filename=filename,
                token=HF_TOKEN,
                local_files_only=False # Allow downloading if not present
            )
            logger.info(f"Model available at: {model_path}")
            
        except Exception as e:
            logger.error(f"Failed to download/locate model from Hugging Face: {e}")
            raise HTTPException(status_code=502, detail=f"Failed to retrieve model from upstream: {e}")
            
        # Serve the file
        return FileResponse(
            path=model_path,
            media_type="application/octet-stream",
            filename=filename
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error downloading model file {model_id}: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to download model file: {str(e)}")
