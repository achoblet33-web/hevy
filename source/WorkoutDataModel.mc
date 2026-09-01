import Toybox.Application;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;

class WorkoutDataModel {
    private const API_ROOT = "https://api.hevyapp.com/v1";
    private const ROUTINE_CACHE_KEY = "routineCacheV2";
    private const DRAFT_KEY = "activeWorkoutDraftV1";
    private const PENDING_KEY = "pendingWorkoutsV1";

    private var mRoutineCallback as Lang.Method or Null = null;
    private var mPendingCallback as Lang.Method or Null = null;

    function initialize() {
    }

    function getApiKey() as Lang.String {
        var raw = Application.Properties.getValue("apiKey");
        if (raw == null) {
            return "";
        }
        if (raw instanceof Lang.String) {
            return raw as Lang.String;
        }
        return "";
    }

    function hasApiKey() as Lang.Boolean {
        return getApiKey().length() > 0;
    }

    function getCachedRoutines() as Lang.Array {
        var stored = Application.Storage.getValue(ROUTINE_CACHE_KEY);
        if (stored instanceof Lang.Array) {
            return stored as Lang.Array;
        }
        return [];
    }

    function fetchRoutines(callback as Lang.Method) as Void {
        mRoutineCallback = callback;
        var apiKey = getApiKey();
        if (apiKey.length() == 0) {
            finishRoutineRequest(-2, null);
            return;
        }

        var parameters = {
            "page" => 1,
            "pageSize" => 10
        };
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :headers => buildHeaders(apiKey),
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        try {
            Communications.makeWebRequest(
                API_ROOT + "/routines",
                parameters,
                options,
                method(:onRoutinesResponse)
            );
        } catch (error) {
            finishRoutineRequest(-1, null);
        }
    }

    private function onRoutinesResponse(responseCode as Lang.Number, data) as Void {
        if (responseCode >= 200 && responseCode < 300 && data instanceof Lang.Dictionary) {
            var normalized = normalizeRoutines(data as Lang.Dictionary);
            if (normalized.size() > 0) {
                Application.Storage.setValue(ROUTINE_CACHE_KEY, normalized);
                finishRoutineRequest(responseCode, normalized);
                return;
            }
        }
        finishRoutineRequest(responseCode, null);
    }

    private function finishRoutineRequest(responseCode as Lang.Number, routines as Lang.Array or Null) as Void {
        var callback = mRoutineCallback;
        mRoutineCallback = null;
        if (callback != null) {
            (callback as Lang.Method).invoke(responseCode, routines);
        }
    }

    private function normalizeRoutines(response as Lang.Dictionary) as Lang.Array {
        var result = [];
        var rawRoutines = response["routines"];
        if (!(rawRoutines instanceof Lang.Array)) {
            return result;
        }

        var routines = rawRoutines as Lang.Array;
        for (var routineIndex = 0; routineIndex < routines.size(); routineIndex += 1) {
            var rawRoutine = routines[routineIndex];
            if (!(rawRoutine instanceof Lang.Dictionary)) {
                continue;
            }

            var routine = rawRoutine as Lang.Dictionary;
            var normalizedExercises = normalizeExercises(routine["exercises"]);
            if (normalizedExercises.size() == 0) {
                continue;
            }

            result.add({
                "id" => valueAsString(routine["id"], ""),
                "title" => valueAsString(routine["title"], "Routine Hevy"),
                "exercises" => normalizedExercises
            });
        }
        return result;
    }

    private function normalizeExercises(rawExercises) as Lang.Array {
        var result = [];
        if (!(rawExercises instanceof Lang.Array)) {
            return result;
        }

        var exercises = rawExercises as Lang.Array;
        for (var exerciseIndex = 0; exerciseIndex < exercises.size(); exerciseIndex += 1) {
            var rawExercise = exercises[exerciseIndex];
            if (!(rawExercise instanceof Lang.Dictionary)) {
                continue;
            }

            var exercise = rawExercise as Lang.Dictionary;
            var normalizedSets = normalizeSets(exercise["sets"]);
            if (normalizedSets.size() == 0) {
                continue;
            }

            result.add({
                "title" => valueAsString(exercise["title"], "Exercice"),
                "exercise_template_id" => valueAsString(exercise["exercise_template_id"], ""),
                "rest_seconds" => valueAsNumber(exercise["rest_seconds"], 90),
                "sets" => normalizedSets
            });
        }
        return result;
    }

    private function normalizeSets(rawSets) as Lang.Array {
        var result = [];
        if (!(rawSets instanceof Lang.Array)) {
            return result;
        }

        var sets = rawSets as Lang.Array;
        for (var setIndex = 0; setIndex < sets.size(); setIndex += 1) {
            var rawSet = sets[setIndex];
            if (!(rawSet instanceof Lang.Dictionary)) {
                continue;
            }

            var setData = rawSet as Lang.Dictionary;
            result.add({
                "type" => valueAsString(setData["type"], "normal"),
                "weight_kg" => valueAsFloat(setData["weight_kg"], 0.0),
                "reps" => valueAsNumber(setData["reps"], 0)
            });
        }
        return result;
    }

    function saveDraft(draft as Lang.Dictionary) as Void {
        Application.Storage.setValue(DRAFT_KEY, draft);
    }

    function clearDraft() as Void {
        Application.Storage.deleteValue(DRAFT_KEY);
    }

    function enqueueWorkout(payload as Lang.Dictionary) as Void {
        var pending = getPendingWorkouts();
        pending.add(payload);
        Application.Storage.setValue(PENDING_KEY, pending);
    }

    function pendingCount() as Lang.Number {
        return getPendingWorkouts().size();
    }

    function flushOldestPending(callback as Lang.Method) as Void {
        mPendingCallback = callback;
        var pending = getPendingWorkouts();
        if (pending.size() == 0) {
            finishPendingRequest(true, 0);
            return;
        }

        var apiKey = getApiKey();
        if (apiKey.length() == 0) {
            finishPendingRequest(false, pending.size());
            return;
        }

        var oldest = pending[0];
        if (!(oldest instanceof Lang.Dictionary)) {
            removeOldestPending();
            finishPendingRequest(false, pendingCount());
            return;
        }

        var body = { "workout" => (oldest as Lang.Dictionary) };
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => buildHeaders(apiKey),
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };

        try {
            Communications.makeWebRequest(
                API_ROOT + "/workouts",
                body,
                options,
                method(:onPendingResponse)
            );
        } catch (error) {
            finishPendingRequest(false, pending.size());
        }
    }

    private function onPendingResponse(responseCode as Lang.Number, data) as Void {
        var success = responseCode >= 200 && responseCode < 300;
        if (success) {
            removeOldestPending();
        }
        finishPendingRequest(success, pendingCount());
    }

    private function finishPendingRequest(success as Lang.Boolean, remaining as Lang.Number) as Void {
        var callback = mPendingCallback;
        mPendingCallback = null;
        if (callback != null) {
            (callback as Lang.Method).invoke(success, remaining);
        }
    }

    private function getPendingWorkouts() as Lang.Array {
        var stored = Application.Storage.getValue(PENDING_KEY);
        if (stored instanceof Lang.Array) {
            return stored as Lang.Array;
        }
        return [];
    }

    private function removeOldestPending() as Void {
        var pending = getPendingWorkouts();
        var remaining = [];
        for (var index = 1; index < pending.size(); index += 1) {
            remaining.add(pending[index]);
        }
        Application.Storage.setValue(PENDING_KEY, remaining);
    }

    private function buildHeaders(apiKey as Lang.String) as Lang.Dictionary {
        return {
            "api-key" => apiKey,
            "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON
        };
    }

    private function valueAsString(value, fallback as Lang.String) as Lang.String {
        if (value == null) {
            return fallback;
        }
        if (value instanceof Lang.String) {
            return value as Lang.String;
        }
        return (value as Lang.Object).toString();
    }

    private function valueAsNumber(value, fallback as Lang.Number) as Lang.Number {
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

    private function valueAsFloat(value, fallback as Lang.Float) as Lang.Float {
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
