package com.friendorfoe.data.local

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

/**
 * Room entity for persisted local gameplay sessions.
 */
@Entity(
    tableName = "game_sessions",
    indices = [
        Index(value = ["ended_at"]),
        Index(value = ["score"])
    ]
)
data class GameSessionEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,

    @ColumnInfo(name = "started_at")
    val startedAt: Long,

    @ColumnInfo(name = "ended_at")
    val endedAt: Long,

    @ColumnInfo(name = "duration_seconds")
    val durationSeconds: Int,

    @ColumnInfo(name = "score")
    val score: Int,

    @ColumnInfo(name = "shots")
    val shots: Int,

    @ColumnInfo(name = "hits")
    val hits: Int,

    @ColumnInfo(name = "misses")
    val misses: Int,

    @ColumnInfo(name = "best_streak")
    val bestStreak: Int,

    @ColumnInfo(name = "accuracy_percent")
    val accuracyPercent: Int,

    @ColumnInfo(name = "shot_down_count")
    val shotDownCount: Int = 0,

    @ColumnInfo(name = "shot_down_targets")
    val shotDownTargets: String = "",

    @ColumnInfo(name = "exit_reason")
    val exitReason: String
)
