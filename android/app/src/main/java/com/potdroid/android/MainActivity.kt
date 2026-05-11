package com.potdroid.android

import android.Manifest
import android.graphics.Bitmap
import android.graphics.Matrix
import android.os.Build
import android.os.Bundle
import android.util.Size as AndroidSize
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.CameraSelector
import androidx.camera.core.ExperimentalGetImage
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview as CameraXPreview
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import com.potdroid.android.data.AccelerometerDisplayState
import com.potdroid.android.data.AccelerometerMonitor
import com.potdroid.android.data.DebugSettings
import com.potdroid.android.data.CandidateRepository
import com.potdroid.android.data.LocationProvider
import com.potdroid.android.data.PotDroidDatabase
import com.potdroid.android.network.ApiClient
import com.potdroid.android.network.PairingParser
import com.potdroid.android.network.PairingPayload
import com.potdroid.android.network.PairingRequest
import com.potdroid.android.vision.BoundingBox
import com.potdroid.android.vision.TflitePotholeDetector
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.Locale
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong
import java.util.concurrent.Executors

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
    var connectivityStatus by remember { mutableStateOf<String?>(null) }
    var scanningStatus by remember { mutableStateOf("Model ready") }
    var scannerLog by remember { mutableStateOf<List<String>>(emptyList()) }
    var hasCameraPermission by remember { mutableStateOf(false) }
    var driveStarted by remember { mutableStateOf(false) }
    val permissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestMultiplePermissions(),
    ) { grants ->
        hasCameraPermission = grants[Manifest.permission.CAMERA] == true
    }

    fun saveConnection() {
        settings.apiBaseUrl = apiBaseUrl
        settings.apiToken = apiToken
    }

    fun appendScannerLog(message: String) {
        if (!BuildConfig.DEBUG || scannerLog.lastOrNull() == message) return
        scannerLog = (scannerLog + message).takeLast(MAX_SCANNER_LOG_LINES)
    }

    fun pairWith(input: String) {
        pairingInput = input
        scope.launch {
            pairingStatus = "Pairing..."
            connectivityStatus = null
            val parsedPairing = PairingParser.parse(input, fallbackApiBaseUrl = apiBaseUrl)
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
                        driveStarted = false
                        scanningStatus = "Ready"
                        pairingStatus = "Paired. Long-lived token saved."
                    }
                } else {
                    pairingStatus = "Pairing failed: HTTP ${response.code()}"
                }
            }.onFailure { error ->
                pairingStatus = "Pairing failed: ${error.message ?: error::class.java.simpleName}"
            }
        }
    }

    fun testConnection() {
        saveConnection()
        scope.launch {
            connectivityStatus = "Testing connection..."
            runCatching {
                ApiClient(settings).candidatePotholeApi().healthCheck()
            }.onSuccess { response ->
                connectivityStatus = if (response.isSuccessful) {
                    "Connection OK"
                } else {
                    "Connection failed: HTTP ${response.code()}"
                }
            }.onFailure { error ->
                connectivityStatus = "Connection failed: ${error.message ?: error::class.java.simpleName}"
            }
        }
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
        connectivityStatus = connectivityStatus,
        scanningStatus = scanningStatus,
        scannerLog = scannerLog,
        hasCameraPermission = hasCameraPermission,
        driveStarted = driveStarted,
        onApiBaseUrlChange = { apiBaseUrl = it },
        onApiTokenChange = { apiToken = it },
        onPairingInputChange = { pairingInput = it },
        onSave = {
            saveConnection()
            connectivityStatus = "Connection settings saved."
        },
        onPair = { pairWith(pairingInput) },
        onQrScanned = { scannedPayload ->
            if (apiToken.isBlank() && pairingStatus != "Pairing...") pairWith(scannedPayload)
        },
        onTestConnection = { testConnection() },
        onUnpair = {
            settings.apiToken = ""
            apiToken = ""
            driveStarted = false
            pairingStatus = null
            connectivityStatus = "Device unpaired."
        },
        onStartDrive = {
            driveStarted = true
            scanningStatus = "Scanning"
            appendScannerLog("Drive started")
        },
        onStopDrive = {
            driveStarted = false
            scanningStatus = "Ready"
            appendScannerLog("Drive stopped")
        },
        onRequestPermissions = {
            permissionLauncher.launch(arrayOf(Manifest.permission.CAMERA, Manifest.permission.ACCESS_FINE_LOCATION))
        },
        drivingCameraContent = { modifier ->
            CameraPreview(
                modifier = modifier,
                onStatusChange = { scanningStatus = it },
                onLog = { appendScannerLog(it) },
            )
        },
        qrScannerContent = { modifier, onQrScanned ->
            QrScannerPreview(modifier = modifier, onQrScanned = onQrScanned)
        },
    )
}

@Composable
fun PotDroidScreen(
    apiBaseUrl: String,
    apiToken: String,
    pairingInput: String,
    pairingStatus: String?,
    connectivityStatus: String?,
    scanningStatus: String,
    scannerLog: List<String>,
    hasCameraPermission: Boolean,
    driveStarted: Boolean,
    onApiBaseUrlChange: (String) -> Unit,
    onApiTokenChange: (String) -> Unit,
    onPairingInputChange: (String) -> Unit,
    onSave: () -> Unit,
    onPair: () -> Unit,
    onQrScanned: (String) -> Unit,
    onTestConnection: () -> Unit,
    onUnpair: () -> Unit,
    onStartDrive: () -> Unit,
    onStopDrive: () -> Unit,
    onRequestPermissions: () -> Unit,
    modifier: Modifier = Modifier,
    drivingCameraContent: @Composable (Modifier) -> Unit = { cameraModifier ->
        CameraPreviewPlaceholder(modifier = cameraModifier)
    },
    qrScannerContent: @Composable (Modifier, (String) -> Unit) -> Unit = { scannerModifier, _ ->
        QrScannerPlaceholder(modifier = scannerModifier)
    },
) {
    if (apiToken.isBlank()) {
        UnpairedScreen(
            apiBaseUrl = apiBaseUrl,
            pairingInput = pairingInput,
            pairingStatus = pairingStatus,
            connectivityStatus = connectivityStatus,
            hasCameraPermission = hasCameraPermission,
            onApiBaseUrlChange = onApiBaseUrlChange,
            onPairingInputChange = onPairingInputChange,
            onPair = onPair,
            onQrScanned = onQrScanned,
            onTestConnection = onTestConnection,
            onRequestPermissions = onRequestPermissions,
            qrScannerContent = qrScannerContent,
            modifier = modifier,
        )
    } else {
        DrivingScreen(
            apiBaseUrl = apiBaseUrl,
            apiToken = apiToken,
            connectivityStatus = connectivityStatus,
            scanningStatus = scanningStatus,
            scannerLog = scannerLog,
            hasCameraPermission = hasCameraPermission,
            driveStarted = driveStarted,
            onApiBaseUrlChange = onApiBaseUrlChange,
            onApiTokenChange = onApiTokenChange,
            onSave = onSave,
            onTestConnection = onTestConnection,
            onUnpair = onUnpair,
            onStartDrive = onStartDrive,
            onStopDrive = onStopDrive,
            onRequestPermissions = onRequestPermissions,
            cameraContent = drivingCameraContent,
            modifier = modifier,
        )
    }
}

@Composable
private fun UnpairedScreen(
    apiBaseUrl: String,
    pairingInput: String,
    pairingStatus: String?,
    connectivityStatus: String?,
    hasCameraPermission: Boolean,
    onApiBaseUrlChange: (String) -> Unit,
    onPairingInputChange: (String) -> Unit,
    onPair: () -> Unit,
    onQrScanned: (String) -> Unit,
    onTestConnection: () -> Unit,
    onRequestPermissions: () -> Unit,
    qrScannerContent: @Composable (Modifier, (String) -> Unit) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .windowInsetsPadding(WindowInsets.safeDrawing)
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp, vertical = 18.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        HeaderBlock(title = "Pair PotDroid", subtitle = "Scan the Rails QR code", status = "Unpaired")

        ElevatedCard(
            colors = CardDefaults.elevatedCardColors(containerColor = MaterialTheme.colorScheme.surface),
            elevation = CardDefaults.elevatedCardElevation(defaultElevation = 1.dp),
            shape = RoundedCornerShape(20.dp),
        ) {
            Column(
                modifier = Modifier.padding(12.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text("QR scanner", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                    StatusPill(text = if (hasCameraPermission) "Camera on" else "Permission")
                }

                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(min = 360.dp, max = 460.dp)
                        .clip(RoundedCornerShape(18.dp))
                        .border(1.dp, MaterialTheme.colorScheme.outlineVariant, RoundedCornerShape(18.dp)),
                ) {
                    if (hasCameraPermission) {
                        qrScannerContent(Modifier.fillMaxSize(), onQrScanned)
                        ScannerFrame(modifier = Modifier.fillMaxSize())
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
                OutlinedTextField(
                    value = apiBaseUrl,
                    onValueChange = onApiBaseUrlChange,
                    label = { Text("API base URL") },
                    modifier = Modifier.fillMaxWidth(),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri),
                    singleLine = true,
                )
                OutlinedTextField(
                    value = pairingInput,
                    onValueChange = onPairingInputChange,
                    label = { Text("QR payload, deep link, or code") },
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(min = 90.dp),
                    minLines = 2,
                    maxLines = 4,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Text),
                )
                Button(
                    onClick = onPair,
                    enabled = pairingInput.isNotBlank(),
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text("Pair device")
                }
                OutlinedButton(onClick = onTestConnection, modifier = Modifier.fillMaxWidth()) {
                    Text("Test Rails connection")
                }
            }
        }

        StatusMessage(pairingStatus ?: connectivityStatus)
    }
}

@Composable
private fun DrivingScreen(
    apiBaseUrl: String,
    apiToken: String,
    connectivityStatus: String?,
    scanningStatus: String,
    scannerLog: List<String>,
    hasCameraPermission: Boolean,
    driveStarted: Boolean,
    onApiBaseUrlChange: (String) -> Unit,
    onApiTokenChange: (String) -> Unit,
    onSave: () -> Unit,
    onTestConnection: () -> Unit,
    onUnpair: () -> Unit,
    onStartDrive: () -> Unit,
    onStopDrive: () -> Unit,
    onRequestPermissions: () -> Unit,
    cameraContent: @Composable (Modifier) -> Unit,
    modifier: Modifier = Modifier,
) {
    var settingsOpen by remember { mutableStateOf(false) }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(Color(0xFF070B12))
            .windowInsetsPadding(WindowInsets.safeDrawing),
    ) {
        if (driveStarted && hasCameraPermission) {
            cameraContent(Modifier.fillMaxSize())
        } else if (driveStarted) {
            CameraPermissionPlaceholder(
                modifier = Modifier.fillMaxSize(),
                onRequestPermissions = onRequestPermissions,
            )
        } else {
            DriveSetupPlaceholder(modifier = Modifier.fillMaxSize())
        }

        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color(0x33000000)),
        )

        Row(
            modifier = Modifier
                .align(Alignment.TopStart)
                .fillMaxWidth()
                .padding(12.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.Top,
        ) {
            Surface(
                color = Color(0xE60B1220),
                contentColor = Color.White,
                shape = RoundedCornerShape(999.dp),
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 7.dp),
                    horizontalArrangement = Arrangement.spacedBy(7.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    if (driveStarted) LiveDot()
                    Text(if (driveStarted) "Scanning" else "Ready", style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.SemiBold)
                }
            }

            Box {
                Surface(
                    color = Color(0xE60B1220),
                    contentColor = Color.White,
                    shape = RoundedCornerShape(999.dp),
                ) {
                    TextButton(onClick = { settingsOpen = true }) {
                        Text("Settings")
                    }
                }
                DropdownMenu(expanded = settingsOpen, onDismissRequest = { settingsOpen = false }) {
                    DropdownMenuItem(text = { Text("Test connection") }, onClick = {
                        settingsOpen = false
                        onTestConnection()
                    })
                    DropdownMenuItem(text = { Text("Unpair device") }, onClick = {
                        settingsOpen = false
                        onUnpair()
                    })
                    if (driveStarted) {
                        DropdownMenuItem(text = { Text("Stop drive") }, onClick = {
                            settingsOpen = false
                            onStopDrive()
                        })
                    }
                }
            }
        }

        if (!driveStarted) {
            Surface(
                modifier = Modifier
                    .align(Alignment.Center)
                    .padding(20.dp)
                    .fillMaxWidth(),
                color = Color(0xE60B1220),
                contentColor = Color.White,
                shape = RoundedCornerShape(20.dp),
            ) {
                Column(
                    modifier = Modifier.padding(16.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    Text(
                        text = "Ready for setup",
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.SemiBold,
                    )
                    Text(
                        text = "Mount the phone securely, then start the drive.",
                        color = Color(0xFFCBD5E1),
                        style = MaterialTheme.typography.bodyMedium,
                    )
                    Button(
                        onClick = onStartDrive,
                        enabled = hasCameraPermission,
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text("Start drive")
                    }
                    if (!hasCameraPermission) {
                        FilledTonalButton(onClick = onRequestPermissions, modifier = Modifier.fillMaxWidth()) {
                            Text("Grant permissions")
                        }
                    }
                }
            }
        }

        Surface(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(12.dp),
            color = Color(0xE60B1220),
            contentColor = Color.White,
            shape = RoundedCornerShape(999.dp),
        ) {
            Row(
                modifier = Modifier.padding(horizontal = 10.dp, vertical = 7.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                StatusPill(text = if (driveStarted) "Queue ready" else "Waiting")
                StatusPill(text = scanningStatus)
                Text(
                    text = connectivityStatus ?: apiBaseUrl.removeSuffix("/"),
                    color = Color(0xFFCBD5E1),
                    style = MaterialTheme.typography.bodySmall,
                    maxLines = 1,
                )
            }
        }

        if (BuildConfig.DEBUG && scannerLog.isNotEmpty()) {
            Surface(
                modifier = Modifier
                    .align(Alignment.BottomStart)
                    .padding(start = 12.dp, end = 12.dp, bottom = 64.dp)
                    .fillMaxWidth(0.82f),
                color = Color(0xD90B1220),
                contentColor = Color.White,
                shape = RoundedCornerShape(12.dp),
            ) {
                Column(
                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(2.dp),
                ) {
                    Text(
                        text = "Detector log",
                        style = MaterialTheme.typography.labelMedium,
                        color = Color(0xFF93C5FD),
                        fontWeight = FontWeight.SemiBold,
                    )
                    scannerLog.forEach { line ->
                        Text(
                            text = line,
                            style = MaterialTheme.typography.bodySmall,
                            color = Color(0xFFE2E8F0),
                            maxLines = 1,
                        )
                    }
                }
            }
        }

        if (settingsOpen) {
            Surface(
                modifier = Modifier
                    .align(Alignment.Center)
                    .padding(16.dp)
                    .fillMaxWidth(),
                color = MaterialTheme.colorScheme.surface,
                contentColor = MaterialTheme.colorScheme.onSurface,
                shape = RoundedCornerShape(18.dp),
                shadowElevation = 8.dp,
            ) {
                Column(
                    modifier = Modifier.padding(14.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text("Connection settings", fontWeight = FontWeight.SemiBold)
                        TextButton(onClick = { settingsOpen = false }) {
                            Text("Close")
                        }
                    }
                    SettingsFields(
                        apiBaseUrl = apiBaseUrl,
                        apiToken = apiToken,
                        onApiBaseUrlChange = onApiBaseUrlChange,
                        onApiTokenChange = onApiTokenChange,
                        onSave = onSave,
                    )
                }
            }
        }
    }
}

@Composable
private fun SettingsFields(
    apiBaseUrl: String,
    apiToken: String,
    onApiBaseUrlChange: (String) -> Unit,
    onApiTokenChange: (String) -> Unit,
    onSave: () -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
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
        OutlinedButton(onClick = onSave, modifier = Modifier.fillMaxWidth()) {
            Text("Save settings")
        }
    }
}

private fun String?.present(): Boolean = !isNullOrBlank()

@Composable
private fun HeaderBlock(title: String, subtitle: String, status: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                text = title,
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.SemiBold,
            )
            Text(
                text = subtitle,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                style = MaterialTheme.typography.bodyMedium,
            )
        }
        StatusPill(text = status)
    }
}

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
private fun StatusMessage(message: String?) {
    if (!message.present()) return

    val color = when {
        message?.startsWith("Pairing failed") == true -> MaterialTheme.colorScheme.error
        message?.startsWith("Connection failed") == true -> MaterialTheme.colorScheme.error
        message?.startsWith("Paired") == true -> Color(0xFF0B6B47)
        message?.startsWith("Connection OK") == true -> Color(0xFF0B6B47)
        else -> MaterialTheme.colorScheme.primary
    }

    Surface(
        modifier = Modifier.fillMaxWidth(),
        color = color.copy(alpha = 0.08f),
        border = BorderStroke(1.dp, color.copy(alpha = 0.24f)),
        shape = RoundedCornerShape(12.dp),
    ) {
        Text(
            text = message.orEmpty(),
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 10.dp),
            color = color,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.Medium,
        )
    }
}

@Composable
private fun LiveDot() {
    Box(
        modifier = Modifier
            .size(9.dp)
            .background(Color(0xFF22C55E), RoundedCornerShape(999.dp)),
    )
}

@Composable
private fun ScannerFrame(modifier: Modifier = Modifier) {
    Box(modifier = modifier.padding(36.dp), contentAlignment = Alignment.Center) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(240.dp)
                .border(2.dp, Color.White.copy(alpha = 0.86f), RoundedCornerShape(22.dp)),
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
                text = "Grant camera and location permissions before scanning.",
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
private fun DriveSetupPlaceholder(modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .background(Color(0xFF101828)),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            modifier = Modifier.padding(20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(
                text = "Camera paused",
                color = Color.White,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
            )
            Text(
                text = "Scanning starts only after the drive begins.",
                color = Color(0xFFCBD5E1),
                style = MaterialTheme.typography.bodySmall,
            )
        }
    }
}

@Composable
fun CameraPreview(
    modifier: Modifier = Modifier,
    onStatusChange: (String) -> Unit = {},
    onLog: (String) -> Unit = {},
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val scope = rememberCoroutineScope()
    val currentOnStatusChange by rememberUpdatedState(onStatusChange)
    val currentOnLog by rememberUpdatedState(onLog)
    val detectorResult = remember(context) { runCatching { TflitePotholeDetector(context.applicationContext) } }
    val repository = remember(context) {
        CandidateRepository(
            context.applicationContext,
            PotDroidDatabase.get(context).candidatePotholeDao(),
        )
    }
    val locationProvider = remember(context) { LocationProvider(context.applicationContext) }
    val accelerometerMonitor = remember(context) { AccelerometerMonitor(context.applicationContext) }
    val accelerometerState by accelerometerMonitor.state.collectAsState()
    val processing = remember { AtomicBoolean(false) }
    val modelErrorReported = remember { AtomicBoolean(false) }
    val lastSavedAtMillis = remember { AtomicLong(0) }
    val lastDetectedAtMillis = remember { AtomicLong(0) }
    val lastDetectionLogAtMillis = remember { AtomicLong(0) }
    val analyzerExecutor = remember { Executors.newSingleThreadExecutor() }
    var detectedBoundingBox by remember { mutableStateOf<BoundingBox?>(null) }

    DisposableEffect(detectorResult, analyzerExecutor, accelerometerMonitor) {
        accelerometerMonitor.start()
        if (detectorResult.isSuccess) {
            currentOnLog("Model loaded")
        } else {
            currentOnLog("Model failed: ${detectorResult.exceptionOrNull()?.javaClass?.simpleName ?: "unknown"}")
        }
        onDispose {
            accelerometerMonitor.stop()
            detectorResult.getOrNull()?.close()
            analyzerExecutor.shutdown()
        }
    }

    Box(modifier = modifier) {
        AndroidView(
            modifier = Modifier.fillMaxSize(),
            factory = { viewContext ->
                PreviewView(viewContext).also { previewView ->
                    val cameraProviderFuture = ProcessCameraProvider.getInstance(viewContext)
                    cameraProviderFuture.addListener(
                        {
                            val cameraProvider = cameraProviderFuture.get()
                            val preview = CameraXPreview.Builder().build().also {
                                it.surfaceProvider = previewView.surfaceProvider
                            }
                            val analysis = ImageAnalysis.Builder()
                                .setResolutionSelector(ANALYSIS_RESOLUTION_SELECTOR)
                                .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
                                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                                .build()
                                .also { imageAnalysis ->
                                    imageAnalysis.setAnalyzer(analyzerExecutor) { imageProxy ->
                                        val detector = detectorResult.getOrNull()
                                        if (detector == null) {
                                            if (modelErrorReported.compareAndSet(false, true)) {
                                                scope.launch {
                                                    currentOnStatusChange("Model error")
                                                    currentOnLog("Model unavailable")
                                                }
                                            }
                                            imageProxy.close()
                                            return@setAnalyzer
                                        }

                                        if (!processing.compareAndSet(false, true)) {
                                            imageProxy.close()
                                            return@setAnalyzer
                                        }

                                        val bitmap = runCatching { imageProxy.toUprightBitmap() }
                                            .also { imageProxy.close() }
                                            .getOrElse {
                                                processing.set(false)
                                                scope.launch {
                                                    detectedBoundingBox = null
                                                    currentOnStatusChange("Frame error")
                                                    currentOnLog("Frame conversion failed")
                                                }
                                                return@setAnalyzer
                                            }

                                        scope.launch {
                                            runCatching {
                                                val detection = detector.detect(bitmap)
                                                val now = System.currentTimeMillis()
                                                if (detection == null) {
                                                    if (now - lastDetectedAtMillis.get() > DETECTION_BOX_HOLD_MS) {
                                                        detectedBoundingBox = null
                                                    }
                                                    return@runCatching "Scanning"
                                                }

                                                detectedBoundingBox = detection.boundingBox
                                                lastDetectedAtMillis.set(now)
                                                if (now - lastDetectionLogAtMillis.get() >= DETECTION_LOG_COOLDOWN_MS) {
                                                    lastDetectionLogAtMillis.set(now)
                                                    currentOnLog("Pothole ${(detection.confidence * 100).toInt()}%")
                                                }
                                                if (now - lastSavedAtMillis.get() < DETECTION_SAVE_COOLDOWN_MS) {
                                                    return@runCatching "Detected"
                                                }

                                                lastSavedAtMillis.set(now)
                                                scope.launch {
                                                    delay(ACCELEROMETER_POST_DETECTION_CAPTURE_DELAY_MS)
                                                    val location = withContext(Dispatchers.IO) { locationProvider.currentLocation() }
                                                    if (location == null) {
                                                        currentOnStatusChange("Location needed")
                                                        currentOnLog("Location unavailable")
                                                        return@launch
                                                    }

                                                    runCatching {
                                                        withContext(Dispatchers.IO) {
                                                            repository.saveDetection(
                                                                bitmap = bitmap,
                                                                detection = detection,
                                                                latitude = location.latitude,
                                                                longitude = location.longitude,
                                                                heading = location.heading,
                                                                speed = location.speed,
                                                                accelerometerSnapshot = accelerometerMonitor.snapshot(),
                                                            )
                                                        }
                                                    }.onSuccess {
                                                        currentOnStatusChange("Queued")
                                                        currentOnLog("Queued upload candidate")
                                                    }.onFailure { error ->
                                                        currentOnLog("Queue failed: ${error.javaClass.simpleName}")
                                                    }
                                                }
                                                "Detected"
                                            }.onSuccess { status ->
                                                currentOnStatusChange(status)
                                            }.onFailure { error ->
                                                detectedBoundingBox = null
                                                currentOnStatusChange("Detection error")
                                                currentOnLog("Detection failed: ${error.javaClass.simpleName}")
                                            }
                                            processing.set(false)
                                        }
                                    }
                                }
                            cameraProvider.unbindAll()
                            cameraProvider.bindToLifecycle(
                                lifecycleOwner,
                                CameraSelector.DEFAULT_BACK_CAMERA,
                                preview,
                                analysis,
                            )
                        },
                        ContextCompat.getMainExecutor(context),
                    )
                }
            },
        )
        DetectionBoxOverlay(boundingBox = detectedBoundingBox, modifier = Modifier.fillMaxSize())
        AccelerometerOverlay(
            state = accelerometerState,
            modifier = Modifier
                .align(Alignment.TopStart)
                .padding(12.dp),
        )
    }
}

private const val DETECTION_SAVE_COOLDOWN_MS = 5_000L
private const val ACCELEROMETER_POST_DETECTION_CAPTURE_DELAY_MS = 900L
private const val DETECTION_BOX_HOLD_MS = 750L
private const val DETECTION_LOG_COOLDOWN_MS = 1_000L
private const val MAX_SCANNER_LOG_LINES = 6
private val ANALYSIS_RESOLUTION_SELECTOR = ResolutionSelector.Builder()
    .setResolutionStrategy(
        ResolutionStrategy(
            AndroidSize(640, 480),
            ResolutionStrategy.FALLBACK_RULE_CLOSEST_HIGHER_THEN_LOWER,
        )
    )
    .build()

@Composable
private fun AccelerometerOverlay(
    state: AccelerometerDisplayState,
    modifier: Modifier = Modifier,
) {
    val magnitudes = state.recentMagnitudes
    val peak = state.peakMagnitude.coerceAtLeast(1f)

    Column(
        modifier = modifier
            .width(190.dp)
            .background(Color(0x660B1220), RoundedCornerShape(6.dp))
            .border(BorderStroke(1.dp, Color(0x55FFFFFF)), RoundedCornerShape(6.dp))
            .padding(8.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Text(
            text = if (state.available) state.sensorType else "No accelerometer",
            color = Color.White,
            style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.SemiBold,
        )
        Text(
            text = "X ${state.x.sensorValue()}  Y ${state.y.sensorValue()}  Z ${state.z.sensorValue()}",
            color = Color(0xFFE2E8F0),
            style = MaterialTheme.typography.labelSmall,
        )
        Text(
            text = "Magnitude ${state.magnitude.sensorValue()}  Peak ${state.peakMagnitude.sensorValue()}",
            color = Color(0xFFE2E8F0),
            style = MaterialTheme.typography.labelSmall,
        )
        Canvas(
            modifier = Modifier
                .fillMaxWidth()
                .height(36.dp),
        ) {
            if (magnitudes.size < 2) return@Canvas

            val step = size.width / (magnitudes.size - 1)
            magnitudes.zipWithNext().forEachIndexed { index, (previous, current) ->
                drawLine(
                    color = Color(0xFF38BDF8),
                    start = Offset(index * step, size.height - ((previous / peak).coerceIn(0f, 1f) * size.height)),
                    end = Offset((index + 1) * step, size.height - ((current / peak).coerceIn(0f, 1f) * size.height)),
                    strokeWidth = 2.dp.toPx(),
                )
            }
        }
    }
}

@Composable
private fun DetectionBoxOverlay(
    boundingBox: BoundingBox?,
    modifier: Modifier = Modifier,
) {
    if (boundingBox == null) return

    Canvas(modifier = modifier) {
        val left = boundingBox.left * size.width
        val top = boundingBox.top * size.height
        val right = boundingBox.right * size.width
        val bottom = boundingBox.bottom * size.height

        drawRect(
            color = Color(0x3322C55E),
            topLeft = Offset(left, top),
            size = Size(right - left, bottom - top),
        )
        drawRect(
            color = Color(0xFF22C55E),
            topLeft = Offset(left, top),
            size = Size(right - left, bottom - top),
            style = Stroke(width = 3.dp.toPx()),
        )
    }
}

private fun ImageProxy.toUprightBitmap(): Bitmap {
    val bitmap = toBitmap()
    val rotationDegrees = imageInfo.rotationDegrees
    if (rotationDegrees == 0) return bitmap

    val matrix = Matrix().apply { postRotate(rotationDegrees.toFloat()) }
    return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
}

private fun Float.sensorValue(): String = String.format(Locale.US, "%.1f", this)

@androidx.annotation.OptIn(ExperimentalGetImage::class)
@Composable
fun QrScannerPreview(
    onQrScanned: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val currentOnQrScanned by rememberUpdatedState(onQrScanned)

    AndroidView(
        modifier = modifier,
        factory = { viewContext ->
            PreviewView(viewContext).also { previewView ->
                val cameraProviderFuture = ProcessCameraProvider.getInstance(viewContext)
                cameraProviderFuture.addListener(
                    {
                        val cameraProvider = cameraProviderFuture.get()
                        val scanner = BarcodeScanning.getClient(
                            BarcodeScannerOptions.Builder()
                                .setBarcodeFormats(Barcode.FORMAT_QR_CODE)
                                .build()
                        )
                        val processing = AtomicBoolean(false)
                        val preview = CameraXPreview.Builder().build().also {
                            it.surfaceProvider = previewView.surfaceProvider
                        }
                        val analysis = ImageAnalysis.Builder()
                            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                            .build()
                            .also { imageAnalysis ->
                                imageAnalysis.setAnalyzer(ContextCompat.getMainExecutor(viewContext)) { imageProxy ->
                                    if (!processing.compareAndSet(false, true)) {
                                        imageProxy.close()
                                        return@setAnalyzer
                                    }

                                    val mediaImage = imageProxy.image
                                    if (mediaImage == null) {
                                        processing.set(false)
                                        imageProxy.close()
                                        return@setAnalyzer
                                    }

                                    val image = InputImage.fromMediaImage(
                                        mediaImage,
                                        imageProxy.imageInfo.rotationDegrees,
                                    )
                                    scanner.process(image)
                                        .addOnSuccessListener { barcodes ->
                                            barcodes.firstNotNullOfOrNull { it.rawValue }?.let(currentOnQrScanned)
                                        }
                                        .addOnCompleteListener {
                                            processing.set(false)
                                            imageProxy.close()
                                        }
                                }
                            }

                        cameraProvider.unbindAll()
                        cameraProvider.bindToLifecycle(
                            lifecycleOwner,
                            CameraSelector.DEFAULT_BACK_CAMERA,
                            preview,
                            analysis,
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
fun QrScannerPlaceholder(modifier: Modifier = Modifier) {
    Box(
        modifier = modifier.background(Color(0xFF101828)),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text("QR scanner", color = Color.White, style = MaterialTheme.typography.titleMedium)
            Text("Preview mode", color = Color(0xFFCBD5E1), style = MaterialTheme.typography.bodySmall)
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

@Preview(name = "PotDroid - Unpaired", showBackground = true)
@Composable
private fun PotDroidUnpairedPreview() {
    PotDroidTheme {
        Surface(modifier = Modifier.fillMaxSize()) {
            PotDroidScreen(
                apiBaseUrl = "https://example.trycloudflare.com/",
                apiToken = "",
                pairingInput = "potdroid://pair?u=https%3A%2F%2Fexample.trycloudflare.com&c=ABCD-EFGH-JK23",
                pairingStatus = null,
                connectivityStatus = "Connection OK",
                scanningStatus = "Model ready",
                scannerLog = emptyList(),
                hasCameraPermission = true,
                driveStarted = false,
                onApiBaseUrlChange = {},
                onApiTokenChange = {},
                onPairingInputChange = {},
                onSave = {},
                onPair = {},
                onQrScanned = {},
                onTestConnection = {},
                onUnpair = {},
                onStartDrive = {},
                onStopDrive = {},
                onRequestPermissions = {},
            )
        }
    }
}

@Preview(name = "PotDroid - Driving", showBackground = true)
@Composable
private fun PotDroidDrivingPreview() {
    PotDroidTheme {
        Surface(modifier = Modifier.fillMaxSize()) {
            PotDroidScreen(
                apiBaseUrl = "https://example.trycloudflare.com/",
                apiToken = "pd_preview_token",
                pairingInput = "",
                pairingStatus = "Paired. Long-lived token saved.",
                connectivityStatus = null,
                scanningStatus = "Model ready",
                scannerLog = listOf("Model loaded", "Scanning"),
                hasCameraPermission = true,
                driveStarted = true,
                onApiBaseUrlChange = {},
                onApiTokenChange = {},
                onPairingInputChange = {},
                onSave = {},
                onPair = {},
                onQrScanned = {},
                onTestConnection = {},
                onUnpair = {},
                onStartDrive = {},
                onStopDrive = {},
                onRequestPermissions = {},
            )
        }
    }
}
