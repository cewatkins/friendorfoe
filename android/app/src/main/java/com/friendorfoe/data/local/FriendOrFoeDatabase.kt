package com.friendorfoe.data.local

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase

/**
 * Room database for Friend or Foe local data storage.
 *
 * Currently stores detection history. Future versions may cache
 * aircraft metadata for offline use.
 */
@Database(
    entities = [HistoryEntity::class, TrackingEntity::class, GameSessionEntity::class],
    version = 6,
    exportSchema = true
)
abstract class FriendOrFoeDatabase : RoomDatabase() {

    abstract fun historyDao(): HistoryDao
    abstract fun trackingDao(): TrackingDao
    abstract fun gameSessionDao(): GameSessionDao

    companion object {
        private const val DATABASE_NAME = "friendorfoe.db"

        /** Migration from v2 to v3: no schema changes, preserves data. */
        private val MIGRATION_2_3 = object : Migration(2, 3) {
            override fun migrate(db: SupportSQLiteDatabase) {
                // No schema changes — this migration exists to avoid destructive fallback
            }
        }

        /** Migration from v3 to v4: add indices for query performance. */
        private val MIGRATION_3_4 = object : Migration(3, 4) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("CREATE INDEX IF NOT EXISTS `index_detection_history_object_id` ON `detection_history` (`object_id`)")
                db.execSQL("CREATE INDEX IF NOT EXISTS `index_detection_history_object_type` ON `detection_history` (`object_type`)")
                db.execSQL("CREATE INDEX IF NOT EXISTS `index_detection_history_last_seen` ON `detection_history` (`last_seen`)")
                db.execSQL("CREATE INDEX IF NOT EXISTS `index_position_tracking_object_id` ON `position_tracking` (`object_id`)")
                db.execSQL("CREATE INDEX IF NOT EXISTS `index_position_tracking_timestamp` ON `position_tracking` (`timestamp`)")
            }
        }

        /** Migration from v4 to v5: add local gameplay session persistence table. */
        private val MIGRATION_4_5 = object : Migration(4, 5) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL(
                    """
                    CREATE TABLE IF NOT EXISTS `game_sessions` (
                        `id` INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
                        `started_at` INTEGER NOT NULL,
                        `ended_at` INTEGER NOT NULL,
                        `duration_seconds` INTEGER NOT NULL,
                        `score` INTEGER NOT NULL,
                        `shots` INTEGER NOT NULL,
                        `hits` INTEGER NOT NULL,
                        `misses` INTEGER NOT NULL,
                        `best_streak` INTEGER NOT NULL,
                        `accuracy_percent` INTEGER NOT NULL,
                        `exit_reason` TEXT NOT NULL
                    )
                    """.trimIndent()
                )
                db.execSQL("CREATE INDEX IF NOT EXISTS `index_game_sessions_ended_at` ON `game_sessions` (`ended_at`)")
                db.execSQL("CREATE INDEX IF NOT EXISTS `index_game_sessions_score` ON `game_sessions` (`score`)")
            }
        }

        /** Migration from v5 to v6: add shotdown summary columns for game sessions. */
        private val MIGRATION_5_6 = object : Migration(5, 6) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("ALTER TABLE `game_sessions` ADD COLUMN `shot_down_count` INTEGER NOT NULL DEFAULT 0")
                db.execSQL("ALTER TABLE `game_sessions` ADD COLUMN `shot_down_targets` TEXT NOT NULL DEFAULT ''")
            }
        }

        fun create(context: Context): FriendOrFoeDatabase {
            return Room.databaseBuilder(
                context.applicationContext,
                FriendOrFoeDatabase::class.java,
                DATABASE_NAME
            )
                .addMigrations(MIGRATION_2_3, MIGRATION_3_4, MIGRATION_4_5, MIGRATION_5_6)
                .build()
        }
    }
}
