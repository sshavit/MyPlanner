import from "@jac/mobui" { View, Text, TextInput, Pressable }
import from core.theme { S, C, SD, CD }

def:pub TimePicker(value: str, change: Callable, label: str = "Due date and time", dark: bool = False) -> JsxElement {
    T = SD if dark else S;
    P = CD if dark else C;
    date = value[:10] if len(value) >= 10 else "2026-01-01";
    hour24 = int(value[11:13]) if len(value) >= 13 else 12;
    hour12 = hour24 % 12 if hour24 % 12 else 12;
    minute = value[14:16] if len(value) >= 16 else "00";
    period = "AM" if hour24 < 12 else "PM";
    def setTime(nextHour: str = str(hour12), nextMinute: str = minute, nextPeriod: str = period) {
        h12 = int(nextHour);
        h24 = h12 % 12 + (12 if nextPeriod == "PM" else 0);
        change(date + "T" + f"{h24:02d}" + ":" + nextMinute[:2]);
    }
    return <View style={{"gap": 6}}>
        <Text style={T.name}>{label}</Text>
        <TextInput accessibilityLabel="Due date" value={date} placeholder="YYYY-MM-DD"
            onChangeText={lambda (t: str) { change(t + "T" + f"{hour24:02d}" + ":" + minute[:2]); }}
            style={T.input} placeholderTextColor={P.muted}/>
        <View style={T.row}>
            <Pressable accessibilityRole="button" accessibilityLabel="Hour" style={T.button}
                onPress={lambda { setTime(str(hour12 % 12 + 1)); }}><Text style={T.buttonText}>{"Hour " + str(hour12)}</Text></Pressable>
            <Pressable accessibilityRole="button" accessibilityLabel="Minute" style={T.button}
                onPress={lambda { setTime(str(hour12), "59" if int(minute) == 55 else "00" if int(minute) == 59 else f"{(int(minute) // 5 * 5 + 5) % 60:02d}"); }}><Text style={T.buttonText}>{"Minute " + minute}</Text></Pressable>
            <Pressable accessibilityRole="button" accessibilityLabel="AM or PM" style={T.button}
                onPress={lambda { setTime(str(hour12), minute, "PM" if period == "AM" else "AM"); }}><Text style={T.buttonText}>{period}</Text></Pressable>
        </View>
    </View>;
}

def:pub DateInput(value: str, change: Callable, dark: bool = False) -> JsxElement {
    T = SD if dark else S;
    P = CD if dark else C;
    return <TextInput accessibilityLabel="Choose calendar date" value={value} placeholder="YYYY-MM-DD"
        onChangeText={change} style={T.input} placeholderTextColor={P.muted}/>;
}
