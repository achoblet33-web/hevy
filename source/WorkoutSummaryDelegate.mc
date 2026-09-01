import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class WorkoutSummaryDelegate extends WatchUi.BehaviorDelegate {
    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onKey(keyEvent as WatchUi.KeyEvent) as Lang.Boolean {
        var key = keyEvent.getKey();
        if (key == WatchUi.KEY_ENTER || key == WatchUi.KEY_ESC) {
            System.exit();
            return true;
        }
        return false;
    }

    function onBack() as Lang.Boolean {
        System.exit();
        return true;
    }
}
