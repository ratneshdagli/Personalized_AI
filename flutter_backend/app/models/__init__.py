try:
    from .user_model import UserProfileModel
    from .notification_model import NotificationModel
    from .message_model import MessageModel

    __all__ = [
        "UserProfileModel",
        "NotificationModel",
        "MessageModel",
    ]
except ImportError as e:
    raise ImportError(
        "Missing dependency when importing app models. "
        "Run `python -m pip install -r requirements.txt` in flutter_backend. "
        f"Original error: {e}"
    ) from e


