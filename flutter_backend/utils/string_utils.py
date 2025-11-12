"""
String utility functions for text processing and cleaning.
"""

import re
import string
from typing import List, Set


def clean_text(text: str) -> str:
    """
    Clean and normalize text by removing extra whitespace, 
    special characters, and normalizing case.
    
    Args:
        text: Input text to clean
        
    Returns:
        Cleaned text string
    """
    if not text:
        return ""
    
    # Remove extra whitespace and normalize
    text = re.sub(r'\s+', ' ', text.strip())
    
    # Remove control characters but keep basic punctuation
    text = ''.join(char for char in text if char.isprintable() or char.isspace())
    
    # Normalize to lowercase
    text = text.lower()
    
    return text


def extract_keywords(text: str, min_length: int = 3, max_keywords: int = 10) -> List[str]:
    """
    Extract keywords from text by removing stop words and common words.
    
    Args:
        text: Input text to extract keywords from
        min_length: Minimum length of keywords
        max_keywords: Maximum number of keywords to return
        
    Returns:
        List of extracted keywords
    """
    if not text:
        return []
    
    # Clean the text first
    cleaned_text = clean_text(text)
    
    # Common stop words to filter out
    stop_words = {
        'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 
        'of', 'with', 'by', 'from', 'up', 'about', 'into', 'through', 'during',
        'before', 'after', 'above', 'below', 'between', 'among', 'is', 'are',
        'was', 'were', 'be', 'been', 'being', 'have', 'has', 'had', 'do', 'does',
        'did', 'will', 'would', 'could', 'should', 'may', 'might', 'must', 'can',
        'this', 'that', 'these', 'those', 'i', 'you', 'he', 'she', 'it', 'we',
        'they', 'me', 'him', 'her', 'us', 'them', 'my', 'your', 'his', 'her',
        'its', 'our', 'their', 'mine', 'yours', 'hers', 'ours', 'theirs'
    }
    
    # Split into words and filter
    words = re.findall(r'\b[a-zA-Z]+\b', cleaned_text)
    keywords = [
        word for word in words 
        if len(word) >= min_length and word not in stop_words
    ]
    
    # Remove duplicates while preserving order
    seen = set()
    unique_keywords = []
    for keyword in keywords:
        if keyword not in seen:
            seen.add(keyword)
            unique_keywords.append(keyword)
    
    # Return top keywords
    return unique_keywords[:max_keywords]


def normalize_phone_number(phone: str) -> str:
    """
    Normalize phone number by removing non-digit characters.
    
    Args:
        phone: Phone number string
        
    Returns:
        Normalized phone number with only digits
    """
    if not phone:
        return ""
    
    # Remove all non-digit characters
    digits_only = re.sub(r'\D', '', phone)
    
    return digits_only


def extract_hashtags(text: str) -> List[str]:
    """
    Extract hashtags from text.
    
    Args:
        text: Input text to extract hashtags from
        
    Returns:
        List of hashtags (without the # symbol)
    """
    if not text:
        return []
    
    # Find all hashtags
    hashtags = re.findall(r'#(\w+)', text)
    
    return hashtags


def extract_mentions(text: str) -> List[str]:
    """
    Extract @mentions from text.
    
    Args:
        text: Input text to extract mentions from
        
    Returns:
        List of mentions (without the @ symbol)
    """
    if not text:
        return []
    
    # Find all mentions
    mentions = re.findall(r'@(\w+)', text)
    
    return mentions


def truncate_text(text: str, max_length: int = 100, suffix: str = "...") -> str:
    """
    Truncate text to a maximum length.
    
    Args:
        text: Input text to truncate
        max_length: Maximum length of the result
        suffix: Suffix to add if text is truncated
        
    Returns:
        Truncated text
    """
    if not text or len(text) <= max_length:
        return text
    
    return text[:max_length - len(suffix)] + suffix


def remove_urls(text: str) -> str:
    """
    Remove URLs from text.
    
    Args:
        text: Input text to remove URLs from
        
    Returns:
        Text with URLs removed
    """
    if not text:
        return ""
    
    # Remove URLs
    url_pattern = r'http[s]?://(?:[a-zA-Z]|[0-9]|[$-_@.&+]|[!*\\(\\),]|(?:%[0-9a-fA-F][0-9a-fA-F]))+'
    return re.sub(url_pattern, '', text)


def extract_emails(text: str) -> List[str]:
    """
    Extract email addresses from text.
    
    Args:
        text: Input text to extract emails from
        
    Returns:
        List of email addresses found
    """
    if not text:
        return []
    
    # Email pattern
    email_pattern = r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'
    emails = re.findall(email_pattern, text)
    
    return emails

