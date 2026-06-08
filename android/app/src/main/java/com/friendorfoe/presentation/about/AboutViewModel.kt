package com.friendorfoe.presentation.about

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.friendorfoe.data.BackendEndpoints
import com.friendorfoe.data.DetectionPrefs
import com.friendorfoe.data.repository.SkyObjectRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class AboutViewModel @Inject constructor(
    private val detectionPrefs: DetectionPrefs,
    private val skyObjectRepository: SkyObjectRepository,
) : ViewModel() {

    val adsbEnabled: Boolean get() = detectionPrefs.adsbEnabled
    val bleRidEnabled: Boolean get() = detectionPrefs.bleRidEnabled
    val wifiEnabled: Boolean get() = detectionPrefs.wifiEnabled
    val privacyEnabled: Boolean get() = detectionPrefs.privacyEnabled
    val stalkerEnabled: Boolean get() = detectionPrefs.stalkerDetectionEnabled
    val ultrasonicEnabled: Boolean get() = detectionPrefs.ultrasonicEnabled
    val wifiAnomalyEnabled: Boolean get() = detectionPrefs.wifiAnomalyEnabled
    val sensorBackendEnabled: Boolean get() = detectionPrefs.sensorBackendEnabled
    val backendUrl: String get() = detectionPrefs.backendUrl
    val backendOnlyMode: Boolean get() = detectionPrefs.backendOnlyMode

    fun setAdsbEnabled(enabled: Boolean) { detectionPrefs.adsbEnabled = enabled }
    fun setBleRidEnabled(enabled: Boolean) { detectionPrefs.bleRidEnabled = enabled }
    fun setWifiEnabled(enabled: Boolean) { detectionPrefs.wifiEnabled = enabled }
    fun setPrivacyEnabled(enabled: Boolean) {
        skyObjectRepository.setPrivacyDetectionEnabled(enabled)
    }
    fun setStalkerEnabled(enabled: Boolean) { detectionPrefs.stalkerDetectionEnabled = enabled }
    fun setUltrasonicEnabled(enabled: Boolean) { detectionPrefs.ultrasonicEnabled = enabled }
    fun setWifiAnomalyEnabled(enabled: Boolean) { detectionPrefs.wifiAnomalyEnabled = enabled }
    fun setSensorBackendEnabled(enabled: Boolean) { detectionPrefs.sensorBackendEnabled = enabled }
    fun setBackendUrl(url: String) { detectionPrefs.backendUrl = url }
    fun setBackendOnlyMode(enabled: Boolean) { detectionPrefs.backendOnlyMode = enabled }

    // Connection test
    private val _connectionStatus = MutableStateFlow<String?>(null)
    val connectionStatus: StateFlow<String?> = _connectionStatus.asStateFlow()

    fun testConnection() {
        val candidates = BackendEndpoints.candidates(detectionPrefs.backendUrl)
        _connectionStatus.value = "Testing ${candidates.joinToString(" | ")} ..."
        viewModelScope.launch(Dispatchers.IO) {
            val attempts = candidates.map { url -> BackendEndpoints.probeHealth(url) }
            val success = attempts.firstOrNull { it.ok }
            if (success != null) {
                detectionPrefs.backendUrl = success.url
                _connectionStatus.value = "Connected to ${BackendEndpoints.label(success.url)} (${success.url}) — v${success.version} DB:${success.database}"
            } else {
                _connectionStatus.value = attempts.joinToString("  ") { attempt ->
                    "${BackendEndpoints.label(attempt.url)} failed: ${attempt.error ?: "unreachable"}"
                }
            }
        }
    }
}
