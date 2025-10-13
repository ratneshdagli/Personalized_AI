"""
Tests for LLM Adapter functionality
Run with: python test_llm_adapter.py
"""

import os
import sys
import json
from datetime import datetime

# Add the backend directory to Python path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from ml.llm_adapter import LLMAdapter

def test_simple_summary():
    """Test simple summary fallback"""
    adapter = LLMAdapter()
    
    text = "This is a long text that should be summarized. It contains multiple sentences. The summary should be concise and capture the main point."
    
    summary = adapter._simple_summary(text, 50)
    print(f"✓ Simple summary test: {summary}")
    assert len(summary) <= 50
    assert "..." in summary or len(summary) < 50

def test_rule_based_task_extraction():
    """Test rule-based task extraction"""
    adapter = LLMAdapter()
    
    test_text = """
    Hi everyone! Please submit your final project by October 15th, 2024. 
    Also, don't forget to attend the team meeting tomorrow at 2 PM.
    You need to complete the homework assignment before next week.
    """
    
    result = adapter._extract_tasks_rules(test_text)
    
    print(f"✓ Rule-based extraction test:")
    print(f"  Summary: {result['summary']}")
    print(f"  Tasks found: {len(result['tasks'])}")
    
    for i, task in enumerate(result['tasks']):
        print(f"    Task {i+1}: {task['verb']} - {task['text']} (due: {task['due_date']})")
    
    assert "summary" in result
    assert "tasks" in result
    assert len(result['tasks']) > 0

def test_date_parsing():
    """Test date parsing functionality"""
    adapter = LLMAdapter()
    
    test_dates = [
        "10/15/2024",
        "15/10/24", 
        "2024-10-15",
        "tomorrow",
        "today"
    ]
    
    print("✓ Date parsing test:")
    for date_str in test_dates:
        parsed = adapter._parse_date(date_str)
        print(f"  '{date_str}' -> '{parsed}'")
        # Note: Some dates might be None due to parsing limitations

def test_full_extract_tasks():
    """Test full task extraction (will use rule-based if Groq not available)"""
    adapter = LLMAdapter()
    
    test_text = """
    Dear students,
    
    This is a reminder that your research paper is due on December 20th, 2024. 
    Please submit it through the online portal before 11:59 PM.
    
    Also, remember to attend the final presentation on December 18th at 3 PM in room 101.
    
    If you have any questions, please contact me before the deadline.
    
    Best regards,
    Prof. Smith
    """
    
    print("✓ Full task extraction test:")
    result = adapter.extract_tasks(test_text)
    
    print(f"  Summary: {result['summary']}")
    print(f"  Tasks found: {len(result['tasks'])}")
    
    for i, task in enumerate(result['tasks']):
        print(f"    Task {i+1}: {task['verb']} - {task['text']} (due: {task['due_date']})")
    
    assert "summary" in result
    assert "tasks" in result
    assert isinstance(result['tasks'], list)

def test_summarization():
    """Test text summarization"""
    adapter = LLMAdapter()
    
    long_text = """
    The artificial intelligence revolution is transforming how we work, learn, and interact with technology. 
    Machine learning algorithms are becoming more sophisticated, enabling computers to understand natural language, 
    recognize images, and make predictions with unprecedented accuracy. Companies across industries are investing 
    heavily in AI research and development, from healthcare and finance to transportation and entertainment. 
    However, this rapid advancement also raises important questions about ethics, privacy, and the future of work. 
    As AI systems become more capable, society must grapple with issues of bias, transparency, and the potential 
    displacement of human workers. The key to successful AI adoption lies in finding the right balance between 
    innovation and responsibility.
    """
    
    print("✓ Summarization test:")
    summary = adapter.summarize(long_text, 100)
    print(f"  Original length: {len(long_text)} characters")
    print(f"  Summary length: {len(summary)} characters")
    print(f"  Summary: {summary}")
    
    assert len(summary) <= 100
    assert len(summary) > 10

def test_llm_adapter_initialization():
    """Test LLM adapter initialization"""
    print("✓ LLM Adapter initialization test:")
    
    # Check environment variables
    groq_key = os.getenv("GROQ_API_KEY")
    hf_key = os.getenv("HF_API_KEY")
    
    print(f"  GROQ_API_KEY present: {bool(groq_key)}")
    print(f"  HF_API_KEY present: {bool(hf_key)}")
    
    adapter = LLMAdapter()
    print(f"  Groq client initialized: {adapter.groq_client is not None}")
    
    if adapter.groq_client:
        print("  ✓ Groq integration available")
    else:
        print("  [WARNING] Groq not available - will use fallback methods")

def run_all_tests():
    """Run all tests"""
    print("[TEST] Running LLM Adapter Tests\n")
    
    try:
        test_llm_adapter_initialization()
        print()
        
        test_simple_summary()
        print()
        
        test_date_parsing()
        print()
        
        test_rule_based_task_extraction()
        print()
        
        test_summarization()
        print()
        
        test_full_extract_tasks()
        print()
        
        print("[SUCCESS] All tests completed successfully!")
        
    except Exception as e:
        print(f"[FAILED] Test failed: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    run_all_tests()


