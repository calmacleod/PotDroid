package com.potdroid.android

import android.Manifest
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Button
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.camera.core.CameraSelector
import androidx.camera.core.Preview as CameraXPreview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.ui.viewinterop.AndroidView
import com.potdroid.android.data.DebugSettings
import com.potdroid.android.network.ApiClient
import com.potdroid.android.network.PairingParser
import com.potdroid.android.network.PairingPayload
import com.potdroid.android.network.PairingRequest
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            PotDroidTheme {
                Surface(modifier = Modifier.fillMaxSize()) {
                    PotDroidApp(initialPairingInput = intent?.dataString.orEmpty())
                }
            }
        }
    }
}

@Composable
fun PotDroidApp(initialPairingInput: String = "") {
    val context = LocalContext.current
    val settings = remember { DebugSettings(context) }
    val scope = rememberCoroutineScope()
    var apiBaseUrl by remember { mutableStateOf(settings.apiBaseUrl) }
    var apiToken by remember { mutableStateOf(settings.apiToken) }
    var pairingInput by remember { mutableStateOf(initialPairingInput) }
    var pairingStatus by remember { mutableStateOf<String?>(null) }
    var hasCameraPermission by remember { mutableStateOf(false) }
    val permissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestMultiplePermissions(),
    ) { grants ->
        hasCameraPermission = grants[Manifest.permission.CAMERA] == true
    }

    LaunchedEffect(Unit) {
        permissionLauncher.launch(
            arrayOf(
                Manifest.permission.CAMERA,
                Manifest.permission.ACCESS_FINE_LOCATION,
            )
        )
    }

    PotDroidScreen(
        apiBaseUrl = apiBaseUrl,
        apiToken = apiToken,
        pairingInput = pairingInput,
        pairingStatus = pairingStatus,
        hasCameraPermission = hasCameraPermission,
        onApiBaseUrlChange = { apiBaseUrl = it },
        onApiTokenChange = { apiToken = it },
        onPairingInputChange = { pairingInput = it },
        onSave = {
            settings.apiBaseUrl = apiBaseUrl
            settings.apiToken = apiToken
            pairingStatus = "Connection settings saved."
        },
        onPair = {
            scope.launch {
                pairingStatus = "Pairing..."
                val parsedPairing = PairingParser.parse(pairingInput, fallbackApiBaseUrl = apiBaseUrl)
                settings.apiBaseUrl = parsedPairing.apiBaseUrl
                apiBaseUrl = settings.apiBaseUrl

                runCatching {
                    ApiClient(settings).candidatePotholeApi().claimPairing(
                        PairingRequest(
                            pairing = PairingPayload(
                                code = parsedPairing.code,
                                deviceName = "${Build.MANUFACTURER} ${Build.MODEL}".trim(),
                            )
                        )
                    )
                }.onSuccess { response ->
                    if (response.isSuccessful) {
                        val token = response.body()?.data?.attributes?.apiToken
                        if (token.isNullOrBlank()) {
                            pairingStatus = "Pairing response did not include a token."
                        } else {
                            settings.apiToken = token
                            apiToken = token
                            pairingInput = ""
                            pairingStatus = "Paired. Long-lived token saved."
                        }
                    } else {
                        pairingStatus = "Pairing failed: HTTP ${response.code()}"
                    }
                }.onFailure { error ->
                    pairingStatus = "Pairing failed: ${error.message ?: error::class.java.simpleName}"
                }
            }
        },
        onRequestPermissions = {
            permissionLauncher.launch(arrayOf(Manifest.permission.CAMERA, Manifest.permission.ACCESS_FINE_LOCATION))
        },
        cameraContent = { modifier -> CameraPreview(modifier = modifier) },
    )
}

@Composable
fun PotDroidScreen(
    apiBaseUrl: String,
    apiToken: String,
    pairingInput: String,
    pairingStatus: String?,
    hasCameraPermission: Boolean,
    onApiBaseUrlChange: (String) -> Unit,
    onApiTokenChange: (String) -> Unit,
    onPairingInputChange: (String) -> Unit,
    onSave: () -> Unit,
    onPair: () -> Unit,
    onRequestPermissions: () -> Unit,
    modifier: Modifier = Modifier,
    cameraContent: @Composable (Modifier) -> Unit = { cameraModifier ->
        CameraPreviewPlaceholder(modifier = cameraModifier)
    },
) {
    val cameraShape = RoundedCornerShape(18.dp)
    val statusColor = when {
        pairingStatus?.startsWith("Pairing failed") == true -> MaterialTheme.colorScheme.error
        pairingStatus?.startsWith("Paired") == true -> Color(0xFF0B6B47)
        pairingStatus.present() -> MaterialTheme.colorScheme.primary
        else -> MaterialTheme.colorScheme.onSurfaceVariant
    }

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp, vertical = 18.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(
                    text = "PotDroid",
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.SemiBold,
                )
                Text(
                    text = "Road scan console",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    style = MaterialTheme.typography.bodyMedium,
                )
            }
            StatusPill(text = if (apiToken.isBlank()) "Unpaired" else "Ready")
        }

        ElevatedCard(
            colors = CardDefaults.elevatedCardColors(containerColor = MaterialTheme.colorScheme.surface),
            elevation = CardDefaults.elevatedCardElevation(defaultElevation = 1.dp),
            shape = RoundedCornerShape(18.dp),
        ) {
            Column(
                modifier = Modifier.padding(12.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        Text(
                            text = "Camera",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.SemiBold,
                        )
                        Text(
                            text = "Forward-facing scan preview",
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            style = MaterialTheme.typography.bodySmall,
                        )
                    }
                    StatusPill(text = if (hasCameraPermission) "Live" else "Permission")
                }

                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(min = 220.dp, max = 320.dp)
                        .clip(cameraShape)
                        .border(1.dp, MaterialTheme.colorScheme.outlineVariant, cameraShape),
                ) {
                    if (hasCameraPermission) {
                        cameraContent(Modifier.fillMaxSize())
                    } else {
                        CameraPermissionPlaceholder(
                            modifier = Modifier.fillMaxSize(),
                            onRequestPermissions = onRequestPermissions,
                        )
                    }
                }
            }
        }

        ElevatedCard(
            colors = CardDefaults.elevatedCardColors(containerColor = MaterialTheme.colorScheme.surface),
            elevation = CardDefaults.elevatedCardElevation(defaultElevation = 1.dp),
            shape = RoundedCornerShape(18.dp),
        ) {
            Column(
                modifier = Modifier.padding(14.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Text(
                    text = "Connection",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                )
                OutlinedTextField(
                    value = apiBaseUrl,
                    onValueChange = onApiBaseUrlChange,
                    label = { Text("API base URL") },
                    modifier = Modifier.fillMaxWidth(),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri),
                    singleLine = true,
                )
                OutlinedTextField(
                    value = apiToken,
                    onValueChange = onApiTokenChange,
                    label = { Text("Long-lived API token") },
                    modifier = Modifier.fillMaxWidth(),
                    visualTransformation = PasswordVisualTransformation(),
                    singleLine = true,
                )
                OutlinedButton(
                    onClick = onSave,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text("Save connection settings")
                }
            }
        }

        ElevatedCard(
            colors = CardDefaults.elevatedCardColors(containerColor = MaterialTheme.colorScheme.surface),
            elevation = CardDefaults.elevatedCardElevation(defaultElevation = 1.dp),
            shape = RoundedCornerShape(18.dp),
        ) {
            Column(
                modifier = Modifier.padding(14.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Text(
                    text = "Pairing",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                )
                OutlinedTextField(
                    value = pairingInput,
                    onValueChange = onPairingInputChange,
                    label = { Text("QR payload, deep link, or code") },
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(min = 96.dp),
                    minLines = 2,
                    maxLines = 4,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Text),
                )
                Button(
                    onClick = onPair,
                    enabled = pairingInput.isNotBlank(),
                    modifier = Modifier.fillMaxWidth(),
                    colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.primary),
                ) {
                    Text("Pair this device")
                }

                FilledTonalButton(
                    onClick = onRequestPermissions,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text("Review app permissions")
                }
            }
        }

        if (pairingStatus.present()) {
            Surface(
                modifier = Modifier.fillMaxWidth(),
                color = statusColor.copy(alpha = 0.08f),
                border = BorderStroke(1.dp, statusColor.copy(alpha = 0.24f)),
                shape = RoundedCornerShape(12.dp),
            ) {
                Text(
                    text = pairingStatus.orEmpty(),
                    modifier = Modifier.padding(horizontal = 12.dp, vertical = 10.dp),
                    color = statusColor,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Medium,
                )
            }
        }
        Spacer(modifier = Modifier.height(2.dp))
    }
}

private fun String?.present(): Boolean = !isNullOrBlank()

@Composable
private fun StatusPill(text: String) {
    Surface(
        color = MaterialTheme.colorScheme.secondaryContainer,
        contentColor = MaterialTheme.colorScheme.onSecondaryContainer,
        shape = RoundedCornerShape(999.dp),
    ) {
        Text(
            text = text,
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 5.dp),
            style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.SemiBold,
        )
    }
}

@Composable
private fun CameraPermissionPlaceholder(
    onRequestPermissions: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier
            .background(Color(0xFF101828)),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            modifier = Modifier.padding(20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text(
                text = "Camera access needed",
                color = Color.White,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
            )
            Text(
                text = "Grant camera and location permissions before road scanning.",
                color = Color(0xFFCBD5E1),
                style = MaterialTheme.typography.bodySmall,
            )
            FilledTonalButton(onClick = onRequestPermissions) {
                Text("Grant permissions")
            }
        }
    }
}

@Composable
fun CameraPreview(modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current

    AndroidView(
        modifier = modifier,
        factory = { viewContext ->
            PreviewView(viewContext).also { previewView ->
                val cameraProviderFuture = ProcessCameraProvider.getInstance(viewContext)
                cameraProviderFuture.addListener(
                    {
                        val cameraProvider = cameraProviderFuture.get()
                        val preview = CameraXPreview.Builder().build().also {
                            it.surfaceProvider = previewView.surfaceProvider
                        }
                        cameraProvider.unbindAll()
                        cameraProvider.bindToLifecycle(
                            lifecycleOwner,
                            CameraSelector.DEFAULT_BACK_CAMERA,
                            preview,
                        )
                    },
                    ContextCompat.getMainExecutor(context),
                )
            }
        },
    )
}

@Composable
fun CameraPreviewPlaceholder(modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .background(Color(0xFF101828)),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Box(
                modifier = Modifier
                    .width(72.dp)
                    .height(4.dp)
                    .background(Color(0xFF22C55E), RoundedCornerShape(999.dp)),
            )
            Text(
                text = "Camera preview",
                color = Color.White,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
            )
            Text(
                text = "Detection overlay ready",
                color = Color(0xFFCBD5E1),
                style = MaterialTheme.typography.bodySmall,
            )
        }
    }
}

@Composable
fun PotDroidTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = lightColorScheme(
            primary = Color(0xFF155EEF),
            onPrimary = Color.White,
            secondary = Color(0xFF475467),
            onSecondary = Color.White,
            secondaryContainer = Color(0xFFE6EAF0),
            onSecondaryContainer = Color(0xFF1D2939),
            background = Color(0xFFF5F6F8),
            onBackground = Color(0xFF101828),
            surface = Color.White,
            onSurface = Color(0xFF101828),
            surfaceVariant = Color(0xFFF1F3F6),
            onSurfaceVariant = Color(0xFF667085),
            outline = Color(0xFFB8C0CC),
            outlineVariant = Color(0xFFD7DCE3),
            error = Color(0xFFB42318),
        ),
        content = content,
    )
}

@Preview(name = "PotDroid - Ready", showBackground = true)
@Composable
private fun PotDroidReadyPreview() {
    PotDroidTheme {
        Surface(modifier = Modifier.fillMaxSize()) {
            PotDroidScreen(
                apiBaseUrl = "https://example.trycloudflare.com/",
                apiToken = "pd_preview_token",
                pairingInput = "",
                pairingStatus = "Paired. Long-lived token saved.",
                hasCameraPermission = true,
                onApiBaseUrlChange = {},
                onApiTokenChange = {},
                onPairingInputChange = {},
                onSave = {},
                onPair = {},
                onRequestPermissions = {},
            )
        }
    }
}

@Preview(name = "PotDroid - Permissions Needed", showBackground = true)
@Composable
private fun PotDroidPermissionsPreview() {
    PotDroidTheme {
        Surface(modifier = Modifier.fillMaxSize()) {
            PotDroidScreen(
                apiBaseUrl = "https://example.trycloudflare.com/",
                apiToken = "",
                pairingInput = "potdroid://pair?api_base_url=https%3A%2F%2Fexample.trycloudflare.com&code=ABCD-EFGH-JK23",
                pairingStatus = null,
                hasCameraPermission = false,
                onApiBaseUrlChange = {},
                onApiTokenChange = {},
                onPairingInputChange = {},
                onSave = {},
                onPair = {},
                onRequestPermissions = {},
            )
        }
    }
}
