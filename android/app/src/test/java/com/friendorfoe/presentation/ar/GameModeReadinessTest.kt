package com.friendorfoe.presentation.ar

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class GameModeReadinessTest {

    @Test
    fun returns_progress_message_until_backend_observed() {
        val reason = computeGameModeBlockReason(
            isOnline = true,
            backendObserved = false,
            backendOnline = false,
            sensorNodeCount = 0
        )

        assertEquals("Backend readiness check in progress...", reason)
    }

    @Test
    fun blocks_when_offline() {
        val reason = computeGameModeBlockReason(
            isOnline = false,
            backendObserved = true,
            backendOnline = true,
            sensorNodeCount = 2
        )

        assertEquals("Offline. Connect network for backend game mode.", reason)
    }

    @Test
    fun blocks_when_backend_unreachable() {
        val reason = computeGameModeBlockReason(
            isOnline = true,
            backendObserved = true,
            backendOnline = false,
            sensorNodeCount = 2
        )

        assertEquals("Backend unreachable. Start backend first.", reason)
    }

    @Test
    fun blocks_when_no_nodes_online() {
        val reason = computeGameModeBlockReason(
            isOnline = true,
            backendObserved = true,
            backendOnline = true,
            sensorNodeCount = 0
        )

        assertEquals("No ESP32 nodes online.", reason)
    }

    @Test
    fun allows_game_mode_when_all_ready() {
        val reason = computeGameModeBlockReason(
            isOnline = true,
            backendObserved = true,
            backendOnline = true,
            sensorNodeCount = 1
        )

        assertNull(reason)
    }
}
