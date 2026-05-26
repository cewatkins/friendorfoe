package com.friendorfoe.data.local

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface GameSessionDao {

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(entity: GameSessionEntity): Long

    @Query("SELECT * FROM game_sessions ORDER BY ended_at DESC")
    fun getAllSessions(): Flow<List<GameSessionEntity>>

    @Query("SELECT * FROM game_sessions ORDER BY score DESC, ended_at DESC LIMIT :limit")
    fun getTopSessions(limit: Int = 20): Flow<List<GameSessionEntity>>

    @Query("DELETE FROM game_sessions")
    suspend fun deleteAll()
}
