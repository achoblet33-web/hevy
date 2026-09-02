import Toybox.Application;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.System;

class WorkoutDataModel {
    private const API_ROOT = "https://api.hevyapp.com/v1";
    private const ROUTINE_CACHE_KEY = "routineCacheV2";
    private const DRAFT_KEY = "activeWorkoutDraftV1";
    private const PENDING_KEY = "pendingWorkoutsV1";
    private const MAX_ROUTINES = 10;
    private const MAX_EXERCISES_PER_ROUTINE = 40;
    private const MAX_SETS_PER_ROUTINE = 150;
    private const MAX_SETS_PER_EXERCISE = 150;
    private const MAX_PENDING_WORKOUTS = 3;
    private const MAX_TITLE_LENGTH = 80;
    private const MAX_ID_LENGTH = 128;

    private var mRoutineCallback as Lang.Method or Null = null;
    private var mPendingCallback as Lang.Method or Null = null;

    function initialize() {
        // A draft is only useful while this process is active. A previous process
        // has already finalized its FIT file in onStop(), so do not retain it.
        clearDraft();
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
        try {
            var stored = Application.Storage.getValue(ROUTINE_CACHE_KEY);
            if (stored instanceof Lang.Array) {
                return stored as Lang.Array;
            }
        } catch (error) {
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

    function onRoutinesResponse(
        responseCode as Lang.Number,
        data as Null or Lang.Dictionary or Lang.String or PersistedContent.Iterator
    ) as Void {
        if (responseCode >= 200 && responseCode < 300 && data instanceof Lang.Dictionary) {
            var normalized = normalizeRoutines(data as Lang.Dictionary);
            if (normalized.size() > 0) {
                cacheRoutines(normalized);
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
        for (var routineIndex = 0; routineIndex < routines.size() && result.size() < MAX_ROUTINES; routineIndex += 1) {
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
                "id" => valueAsBoundedString(routine["id"], "", MAX_ID_LENGTH),
                "title" => valueAsBoundedString(routine["title"], "Routine Hevy", MAX_TITLE_LENGTH),
                "exercises" => normalizedExercises
            });
        }
        return result;
    }

    private function normalizeExercises(rawExercises as Lang.Object or Null) as Lang.Array {
        var result = [];
        if (!(rawExercises instanceof Lang.Array)) {
            return result;
        }

        var exercises = rawExercises as Lang.Array;
        var totalSets = 0;
        for (var exerciseIndex = 0;
            exerciseIndex < exercises.size()
                && result.size() < MAX_EXERCISES_PER_ROUTINE
                && totalSets < MAX_SETS_PER_ROUTINE;
            exerciseIndex += 1) {
            var rawExercise = exercises[exerciseIndex];
            if (!(rawExercise instanceof Lang.Dictionary)) {
                continue;
            }

            var exercise = rawExercise as Lang.Dictionary;
            var normalizedSets = normalizeSets(exercise["sets"]);
            if (normalizedSets.size() == 0) {
                continue;
            }
            var remainingSets = MAX_SETS_PER_ROUTINE - totalSets;
            if (normalizedSets.size() > remainingSets) {
                normalizedSets = firstItems(normalizedSets, remainingSets);
            }

            result.add({
                "title" => valueAsBoundedString(exercise["title"], "Exercice", MAX_TITLE_LENGTH),
                "exercise_template_id" => valueAsBoundedString(exercise["exercise_template_id"], "", MAX_ID_LENGTH),
                "rest_seconds" => clampNumber(valueAsNumber(exercise["rest_seconds"], 90), 0, 600),
                "sets" => normalizedSets
            });
            totalSets += normalizedSets.size();
        }
        return result;
    }

    private function normalizeSets(rawSets as Lang.Object or Null) as Lang.Array {
        var result = [];
        if (!(rawSets instanceof Lang.Array)) {
            return result;
        }

        var sets = rawSets as Lang.Array;
        for (var setIndex = 0; setIndex < sets.size() && result.size() < MAX_SETS_PER_EXERCISE; setIndex += 1) {
            var rawSet = sets[setIndex];
            if (!(rawSet instanceof Lang.Dictionary)) {
                continue;
            }

            var setData = rawSet as Lang.Dictionary;
            result.add({
                "type" => valueAsBoundedString(setData["type"], "normal", 16),
                "weight_kg" => clampFloat(valueAsFloat(setData["weight_kg"], 0.0), 0.0, 999.0),
                "reps" => clampNumber(valueAsNumber(setData["reps"], 0), 0, 999)
            });
        }
        return result;
    }

    function saveDraft(draft as Lang.Dictionary) as Void {
        try {
            Application.Storage.setValue(DRAFT_KEY, draft);
        } catch (error) {
        }
    }

    function clearDraft() as Void {
        try {
            Application.Storage.deleteValue(DRAFT_KEY);
        } catch (error) {
        }
    }

    function enqueueWorkout(payload as Lang.Dictionary) as Lang.Boolean {
        var pending = getPendingWorkouts();
        var limited = [];
        var firstIndex = pending.size() >= MAX_PENDING_WORKOUTS
            ? pending.size() - (MAX_PENDING_WORKOUTS - 1)
            : 0;
        for (var index = firstIndex; index < pending.size(); index += 1) {
            limited.add(pending[index]);
        }
        limited.add(payload);
        try {
            Application.Storage.setValue(PENDING_KEY, limited);
            return true;
        } catch (error) {
            try {
                Application.Storage.setValue(PENDING_KEY, [payload]);
                return true;
            } catch (fallbackError) {
                return false;
            }
        }
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

    function onPendingResponse(
        responseCode as Lang.Number,
        data as Null or Lang.Dictionary or Lang.String or PersistedContent.Iterator
    ) as Void {
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
        try {
            var stored = Application.Storage.getValue(PENDING_KEY);
            if (stored instanceof Lang.Array) {
                return stored as Lang.Array;
            }
        } catch (error) {
        }
        return [];
    }

    private function removeOldestPending() as Void {
        var pending = getPendingWorkouts();
        var remaining = [];
        for (var index = 1; index < pending.size(); index += 1) {
            remaining.add(pending[index]);
        }
        try {
            Application.Storage.setValue(PENDING_KEY, remaining);
        } catch (error) {
            // Avoid resending an already accepted workout if storage becomes
            // unavailable while removing it from the queue.
            try {
                Application.Storage.deleteValue(PENDING_KEY);
            } catch (deleteError) {
            }
        }
    }

    private function buildHeaders(apiKey as Lang.String) as Lang.Dictionary {
        return {
            "api-key" => apiKey,
            "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON
        };
    }

    private function cacheRoutines(routines as Lang.Array) as Void {
        try {
            Application.Storage.setValue(ROUTINE_CACHE_KEY, routines);
            return;
        } catch (error) {
        }

        var reduced = firstItems(routines, 3);
        try {
            Application.Storage.setValue(ROUTINE_CACHE_KEY, reduced);
        } catch (error) {
            if (reduced.size() > 0) {
                try {
                    Application.Storage.setValue(ROUTINE_CACHE_KEY, [reduced[0]]);
                } catch (lastError) {
                }
            }
        }
    }

    private function firstItems(values as Lang.Array, maximum as Lang.Number) as Lang.Array {
        var result = [];
        for (var index = 0; index < values.size() && index < maximum; index += 1) {
            result.add(values[index]);
        }
        return result;
    }

    private function valueAsBoundedString(value as Lang.Object or Null, fallback as Lang.String, maximum as Lang.Number) as Lang.String {
        var result = valueAsString(value, fallback);
        if (result.length() <= maximum) {
            return result;
        }
        return result.substring(0, maximum) as Lang.String;
    }

    private function valueAsString(value as Lang.Object or Null, fallback as Lang.String) as Lang.String {
        if (value == null) {
            return fallback;
        }
        if (value instanceof Lang.String) {
            return value as Lang.String;
        }
        return (value as Lang.Object).toString();
    }

    private function valueAsNumber(value as Lang.Object or Null, fallback as Lang.Number) as Lang.Number {
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

    private function valueAsFloat(value as Lang.Object or Null, fallback as Lang.Float) as Lang.Float {
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

    private function clampNumber(value as Lang.Number, minimum as Lang.Number, maximum as Lang.Number) as Lang.Number {
        if (value < minimum) {
            return minimum;
        }
        if (value > maximum) {
            return maximum;
        }
        return value;
    }

    private function clampFloat(value as Lang.Float, minimum as Lang.Float, maximum as Lang.Float) as Lang.Float {
        if (value < minimum) {
            return minimum;
        }
        if (value > maximum) {
            return maximum;
        }
        return value;
    }
}
