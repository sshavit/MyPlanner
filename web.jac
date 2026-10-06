import from core.ui { PlannerApp }
import from core.web_date_controls { WebTimePicker, WebDateInput }
import from core.web_time_slot { WebTimeSlot }

def:pub app -> JsxElement {
    return <PlannerApp timePicker={WebTimePicker} dateInput={WebDateInput} timeSlot={WebTimeSlot}/>;
}
