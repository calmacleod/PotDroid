package com.potdroid.android

import android.Manifest
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.viewinterop.AndroidView
import com.potdroid.android.data.DebugSettings

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme {
                Surface(modifier = Modifier.fillMaxSize()) {
                    PotDroidApp()
                }
            }
        }
    }
}

@Composable
fun PotDroidApp() {
    val context = LocalContext.current
    val settings = remember { DebugSettings(context) }
    var apiBaseUrl by remember { mutableStateOf(settings.apiBaseUrl) }
    var apiToken by remember { mutableStateOf(settings.apiToken) }
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
        hasCameraPermission = hasCameraPermission,
        onApiBaseUrlChange = { apiBaseUrl = it },
        onApiTokenChange = { apiToken = it },
        onSave = {
            settings.apiBaseUrl = apiBaseUrl
            settings.apiToken = apiToken
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
    hasCameraPermission: Boolean,
    onApiBaseUrlChange: (String) -> Unit,
    onApiTokenChange: (String) -> Unit,
    onSave: () -> Unit,
    onRequestPermissions: () -> Unit,
    modifier: Modifier = Modifier,
    cameraContent: @Composable (Modifier) -> Unit = { cameraModifier ->
        CameraPreviewPlaceholder(modifier = cameraModifier)
    },
) {
    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text("PotDroid", style = MaterialTheme.typography.headlineMedium)
        Text("Mount the phone facing forward. Candidate detections are queued locally and uploaded to the Rails API.")

        if (hasCameraPermission) {
            cameraContent(Modifier.weight(1f).fillMaxWidth())
        } else {
            Text("Camera permission is required for road scanning.")
        }

        OutlinedTextField(
            value = apiBaseUrl,
            onValueChange = onApiBaseUrlChange,
            label = { Text("API base URL") },
            modifier = Modifier.fillMaxWidth(),
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri),
        )
        OutlinedTextField(
            value = apiToken,
            onValueChange = onApiTokenChange,
            label = { Text("API token") },
            modifier = Modifier.fillMaxWidth(),
            visualTransformation = PasswordVisualTransformation(),
        )
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Button(
                onClick = onSave,
            ) {
                Text("Save")
            }
            Button(onClick = onRequestPermissions) {
                Text("Permissions")
            }
        }
        Spacer(modifier = Modifier.height(4.dp))
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
            .background(Color(0xFF111827), RoundedCornerShape(8.dp))
            .border(1.dp, Color(0xFF374151), RoundedCornerShape(8.dp)),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = "Camera preview",
            color = Color.White,
            style = MaterialTheme.typography.titleMedium,
        )
    }
}

@Preview(name = "PotDroid - Ready", showBackground = true)
@Composable
private fun PotDroidReadyPreview() {
    MaterialTheme {
        Surface(modifier = Modifier.fillMaxSize()) {
            PotDroidScreen(
                apiBaseUrl = "https://example.trycloudflare.com/",
                apiToken = "pd_preview_token",
                hasCameraPermission = true,
                onApiBaseUrlChange = {},
                onApiTokenChange = {},
                onSave = {},
                onRequestPermissions = {},
            )
        }
    }
}

@Preview(name = "PotDroid - Permissions Needed", showBackground = true)
@Composable
private fun PotDroidPermissionsPreview() {
    MaterialTheme {
        Surface(modifier = Modifier.fillMaxSize()) {
            PotDroidScreen(
                apiBaseUrl = "https://example.trycloudflare.com/",
                apiToken = "",
                hasCameraPermission = false,
                onApiBaseUrlChange = {},
                onApiTokenChange = {},
                onSave = {},
                onRequestPermissions = {},
            )
        }
    }
}
