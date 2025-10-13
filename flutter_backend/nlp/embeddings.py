"""
Embeddings pipeline for semantic search and similarity
Uses sentence-transformers (all-MiniLM) as primary, Hugging Face as fallback
"""

import os
import logging
import numpy as np
from typing import List, Optional, Union
import json

# Primary: sentence-transformers
try:
    from sentence_transformers import SentenceTransformer
    SENTENCE_TRANSFORMERS_AVAILABLE = True
except ImportError:
    SENTENCE_TRANSFORMERS_AVAILABLE = False
    logging.warning("sentence-transformers not available. Install with: pip install sentence-transformers")

# Fallback: Hugging Face Inference API
try:
    import requests
    HF_AVAILABLE = True
except ImportError:
    HF_AVAILABLE = False
    logging.warning("requests not available for Hugging Face fallback")

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
        
        # Initialize primary model
        if SENTENCE_TRANSFORMERS_AVAILABLE:
            try:
                # Use a lightweight, fast model for embeddings
                self.model = SentenceTransformer('all-MiniLM-L6-v2')
                logger.info("sentence-transformers model loaded successfully")
            except Exception as e:
                logger.error(f"Failed to load sentence-transformers model: {e}")
                self.model = None
        else:
            logger.warning("sentence-transformers not available, will use Hugging Face fallback")
    
    def embed_text(self, text: str) -> Optional[List[float]]:
        """
        Generate embedding for a single text
        Returns list of floats or None if failed
        """
        if not text or not text.strip():
            return None
        
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
        if self.model:
            # all-MiniLM-L6-v2 produces 384-dimensional embeddings
            return 384
        else:
            # Hugging Face all-MiniLM-L6-v2 also produces 384 dimensions
            return 384

# Global instance
embeddings_pipeline = EmbeddingsPipeline()

def get_embeddings_pipeline() -> EmbeddingsPipeline:
    """Get the global embeddings pipeline instance"""
    return embeddings_pipeline


