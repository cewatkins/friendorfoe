package com.friendorfoe.data.repository

import com.friendorfoe.data.local.GameSessionDao
import com.friendorfoe.data.local.GameSessionEntity
import kotlinx.coroutines.flow.Flow
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class GameSessionRepository @Inject constructor(
    private val gameSessionDao: GameSessionDao
) {
    suspend fun saveSession(entity: GameSessionEntity): Long {
        return gameSessionDao.insert(entity)
    }

    fun getAllSessions(): Flow<List<GameSessionEntity>> {
        return gameSessionDao.getAllSessions()
    }

    fun getTopSessions(limit: Int = 20): Flow<List<GameSessionEntity>> {
        return gameSessionDao.getTopSessions(limit)
    }

    suspend fun clearSessions() {
        gameSessionDao.deleteAll()
    }
}
