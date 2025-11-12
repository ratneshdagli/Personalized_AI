"""
Test WhatsApp Connector

Tests for WhatsApp chat export parsing and notification processing.
"""

import unittest
from unittest.mock import Mock, patch
from datetime import datetime
import tempfile
import os

# Add the parent directory to the path so we can import our modules
import sys
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from services.whatsapp_connector import WhatsAppConnector
from storage.models import FeedItem
from app.core.nosql import store


class TestWhatsAppConnector(unittest.TestCase):
    """Test cases for WhatsApp connector"""
    
    def setUp(self):
        """Set up test environment"""
        os.environ["BACKEND_STORAGE"] = "memory"
        # Use a fixed user id for NoSQL tests
        self.test_user_id = 1
        # Ensure clean state per test
        if hasattr(store, "_mem"):
            store._mem["feed_items"] = []
            store._mem["connectors"] = []
        
        # Create connector instance
        self.connector = WhatsAppConnector()
        
        # Sample chat export text
        self.sample_chat = """[12/01/2024, 10:30:15] john doe: Hey, are we still meeting tomorrow?
[12/01/2024, 10:31:22] jane smith: Yes, at 2 PM in the conference room
[12/01/2024, 10:32:45] john doe: Perfect! I'll bring the presentation slides
[12/01/2024, 10:33:12] jane smith: Great! Don't forget to send me the agenda
[12/01/2024, 10:34:01] john doe: Will do, sending it now
[12/01/2024, 10:35:30] jane smith: Thanks! See you tomorrow"""
    
    def tearDown(self):
        """Clean up test environment"""
        if hasattr(store, "_mem"):
            store._mem["feed_items"] = []
            store._mem["connectors"] = []
    
    def test_parse_chat_messages(self):
        """Test parsing of chat messages"""
        messages = self.connector._parse_chat_messages(self.sample_chat)
        
        self.assertEqual(len(messages), 6)
        
        # Check first message
        first_msg = messages[0]
        self.assertEqual(first_msg['sender'], 'john doe'.lower())
        self.assertEqual(first_msg['content'], 'Hey, are we still meeting tomorrow?')
        self.assertIsInstance(first_msg['datetime'], datetime)
        
        # Check last message
        last_msg = messages[-1]
        self.assertEqual(last_msg['sender'], 'jane smith')
        self.assertEqual(last_msg['content'], 'Thanks! See you tomorrow')
    
    def test_group_messages_by_day(self):
        """Test grouping messages by day"""
        messages = self.connector._parse_chat_messages(self.sample_chat)
        daily_groups = self.connector._group_messages_by_day(messages)
        
        self.assertEqual(len(daily_groups), 1)  # All messages on same day
        self.assertIn('2024-01-12', daily_groups)
        self.assertEqual(len(daily_groups['2024-01-12']), 6)
    
    @patch('services.whatsapp_connector.get_llm_adapter')
    def test_create_feed_item_from_messages(self, mock_llm):
        """Test creating feed item from messages"""
        # Mock LLM responses
        mock_adapter = Mock()
        # Provide both legacy and potential new API names for summary
        mock_adapter.summarize_text.return_value = "Meeting discussion by john doe about tomorrow's presentation"
        mock_adapter.generate_summary = Mock(return_value="Meeting discussion by john doe about tomorrow's presentation")
        mock_adapter.extract_tasks.return_value = {
            'tasks': [
                {'task': 'Bring presentation slides', 'priority': 'medium'},
                {'task': 'Send agenda to Jane', 'priority': 'high'}
            ]
        }
        mock_llm.return_value = mock_adapter
        
        messages = self.connector._parse_chat_messages(self.sample_chat)
        feed_item = self.connector._create_feed_item_from_messages(
            messages, self.test_user_id, "Test Chat", "2024-01-12"
        )
        
        self.assertIsNotNone(feed_item)
        self.assertEqual(feed_item.user_id, self.test_user_id)
        self.assertEqual(feed_item.source, "whatsapp")
        self.assertEqual(feed_item.origin_id, "whatsapp_Test Chat_2024-01-12")
        self.assertIn("john doe", feed_item.content.lower())
        self.assertIn("jane smith", feed_item.content.lower())
        self.assertGreater(feed_item.priority, 0.5)  # Should have higher priority due to tasks
    
    def test_parse_chat_export(self):
        """Test full chat export parsing"""
        feed_items = self.connector.parse_chat_export(
            self.sample_chat, self.test_user_id, "Test Chat"
        )
        
        self.assertEqual(len(feed_items), 1)  # One day's worth of messages
        
        feed_item = feed_items[0]
        self.assertEqual(feed_item.user_id, self.test_user_id)
        self.assertEqual(feed_item.source, "whatsapp")
        self.assertIn("Test Chat", feed_item.title)
        self.assertIn("john doe", feed_item.content.lower())
        self.assertIn("jane smith", feed_item.content.lower())
    
    def test_process_notification_data(self):
        """Test processing notification data"""
        notification_data = {
            'title': 'WhatsApp Message',
            'content': 'Hey, can you review the proposal by tomorrow?',
            'sender': 'Alice Johnson',
            'timestamp': '2024-01-12T15:30:00Z',
            'user_id': self.test_user_id
        }
        
        feed_item = self.connector.process_notification_data(
            notification_data, self.test_user_id
        )
        
        self.assertIsNotNone(feed_item)
        self.assertEqual(feed_item.user_id, self.test_user_id)
        self.assertEqual(feed_item.source, "whatsapp_notification")
        self.assertIn("Alice Johnson", feed_item.title)
        self.assertIn("proposal", feed_item.content)
        self.assertIn("tomorrow", feed_item.content)
    
    def test_calculate_priority_relevance(self):
        """Test priority and relevance calculation"""
        content = "This is urgent! Please call me ASAP about the deadline. You, we, us, me, my."
        # Use >2 senders to increase relevance and include personal keywords to exceed 0.5
        senders = {"John", "Jane", "Alex"}
        tasks = [{"task": "Call John", "priority": "high"}]
        
        priority, relevance = self.connector._calculate_priority_relevance(
            content, senders, tasks
        )
        
        self.assertGreater(priority, 0.7)  # Should be high due to urgent keywords and tasks
        self.assertGreater(relevance, 0.5)  # Should now be > 0.5 due to senders and keywords
    
    def test_empty_chat_export(self):
        """Test handling of empty chat export"""
        feed_items = self.connector.parse_chat_export("", self.test_user_id, "Empty Chat")
        self.assertEqual(len(feed_items), 0)
    
    def test_malformed_chat_export(self):
        """Test handling of malformed chat export"""
        malformed_chat = """This is not a proper WhatsApp export
Just some random text
Without proper formatting"""
        
        feed_items = self.connector.parse_chat_export(
            malformed_chat, self.test_user_id, "Malformed Chat"
        )
        
        # Should handle gracefully and return empty list or minimal items
        self.assertIsInstance(feed_items, list)


def run_whatsapp_tests():
    """Run all WhatsApp connector tests"""
    print("[TEST] Running WhatsApp Connector Tests...")
    
    # Create test suite
    suite = unittest.TestLoader().loadTestsFromTestCase(TestWhatsAppConnector)
    
    # Run tests
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    
    # Print results
    if result.wasSuccessful():
        print("[SUCCESS] All WhatsApp connector tests passed!")
        return True
    else:
        print(f"[FAILED] {len(result.failures)} test(s) failed, {len(result.errors)} error(s)")
        for failure in result.failures:
            print(f"FAIL: {failure[0]}")
            print(f"  {failure[1]}")
        for error in result.errors:
            print(f"ERROR: {error[0]}")
            print(f"  {error[1]}")
        return False


if __name__ == "__main__":
    run_whatsapp_tests()

