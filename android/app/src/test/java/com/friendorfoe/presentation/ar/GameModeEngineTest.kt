package com.friendorfoe.presentation.ar

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class GameModeEngineTest {

    @Test
    fun `points increase with confidence`() {
        val low = GameModeEngine.pointsForHit(confidence = 0.2f, distanceMeters = 1000.0, streakBeforeHit = 0)
        val high = GameModeEngine.pointsForHit(confidence = 0.9f, distanceMeters = 1000.0, streakBeforeHit = 0)

        assertTrue(high > low)
    }

    @Test
    fun `points increase with distance`() {
        val near = GameModeEngine.pointsForHit(confidence = 0.7f, distanceMeters = 100.0, streakBeforeHit = 0)
        val far = GameModeEngine.pointsForHit(confidence = 0.7f, distanceMeters = 7000.0, streakBeforeHit = 0)

        assertTrue(far > near)
    }

    @Test
    fun `points increase with streak multiplier`() {
        val noStreak = GameModeEngine.pointsForHit(confidence = 0.6f, distanceMeters = 3000.0, streakBeforeHit = 0)
        val streaked = GameModeEngine.pointsForHit(confidence = 0.6f, distanceMeters = 3000.0, streakBeforeHit = 5)

        assertTrue(streaked > noStreak)
    }

    @Test
    fun `accuracy percent rounds as expected`() {
        val state = GameSessionState(shots = 3, hits = 2)
        assertEquals(67, state.accuracyPercent)
    }
}
