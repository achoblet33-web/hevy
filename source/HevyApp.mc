import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class HevyApp extends Application.AppBase {
    private var mModel as WorkoutDataModel;
    private var mEngine as WorkoutEngineView or Null = null;

    function initialize() {
        AppBase.initialize();
        mModel = new WorkoutDataModel();
    }

    function onStart(state as Lang.Dictionary or Null) {
    }

    function onStop(state as Lang.Dictionary or Null) {
        if (mEngine != null) {
            (mEngine as WorkoutEngineView).onAppStop();
        }
    }

    function getInitialView() {
        var engine = new WorkoutEngineView(mModel);
        mEngine = engine;
        return [engine, new WorkoutEngineDelegate(engine)];
    }
}

function getApp() as HevyApp {
    return Application.getApp() as HevyApp;
}
