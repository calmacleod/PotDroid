package com.potdroid.android.data

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import kotlinx.coroutines.flow.Flow

@Dao
interface CandidatePotholeDao {
    @Query("SELECT * FROM candidate_potholes ORDER BY capturedAtMillis DESC")
    fun observeAll(): Flow<List<CandidatePotholeEntity>>

    @Query("SELECT * FROM candidate_potholes WHERE uploadStatus IN (:statuses) ORDER BY capturedAtMillis ASC")
    suspend fun pendingUploads(statuses: List<UploadStatus> = listOf(UploadStatus.Pending, UploadStatus.Failed)): List<CandidatePotholeEntity>

    @Query("SELECT * FROM candidate_potholes WHERE id = :id")
    suspend fun find(id: Long): CandidatePotholeEntity?

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insert(candidate: CandidatePotholeEntity): Long

    @Update
    suspend fun update(candidate: CandidatePotholeEntity)
}
