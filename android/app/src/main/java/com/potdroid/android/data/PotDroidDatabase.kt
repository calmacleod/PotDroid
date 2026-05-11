package com.potdroid.android.data

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.TypeConverters
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase

@Database(
    entities = [CandidatePotholeEntity::class],
    version = 2,
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
                )
                    .addMigrations(MIGRATION_1_2)
                    .build()
                    .also { instance = it }
            }

        private val MIGRATION_1_2 = object : Migration(1, 2) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("ALTER TABLE candidate_potholes ADD COLUMN accelerometerData TEXT")
            }
        }
    }
}
