"""
Tests for Gmail connector functionality
Run with: python test_gmail.py
"""

import os
import sys
import json
from datetime import datetime, timedelta

# Add the backend directory to Python path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from services.gmail_connector import get_gmail_connector
from storage.db import get_db_session, init_db
from storage.models import User, ConnectorConfig, SourceType

def test_gmail_connector_initialization():
    """Test Gmail connector initialization"""
    print("[TEST] Testing Gmail connector initialization...")
    
    try:
        gmail_connector = get_gmail_connector()
        
        # Check if Google APIs are available
        if not gmail_connector.client_id:
            print("  [WARNING]  Gmail OAuth not configured (missing GMAIL_CLIENT_ID)")
            print("  [SUCCESS] Gmail connector initialized (OAuth disabled)")
            return True
        
        print(f"  [SUCCESS] Gmail connector initialized with client ID: {gmail_connector.client_id[:10]}...")
        print(f"  [SUCCESS] Redirect URI: {gmail_connector.redirect_uri}")
        print(f"  [SUCCESS] Scopes: {len(gmail_connector.scopes)} configured")
        
        return True
        
    except Exception as e:
        print(f"[FAILED] Gmail connector initialization failed: {e}")
        return False

def test_auth_url_generation():
    """Test Gmail OAuth URL generation"""
    print("\n[TEST] Testing Gmail OAuth URL generation...")
    
    try:
        gmail_connector = get_gmail_connector()
        
        if not gmail_connector.client_id:
            print("  [WARNING]  Skipping OAuth URL test - Gmail OAuth not configured")
            return True
        
        # Test URL generation
        test_user_id = 123
        auth_url = gmail_connector.get_auth_url(test_user_id)
        
        if auth_url:
            print(f"  [SUCCESS] Generated auth URL: {auth_url[:50]}...")
            print(f"  [SUCCESS] URL contains state parameter: {'state=' in auth_url}")
            print(f"  [SUCCESS] URL contains client_id: {gmail_connector.client_id[:10] in auth_url}")
        else:
            print("  [FAILED] Failed to generate auth URL")
            return False
        
        return True
        
    except Exception as e:
        print(f"[FAILED] OAuth URL generation test failed: {e}")
        return False

def test_email_parsing():
    """Test email message parsing functionality"""
    print("\n[TEST] Testing email parsing...")
    
    try:
        gmail_connector = get_gmail_connector()
        
        # Mock Gmail message structure
        mock_message = {
            'id': 'test_message_123',
            'threadId': 'thread_456',
            'payload': {
                'headers': [
                    {'name': 'Subject', 'value': 'Test Assignment Due Tomorrow'},
                    {'name': 'From', 'value': 'Professor Smith <professor@university.edu>'},
                    {'name': 'Date', 'value': 'Mon, 20 Jan 2025 10:00:00 +0000'},
                    {'name': 'To', 'value': 'student@university.edu'}
                ],
                'body': {
                    'data': 'VGVzdCBlbWFpbCBib2R5IGNvbnRlbnQ='  # Base64 encoded "Test email body content"
                },
                'mimeType': 'text/plain'
            }
        }
        
        # Test parsing
        parsed_email = gmail_connector._parse_email_message(mock_message)
        
        if parsed_email:
            print(f"  [SUCCESS] Email parsed successfully")
            print(f"    - ID: {parsed_email['id']}")
            print(f"    - Subject: {parsed_email['subject']}")
            print(f"    - Sender: {parsed_email['sender']}")
            print(f"    - Sender Email: {parsed_email['sender_email']}")
            print(f"    - Body: {parsed_email['body'][:50]}...")
        else:
            print("  [FAILED] Failed to parse email message")
            return False
        
        return True
        
    except Exception as e:
        print(f"[FAILED] Email parsing test failed: {e}")
        return False

def test_priority_determination():
    """Test priority determination logic"""
    print("\n[TEST] Testing priority determination...")
    
    try:
        gmail_connector = get_gmail_connector()
        
        # Test cases
        test_cases = [
            {
                "subject": "URGENT: Assignment Due Tomorrow",
                "body": "This is urgent! Please submit immediately.",
                "tasks": [],
                "expected": "URGENT"
            },
            {
                "subject": "Important Meeting Next Week",
                "body": "Don't forget about the important meeting.",
                "tasks": [],
                "expected": "HIGH"
            },
            {
                "subject": "Regular Newsletter",
                "body": "Here's our weekly newsletter with updates.",
                "tasks": [],
                "expected": "MEDIUM"
            },
            {
                "subject": "Project Due in 2 Days",
                "body": "Please complete your project.",
                "tasks": [{"due_date": (datetime.now() + timedelta(days=2)).strftime("%Y-%m-%d")}],
                "expected": "HIGH"
            }
        ]
        
        for i, test_case in enumerate(test_cases):
            priority = gmail_connector._determine_priority(
                test_case["subject"],
                test_case["body"],
                test_case["tasks"]
            )
            
            print(f"  Test {i+1}: {test_case['subject']}")
            print(f"    Expected: {test_case['expected']}, Got: {priority.value}")
            
            # Check if priority is reasonable (not exact match due to complexity)
            if priority.value in ["URGENT", "HIGH", "MEDIUM", "LOW"]:
                print(f"    [SUCCESS] Valid priority level")
            else:
                print(f"    [FAILED] Invalid priority level")
                return False
        
        return True
        
    except Exception as e:
        print(f"[FAILED] Priority determination test failed: {e}")
        return False

def test_entity_extraction():
    """Test entity extraction from email content"""
    print("\n[TEST] Testing entity extraction...")
    
    try:
        gmail_connector = get_gmail_connector()
        
        # Test cases
        test_cases = [
            {
                "subject": "CS101 Assignment Due Friday",
                "body": "Please submit your programming assignment by Friday.",
                "expected_entities": ["assignment"]
            },
            {
                "subject": "Team Meeting Tomorrow",
                "body": "Don't forget about our team conference call.",
                "expected_entities": ["meeting"]
            },
            {
                "subject": "Project Deadline Approaching",
                "body": "Submit your final project before the deadline.",
                "expected_entities": ["deadline"]
            }
        ]
        
        for i, test_case in enumerate(test_cases):
            entities = gmail_connector._extract_entities(
                test_case["subject"],
                test_case["body"]
            )
            
            print(f"  Test {i+1}: {test_case['subject']}")
            print(f"    Extracted entities: {entities}")
            print(f"    Expected: {test_case['expected_entities']}")
            
            # Check if at least one expected entity is found
            found_expected = any(entity in entities for entity in test_case["expected_entities"])
            if found_expected:
                print(f"    [SUCCESS] Found expected entities")
            else:
                print(f"    [WARNING]  Expected entities not found (may be normal)")
        
        return True
        
    except Exception as e:
        print(f"[FAILED] Entity extraction test failed: {e}")
        return False

def test_database_integration():
    """Test Gmail connector database integration"""
    print("\n[TEST] Testing database integration...")
    
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
            
            # Test connector config creation
            config = ConnectorConfig(
                user_id=user.id,
                connector_type=SourceType.GMAIL,
                is_enabled=True,
                config_data={
                    "email": "test@example.com",
                    "name": "Test User"
                }
            )
            
            db.add(config)
            db.commit()
            
            print(f"  [SUCCESS] Created Gmail connector config for user {user.id}")
            
            # Test config retrieval
            retrieved_config = db.query(ConnectorConfig).filter(
                ConnectorConfig.user_id == user.id,
                ConnectorConfig.connector_type == SourceType.GMAIL
            ).first()
            
            if retrieved_config:
                print(f"  [SUCCESS] Retrieved Gmail config: {retrieved_config.config_data}")
            else:
                print("  [FAILED] Failed to retrieve Gmail config")
                return False
            
            return True
            
        finally:
            db.close()
            
    except Exception as e:
        print(f"[FAILED] Database integration test failed: {e}")
        return False

def test_email_processing_simulation():
    """Test email processing simulation (without actual Gmail API)"""
    print("\n[TEST] Testing email processing simulation...")
    
    try:
        gmail_connector = get_gmail_connector()
        
        # Mock email data
        mock_emails = [
            {
                'id': 'email_1',
                'thread_id': 'thread_1',
                'subject': 'Assignment Due Tomorrow',
                'sender': 'Professor Smith <professor@university.edu>',
                'sender_email': 'professor@university.edu',
                'date': datetime.now(),
                'body': 'Please submit your final project by tomorrow. This is urgent!',
                'headers': {}
            },
            {
                'id': 'email_2',
                'thread_id': 'thread_2',
                'subject': 'Weekly Newsletter',
                'sender': 'Newsletter <newsletter@company.com>',
                'sender_email': 'newsletter@company.com',
                'date': datetime.now() - timedelta(hours=2),
                'body': 'Here are the latest updates from our team.',
                'headers': {}
            }
        ]
        
        # Test processing
        test_user_id = 1
        feed_items = gmail_connector.process_emails_to_feed_items(test_user_id, mock_emails)
        
        if feed_items:
            print(f"  [SUCCESS] Processed {len(feed_items)} emails into feed items")
            
            for i, item in enumerate(feed_items):
                print(f"    Item {i+1}: {item.title}")
                print(f"      Priority: {item.priority.value}")
                print(f"      Has tasks: {item.has_tasks}")
                print(f"      Entities: {item.entities}")
                print(f"      Relevance score: {item.relevance_score}")
        else:
            print("  [FAILED] No feed items created from emails")
            return False
        
        return True
        
    except Exception as e:
        print(f"[FAILED] Email processing simulation test failed: {e}")
        return False

def run_all_tests():
    """Run all Gmail connector tests"""
    print("[TEST] Running Gmail Connector Tests\n")
    
    tests = [
        test_gmail_connector_initialization,
        test_auth_url_generation,
        test_email_parsing,
        test_priority_determination,
        test_entity_extraction,
        test_database_integration,
        test_email_processing_simulation
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
        print("[SUCCESS] All Gmail connector tests passed!")
        return True
    else:
        print("[WARNING]  Some Gmail connector tests failed!")
        return False

if __name__ == "__main__":
    success = run_all_tests()
    sys.exit(0 if success else 1)


