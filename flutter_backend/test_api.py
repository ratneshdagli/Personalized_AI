"""
Test script for the API endpoints
Run with: python test_api.py
"""

import requests
import json

BASE_URL = "http://localhost:8000/api"

def test_health():
    """Test health endpoint"""
    try:
        response = requests.get(f"{BASE_URL}/health")
        print(f"[OK] Health check: {response.status_code}")
        if response.status_code == 200:
            print(f"  Response: {response.json()}")
        return response.status_code == 200
    except Exception as e:
        print(f"[ERROR] Health check failed: {e}")
        return False

def test_feed():
    """Test feed endpoint"""
    try:
        response = requests.get(f"{BASE_URL}/feed")
        print(f"[OK] Feed endpoint: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            print(f"  Found {len(data)} feed items")
            if data:
                print(f"  First item: {data[0].get('title', 'No title')}")
        return response.status_code == 200
    except Exception as e:
        print(f"[ERROR] Feed test failed: {e}")
        return False

def test_extract_tasks():
    """Test task extraction endpoint"""
    test_text = """
    Dear students,
    
    This is a reminder that your research paper is due on December 20th, 2024. 
    Please submit it through the online portal before 11:59 PM.
    
    Also, remember to attend the final presentation on December 18th at 3 PM in room 101.
    
    If you have any questions, please contact me before the deadline.
    
    Best regards,
    Prof. Smith
    """
    
    try:
        response = requests.post(
            f"{BASE_URL}/extract_tasks",
            headers={"Content-Type": "application/json"},
            json={"text": test_text}
        )
        print(f"[OK] Task extraction: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            print(f"  Summary: {data.get('summary', 'No summary')}")
            tasks = data.get('tasks', [])
            print(f"  Tasks found: {len(tasks)}")
            for i, task in enumerate(tasks):
                print(f"    Task {i+1}: {task.get('verb', 'N/A')} - {task.get('text', 'N/A')} (due: {task.get('due_date', 'N/A')})")
        else:
            print(f"  Error: {response.text}")
        return response.status_code == 200
    except Exception as e:
        print(f"[ERROR] Task extraction test failed: {e}")
        return False

def main():
    print("=== Testing API Endpoints ===\n")
    
    # Test health endpoint
    health_ok = test_health()
    print()
    
    # Test feed endpoint
    feed_ok = test_feed()
    print()
    
    # Test task extraction
    tasks_ok = test_extract_tasks()
    print()
    
    # Summary
    print("=== TEST SUMMARY ===")
    if health_ok and feed_ok and tasks_ok:
        print("All tests passed successfully!")
    else:
        print("Some tests failed!")
        print(f"  Health: {'OK' if health_ok else 'FAILED'}")
        print(f"  Feed: {'OK' if feed_ok else 'FAILED'}")
        print(f"  Tasks: {'OK' if tasks_ok else 'FAILED'}")

if __name__ == "__main__":
    main()


