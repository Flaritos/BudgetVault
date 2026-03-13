#!/usr/bin/env python3
"""BudgetVault Twitter auto-poster. Run via cron every 15 minutes."""

import json
import os
import sys
import traceback
from datetime import datetime, timedelta
from pathlib import Path
from zoneinfo import ZoneInfo

import tweepy
from dotenv import load_dotenv

SCRIPT_DIR = Path(__file__).parent
ENV_FILE = SCRIPT_DIR / ".env"
TWEETS_FILE = SCRIPT_DIR / "tweets.json"
LOG_FILE = SCRIPT_DIR / "tweet_log.json"
EST = ZoneInfo("America/New_York")
WINDOW_MINUTES = 15


def log_msg(msg: str) -> None:
    """Print a timestamped log message to stdout (captured by cron)."""
    now = datetime.now(EST).strftime("%Y-%m-%d %H:%M:%S %Z")
    print(f"[{now}] {msg}")


def load_env() -> None:
    """Load Twitter credentials from .env file."""
    if not ENV_FILE.exists():
        log_msg(f"ERROR: .env file not found at {ENV_FILE}")
        sys.exit(1)
    load_dotenv(ENV_FILE)
    required = [
        "TWITTER_API_KEY",
        "TWITTER_API_SECRET",
        "TWITTER_ACCESS_TOKEN",
        "TWITTER_ACCESS_TOKEN_SECRET",
    ]
    missing = [k for k in required if not os.getenv(k)]
    if missing:
        log_msg(f"ERROR: Missing environment variables: {', '.join(missing)}")
        sys.exit(1)


def get_tweepy_clients() -> tuple[tweepy.Client, tweepy.API]:
    """Create both v2 Client (for posting) and v1.1 API (for media upload)."""
    api_key = os.environ["TWITTER_API_KEY"]
    api_secret = os.environ["TWITTER_API_SECRET"]
    access_token = os.environ["TWITTER_ACCESS_TOKEN"]
    access_secret = os.environ["TWITTER_ACCESS_TOKEN_SECRET"]

    # v2 client for creating tweets
    client = tweepy.Client(
        consumer_key=api_key,
        consumer_secret=api_secret,
        access_token=access_token,
        access_token_secret=access_secret,
    )

    # v1.1 API for media upload (v2 does not support media upload directly)
    auth = tweepy.OAuth1UserHandler(api_key, api_secret, access_token, access_secret)
    api = tweepy.API(auth)

    return client, api


def load_tweets() -> list[dict]:
    """Load the tweet schedule from tweets.json."""
    if not TWEETS_FILE.exists():
        log_msg(f"ERROR: tweets.json not found at {TWEETS_FILE}")
        sys.exit(1)
    with open(TWEETS_FILE, "r") as f:
        return json.load(f)


def load_log() -> dict:
    """Load the posting log. Returns empty dict if file doesn't exist."""
    if not LOG_FILE.exists():
        return {}
    with open(LOG_FILE, "r") as f:
        return json.load(f)


def save_log(log: dict) -> None:
    """Persist the posting log to disk."""
    with open(LOG_FILE, "w") as f:
        json.dump(log, f, indent=2)


def is_time_to_post(scheduled_date: str, scheduled_time: str, now: datetime) -> bool:
    """Check if now is within a 15-minute window AFTER the scheduled time.

    Args:
        scheduled_date: Date string in YYYY-MM-DD format.
        scheduled_time: Time string in HH:MM format (EST).
        now: Current datetime (timezone-aware, EST).

    Returns:
        True if the current time is >= scheduled time and < scheduled time + 15 min,
        AND the date matches.
    """
    scheduled_dt = datetime.strptime(
        f"{scheduled_date} {scheduled_time}", "%Y-%m-%d %H:%M"
    ).replace(tzinfo=EST)
    window_end = scheduled_dt + timedelta(minutes=WINDOW_MINUTES)
    return scheduled_dt <= now < window_end


def post_tweet(
    client: tweepy.Client,
    api: tweepy.API,
    text: str,
    media_path: str | None = None,
    reply_to_id: str | None = None,
) -> dict:
    """Post a tweet, optionally with media and/or as a reply.

    Returns:
        Dict with 'tweet_id' on success, or 'error' on failure.
    """
    media_ids = None

    # Upload media via v1.1 API if a media path is provided
    if media_path:
        media_file = Path(media_path)
        if not media_file.exists():
            return {"error": f"Media file not found: {media_path}"}
        try:
            media = api.media_upload(filename=str(media_file))
            media_ids = [media.media_id]
            log_msg(f"  Media uploaded: {media.media_id} ({media_file.name})")
        except Exception as e:
            return {"error": f"Media upload failed: {e}"}

    # Post tweet via v2 Client
    try:
        kwargs = {"text": text}
        if media_ids:
            kwargs["media_ids"] = media_ids
        if reply_to_id:
            kwargs["in_reply_to_tweet_id"] = reply_to_id
        response = client.create_tweet(**kwargs)
        tweet_id = str(response.data["id"])
        log_msg(f"  Tweet posted: {tweet_id}")
        return {"tweet_id": tweet_id}
    except Exception as e:
        return {"error": f"Tweet creation failed: {e}"}


def main() -> None:
    """Main entry point. Check schedule and post any due tweets."""
    log_msg("--- Tweet scheduler run started ---")

    load_env()
    tweets = load_tweets()
    log = load_log()
    now = datetime.now(EST)

    log_msg(f"Current EST time: {now.strftime('%Y-%m-%d %H:%M:%S')}")
    log_msg(f"Loaded {len(tweets)} scheduled tweets, {len(log)} already posted")

    # Determine which tweets are due right now
    due_tweets = []
    for tweet in tweets:
        key = tweet["key"]
        if key in log and log[key].get("status") == "posted":
            continue  # Already posted
        if tweet.get("manual"):
            continue  # Manual-gate: skip, must be posted manually
        if is_time_to_post(tweet["date"], tweet["time"], now):
            due_tweets.append(tweet)

    if not due_tweets:
        log_msg("No tweets due right now. Exiting.")
        return

    log_msg(f"Found {len(due_tweets)} tweet(s) due for posting")

    # Authenticate with Twitter
    client, api = get_tweepy_clients()

    for tweet in due_tweets:
        key = tweet["key"]
        log_msg(f"Posting tweet: {key}")

        # Resolve reply_to_key to a tweet ID from the log
        reply_to_id = None
        if tweet.get("reply_to_key"):
            parent_key = tweet["reply_to_key"]
            parent_entry = log.get(parent_key)
            if parent_entry and parent_entry.get("tweet_id"):
                reply_to_id = parent_entry["tweet_id"]
                log_msg(f"  Replying to {parent_key} (tweet {reply_to_id})")
            else:
                log_msg(
                    f"  WARNING: Parent tweet '{parent_key}' not found in log. "
                    f"Posting as standalone tweet instead."
                )

        result = post_tweet(
            client=client,
            api=api,
            text=tweet["text"],
            media_path=tweet.get("media"),
            reply_to_id=reply_to_id,
        )

        # Log the result
        log_entry = {
            "key": key,
            "scheduled_date": tweet["date"],
            "scheduled_time": tweet["time"],
            "posted_at": datetime.now(EST).isoformat(),
        }

        if "tweet_id" in result:
            log_entry["tweet_id"] = result["tweet_id"]
            log_entry["status"] = "posted"
            log_msg(f"  SUCCESS: {key} -> tweet {result['tweet_id']}")
        else:
            log_entry["error"] = result["error"]
            log_entry["status"] = "failed"
            log_msg(f"  FAILED: {key} -> {result['error']}")

        log[key] = log_entry
        save_log(log)  # Save after each tweet in case of crash

    log_msg("--- Tweet scheduler run complete ---")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        log_msg(f"FATAL ERROR: {e}")
        traceback.print_exc()
        sys.exit(1)
