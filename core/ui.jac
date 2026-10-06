import from "@jac/mobui" {
    View,
    Text,
    TextInput,
    Pressable,
    ScrollView,
    Modal,
    useWindowDimensions
}
import from "@jac/runtime" {
    jacSetToken,
    __getApiBaseUrl,
    jacLogout,
    jacIsLoggedIn,
    __getLocalStorage,
    __setLocalStorage
}
import from core.feed { Planner, TaskView, Breakdown, join, save_task, create_recurring, update_series, complete_task, delete_task, delete_series, load_planner, break_down, accept_steps }
import from core.theme { S, C, SD, CD }

def Button(
    label: str, action: Callable, quiet: bool = False, disabled: bool = False,
    dark: bool = False
) -> JsxElement {
    T = SD if dark else S;
    return
        <Pressable
            accessibilityRole="button"
            accessibilityLabel={label}
            disabled={disabled}
            onPress={action}
            style={[
                T.button,
                T.quiet if quiet else {},
                {"opacity": 0.45 if disabled else 1}
            ]}
        >
            <Text style={[T.buttonText, T.quietText if quiet else {}]}>{label}</Text>
        </Pressable>;
}

def Field(label: str, value: str, change: Callable, multiline: bool = False, dark: bool = False) -> JsxElement {
    T = SD if dark else S;
    P = CD if dark else C;
    return <View style={{"gap": 6}}>
        <Text style={T.name}>{label}</Text>
        <TextInput accessibilityLabel={label} value={value} onChangeText={change}
            style={[T.input, T.composer if multiline else {}]} multiline={multiline}
            autoCapitalize="none" placeholder={label} placeholderTextColor={P.muted}/>
    </View>;
}

def CheckRow(label: str, checked: bool, action: Callable, dark: bool = False) -> JsxElement {
    T = SD if dark else S;
    P = CD if dark else C;
    return <Pressable accessibilityRole="checkbox" accessibilityLabel={label}
        accessibilityState={{"checked": checked}} onPress={action}
        style={[T.row, {"paddingVertical": 5}]}>
        <View style={{"width": 21, "height": 21, "borderWidth": 2, "borderColor": P.accent, "borderRadius": 5,
            "backgroundColor": P.accent if checked else P.card, "alignItems": "center", "justifyContent": "center"}}>
            {<Text style={{"color": P.buttonInk, "fontSize": 13, "fontWeight": "800"}}>✓</Text> if checked else None}
        </View>
        <Text style={T.name}>{label}</Text>
    </Pressable>;
}

def TimePicker(value: str, change: Callable, dark: bool = False) -> JsxElement {
    T = SD if dark else S;
    P = CD if dark else C;
    date = value[:10] if len(value) >= 10 else "2026-01-01";
    hour24 = int(value[11:13]) if len(value) >= 13 else 12;
    hour12 = hour24 % 12 if hour24 % 12 else 12;
    minute = value[14:16] if len(value) >= 16 else "00";
    period = "AM" if hour24 < 12 else "PM";
    hours = [str(h) for h in range(1, 13)];
    minutes = [f"{m:02d}" for m in range(0, 60, 5)];
    def setTime(nextHour: str = str(hour12), nextMinute: str = minute, nextPeriod: str = period) {
        h12 = int(nextHour);
        h24 = h12 % 12 + (12 if nextPeriod == "PM" else 0);
        change(date + "T" + f"{h24:02d}" + ":" + nextMinute[:2]);
    }
    return <View style={{"gap": 6}}>
        <Text style={T.name}>Due date and time</Text>
        <input aria-label="Due date" type="date" value={date} onChange={lambda (e: ChangeEvent) { change((e.target.value as str) + "T" + f"{hour24:02d}" + ":" + minute[:2]); }}
            style={{"padding": 13, "borderRadius": 12, "border": "1px solid " + P.line, "fontSize": 15, "backgroundColor": P.input, "color": P.ink, "colorScheme": "dark" if dark else "light"}}/>
        <View style={T.row}>
            <View style={{"flex": 1, "gap": 6}}>
                <Text style={T.name}>Hour</Text>
                <select aria-label="Due hour" value={str(hour12)} onChange={lambda (e: ChangeEvent) { setTime(e.target.value as str); }} style={{"padding": 13, "borderRadius": 12, "border": "1px solid " + P.line, "fontSize": 15, "backgroundColor": P.input, "color": P.ink, "colorScheme": "dark" if dark else "light"}}>
                    {for h in hours { <option key={h} value={h}>{h}</option> }}
                </select>
            </View>
            <View style={{"flex": 1, "gap": 6}}>
                <Text style={T.name}>Minute</Text>
                <select aria-label="Due minute" value={minute} onChange={lambda (e: ChangeEvent) { setTime(str(hour12), e.target.value as str); }} style={{"padding": 13, "borderRadius": 12, "border": "1px solid " + P.line, "fontSize": 15, "backgroundColor": P.input, "color": P.ink, "colorScheme": "dark" if dark else "light"}}>
                    {for m in minutes { <option key={m} value={m}>{m}</option> }}
                    <option value="59">59</option>
                </select>
            </View>
            <View style={{"flex": 1, "gap": 6}}>
                <Text style={T.name}>AM / PM</Text>
                <select aria-label="Due AM or PM" value={period} onChange={lambda (e: ChangeEvent) { setTime(str(hour12), minute, e.target.value as str); }} style={{"padding": 13, "borderRadius": 12, "border": "1px solid " + P.line, "fontSize": 15, "backgroundColor": P.input, "color": P.ink, "colorScheme": "dark" if dark else "light"}}>
                    <option value="AM">AM</option><option value="PM">PM</option>
                </select>
            </View>
        </View>
    </View>;
}

def monthLabel(day: str) -> str {
    if len(day) < 7 { return "Calendar"; }
    months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
    return months[int(day[5:7]) - 1] + " " + day[:4];
}

def displayTime(due: str) -> str {
    if len(due) < 16 { return due; }
    hour = int(due[11:13]);
    return str(hour % 12 if hour % 12 else 12) + ":" + due[14:16] + (" AM" if hour < 12 else " PM");
}

def daysInMonth(year: int, month: int) -> int {
    if month == 2 {
        return 29 if year % 4 == 0 and (year % 100 != 0 or year % 400 == 0) else 28;
    }
    return 30 if month in [4, 6, 9, 11] else 31;
}

def shiftMonth(day: str, shift: int) -> str {
    if len(day) < 10 { return day; }
    index = int(day[:4]) * 12 + int(day[5:7]) - 1 + shift;
    year = index // 12;
    month = index % 12 + 1;
    return f"{year:04d}-{month:02d}-01";
}

def calendarDays(day: str) -> list[str] {
    if len(day) < 10 { return []; }
    year = int(day[:4]);
    month = int(day[5:7]);
    prior = shiftMonth(day, -1);
    following = shiftMonth(day, 1);
    offsets = [0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4];
    weekdayYear = year - 1 if month < 3 else year;
    firstWeekday = (weekdayYear + weekdayYear // 4 - weekdayYear // 100 + weekdayYear // 400 + offsets[month - 1] + 1) % 7;
    currentCount = daysInMonth(year, month);
    priorCount = daysInMonth(int(prior[:4]), int(prior[5:7]));
    result: list[str] = [];
    for i in range(42) {
        number = i - firstWeekday + 1;
        if number < 1 {
            result.append(prior[:7] + f"-{priorCount + number:02d}");
        } elif number > currentCount {
            result.append(following[:7] + f"-{number - currentCount:02d}");
        } else {
            result.append(f"{year:04d}-{month:02d}-{number:02d}");
        }
    }
    return result;
}

def:pub PlannerApp(remote: bool = False) -> JsxElement {
    has feed: Planner = Planner(), username: str = "", password: str = "",
        signup: bool = False, logged: bool = False, busy: bool = False,
        loading: bool = True, error: str = "", notice: str = "",
        server: str = "", connected: bool = not remote,
        mode: str = "calendar", day: str = "", courseFilter: str = "",
        priorityFilter: str = "", status: str = "open",
        title: str = "", course: str = "EECS 449", due: str = "", notes: str = "",
        priority: str = "medium", editing: str = "", deleting: str = "",
        ai: Breakdown = Breakdown(), aiTask: str = "", aiTitle: str = "",
        composerOpen: bool = False, filtersOpen: bool = False,
        editorPane: str = "main", moreTask: str = "",
        recurring: bool = False, repeatFrequency: str = "weekly",
        repeatCount: int = 8, editFuture: bool = False,
        jumpOpen: bool = False, jumpDate: str = "",
        dragStart: int = -1, dragEnd: int = -1,
        section: str = "assignments", darkMode: bool = False;
    wide = useWindowDimensions().width >= 1000;
    T = SD if darkMode else S;
    P = CD if darkMode else C;
    activeFilters = int(courseFilter != "") + int(priorityFilter != "") + int(status != "open");
    visibleTasks = feed.tasks if mode not in ["calendar", "week", "day"] else [];

    async def refresh(shift: int = 0) {
        if not connected { loading = False; return; }
        loading = True;
        try {
            feed = await load_planner(mode, day,
                courseFilter, priorityFilter, status, shift);
            error = "";
            if shift != 0 { day = feed.days[0] if mode == "week" and len(feed.days) == 7 else feed.selected; }
            if not due { due = feed.today + "T12:00"; }
            if logged and not feed.viewer { jacLogout(); logged = False; }
        } except Exception as e {
            error = "Could not load planner. Check your connection or sign in again. " + str(e);
        } finally { loading = False; }
    }

    async def connect {
        if not server.startswith("http://") and not server.startswith("https://") {
            error = "Enter a server address starting with http:// or https://."; return;
        }
        server = server.rstrip("/");
        globalThis.__JAC_API_BASE_URL__ = server;
        __setLocalStorage("planner_server", server);
        jacLogout(); logged = False; connected = True; error = "";
    }

    can with entry {
        logged = jacIsLoggedIn();
        darkMode = __getLocalStorage("daymark_dark_mode") == "true";
        username = __getLocalStorage("planner_username") or "";
        server = __getLocalStorage("planner_server") or "http://localhost:8000";
        if remote and __getLocalStorage("planner_server") {
            globalThis.__JAC_API_BASE_URL__ = server; connected = True;
        }
    }
    can with [mode, day, courseFilter, priorityFilter, status, connected] entry { refresh(); }

    async def authenticate {
        if busy {
            return;
        }
        busy = True;
        error = "";
        try {
            if not username.strip() or not password {
                error = "Enter a username and password.";
                return;
            }
            identity = {"type": "username", "value": username.strip()};
            payload: dict[str, any] = {
                "credential": {"type": "password", "password": password}
            };
            if signup {
                payload["identities"] = [identity];
            } else {
                payload["identity"] = identity;
            }
            response = await fetch(
                __getApiBaseUrl()
                    + "/api/feed/user/"
                    + ("register" if signup else "login"),
                {
                    "method": "POST",
                    "headers": {"Content-Type": "application/json"},
                    "body": JSON.stringify(payload)
                }
            );
            result: any = await response.json();
            if not response.ok {
                error = result.error.message or "Could not sign in.";
                return;
            }
            jacSetToken(result.data.token);
            username = await join(username.strip());
            __setLocalStorage("planner_username", username);
            logged = True;
            password = "";
            await refresh();
        } except Exception {
            error = "Could not sign in. Check your connection and try again.";
        } finally {
            busy = False;
        }
    }

    def resetForm {
        editing = ""; title = ""; notes = ""; priority = "medium";
        due = feed.today + "T12:00";
        recurring = False; repeatFrequency = "weekly"; repeatCount = 8;
        editFuture = False; editorPane = "main";
    }
    def openComposer {
        resetForm();
        if mode == "day" and feed.selected { due = feed.selected + "T12:00"; }
        error = ""; composerOpen = True;
    }
    def edit(task: TaskView) {
        editing = task.id; title = task.title; course = task.course;
        due = task.due; notes = task.notes; priority = task.priority;
        recurring = bool(task.series_id); repeatFrequency = task.repeat;
        editFuture = False; editorPane = "main";
        error = ""; composerOpen = True;
    }
    def toggleRecurring {
        nextValue = not recurring;
        recurring = nextValue;
        if nextValue { editorPane = "repeat"; }
    }
    async def act(kind: str, id: str = "", done: bool = True) {
        if busy { return; }
        busy = True; error = ""; notice = "";
        try {
            if kind == "save" {
                if editing and editFuture {
                    await update_series(editing, title, course, due, priority, notes);
                } elif editing {
                    await save_task(title, course, due, priority, notes, editing);
                } elif recurring {
                    await create_recurring(title, course, due, priority, notes, repeatFrequency, repeatCount);
                } else {
                    await save_task(title, course, due, priority, notes);
                }
                notice = "Future dates updated." if editing and editFuture else
                    str(repeatCount) + " repeating dates added." if recurring and not editing else
                    "Assignment saved.";
                resetForm(); composerOpen = False;
            } elif kind == "complete" {
                await complete_task(id, done);
                notice = "Assignment completed. Nice work!" if done else "Assignment reopened.";
            } elif kind == "delete" {
                await delete_task(id); deleting = "";
                if editing == id { resetForm(); }
                if aiTask == id { aiTask = ""; ai = Breakdown(); }
                notice = "Assignment deleted.";
            } elif kind == "delete_series" {
                await delete_series(id); deleting = "";
                notice = "This and future occurrences deleted.";
            } elif kind == "ai" {
                ai = await break_down(id); aiTask = id;
            } elif kind == "accept" {
                await accept_steps(aiTask, ai.steps); aiTask = ""; ai = Breakdown();
                notice = "Study steps added with the assignment’s deadline. Edit them to schedule earlier work sessions.";
            }
            await refresh();
        } except Exception as e { error = str(e); }
        finally { busy = False; }
    }
    async def logout {
        jacLogout(); logged = False; password = ""; feed = Planner();
        resetForm(); composerOpen = False; filtersOpen = False;
        aiTask = ""; section = "assignments"; error = ""; notice = ""; await refresh();
    }
    def toggleDarkMode {
        nextMode = not darkMode;
        darkMode = nextMode;
        __setLocalStorage("daymark_dark_mode", "true" if nextMode else "false");
    }
    def navigate(shift: int) {
        if mode == "calendar" {
            day = shiftMonth(feed.selected if feed.selected else feed.today, shift);
        } else {
            day = feed.days[0] if mode == "week" and len(feed.days) == 7 else feed.selected;
            refresh(shift * (7 if mode == "week" else 1));
        }
    }
    def jumpToDate {
        if len(jumpDate) == 10 {
            day = jumpDate;
            jumpOpen = False;
        }
    }
    def pickCalendarTime(hour: int) {
        h24 = hour % 12 + (12 if hour >= 12 else 0);
        date = feed.selected if feed.selected else feed.today;
        due = date + "T" + f"{h24:02d}" + ":00";
        title = ""; course = "EECS 449"; notes = ""; priority = "medium";
        recurring = False; editing = ""; editorPane = "main";
        composerOpen = True;
    }

    return <ScrollView style={T.screen} contentContainerStyle={[T.page, {"minHeight": "100vh", "alignContent": "flex-start"}]} keyboardShouldPersistTaps="handled">
        <View style={T.header}>
            <View style={T.row}>
                <View style={T.brandMark}><Text style={T.brandMarkText}>SS</Text></View>
                <View><Text style={T.brand}>Simon's Scheduler</Text><Text style={T.small}>YOUR STUDENT WORKSPACE</Text></View>
            </View>
            {<Text style={T.eyebrow}>PLAN WITH CLARITY  /  MOVE WITH PURPOSE</Text> if wide else None}
        </View>
        {<View style={T.row}>
            <Button dark={darkMode} label="Assignments" quiet={section != "assignments"} action={lambda { section = "assignments"; }}/>
            <Button dark={darkMode} label="Settings" quiet={section != "settings"} action={lambda { section = "settings"; }}/>
        </View> if logged and connected else None}
        {<View style={T.hero}>
            <View style={T.heroGlow}/>
            <View style={T.heroGlowSmall}/>
            <Text style={T.heroEyebrow}>{"WELCOME BACK, " + feed.viewer.upper() if logged and feed.viewer else "A CLEARER WAY TO PLAN"}</Text>
            <Text accessibilityRole="header" style={T.heroTitle}>{"Make room for what matters." if logged else "Your semester, beautifully organized."}</Text>
            <Text style={T.heroText}>See what is due, find your focus, and make progress one step at a time.</Text>
            {<View style={[T.row, {"marginTop": 6}]}>
                <View style={{"backgroundColor": "#FFFFFF22", "borderRadius": 10, "paddingHorizontal": 12, "paddingVertical": 8}}><Text style={{"color": "#FFFFFF", "fontWeight": "700"}}>{feed.today}</Text></View>
                <View style={{"backgroundColor": "#FFFFFF22", "borderRadius": 10, "paddingHorizontal": 12, "paddingVertical": 8}}><Text style={{"color": "#FFFFFF", "fontWeight": "700"}}>{str(feed.total) + " assignments in your space"}</Text></View>
            </View> if logged else None}
        </View> if not logged else None}
        {<Text accessibilityRole="alert" style={T.error}>{error}</Text> if error else None}
        {<Text accessibilityRole="status" style={T.success}>{notice}</Text> if notice else None}
        {<View style={[T.card, {"maxWidth": 520, "width": "100%", "alignSelf": "center"}]}>
            <Text style={T.eyebrow}>CONNECT YOUR SPACE</Text>
            <Text style={T.heading}>Connect to your planner</Text>
            <Field dark={darkMode} label="Server address" value={server} change={lambda (t: str) { server = t; }}/>
            <Button dark={darkMode} label="Connect" action={connect}/>
        </View> if not connected else None}
        {<View style={[T.card, {"maxWidth": 520, "width": "100%", "alignSelf": "center", "padding": 30}]}>
            <Text style={T.eyebrow}>YOUR ACCOUNT</Text>
            <Text style={T.heading}>{"Start a fresh page." if signup else "Welcome back."}</Text>
            <Text style={T.body}>One private planner, on your laptop, phone, and terminal.</Text>
            <Field dark={darkMode} label="Username" value={username} change={lambda (t: str) { username = t; }}/>
            <Text style={T.name}>Password</Text>
            <TextInput accessibilityLabel="Password" style={T.input} value={password}
                secureTextEntry={True} onChangeText={lambda (t: str) { password = t; }} onSubmitEditing={authenticate}/>
            <Button dark={darkMode} label={"Please wait…" if busy else "Create account" if signup else "Sign in"}
                action={authenticate} disabled={busy}/>
            <Button dark={darkMode} label={"I already have an account" if signup else "New here? Create an account"}
                quiet={True} action={lambda { signup = not signup; error = ""; }} disabled={busy}/>
        </View> if connected and not logged else None}
        {<View style={T.stack}>
            <View style={T.between}>
                <View><Text style={T.eyebrow}>YOUR WORKSPACE</Text><Text style={T.heading}>Calendar</Text></View>
                <View style={T.row}>
                    <Button dark={darkMode} label="+ Add assignment" action={openComposer} disabled={busy or loading}/>
                </View>
            </View>
            <View style={[T.row, {"gap": 8}]}>
                <Text style={T.small}>{str(feed.upcoming) + " due soon"}</Text>
                <Text style={T.small}>·</Text>
                <Text style={T.small}>{str(feed.overdue) + " overdue"}</Text>
                <Text style={T.small}>·</Text>
                <Text style={T.small}>{str(feed.completed) + "/" + str(feed.total) + " done"}</Text>
            </View>
            <View style={[T.between, {"gap": 8}]}>
                <ScrollView horizontal={True} showsHorizontalScrollIndicator={False} style={{"flex": 1}} contentContainerStyle={{"gap": 6, "alignItems": "center"}}>
                    {[<Button dark={darkMode} key={v} label={v.title()} quiet={mode != v}
                        action={lambda { mode = v; day = feed.today if v == "calendar" else feed.selected; }} disabled={loading or busy}/> for v in ["calendar", "week", "day"]]}
                </ScrollView>
                <Button dark={darkMode} label={"Filters (" + str(activeFilters) + ")" if activeFilters else "Filters"} quiet={True} action={lambda { filtersOpen = True; }}/>
            </View>
                    {<View style={[T.between, T.card, {"paddingVertical": 12}]}>
                        <Button dark={darkMode} label={"Previous month" if mode == "calendar" else "Previous"} quiet={True} disabled={loading} action={lambda { navigate(-1); }}/>
                        <Text style={T.heading}>{monthLabel(feed.selected) if mode == "calendar" else feed.days[0] + " — " + feed.days[6] if mode == "week" and len(feed.days) == 7 else feed.selected}</Text>
                        <View style={T.row}>
                            <Button dark={darkMode} label="Today" quiet={True} action={lambda { day = feed.today; }}/>
                            <Button dark={darkMode} label="Jump to date" quiet={True} action={lambda { jumpDate = feed.selected; jumpOpen = True; }}/>
                            <Button dark={darkMode} label={"Next month" if mode == "calendar" else "Next"} quiet={True} disabled={loading} action={lambda { navigate(1); }}/>
                        </View>
                    </View> if mode in ["day", "week", "calendar"] else None}
                    {<View style={[T.card, {"padding": 12, "gap": 8}]}>
                        <View style={{"flexDirection": "row"}}>
                            {[<Text key={name} style={[T.eyebrow, {"width": "14.285%", "textAlign": "center", "paddingVertical": 9}]}>{name}</Text> for name in ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]]}
                        </View>
                        {<View style={{"flexDirection": "row", "flexWrap": "wrap"}}>
                            {for calendar_day in calendarDays(feed.selected) {
                                <Pressable key={calendar_day} accessibilityRole="button" accessibilityLabel={"View assignments for " + calendar_day}
                                    onPress={lambda { day = calendar_day; mode = "day"; }}
                                    style={{"width": "14.285%", "minHeight": 104 if wide else 62, "padding": 6, "borderWidth": 1, "borderColor": P.line, "backgroundColor": P.pale if calendar_day == feed.today else P.input if calendar_day[:7] != feed.selected[:7] else P.card}}>
                                    <Text style={[T.name, {"color": P.accent if calendar_day == feed.today else P.muted if calendar_day[:7] != feed.selected[:7] else P.ink}]}>{calendar_day[8:10]}</Text>
                                    {<Text style={[T.small, {"fontWeight": "700", "color": P.purple}]}>{str(len([calendar_task for calendar_task in feed.tasks if calendar_task.due[:10] == calendar_day])) + " due"}</Text> if not wide and len([calendar_task for calendar_task in feed.tasks if calendar_task.due[:10] == calendar_day]) else None}
                                    {[<Text key={calendar_task.id} style={[T.small, {"backgroundColor": P.pale, "padding": 4, "borderRadius": 5, "color": P.accent, "textDecorationLine": "line-through" if calendar_task.completed else "none"}]}>{displayTime(calendar_task.due) + " " + calendar_task.title + (" ↻" if calendar_task.series_id else "")}</Text> for calendar_task in feed.tasks if wide and calendar_task.due[:10] == calendar_day]}
                                </Pressable>
                            }}
                        </View> if mode == "calendar" else None}
                        {<View style={{"flexDirection": "row"}}>
                            {for calendar_day in feed.days {
                                <Pressable key={calendar_day} accessibilityRole="button" accessibilityLabel={"View assignments for " + calendar_day}
                                    onPress={lambda { day = calendar_day; mode = "day"; }}
                                    style={{"flex": 1, "minWidth": 42, "minHeight": 116 if mode == "week" else 84, "padding": 7, "gap": 5, "borderWidth": 1, "borderColor": P.line, "borderRadius": 8, "backgroundColor": P.pale if calendar_day == feed.today else P.card}}>
                                    <Text style={[T.eyebrow, {"textAlign": "center"}]}>{calendar_day[5:7] + "/" + calendar_day[8:10]}</Text>
                                    {<Text style={T.small}>{str(len([calendar_task for calendar_task in feed.tasks if calendar_task.due[:10] == calendar_day])) + " due"}</Text> if len([calendar_task for calendar_task in feed.tasks if calendar_task.due[:10] == calendar_day]) else <Text style={T.small}>—</Text>}
                                </Pressable>
                            }}
                        </View> if mode == "week" else None}
                        {<View style={{"gap": 8, "padding": 8}}>
                            <Text style={T.eyebrow}>{"TODAY" if feed.selected == feed.today else "SELECTED DAY"}</Text>
                            <Text style={T.small}>Drag across time slots to select a due time.</Text>
                            <View style={{"gap": 2}}>
                                {for slot in range(24) {
                                    <div key={slot} onMouseDown={lambda (e: MouseEvent) { dragStart = slot; dragEnd = slot; }}
                                        onMouseEnter={lambda (e: MouseEvent) { if dragStart >= 0 { dragEnd = slot; } }}
                                        onMouseUp={lambda (e: MouseEvent) { if dragStart >= 0 { pickCalendarTime(min(dragStart, slot)); dragStart = -1; dragEnd = -1; } }}
                                        style={{"height": 34, "paddingHorizontal": 10, "justifyContent": "center", "borderLeftWidth": 3, "borderLeftColor": P.accent, "borderBottomWidth": 1, "borderBottomColor": P.line, "backgroundColor": P.pale if dragStart >= 0 and slot >= min(dragStart, dragEnd) and slot <= max(dragStart, dragEnd) else P.card}}>
                                        <Text style={T.small}>{str(slot % 12 if slot % 12 else 12) + (":00" if slot == dragStart else "") + (" AM" if slot < 12 else " PM")}</Text>
                                    </div>
                                }}
                            </View>
                            {<Text style={T.small}>No assignments scheduled.</Text> if not [calendar_task for calendar_task in feed.tasks if calendar_task.due[:10] == feed.selected] else None}
                            {[<View key={calendar_task.id} style={[T.between, {"padding": 10, "borderRadius": 9, "backgroundColor": P.pale}]}>
                                <View style={{"gap": 3}}><Text style={T.name}>{calendar_task.title}</Text><Text style={T.small}>{calendar_task.course + " · " + displayTime(calendar_task.due)}</Text></View>
                                <Text style={T.eyebrow}>{calendar_task.priority.upper()}</Text>
                            </View> for calendar_task in feed.tasks if calendar_task.due[:10] == feed.selected]}
                        </View> if mode == "day" else None}
                    </View> if mode in ["calendar", "week", "day"] and not loading else None}
                    {<Text style={T.small}>{str(len(feed.tasks)) + " assignments in this view"}</Text> if mode not in ["calendar", "week", "day"] else None}
                    {<Text style={T.small}>Loading your planner…</Text> if loading else None}
                    {<View style={[T.card, {"alignItems": "center", "paddingVertical": 40}]}><Text style={{"fontSize": 32, "color": P.purple}}>✦</Text><Text style={T.heading}>A little breathing room.</Text>
                        <Text style={[T.body, {"textAlign": "center"}]}>No assignments match this view. Add something new or adjust the filters.</Text></View>
                        if not loading and not feed.tasks and mode not in ["calendar", "week", "day"] else None}
                    {for task in visibleTasks {
                        <View key={task.id} testID={"task-" + task.id} style={[T.card,
                            {"padding": 14, "gap": 8, "borderLeftWidth": 4, "borderLeftColor": "#EF7589" if not task.completed and task.due < feed.now else P.purple if task.priority == "high" else P.blue}]}>
                            <View style={T.between}>
                                <View style={{"flex": 1, "minWidth": 180, "gap": 4}}>
                                    <Text style={[T.name, {"fontSize": 16, "textDecorationLine": "line-through" if task.completed else "none"}]}>{task.title}</Text>
                                    <Text style={T.small}>{task.course + "  ·  " + task.due[:10] + "  ·  " + displayTime(task.due) + ("  ·  ↻ " + task.repeat if task.series_id else "")}</Text>
                                </View>
                                <View style={T.row}>
                                    <Button dark={darkMode} label={"Reopen" if task.completed else "Done"} action={lambda { act("complete", task.id, not task.completed); }} disabled={busy}/>
                                    <Button dark={darkMode} label={"Less" if moreTask == task.id else "More"} quiet={True} action={lambda { moreTask = "" if moreTask == task.id else task.id; }}/>
                                </View>
                            </View>
                            {<View style={{"gap": 9, "paddingTop": 8, "borderTopWidth": 1, "borderTopColor": P.line}}>
                                <Text style={T.eyebrow}>{task.priority.upper() + " PRIORITY  ·  " + ("COMPLETED" if task.completed else "OVERDUE" if task.due < feed.now else "UPCOMING")}</Text>
                                {<Text selectable={True} style={T.body}>{task.notes}</Text> if task.notes else None}
                                <View style={T.row}>
                                    <Button dark={darkMode} label="Edit" quiet={True} action={lambda { edit(task); }} disabled={busy}/>
                                    <Button dark={darkMode} label="Break into steps ✦" quiet={True} disabled={busy} action={lambda { aiTitle = task.title; act("ai", task.id); }}/>
                                    <Button dark={darkMode} label="Delete" quiet={True} action={lambda { deleting = task.id; }} disabled={busy}/>
                                </View>
                            </View> if moreTask == task.id else None}
                            {<View style={T.row}><Text style={T.body}>Delete this assignment?</Text>
                                <Button dark={darkMode} label={"Delete this date" if task.series_id else "Confirm delete"} action={lambda { act("delete", task.id); }} disabled={busy}/>
                                {<Button dark={darkMode} label="Delete this and future" action={lambda { act("delete_series", task.id); }} disabled={busy}/> if task.series_id else None}
                                <Button dark={darkMode} label="Keep task" quiet={True} action={lambda { deleting = ""; }}/></View> if deleting == task.id else None}
                        </View>
                    }}
        </View> if logged and connected and section == "assignments" else None}
        {<View style={{"width": "100%", "maxWidth": 560, "gap": 12}}>
            <View><Text style={T.eyebrow}>PREFERENCES</Text><Text style={T.heading}>Settings</Text></View>
            <View style={T.card}>
                <View style={T.between}>
                    <View style={{"gap": 4}}><Text style={T.name}>Dark mode</Text><Text style={T.small}>Use a darker background throughout Simon's Scheduler.</Text></View>
                    <Button dark={darkMode} label={"On" if darkMode else "Off"} quiet={not darkMode} action={toggleDarkMode}/>
                </View>
            </View>
            <View style={T.card}>
                <Text style={T.name}>Account</Text>
                <Text style={T.small}>{"Signed in as " + feed.viewer}</Text>
                <View style={T.row}>
                    <Button dark={darkMode} label="Sign out" action={logout} disabled={busy}/>
                    {<Button dark={darkMode} label="Change server" quiet={True} action={lambda {
                        jacLogout(); logged = False; connected = False; feed = Planner();
                        section = "assignments"; error = "";
                    }}/> if remote else None}
                </View>
            </View>
        </View> if logged and connected and section == "settings" else None}
        <Modal visible={composerOpen and logged} transparent={True} animationType="fade"
            onRequestClose={lambda { composerOpen = False; }}>
            <View style={{"flex": 1, "justifyContent": "center", "alignItems": "center", "padding": 12, "backgroundColor": "#17213CCC"}}>
                <View style={[T.card, {"width": "100%", "maxWidth": 520, "maxHeight": "96%", "padding": 18, "gap": 10}]}>
                    <View style={T.between}>
                        <Text style={T.heading}>{"Edit assignment" if editing else "Add assignment"}</Text>
                        <Button dark={darkMode} label="Close" quiet={True} action={lambda { composerOpen = False; }}/>
                    </View>
                    {<Text accessibilityRole="alert" style={T.error}>{error}</Text> if error else None}
                    {<View style={{"gap": 10}}>
                        <Field dark={darkMode} label="What is due?" value={title} change={lambda (t: str) { title = t; }}/>
                        <Field dark={darkMode} label="Course" value={course} change={lambda (t: str) { course = t; }}/>
                        <TimePicker dark={darkMode} value={due} change={lambda (t: str) { due = t; }}/>
                        {<CheckRow dark={darkMode} label="Repeat this assignment" checked={recurring} action={toggleRecurring}/> if not editing else None}
                        {<View style={{"gap": 4}}>
                            <Text style={T.small}>{"Repeats " + repeatFrequency}</Text>
                            <CheckRow dark={darkMode} label="Update this and future dates" checked={editFuture} action={lambda { editFuture = not editFuture; }}/>
                        </View> if editing and recurring else None}
                        {<Button dark={darkMode} label={"Repeat: " + repeatFrequency + " · " + str(repeatCount) + " dates"} quiet={True} action={lambda { editorPane = "repeat"; }}/> if recurring and not editing else None}
                    </View> if editorPane == "main" else None}
                    {<View style={{"gap": 8}}>
                        <Text style={T.small}>{title if title else "New assignment"}</Text>
                        <Text style={T.name}>Priority</Text>
                        <View style={T.row}>{[<Button dark={darkMode} key={p} label={p.title()} quiet={priority != p} action={lambda { priority = p; }}/> for p in ["low", "medium", "high"]]}</View>
                        <Field dark={darkMode} label="Notes" value={notes} change={lambda (t: str) { notes = t; }} multiline={True}/>
                    </View> if editorPane == "details" else None}
                    {<View style={{"gap": 10}}>
                        <Text style={T.name}>Repeat</Text>
                        <Text style={T.small}>Each date becomes an assignment you can complete separately.</Text>
                        <View style={T.row}>{[<Button dark={darkMode} key={frequency} label={frequency.title()} quiet={repeatFrequency != frequency} action={lambda { repeatFrequency = frequency; }}/> for frequency in ["daily", "weekly", "monthly"]]}</View>
                        <Text style={T.name}>Number of dates</Text>
                        <View style={T.row}>{[<Button dark={darkMode} key={count} label={str(count)} quiet={repeatCount != count} action={lambda { repeatCount = count; }}/> for count in [4, 8, 12, 16]]}</View>
                        <Text style={T.small}>Includes the first due date. You can remove future dates later.</Text>
                    </View> if editorPane == "repeat" else None}
                    <View style={T.between}>
                        <Button dark={darkMode} label={"Back" if editorPane != "main" else "Priority & notes"} quiet={True} action={lambda { editorPane = "main" if editorPane != "main" else "details"; }}/>
                        <Button dark={darkMode} label={"Saving…" if busy else "Save changes" if editing else "Add " + str(repeatCount) + " dates" if recurring else "Add assignment"}
                            action={lambda { act("save"); }} disabled={busy or not title.strip()}/>
                    </View>
                </View>
            </View>
        </Modal>
        <Modal visible={jumpOpen and logged} transparent={True} animationType="fade"
            onRequestClose={lambda { jumpOpen = False; }}>
            <View style={{"flex": 1, "justifyContent": "center", "alignItems": "center", "padding": 12, "backgroundColor": "#17213CCC"}}>
                <View style={[T.card, {"width": "100%", "maxWidth": 380, "padding": 18, "gap": 12}]}>
                    <Text style={T.heading}>Jump to date</Text>
                    <input aria-label="Choose calendar date" type="date" value={jumpDate}
                        onChange={lambda (e: ChangeEvent) { jumpDate = e.target.value as str; }}
                        style={{"padding": 13, "borderRadius": 12, "border": "1px solid " + P.line,
                            "fontSize": 15, "backgroundColor": P.input, "color": P.ink,
                            "colorScheme": "dark" if darkMode else "light"}}/>
                    <View style={T.row}>
                        <Button dark={darkMode} label="Go to date" action={jumpToDate} disabled={len(jumpDate) != 10}/>
                        <Button dark={darkMode} label="Cancel" quiet={True} action={lambda { jumpOpen = False; }}/>
                    </View>
                </View>
            </View>
        </Modal>
        <Modal visible={filtersOpen and logged} transparent={True} animationType="fade"
            onRequestClose={lambda { filtersOpen = False; }}>
            <View style={{"flex": 1, "justifyContent": "center", "alignItems": "center", "padding": 12, "backgroundColor": "#17213CCC"}}>
                <View style={[T.card, {"width": "100%", "maxWidth": 560, "padding": 18, "gap": 12}]}>
                    <View style={T.between}><Text style={T.heading}>Filters</Text><Button dark={darkMode} label="Done" action={lambda { filtersOpen = False; }}/></View>
                    <Text style={T.name}>Course</Text>
                    <ScrollView horizontal={True} showsHorizontalScrollIndicator={False} contentContainerStyle={{"gap": 6}}>
                        <Button dark={darkMode} label="All courses" quiet={courseFilter != ""} action={lambda { courseFilter = ""; }}/>
                        {[<Button dark={darkMode} key={c} label={c} quiet={courseFilter != c} action={lambda { courseFilter = c; }}/> for c in feed.courses]}
                    </ScrollView>
                    <Text style={T.name}>Priority</Text>
                    <View style={T.row}>
                        <Button dark={darkMode} label="Any" quiet={priorityFilter != ""} action={lambda { priorityFilter = ""; }}/>
                        {[<Button dark={darkMode} key={p} label={p.title()} quiet={priorityFilter != p} action={lambda { priorityFilter = p; }}/> for p in ["low", "medium", "high"]]}
                    </View>
                    <Text style={T.name}>Status</Text>
                    <View style={T.row}>{[<Button dark={darkMode} key={s} label={s.title()} quiet={status != s} action={lambda { status = s; }}/> for s in ["open", "completed", "all"]]}</View>
                    {<Button dark={darkMode} label="Clear filters" quiet={True} action={lambda { courseFilter = ""; priorityFilter = ""; status = "open"; }}/> if activeFilters else None}
                </View>
            </View>
        </Modal>
        <Modal visible={bool(aiTask) and logged} transparent={True} animationType="fade"
            onRequestClose={lambda { aiTask = ""; ai = Breakdown(); }}>
            <View style={{"flex": 1, "justifyContent": "center", "alignItems": "center", "padding": 12, "backgroundColor": "#17213CCC"}}>
                <View style={[T.card, {"width": "100%", "maxWidth": 520, "backgroundColor": P.pale, "borderColor": P.line}]}>
                    <Text style={T.eyebrow}>✦ STUDY COACH</Text>
                    <Text style={T.heading}>{aiTitle}</Text>
                    <Text style={T.body}>{"Review these steps before adding them. They inherit the assignment’s deadline; edit dates to spread out your work." if ai.available else ai.message}</Text>
                    {[<Text key={step} style={T.body}>• {step}</Text> for step in ai.steps]}
                    {<Button dark={darkMode} label="Add these study steps" action={lambda { act("accept"); }} disabled={busy}/> if ai.available and ai.steps else None}
                    <Button dark={darkMode} label="Dismiss" quiet={True} action={lambda { aiTask = ""; ai = Breakdown(); }}/>
                </View>
            </View>
        </Modal>
        <View style={T.footer}>
            <Text style={T.small}>Simon's Scheduler · Make every day count.</Text>
        </View>
    </ScrollView>;
}
