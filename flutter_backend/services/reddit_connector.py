"""
Reddit connector for fetching posts from subreddits
Uses Reddit API to fetch posts and process them into feed items
"""

import os
import logging
import json
from typing import List, Dict, Any, Optional
from datetime import datetime, timedelta

# Reddit API
try:
    import praw
    PRAW_AVAILABLE = True
except ImportError:
    PRAW_AVAILABLE = False
    logging.warning("PRAW not available. Install with: pip install praw")

from storage.db import get_db_session
from storage.models import User, FeedItem, ConnectorConfig, SourceType, PriorityLevel
from ml.llm_adapter import llm_adapter
from nlp.embeddings import get_embeddings_pipeline

logger = logging.getLogger(__name__)

class RedditConnector:
    """
    Reddit connector for fetching posts from subreddits
    """
    
    def __init__(self):
        self.client_id = os.getenv("REDDIT_CLIENT_ID")
        self.client_secret = os.getenv("REDDIT_CLIENT_SECRET")
        self.user_agent = os.getenv("REDDIT_USER_AGENT", "PersonalizedAIFeed/1.0")
        self.embeddings_pipeline = get_embeddings_pipeline()
        
        # Default subreddits
        self.default_subreddits = [
            "technology",
            "programming",
            "MachineLearning",
            "artificial",
            "startups",
            "webdev",
            "compsci",
            "datascience"
        ]
        
        self.reddit = None
        if PRAW_AVAILABLE and self.client_id and self.client_secret:
            try:
                self.reddit = praw.Reddit(
                    client_id=self.client_id,
                    client_secret=self.client_secret,
                    user_agent=self.user_agent
                )
                logger.info("Reddit API initialized successfully")
            except Exception as e:
                logger.error(f"Failed to initialize Reddit API: {e}")
    
    def fetch_subreddit_posts(self, subreddit_names: List[str], 
                             max_posts_per_subreddit: int = 10,
                             time_filter: str = "day") -> List[Dict[str, Any]]:
        """
        Fetch posts from specified subreddits
        """
        if not self.reddit:
            logger.error("Reddit API not available")
            return []
        
        posts = []
        
        for subreddit_name in subreddit_names:
            try:
                logger.info(f"Fetching posts from r/{subreddit_name}")
                
                subreddit = self.reddit.subreddit(subreddit_name)
                
                # Fetch hot posts
                for submission in subreddit.hot(limit=max_posts_per_subreddit):
                    try:
                        post = self._parse_reddit_post(submission, subreddit_name)
                        if post:
                            posts.append(post)
                    except Exception as e:
                        logger.error(f"Failed to parse Reddit post: {e}")
                        continue
                
                logger.info(f"Fetched posts from r/{subreddit_name}")
                
            except Exception as e:
                logger.error(f"Failed to fetch from r/{subreddit_name}: {e}")
                continue
        
        return posts
    
    def _parse_reddit_post(self, submission: Any, subreddit_name: str) -> Optional[Dict[str, Any]]:
        """
        Parse Reddit submission into structured post data
        """
        try:
            # Extract basic information
            title = submission.title
            url = submission.url
            selftext = submission.selftext
            author = str(submission.author) if submission.author else "[deleted]"
            score = submission.score
            num_comments = submission.num_comments
            created_utc = submission.created_utc
            
            # Parse created date
            date = datetime.fromtimestamp(created_utc)
            
            # Extract content
            content = selftext if selftext else ""
            
            # Extract flair
            flair = submission.link_flair_text if submission.link_flair_text else ""
            
            # Extract domain
            domain = submission.domain
            
            # Determine if it's a text post or link post
            post_type = "text" if selftext else "link"
            
            return {
                'id': submission.id,
                'title': title,
                'url': url,
                'content': content,
                'author': author,
                'score': score,
                'num_comments': num_comments,
                'date': date,
                'subreddit': subreddit_name,
                'flair': flair,
                'domain': domain,
                'post_type': post_type,
                'permalink': f"https://reddit.com{submission.permalink}"
            }
            
        except Exception as e:
            logger.error(f"Failed to parse Reddit post: {e}")
            return None
    
    def fetch_user_subscribed_subreddits(self, user_id: int) -> List[str]:
        """
        Fetch user's subscribed subreddits (requires OAuth)
        For now, returns default subreddits
        """
        # TODO: Implement OAuth to fetch user's subscribed subreddits
        # For now, return default subreddits
        return self.default_subreddits.copy()
    
    def process_posts_to_feed_items(self, user_id: int, posts: List[Dict[str, Any]]) -> List[FeedItem]:
        """
        Process Reddit posts into FeedItem objects
        """
        feed_items = []
        
        for post in posts:
            try:
                # Generate summary using LLM
                post_text = f"{post['title']} {post['content']}"
                summary = llm_adapter.summarize(post_text, max_length=200)
                
                # Extract tasks (Reddit posts rarely have actionable tasks)
                task_result = llm_adapter.extract_tasks(post_text)
                extracted_tasks = task_result.get('tasks', [])
                
                # Determine priority
                priority = self._determine_priority(post)
                
                # Calculate relevance score
                relevance_score = self._calculate_relevance_score(post, user_id)
                
                # Extract entities
                entities = self._extract_entities(post)
                
                # Create feed item
                feed_item = FeedItem(
                    user_id=user_id,
                    source=SourceType.REDDIT,
                    origin_id=post['id'],
                    title=post['title'],
                    summary=summary,
                    text=post['content'][:1000] if post['content'] else None,
                    date=post['date'],
                    priority=priority,
                    relevance_score=relevance_score,
                    entities=entities,
                    has_tasks=len(extracted_tasks) > 0,
                    extracted_tasks=extracted_tasks,
                    metadata={
                        'author': post['author'],
                        'subreddit': post['subreddit'],
                        'score': post['score'],
                        'num_comments': post['num_comments'],
                        'flair': post['flair'],
                        'domain': post['domain'],
                        'post_type': post['post_type'],
                        'url': post['url'],
                        'permalink': post['permalink']
                    }
                )
                
                # Generate embedding
                embedding_text = f"{post['title']} {summary or ''}"
                embedding = self.embeddings_pipeline.embed_text(embedding_text)
                if embedding:
                    feed_item.embedding = json.dumps(embedding)
                
                feed_items.append(feed_item)
                
            except Exception as e:
                logger.error(f"Failed to process Reddit post {post.get('id', 'unknown')}: {e}")
                continue
        
        return feed_items
    
    def _determine_priority(self, post: Dict[str, Any]) -> PriorityLevel:
        """
        Determine priority level for Reddit post
        """
        title = post['title'].lower()
        content = post.get('content', '').lower()
        text = f"{title} {content}"
        
        # Check for urgent/important keywords
        urgent_keywords = ['urgent', 'help', 'emergency', 'crisis', 'breaking']
        if any(keyword in text for keyword in urgent_keywords):
            return PriorityLevel.HIGH
        
        # Check for high-engagement posts
        score = post.get('score', 0)
        num_comments = post.get('num_comments', 0)
        
        if score > 1000 or num_comments > 100:
            return PriorityLevel.HIGH
        elif score > 100 or num_comments > 20:
            return PriorityLevel.MEDIUM
        
        # Check for technology/learning content
        tech_keywords = ['tutorial', 'guide', 'learn', 'how to', 'best practices']
        if any(keyword in text for keyword in tech_keywords):
            return PriorityLevel.MEDIUM
        
        return PriorityLevel.LOW
    
    def _calculate_relevance_score(self, post: Dict[str, Any], user_id: int) -> float:
        """
        Calculate relevance score for Reddit post
        """
        # Base score
        score = 0.4  # Reddit posts start with medium relevance
        
        # Boost for high-engagement posts
        reddit_score = post.get('score', 0)
        if reddit_score > 1000:
            score += 0.2
        elif reddit_score > 100:
            score += 0.1
        
        # Boost for posts with many comments (discussion)
        num_comments = post.get('num_comments', 0)
        if num_comments > 50:
            score += 0.1
        elif num_comments > 10:
            score += 0.05
        
        # Boost for technology subreddits
        subreddit = post.get('subreddit', '').lower()
        tech_subreddits = ['programming', 'machinelearning', 'artificial', 'technology', 'webdev', 'compsci']
        if subreddit in tech_subreddits:
            score += 0.1
        
        # Boost for recent posts
        post_age_hours = (datetime.now() - post['date']).total_seconds() / 3600
        if post_age_hours < 24:
            score += 0.1
        elif post_age_hours < 168:  # 1 week
            score += 0.05
        
        return min(1.0, score)
    
    def _extract_entities(self, post: Dict[str, Any]) -> List[str]:
        """
        Extract entities from Reddit post
        """
        entities = []
        
        title = post['title'].lower()
        content = post.get('content', '').lower()
        text = f"{title} {content}"
        
        # Technology entities
        tech_entities = [
            'python', 'javascript', 'react', 'node.js', 'ai', 'machine learning',
            'blockchain', 'cryptocurrency', 'startup', 'programming', 'coding'
        ]
        
        for entity in tech_entities:
            if entity in text:
                entities.append(entity)
        
        # Programming languages
        languages = ['python', 'javascript', 'java', 'c++', 'c#', 'go', 'rust', 'php', 'ruby']
        for lang in languages:
            if lang in text:
                entities.append(f"language_{lang}")
        
        # Frameworks and tools
        frameworks = ['react', 'angular', 'vue', 'django', 'flask', 'express', 'spring']
        for framework in frameworks:
            if framework in text:
                entities.append(f"framework_{framework}")
        
        # Add subreddit as entity
        entities.append(f"subreddit_{post.get('subreddit', '').lower()}")
        
        return entities[:15]  # Limit to 15 entities

# Global Reddit connector instance
reddit_connector = RedditConnector()

def get_reddit_connector() -> RedditConnector:
    """Get the global Reddit connector instance"""
    return reddit_connector


