import from "@jac/mobui" {
    View,
    Text,
    TextInput,
    Pressable,
    ScrollView,
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
import from core.feed { Planner, TaskView, Breakdown, join, save_task, complete_task, delete_task, load_planner, break_down, accept_steps }
import from core.theme { S, C }

def Button(
    label: str, action: Callable, quiet: bool = False, disabled: bool = False
) -> JsxElement {
    return
        <Pressable
            accessibilityRole="button"
            accessibilityLabel={label}
            disabled={disabled}
            onPress={action}
            style={[
                S.button,
                S.quiet if quiet else {},
                {"opacity": 0.45 if disabled else 1}
            ]}
        >
            <Text style={[S.buttonText, S.quietText if quiet else {}]}>{label}</Text>
        </Pressable>;
}

def Field(label: str, value: str, change: Callable, multiline: bool = False) -> JsxElement {
    return <View style={{"gap": 6}}>
        <Text style={S.name}>{label}</Text>
        <TextInput accessibilityLabel={label} value={value} onChangeText={change}
            style={[S.input, S.composer if multiline else {}]} multiline={multiline}
            autoCapitalize="none" placeholder={label} placeholderTextColor={C.muted}/>
    </View>;
}

def:pub PlannerApp(remote: bool = False) -> JsxElement {
    has feed: Planner = Planner(), username: str = "", password: str = "",
        signup: bool = False, logged: bool = False, busy: bool = False,
        loading: bool = True, error: str = "", notice: str = "",
        server: str = "", connected: bool = not remote,
        mode: str = "dashboard", day: str = "", courseFilter: str = "",
        priorityFilter: str = "", status: str = "open",
        title: str = "", course: str = "EECS 449", due: str = "", notes: str = "",
        priority: str = "medium", editing: str = "", deleting: str = "",
        ai: Breakdown = Breakdown(), aiTask: str = "", aiTitle: str = "";
    wide = useWindowDimensions().width >= 1000;

    async def refresh(shift: int = 0) {
        if not connected { loading = False; return; }
        loading = True;
        try {
            feed = await load_planner(mode, day, courseFilter, priorityFilter, status, shift);
            if shift != 0 { day = feed.selected; }
            if not due { due = feed.today + "T23:59"; }
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
        due = feed.today + "T23:59";
    }
    def edit(task: TaskView) {
        editing = task.id; title = task.title; course = task.course;
        due = task.due; notes = task.notes; priority = task.priority;
        notice = "Editing “" + task.title + "” in the assignment form.";
    }
    async def act(kind: str, id: str = "", done: bool = True) {
        if busy { return; }
        busy = True; error = ""; notice = "";
        try {
            if kind == "save" {
                await save_task(title, course, due, priority, notes, editing);
                notice = "Assignment saved."; resetForm();
            } elif kind == "complete" {
                await complete_task(id, done);
                notice = "Assignment completed. Nice work!" if done else "Assignment reopened.";
            } elif kind == "delete" {
                await delete_task(id); deleting = "";
                if editing == id { resetForm(); }
                if aiTask == id { aiTask = ""; ai = Breakdown(); }
                notice = "Assignment deleted.";
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
        resetForm(); aiTask = ""; error = ""; notice = ""; await refresh();
    }

    return <ScrollView style={S.screen} contentContainerStyle={S.page} keyboardShouldPersistTaps="handled">
        <View style={S.header}>
            <View><Text style={S.brand}>◒  Daymark</Text><Text style={S.small}>THE STUDENT PLANNER</Text></View>
            <Text style={S.eyebrow}>EECS 449 · MAKE ROOM TO FOCUS</Text>
        </View>
        <View style={S.stack}>
            <Text style={S.eyebrow}>A LITTLE STRUCTURE. A CLEARER MIND.</Text>
            <Text accessibilityRole="header" style={S.title}>Your semester, in perspective.</Text>
            <Text style={S.subtitle}>Capture the deadlines. Find your next step. Make progress every day.</Text>
        </View>
        {<Text accessibilityRole="alert" style={S.error}>{error}</Text> if error else None}
        {<Text accessibilityRole="status" style={S.success}>{notice}</Text> if notice else None}
        {<View style={S.card}>
            <Text style={S.name}>Connect to your planner</Text>
            <Field label="Server address" value={server} change={lambda (t: str) { server = t; }}/>
            <Button label="Connect" action={connect}/>
        </View> if not connected else None}
        {<View style={[S.card, {"maxWidth": 520}]}>
            <Text style={S.heading}>{"Start a fresh page." if signup else "Welcome back."}</Text>
            <Text style={S.body}>One private planner, on your laptop, phone, and terminal.</Text>
            <Field label="Username" value={username} change={lambda (t: str) { username = t; }}/>
            <Text style={S.name}>Password</Text>
            <TextInput accessibilityLabel="Password" style={S.input} value={password}
                secureTextEntry={True} onChangeText={lambda (t: str) { password = t; }} onSubmitEditing={authenticate}/>
            <Button label={"Please wait…" if busy else "Create account" if signup else "Sign in"}
                action={authenticate} disabled={busy}/>
            <Button label={"I already have an account" if signup else "New here? Create an account"}
                quiet={True} action={lambda { signup = not signup; error = ""; }} disabled={busy}/>
        </View> if connected and not logged else None}
        {<View style={S.stack}>
            <View style={S.between}>
                <Text style={S.name}>YOUR WORKSPACE / {feed.viewer}</Text>
                <View style={S.row}>
                    <Button label="Refresh" quiet={True} action={lambda { error = ""; refresh(); }} disabled={busy or loading}/>
                    <Button label="Sign out" quiet={True} action={logout} disabled={busy}/>
                </View>
            </View>
            <View style={S.row}>
                <View style={[S.metric, {"backgroundColor": "#f9e9df"}]}><Text style={S.score}>{feed.overdue}</Text><Text style={S.name}>Overdue · time to regroup</Text></View>
                <View style={S.metric}><Text style={S.score}>{feed.upcoming}</Text><Text style={S.name}>Due in the next 7 days</Text></View>
                <View style={[S.metric, {"backgroundColor": "#e6eddf"}]}><Text style={S.score}>{feed.completed}/{feed.total}</Text><Text style={S.name}>Assignments completed</Text></View>
            </View>
            <View style={{"gap": 24, "flexDirection": "row" if wide else "column", "alignItems": "flex-start"}}>
                <View style={[S.card, {"width": 320 if wide else "100%"}]}>
                    <Text style={S.eyebrow}>{"MAKE AN ADJUSTMENT" if editing else "GET IT OFF YOUR MIND"}</Text>
                    <Text style={S.heading}>{"Edit assignment" if editing else "New assignment"}</Text>
                    <Field label="Title" value={title} change={lambda (t: str) { title = t; }}/>
                    <Field label="Course" value={course} change={lambda (t: str) { course = t; }}/>
                    <Field label="Due (YYYY-MM-DDTHH:MM)" value={due} change={lambda (t: str) { due = t; }}/>
                    <Text style={S.small}>24-hour campus time. Example: 2026-10-09T23:59</Text>
                    <Text style={S.name}>Priority</Text>
                    <View style={S.row}>{[<Button key={p} label={p} quiet={priority != p}
                        action={lambda { priority = p; }}/> for p in ["low", "medium", "high"]]}</View>
                    <Field label="Notes" value={notes} change={lambda (t: str) { notes = t; }} multiline={True}/>
                    <Button label={"Saving…" if busy else "Save changes" if editing else "Add assignment"}
                        action={lambda { act("save"); }} disabled={busy or not title.strip()}/>
                    {<Button label="Cancel edit" quiet={True} action={resetForm} disabled={busy}/> if editing else None}
                    <Text style={S.small}>Small steps count. Add one assignment, then choose where to begin.</Text>
                </View>
                <View style={[S.stack, {"flex": 1, "width": "100%", "minWidth": 0}]}>
                    <View style={S.row}>{[<Button key={v} label={v.title()} quiet={mode != v}
                        action={lambda { mode = v; }} disabled={loading or busy}/> for v in ["dashboard", "day", "week", "all"]]}</View>
                    <View style={S.card}>
                        <Text style={S.eyebrow}>FIND YOUR FOCUS</Text>
                        <View style={S.row}>
                            <Button label="All courses" quiet={courseFilter != ""} action={lambda { courseFilter = ""; }}/>
                            {[<Button key={c} label={c} quiet={courseFilter != c} action={lambda { courseFilter = c; }}/>
                                for c in feed.courses]}
                        </View>
                        <View style={S.row}>
                            <Button label="Any priority" quiet={priorityFilter != ""} action={lambda { priorityFilter = ""; }}/>
                            {[<Button key={p} label={p.title() + " priority"} quiet={priorityFilter != p}
                                action={lambda { priorityFilter = p; }}/> for p in ["low", "medium", "high"]]}
                        </View>
                        <View style={S.row}>{[<Button key={s} label={s.title()} quiet={status != s}
                            action={lambda { status = s; }}/> for s in ["open", "completed", "all"]]}</View>
                    </View>
                    {<View style={S.between}>
                        <Button label="Previous" quiet={True} disabled={loading} action={lambda { refresh(-7 if mode == "week" else -1); }}/>
                        <Text style={S.name}>{feed.days[0] + " — " + feed.days[6] if mode == "week" and len(feed.days) == 7 else feed.selected}</Text>
                        <Button label="Next" quiet={True} disabled={loading} action={lambda { refresh(7 if mode == "week" else 1); }}/>
                    </View> if mode in ["day", "week"] else None}
                    <View style={S.between}>
                        <Text style={S.heading}>{"Your next steps" if mode == "dashboard" else mode.title() + " planner"}</Text>
                        <Text style={S.small}>{len(feed.tasks)} assignments</Text>
                    </View>
                    {<Text style={S.small}>Overdue work and the next 7 days, sorted by deadline.</Text> if mode == "dashboard" else None}
                    {<Text style={S.small}>Loading your planner…</Text> if loading else None}
                    {<View style={S.card}><Text style={S.heading}>A little breathing room.</Text>
                        <Text style={S.body}>No assignments match this view. Add something new or adjust the filters.</Text></View>
                        if not loading and not feed.tasks else None}
                    {for task in feed.tasks {
                        <View key={task.id} testID={"task-" + task.id} style={[S.card,
                            {"borderLeftWidth": 4, "borderLeftColor": "#b96543" if not task.completed and task.due < feed.now else C.accent}]}>
                            <View style={S.between}>
                                <Text style={S.eyebrow}>{task.course} · {task.priority.upper()}</Text>
                                <Text style={S.small}>{"COMPLETED" if task.completed else "OVERDUE" if task.due < feed.now else "UPCOMING"}</Text>
                            </View>
                            <Text style={[S.heading, {"textDecorationLine": "line-through" if task.completed else "none"}]}>{task.title}</Text>
                            <Text style={S.name}>Due {task.due.replace("T", " · ")}</Text>
                            {<Text selectable={True} style={S.body}>{task.notes}</Text> if task.notes else None}
                            <View style={S.row}>
                                <Button label={"Reopen" if task.completed else "Complete"} action={lambda { act("complete", task.id, not task.completed); }} disabled={busy}/>
                                <Button label="Edit" quiet={True} action={lambda { edit(task); }} disabled={busy}/>
                                <Button label="Break into steps ✦" quiet={True} disabled={busy} action={lambda { aiTitle = task.title; act("ai", task.id); }}/>
                                <Button label="Delete" quiet={True} action={lambda { deleting = task.id; }} disabled={busy}/>
                            </View>
                            {<View style={S.row}><Text style={S.body}>Delete this assignment?</Text>
                                <Button label="Confirm delete" action={lambda { act("delete", task.id); }} disabled={busy}/>
                                <Button label="Keep task" quiet={True} action={lambda { deleting = ""; }}/></View> if deleting == task.id else None}
                        </View>
                    }}
                    {<View style={[S.card, {"backgroundColor": "#e6eddf"}]}>
                        <Text style={S.eyebrow}>STUDY COACH ✦ AI BREAKDOWN</Text>
                        <Text style={S.heading}>{aiTitle}</Text>
                        <Text style={S.body}>{"Review these steps before adding them. They inherit the assignment’s deadline; edit dates to spread out your work." if ai.available else ai.message}</Text>
                        {[<Text key={step} style={S.body}>• {step}</Text> for step in ai.steps]}
                        {<Button label="Add these study steps" action={lambda { act("accept"); }} disabled={busy}/> if ai.available and ai.steps else None}
                        <Button label="Dismiss" quiet={True} action={lambda { aiTask = ""; ai = Breakdown(); }}/>
                    </View> if aiTask else None}
                </View>
            </View>
        </View> if logged and connected else None}
        <View style={S.footer}>
            {<Button label="Change server" quiet={True} action={lambda {
                jacLogout(); logged = False; connected = False; feed = Planner(); error = "";
            }}/> if remote and connected else None}
            <Text style={S.small}>Daymark · One semester. One step at a time.</Text>
        </View>
    </ScrollView>;
}
