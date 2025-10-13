import os

# --- IMPORTANT ---
# 1. Get your free API key from https://gnews.io/
# 2. Set this key as an environment variable named 'GNEWS_API_KEY'
GNEWS_API_KEY = os.getenv("GNEWS_API_KEY")

if not GNEWS_API_KEY:
    print("WARNING: GNEWS_API_KEY environment variable not set. Live news will not be fetched.")

GNEWS_API_URL = "https://gnews.io/api/v4/top-headlines"