import from "@jac/mobui" { Pressable }

def:pub TimeSlot(style: any, start: Callable, enter: Callable, finish: Callable, tap: Callable, children: any = None) -> JsxElement {
    return <Pressable style={style} onPress={tap}>{children}</Pressable>;
}
