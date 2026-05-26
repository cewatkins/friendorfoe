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
    val lastEvent: String? = null
) {
    val accuracyPercent: Int
        get() = if (shots == 0) 0 else ((hits.toFloat() / shots.toFloat()) * 100f).roundToInt()
}

object GameModeEngine {
    private const val BASE_HIT_SCORE = 100
    private const val MAX_CONFIDENCE_BONUS = 220
    private const val MAX_DISTANCE_BONUS = 120
    private const val DISTANCE_BONUS_CEILING_METERS = 8_000.0

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
}