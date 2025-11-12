import sys
from pathlib import Path

# Ensure project root and local app package are importable when running `pytest` from flutter_backend/
ROOT = Path(__file__).resolve().parents[1]
APP_DIR = ROOT / "app"

# Prepend to sys.path to take precedence over any installed `app` packages
root_str = str(ROOT)
app_str = str(APP_DIR)
if app_str not in sys.path:
    sys.path.insert(0, app_str)
if root_str not in sys.path:
    sys.path.insert(0, root_str)


