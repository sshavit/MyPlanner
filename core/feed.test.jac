import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from unittest.mock { patch }
import from jaclang.testing.testing { JacTestClient }
import from jaclang.byllm.lib { MockLLM }

def call(client: JacTestClient, name: str, fields: dict[str, any] | None = None) -> any {
    response = client.post("/function/" + name, json=fields or {});
    assert response.ok, response.text;
    return response.data["result"];
}

test "planner CRUD validation isolation filters and persistence" {
    with TemporaryDirectory() as folder {
        client = JacTestClient.from_file(str(Path(__file__).with_name("feed.jac")), base_path=folder);
        try {
            fields = {"title": "Build planner", "course": "EECS 449", "due": "2026-10-05T23:59", "priority": "high", "notes": "Web, mobile, CLI"};
            assert not client.post("/function/save_task", json=fields).ok;
            for name in ["alice", "bob"] { assert client.register_user(name, "planner-secret-123").ok; }
            assert client.login("alice", "planner-secret-123").ok;
            assert call(client, "join", {"username": "alice"}) == "alice";
            assert not client.post("/function/join", json={"username": "bob"}).ok;
            for bad in [{"title": " "}, {"due": "2026-02-30T23:00"}, {"due": "tomorrow"}, {"course": ""}, {"priority": "urgent"}, {"notes": "x" * 4001}] {
                assert not client.post("/function/save_task", json={**fields, **bad}).ok;
            }
            id = call(client, "save_task", fields);
            other = call(client, "save_task", {**fields, "title": "Read paper", "course": "EECS 445", "due": "2026-10-11T10:00", "priority": "low"});
            call(client, "save_task", {**fields, "title": "Next Monday", "due": "2026-10-12T10:00"});
            day = call(client, "load_planner", {"mode": "day", "day": "2026-10-05"});
            assert len(day["tasks"]) == 1;
            assert day["tasks"][0]["id"] == id;
            week = call(client, "load_planner", {"mode": "week", "day": "2026-10-07"});
            assert len(week["tasks"]) == 2;
            assert week["days"][0] == "2026-10-05" and week["days"][6] == "2026-10-11";
            filtered = call(client, "load_planner", {"mode": "all", "course": "EECS 445", "priority": "low"});
            assert len(filtered["tasks"]) == 1 and filtered["tasks"][0]["id"] == other;
            assert call(client, "complete_task", {"task_id": id}) is True;
            assert call(client, "complete_task", {"task_id": id}) is True;
            done = call(client, "load_planner", {"mode": "all", "status": "completed"});
            assert len(done["tasks"]) == 1;
            assert done["completed"] == 1 and done["total"] == 3;
            call(client, "save_task", {**fields, "task_id": id, "title": "Planner revised"});
            assert call(client, "load_planner", {"mode": "all", "status": "completed"})["tasks"][0]["title"] == "Planner revised";
            assert client.login("bob", "planner-secret-123").ok;
            call(client, "join", {"username": "bob"});
            assert not call(client, "load_planner", {"mode": "all"})["tasks"];
            for endpoint in ["complete_task", "delete_task", "break_down"] {
                assert not client.post("/function/" + endpoint, json={"task_id": id}).ok;
            }
            assert not client.post("/function/save_task", json={**fields, "task_id": id}).ok;
            assert not client.post("/function/accept_steps", json={"task_id": id, "steps": ["Steal"]}).ok;
            assert client.login("alice", "planner-secret-123").ok;
            call(client, "complete_task", {"task_id": id, "completed": False});
            steps = call(client, "accept_steps", {"task_id": id, "steps": ["Sketch API", "Test workflows"]});
            assert len(steps) == 2;
            assert len(call(client, "load_planner", {"mode": "all"})["tasks"]) == 5;
            assert not client.post("/function/accept_steps", json={"task_id": id, "steps": ["Fine", ""]}).ok;
            assert len(call(client, "load_planner", {"mode": "all"})["tasks"]) == 5;
            call(client, "delete_task", {"task_id": other});
            assert not client.post("/function/delete_task", json={"task_id": other}).ok;
            client.close();
            client = JacTestClient.from_file(str(Path(__file__).with_name("feed.jac")), base_path=folder);
            assert client.login("alice", "planner-secret-123").ok;
            restored = call(client, "load_planner", {"mode": "all"});
            assert len(restored["tasks"]) == 4;
            assert any(t["title"] == "Planner revised" for t in restored["tasks"]);
            client.clear_auth();
            assert not call(client, "load_planner", {"mode": "all"})["tasks"];
        } finally { client.close(); JacRuntime.set_shared_root_resolver(None); }
    }
}

test "date boundaries and dashboard counts" {
    with TemporaryDirectory() as folder {
        client = JacTestClient.from_file(str(Path(__file__).with_name("feed.jac")), base_path=folder);
        try {
            assert client.register_user("dates", "planner-secret-123").ok;
            assert client.login("dates", "planner-secret-123").ok;
            call(client, "join", {"username": "dates"});
            now = clock();
            past = (now - datetime.timedelta(days=1)).strftime("%Y-%m-%dT%H:%M");
            future = (now + datetime.timedelta(days=1)).strftime("%Y-%m-%dT%H:%M");
            far = (now + datetime.timedelta(days=8)).strftime("%Y-%m-%dT%H:%M");
            for due in [past, future, far] {
                call(client, "save_task", {"title": due, "course": "EECS 449", "due": due});
            }
            dashboard = call(client, "load_planner");
            assert dashboard["overdue"] == 1 and dashboard["upcoming"] == 1;
            assert len(dashboard["tasks"]) == 2;
            assert len(call(client, "load_planner", {"mode": "upcoming"})["tasks"]) == 1;
        } finally { client.close(); JacRuntime.set_shared_root_resolver(None); }
    }
}

test "events allow no group including recurring edits" {
    with TemporaryDirectory() as folder {
        client = JacTestClient.from_file(str(Path(__file__).with_name("feed.jac")), base_path=folder);
        try {
            assert client.register_user("events", "planner-secret-123").ok;
            assert client.login("events", "planner-secret-123").ok;
            call(client, "join", {"username": "events"});
            fields = {"title": "Personal event", "course": "", "start": "2026-10-05T12:00", "end": "2026-10-05T13:00"};
            id = call(client, "save_event", fields);
            call(client, "save_event", {**fields, "event_id": id, "course": " "});
            ids = call(client, "create_recurring_event", {**fields, "course": "Club", "occurrences": 2});
            assert call(client, "update_event_series", {**fields, "event_id": ids[0]}) == 2;
            call(client, "create_recurring_event", {**fields, "occurrences": 2});
            planner = call(client, "load_planner", {"mode": "all"});
            assert len(planner["tasks"]) == 5;
            assert all(t["course"] == "" for t in planner["tasks"]);
            assert planner["courses"] == [] and planner["groups"] == [];
            assert not client.post("/function/save_event", json={**fields, "course": "x" * 61}).ok;
        } finally { client.close(); JacRuntime.set_shared_root_resolver(None); }
    }
}

test "AI delegates typed study steps through by llm" {
    fake = MockLLM(outputs=[["Read the rubric", "Implement the API", "Test the app"]]);
    with patch(__name__ + ".llm", fake) {
        steps = propose_steps("Planner", "EECS 449", "2026-10-09T23:59", "Jac coursework");
        assert len(steps) == 3;
        assert steps[1] == "Implement the API";
        assert "EECS 449" in str(fake.sent("messages"));
    }
}
