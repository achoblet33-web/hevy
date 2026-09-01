import Toybox.Activity;
import Toybox.ActivityRecording;
import Toybox.Attention;
import Toybox.FitContributor;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Sensor;
import Toybox.System;
import Toybox.Time;
import Toybox.Timer;
import Toybox.WatchUi;

class WorkoutEngineView extends WatchUi.View {
    const STATE_PREPARATION = 0;
    const STATE_ACTIVE_SET = 1;
    const STATE_REST = 2;
    const STATE_PAUSED = 3;

    private const FIT_WEIGHT_FIELD_ID = 0;
    private const FIT_REPS_FIELD_ID = 1;
    private const WEIGHT_STEP_KG = 2.5;
    private const REST_STEP_SECONDS = 15;

    private const COLOR_GREEN = 0x00E676;
    private const COLOR_BLUE = 0x29B6F6;
    private const COLOR_ORANGE = 0xFF9800;
    private const COLOR_RED = 0xFF5252;
    private const COLOR_MUTED = 0x8A8A8A;
    private const COLOR_PANEL = 0x181818;

    private var mModel as WorkoutDataModel;
    private var mState as Lang.Number = STATE_PREPARATION;
    private var mStateBeforePause as Lang.Number = STATE_ACTIVE_SET;
    private var mWidth as Lang.Number = 454;
    private var mHeight as Lang.Number = 454;

    private var mRoutines as Lang.Array = [];
    private var mSelectedRoutineIndex as Lang.Number = 0;
    private var mRoutine as Lang.Dictionary or Null = null;
    private var mRoutineTitle as Lang.String = "Hevy";
    private var mCurrentExerciseIndex as Lang.Number = 0;
    private var mCurrentSetIndex as Lang.Number = 0;
    private var mCurrentWeight as Lang.Float = 0.0;
    private var mCurrentReps as Lang.Number = 0;
    private var mRestRemaining as Lang.Number = 90;
    private var mWorkoutSeconds as Lang.Number = 0;
    private var mSessionStartSeconds as Lang.Number = 0;
    private var mCompletedSetsHistory as Lang.Array = [];

    private var mSession as ActivityRecording.Session or Null = null;
    private var mWeightField as FitContributor.Field or Null = null;
    private var mRepsField as FitContributor.Field or Null = null;
    private var mTicker as Timer.Timer or Null = null;

    private var mNetworkStarted as Lang.Boolean = false;
    private var mLoading as Lang.Boolean = false;
    private var mFinishing as Lang.Boolean = false;
    private var mMessage as Lang.String = "Préparation";

    function initialize(model as WorkoutDataModel) {
        View.initialize();
        mModel = model;
        var settings = System.getDeviceSettings();
        mWidth = settings.screenWidth;
        mHeight = settings.screenHeight;
        mRoutines = mModel.getCachedRoutines();
        if (mRoutines.size() > 0) {
            mMessage = "Cache disponible";
        }
    }

    function onShow() as Void {
        if (!mNetworkStarted) {
            mNetworkStarted = true;
            mLoading = true;
            mMessage = "Synchronisation...";
            mModel.flushOldestPending(method(:onPendingFlushed));
        }
    }

    function onHide() as Void {
        stopTicker();
    }

    private function onPendingFlushed(success as Lang.Boolean, remaining as Lang.Number) as Void {
        mLoading = false;
        requestRoutines();
    }

    function requestRoutines() as Void {
        if (mLoading) {
            return;
        }
        if (!mModel.hasApiKey()) {
            mLoading = false;
            mMessage = mRoutines.size() > 0 ? "Mode hors ligne" : "Configurer la clé API";
            WatchUi.requestUpdate();
            return;
        }
        mLoading = true;
        mMessage = "Chargement Hevy...";
        mModel.fetchRoutines(method(:onRoutinesLoaded));
        WatchUi.requestUpdate();
    }

    private function onRoutinesLoaded(responseCode as Lang.Number, routines as Lang.Array or Null) as Void {
        mLoading = false;
        if (routines != null && (routines as Lang.Array).size() > 0) {
            mRoutines = routines as Lang.Array;
            if (mSelectedRoutineIndex >= mRoutines.size()) {
                mSelectedRoutineIndex = 0;
            }
            mMessage = "Routines à jour";
        } else if (mRoutines.size() > 0) {
            mMessage = "Hors ligne - cache";
        } else {
            mMessage = responseCode == -2 ? "Configurer la clé API" : "Connexion indisponible";
        }
        WatchUi.requestUpdate();
    }

    private function startTicker() as Void {
        if (mTicker == null && !mFinishing) {
            mTicker = new Timer.Timer();
            (mTicker as Timer.Timer).start(method(:onTick), 1000, true);
        }
    }

    private function stopTicker() as Void {
        if (mTicker != null) {
            (mTicker as Timer.Timer).stop();
            mTicker = null;
        }
    }

    private function onTick() as Void {
        if (mState == STATE_ACTIVE_SET || mState == STATE_REST) {
            mWorkoutSeconds += 1;
        }
        if (mState == STATE_REST) {
            if (mRestRemaining > 0) {
                mRestRemaining -= 1;
            }
            if (mRestRemaining <= 0) {
                vibrateRestFinished();
                mState = STATE_ACTIVE_SET;
            }
        }
        WatchUi.requestUpdate();
    }

    private function vibrateRestFinished() as Void {
        try {
            Attention.vibrate([
                new Attention.VibeProfile(80, 180),
                new Attention.VibeProfile(0, 120),
                new Attention.VibeProfile(80, 180)
            ]);
        } catch (error) {
        }
    }

    function getState() as Lang.Number {
        return mState;
    }

    function moveRoutineSelection(delta as Lang.Number) as Void {
        if (mState != STATE_PREPARATION || mRoutines.size() == 0) {
            return;
        }
        mSelectedRoutineIndex += delta;
        if (mSelectedRoutineIndex < 0) {
            mSelectedRoutineIndex = mRoutines.size() - 1;
        } else if (mSelectedRoutineIndex >= mRoutines.size()) {
            mSelectedRoutineIndex = 0;
        }
        WatchUi.requestUpdate();
    }

    function startSelectedRoutine() as Void {
        if (mState != STATE_PREPARATION || mRoutines.size() == 0 || mLoading) {
            return;
        }
        var selected = mRoutines[mSelectedRoutineIndex];
        if (!(selected instanceof Lang.Dictionary)) {
            return;
        }

        mRoutine = selected as Lang.Dictionary;
        mRoutineTitle = dictionaryString(mRoutine as Lang.Dictionary, "title", "Séance Hevy");
        mCurrentExerciseIndex = 0;
        mCurrentSetIndex = 0;
        mCompletedSetsHistory = [];
        mWorkoutSeconds = 0;
        mSessionStartSeconds = Time.now().value();
        loadCurrentTarget();
        createFitSession();
        mState = STATE_ACTIVE_SET;
        startTicker();
        mMessage = "Séance active";
        persistDraft();
        WatchUi.requestUpdate();
    }

    private function createFitSession() as Void {
        try {
            Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE]);
            var fitName = mRoutineTitle.length() > 30
                ? (mRoutineTitle.substring(0, 30) as Lang.String)
                : mRoutineTitle;
            mSession = ActivityRecording.createSession({
                :name => fitName,
                :sport => Activity.SPORT_TRAINING,
                :subSport => Activity.SUB_SPORT_STRENGTH_TRAINING
            });
            if (mSession == null) {
                mMessage = "FIT indisponible";
                return;
            }

            var session = mSession as ActivityRecording.Session;
            mWeightField = session.createField(
                "weight_kg",
                FIT_WEIGHT_FIELD_ID,
                FitContributor.DATA_TYPE_FLOAT,
                { :mesgType => FitContributor.MESG_TYPE_LAP, :units => "kg" }
            );
            mRepsField = session.createField(
                "repetitions",
                FIT_REPS_FIELD_ID,
                FitContributor.DATA_TYPE_UINT16,
                { :mesgType => FitContributor.MESG_TYPE_LAP, :units => "reps" }
            );
            session.start();
        } catch (error) {
            Sensor.setEnabledSensors([]);
            mSession = null;
            mWeightField = null;
            mRepsField = null;
            mMessage = "FIT indisponible";
        }
    }

    function togglePause() as Void {
        if (mState == STATE_ACTIVE_SET || mState == STATE_REST) {
            mStateBeforePause = mState;
            mState = STATE_PAUSED;
            stopTicker();
            stopFitRecording();
        } else if (mState == STATE_PAUSED) {
            mState = mStateBeforePause;
            startFitRecording();
            startTicker();
        }
        WatchUi.requestUpdate();
    }

    private function stopFitRecording() as Void {
        if (mSession != null && (mSession as ActivityRecording.Session).isRecording()) {
            (mSession as ActivityRecording.Session).stop();
        }
    }

    private function startFitRecording() as Void {
        if (mSession != null && !(mSession as ActivityRecording.Session).isRecording()) {
            (mSession as ActivityRecording.Session).start();
        }
    }

    function handleLapBack() as Void {
        if (mState == STATE_PREPARATION) {
            System.exit();
        } else if (mState == STATE_ACTIVE_SET) {
            logCurrentSet();
        } else if (mState == STATE_REST) {
            skipRest();
        }
    }

    function handleTap(x as Lang.Number, y as Lang.Number) as Void {
        var bottomStart = (mHeight * 77) / 100;
        var centerX = mWidth / 2;
        var centerY = mHeight / 2;

        if (mState == STATE_PREPARATION) {
            if (y > bottomStart) {
                if (x < centerX) {
                    startSelectedRoutine();
                } else {
                    requestRoutines();
                }
            } else if (y < centerY) {
                moveRoutineSelection(-1);
            } else {
                moveRoutineSelection(1);
            }
            return;
        }

        if (y > bottomStart) {
            if (x < centerX) {
                if (mState == STATE_ACTIVE_SET) {
                    logCurrentSet();
                } else if (mState == STATE_REST) {
                    skipRest();
                } else if (mState == STATE_PAUSED) {
                    togglePause();
                }
            } else {
                finishWorkout();
            }
            return;
        }

        if (mState == STATE_ACTIVE_SET) {
            var direction = y < centerY ? 1 : -1;
            if (x < centerX) {
                adjustReps(direction);
            } else {
                adjustWeight(direction);
            }
        } else if (mState == STATE_REST) {
            adjustRest(y < centerY ? REST_STEP_SECONDS : -REST_STEP_SECONDS);
        }
    }

    private function adjustReps(delta as Lang.Number) as Void {
        mCurrentReps += delta;
        if (mCurrentReps < 0) {
            mCurrentReps = 0;
        } else if (mCurrentReps > 999) {
            mCurrentReps = 999;
        }
        WatchUi.requestUpdate();
    }

    private function adjustWeight(direction as Lang.Number) as Void {
        mCurrentWeight += WEIGHT_STEP_KG * direction;
        if (mCurrentWeight < 0.0) {
            mCurrentWeight = 0.0;
        } else if (mCurrentWeight > 999.0) {
            mCurrentWeight = 999.0;
        }
        WatchUi.requestUpdate();
    }

    private function adjustRest(delta as Lang.Number) as Void {
        mRestRemaining += delta;
        if (mRestRemaining < 0) {
            mRestRemaining = 0;
        } else if (mRestRemaining > 600) {
            mRestRemaining = 600;
        }
        WatchUi.requestUpdate();
    }

    private function skipRest() as Void {
        if (mState == STATE_REST) {
            mRestRemaining = 0;
            mState = STATE_ACTIVE_SET;
            WatchUi.requestUpdate();
        }
    }

    private function logCurrentSet() as Void {
        if (mState != STATE_ACTIVE_SET || mRoutine == null) {
            return;
        }

        var exercise = getCurrentExercise();
        var targetSet = getCurrentTargetSet();
        if (exercise == null || targetSet == null) {
            return;
        }

        var completed = {
            "exercise_template_id" => dictionaryString(exercise as Lang.Dictionary, "exercise_template_id", ""),
            "exercise_title" => dictionaryString(exercise as Lang.Dictionary, "title", "Exercice"),
            "exercise_index" => mCurrentExerciseIndex,
            "set_index" => mCurrentSetIndex,
            "type" => dictionaryString(targetSet as Lang.Dictionary, "type", "normal"),
            "weight_kg" => mCurrentWeight,
            "reps" => mCurrentReps
        };
        mCompletedSetsHistory.add(completed);

        if (mWeightField != null) {
            (mWeightField as FitContributor.Field).setData(mCurrentWeight);
        }
        if (mRepsField != null) {
            (mRepsField as FitContributor.Field).setData(mCurrentReps);
        }
        if (mSession != null && (mSession as ActivityRecording.Session).isRecording()) {
            (mSession as ActivityRecording.Session).addLap();
        }

        var rest = dictionaryNumber(exercise as Lang.Dictionary, "rest_seconds", 90);
        if (!advanceCursor()) {
            persistDraft();
            finishWorkout();
            return;
        }

        loadCurrentTarget();
        mRestRemaining = rest;
        mState = STATE_REST;
        persistDraft();
        WatchUi.requestUpdate();
    }

    private function advanceCursor() as Lang.Boolean {
        var exercise = getCurrentExercise();
        if (exercise == null) {
            return false;
        }
        var rawSets = (exercise as Lang.Dictionary)["sets"];
        if (rawSets instanceof Lang.Array && mCurrentSetIndex + 1 < (rawSets as Lang.Array).size()) {
            mCurrentSetIndex += 1;
            return true;
        }

        var exercises = getExercises();
        if (mCurrentExerciseIndex + 1 < exercises.size()) {
            mCurrentExerciseIndex += 1;
            mCurrentSetIndex = 0;
            return true;
        }
        return false;
    }

    private function loadCurrentTarget() as Void {
        var targetSet = getCurrentTargetSet();
        if (targetSet == null) {
            mCurrentWeight = 0.0;
            mCurrentReps = 0;
            return;
        }
        mCurrentWeight = dictionaryFloat(targetSet as Lang.Dictionary, "weight_kg", 0.0);
        mCurrentReps = dictionaryNumber(targetSet as Lang.Dictionary, "reps", 0);
    }

    private function getExercises() as Lang.Array {
        if (mRoutine == null) {
            return [];
        }
        var raw = (mRoutine as Lang.Dictionary)["exercises"];
        if (raw instanceof Lang.Array) {
            return raw as Lang.Array;
        }
        return [];
    }

    private function getCurrentExercise() as Lang.Dictionary or Null {
        var exercises = getExercises();
        if (mCurrentExerciseIndex < 0 || mCurrentExerciseIndex >= exercises.size()) {
            return null;
        }
        var value = exercises[mCurrentExerciseIndex];
        if (value instanceof Lang.Dictionary) {
            return value as Lang.Dictionary;
        }
        return null;
    }

    private function getCurrentTargetSet() as Lang.Dictionary or Null {
        var exercise = getCurrentExercise();
        if (exercise == null) {
            return null;
        }
        var rawSets = (exercise as Lang.Dictionary)["sets"];
        if (!(rawSets instanceof Lang.Array)) {
            return null;
        }
        var sets = rawSets as Lang.Array;
        if (mCurrentSetIndex < 0 || mCurrentSetIndex >= sets.size()) {
            return null;
        }
        var value = sets[mCurrentSetIndex];
        if (value instanceof Lang.Dictionary) {
            return value as Lang.Dictionary;
        }
        return null;
    }

    private function persistDraft() as Void {
        if (mRoutine == null) {
            return;
        }
        mModel.saveDraft({
            "routine_title" => mRoutineTitle,
            "routine" => mRoutine as Lang.Dictionary,
            "exercise_index" => mCurrentExerciseIndex,
            "set_index" => mCurrentSetIndex,
            "start_time" => mSessionStartSeconds,
            "workout_seconds" => mWorkoutSeconds,
            "completed_sets" => mCompletedSetsHistory
        });
    }

    function finishWorkout() as Void {
        if (mFinishing || mState == STATE_PREPARATION) {
            return;
        }
        mFinishing = true;
        stopTicker();
        persistDraft();

        var summary = new WorkoutSummaryView(
            mModel,
            mRoutineTitle,
            mSessionStartSeconds,
            Time.now().value(),
            mWorkoutSeconds,
            mCompletedSetsHistory,
            mSession
        );
        WatchUi.pushView(summary, new WorkoutSummaryDelegate(), WatchUi.SLIDE_UP);
    }

    function onAppStop() as Void {
        stopTicker();
        if (!mFinishing && mState != STATE_PREPARATION && mSession != null) {
            var session = mSession as ActivityRecording.Session;
            if (session.isRecording()) {
                session.stop();
            }
            session.save();
            Sensor.setEnabledSensors([]);
            persistDraft();
        }
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setAntiAlias(true);

        if (mState == STATE_PREPARATION) {
            drawPreparation(dc);
        } else if (mState == STATE_ACTIVE_SET) {
            drawActiveSet(dc);
        } else if (mState == STATE_REST) {
            drawRest(dc);
        } else {
            drawPaused(dc);
        }
    }

    private function drawPreparation(dc as Graphics.Dc) as Void {
        drawHeader(dc, "HEVY", COLOR_GREEN);
        if (mRoutines.size() == 0) {
            drawFittedText(dc, mWidth / 2, percentY(34), Graphics.FONT_MEDIUM, mMessage, COLOR_MUTED, percentX(68));
            drawFittedText(dc, mWidth / 2, percentY(47), Graphics.FONT_SMALL, "Synchronisez une routine", Graphics.COLOR_WHITE, percentX(70));
            drawButton(dc, false, "AUCUNE", COLOR_MUTED);
            drawButton(dc, true, "SYNC", COLOR_BLUE);
            return;
        }

        var selected = mRoutines[mSelectedRoutineIndex] as Lang.Dictionary;
        drawFittedText(dc, mWidth / 2, percentY(25), Graphics.FONT_XTINY, "ROUTINE " + (mSelectedRoutineIndex + 1) + "/" + mRoutines.size(), COLOR_MUTED, percentX(62));
        drawFittedText(dc, mWidth / 2, percentY(36), Graphics.FONT_LARGE, dictionaryString(selected, "title", "Routine"), Graphics.COLOR_WHITE, percentX(72));
        drawFittedText(dc, mWidth / 2, percentY(56), Graphics.FONT_XTINY, "TOUCHEZ HAUT / BAS", COLOR_MUTED, percentX(64));
        drawFittedText(dc, mWidth / 2, percentY(64), Graphics.FONT_XTINY, mMessage, COLOR_GREEN, percentX(64));
        drawButton(dc, false, "START", COLOR_GREEN);
        drawButton(dc, true, "SYNC", COLOR_BLUE);
    }

    private function drawActiveSet(dc as Graphics.Dc) as Void {
        var exercise = getCurrentExercise();
        var exerciseTitle = exercise == null ? "Exercice" : dictionaryString(exercise as Lang.Dictionary, "title", "Exercice");
        drawHeader(dc, formatDuration(mWorkoutSeconds), COLOR_GREEN);
        drawFittedText(dc, mWidth / 2, percentY(19), Graphics.FONT_MEDIUM, exerciseTitle, Graphics.COLOR_WHITE, percentX(74));
        drawFittedText(dc, mWidth / 2, percentY(30), Graphics.FONT_XTINY, "SÉRIE " + (mCurrentSetIndex + 1), COLOR_MUTED, percentX(55));

        drawFittedText(dc, percentX(29), percentY(43), Graphics.FONT_XTINY, "REPS", COLOR_BLUE, percentX(27));
        drawFittedText(dc, percentX(29), percentY(51), Graphics.FONT_LARGE, mCurrentReps.toString(), Graphics.COLOR_WHITE, percentX(30));
        drawFittedText(dc, percentX(71), percentY(43), Graphics.FONT_XTINY, "POIDS KG", COLOR_ORANGE, percentX(27));
        drawFittedText(dc, percentX(71), percentY(51), Graphics.FONT_LARGE, mCurrentWeight.format("%.1f"), Graphics.COLOR_WHITE, percentX(30));
        drawFittedText(dc, mWidth / 2, percentY(68), Graphics.FONT_XTINY, "HAUT +   •   BAS -", COLOR_MUTED, percentX(60));
        drawButton(dc, false, "LOG SET", COLOR_GREEN);
        drawButton(dc, true, "FINISH", COLOR_RED);
    }

    private function drawRest(dc as Graphics.Dc) as Void {
        drawHeader(dc, "REPOS", COLOR_ORANGE);
        drawFittedText(dc, mWidth / 2, percentY(29), Graphics.FONT_XTINY, "PROCHAINE SÉRIE", COLOR_MUTED, percentX(60));
        drawFittedText(dc, mWidth / 2, percentY(39), Graphics.FONT_LARGE, formatDuration(mRestRemaining), Graphics.COLOR_WHITE, percentX(66));
        var exercise = getCurrentExercise();
        var nextTitle = exercise == null ? "" : dictionaryString(exercise as Lang.Dictionary, "title", "");
        drawFittedText(dc, mWidth / 2, percentY(57), Graphics.FONT_SMALL, nextTitle, COLOR_BLUE, percentX(70));
        drawFittedText(dc, mWidth / 2, percentY(67), Graphics.FONT_XTINY, "HAUT +15s   •   BAS -15s", COLOR_MUTED, percentX(66));
        drawButton(dc, false, "SKIP", COLOR_ORANGE);
        drawButton(dc, true, "FINISH", COLOR_RED);
    }

    private function drawPaused(dc as Graphics.Dc) as Void {
        drawHeader(dc, "PAUSE", COLOR_ORANGE);
        drawFittedText(dc, mWidth / 2, percentY(36), Graphics.FONT_LARGE, formatDuration(mWorkoutSeconds), Graphics.COLOR_WHITE, percentX(60));
        drawFittedText(dc, mWidth / 2, percentY(54), Graphics.FONT_SMALL, "START pour reprendre", COLOR_MUTED, percentX(70));
        drawButton(dc, false, "RESUME", COLOR_GREEN);
        drawButton(dc, true, "FINISH", COLOR_RED);
    }

    private function drawHeader(dc as Graphics.Dc, text as Lang.String, color as Lang.Number) as Void {
        drawFittedText(dc, mWidth / 2, percentY(8), Graphics.FONT_SMALL, text, color, percentX(55));
    }

    private function drawButton(dc as Graphics.Dc, right as Lang.Boolean, label as Lang.String, color as Lang.Number) as Void {
        var x = right ? percentX(52) : percentX(18);
        var y = percentY(78);
        var width = percentX(30);
        var height = percentY(10);
        dc.setColor(COLOR_PANEL, Graphics.COLOR_BLACK);
        dc.fillRoundedRectangle(x, y, width, height, 12);
        drawFittedText(dc, x + (width / 2), y + (height / 2) - 9, Graphics.FONT_XTINY, label, color, width - 10);
    }

    private function drawFittedText(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number, font, text as Lang.String, color as Lang.Number, maxWidth as Lang.Number) as Void {
        var output = text;
        while (output.length() > 3 && dc.getTextWidthInPixels(output, font) > maxWidth) {
            output = output.substring(0, output.length() - 2) as Lang.String;
        }
        if (output.length() < text.length()) {
            output += "…";
        }
        dc.setColor(color, Graphics.COLOR_BLACK);
        dc.drawText(x, y, font, output, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function percentX(value as Lang.Number) as Lang.Number {
        return (mWidth * value) / 100;
    }

    private function percentY(value as Lang.Number) as Lang.Number {
        return (mHeight * value) / 100;
    }

    private function formatDuration(totalSeconds as Lang.Number) as Lang.String {
        var safeSeconds = totalSeconds < 0 ? 0 : totalSeconds;
        var minutes = safeSeconds / 60;
        var seconds = safeSeconds % 60;
        return minutes.format("%02d") + ":" + seconds.format("%02d");
    }

    private function dictionaryString(dictionary as Lang.Dictionary, key as Lang.String, fallback as Lang.String) as Lang.String {
        var value = dictionary[key];
        if (value == null) {
            return fallback;
        }
        if (value instanceof Lang.String) {
            return value as Lang.String;
        }
        return (value as Lang.Object).toString();
    }

    private function dictionaryNumber(dictionary as Lang.Dictionary, key as Lang.String, fallback as Lang.Number) as Lang.Number {
        var value = dictionary[key];
        if (value == null) {
            return fallback;
        }
        if (value instanceof Lang.Number) {
            return value as Lang.Number;
        }
        if (value instanceof Lang.Float) {
            return (value as Lang.Float).toNumber();
        }
        if (value instanceof Lang.Double) {
            return (value as Lang.Double).toNumber();
        }
        if (value instanceof Lang.String) {
            var parsed = (value as Lang.String).toFloat();
            return parsed == null ? fallback : (parsed as Lang.Float).toNumber();
        }
        return fallback;
    }

    private function dictionaryFloat(dictionary as Lang.Dictionary, key as Lang.String, fallback as Lang.Float) as Lang.Float {
        var value = dictionary[key];
        if (value == null) {
            return fallback;
        }
        if (value instanceof Lang.Number) {
            return (value as Lang.Number).toFloat();
        }
        if (value instanceof Lang.Float) {
            return value as Lang.Float;
        }
        if (value instanceof Lang.Double) {
            return (value as Lang.Double).toFloat();
        }
        if (value instanceof Lang.String) {
            var parsed = (value as Lang.String).toFloat();
            return parsed == null ? fallback : parsed as Lang.Float;
        }
        return fallback;
    }
}
