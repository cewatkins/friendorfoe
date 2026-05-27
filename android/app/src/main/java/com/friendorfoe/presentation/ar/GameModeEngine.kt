package com.friendorfoe.presentation.ar

import kotlin.math.min
import kotlin.math.roundToInt

data class GameSessionState(
    val isRunning: Boolean = false,
    val remainingSeconds: Int = 0,
    val score: Int = 0,
    val shots: Int = 0,
    val hits: Int = 0,
    val misses: Int = 0,
    val streak: Int = 0,
    val bestStreak: Int = 0,
    val shotDownTargets: List<ShotDownTarget> = emptyList(),
    val targetHitCounts: Map<String, Int> = emptyMap(),
    val targetPointTotals: Map<String, Int> = emptyMap(),
    val lastEvent: String? = null
) {
    val accuracyPercent: Int
        get() = if (shots == 0) 0 else ((hits.toFloat() / shots.toFloat()) * 100f).roundToInt()
}

data class ShotDownTarget(
    val objectId: String,
    val label: String,
    val hits: Int,
    val pointsFromHits: Int,
    val bonusPoints: Int,
    val isAircraft: Boolean
)

data class ShotDownTransition(
    val nextHitCount: Int,
    val nextPointTotal: Int,
    val requiredHits: Int,
    val requiredPoints: Int,
    val isShotDown: Boolean,
    val bonusPoints: Int,
    val progressPercent: Int
)

object GameModeEngine {
    private const val BASE_HIT_SCORE = 100
    private const val MAX_CONFIDENCE_BONUS = 220
    private const val MAX_DISTANCE_BONUS = 120
    private const val DISTANCE_BONUS_CEILING_METERS = 8_000.0
    private const val AIRCRAFT_SHOTDOWN_HITS = 3
    private const val DRONE_SHOTDOWN_HITS = 2
    private const val AIRCRAFT_SHOTDOWN_POINTS = 900
    private const val DRONE_SHOTDOWN_POINTS = 600
    private const val AIRCRAFT_SHOTDOWN_BONUS = 250
    private const val DRONE_SHOTDOWN_BONUS = 150

    fun pointsForHit(confidence: Float, distanceMeters: Double, streakBeforeHit: Int): Int {
        val normalizedConfidence = confidence.coerceIn(0f, 1f)
        val normalizedDistance = (distanceMeters.coerceIn(0.0, DISTANCE_BONUS_CEILING_METERS) /
            DISTANCE_BONUS_CEILING_METERS).toFloat()
        val streakMultiplier = 1.0f + (min(streakBeforeHit, 10) * 0.12f)

        val baseScore = BASE_HIT_SCORE +
            (normalizedConfidence * MAX_CONFIDENCE_BONUS).roundToInt() +
            (normalizedDistance * MAX_DISTANCE_BONUS).roundToInt()

        return (baseScore * streakMultiplier).roundToInt().coerceAtLeast(50)
    }

    fun requiredHitsForShotDown(isAircraft: Boolean): Int {
        return if (isAircraft) AIRCRAFT_SHOTDOWN_HITS else DRONE_SHOTDOWN_HITS
    }

    fun requiredPointsForShotDown(isAircraft: Boolean): Int {
        return if (isAircraft) AIRCRAFT_SHOTDOWN_POINTS else DRONE_SHOTDOWN_POINTS
    }

    fun shotDownBonus(isAircraft: Boolean): Int {
        return if (isAircraft) AIRCRAFT_SHOTDOWN_BONUS else DRONE_SHOTDOWN_BONUS
    }

    fun shotDownProgressPercent(isAircraft: Boolean, hitCount: Int, pointTotal: Int): Int {
        val requiredHits = requiredHitsForShotDown(isAircraft).coerceAtLeast(1)
        val requiredPoints = requiredPointsForShotDown(isAircraft).coerceAtLeast(1)
        val hitProgress = hitCount.coerceAtLeast(0).toFloat() / requiredHits.toFloat()
        val pointProgress = pointTotal.coerceAtLeast(0).toFloat() / requiredPoints.toFloat()
        return (maxOf(hitProgress, pointProgress) * 100f).roundToInt().coerceIn(0, 100)
    }

    fun evaluateShotDownTransition(
        isAircraft: Boolean,
        previousHitCount: Int,
        previousPointTotal: Int,
        hitPoints: Int
    ): ShotDownTransition {
        val nextHitCount = (previousHitCount + 1).coerceAtLeast(0)
        val nextPointTotal = (previousPointTotal + hitPoints).coerceAtLeast(0)
        val requiredHits = requiredHitsForShotDown(isAircraft)
        val requiredPoints = requiredPointsForShotDown(isAircraft)
        val shotDown = nextHitCount >= requiredHits || nextPointTotal >= requiredPoints
        return ShotDownTransition(
            nextHitCount = nextHitCount,
            nextPointTotal = nextPointTotal,
            requiredHits = requiredHits,
            requiredPoints = requiredPoints,
            isShotDown = shotDown,
            bonusPoints = if (shotDown) shotDownBonus(isAircraft) else 0,
            progressPercent = shotDownProgressPercent(isAircraft, nextHitCount, nextPointTotal)
        )
    }
}