import os
import re
import sys
import argparse

def parse_env_file(filepath=".env"):
    """Simple parser for dotenv files to load into os.environ if python-dotenv is not installed."""
    if not os.path.exists(filepath):
        return
    with open(filepath, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line:
                key, val = line.split("=", 1)
                key = key.strip()
                val = val.strip()
                # Remove quotes if present
                if (val.startswith('"') and val.endswith('"')) or (val.startswith("'") and val.endswith("'")):
                    val = val[1:-1]
                if key not in os.environ:
                    os.environ[key] = val

def parse_social_content(filepath="SOCIAL_CONTENT.md"):
    """Parses SOCIAL_CONTENT.md specifically for the Reddit section."""
    if not os.path.exists(filepath):
        print(f"Error: Source file '{filepath}' not found.")
        sys.exit(1)

    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    # Find the Reddit section
    # Usually starts with '## 🏢 Reddit' or similar and goes until the next '##' or end of file
    pattern = r"##\s*(?:🏢\s*)?Reddit\b(.*?)(?=##|$)"
    match = re.search(pattern, content, re.DOTALL | re.IGNORECASE)
    if not match:
        print("Error: Could not find Reddit section in the file.")
        sys.exit(1)

    reddit_section = match.group(1)

    # Extract subreddits
    # Format: *Subreddits: r/productivity, r/privacy, r/selfimprovement*
    subreddits_match = re.search(r"\*Subreddits:\s*([^*]+)\*", reddit_section, re.IGNORECASE)
    subreddits = []
    if subreddits_match:
        # Extract subreddit names (r/xxx or just xxx)
        raw_subs = subreddits_match.group(1).split(",")
        for sub in raw_subs:
            sub = sub.strip()
            if sub.startswith("r/"):
                sub = sub[2:]
            if sub:
                subreddits.append(sub)
    else:
        print("Warning: Could not find Subreddits list in Reddit section.")

    # Extract Title
    # Format: **Title: title text**
    title_match = re.search(r"\*\*Title:\s*([^*]+)\*\*", reddit_section, re.IGNORECASE)
    title = ""
    if title_match:
        title = title_match.group(1).strip()
    else:
        print("Error: Could not find Title in Reddit section.")
        sys.exit(1)

    # Extract Body
    # Everything after the Title bold section
    body_start_idx = reddit_section.find(title_match.group(0)) + len(title_match.group(0))
    body = reddit_section[body_start_idx:].strip()

    return subreddits, title, body

def main():
    parser = argparse.ArgumentParser(description="Automate posting content from SOCIAL_CONTENT.md to Reddit.")
    parser.add_argument("--file", default="SOCIAL_CONTENT.md", help="Path to markdown content file (default: SOCIAL_CONTENT.md)")
    parser.add_argument("--link", help="Custom link to replace [Link to App] or [Link]")
    parser.add_argument("--dry-run", action="store_true", help="Print post details without submitting to Reddit")
    parser.add_argument("--subreddits", help="Override subreddits to post to (comma separated list)")
    args = parser.parse_args()

    # Load environment variables
    parse_env_file()

    # Try to import python-dotenv just in case it is installed and can refresh/load properly
    try:
        from dotenv import load_dotenv
        load_dotenv()
    except ImportError:
        pass

    # Extract details
    subreddits, title, body = parse_social_content(args.file)

    # Command line overrides
    if args.subreddits:
        subreddits = [s.strip().replace("r/", "") for s in args.subreddits.split(",") if s.strip()]

    if args.link:
        # Replace placeholders like [Link], [Link to App], etc.
        body = re.sub(r"\[Link.*?\]", args.link, body)

    print("=" * 60)
    print("REDDIT POST PREVIEW")
    print("=" * 60)
    print(f"Target Subreddits: {', '.join(f'r/{s}' for s in subreddits)}")
    print(f"Title:             {title}")
    print("-" * 60)
    print("Body Content:")
    print(body)
    print("=" * 60)

    if args.dry_run:
        print("Dry run enabled. Post not submitted.")
        return

    # Check for PRAW
    try:
        import praw
    except ImportError:
        print("\nError: The 'praw' package is required to post to Reddit.")
        print("Please install it using: pip install praw")
        sys.exit(1)

    # Validate environment variables
    client_id = os.environ.get("REDDIT_CLIENT_ID")
    client_secret = os.environ.get("REDDIT_CLIENT_SECRET")
    username = os.environ.get("REDDIT_USERNAME")
    password = os.environ.get("REDDIT_PASSWORD")
    user_agent = os.environ.get("REDDIT_USER_AGENT", "OasisPosterAgent:v1.0")

    missing = []
    if not client_id: missing.append("REDDIT_CLIENT_ID")
    if not client_secret: missing.append("REDDIT_CLIENT_SECRET")
    if not username: missing.append("REDDIT_USERNAME")
    if not password: missing.append("REDDIT_PASSWORD")

    if missing:
        print(f"\nError: Missing Reddit credentials in environment variables: {', '.join(missing)}")
        print("Please add these to your .env file.")
        print("\nTo get Reddit API credentials:")
        print("1. Go to https://www.reddit.com/prefs/apps")
        print("2. Click 'are you a developer? create another app...' button at the bottom.")
        print("3. Fill in name, select 'script', description, and set redirect uri to http://localhost:8080")
        print("4. Use the ID under 'personal use script' as REDDIT_CLIENT_ID.")
        print("5. Use the 'secret' as REDDIT_CLIENT_SECRET.")
        sys.exit(1)

    # Initialize Reddit API
    print("Authenticating with Reddit...")
    try:
        reddit = praw.Reddit(
            client_id=client_id,
            client_secret=client_secret,
            password=password,
            user_agent=user_agent,
            username=username
        )
        # Verify credentials
        me = reddit.user.me()
        print(f"Successfully authenticated as /u/{me.name}")
    except Exception as e:
        print(f"Authentication failed: {e}")
        sys.exit(1)

    # Post to subreddits
    for sub_name in subreddits:
        print(f"Posting to r/{sub_name}...")
        try:
            subreddit = reddit.subreddit(sub_name)
            submission = subreddit.submit(title=title, selftext=body)
            print(f"Success! Posted to r/{sub_name}: {submission.url}")
        except Exception as e:
            print(f"Failed to post to r/{sub_name}: {e}")

if __name__ == "__main__":
    main()
