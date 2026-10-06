import from "@jac/mobui" {
    View,
    Text,
    TextInput,
    Pressable,
    ScrollView,
    Modal,
    Image,
    useWindowDimensions
}
import from "react" { useEffect }
import from "@jac/runtime" {
    jacSetToken,
    __getApiBaseUrl,
    jacLogout,
    jacIsLoggedIn,
    __getLocalStorage,
    __setLocalStorage
}
import from core.feed { Planner, TaskView, Breakdown, join, save_task, save_event, save_group, create_recurring, create_recurring_event, update_series, update_event_series, complete_task, delete_task, delete_series, load_planner, planner_clock, break_down, accept_steps }
import from core.theme { S, C, SD, CD }
import from core.date_controls { TimePicker, DateInput }
import from core.time_slot { TimeSlot }

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

def weekdayIndex(day: str) -> int {
    if len(day) < 10 { return 0; }
    year = int(day[:4]);
    month = int(day[5:7]);
    number = int(day[8:10]);
    offsets = [0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4];
    weekdayYear = year - 1 if month < 3 else year;
    return (weekdayYear + weekdayYear // 4 - weekdayYear // 100 + weekdayYear // 400 + offsets[month - 1] + number) % 7;
}

def calendarDayFor(task: TaskView) -> str {
    return task.start[:10] if task.start else task.due[:10];
}

def:pub PlannerApp(remote: bool = False, timePicker: any = TimePicker, dateInput: any = DateInput, timeSlot: any = TimeSlot) -> JsxElement {
    has feed: Planner = Planner(), username: str = "", password: str = "",
        signup: bool = False, logged: bool = False, busy: bool = False,
        loading: bool = True, error: str = "", notice: str = "",
        server: str = "", connected: bool = not remote,
        mode: str = "week", day: str = "", courseFilter: str = "",
        priorityFilter: str = "", status: str = "open",
        title: str = "", course: str = "EECS 449", due: str = "", notes: str = "",
        itemType: str = "assignment", eventStart: str = "", eventEnd: str = "",
        priority: str = "medium", editing: str = "", deleting: str = "",
        ai: Breakdown = Breakdown(), aiTask: str = "", aiTitle: str = "",
        composerOpen: bool = False, filtersOpen: bool = False,
        editorPane: str = "main", moreTask: str = "",
        recurring: bool = False, repeatFrequency: str = "weekly",
        repeatCount: int = 8, editFuture: bool = False,
        jumpOpen: bool = False, jumpDate: str = "",
        dragStart: int = -1, dragEnd: int = -1, dragDay: str = "",
        groupName: str = "", groupKind: str = "course", groupColorChoice: str = "#8B5CF6",
        liveToday: str = "", liveNow: str = "",
        section: str = "assignments", darkMode: bool = False;
    Picker = timePicker;
    CalendarDateInput = dateInput;
    Slot = timeSlot;
    windowSize = useWindowDimensions();
    wide = windowSize.width >= 1000;
    visibleStartHour = 8;
    visibleEndHour = 24;
    slotHeight = max(34, int((windowSize.height - 330) / (visibleEndHour - visibleStartHour))) if wide else 34;
    clockToday = liveToday if liveToday else feed.today;
    clockNow = liveNow if liveNow else feed.now;
    nowHour = int(clockNow[11:13]) if len(clockNow) >= 16 else -1;
    nowMinuteOffset = int(clockNow[14:16]) * slotHeight // 60 if len(clockNow) >= 16 else 0;
    weekdayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    T = SD if darkMode else S;
    P = CD if darkMode else C;
    groupColors = ["#8B5CF6", "#3B82F6", "#14B8A6", "#F59E0B", "#F43F5E", "#06B6D4", "#F97316", "#84CC16"];
    activeFilters = int(courseFilter != "") + int(priorityFilter != "") + int(status != "open");
    visibleTasks = feed.tasks if mode not in ["calendar", "week", "day"] else [];

    def groupColorFor(name: str) -> str {
        for group in feed.groups {
            if group.name == name { return group.color; }
        }
        return P.accent;
    }

    async def refresh(shift: int = 0) {
        if not connected { loading = False; return; }
        loading = True;
        try {
            feed = await load_planner("all" if mode == "calendar" else mode, day,
                courseFilter, priorityFilter, status, shift);
            error = "";
            if shift != 0 { day = feed.days[0] if mode == "week" and len(feed.days) == 7 else feed.selected; }
            if not due { due = feed.today + "T12:00"; }
            if logged and not feed.viewer { jacLogout(); logged = False; }
        } except Exception as e {
            error = "Could not load planner. Check your connection or sign in again. " + str(e);
        } finally { loading = False; }
    }

    async def syncClock {
        try {
            clock = await planner_clock();
            liveToday = clock.today; liveNow = clock.now;
        } except Exception { liveToday = feed.today; liveNow = feed.now; }
    }

    useEffect(lambda {
        if connected {
            syncClock();
            timer = globalThis.setInterval(lambda { syncClock(); }, 30000);
            return lambda { globalThis.clearInterval(timer); };
        }
    }, [connected]);

    async def connect {
        if not server.startswith("http://") and not server.startswith("https://") {
            error = "Enter a server address starting with http:// or https://."; return;
        }
        server = server.rstrip("/");
        globalThis.__JAC_API_BASE_URL__ = server;
        __setLocalStorage("planner_server", server);
        jacLogout(); logged = False; connected = True; error = "";
    }

    async def createGroup {
        if busy { return; }
        busy = True; error = ""; notice = "";
        try {
            await save_group(groupName, groupKind, groupColorChoice);
            added_name = groupName.strip();
            groupName = "";
            notice = groupKind.title() + " added: " + added_name + ". Choose it when adding an assignment.";
            await refresh();
        } except Exception as e { error = str(e); }
        finally { busy = False; }
    }

    async def recolorGroup(name: str, kind: str, color: str) {
        if busy { return; }
        busy = True; error = "";
        try {
            await save_group(name, kind, color);
            await refresh();
        } except Exception as e { error = str(e); }
        finally { busy = False; }
    }

    can with entry {
        if wide { mode = "week"; }
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
        itemType = "assignment"; eventStart = feed.today + "T12:00"; eventEnd = feed.today + "T13:00";
        recurring = False; repeatFrequency = "weekly"; repeatCount = 8;
        editFuture = False; editorPane = "main";
    }
    def openComposer {
        resetForm();
        if mode == "day" and feed.selected { due = feed.selected + "T12:00"; }
        if mode == "day" and feed.selected { eventStart = feed.selected + "T12:00"; eventEnd = feed.selected + "T13:00"; }
        error = ""; composerOpen = True;
    }
    def edit(task: TaskView) {
        editing = task.id; title = task.title; course = task.course;
        due = task.due; notes = task.notes; priority = task.priority;
        itemType = "event" if task.start else "assignment";
        eventStart = task.start if task.start else task.due;
        eventEnd = task.end if task.end else task.due;
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
                if itemType == "event" {
                    if editing and recurring and editFuture {
                        await update_event_series(editing, title, course, eventStart, eventEnd, notes);
                    } elif recurring and not editing {
                        await create_recurring_event(title, course, eventStart, eventEnd, notes, repeatFrequency, repeatCount);
                    } else {
                        await save_event(title, course, eventStart, eventEnd, notes, editing);
                    }
                } elif editing and editFuture {
                    await update_series(editing, title, course, due, priority, notes);
                } elif editing {
                    await save_task(title, course, due, priority, notes, editing);
                } elif recurring {
                    await create_recurring(title, course, due, priority, notes, repeatFrequency, repeatCount);
                } else {
                    await save_task(title, course, due, priority, notes);
                }
                notice = "Future event dates updated." if itemType == "event" and editing and editFuture else
                    str(repeatCount) + " repeating events added." if itemType == "event" and recurring and not editing else
                    "Event saved." if itemType == "event" else "Future dates updated." if editing and editFuture else
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
            day = shiftMonth(feed.selected if feed.selected else clockToday, shift);
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
    def pickCalendarTime(startHour: int, endHour: int, date: str = "") {
        date = date if date else feed.selected if feed.selected else clockToday;
        startValue = date + "T" + f"{startHour:02d}" + ":00";
        endValue = date + "T" + f"{endHour:02d}" + ":00" if endHour < 24 else date + "T23:59";
        itemType = "event"; eventStart = startValue; eventEnd = endValue;
        due = startValue;
        title = ""; course = ""; notes = ""; priority = "medium";
        recurring = False; editing = ""; editorPane = "main";
        composerOpen = True;
    }

    return <View style={[T.screen, {"height": windowSize.height, "position": "relative", "overflow": "hidden"}]}>
        <ScrollView style={T.screen} showsVerticalScrollIndicator={False} contentContainerStyle={[T.page, {"minHeight": windowSize.height, "paddingBottom": 110}]} keyboardShouldPersistTaps="handled">
        <View style={[T.header, {"paddingVertical": 4}]}>
            <View style={T.row}>
                <Image accessibilityLabel="SiMinute logo" source={{"uri": server.rstrip("/") + "/static/assets/timon-logo.png" if remote else "/static/assets/timon-logo.png"}} style={{"width": 52, "height": 52}} resizeMode="contain"/>
                <Text style={T.brand}>SiMinute</Text>
            </View>
            {<Button dark={darkMode} label="⚙" quiet={True} action={lambda { section = "settings" if section == "assignments" else "assignments"; }}/> if logged and connected else None}
        </View>
        {<View style={T.hero}>
            <View style={T.heroGlow}/>
            <View style={T.heroGlowSmall}/>
            <Text style={T.heroEyebrow}>{"WELCOME BACK, " + feed.viewer.upper() if logged and feed.viewer else "SCHEDULE"}</Text>
            <Text accessibilityRole="header" style={T.heroTitle}>{"Your schedule" if logged else "Welcome to SiMinute"}</Text>
            <Text style={T.heroText}>Assignments and events in one calendar.</Text>
            {<View style={[T.row, {"marginTop": 6}]}>
                <View style={{"backgroundColor": "#FFFFFF22", "borderRadius": 10, "paddingHorizontal": 12, "paddingVertical": 8}}><Text style={{"color": "#FFFFFF", "fontWeight": "700"}}>{clockToday}</Text></View>
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
        {<View style={[T.stack, {"gap": 6, "flex": 1}]}> 
            {<View style={T.between}>
                <View><Text style={T.eyebrow}>YOUR WORKSPACE</Text><Text style={T.heading}>Calendar</Text></View>
            </View> if not wide else None}
            <View style={[T.row, {"gap": 8}]}>
                <Text style={T.small}>{str(feed.upcoming) + " due soon"}</Text>
                <Text style={T.small}>·</Text>
                <Text style={T.small}>{str(feed.overdue) + " overdue"}</Text>
                <Text style={T.small}>·</Text>
                <Text style={T.small}>{str(feed.completed) + "/" + str(feed.total) + " done"}</Text>
            </View>
            <View style={[T.between, {"gap": 6}]}>
                <ScrollView horizontal={True} showsHorizontalScrollIndicator={False} style={{"flex": 1}} contentContainerStyle={{"gap": 6, "alignItems": "center"}}>
                    {[<Button dark={darkMode} key={v} label={v.title()} quiet={mode != v}
                        action={lambda { mode = v; day = clockToday if v == "calendar" else feed.selected; }} disabled={loading or busy}/> for v in ["calendar", "week", "day"]]}
                </ScrollView>
                <View style={T.row}>
                    <Button dark={darkMode} label={"Filters (" + str(activeFilters) + ")" if activeFilters else "Filters"} quiet={True} action={lambda { filtersOpen = True; }}/>
                </View>
            </View>
                    {<View style={[T.between, T.card, {"paddingVertical": 8, "gap": 6}]}>
                        <Button dark={darkMode} label={"Previous month" if mode == "calendar" else "Previous"} quiet={True} disabled={loading} action={lambda { navigate(-1); }}/>
                        <Text style={T.heading}>{monthLabel(feed.selected) if mode == "calendar" else feed.days[0] + " — " + feed.days[6] if mode == "week" and len(feed.days) == 7 else feed.selected}</Text>
                        <View style={T.row}>
                            <Button dark={darkMode} label="Today" quiet={True} action={lambda { day = clockToday; }}/>
                            <Button dark={darkMode} label="Jump to date" quiet={True} action={lambda { jumpDate = feed.selected; jumpOpen = True; }}/>
                            <Button dark={darkMode} label={"Next month" if mode == "calendar" else "Next"} quiet={True} disabled={loading} action={lambda { navigate(1); }}/>
                        </View>
                    </View> if mode in ["day", "week", "calendar"] else None}
                    {<View style={[T.card, {"padding": 8 if wide else 12, "gap": 5 if wide else 8, "position": "relative", "flex": 1, "minHeight": windowSize.height - 390 if wide else 420}]}> 
                        <ScrollView style={{"flex": 1}} showsVerticalScrollIndicator={False} contentContainerStyle={{"gap": 5 if wide else 8, "paddingBottom": 72}}>
                        {<View style={{"flexDirection": "row"}}>
                            {[<Text key={name} style={[T.eyebrow, {"width": "14.285%", "textAlign": "center", "paddingVertical": 9}]}>{name}</Text> for name in ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]]}
                        </View> if mode == "calendar" else None}
                        {<View style={{"flexDirection": "row", "flexWrap": "wrap"}}>
                            {for calendar_day in calendarDays(feed.selected) {
                                <Pressable key={calendar_day} accessibilityRole="button" accessibilityLabel={"View assignments for " + calendar_day}
                                    onPress={lambda { day = calendar_day; mode = "day"; }}
                                    style={{"width": "14.285%", "minHeight": 104 if wide else 62, "padding": 6, "borderWidth": 1, "borderColor": P.line, "backgroundColor": P.pale if calendar_day == clockToday else P.input if calendar_day[:7] != feed.selected[:7] else P.card}}>
                                    <Text style={[T.name, {"color": P.accent if calendar_day == clockToday else P.muted if calendar_day[:7] != feed.selected[:7] else P.ink}]}>{calendar_day[8:10]}</Text>
                                    {<Text style={[T.small, {"fontWeight": "700", "color": P.purple}]}>{str(len([calendar_task for calendar_task in feed.tasks if calendarDayFor(calendar_task) == calendar_day])) + " due"}</Text> if not wide and len([calendar_task for calendar_task in feed.tasks if calendarDayFor(calendar_task) == calendar_day]) else None}
                                    {[<Text key={calendar_task.id} style={[T.small, {"backgroundColor": P.pale, "padding": 4, "borderRadius": 5, "color": groupColorFor(calendar_task.course), "textDecorationLine": "line-through" if calendar_task.completed else "none"}]}>{(displayTime(calendar_task.start) + "–" + displayTime(calendar_task.end) if calendar_task.start else displayTime(calendar_task.due)) + " " + calendar_task.title + (" ↻ " + calendar_task.repeat if calendar_task.series_id else "")}</Text> for calendar_task in feed.tasks if wide and calendarDayFor(calendar_task) == calendar_day]}
                                </Pressable>
                            }}
                        </View> if mode == "calendar" else None}
                        {<View style={{"flexDirection": "row"}}>
                            {for calendar_day in feed.days {
                                <Pressable key={calendar_day} accessibilityRole="button" accessibilityLabel={"View assignments for " + calendar_day}
                                    onPress={lambda { day = calendar_day; mode = "day"; }}
                                    style={{"flex": 1, "minWidth": 42, "minHeight": 116 if mode == "week" else 84, "padding": 7, "gap": 5, "borderWidth": 1, "borderColor": P.line, "borderRadius": 8, "backgroundColor": P.pale if calendar_day == clockToday else P.card}}>
                                    <Text style={[T.eyebrow, {"textAlign": "center"}]}>{weekdayNames[weekdayIndex(calendar_day)] + " " + calendar_day[5:7] + "/" + calendar_day[8:10]}</Text>
                                    {<Text style={T.small}>{str(len([calendar_task for calendar_task in feed.tasks if calendarDayFor(calendar_task) == calendar_day])) + " due"}</Text> if len([calendar_task for calendar_task in feed.tasks if calendarDayFor(calendar_task) == calendar_day]) else <Text style={T.small}>—</Text>}
                                </Pressable>
                            }}
                        </View> if mode == "week" and not wide else None}
                        {<View style={{"gap": 2, "padding": 8}}>
                            <View style={{"flexDirection": "row", "gap": 2}}>
                                <View style={{"width": 54}}/>
                                {for calendar_day in feed.days {
                                    <Pressable key={calendar_day} accessibilityRole="button" accessibilityLabel={"View assignments for " + calendar_day}
                                        onPress={lambda { day = calendar_day; mode = "day"; }}
                                        style={{"flex": 1, "minWidth": 48, "padding": 7, "gap": 3, "borderWidth": 1, "borderColor": P.line, "borderRadius": 8, "backgroundColor": P.pale if calendar_day == clockToday else P.card}}>
                                        <Text style={[T.eyebrow, {"textAlign": "center"}]}>{weekdayNames[weekdayIndex(calendar_day)] + " " + calendar_day[5:7] + "/" + calendar_day[8:10]}</Text>
                                        <Text style={[T.small, {"textAlign": "center"}]}>{str(len([calendar_task for calendar_task in feed.tasks if (calendar_task.start[:10] if calendar_task.start else calendar_task.due[:10]) == calendar_day])) + " items"}</Text>
                                    </Pressable>
                                }}
                            </View>
                            {for slot in range(visibleStartHour, visibleEndHour) {
                                    <View key={slot} style={{"flexDirection": "row", "gap": 2, "borderTopWidth": 1, "borderTopColor": P.line}}>
                                    <View style={{"width": 54, "height": slotHeight, "justifyContent": "flex-start", "alignItems": "flex-end", "paddingRight": 5}}>
                                        <Text style={T.small}>{str(slot % 12 if slot % 12 else 12) + (" AM" if slot < 12 else " PM")}</Text>
                                    </View>
                                    {for calendar_day in feed.days {
                                        <Slot key={calendar_day + str(slot)} start={lambda (e: MouseEvent) { dragStart = slot; dragEnd = slot; dragDay = calendar_day; day = calendar_day; }}
                                            enter={lambda (e: MouseEvent) { if dragStart >= 0 and dragDay == calendar_day { dragEnd = slot; } }}
                                            finish={lambda (e: MouseEvent) { if dragStart >= 0 { startHour = min(dragStart, dragEnd); finishHour = max(dragStart, dragEnd) + 1; day = dragDay; pickCalendarTime(startHour, finishHour, dragDay); dragStart = -1; dragEnd = -1; dragDay = ""; } }}
                                            tap={lambda { day = calendar_day; pickCalendarTime(slot, slot + 1, calendar_day); }}
                                            style={{"position": "relative", "flex": 1, "minWidth": 48, "height": slotHeight, "overflow": "hidden", "borderLeftWidth": 1, "borderLeftColor": P.line, "borderRightWidth": 1, "borderRightColor": P.line, "backgroundColor": P.pale if dragStart >= 0 and dragDay == calendar_day and slot >= min(dragStart, dragEnd) and slot <= max(dragStart, dragEnd) else P.card}}>
                                            <View style={{"position": "absolute", "left": 0, "right": 0, "top": slotHeight // 2, "borderTopWidth": 1, "borderTopColor": P.line}}/>
                                            {<View accessibilityLabel="Current time" style={{"position": "absolute", "left": 0, "right": 0, "top": nowMinuteOffset, "height": 2, "backgroundColor": "#EF3038", "zIndex": 40, "pointerEvents": "none"}}/> if calendar_day == clockToday and slot == nowHour else None}
                                            {[<Text key={calendar_task.id} style={[T.small, {"width": "100%", "boxSizing": "border-box", "display": "block", "padding": 3, "borderRadius": 4, "backgroundColor": P.pale, "color": groupColorFor(calendar_task.course), "textDecorationLine": "line-through" if calendar_task.completed else "none"}]}>{(displayTime(calendar_task.start) + "–" + displayTime(calendar_task.end) if calendar_task.start else displayTime(calendar_task.due)) + " " + calendar_task.title + (" ↻ " + calendar_task.repeat if calendar_task.series_id else "")}</Text> for calendar_task in feed.tasks if (calendar_task.start[:10] if calendar_task.start else calendar_task.due[:10]) == calendar_day and int((calendar_task.start if calendar_task.start else calendar_task.due)[11:13]) == slot]}
                                        </Slot>
                                    }}
                                </View>
                            }}
                        </View> if mode == "week" and wide else None}
                        {<View style={{"gap": 8, "padding": 8}}>
                            <Text style={T.eyebrow}>{"TODAY" if feed.selected == clockToday else "SELECTED DAY"}</Text>
                            <Text style={T.small}>{"Tap a time slot to create an event." if remote else "Drag within the day to create an event."}</Text>
                            <View style={{"gap": 2}}>
                                {for slot in range(visibleStartHour, visibleEndHour) {
                                    <View key={slot} style={{"flexDirection": "row", "borderTopWidth": 1, "borderTopColor": P.line}}>
                                        <View style={{"width": 54, "height": slotHeight, "justifyContent": "flex-start", "alignItems": "flex-end", "paddingRight": 5}}>
                                            <Text style={T.small}>{str(slot % 12 if slot % 12 else 12) + (" AM" if slot < 12 else " PM")}</Text>
                                        </View>
                                        <Slot key={"day" + str(slot)} start={lambda (e: MouseEvent) { dragStart = slot; dragEnd = slot; dragDay = feed.selected; }}
                                            enter={lambda (e: MouseEvent) { if dragStart >= 0 and dragDay == feed.selected { dragEnd = slot; } }}
                                            finish={lambda (e: MouseEvent) { if dragStart >= 0 { startHour = min(dragStart, dragEnd); finishHour = max(dragStart, dragEnd) + 1; pickCalendarTime(startHour, finishHour, feed.selected); dragStart = -1; dragEnd = -1; dragDay = ""; } }}
                                            tap={lambda { pickCalendarTime(slot, slot + 1, feed.selected); }}
                                            style={{"position": "relative", "flex": 1, "minWidth": 48, "height": slotHeight, "overflow": "hidden", "borderLeftWidth": 1, "borderLeftColor": P.line, "borderRightWidth": 1, "borderRightColor": P.line, "backgroundColor": P.pale if dragStart >= 0 and dragDay == feed.selected and slot >= min(dragStart, dragEnd) and slot <= max(dragStart, dragEnd) else P.card}}>
                                            <View style={{"position": "absolute", "left": 0, "right": 0, "top": slotHeight // 2, "borderTopWidth": 1, "borderTopColor": P.line}}/>
                                            {<View accessibilityLabel="Current time" style={{"position": "absolute", "left": 0, "right": 0, "top": nowMinuteOffset, "height": 2, "backgroundColor": "#EF3038", "zIndex": 40, "pointerEvents": "none"}}/> if feed.selected == clockToday and slot == nowHour else None}
                                            {[<Text key={calendar_task.id} style={[T.small, {"width": "100%", "boxSizing": "border-box", "display": "block", "padding": 3, "borderRadius": 4, "backgroundColor": P.pale, "color": groupColorFor(calendar_task.course), "textDecorationLine": "line-through" if calendar_task.completed else "none"}]}>{(displayTime(calendar_task.start) + "–" + displayTime(calendar_task.end) if calendar_task.start else displayTime(calendar_task.due)) + " " + calendar_task.title + (" ↻ " + calendar_task.repeat if calendar_task.series_id else "")}</Text> for calendar_task in feed.tasks if (calendar_task.start[:10] if calendar_task.start else calendar_task.due[:10]) == feed.selected and int((calendar_task.start if calendar_task.start else calendar_task.due)[11:13]) == slot]}
                                        </Slot>
                                    </View>
                                }}
                            </View>
                            {<Text style={T.small}>No assignments scheduled.</Text> if not [calendar_task for calendar_task in feed.tasks if calendarDayFor(calendar_task) == feed.selected] else None}
                            {[<View key={calendar_task.id} style={[T.between, {"padding": 10, "borderRadius": 9, "backgroundColor": P.pale}]}>
                                <View style={{"gap": 3}}><Text style={T.name}>{calendar_task.title}</Text><View style={T.row}><View style={{"width": 8, "height": 8, "borderRadius": 4, "backgroundColor": groupColorFor(calendar_task.course)}}/><Text style={T.small}>{calendar_task.course + " · " + (displayTime(calendar_task.start) + "–" + displayTime(calendar_task.end) if calendar_task.start else displayTime(calendar_task.due)) + (" · ↻ " + calendar_task.repeat if calendar_task.series_id else "")}</Text></View></View>
                                <View style={T.row}><Text style={T.eyebrow}>{"EVENT" if calendar_task.start else "DUE"}</Text><Button dark={darkMode} label="Edit" quiet={True} action={lambda { edit(calendar_task); }}/><Button dark={darkMode} label="Delete" quiet={True} action={lambda { act("delete", calendar_task.id); }}/></View>
                            </View> for calendar_task in feed.tasks if calendarDayFor(calendar_task) == feed.selected]}
                        </View> if mode == "day" else None}
                        </ScrollView>
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
                                    <View style={T.row}><View style={{"width": 8, "height": 8, "borderRadius": 4, "backgroundColor": groupColorFor(task.course)}}/><Text style={T.small}>{task.course + "  ·  " + task.due[:10] + "  ·  " + displayTime(task.due) + ("  ·  ↻ " + task.repeat if task.series_id else "")}</Text></View>
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
            <View style={[T.row, {"gap": 12}]}>
                <Button dark={darkMode} label="←" quiet={True} action={lambda { section = "assignments"; }}/>
                <View><Text style={T.eyebrow}>PREFERENCES</Text><Text style={T.heading}>Settings</Text></View>
            </View>
            <View style={T.card}>
                <View style={T.between}>
                    <View style={{"gap": 4}}><Text style={T.name}>Dark mode</Text><Text style={T.small}>{"Use a darker background throughout " + feed.viewer + "'s schedule." if feed.viewer else "Use a darker background throughout your schedule."}</Text></View>
                    <Button dark={darkMode} label={"On" if darkMode else "Off"} quiet={not darkMode} action={toggleDarkMode}/>
                </View>
            </View>
            <View style={T.card}>
                <Text style={T.heading}>Courses and clubs</Text>
                <Text style={T.small}>Create groups for assignments and events. Each group color appears beside its items.</Text>
                <Field dark={darkMode} label="Course or club name" value={groupName} change={lambda (t: str) { groupName = t; }}/>
                <View style={T.row}>
                    <Button dark={darkMode} label="Course" quiet={groupKind != "course"} action={lambda { groupKind = "course"; }}/>
                    <Button dark={darkMode} label="Club" quiet={groupKind != "club"} action={lambda { groupKind = "club"; }}/>
                </View>
                <Text style={T.small}>Choose a color</Text>
                <View style={T.row}>
                    {[<Pressable key={color} accessibilityRole="button" accessibilityLabel={"Choose color " + color}
                        onPress={lambda { groupColorChoice = color; }}
                        style={{"width": 28, "height": 28, "borderRadius": 14, "backgroundColor": color, "borderWidth": 3 if groupColorChoice == color else 1, "borderColor": P.ink if groupColorChoice == color else P.line}}/> for color in groupColors]}
                </View>
                <Button dark={darkMode} label={"Add " + groupKind} action={createGroup} disabled={busy or not groupName.strip()}/>
                {<View style={{"gap": 10}}>
                    <Text style={T.name}>Your groups</Text>
                    {[<View key={group.name} style={[T.between, {"paddingVertical": 8, "borderTopWidth": 1, "borderTopColor": P.line}]}>
                        <View style={T.row}>
                            <View style={{"width": 12, "height": 12, "borderRadius": 6, "backgroundColor": group.color}}/>
                            <View><Text style={T.name}>{group.name}</Text><Text style={T.small}>{group.kind.title()}</Text></View>
                        </View>
                        <View style={T.row}>
                            {[<Pressable key={color} accessibilityRole="button" accessibilityLabel={"Set " + group.name + " color to " + color}
                                onPress={lambda { recolorGroup(group.name, group.kind, color); }}
                                style={{"width": 20, "height": 20, "borderRadius": 10, "backgroundColor": color, "borderWidth": 2 if group.color == color else 1, "borderColor": P.ink if group.color == color else P.line}}/> for color in groupColors]}
                        </View>
                    </View> for group in feed.groups]}
                    {<Text style={T.small}>No groups yet. Add a course or club above.</Text> if not feed.groups else None}
                </View>}
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
                        <Text style={T.heading}>{"Edit event" if editing and itemType == "event" else "Edit assignment" if editing else "Add event" if itemType == "event" else "Add assignment"}</Text>
                        <Button dark={darkMode} label="Close" quiet={True} action={lambda { composerOpen = False; }}/>
                    </View>
                    {<Text accessibilityRole="alert" style={T.error}>{error}</Text> if error else None}
                    {<View style={{"gap": 10}}>
                        <Text style={T.name}>What are you adding?</Text>
                        <View style={T.row}>
                            <Button dark={darkMode} label="Assignment" quiet={itemType != "assignment"} action={lambda { itemType = "assignment"; } } disabled={bool(editing)}/>
                            <Button dark={darkMode} label="Event" quiet={itemType != "event"} action={lambda { if itemType != "event" { course = ""; } itemType = "event"; } } disabled={bool(editing)}/>
                        </View>
                        <Field dark={darkMode} label={"Event title" if itemType == "event" else "What is due?"} value={title} change={lambda (t: str) { title = t; }}/>
                        <Field dark={darkMode} label={"Course or club (optional)" if itemType == "event" else "Course or club"} value={course} change={lambda (t: str) { course = t; }}/>
                        {<Button dark={darkMode} label="None" quiet={course != ""} action={lambda { course = ""; }}/> if itemType == "event" else None}
                        {<View style={{"gap": 6}}>
                            <Text style={T.small}>Or choose a saved group</Text>
                            <View style={T.row}>{[<Button dark={darkMode} key={group.name} label={group.name} quiet={course != group.name} action={lambda { course = group.name; }}/> for group in feed.groups]}</View>
                        </View> if feed.groups else None}
                        {<View style={{"gap": 10}}>
                            <Picker dark={darkMode} value={eventStart} label="Event starts" change={lambda (t: str) { eventStart = t; }}/>
                            <Picker dark={darkMode} value={eventEnd} label="Event ends" change={lambda (t: str) { eventEnd = t; }}/>
                            <Text style={T.small}>End time must be later than start time.</Text>
                        </View> if itemType == "event" else <Picker dark={darkMode} value={due} change={lambda (t: str) { due = t; }}/>}
                        {<CheckRow dark={darkMode} label={"Repeat this event" if itemType == "event" else "Repeat this assignment"} checked={recurring} action={toggleRecurring}/> if not editing else None}
                        {<View style={{"gap": 4}}>
                            <Text style={T.small}>{("Repeats " + repeatFrequency) if itemType == "event" else ("Repeats " + repeatFrequency)}</Text>
                            <CheckRow dark={darkMode} label="Update this and future occurrences" checked={editFuture} action={lambda { editFuture = not editFuture; }}/>
                        </View> if editing and recurring else None}
                        {<Button dark={darkMode} label={"Repeat: " + repeatFrequency + " · " + str(repeatCount) + (" events" if itemType == "event" else " dates")} quiet={True} action={lambda { editorPane = "repeat"; }}/> if recurring and not editing else None}
                    </View> if editorPane == "main" else None}
                    {<View style={{"gap": 8}}>
                        <Text style={T.small}>{title if title else "New assignment"}</Text>
                        <Text style={T.name}>Priority</Text>
                        <View style={T.row}>{[<Button dark={darkMode} key={p} label={p.title()} quiet={priority != p} action={lambda { priority = p; }}/> for p in ["low", "medium", "high"]]}</View>
                        <Field dark={darkMode} label="Notes" value={notes} change={lambda (t: str) { notes = t; }} multiline={True}/>
                    </View> if editorPane == "details" else None}
                    {<View style={{"gap": 10}}>
                        <Text style={T.name}>Repeat</Text>
                        <Text style={T.small}>{"Each date creates a separate event occurrence." if itemType == "event" else "Each date becomes an assignment you can complete separately."}</Text>
                        <View style={T.row}>{[<Button dark={darkMode} key={frequency} label={frequency.title()} quiet={repeatFrequency != frequency} action={lambda { repeatFrequency = frequency; }}/> for frequency in ["daily", "weekly", "monthly"]]}</View>
                        <Text style={T.name}>Number of dates</Text>
                        <View style={T.row}>{[<Button dark={darkMode} key={count} label={str(count)} quiet={repeatCount != count} action={lambda { repeatCount = count; }}/> for count in [4, 8, 12, 16]]}</View>
                        <Text style={T.small}>Includes the first due date. You can remove future dates later.</Text>
                    </View> if editorPane == "repeat" else None}
                    <View style={T.between}>
                        <Button dark={darkMode} label={"Back" if editorPane != "main" else "Priority & notes"} quiet={True} action={lambda { editorPane = "main" if editorPane != "main" else "details"; }}/>
                        <Button dark={darkMode} label={"Saving…" if busy else "Save event" if itemType == "event" and editing else "Add " + str(repeatCount) + " events" if itemType == "event" and recurring and not editing else "Save event" if itemType == "event" else "Save changes" if editing else "Add " + str(repeatCount) + " dates" if recurring else "Add assignment"}
                            action={lambda { act("save"); }} disabled={busy or not title.strip() or itemType == "event" and eventEnd <= eventStart}/>
                    </View>
                </View>
            </View>
        </Modal>
        <Modal visible={jumpOpen and logged} transparent={True} animationType="fade"
            onRequestClose={lambda { jumpOpen = False; }}>
            <View style={{"flex": 1, "justifyContent": "center", "alignItems": "center", "padding": 12, "backgroundColor": "#17213CCC"}}>
                <View style={[T.card, {"width": "100%", "maxWidth": 380, "padding": 18, "gap": 12}]}>
                    <Text style={T.heading}>Jump to date</Text>
                    <CalendarDateInput value={jumpDate} change={lambda (t: str) { jumpDate = t; }} dark={darkMode}/>
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
                        {[<Button dark={darkMode} key={group.name} label={group.name} quiet={courseFilter != group.name} action={lambda { courseFilter = group.name; }}/> for group in feed.groups]}
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
        </ScrollView>
        {<View style={{"position": "absolute", "right": "6%", "bottom": "5%", "zIndex": 1000}}>
            <Button dark={darkMode} label="+ Add assignment" action={openComposer} disabled={busy or loading}/>
        </View> if logged and connected and section == "assignments" and mode in ["calendar", "week", "day"] else None}
    </View>;
}
