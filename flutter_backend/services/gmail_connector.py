"""
Gmail connector for OAuth2 authentication and email ingestion
Uses Gmail API to fetch emails and extract actionable content
"""

import os
import logging
import base64
import json
from typing import List, Dict, Any, Optional, Tuple
from datetime import datetime, timedelta
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
import re

# Google API libraries
try:
    from google.auth.transport.requests import Request
    from google.oauth2.credentials import Credentials
    from google_auth_oauthlib.flow import Flow
    from googleapiclient.discovery import build
    from googleapiclient.errors import HttpError
    GOOGLE_APIS_AVAILABLE = True
except ImportError:
    GOOGLE_APIS_AVAILABLE = False
    logging.warning("Google APIs not available. Install with: pip install google-auth google-auth-oauthlib google-api-python-client")

from storage.db import get_db_session
from storage.models import User, FeedItem, ConnectorConfig, SourceType, PriorityLevel
from ml.llm_adapter import llm_adapter
from nlp.embeddings import get_embeddings_pipeline

logger = logging.getLogger(__name__)

class GmailConnector:
    """
    Gmail connector for OAuth2 authentication and email processing
    """
    
    def __init__(self):
        self.client_id = os.getenv("GMAIL_CLIENT_ID")
        self.client_secret = os.getenv("GMAIL_CLIENT_SECRET")
        self.redirect_uri = os.getenv("GMAIL_REDIRECT_URI", "http://localhost:8000/api/auth/gmail/callback")
        
        # Gmail API scopes
        self.scopes = [
            'https://www.googleapis.com/auth/gmail.readonly',
            'https://www.googleapis.com/auth/userinfo.email',
            'https://www.googleapis.com/auth/userinfo.profile'
        ]
        
        if not GOOGLE_APIS_AVAILABLE:
            logger.error("Google APIs not available. Gmail connector disabled.")
    
    def get_auth_url(self, user_id: int) -> Optional[str]:
        """
        Generate OAuth2 authorization URL for Gmail
        Returns URL for user to visit for authorization
        """
        if not GOOGLE_APIS_AVAILABLE or not self.client_id:
            logger.error("Gmail OAuth not configured")
            return None
        
        try:
            flow = Flow.from_client_config(
                {
                    "web": {
                        "client_id": self.client_id,
                        "client_secret": self.client_secret,
                        "auth_uri": "https://accounts.google.com/o/oauth2/auth",
                        "token_uri": "https://oauth2.googleapis.com/token",
                        "redirect_uris": [self.redirect_uri]
                    }
                },
                scopes=self.scopes
            )
            flow.redirect_uri = self.redirect_uri
            
            # Add state parameter to track user
            auth_url, state = flow.authorization_url(
                access_type='offline',
                include_granted_scopes='true',
                state=str(user_id)
            )
            
            logger.info(f"Generated Gmail auth URL for user {user_id}")
            return auth_url
            
        except Exception as e:
            logger.error(f"Failed to generate Gmail auth URL: {e}")
            return None
    
    def handle_oauth_callback(self, authorization_code: str, state: str) -> bool:
        """
        Handle OAuth2 callback and store credentials
        Returns True if successful, False otherwise
        """
        if not GOOGLE_APIS_AVAILABLE or not self.client_id:
            logger.error("Gmail OAuth not configured")
            return False
        
        try:
            user_id = int(state)
            
            flow = Flow.from_client_config(
                {
                    "web": {
                        "client_id": self.client_id,
                        "client_secret": self.client_secret,
                        "auth_uri": "https://accounts.google.com/o/oauth2/auth",
                        "token_uri": "https://oauth2.googleapis.com/token",
                        "redirect_uris": [self.redirect_uri]
                    }
                },
                scopes=self.scopes
            )
            flow.redirect_uri = self.redirect_uri
            
            # Exchange authorization code for tokens
            flow.fetch_token(code=authorization_code)
            credentials = flow.credentials
            
            # Store credentials in database
            db = get_db_session()
            try:
                # Get or create connector config
                config = db.query(ConnectorConfig).filter(
                    ConnectorConfig.user_id == user_id,
                    ConnectorConfig.connector_type == SourceType.GMAIL
                ).first()
                
                if not config:
                    config = ConnectorConfig(
                        user_id=user_id,
                        connector_type=SourceType.GMAIL,
                        is_enabled=True
                    )
                    db.add(config)
                
                # Store encrypted tokens
                config.access_token = self._encrypt_token(credentials.token)
                config.refresh_token = self._encrypt_token(credentials.refresh_token) if credentials.refresh_token else None
                config.token_expires_at = credentials.expiry
                config.config_data = {
                    "email": credentials.id_token.get("email") if credentials.id_token else None,
                    "name": credentials.id_token.get("name") if credentials.id_token else None
                }
                
                db.commit()
                logger.info(f"Gmail OAuth completed for user {user_id}")
                return True
                
            finally:
                db.close()
                
        except Exception as e:
            logger.error(f"Gmail OAuth callback failed: {e}")
            return False
    
    def _encrypt_token(self, token: str) -> str:
        """
        Encrypt token for storage (simple base64 for now)
        TODO: Implement proper encryption with ENCRYPTION_KEY
        """
        if not token:
            return ""
        return base64.b64encode(token.encode()).decode()
    
    def _decrypt_token(self, encrypted_token: str) -> str:
        """
        Decrypt token from storage
        """
        if not encrypted_token:
            return ""
        try:
            return base64.b64decode(encrypted_token.encode()).decode()
        except:
            return ""
    
    def get_credentials(self, user_id: int) -> Optional[Any]:
        """
        Get valid Gmail credentials for user
        Refreshes token if needed
        """
        if not GOOGLE_APIS_AVAILABLE:
            return None
        
        try:
            db = get_db_session()
            try:
                config = db.query(ConnectorConfig).filter(
                    ConnectorConfig.user_id == user_id,
                    ConnectorConfig.connector_type == SourceType.GMAIL,
                    ConnectorConfig.is_enabled == True
                ).first()
                
                if not config or not config.access_token:
                    return None
                
                # Create credentials object (only available if Google APIs installed)
                # Use dynamic import to avoid NameError when typing module is not available
                from google.oauth2.credentials import Credentials as _Credentials
                credentials = _Credentials(
                    token=self._decrypt_token(config.access_token),
                    refresh_token=self._decrypt_token(config.refresh_token) if config.refresh_token else None,
                    token_uri="https://oauth2.googleapis.com/token",
                    client_id=self.client_id,
                    client_secret=self.client_secret,
                    scopes=self.scopes
                )
                
                # Refresh token if expired
                if credentials.expired and credentials.refresh_token:
                    credentials.refresh(Request())
                    
                    # Update stored token
                    config.access_token = self._encrypt_token(credentials.token)
                    config.token_expires_at = credentials.expiry
                    db.commit()
                
                return credentials
                
            finally:
                db.close()
                
        except Exception as e:
            logger.error(f"Failed to get Gmail credentials for user {user_id}: {e}")
            return None
    
    def fetch_emails(self, user_id: int, max_results: int = 50, 
                    since_date: Optional[datetime] = None) -> List[Dict[str, Any]]:
        """
        Fetch emails from Gmail for a user
        Returns list of email data
        """
        if not GOOGLE_APIS_AVAILABLE:
            logger.error("Google APIs not available")
            return []
        
        try:
            credentials = self.get_credentials(user_id)
            if not credentials:
                logger.warning(f"No valid Gmail credentials for user {user_id}")
                return []
            
            # Build Gmail service
            service = build('gmail', 'v1', credentials=credentials)
            
            # Build query
            query_parts = []
            if since_date:
                since_timestamp = int(since_date.timestamp())
                query_parts.append(f"after:{since_timestamp}")
            
            query = " ".join(query_parts) if query_parts else ""
            
            # Fetch messages
            results = service.users().messages().list(
                userId='me',
                q=query,
                maxResults=max_results
            ).execute()
            
            messages = results.get('messages', [])
            logger.info(f"Found {len(messages)} Gmail messages for user {user_id}")
            
            # Fetch full message details
            emails = []
            for message in messages:
                try:
                    msg = service.users().messages().get(
                        userId='me',
                        id=message['id'],
                        format='full'
                    ).execute()
                    
                    email_data = self._parse_email_message(msg)
                    if email_data:
                        emails.append(email_data)
                        
                except HttpError as e:
                    logger.error(f"Failed to fetch message {message['id']}: {e}")
                    continue
            
            return emails
            
        except Exception as e:
            logger.error(f"Gmail fetch failed for user {user_id}: {e}")
            return []
    
    def _parse_email_message(self, message: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """
        Parse Gmail message into structured data
        """
        try:
            headers = message['payload'].get('headers', [])
            header_dict = {h['name'].lower(): h['value'] for h in headers}
            
            # Extract basic info
            subject = header_dict.get('subject', 'No Subject')
            sender = header_dict.get('from', 'Unknown Sender')
            sender_email = self._extract_email_address(sender)
            date_str = header_dict.get('date', '')
            
            # Parse date
            try:
                from email.utils import parsedate_to_datetime
                date = parsedate_to_datetime(date_str)
            except:
                date = datetime.now()
            
            # Extract body
            body = self._extract_email_body(message['payload'])
            
            # Extract thread ID and message ID
            thread_id = message.get('threadId')
            message_id = message.get('id')
            
            return {
                'id': message_id,
                'thread_id': thread_id,
                'subject': subject,
                'sender': sender,
                'sender_email': sender_email,
                'date': date,
                'body': body,
                'headers': header_dict
            }
            
        except Exception as e:
            logger.error(f"Failed to parse email message: {e}")
            return None
    
    def _extract_email_address(self, from_field: str) -> str:
        """
        Extract email address from 'From' field
        """
        # Pattern to match email addresses
        email_pattern = r'<([^>]+)>|([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})'
        match = re.search(email_pattern, from_field)
        if match:
            return match.group(1) or match.group(2)
        return from_field
    
    def _extract_email_body(self, payload: Dict[str, Any]) -> str:
        """
        Extract text body from email payload
        """
        body = ""
        
        if 'parts' in payload:
            # Multipart message
            for part in payload['parts']:
                if part['mimeType'] == 'text/plain':
                    data = part['body'].get('data')
                    if data:
                        body += base64.urlsafe_b64decode(data).decode('utf-8', errors='ignore')
                elif part['mimeType'] == 'text/html' and not body:
                    # Fallback to HTML if no plain text
                    data = part['body'].get('data')
                    if data:
                        html_body = base64.urlsafe_b64decode(data).decode('utf-8', errors='ignore')
                        # Simple HTML tag removal
                        body = re.sub(r'<[^>]+>', '', html_body)
        else:
            # Single part message
            if payload['mimeType'] == 'text/plain':
                data = payload['body'].get('data')
                if data:
                    body = base64.urlsafe_b64decode(data).decode('utf-8', errors='ignore')
            elif payload['mimeType'] == 'text/html':
                data = payload['body'].get('data')
                if data:
                    html_body = base64.urlsafe_b64decode(data).decode('utf-8', errors='ignore')
                    body = re.sub(r'<[^>]+>', '', html_body)
        
        return body.strip()
    
    def process_emails_to_feed_items(self, user_id: int, emails: List[Dict[str, Any]]) -> List[FeedItem]:
        """
        Process emails into FeedItem objects
        """
        feed_items = []
        embeddings_pipeline = get_embeddings_pipeline()
        
        for email in emails:
            try:
                # Generate summary using LLM
                email_text = f"{email['subject']} {email['body']}"
                summary = llm_adapter.summarize(email_text, max_length=150)
                
                # Extract tasks
                task_result = llm_adapter.extract_tasks(email_text)
                extracted_tasks = task_result.get('tasks', [])
                
                # Determine priority based on content
                priority = self._determine_priority(email['subject'], email['body'], extracted_tasks)
                
                # Calculate relevance score (can be enhanced with user preferences)
                relevance_score = self._calculate_relevance_score(email, user_id)
                
                # Extract entities (simple keyword extraction for now)
                entities = self._extract_entities(email['subject'], email['body'])
                
                # Create feed item
                feed_item = FeedItem(
                    user_id=user_id,
                    source=SourceType.GMAIL,
                    origin_id=email['id'],
                    title=email['subject'],
                    summary=summary,
                    text=email['body'][:1000] if email['body'] else None,  # Truncate for storage
                    date=email['date'],
                    priority=priority,
                    relevance_score=relevance_score,
                    entities=entities,
                    has_tasks=len(extracted_tasks) > 0,
                    extracted_tasks=extracted_tasks,
                    metadata={
                        'sender': email['sender'],
                        'sender_email': email['sender_email'],
                        'thread_id': email['thread_id'],
                        'headers': email['headers']
                    }
                )
                
                # Generate embedding
                embedding_text = f"{email['subject']} {summary or ''}"
                embedding = embeddings_pipeline.embed_text(embedding_text)
                if embedding:
                    feed_item.embedding = json.dumps(embedding)
                
                feed_items.append(feed_item)
                
            except Exception as e:
                logger.error(f"Failed to process email {email.get('id', 'unknown')}: {e}")
                continue
        
        return feed_items
    
    def _determine_priority(self, subject: str, body: str, tasks: List[Dict[str, Any]]) -> PriorityLevel:
        """
        Determine priority level based on email content
        """
        text = f"{subject} {body}".lower()
        
        # Check for urgent keywords
        urgent_keywords = ['urgent', 'asap', 'immediately', 'emergency', 'critical']
        if any(keyword in text for keyword in urgent_keywords):
            return PriorityLevel.URGENT
        
        # Check for high priority keywords
        high_keywords = ['important', 'deadline', 'due', 'submit', 'complete']
        if any(keyword in text for keyword in high_keywords):
            return PriorityLevel.HIGH
        
        # Check for tasks with near due dates
        for task in tasks:
            if task.get('due_date'):
                try:
                    due_date = datetime.fromisoformat(task['due_date'].replace('Z', '+00:00'))
                    days_until_due = (due_date - datetime.now()).days
                    if days_until_due <= 1:
                        return PriorityLevel.URGENT
                    elif days_until_due <= 3:
                        return PriorityLevel.HIGH
                except:
                    pass
        
        return PriorityLevel.MEDIUM
    
    def _calculate_relevance_score(self, email: Dict[str, Any], user_id: int) -> float:
        """
        Calculate relevance score for email
        Can be enhanced with user preferences
        """
        # Base score
        score = 0.5
        
        # Boost for emails with tasks
        if any(keyword in email['subject'].lower() for keyword in ['submit', 'complete', 'attend', 'due']):
            score += 0.2
        
        # Boost for emails from important domains (can be user-configurable)
        sender_domain = email['sender_email'].split('@')[-1] if '@' in email['sender_email'] else ''
        important_domains = ['edu', 'university.edu', 'company.com']  # Can be user-specific
        if any(domain in sender_domain for domain in important_domains):
            score += 0.1
        
        return min(1.0, score)
    
    def _extract_entities(self, subject: str, body: str) -> List[str]:
        """
        Extract entities from email content
        Simple keyword extraction for now
        """
        text = f"{subject} {body}".lower()
        
        # Common entity patterns
        entities = []
        
        # Assignment/project patterns
        if any(word in text for word in ['assignment', 'project', 'homework']):
            entities.append('assignment')
        
        # Meeting patterns
        if any(word in text for word in ['meeting', 'conference', 'call']):
            entities.append('meeting')
        
        # Deadline patterns
        if any(word in text for word in ['deadline', 'due', 'submit']):
            entities.append('deadline')
        
        # Course patterns
        course_match = re.search(r'course\s+([a-zA-Z0-9]+)', text)
        if course_match:
            entities.append(f"course_{course_match.group(1)}")
        
        return entities

# Global Gmail connector instance
gmail_connector = GmailConnector()

def get_gmail_connector() -> GmailConnector:
    """Get the global Gmail connector instance"""
    return gmail_connector


