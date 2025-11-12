"""
Tests for ranking service and feedback functionality
Run with: python test_ranking.py
"""

import os
import sys
import json
from datetime import datetime, timedelta

# Add the backend directory to Python path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from storage.db import get_db_session, init_db
from storage.models import User, FeedItem, UserProfile, Feedback, SourceType, PriorityLevel
from services.ranking import get_ranking_service

def test_ranking_service():
    """Test ranking service functionality"""
    print("[TEST] Testing ranking service...")
    
    try:
        ranking_service = get_ranking_service()
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
            
            # Create test feed items
            test_items = [
                FeedItem(
                    user_id=user.id,
                    source=SourceType.GMAIL,
                    origin_id="test_email_1",
                    title="Urgent: Assignment Due Tomorrow",
                    summary="Final project submission deadline",
                    text="Please submit your final project by tomorrow. This is urgent!",
                    date=datetime.now(),
                    priority=PriorityLevel.URGENT,
                    relevance_score=0.8,
                    entities=["assignment", "deadline", "urgent"],
                    has_tasks=True,
                    extracted_tasks=[{
                        "verb": "submit",
                        "due_date": (datetime.now() + timedelta(days=1)).strftime("%Y-%m-%d"),
                        "text": "final project by tomorrow"
                    }],
                    metadata={"sender": "professor@university.edu", "sender_email": "professor@university.edu"}
                ),
                FeedItem(
                    user_id=user.id,
                    source=SourceType.REDDIT,
                    origin_id="reddit_post_1",
                    title="Interesting Tech News",
                    summary="Latest developments in AI",
                    text="Check out this cool new AI technology...",
                    date=datetime.now() - timedelta(hours=2),
                    priority=PriorityLevel.MEDIUM,
                    relevance_score=0.6,
                    entities=["AI", "technology"],
                    has_tasks=False,
                    metadata={"sender": "reddit_user", "subreddit": "technology"}
                ),
                FeedItem(
                    user_id=user.id,
                    source=SourceType.NEWS,
                    origin_id="news_1",
                    title="Meeting Scheduled for Next Week",
                    summary="Team meeting reminder",
                    text="Don't forget about the team meeting next Tuesday at 2 PM.",
                    date=datetime.now() - timedelta(hours=1),
                    priority=PriorityLevel.MEDIUM,
                    relevance_score=0.5,
                    entities=["meeting", "team"],
                    has_tasks=True,
                    extracted_tasks=[{
                        "verb": "attend",
                        "due_date": (datetime.now() + timedelta(days=7)).strftime("%Y-%m-%d"),
                        "text": "team meeting next Tuesday at 2 PM"
                    }],
                    metadata={"sender": "manager@company.com", "sender_email": "manager@company.com"}
                )
            ]
            
            for item in test_items:
                db.add(item)
            db.commit()
            
            print(f"  [SUCCESS] Created {len(test_items)} test feed items")
            
            # Test ranking without user profile
            ranked_items = ranking_service.rank_feed_items(test_items, user.id, db)
            
            if ranked_items:
                print(f"  [SUCCESS] Ranked {len(ranked_items)} items")
                for i, (item, score, breakdown) in enumerate(ranked_items[:3]):
                    print(f"    {i+1}. {item.title} (score: {score:.3f})")
                    print(f"       Breakdown: {breakdown}")
            else:
                print("  [FAILED] No ranked items returned")
                return False
            
            print("[SUCCESS] Ranking service test passed")
            return True
            
        finally:
            db.close()
            
    except Exception as e:
        print(f"[FAILED] Ranking service test failed: {e}")
        return False

def test_feedback_learning():
    """Test feedback learning and profile updates"""
    print("\n[TEST] Testing feedback learning...")
    
    try:
        ranking_service = get_ranking_service()
        db = get_db_session()
        
        try:
            # Get test user
            user = db.query(User).filter(User.email == "test@example.com").first()
            if not user:
                print("  [FAILED] Test user not found")
                return False
            
            # Get a test feed item
            feed_item = db.query(FeedItem).filter(FeedItem.user_id == user.id).first()
            if not feed_item:
                print("  [FAILED] No test feed items found")
                return False
            
            # Test positive feedback
            success = ranking_service.update_user_profile_from_feedback(
                user_id=user.id,
                feed_item=feed_item,
                feedback_type="like",
                feedback_value=1.0,
                db=db
            )
            
            if success:
                print("  [SUCCESS] Positive feedback processed successfully")
            else:
                print("  [FAILED] Failed to process positive feedback")
                return False
            
            # Check if user profile was updated
            user_profile = db.query(UserProfile).filter(UserProfile.user_id == user.id).first()
            if user_profile and user_profile.feedback_history:
                print(f"  [SUCCESS] User profile updated with {len(user_profile.feedback_history)} feedback items")
            else:
                print("  [FAILED] User profile not updated")
                return False
            
            # Test negative feedback
            success = ranking_service.update_user_profile_from_feedback(
                user_id=user.id,
                feed_item=feed_item,
                feedback_type="dislike",
                feedback_value=0.0,
                db=db
            )
            
            if success:
                print("  [SUCCESS] Negative feedback processed successfully")
            else:
                print("  [FAILED] Failed to process negative feedback")
                return False
            
            print("[SUCCESS] Feedback learning test passed")
            return True
            
        finally:
            db.close()
            
    except Exception as e:
        print(f"[FAILED] Feedback learning test failed: {e}")
        return False

def test_user_profile_creation():
    """Test user profile creation and management"""
    print("\n[TEST] Testing user profile creation...")
    
    try:
        db = get_db_session()
        
        try:
            # Get test user
            user = db.query(User).filter(User.email == "test@example.com").first()
            if not user:
                print("  [FAILED] Test user not found")
                return False
            
            # Create user profile with some data
            user_profile = UserProfile(
                user_id=user.id,
                important_keywords=["assignment", "deadline", "project"],
                important_contacts=["professor@university.edu", "manager@company.com"],
                preferred_sources=["gmail", "reddit"],
                local_only_mode=False,
                allow_llm_processing=True,
                ranking_weights={
                    "semantic_relevance": 0.5,
                    "sender_importance": 0.3,
                    "urgency": 0.2
                }
            )
            
            db.add(user_profile)
            db.commit()
            
            print("  [SUCCESS] User profile created successfully")
            
            # Test profile retrieval
            retrieved_profile = db.query(UserProfile).filter(UserProfile.user_id == user.id).first()
            if retrieved_profile:
                print(f"  [SUCCESS] Profile retrieved: {len(retrieved_profile.important_keywords)} keywords, {len(retrieved_profile.important_contacts)} contacts")
            else:
                print("  [FAILED] Failed to retrieve user profile")
                return False
            
            print("[SUCCESS] User profile creation test passed")
            return True
            
        finally:
            db.close()
            
    except Exception as e:
        print(f"[FAILED] User profile creation test failed: {e}")
        return False

def test_feedback_endpoints():
    """Test feedback API endpoints (simulation)"""
    print("\n[TEST] Testing feedback endpoints simulation...")
    
    try:
        # This would normally test the actual API endpoints
        # For now, we'll simulate the feedback flow
        
        db = get_db_session()
        
        try:
            # Get test user and feed item
            user = db.query(User).filter(User.email == "test@example.com").first()
            feed_item = db.query(FeedItem).filter(FeedItem.user_id == user.id).first()
            
            if not user or not feed_item:
                print("  [FAILED] Test data not found")
                return False
            
            # Simulate feedback submission
            feedback = Feedback(
                user_id=user.id,
                feed_item_id=feed_item.id,
                feedback_type="like",
                feedback_value=1.0,
                context={"source": "test"}
            )
            
            db.add(feedback)
            db.commit()
            
            print("  [SUCCESS] Feedback record created successfully")
            
            # Test feedback retrieval
            feedback_count = db.query(Feedback).filter(Feedback.user_id == user.id).count()
            print(f"  [SUCCESS] Total feedback records: {feedback_count}")
            
            print("[SUCCESS] Feedback endpoints simulation test passed")
            return True
            
        finally:
            db.close()
            
    except Exception as e:
        print(f"[FAILED] Feedback endpoints simulation test failed: {e}")
        return False

def test_ranking_with_personalization():
    """Test ranking with user personalization"""
    print("\n[TEST] Testing ranking with personalization...")
    
    try:
        ranking_service = get_ranking_service()
        db = get_db_session()
        
        try:
            # Get test user
            user = db.query(User).filter(User.email == "test@example.com").first()
            if not user:
                print("  [FAILED] Test user not found")
                return False
            
            # Get user profile with personalization data
            user_profile = db.query(UserProfile).filter(UserProfile.user_id == user.id).first()
            if not user_profile:
                print("  [FAILED] User profile not found")
                return False
            
            # Get all feed items for this user
            feed_items = db.query(FeedItem).filter(FeedItem.user_id == user.id).all()
            
            if not feed_items:
                print("  [FAILED] No feed items found")
                return False
            
            # Test ranking with personalization
            ranked_items = ranking_service.rank_feed_items(feed_items, user.id, db)
            
            if ranked_items:
                print(f"  [SUCCESS] Ranked {len(ranked_items)} items with personalization")
                
                # Show top 3 items with detailed breakdown
                for i, (item, score, breakdown) in enumerate(ranked_items[:3]):
                    print(f"    {i+1}. {item.title}")
                    print(f"       Final Score: {score:.3f}")
                    print(f"       Breakdown: {json.dumps(breakdown, indent=6)}")
                    print()
            else:
                print("  [FAILED] No ranked items returned")
                return False
            
            print("[SUCCESS] Ranking with personalization test passed")
            return True
            
        finally:
            db.close()
            
    except Exception as e:
        print(f"[FAILED] Ranking with personalization test failed: {e}")
        return False

def run_all_tests():
    """Run all ranking and feedback tests"""
    print("[TEST] Running Ranking & Feedback Tests\n")
    
    tests = [
        test_ranking_service,
        test_feedback_learning,
        test_user_profile_creation,
        test_feedback_endpoints,
        test_ranking_with_personalization
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
        print("[SUCCESS] All ranking tests passed!")
        return True
    else:
        print("[WARNING]  Some ranking tests failed!")
        return False

if __name__ == "__main__":
    success = run_all_tests()
    sys.exit(0 if success else 1)


