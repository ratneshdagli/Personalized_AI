import spacy
from typing import List
from models import FeedItem
from datetime import datetime, timedelta

# Load the small English spaCy model
nlp = spacy.load("en_core_web_sm")

# Define keywords and source scores for personalization
# In a real app, this would come from a user's profile
KEYWORD_SCORES = {
    "assignment": 25,
    "due": 25,
    "submit": 20,
    "deadline": 30,
    "hiring": 15,
    "internship": 15,
}
SOURCE_SCORES = {"Gmail": 20, "Reddit": 10, "Instagram": 5, "News": 2}
URGENCY_BOOST = 40  # Extra points for items due within 24 hours


def rank_feed_items(items: List[FeedItem]) -> List[FeedItem]:
    """
    Ranks feed items based on a scoring system and returns them sorted.
    """
    ranked_items = []

    for item in items:
        score = 0
        
        # 1. Score based on source
        score += SOURCE_SCORES.get(item.source, 0)

        doc = nlp(item.summary.lower())
        
        # 2. Score based on keywords
        for token in doc:
            if token.text in KEYWORD_SCORES:
                score += KEYWORD_SCORES[token.text]

        # 3. Check for urgency (due within 24 hours)
        is_urgent = False
        for ent in doc.ents:
            if ent.label_ in ["DATE", "TIME"]:
                # This is a simple check; a real app would use more robust date parsing
                if "tomorrow" in ent.text or "today" in ent.text:
                    is_urgent = True
                    break
        
        if is_urgent:
            score += URGENCY_BOOST

        # Assign a new priority based on score thresholds
        if score > 50:
            item.priority = 1  # High
        elif score > 20:
            item.priority = 2  # Medium
        else:
            item.priority = 3  # Low
        
        ranked_items.append(item)

    # Sort items by priority (1 is highest) and then by original date
    ranked_items.sort(key=lambda x: (x.priority, x.date), reverse=False)
    
    return ranked_items