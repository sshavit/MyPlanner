import from "@jac/mobui" { View, Text }
import from core.theme { S, C, SD, CD }

def:pub WebTimePicker(value: str, change: Callable, label: str = "Due date and time", dark: bool = False) -> JsxElement {
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
        <Text style={T.name}>{label}</Text>
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

def:pub WebDateInput(value: str, change: Callable, dark: bool = False) -> JsxElement {
    P = CD if dark else C;
    return <input aria-label="Choose calendar date" type="date" value={value}
        onChange={lambda (e: ChangeEvent) { change(e.target.value as str); }}
        style={{"padding": 13, "borderRadius": 12, "border": "1px solid " + P.line,
            "fontSize": 15, "backgroundColor": P.input, "color": P.ink,
            "colorScheme": "dark" if dark else "light"}}/>;
}
