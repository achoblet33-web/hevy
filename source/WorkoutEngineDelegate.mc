import Toybox.Lang;
import Toybox.WatchUi;

class WorkoutEngineDelegate extends WatchUi.BehaviorDelegate {
    private var mView as WorkoutEngineView;

    function initialize(view as WorkoutEngineView) {
        BehaviorDelegate.initialize();
        mView = view;
    }

    function onKey(keyEvent as WatchUi.KeyEvent) as Lang.Boolean {
        var key = keyEvent.getKey();
        if (mView.isCancelConfirmationOpen()) {
            return true;
        }
        if (mView.isEditorOpen()) {
            if (key == WatchUi.KEY_UP) {
                mView.adjustEditor(1);
            } else if (key == WatchUi.KEY_DOWN) {
                mView.adjustEditor(-1);
            } else if (key == WatchUi.KEY_ENTER) {
                mView.acceptEditor();
            }
            return true;
        }
        if (key == WatchUi.KEY_ENTER) {
            mView.togglePause();
            return true;
        }
        if (mView.getState() == 0) {
            if (key == WatchUi.KEY_UP) {
                mView.moveRoutineSelection(-1);
                return true;
            }
            if (key == WatchUi.KEY_DOWN) {
                mView.moveRoutineSelection(1);
                return true;
            }
        }
        return false;
    }

    function onSwipe(swipeEvent as WatchUi.SwipeEvent) as Lang.Boolean {
        return mView.handleSwipe(swipeEvent.getDirection());
    }

    function onTap(clickEvent as WatchUi.ClickEvent) as Lang.Boolean {
        var coordinates = clickEvent.getCoordinates();
        var x = coordinates[0] as Lang.Number;
        var y = coordinates[1] as Lang.Number;
        mView.handleTap(x, y);
        return true;
    }

    function onBack() as Lang.Boolean {
        mView.handleLapBack();
        return true;
    }
}
