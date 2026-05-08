package com.potdroid.android.network

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import okhttp3.MultipartBody
import okhttp3.RequestBody
import okhttp3.ResponseBody
import retrofit2.Response
import retrofit2.http.GET
import retrofit2.http.Body
import retrofit2.http.Multipart
import retrofit2.http.POST
import retrofit2.http.Part
import retrofit2.http.Path

interface CandidatePotholeApi {
    @GET("up")
    suspend fun healthCheck(): Response<ResponseBody>

    @POST("api/v1/pairing")
    suspend fun claimPairing(@Body request: PairingRequest): Response<PairingResponse>

    @Multipart
    @POST("api/v1/candidate_potholes")
    suspend fun createCandidate(
        @Part image: MultipartBody.Part,
        @Part("candidate_pothole[latitude]") latitude: RequestBody,
        @Part("candidate_pothole[longitude]") longitude: RequestBody,
        @Part("candidate_pothole[heading]") heading: RequestBody?,
        @Part("candidate_pothole[speed]") speed: RequestBody?,
        @Part("candidate_pothole[detector_confidence]") detectorConfidence: RequestBody,
        @Part("candidate_pothole[detector_model_version]") detectorModelVersion: RequestBody,
        @Part("candidate_pothole[captured_at]") capturedAt: RequestBody,
        @Part("candidate_pothole[bounding_box][left]") boundingBoxLeft: RequestBody,
        @Part("candidate_pothole[bounding_box][top]") boundingBoxTop: RequestBody,
        @Part("candidate_pothole[bounding_box][right]") boundingBoxRight: RequestBody,
        @Part("candidate_pothole[bounding_box][bottom]") boundingBoxBottom: RequestBody,
    ): Response<CandidateResponse>

    @GET("api/v1/candidate_potholes/{id}")
    suspend fun candidate(@Path("id") id: Long): CandidateResponse
}

@Serializable
data class PairingRequest(
    val pairing: PairingPayload,
)

@Serializable
data class PairingPayload(
    val code: String,
    @SerialName("device_name") val deviceName: String,
)

@Serializable
data class PairingResponse(
    val data: PairingData,
)

@Serializable
data class PairingData(
    val type: String,
    val attributes: PairingAttributes,
)

@Serializable
data class PairingAttributes(
    @SerialName("api_token") val apiToken: String,
    @SerialName("token_type") val tokenType: String,
    @SerialName("long_lived") val longLived: Boolean,
    @SerialName("user_email") val userEmail: String? = null,
)

@Serializable
data class CandidateResponse(
    val data: CandidateData,
)

@Serializable
data class CandidateData(
    val id: Long,
    val type: String,
    val attributes: CandidateAttributes,
)

@Serializable
data class CandidateAttributes(
    val status: String,
    val latitude: Double,
    val longitude: Double,
    @SerialName("detector_confidence") val detectorConfidence: Double,
    @SerialName("detector_model_version") val detectorModelVersion: String? = null,
)
