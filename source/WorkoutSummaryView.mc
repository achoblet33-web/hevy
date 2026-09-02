import Toybox.ActivityRecording;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Sensor;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

class WorkoutSummaryView extends WatchUi.View {
    private const COLOR_GREEN = 0x00E676;
    private const COLOR_BLUE = 0x29B6F6;
    private const COLOR_ORANGE = 0xFF9800;
    private const COLOR_RED = 0xFF5252;
    private const COLOR_MUTED = 0x8A8A8A;

    private var mModel as WorkoutDataModel;
    private var mRoutineTitle as Lang.String;
    private var mStartSeconds as Lang.Number;
    private var mEndSeconds as Lang.Number;
    private var mDurationSeconds as Lang.Number;
    private var mHistory as Lang.Array;
    private var mSession as ActivityRecording.Session or Null;
    private var mWidth as Lang.Number = 454;
    private var mHeight as Lang.Number = 454;

    private var mFinalized as Lang.Boolean = false;
    private var mSyncLabel as Lang.String = "Sauvegarde...";
    private var mSyncColor as Lang.Number = COLOR_ORANGE;
    private var mTotalReps as Lang.Number = 0;
    private var mTotalVolume as Lang.Float = 0.0;

    function initialize(
        model as WorkoutDataModel,
        routineTitle as Lang.String,
        startSeconds as Lang.Number,
        endSeconds as Lang.Number,
        durationSeconds as Lang.Number,
        history as Lang.Array,
        session as ActivityRecording.Session or Null
    ) {
        View.initialize();
        mModel = model;
        mRoutineTitle = routineTitle;
        mStartSeconds = startSeconds;
        mEndSeconds = endSeconds;
        mDurationSeconds = durationSeconds;
        mHistory = history;
        mSession = session;
        var settings = System.getDeviceSettings();
        mWidth = settings.screenWidth;
        mHeight = settings.screenHeight;
        calculateTotals();
    }

    function onShow() as Void {
        if (!mFinalized) {
            mFinalized = true;
            finalizeFit();
            mModel.clearDraft();

            if (mHistory.size() == 0) {
                mSyncLabel = "Aucune série à envoyer";
                mSyncColor = COLOR_MUTED;
            } else {
                mModel.enqueueWorkout(buildWorkoutPayload());
                mSyncLabel = "Envoi Hevy...";
                mSyncColor = COLOR_ORANGE;
                mModel.flushOldestPending(method(:onUploadComplete));
            }
        }
        WatchUi.requestUpdate();
    }

    private function finalizeFit() as Void {
        if (mSession == null) {
            return;
        }
        try {
            var session = mSession as ActivityRecording.Session;
            if (session.isRecording()) {
                session.stop();
            }
            session.save();
        } catch (error) {
        }
        Sensor.setEnabledSensors([]);
        mSession = null;
    }

    function onUploadComplete(success as Lang.Boolean, remaining as Lang.Number) as Void {
        if (success && remaining == 0) {
            mSyncLabel = "Synchronisé avec Hevy";
            mSyncColor = COLOR_GREEN;
        } else if (success) {
            mSyncLabel = remaining + " séance(s) en attente";
            mSyncColor = COLOR_ORANGE;
        } else if (!mModel.hasApiKey()) {
            mSyncLabel = "Clé API à configurer";
            mSyncColor = COLOR_RED;
        } else {
            mSyncLabel = "En attente de connexion";
            mSyncColor = COLOR_ORANGE;
        }
        WatchUi.requestUpdate();
    }

    private function calculateTotals() as Void {
        for (var index = 0; index < mHistory.size(); index += 1) {
            var raw = mHistory[index];
            if (!(raw instanceof Lang.Dictionary)) {
                continue;
            }
            var item = raw as Lang.Dictionary;
            var reps = dictionaryNumber(item, "reps", 0);
            var weight = dictionaryFloat(item, "weight_kg", 0.0);
            mTotalReps += reps;
            mTotalVolume += weight * reps;
        }
    }

    private function buildWorkoutPayload() as Lang.Dictionary {
        return {
            "title" => mRoutineTitle,
            "description" => "Enregistré depuis Garmin",
            "start_time" => isoUtc(mStartSeconds),
            "end_time" => isoUtc(mEndSeconds),
            "is_private" => false,
            "exercises" => buildExercisePayloads()
        };
    }

    private function buildExercisePayloads() as Lang.Array {
        var exercises = [];
        var currentExerciseIndex = -1;
        var exercisePayload = null;
        for (var index = 0; index < mHistory.size(); index += 1) {
            var raw = mHistory[index];
            if (!(raw instanceof Lang.Dictionary)) {
                continue;
            }
            var completed = raw as Lang.Dictionary;
            var templateId = dictionaryString(completed, "exercise_template_id", "");
            if (templateId.length() == 0) {
                continue;
            }

            var sourceExerciseIndex = dictionaryNumber(completed, "exercise_index", -1);
            if (exercisePayload == null || sourceExerciseIndex != currentExerciseIndex) {
                currentExerciseIndex = sourceExerciseIndex;
                exercisePayload = {
                    "exercise_template_id" => templateId,
                    "superset_id" => null,
                    "notes" => "",
                    "sets" => []
                };
                exercises.add(exercisePayload as Lang.Dictionary);
            }

            var rawSets = (exercisePayload as Lang.Dictionary)["sets"];
            if (rawSets instanceof Lang.Array) {
                (rawSets as Lang.Array).add({
                    "type" => dictionaryString(completed, "type", "normal"),
                    "weight_kg" => dictionaryFloat(completed, "weight_kg", 0.0),
                    "reps" => dictionaryNumber(completed, "reps", 0)
                });
            }
        }
        return exercises;
    }

    private function isoUtc(seconds as Lang.Number) as Lang.String {
        var info = Gregorian.utcInfo(new Time.Moment(seconds), Time.FORMAT_SHORT);
        return info.year.format("%04d") + "-"
            + (info.month as Lang.Number).format("%02d") + "-"
            + info.day.format("%02d") + "T"
            + info.hour.format("%02d") + ":"
            + info.min.format("%02d") + ":"
            + info.sec.format("%02d") + "Z";
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        mWidth = dc.getWidth();
        mHeight = dc.getHeight();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setAntiAlias(true);

        drawFittedText(dc, mWidth / 2, percentY(8), Graphics.FONT_SMALL, "TERMINÉ", COLOR_GREEN, percentX(56));
        drawWrappedText(dc, mWidth / 2, percentY(19), Graphics.FONT_SMALL, mRoutineTitle, Graphics.COLOR_WHITE, percentX(74));
        drawFittedText(dc, mWidth / 2, percentY(32), Graphics.FONT_XTINY, "DURÉE", COLOR_MUTED, percentX(42));
        drawFittedText(dc, mWidth / 2, percentY(39), Graphics.FONT_LARGE, formatDuration(mDurationSeconds), Graphics.COLOR_WHITE, percentX(55));

        drawFittedText(dc, percentX(30), percentY(57), Graphics.FONT_XTINY, "SÉRIES", COLOR_BLUE, percentX(24));
        drawFittedText(dc, percentX(30), percentY(64), Graphics.FONT_MEDIUM, mHistory.size().toString(), Graphics.COLOR_WHITE, percentX(24));
        drawFittedText(dc, percentX(70), percentY(57), Graphics.FONT_XTINY, "VOLUME KG", COLOR_BLUE, percentX(28));
        drawFittedText(dc, percentX(70), percentY(64), Graphics.FONT_MEDIUM, mTotalVolume.format("%.0f"), Graphics.COLOR_WHITE, percentX(28));

        drawFittedText(dc, mWidth / 2, percentY(76), Graphics.FONT_XTINY, mTotalReps + " répétitions", COLOR_MUTED, percentX(58));
        drawWrappedText(dc, mWidth / 2, percentY(82), Graphics.FONT_XTINY, mSyncLabel, mSyncColor, percentX(72));
        drawFittedText(dc, mWidth / 2, percentY(90), Graphics.FONT_XTINY, "BACK pour quitter", COLOR_MUTED, percentX(66));
    }

    private function drawWrappedText(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number, font as Graphics.FontType, value as Lang.String, color as Lang.Number, maxWidth as Lang.Number) as Void {
        var lines = [];
        var start = 0;
        while (start < value.length()) {
            var end = start + 1;
            var lastFit = end;
            while (end <= value.length()) {
                var candidate = value.substring(start, end) as Lang.String;
                if (dc.getTextWidthInPixels(candidate, font) > maxWidth) {
                    break;
                }
                lastFit = end;
                end += 1;
            }
            var lineEnd = lastFit;
            if (lastFit < value.length()) {
                while (lineEnd > start && (value.substring(lineEnd - 1, lineEnd) as Lang.String) != " ") {
                    lineEnd -= 1;
                }
                if (lineEnd == start) {
                    lineEnd = lastFit;
                }
            }
            lines.add(value.substring(start, lineEnd) as Lang.String);
            start = lineEnd;
            while (start < value.length() && (value.substring(start, start + 1) as Lang.String) == " ") {
                start += 1;
            }
        }
        var lineHeight = dc.getFontHeight(font) + 2;
        var startY = y - (((lines.size() - 1) * lineHeight) / 2);
        dc.setColor(color, Graphics.COLOR_BLACK);
        for (var lineIndex = 0; lineIndex < lines.size(); lineIndex += 1) {
            var rawLine = lines[lineIndex];
            if (rawLine instanceof Lang.String) {
                dc.drawText(x, startY + (lineIndex * lineHeight), font, rawLine as Lang.String, Graphics.TEXT_JUSTIFY_CENTER);
            }
        }
    }

    private function drawFittedText(dc as Graphics.Dc, x as Lang.Number, y as Lang.Number, font as Graphics.FontType, text as Lang.String, color as Lang.Number, maxWidth as Lang.Number) as Void {
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
        return (safeSeconds / 60).format("%02d") + ":" + (safeSeconds % 60).format("%02d");
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
