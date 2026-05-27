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

    @Test
    fun `drone shotdown thresholds are lower than aircraft`() {
        val aircraftHits = GameModeEngine.requiredHitsForShotDown(isAircraft = true)
        val droneHits = GameModeEngine.requiredHitsForShotDown(isAircraft = false)
        val aircraftPoints = GameModeEngine.requiredPointsForShotDown(isAircraft = true)
        val dronePoints = GameModeEngine.requiredPointsForShotDown(isAircraft = false)

        assertTrue(droneHits < aircraftHits)
        assertTrue(dronePoints < aircraftPoints)
    }

    @Test
    fun `aircraft shotdown bonus is higher than drone`() {
        val aircraftBonus = GameModeEngine.shotDownBonus(isAircraft = true)
        val droneBonus = GameModeEngine.shotDownBonus(isAircraft = false)

        assertTrue(aircraftBonus > droneBonus)
    }

    @Test
    fun `evaluate transition shotdowns aircraft by hits`() {
        val transition = GameModeEngine.evaluateShotDownTransition(
            isAircraft = true,
            previousHitCount = 2,
            previousPointTotal = 500,
            hitPoints = 120
        )

        assertTrue(transition.isShotDown)
        assertEquals(3, transition.nextHitCount)
        assertEquals(GameModeEngine.shotDownBonus(isAircraft = true), transition.bonusPoints)
    }

    @Test
    fun `evaluate transition shotdowns drone by points`() {
        val transition = GameModeEngine.evaluateShotDownTransition(
            isAircraft = false,
            previousHitCount = 1,
            previousPointTotal = 580,
            hitPoints = 30
        )

        assertTrue(transition.isShotDown)
        assertEquals(610, transition.nextPointTotal)
        assertEquals(GameModeEngine.shotDownBonus(isAircraft = false), transition.bonusPoints)
    }
}
