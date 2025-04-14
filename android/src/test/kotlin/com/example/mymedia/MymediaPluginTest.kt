package com.example.mymedia

import android.content.Context
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.test.Test
import org.mockito.Mockito
import org.mockito.Mockito.mock

/*
 * This demonstrates a simple unit test of the Kotlin portion of this plugin's implementation.
 *
 * Once you have built the plugin's example app, you can run these tests from the command
 * line by running `./gradlew testDebugUnitTest` in the `example/android/` directory, or
 * you can run them directly from IDEs that support JUnit such as Android Studio.
 */

internal class MymediaPluginTest {
  private val mockContext: Context = mock(Context::class.java)

  @Test
  fun onMethodCall_getPlatformVersion_returnsExpectedValue() {
    val plugin = MymediaPlugin()
    plugin.onAttachedToEngine(mockContext, mock(MethodChannel::class.java), mock(io.flutter.plugin.common.EventChannel::class.java))

    val call = MethodCall("getPlatformVersion", null)
    val mockResult: MethodChannel.Result = mock(MethodChannel.Result::class.java)
    plugin.onMethodCall(call, mockResult)

    Mockito.verify(mockResult).success("Android " + android.os.Build.VERSION.RELEASE)
  }

  @Test
  fun onMethodCall_invalidMethod_callsNotImplemented() {
    val plugin = MymediaPlugin()
    plugin.onAttachedToEngine(mockContext, mock(MethodChannel::class.java), mock(io.flutter.plugin.common.EventChannel::class.java))

    val call = MethodCall("invalidMethod", null)
    val mockResult: MethodChannel.Result = mock(MethodChannel.Result::class.java)
    plugin.onMethodCall(call, mockResult)

    Mockito.verify(mockResult).notImplemented()
  }
}
