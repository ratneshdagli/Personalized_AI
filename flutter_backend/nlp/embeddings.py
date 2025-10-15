"""
Embeddings pipeline for semantic search and similarity
Uses sentence-transformers (all-MiniLM) as primary, Hugging Face as fallback
"""

import os
import logging
import numpy as np
from typing import List, Optional, Union
import json

# We avoid importing heavy ML libraries at module import time. They are loaded lazily when
# an embedding is actually requested. This prevents import-time crashes on systems where
# compiled dependencies (numpy/scipy/faiss/etc.) are incompatible or not installed.
SENTENCE_TRANSFORMERS_AVAILABLE = False
HF_AVAILABLE = False

logger = logging.getLogger(__name__)

class EmbeddingsPipeline:
    """
    Embeddings pipeline with multiple fallback options
    Primary: sentence-transformers (local, free)
    Fallback: Hugging Face Inference API
    """
    
    def __init__(self):
        self.model = None
        self.hf_api_key = os.getenv("HF_API_KEY")
        self.hf_model_url = "https://api-inference.huggingface.co/models/sentence-transformers/all-MiniLM-L6-v2"
        # model is loaded lazily by _ensure_model_loaded

    def _ensure_model_loaded(self):
        """Load sentence-transformers model or mark it unavailable.

        This is called lazily to avoid import-time side effects.
        """
        if self.model is not None:
            return
        # Try to import local sentence-transformers
        try:
            from sentence_transformers import SentenceTransformer
            # instantiate model
            self.model = SentenceTransformer('all-MiniLM-L6-v2')
            logger.info("sentence-transformers model loaded successfully")
            global SENTENCE_TRANSFORMERS_AVAILABLE
            SENTENCE_TRANSFORMERS_AVAILABLE = True
            return
        except Exception as e:
            logger.warning(f"Local sentence-transformers not available or failed to load: {e}")
            self.model = None
        # Try to ensure requests is available for HF fallback
        try:
            import requests  # noqa: F401
            global HF_AVAILABLE
            HF_AVAILABLE = True
        except Exception:
            HF_AVAILABLE = False
    
    def embed_text(self, text: str) -> Optional[List[float]]:
        """
        Generate embedding for a single text
        Returns list of floats or None if failed
        """
        if not text or not text.strip():
            return None
        
        # Ensure model/loading state is available
        self._ensure_model_loaded()

        # Try local model first
        if self.model:
            try:
                embedding = self.model.encode([text])[0]
                return embedding.tolist()
            except Exception as e:
                logger.warning(f"Local embedding failed: {e}, trying fallback")
        
        # Fallback to Hugging Face
        if HF_AVAILABLE:
            try:
                return self._embed_hf(text)
            except Exception as e:
                logger.error(f"Hugging Face embedding failed: {e}")
        
        logger.error("All embedding methods failed")
        return None
    
    def embed_batch(self, texts: List[str]) -> List[Optional[List[float]]]:
        """
        Generate embeddings for multiple texts
        Returns list of embeddings (some may be None if failed)
        """
        if not texts:
            return []
        
        # Filter out empty texts
        valid_texts = [text for text in texts if text and text.strip()]
        if not valid_texts:
            return [None] * len(texts)
        
        # Ensure model/loading state
        self._ensure_model_loaded()

        # Try local model first
        if self.model:
            try:
                embeddings = self.model.encode(valid_texts)
                # Convert to list format and handle None values
                result = []
                valid_idx = 0
                for text in texts:
                    if text and text.strip():
                        result.append(embeddings[valid_idx].tolist())
                        valid_idx += 1
                    else:
                        result.append(None)
                return result
            except Exception as e:
                logger.warning(f"Local batch embedding failed: {e}, trying fallback")
        
        # Fallback to Hugging Face (one by one)
        if HF_AVAILABLE:
            result = []
            for text in texts:
                if text and text.strip():
                    try:
                        embedding = self._embed_hf(text)
                        result.append(embedding)
                    except Exception as e:
                        logger.error(f"Hugging Face embedding failed for text: {e}")
                        result.append(None)
                else:
                    result.append(None)
            return result
        
        logger.error("All embedding methods failed")
        return [None] * len(texts)
    
    def _embed_hf(self, text: str) -> Optional[List[float]]:
        """
        Generate embedding using Hugging Face Inference API
        """
        headers = {}
        if self.hf_api_key:
            headers["Authorization"] = f"Bearer {self.hf_api_key}"
        
        payload = {
            "inputs": text,
            "options": {
                "wait_for_model": True
            }
        }
        
        response = requests.post(
            self.hf_model_url,
            headers=headers,
            json=payload,
            timeout=30
        )
        
        if response.status_code == 200:
            result = response.json()
            if isinstance(result, list) and len(result) > 0:
                return result[0]
        else:
            logger.error(f"Hugging Face API error: {response.status_code} - {response.text}")
        
        return None
    
    def similarity(self, embedding1: List[float], embedding2: List[float]) -> float:
        """
        Calculate cosine similarity between two embeddings
        Returns value between -1 and 1
        """
        if not embedding1 or not embedding2:
            return 0.0
        
        try:
            # Convert to numpy arrays
            vec1 = np.array(embedding1)
            vec2 = np.array(embedding2)
            
            # Calculate cosine similarity
            dot_product = np.dot(vec1, vec2)
            norm1 = np.linalg.norm(vec1)
            norm2 = np.linalg.norm(vec2)
            
            if norm1 == 0 or norm2 == 0:
                return 0.0
            
            similarity = dot_product / (norm1 * norm2)
            return float(similarity)
        except Exception as e:
            logger.error(f"Similarity calculation failed: {e}")
            return 0.0
    
    def find_similar(self, query_embedding: List[float], candidate_embeddings: List[List[float]], 
                    top_k: int = 10, threshold: float = 0.0) -> List[tuple]:
        """
        Find most similar embeddings to query
        Returns list of (index, similarity_score) tuples
        """
        if not query_embedding or not candidate_embeddings:
            return []
        
        similarities = []
        for i, candidate in enumerate(candidate_embeddings):
            if candidate:  # Skip None embeddings
                sim = self.similarity(query_embedding, candidate)
                if sim >= threshold:
                    similarities.append((i, sim))
        
        # Sort by similarity (descending)
        similarities.sort(key=lambda x: x[1], reverse=True)
        
        return similarities[:top_k]
    
    def get_embedding_dimension(self) -> int:
        """
        Get the dimension of embeddings produced by this pipeline
        """
        # all-MiniLM-L6-v2 produces 384-dimensional embeddings regardless of backend
        return 384

# Lazy global pipeline
_embeddings_pipeline: Optional[EmbeddingsPipeline] = None


def get_embeddings_pipeline() -> EmbeddingsPipeline:
    """Get or create the global EmbeddingsPipeline instance lazily."""
    global _embeddings_pipeline
    if _embeddings_pipeline is None:
        _embeddings_pipeline = EmbeddingsPipeline()
    return _embeddings_pipeline


