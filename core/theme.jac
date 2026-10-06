import from "@jac/mobui" { StyleSheet }

obj Colors {
    has ink: str = "#17213C",
        muted: str = "#68738D",
        paper: str = "#F5F7FD",
        card: str = "#FFFFFF",
        line: str = "#E3E8F4",
        accent: str = "#5B5FF0",
        purple: str = "#8A5CF6",
        blue: str = "#477BF5",
        pale: str = "#EEF0FF",
        navy: str = "#18224A",
        input: str = "#FAFBFF",
        buttonInk: str = "#FFFFFF",
        successBg: str = "#E9F7F1",
        successInk: str = "#137359",
        errorBg: str = "#FFF0EF",
        errorInk: str = "#AB3E48";
}

def buildStyles(c: Colors) -> any {
    return StyleSheet.create(
         {
             "screen": {"flex": 1, "backgroundColor": c.paper},
             "page": {"width": "100%", "maxWidth": 1480, "alignSelf": "center", "padding": 16, "gap": 12},
             "header": {"flexDirection": "row", "justifyContent": "space-between", "alignItems": "center", "gap": 16, "paddingVertical": 6},
             "brand": {"fontSize": 25, "fontWeight": "800", "color": c.ink, "letterSpacing": -1},
             "brandMark": {"width": 40, "height": 40, "borderRadius": 13, "backgroundColor": c.accent, "alignItems": "center", "justifyContent": "center"},
             "brandMarkText": {"fontSize": 23, "fontWeight": "800", "color": "#FFFFFF"},
             "hero": {"backgroundColor": c.navy, "borderRadius": 28, "padding": 32, "gap": 15, "overflow": "hidden"},
             "heroGlow": {"position": "absolute", "right": -70, "top": -110, "width": 350, "height": 350, "borderRadius": 175, "backgroundColor": "#343E88"},
             "heroGlowSmall": {"position": "absolute", "right": 135, "bottom": -120, "width": 240, "height": 240, "borderRadius": 120, "backgroundColor": "#35327A"},
             "heroEyebrow": {"fontSize": 12, "fontWeight": "800", "letterSpacing": 2, "color": "#B9B9FF"},
             "heroTitle": {"fontSize": 40, "fontWeight": "800", "letterSpacing": -1.5, "color": "#FFFFFF"},
             "heroText": {"fontSize": 16, "lineHeight": 25, "color": "#C9D3F3"},
             "heading": {"fontSize": 22, "fontWeight": "800", "letterSpacing": -0.5, "color": c.ink},
             "title": {"fontSize": 38, "fontWeight": "800", "letterSpacing": -1.5, "color": c.ink},
             "subtitle": {"fontSize": 16, "lineHeight": 25, "color": c.muted},
             "eyebrow": {"fontSize": 11, "fontWeight": "800", "letterSpacing": 1.5, "color": c.accent},
             "row": {"flexDirection": "row", "gap": 10, "alignItems": "center", "flexWrap": "wrap"},
             "between": {"flexDirection": "row", "justifyContent": "space-between", "alignItems": "center", "gap": 12, "flexWrap": "wrap"},
             "stack": {"gap": 10},
             "card": {"backgroundColor": c.card, "borderWidth": 1, "borderColor": c.line, "borderRadius": 22, "padding": 22, "gap": 16},
             "metric": {"flex": 1, "minWidth": 210, "padding": 24, "gap": 8, "borderRadius": 22, "borderWidth": 1, "borderColor": c.line, "backgroundColor": c.card},
             "metricLabel": {"fontSize": 12, "fontWeight": "800", "letterSpacing": 1, "color": c.muted},
             "metricHint": {"fontSize": 13, "color": c.muted},
             "score": {"fontSize": 40, "fontWeight": "800", "color": c.ink, "letterSpacing": -2},
             "input": {"borderWidth": 1, "borderColor": c.line, "borderRadius": 12, "padding": 13, "fontSize": 15, "color": c.ink, "backgroundColor": c.input},
             "composer": {"minHeight": 95, "textAlignVertical": "top"},
             "button": {"backgroundColor": c.accent, "paddingHorizontal": 17, "paddingVertical": 11, "borderRadius": 11, "alignItems": "center", "justifyContent": "center"},
             "buttonText": {"color": c.buttonInk, "fontWeight": "700", "fontSize": 14},
             "quiet": {"backgroundColor": c.pale},
             "quietText": {"color": c.accent},
             "body": {"fontSize": 15, "lineHeight": 24, "color": c.ink},
             "small": {"fontSize": 12, "lineHeight": 19, "color": c.muted},
             "name": {"fontSize": 14, "fontWeight": "700", "color": c.ink},
             "success": {"padding": 14, "borderRadius": 12, "backgroundColor": c.successBg, "color": c.successInk},
             "error": {"padding": 14, "borderRadius": 12, "backgroundColor": c.errorBg, "color": c.errorInk, "fontSize": 14},
             "footer": {"paddingVertical": 20, "borderTopWidth": 1, "borderTopColor": c.line}
         }
     );
}

glob:pub C = Colors(),
    CD = Colors(ink="#F2F5FF", muted="#AAB5CF", paper="#0E1424", card="#1A2338", line="#303B55", accent="#A7A8FF", purple="#C9A8FF", blue="#92B8FF", pale="#2A3455", navy="#18224A", input="#222D45", buttonInk="#161B37", successBg="#193E36", successInk="#89DFC2", errorBg="#4A2732", errorInk="#FFB5BE"),
    S = buildStyles(C),
    SD = buildStyles(CD);
