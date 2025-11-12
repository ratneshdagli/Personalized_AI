"""
Test Notification Workflow - WhatsApp to Recent Activity

This script tests the complete notification workflow to verify all fixes are working.
"""

import requests
import json
import time
from datetime import datetime

# Configuration
BASE_URL = "http://localhost:8000"
API_URL = f"{BASE_URL}/api"

def test_health_check():
    """Test if backend is running"""
    print("\n1. Testing backend health...")
    try:
        response = requests.get(f"{BASE_URL}/health", timeout=5)
        if response.status_code == 200:
            print("   ✅ Backend is healthy")
            return True
        else:
            print(f"   ❌ Backend returned status {response.status_code}")
            return False
    except Exception as e:
        print(f"   ❌ Backend connection failed: {e}")
        return False


def test_feed_endpoint():
    """Test if feed endpoint works without database errors"""
    print("\n2. Testing feed endpoint...")
    try:
        response = requests.get(f"{API_URL}/feed", timeout=10)
        if response.status_code == 200:
            data = response.json()
            print(f"   ✅ Feed loaded successfully ({len(data)} items)")
            
            # Check for WhatsApp items
            whatsapp_items = [item for item in data if 'whatsapp' in item.get('source', '').lower()]
            print(f"   📱 Found {len(whatsapp_items)} WhatsApp items")
            
            if whatsapp_items:
                print("\n   Sample WhatsApp item:")
                sample = whatsapp_items[0]
                print(f"      - Title: {sample.get('title')}")
                print(f"      - Summary: {sample.get('summary', '')[:80]}...")
                print(f"      - Source: {sample.get('source')}")
                print(f"      - Priority: {sample.get('priority')}")
            
            return True
        else:
            print(f"   ❌ Feed endpoint returned status {response.status_code}")
            print(f"      Response: {response.text[:200]}")
            return False
    except Exception as e:
        print(f"   ❌ Feed endpoint failed: {e}")
        return False


def test_whatsapp_ingestion():
    """Test WhatsApp message ingestion"""
    print("\n3. Testing WhatsApp message ingestion...")
    
    test_message = {
        "sender": "Test Automation",
        "message": "Important meeting scheduled for tomorrow at 2 PM. Don't forget to submit the quarterly report by Friday.",
        "timestamp": int(time.time() * 1000),
        "user_id": "1"
    }
    
    try:
        response = requests.post(
            f"{API_URL}/whatsapp/add",
            json=test_message,
            headers={"Content-Type": "application/json"},
            timeout=15
        )
        
        if response.status_code == 200:
            print("   ✅ WhatsApp message sent successfully")
            print(f"   📨 Message: '{test_message['message'][:60]}...'")
            
            # Wait for background processing
            print("   ⏳ Waiting for background processing (3 seconds)...")
            time.sleep(3)
            
            return True
        else:
            print(f"   ❌ WhatsApp ingestion failed with status {response.status_code}")
            print(f"      Response: {response.text[:200]}")
            return False
    except Exception as e:
        print(f"   ❌ WhatsApp ingestion error: {e}")
        return False


def test_feed_after_ingestion():
    """Test if the ingested message appears in feed"""
    print("\n4. Verifying message appears in feed...")
    try:
        response = requests.get(f"{API_URL}/feed", timeout=10)
        if response.status_code == 200:
            data = response.json()
            
            # Look for test message
            test_items = [
                item for item in data 
                if 'Test Automation' in item.get('title', '') or 
                   'Test Automation' in item.get('summary', '')
            ]
            
            if test_items:
                print(f"   ✅ Test message found in feed!")
                print(f"\n   Message details:")
                item = test_items[0]
                print(f"      - ID: {item.get('id')}")
                print(f"      - Title: {item.get('title')}")
                print(f"      - Summary: {item.get('summary', '')[:80]}...")
                print(f"      - Source: {item.get('source')}")
                print(f"      - Priority: {item.get('priority')}")
                print(f"      - Date: {item.get('date')}")
                return True
            else:
                print("   ⚠️  Test message not found in feed (may need more time)")
                return False
        else:
            print(f"   ❌ Feed check failed with status {response.status_code}")
            return False
    except Exception as e:
        print(f"   ❌ Feed verification error: {e}")
        return False


def test_todos_endpoint():
    """Test if todos endpoint works"""
    print("\n5. Testing todos endpoint...")
    try:
        response = requests.get(f"{API_URL}/todos?user_id=1", timeout=10)
        if response.status_code == 200:
            data = response.json()
            todos = data.get('todos', [])
            print(f"   ✅ Todos loaded successfully ({len(todos)} items)")
            
            if todos:
                print("\n   Sample todo:")
                sample = todos[0]
                print(f"      - Title: {sample.get('title')}")
                print(f"      - Priority: {sample.get('priority')}")
                print(f"      - Due Date: {sample.get('due_date')}")
                print(f"      - Source: {sample.get('source')}")
            
            return True
        else:
            print(f"   ❌ Todos endpoint returned status {response.status_code}")
            return False
    except Exception as e:
        print(f"   ❌ Todos endpoint failed: {e}")
        return False


def test_events_endpoint():
    """Test if events endpoint works"""
    print("\n6. Testing events endpoint...")
    try:
        response = requests.get(f"{API_URL}/events?user_id=1", timeout=10)
        if response.status_code == 200:
            data = response.json()
            events = data.get('events', [])
            print(f"   ✅ Events loaded successfully ({len(events)} items)")
            
            if events:
                print("\n   Sample event:")
                sample = events[0]
                print(f"      - Title: {sample.get('title')}")
                print(f"      - Start Time: {sample.get('start_time')}")
                print(f"      - Duration: {sample.get('duration_minutes')} minutes")
                print(f"      - Source: {sample.get('source')}")
            
            return True
        else:
            print(f"   ❌ Events endpoint returned status {response.status_code}")
            return False
    except Exception as e:
        print(f"   ❌ Events endpoint failed: {e}")
        return False


def main():
    """Run all tests"""
    print("=" * 60)
    print("  NOTIFICATION WORKFLOW TEST")
    print("=" * 60)
    print(f"  Testing against: {BASE_URL}")
    print(f"  Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 60)
    
    results = {}
    
    # Run tests
    results['health'] = test_health_check()
    
    if not results['health']:
        print("\n❌ Backend is not running. Please start it first:")
        print("   cd flutter_backend")
        print("   uvicorn main:app --host 0.0.0.0 --port 8000 --reload")
        return
    
    results['feed'] = test_feed_endpoint()
    results['whatsapp'] = test_whatsapp_ingestion()
    results['feed_after'] = test_feed_after_ingestion()
    results['todos'] = test_todos_endpoint()
    results['events'] = test_events_endpoint()
    
    # Summary
    print("\n" + "=" * 60)
    print("  TEST SUMMARY")
    print("=" * 60)
    
    passed = sum(1 for v in results.values() if v)
    total = len(results)
    
    for test_name, result in results.items():
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"  {status}  {test_name.replace('_', ' ').title()}")
    
    print("=" * 60)
    print(f"  Result: {passed}/{total} tests passed")
    
    if passed == total:
        print("  🎉 All tests passed! Workflow is working correctly.")
    elif passed >= total - 1:
        print("  ⚠️  Most tests passed. Check warnings above.")
    else:
        print("  ❌ Some tests failed. Check errors above.")
    
    print("=" * 60)


if __name__ == "__main__":
    main()
