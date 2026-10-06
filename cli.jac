import argparse;
import asyncio;
import getpass;
import json;
import os;
import sys;
import urllib.request;
import from pathlib { Path }
import from jaclang.server { sv_client }
import from core.feed { join, save_task, complete_task, load_planner }

def auth_request(base: str, username: str, password: str) -> str {
    payload = json.dumps({"identity": {"type": "username", "value": username},
        "credential": {"type": "password", "password": password}}).encode();
    request = urllib.request.Request(base + "/api/feed/user/login", data=payload,
        headers={"Content-Type": "application/json"});
    with urllib.request.urlopen(request, timeout=15) as response {
        return str(json.loads(response.read())["data"]["token"]);
    }
}

async def main -> int {
    parser = argparse.ArgumentParser(description="Simon's Scheduler: your student planner in a terminal.");
    parser.add_argument("--url", `default=os.environ.get("PLANNER_URL", "http://127.0.0.1:8000"));
    parser.add_argument("command", choices=["login", "logout", "add", "today", "upcoming", "all", "complete"]);
    parser.add_argument("value", nargs="?", `default="", help="Username, task title, or task ID");
    parser.add_argument("--course", `default="EECS 449");
    parser.add_argument("--due", `default="", help="Campus local time: YYYY-MM-DDTHH:MM");
    parser.add_argument("--priority", choices=["low", "medium", "high"], `default="medium");
    parser.add_argument("--notes", `default="");
    parser.add_argument("--json", action="store_true", dest="as_json");
    args = parser.parse_args();
    base = str(args.url).rstrip("/");
    credentials = Path(os.environ.get("PLANNER_SESSION", str(Path.home() / ".daymark.json")));
    os.environ["JAC_APP_FEED_URL"] = base + "/api/feed";
    try {
        if args.command == "logout" {
            credentials.unlink(missing_ok=True); print("Signed out."); return 0;
        }
        if args.command == "login" {
            if not args.value { parser.error("login needs a username; create your account in the web app first"); }
            password = os.environ.get("PLANNER_PASSWORD") or getpass.getpass("Password: ");
            token = auth_request(base, str(args.value), password);
            sv_client.set_bearer_token(token);
            name = await join(str(args.value));
            fd = os.open(str(credentials), os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600);
            with os.fdopen(fd, "w") as handle { json.dump({"url": base, "token": token}, handle); }
            credentials.chmod(0o600);
            print("Signed in as " + name); return 0;
        }
        if not credentials.exists() { raise ValueError("Run: jac run cli -- login USERNAME"); }
        saved = json.loads(credentials.read_text());
        if saved.get("url") != base { raise ValueError("Please log in to this server first."); }
        sv_client.set_bearer_token(str(saved["token"]));
        if args.command == "add" {
            if not args.value or not args.due { parser.error("add requires a title and --due YYYY-MM-DDTHH:MM"); }
            id = await save_task(str(args.value), str(args.course), str(args.due), str(args.priority), str(args.notes), "");
            print(id);
        } elif args.command == "complete" {
            if not args.value { parser.error("complete requires a task ID (shown by today/upcoming/all)"); }
            await complete_task(str(args.value), True); print("Completed " + str(args.value));
        } else {
            view = "day" if args.command == "today" else str(args.command);
            feed = await load_planner(mode=view, day="", course="", priority="", status="all" if args.command == "all" else "open", shift=0);
            if not feed.viewer { raise ValueError("Session expired. Please log in again."); }
            if args.as_json {
                print(json.dumps([{"id": t.id, "title": t.title, "course": t.course,
                    "due": t.due, "priority": t.priority, "notes": t.notes, "completed": t.completed} for t in feed.tasks]));
            } else {
                for t in feed.tasks {
                    state = "done" if t.completed else "OVERDUE" if t.due < feed.now else "open";
                    print(f"{t.id}  [{state}] {t.title}\n  {t.course} | {t.due} | {t.priority}");
                }
                if not feed.tasks { print("No assignments in this view."); }
            }
        }
        return 0;
    } except Exception as e { print("Simon's Scheduler: " + str(e), file=sys.stderr); return 1; }
}
with entry:__main__ { sys.`exit(asyncio.run(main())); }
