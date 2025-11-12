"""
News connector for RSS feeds and NewsAPI integration
Fetches news articles and processes them into feed items
"""

import os
import logging
import json
try:
    import feedparser
    _FEEDPARSER_AVAILABLE = True
except ImportError:
    feedparser = None
    _FEEDPARSER_AVAILABLE = False
    # We'll use a lightweight fallback parser when feedparser is not installed
    import xml.etree.ElementTree as ET
from typing import List, Dict, Any, Optional
from datetime import datetime, timedelta
import requests
from urllib.parse import urljoin, urlparse

from storage.db import get_db_session
from storage.models import User, FeedItem, ConnectorConfig, SourceType, PriorityLevel
from ml.llm_adapter import llm_adapter
from nlp.embeddings import get_embeddings_pipeline

logger = logging.getLogger(__name__)

class NewsConnector:
    """
    News connector for RSS feeds and NewsAPI
    """
    
    def __init__(self):
        self.newsapi_key = os.getenv("NEWSAPI_KEY")
        self.gnews_api_key = os.getenv("GNEWS_API_KEY")
        self.embeddings_pipeline = get_embeddings_pipeline()
        
        # Default RSS feeds
        self.default_rss_feeds = [
            {
                "name": "BBC News",
                "url": "http://feeds.bbci.co.uk/news/rss.xml",
                "category": "general"
            },
            {
                "name": "TechCrunch",
                "url": "https://techcrunch.com/feed/",
                "category": "technology"
            },
            {
                "name": "Hacker News",
                "url": "https://hnrss.org/frontpage",
                "category": "technology"
            },
            {
                "name": "Reuters Technology",
                "url": "https://feeds.reuters.com/reuters/technologyNews",
                "category": "technology"
            }
        ]
    
    def fetch_rss_feeds(self, feed_urls: List[str], max_items_per_feed: int = 20) -> List[Dict[str, Any]]:
        """
        Fetch articles from RSS feeds
        """
        articles = []
        
        for feed_url in feed_urls:
            try:
                logger.info(f"Fetching RSS feed: {feed_url}")
                
                # Parse RSS feed
                if _FEEDPARSER_AVAILABLE and feedparser:
                    feed = feedparser.parse(feed_url)
                    if getattr(feed, 'bozo', False):
                        logger.warning(f"RSS feed parsing warning for {feed_url}: {getattr(feed, 'bozo_exception', '')}")
                    entries = list(getattr(feed, 'entries', []))[:max_items_per_feed]
                else:
                    # Fallback: fetch raw XML and parse basic <item> elements
                    try:
                        resp = requests.get(feed_url, timeout=15)
                        resp.raise_for_status()
                        root = ET.fromstring(resp.content)
                        # Find items in channel or feed
                        items = root.findall('.//item') or root.findall('.//entry')
                        entries = items[:max_items_per_feed]
                    except Exception as e:
                        logger.error(f"Fallback RSS fetch failed for {feed_url}: {e}")
                        entries = []

                # Process feed items
                for entry in entries:
                    try:
                        article = self._parse_rss_entry(entry, feed_url)
                        if article:
                            articles.append(article)
                    except Exception as e:
                        logger.error(f"Failed to parse RSS entry: {e}")
                        continue

                logger.info(f"Fetched {len(entries)} items from {feed_url}")
                
            except Exception as e:
                logger.error(f"Failed to fetch RSS feed {feed_url}: {e}")
                continue
        
        return articles
    
    def _parse_rss_entry(self, entry: Any, feed_url: str) -> Optional[Dict[str, Any]]:
        """
        Parse RSS entry into structured article data
        """
        try:
            # Extract basic information
            title = getattr(entry, 'title', 'No Title')
            link = getattr(entry, 'link', '')
            summary = getattr(entry, 'summary', '')
            published = getattr(entry, 'published_parsed', None)
            
            # Parse published date
            if published:
                try:
                    from email.utils import parsedate_to_datetime
                    date = parsedate_to_datetime(entry.published)
                except:
                    date = datetime.now()
            else:
                date = datetime.now()
            
            # Extract author
            author = getattr(entry, 'author', '')
            
            # Extract tags/categories
            tags = []
            if hasattr(entry, 'tags'):
                tags = [tag.term for tag in entry.tags]
            elif hasattr(entry, 'category'):
                tags = [entry.category]
            
            # Extract content
            content = summary
            if hasattr(entry, 'content') and entry.content:
                content = entry.content[0].value if isinstance(entry.content, list) else str(entry.content)
            
            # Clean HTML from content
            import re
            content = re.sub(r'<[^>]+>', '', content)
            
            return {
                'title': title,
                'link': link,
                'summary': summary,
                'content': content,
                'author': author,
                'date': date,
                'tags': tags,
                'source': feed_url,
                'source_name': self._get_source_name(feed_url)
            }
            
        except Exception as e:
            logger.error(f"Failed to parse RSS entry: {e}")
            return None
    
    def _get_source_name(self, feed_url: str) -> str:
        """
        Extract source name from feed URL
        """
        try:
            parsed = urlparse(feed_url)
            domain = parsed.netloc
            # Remove www. prefix
            if domain.startswith('www.'):
                domain = domain[4:]
            return domain
        except:
            return "Unknown Source"
    
    def fetch_newsapi_articles(self, query: str = "technology", max_results: int = 20) -> List[Dict[str, Any]]:
        """
        Fetch articles from NewsAPI
        """
        if not self.newsapi_key:
            logger.warning("NewsAPI key not configured")
            return []
        
        try:
            url = "https://newsapi.org/v2/everything"
            params = {
                'q': query,
                'apiKey': self.newsapi_key,
                'pageSize': min(max_results, 100),
                'sortBy': 'publishedAt',
                'language': 'en'
            }
            
            response = requests.get(url, params=params, timeout=30)
            response.raise_for_status()
            
            data = response.json()
            articles = []
            
            for article_data in data.get('articles', []):
                try:
                    article = self._parse_newsapi_article(article_data)
                    if article:
                        articles.append(article)
                except Exception as e:
                    logger.error(f"Failed to parse NewsAPI article: {e}")
                    continue
            
            logger.info(f"Fetched {len(articles)} articles from NewsAPI")
            return articles
            
        except Exception as e:
            logger.error(f"NewsAPI fetch failed: {e}")
            return []
    
    def _parse_newsapi_article(self, article_data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """
        Parse NewsAPI article into structured data
        """
        try:
            # Parse published date
            published_str = article_data.get('publishedAt', '')
            if published_str:
                try:
                    date = datetime.fromisoformat(published_str.replace('Z', '+00:00'))
                except:
                    date = datetime.now()
            else:
                date = datetime.now()
            
            return {
                'title': article_data.get('title', 'No Title'),
                'link': article_data.get('url', ''),
                'summary': article_data.get('description', ''),
                'content': article_data.get('content', ''),
                'author': article_data.get('author', ''),
                'date': date,
                'tags': [],
                'source': article_data.get('source', {}).get('name', 'NewsAPI'),
                'source_name': article_data.get('source', {}).get('name', 'NewsAPI')
            }
            
        except Exception as e:
            logger.error(f"Failed to parse NewsAPI article: {e}")
            return None
    
    def fetch_gnews_articles(self, query: str = "technology", max_results: int = 20) -> List[Dict[str, Any]]:
        """
        Fetch articles from GNews API
        """
        if not self.gnews_api_key:
            logger.warning("GNews API key not configured")
            return []
        
        try:
            url = "https://gnews.io/api/v4/search"
            params = {
                'q': query,
                'token': self.gnews_api_key,
                'max': min(max_results, 10),  # GNews free tier limit
                'lang': 'en',
                'sortby': 'publishedAt'
            }
            
            response = requests.get(url, params=params, timeout=30)
            response.raise_for_status()
            
            data = response.json()
            articles = []
            
            for article_data in data.get('articles', []):
                try:
                    article = self._parse_gnews_article(article_data)
                    if article:
                        articles.append(article)
                except Exception as e:
                    logger.error(f"Failed to parse GNews article: {e}")
                    continue
            
            logger.info(f"Fetched {len(articles)} articles from GNews")
            return articles
            
        except Exception as e:
            logger.error(f"GNews fetch failed: {e}")
            return []
    
    def _parse_gnews_article(self, article_data: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """
        Parse GNews article into structured data
        """
        try:
            # Parse published date
            published_str = article_data.get('publishedAt', '')
            if published_str:
                try:
                    date = datetime.fromisoformat(published_str.replace('Z', '+00:00'))
                except:
                    date = datetime.now()
            else:
                date = datetime.now()
            
            return {
                'title': article_data.get('title', 'No Title'),
                'link': article_data.get('url', ''),
                'summary': article_data.get('description', ''),
                'content': article_data.get('content', ''),
                'author': '',
                'date': date,
                'tags': [],
                'source': article_data.get('source', {}).get('name', 'GNews'),
                'source_name': article_data.get('source', {}).get('name', 'GNews')
            }
            
        except Exception as e:
            logger.error(f"Failed to parse GNews article: {e}")
            return None
    
    def process_articles_to_feed_items(self, user_id: int, articles: List[Dict[str, Any]]) -> List[FeedItem]:
        """
        Process news articles into FeedItem objects
        """
        feed_items = []
        
        for article in articles:
            try:
                # Generate summary using LLM
                article_text = f"{article['title']} {article['summary']} {article['content']}"
                summary = llm_adapter.summarize(article_text, max_length=200)
                
                # Extract tasks (news articles rarely have actionable tasks)
                task_result = llm_adapter.extract_tasks(article_text)
                extracted_tasks = task_result.get('tasks', [])
                
                # Determine priority (news is generally medium priority)
                priority = self._determine_priority(article)
                
                # Calculate relevance score
                relevance_score = self._calculate_relevance_score(article, user_id)
                
                # Extract entities
                entities = self._extract_entities(article)
                
                # Create feed item
                feed_item = FeedItem(
                    user_id=user_id,
                    source=SourceType.NEWS,
                    origin_id=article['link'] or f"news_{hash(article['title'])}",
                    title=article['title'],
                    summary=summary,
                    text=article['content'][:1000] if article['content'] else None,
                    date=article['date'],
                    priority=priority,
                    relevance_score=relevance_score,
                    entities=entities,
                    has_tasks=len(extracted_tasks) > 0,
                    extracted_tasks=extracted_tasks,
                    metadata={
                        'author': article['author'],
                        'source': article['source'],
                        'source_name': article['source_name'],
                        'link': article['link'],
                        'tags': article['tags']
                    }
                )
                
                # Generate embedding
                embedding_text = f"{article['title']} {summary or ''}"
                embedding = self.embeddings_pipeline.embed_text(embedding_text)
                if embedding:
                    feed_item.embedding = json.dumps(embedding)
                
                feed_items.append(feed_item)
                
            except Exception as e:
                logger.error(f"Failed to process article {article.get('title', 'unknown')}: {e}")
                continue
        
        return feed_items
    
    def _determine_priority(self, article: Dict[str, Any]) -> PriorityLevel:
        """
        Determine priority level for news article
        """
        title = article['title'].lower()
        content = article.get('content', '').lower()
        text = f"{title} {content}"
        
        # Check for urgent/breaking news keywords
        urgent_keywords = ['breaking', 'urgent', 'emergency', 'crisis', 'alert']
        if any(keyword in text for keyword in urgent_keywords):
            return PriorityLevel.HIGH
        
        # Check for important technology keywords
        tech_keywords = ['ai', 'artificial intelligence', 'machine learning', 'startup', 'funding', 'acquisition']
        if any(keyword in text for keyword in tech_keywords):
            return PriorityLevel.MEDIUM
        
        return PriorityLevel.LOW
    
    def _calculate_relevance_score(self, article: Dict[str, Any], user_id: int) -> float:
        """
        Calculate relevance score for news article
        Can be enhanced with user preferences
        """
        # Base score
        score = 0.3  # News articles start with lower relevance
        
        # Boost for technology content
        title = article['title'].lower()
        tech_keywords = ['ai', 'tech', 'software', 'programming', 'startup', 'innovation']
        if any(keyword in title for keyword in tech_keywords):
            score += 0.2
        
        # Boost for recent articles
        article_age_hours = (datetime.now() - article['date']).total_seconds() / 3600
        if article_age_hours < 24:
            score += 0.1
        elif article_age_hours < 168:  # 1 week
            score += 0.05
        
        return min(1.0, score)
    
    def _extract_entities(self, article: Dict[str, Any]) -> List[str]:
        """
        Extract entities from news article
        """
        entities = []
        
        title = article['title'].lower()
        content = article.get('content', '').lower()
        text = f"{title} {content}"
        
        # Technology entities
        tech_entities = ['ai', 'artificial intelligence', 'machine learning', 'blockchain', 'cryptocurrency']
        for entity in tech_entities:
            if entity in text:
                entities.append(entity)
        
        # Company entities (simple pattern matching)
        import re
        company_patterns = [
            r'\b([A-Z][a-z]+)\s+(Inc|Corp|LLC|Ltd)\b',
            r'\b([A-Z][a-z]+)\s+Technologies?\b',
            r'\b([A-Z][a-z]+)\s+Systems?\b'
        ]
        
        for pattern in company_patterns:
            matches = re.findall(pattern, article['title'])
            for match in matches:
                if isinstance(match, tuple):
                    entities.append(match[0].lower())
                else:
                    entities.append(match.lower())
        
        return entities[:10]  # Limit to 10 entities

# Global news connector instance
news_connector = NewsConnector()

def get_news_connector() -> NewsConnector:
    """Get the global news connector instance"""
    return news_connector


