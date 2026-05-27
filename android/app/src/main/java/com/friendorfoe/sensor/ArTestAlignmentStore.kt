package com.friendorfoe.sensor

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Shared test-only AR alignment state.
 *
 * Map view can publish a manual azimuth correction derived from a selected aircraft,
 * and AR view applies it as an additional heading bias.
 */
@Singleton
class ArTestAlignmentStore @Inject constructor() {

    private val _manualBiasDegrees = MutableStateFlow(0f)
    val manualBiasDegrees: StateFlow<Float> = _manualBiasDegrees.asStateFlow()

    fun setManualBiasDegrees(biasDegrees: Float) {
        _manualBiasDegrees.value = biasDegrees.coerceIn(-45f, 45f)
    }

    fun reset() {
        _manualBiasDegrees.value = 0f
    }
}
