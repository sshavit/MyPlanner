# SiMinute — Personal Student Planner

![SiMinute](assets/timon-logo.png)

**Name:** Simon Shavit
**UMID:** 22515289

SiMinute is a personal coursework planner built with Jac. It helps students
organize assignments and study work from a web browser, an iPhone app, or the
command line. All three interfaces use the same authenticated Jac backend and
persist data between sessions.

## Features

- Create, edit, complete, reopen, and delete assignments.
- Record a title, course, due date and time, priority, and notes.
- View dashboard, daily, weekly, and all-task lists.
- Filter tasks by course, priority, or completion status.
- Track overdue and upcoming work.

SiMinute uses one shared Jac backend to keep planning data synchronized across all four interfaces. The server handles authentication, task persistence, filtering, daily and weekly views, completion status, and optional AI-generated study steps. The web frontend provides the complete planning experience for creating and organizing assignments, while the mobile app makes it convenient to check or update tasks from an iPhone. The CLI supports quick actions such as adding an assignment, viewing today’s work, and marking tasks complete from a terminal. What makes SiMinute impressive is that all three clients work with the same account and data, so a task added on one platform is immediately available on the others. It combines a practical student-focused workflow with persistent storage, multiple access points, and an optional AI study coach.

## Prerequisites

- WSL or Linux
- Jac `0.37.23`
- A browser for the web interface
- For the mobile app: an iPhone with Expo Go
- For the AI study coach: an `OPENAI_API_KEY` environment variable

## Install and run the web app

From the repository root:

```bash
jac --version
jac install
jac run
```

Open <http://localhost:8000> in a browser. Create an account and sign in.
Keep the `jac run` terminal open while using the app. The first startup may
take longer while Jac prepares its local database and build tools.

To use a different timezone, set it before starting the server:

```bash
export PLANNER_TIMEZONE="America/New_York"
jac run
```

The default timezone is `America/New_York`. Enter due dates as
`YYYY-MM-DDTHH:MM`, for example `2026-10-09T23:59`.

## CLI

Start the server with `jac run`, then use the CLI from another terminal. Create
an account in the web app first:

```bash
jac run cli -- login alice
jac run cli -- add "Finish planner" --course "EECS 449" \
  --due "2026-10-09T23:59" --priority high
jac run cli -- today
jac run cli -- upcoming
jac run cli -- all
jac run cli -- complete TASK_ID
jac run cli -- logout
```

The `complete` command uses the task ID shown by `all`. For a different server,
use `--url` or set `PLANNER_URL`:

```bash
jac run cli -- --url http://HOST:8000 login alice
```

The CLI stores its login token in `~/.timon.json`. Use `--json` with `all` for
machine-readable output.

## iPhone app with Expo Go

Keep the web server running in one terminal:

```bash
jac run
```

In a second terminal, set the computer's LAN address so the iPhone can reach
both the planner server and Expo:

```bash
export JAC_RN_DEV_HOST=192.168.1.100
export REACT_NATIVE_PACKAGER_HOSTNAME="$JAC_RN_DEV_HOST"
jac run --dev --platform ios mobile
```

Replace `192.168.1.100` with the computer address reachable from the iPhone.
Scan the Expo Go QR code, or open the displayed `exp://` address in Expo Go.
In SiMinute, enter the planner server address:

```text
http://192.168.1.100:8000
```

Replace the address with the same reachable computer address, then sign in
with the account created on the web app. The phone and computer must be on a
network that allows access to ports `8000` and `8081`.

To preview the mobile interface in a browser instead:

```bash
jac run --dev --platform web mobile
```

## AI study coach

Set an API key before starting the server:

```bash
export OPENAI_API_KEY="your-key"
jac run
```

On an assignment, choose **Break into steps** to review suggested study
sessions before adding them to the planner. The AI feature is optional; all
normal planning features work without it.

## How the components fit together

- `core/feed.jac` contains the planning service, persistence, authentication,
  task operations, views, and AI study-step workflow.
- `web.jac` provides the browser application.
- `mobile.jac` provides the Expo/React Native mobile application.
- `cli.jac` provides terminal commands for the same planner.
- `jac.toml` configures the web, mobile, CLI, and backend services.

The web app, mobile app, and CLI connect to the same Jac service, so a task
created in one interface is available in the others after refreshing or
requesting the latest task list.
