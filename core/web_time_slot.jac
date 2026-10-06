def:pub WebTimeSlot(style: any, start: Callable[[MouseEvent], None], enter: Callable[[MouseEvent], None], finish: Callable[[MouseEvent], None], tap: Callable, children: any = None) -> JsxElement {
    return <div style={style} onMouseDown={start} onMouseEnter={enter} onMouseUp={finish}>{children}</div>;
}
