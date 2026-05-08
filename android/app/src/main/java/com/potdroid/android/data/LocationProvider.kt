package com.potdroid.android.data

import android.annotation.SuppressLint
import android.content.Context
import com.google.android.gms.location.LocationServices
import kotlinx.coroutines.tasks.await

data class RoadLocation(
    val latitude: Double,
    val longitude: Double,
    val heading: Double?,
    val speed: Double?,
)

class LocationProvider(context: Context) {
    private val fusedLocationClient = LocationServices.getFusedLocationProviderClient(context)

    @SuppressLint("MissingPermission")
    suspend fun currentLocation(): RoadLocation? {
        val location = fusedLocationClient.lastLocation.await() ?: return null
        return RoadLocation(
            latitude = location.latitude,
            longitude = location.longitude,
            heading = if (location.hasBearing()) location.bearing.toDouble() else null,
            speed = if (location.hasSpeed()) location.speed.toDouble() else null,
        )
    }
}
