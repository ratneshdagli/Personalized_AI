"""
Vector store implementation using FAISS for semantic search
Provides efficient similarity search over embeddings
"""

import os
import json
import logging
import numpy as np
from typing import List, Dict, Any, Optional
import pickle

# FAISS for vector search
try:
    import faiss
    FAISS_AVAILABLE = True
except ImportError:
    FAISS_AVAILABLE = False
    logging.warning("FAISS not available. Install with: pip install faiss-cpu")

from .db import get_db_session
from .models import FeedItem
from nlp.embeddings import get_embeddings_pipeline

logger = logging.getLogger(__name__)

class VectorStore:
    """
    FAISS-based vector store for semantic search
    Stores embeddings and provides similarity search functionality
    """
    
    def __init__(self, index_path: str = "./data/vector_index"):
        self.index_path = index_path
        self.index = None
        self.id_mapping = {}  # Maps FAISS index -> (feed_item_id, user_id)
        self.embeddings_pipeline = get_embeddings_pipeline()
        self.dimension = self.embeddings_pipeline.get_embedding_dimension()

        os.makedirs(os.path.dirname(index_path), exist_ok=True)
        # Delay index initialization until first use to avoid import-time failures
        self._initialized = False
    
    def _initialize_index(self):
        """Initialize or load FAISS index"""
        if not FAISS_AVAILABLE:
            logger.error("FAISS not available, vector search disabled")
            return
        if self._initialized:
            return
        try:
            if os.path.exists(f"{self.index_path}.faiss"):
                self.index = faiss.read_index(f"{self.index_path}.faiss")
                with open(f"{self.index_path}.ids", "rb") as f:
                    self.id_mapping = pickle.load(f)
                logger.info(f"Loaded existing vector index with {self.index.ntotal} vectors")
            else:
                # Prefer IndexFlatIP if available, otherwise try IndexFlatL2
                if hasattr(faiss, 'IndexFlatIP'):
                    self.index = faiss.IndexFlatIP(self.dimension)
                elif hasattr(faiss, 'IndexFlatL2'):
                    self.index = faiss.IndexFlatL2(self.dimension)
                else:
                    logger.error("FAISS installed but no suitable IndexFlat* class found")
                    self.index = None
                self.id_mapping = {}
                logger.info("Created new vector index")
        except Exception as e:
            logger.error(f"Failed to initialize vector index: {e}")
            # Initialization failed; set index to None to disable vector ops
            try:
                if hasattr(faiss, 'IndexFlatL2'):
                    self.index = faiss.IndexFlatL2(self.dimension)
                else:
                    self.index = None
            except Exception:
                self.index = None
            self.id_mapping = {}
        finally:
            self._initialized = True
    
    def add_embedding(self, feed_item_id: int, embedding: List[float], user_id: Optional[int] = None) -> bool:
        """Add an embedding to the vector store"""
        if not FAISS_AVAILABLE:
            logger.warning("add_embedding: FAISS not available, skipping")
            return False
        if not self._initialized:
            self._initialize_index()
        if not self.index or not embedding:
            return False
        try:
            embedding_array = np.array(embedding, dtype=np.float32)
            embedding_array /= np.linalg.norm(embedding_array)
            
            self.index.add(embedding_array.reshape(1, -1))
            faiss_index = self.index.ntotal - 1
            self.id_mapping[faiss_index] = (feed_item_id, user_id)
            logger.debug(f"Added embedding for feed item {feed_item_id} (user {user_id}) at index {faiss_index}")
            return True
        except Exception as e:
            logger.error(f"Failed to add embedding: {e}")
            return False
    
    def remove_embedding(self, feed_item_id: int) -> bool:
        """Remove an embedding (rebuild index without it)"""
        if not self.index:
            return False
        try:
            if not any(feed_item_id == val[0] for val in self.id_mapping.values()):
                logger.warning(f"Feed item {feed_item_id} not in vector store")
                return False
            self._rebuild_index_excluding(feed_item_id)
            return True
        except Exception as e:
            logger.error(f"Failed to remove embedding: {e}")
            return False
    
    def _rebuild_index_excluding(self, exclude_feed_item_id: int):
        """Rebuild index excluding a specific feed item"""
        try:
            db = get_db_session()
            try:
                feed_items = db.query(FeedItem).filter(
                    FeedItem.id != exclude_feed_item_id,
                    FeedItem.embedding.isnot(None)
                ).all()
                # Create a fresh index
                if not FAISS_AVAILABLE:
                    logger.error("FAISS not available, cannot rebuild index")
                    return
                if hasattr(faiss, 'IndexFlatIP'):
                    self.index = faiss.IndexFlatIP(self.dimension)
                elif hasattr(faiss, 'IndexFlatL2'):
                    self.index = faiss.IndexFlatL2(self.dimension)
                else:
                    logger.error("FAISS has no suitable IndexFlat* implementation")
                    self.index = None
                self.id_mapping = {}
                
                for item in feed_items:
                    embedding = item.embedding
                    if isinstance(embedding, str):
                        try:
                            embedding = json.loads(embedding)
                        except:
                            logger.warning(f"Failed to parse embedding for FeedItem {item.id}")
                            continue
                    self.add_embedding(item.id, embedding, user_id=item.user_id)
                logger.info(f"Rebuilt vector index with {len(feed_items)} items")
            finally:
                db.close()
        except Exception as e:
            logger.error(f"Failed to rebuild index: {e}")
    
    def search_by_embedding(self, query_embedding: List[float], user_id: int,
                           top_k: int = 10, threshold: float = 0.0) -> List[Dict[str, Any]]:
        """Search using precomputed embedding"""
        if not FAISS_AVAILABLE:
            return []
        if not self._initialized:
            self._initialize_index()
        if not self.index or self.index.ntotal == 0 or not query_embedding:
            return []
        try:
            query_array = np.array(query_embedding, dtype=np.float32)
            query_array /= np.linalg.norm(query_array)
            
            scores, indices = self.index.search(query_array.reshape(1, -1), top_k)
            results = []
            db = get_db_session()
            try:
                for score, idx in zip(scores[0], indices[0]):
                    if idx == -1 or idx not in self.id_mapping:
                        continue
                    feed_item_id, stored_user_id = self.id_mapping[idx]
                    if stored_user_id != user_id:
                        continue
                    feed_item = db.query(FeedItem).filter(FeedItem.id == feed_item_id).first()
                    if feed_item and score >= threshold:
                        results.append({
                            "feed_item": feed_item,
                            "similarity_score": float(score),
                            "feed_item_id": feed_item_id
                        })
            finally:
                db.close()
            results.sort(key=lambda x: x["similarity_score"], reverse=True)
            return results
        except Exception as e:
            logger.error(f"Vector search by embedding failed: {e}")
            return []
    
    def search(self, query: str, user_id: int, top_k: int = 10, threshold: float = 0.0) -> List[Dict[str, Any]]:
        """Search using a text query"""
        embedding = self.embeddings_pipeline.embed_text(query)
        if not embedding:
            logger.error("Failed to generate query embedding")
            return []
        return self.search_by_embedding(embedding, user_id, top_k, threshold)
    
    def save_index(self):
        """Save FAISS index and ID mapping"""
        if not self.index or not FAISS_AVAILABLE:
            return
        try:
            faiss.write_index(self.index, f"{self.index_path}.faiss")
            with open(f"{self.index_path}.ids", "wb") as f:
                pickle.dump(self.id_mapping, f)
            logger.info(f"Saved vector index with {self.index.ntotal} vectors")
        except Exception as e:
            logger.error(f"Failed to save vector index: {e}")
    
    def rebuild_index(self, user_id: Optional[int] = None):
        """Rebuild entire index from database, optionally for one user"""
        if not FAISS_AVAILABLE:
            logger.error("FAISS not available, cannot rebuild index")
            return
        try:
            db = get_db_session()
            try:
                query = db.query(FeedItem).filter(FeedItem.embedding.isnot(None))
                if user_id:
                    query = query.filter(FeedItem.user_id == user_id)
                feed_items = query.all()
                
                self.index = faiss.IndexFlatIP(self.dimension)
                self.id_mapping = {}
                
                for item in feed_items:
                    embedding = item.embedding
                    if isinstance(embedding, str):
                        try:
                            embedding = json.loads(embedding)
                        except:
                            logger.warning(f"Failed to parse embedding for FeedItem {item.id}")
                            continue
                    self.add_embedding(item.id, embedding, user_id=item.user_id)
                logger.info(f"Rebuilt vector index with {len(feed_items)} items")
                self.save_index()
            finally:
                db.close()
        except Exception as e:
            logger.error(f"Failed to rebuild vector index: {e}")
    
    def get_stats(self) -> Dict[str, Any]:
        """Get statistics about the vector store"""
        if not self.index:
            return {"total_vectors": 0, "dimension": self.dimension}
        return {
            "total_vectors": self.index.ntotal,
            "dimension": self.dimension,
            "index_type": "FAISS IndexFlatIP",
            "available": FAISS_AVAILABLE
        }

# Global vector store instance
vector_store = VectorStore()

def get_vector_store() -> VectorStore:
    """Get the global vector store instance"""
    return vector_store


# Public API expected by other modules
def add_embedding(item_id: str, embedding: list[float]) -> bool:
    """
    Add an embedding to the global vector store.
    Accepts item_id as str for compatibility and stores it as int when possible.
    """
    try:
        feed_item_id = int(item_id)
    except (TypeError, ValueError):
        # Fallback: if cannot cast, store a sentinel mapping with None user
        # The underlying store expects int IDs; abort if not numeric
        logger.error(f"add_embedding: item_id must be numeric, got: {item_id}")
        return False

    ok = vector_store.add_embedding(feed_item_id, embedding, user_id=None)
    if ok:
        # Persist index opportunistically
        try:
            vector_store.save_index()
        except Exception as e:
            logger.warning(f"Failed to save vector index after add: {e}")
    return ok


