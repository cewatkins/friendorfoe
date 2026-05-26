package com.friendorfoe.presentation.history

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bluetooth
import androidx.compose.material.icons.filled.CellTower
import androidx.compose.material.icons.filled.Wifi
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.friendorfoe.data.local.GameSessionEntity
import com.friendorfoe.data.local.HistoryEntity
import com.friendorfoe.presentation.filter.FilterBar
import com.friendorfoe.presentation.util.categoryColor
import com.friendorfoe.presentation.util.isMilitary
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

/**
 * History screen showing past detection records from the Room database.
 *
 * Displays entries grouped by date with sticky headers. Each item shows
 * category color, display name, description, time, and detection source.
 *
 * @param onEntryTapped Callback when a history entry is tapped, receives object ID
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun HistoryScreen(
    onEntryTapped: (String) -> Unit,
    onNavigateToReferenceGuide: (() -> Unit)? = null,
    onNavigateToAbout: (() -> Unit)? = null,
    viewModel: HistoryViewModel = hiltViewModel()
) {
    val groupedHistory by viewModel.groupedHistory.collectAsStateWithLifecycle()
    val recentGameSessions by viewModel.recentGameSessions.collectAsStateWithLifecycle()
    val filterState by viewModel.filterState.collectAsStateWithLifecycle()
    val filteredEntryCount by viewModel.filteredEntryCount.collectAsStateWithLifecycle()

    Column(modifier = Modifier.fillMaxSize()) {
        FilterBar(
            filterState = filterState,
            onFilterStateChange = { viewModel.updateFilter(it) },
            resultCount = filteredEntryCount,
            onNavigateToReferenceGuide = onNavigateToReferenceGuide,
            onNavigateToAbout = onNavigateToAbout
        )

        if (groupedHistory.isEmpty() && recentGameSessions.isEmpty()) {
            EmptyHistoryState()
        } else {
            LazyColumn(
                modifier = Modifier.fillMaxSize()
            ) {
                if (recentGameSessions.isNotEmpty()) {
                    item(key = "game_sessions_header") {
                        SessionGroupHeader(title = "Recent Game Sessions")
                    }
                    items(
                        items = recentGameSessions,
                        key = { "session_${it.id}" }
                    ) { session ->
                        GameSessionItem(session = session)
                    }
                    item(key = "game_sessions_divider") {
                        HorizontalDivider(
                            color = MaterialTheme.colorScheme.outlineVariant,
                            thickness = 0.7.dp
                        )
                    }
                }

                groupedHistory.forEach { (dateLabel, entries) ->
                    stickyHeader(key = dateLabel) {
                        DateGroupHeader(dateLabel = dateLabel)
                    }

                    items(
                        items = entries,
                        key = { it.id }
                    ) { entry ->
                        HistoryItem(
                            entry = entry,
                            onClick = { onEntryTapped(entry.objectId) }
                        )
                        HorizontalDivider(
                            color = MaterialTheme.colorScheme.outlineVariant,
                            thickness = 0.5.dp
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun SessionGroupHeader(title: String) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        color = MaterialTheme.colorScheme.surface
    ) {
        Text(
            text = title,
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 10.dp),
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun GameSessionItem(session: GameSessionEntity) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 4.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.55f)
        ),
        shape = RoundedCornerShape(10.dp)
    ) {
        Column(modifier = Modifier.padding(horizontal = 12.dp, vertical = 10.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "${session.score} pts",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = formatDateTime(session.endedAt),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            Spacer(modifier = Modifier.height(4.dp))

            Text(
                text = "${session.durationSeconds}s  |  H ${session.hits}  M ${session.misses}  |  ${session.accuracyPercent}%  |  Best ${session.bestStreak}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )

            Text(
                text = "Ended: ${session.exitReason}",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.85f)
            )
        }
    }
}

@Composable
private fun EmptyHistoryState() {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Text(
                text = "No detections recorded yet",
                style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = "Past aircraft and drone detections\nwill appear here",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f),
                textAlign = TextAlign.Center
            )
        }
    }
}

@Composable
private fun DateGroupHeader(dateLabel: String) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        color = MaterialTheme.colorScheme.surfaceVariant
    ) {
        Text(
            text = dateLabel,
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun HistoryItem(
    entry: HistoryEntity,
    onClick: () -> Unit
) {
    val rowBackground = when {
        isMilitary(entry.category) -> Modifier.background(Color(0xFFF44336).copy(alpha = 0.08f))
        entry.category.equals("emergency", ignoreCase = true) -> Modifier.background(Color(0xFFE91E63).copy(alpha = 0.10f))
        else -> Modifier
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .then(rowBackground)
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Category color dot
        Box(
            modifier = Modifier
                .size(12.dp)
                .clip(CircleShape)
                .background(categoryColor(entry.category))
        )

        Spacer(modifier = Modifier.width(12.dp))

        // Display name and description
        Column(
            modifier = Modifier.weight(1f)
        ) {
            Text(
                text = entry.displayName,
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = FontWeight.Medium,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            if (!entry.description.isNullOrBlank()) {
                Text(
                    text = entry.description,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }

        Spacer(modifier = Modifier.width(8.dp))

        // Time of detection
        Column(
            horizontalAlignment = Alignment.End
        ) {
            Text(
                text = formatTime(entry.lastSeen),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )

            Spacer(modifier = Modifier.height(2.dp))

            // Detection source badge
            DetectionSourceBadge(source = entry.detectionSource)
        }
    }
}

@Composable
private fun DetectionSourceBadge(source: String) {
    val (icon, label) = detectionSourceInfo(source)
    val badgeColor = MaterialTheme.colorScheme.surfaceVariant
    val tintColor = MaterialTheme.colorScheme.onSurfaceVariant

    Surface(
        shape = RoundedCornerShape(4.dp),
        color = badgeColor
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 4.dp, vertical = 2.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = icon,
                contentDescription = label,
                modifier = Modifier.size(12.dp),
                tint = tintColor
            )
            Spacer(modifier = Modifier.width(2.dp))
            Text(
                text = label,
                style = MaterialTheme.typography.labelSmall,
                color = tintColor
            )
        }
    }
}

/** Formats a timestamp (epoch millis) to a readable time string like "2:45 PM". */
private fun formatTime(epochMillis: Long): String {
    val formatter = DateTimeFormatter.ofPattern("h:mm a", Locale.getDefault())
    return Instant.ofEpochMilli(epochMillis)
        .atZone(ZoneId.systemDefault())
        .format(formatter)
}

/** Formats a timestamp to a compact date-time string like "May 26, 2:45 PM". */
private fun formatDateTime(epochMillis: Long): String {
    val formatter = DateTimeFormatter.ofPattern("MMM d, h:mm a", Locale.getDefault())
    return Instant.ofEpochMilli(epochMillis)
        .atZone(ZoneId.systemDefault())
        .format(formatter)
}

/** Maps a detection source string to its icon and short label. */
private fun detectionSourceInfo(source: String): Pair<ImageVector, String> = when (source.lowercase()) {
    "ads_b" -> Icons.Default.CellTower to "ADS-B"
    "remote_id" -> Icons.Default.Bluetooth to "RID"
    "wifi_nan" -> Icons.Default.Wifi to "NaN"
    "wifi_beacon" -> Icons.Default.Wifi to "Beacon"
    "wifi" -> Icons.Default.Wifi to "WiFi"
    else -> Icons.Default.CellTower to source
}
