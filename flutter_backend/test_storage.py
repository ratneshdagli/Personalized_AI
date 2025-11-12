"""
Tests for storage and vector search functionality
Run with: python test_storage.py
"""

import os
import sys
import json
import tempfile
import shutil
from datetime import datetime

# Add the backend directory to Python path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from storage.db import init_db, get_db_session, check_db_health
from storage.models import User, FeedItem, SourceType, PriorityLevel
from storage.vector_store import VectorStore
from nlp.embeddings import EmbeddingsPipeline

def test_database_connection():
    """Test database connection and initialization"""
    print("[TEST] Testing database connection...")
    
    try:
        # Test health check
        is_healthy = check_db_health()
        print(f"  Database health: {'[SUCCESS] OK' if is_healthy else '[FAILED] FAILED'}")
        
        if is_healthy:
            # Test session creation
            db = get_db_session()
            try:
                # Test basic query
                user_count = db.query(User).count()
                print(f"  Users in database: {user_count}")
                print("[SUCCESS] Database connection test passed")
                return True
            finally:
                db.close()
        else:
            print("[FAILED] Database connection test failed")
            return False
            
    except Exception as e:
        print(f"[FAILED] Database test failed: {e}")
        return False

def test_embeddings_pipeline():
    """Test embeddings pipeline"""
    print("\n[TEST] Testing embeddings pipeline...")
    
    try:
        pipeline = EmbeddingsPipeline()
        
        # Test single text embedding
        test_text = "This is a test message about assignment submission"
        embedding = pipeline.embed_text(test_text)
        
        if embedding:
            print(f"  [SUCCESS] Single embedding generated: {len(embedding)} dimensions")
            print(f"  Embedding preview: {embedding[:5]}...")
        else:
            print("  [FAILED] Failed to generate single embedding")
            return False
        
        # Test batch embedding
        test_texts = [
            "Submit assignment by Friday",
            "Meeting tomorrow at 2 PM",
            "Complete project report"
        ]
        embeddings = pipeline.embed_batch(test_texts)
        
        if embeddings and all(emb is not None for emb in embeddings):
            print(f"  [SUCCESS] Batch embeddings generated: {len(embeddings)} items")
        else:
            print("  [FAILED] Failed to generate batch embeddings")
            return False
        
        # Test similarity calculation
        sim = pipeline.similarity(embeddings[0], embeddings[1])
        print(f"  [SUCCESS] Similarity calculation: {sim:.3f}")
        
        print("[SUCCESS] Embeddings pipeline test passed")
        return True
        
    except Exception as e:
        print(f"[FAILED] Embeddings pipeline test failed: {e}")
        return False

def test_vector_store():
    """Test vector store functionality"""
    print("\n[TEST] Testing vector store...")
    
    try:
        # Create temporary directory for test index
        temp_dir = tempfile.mkdtemp()
        index_path = os.path.join(temp_dir, "test_index")
        
        try:
            # Initialize vector store
            vector_store = VectorStore(index_path=index_path)
            
            # Test adding embeddings
            test_embeddings = [
                [0.1, 0.2, 0.3, 0.4] * 96,  # 384 dimensions
                [0.2, 0.3, 0.4, 0.5] * 96,
                [0.3, 0.4, 0.5, 0.6] * 96
            ]
            
            dummy_user_id = 1  # or any valid test user ID

            for i, embedding in enumerate(test_embeddings):
                success = vector_store.add_embedding(i + 1, embedding, user_id=dummy_user_id)
                if not success:
                    print(f"  [FAILED] Failed to add embedding {i + 1}")
                    return False

            
            print(f"  [SUCCESS] Added {len(test_embeddings)} embeddings")
            
            # Test search
            query_embedding = [0.15, 0.25, 0.35, 0.45] * 96
            results = vector_store.search_by_embedding(
                query_embedding=query_embedding,
                user_id=dummy_user_id,
                top_k=2
            )
            
            if results:
                print(f"  [SUCCESS] Search returned {len(results)} results")
                for result in results:
                    print(f"    - ID: {result['feed_item_id']}, Score: {result['similarity_score']:.3f}")
            else:
                print("  [FAILED] Search returned no results")
                return False
            
            # Test stats
            stats = vector_store.get_stats()
            print(f"  [SUCCESS] Vector store stats: {stats}")
            
            print("[SUCCESS] Vector store test passed")
            return True
            
        finally:
            # Clean up temporary directory
            shutil.rmtree(temp_dir)
            
    except Exception as e:
        print(f"[FAILED] Vector store test failed: {e}")
        return False

def test_feed_item_creation():
    """Test creating feed items with embeddings"""
    print("\n[TEST] Testing feed item creation...")
    
    try:
        db = get_db_session()
        try:
            # Get or create test user
            user = db.query(User).filter(User.email == "test@example.com").first()
            if not user:
                user = User(
                    email="test@example.com",
                    name="Test User",
                    is_active=True
                )
                db.add(user)
                db.commit()
                db.refresh(user)
            
            # Create test feed item
            feed_item = FeedItem(
                user_id=user.id,
                source=SourceType.GMAIL,
                origin_id="test_email_123",
                title="Test Assignment Due Next Week",
                summary="Assignment submission reminder",
                text="Please submit your final project by next Friday. The deadline is strict.",
                date=datetime.now(),
                priority=PriorityLevel.HIGH,
                relevance_score=0.8,
                entities=["assignment", "deadline", "project"],
                has_tasks=True,
                extracted_tasks=[
                    {
                        "verb": "submit",
                        "due_date": "2025-01-24",
                        "text": "final project by next Friday"
                    }
                ]
            )
            
            db.add(feed_item)
            db.commit()
            db.refresh(feed_item)
            
            print(f"  [SUCCESS] Created feed item with ID: {feed_item.id}")
            
            # Test generating and storing embedding
            pipeline = EmbeddingsPipeline()
            embedding = pipeline.embed_text(feed_item.title + " " + (feed_item.summary or ""))
            
            if embedding:
                feed_item.embedding = json.dumps(embedding)
                db.commit()
                print(f"  [SUCCESS] Added embedding to feed item")
                
                # Test vector store integration
                vector_store = VectorStore()
                # Fixed: pass user_id
                success = vector_store.add_embedding(feed_item.id, embedding, user_id=feed_item.user_id)

                if success:
                    print(f"  [SUCCESS] Added feed item to vector store")
                else:
                    print(f"  [FAILED] Failed to add to vector store")
                    return False
            else:
                print(f"  [FAILED] Failed to generate embedding")
                return False
            
            print("[SUCCESS] Feed item creation test passed")
            return True
            
        finally:
            db.close()
            
    except Exception as e:
        print(f"[FAILED] Feed item creation test failed: {e}")
        return False

def test_search_integration():
    """Test end-to-end search functionality"""
    print("\n[TEST] Testing search integration...")
    
    try:
        # This would test the actual search endpoint
        # For now, we'll test the components
        
        db = get_db_session()
        try:
            # Get test user
            user = db.query(User).filter(User.email == "test@example.com").first()
            if not user:
                print("  [FAILED] Test user not found")
                return False
            
            # Get feed items with embeddings
            feed_items = db.query(FeedItem).filter(
                FeedItem.user_id == user.id,
                FeedItem.embedding.isnot(None)
            ).all()
            
            if not feed_items:
                print("  [FAILED] No feed items with embeddings found")
                return False
            
            print(f"  [SUCCESS] Found {len(feed_items)} feed items with embeddings")
            
            # Test vector search
            vector_store = VectorStore()
            pipeline = EmbeddingsPipeline()
            
            query = "assignment submission deadline"
            query_embedding = pipeline.embed_text(query)
            
            if query_embedding:
                results = vector_store.search_by_embedding(
                    query_embedding=query_embedding,
                    user_id=user.id,
                    top_k=5
                )
                
                print(f"  [SUCCESS] Search for '{query}' returned {len(results)} results")
                for result in results:
                    print(f"    - {result['feed_item'].title} (score: {result['similarity_score']:.3f})")
            else:
                print("  [FAILED] Failed to generate query embedding")
                return False
            
            print("[SUCCESS] Search integration test passed")
            return True
            
        finally:
            db.close()
            
    except Exception as e:
        print(f"[FAILED] Search integration test failed: {e}")
        return False

def run_all_tests():
    """Run all storage and vector search tests"""
    print("[TEST] Running Storage & Vector Search Tests\n")
    
    # Initialize database and create all tables
    print("[INIT] Initializing database...")
    init_db()
    
    tests = [
        test_database_connection,
        test_embeddings_pipeline,
        test_vector_store,
        test_feed_item_creation,
        test_search_integration
    ]
    
    passed = 0
    for test in tests:
        try:
            if test():
                passed += 1
        except Exception as e:
            print(f"[FAILED] Test {test.__name__} failed with exception: {e}")
    
    print(f"\n[SUMMARY] Test Results: {passed}/{len(tests)} tests passed")
    
    if passed == len(tests):
        print("[SUCCESS] All storage tests passed!")
        return True
    else:
        print("[WARNING]  Some storage tests failed!")
        return False


if __name__ == "__main__":
    success = run_all_tests()
    sys.exit(0 if success else 1)


