package com.potdroid.android.data

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.TypeConverters

@Database(
    entities = [CandidatePotholeEntity::class],
    version = 1,
    exportSchema = false,
)
@TypeConverters(RoomConverters::class)
abstract class PotDroidDatabase : RoomDatabase() {
    abstract fun candidatePotholeDao(): CandidatePotholeDao

    companion object {
        @Volatile private var instance: PotDroidDatabase? = null

        fun get(context: Context): PotDroidDatabase =
            instance ?: synchronized(this) {
                instance ?: Room.databaseBuilder(
                    context.applicationContext,
                    PotDroidDatabase::class.java,
                    "potdroid.db",
                ).build().also { instance = it }
            }
    }
}
