#!/usr/bin/env python3
"""
Run all tests for the Personalized AI Feed Backend
"""

import subprocess
import sys
import os

def run_command(command, description):
    """Run a command and return success status"""
    print(f"\n[TEST] {description}")
    print(f"Running: {command}")
    print("-" * 50)
    
    try:
        result = subprocess.run(command, shell=True, capture_output=True, text=True)
        if result.returncode == 0:
            print("[SUCCESS]")
            if result.stdout:
                print(result.stdout)
        else:
            print("[FAILED]")
            if result.stderr:
                print(result.stderr)
            if result.stdout:
                print(result.stdout)
        return result.returncode == 0
    except Exception as e:
        print(f"[ERROR] {e}")
        return False

def main():
    print("Personalized AI Feed Backend - Test Suite")
    print("=" * 60)
    
    # Change to backend directory
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    
    tests = [
        ("python test_llm_adapter.py", "LLM Adapter Tests"),
        ("python test_api.py", "API Endpoint Tests"),
        ("python test_storage.py", "Storage & Vector Search Tests"),
        ("python test_ranking.py", "Ranking & Feedback Tests"),
        ("python test_gmail.py", "Gmail Connector Tests"),
        ("python test_whatsapp.py", "WhatsApp Connector Tests"),
        ("python test_background_jobs.py", "Background Jobs Tests"),
    ]
    
    results = []
    for command, description in tests:
        success = run_command(command, description)
        results.append((description, success))
    
    # Summary
    print("\n" + "=" * 60)
    print("TEST SUMMARY")
    print("=" * 60)
    
    passed = 0
    for description, success in results:
        status = "[PASSED]" if success else "[FAILED]"
        print(f"{status} - {description}")
        if success:
            passed += 1
    
    print(f"\nResults: {passed}/{len(results)} tests passed")
    
    if passed == len(results):
        print("All tests passed! Backend is ready.")
        return 0
    else:
        print("Some tests failed. Check the output above.")
        return 1

if __name__ == "__main__":
    sys.exit(main())
