package com.potdroid.android.data

import androidx.room.TypeConverter

class RoomConverters {
    @TypeConverter
    fun uploadStatusToString(status: UploadStatus): String = status.name

    @TypeConverter
    fun stringToUploadStatus(value: String): UploadStatus = UploadStatus.valueOf(value)
}
