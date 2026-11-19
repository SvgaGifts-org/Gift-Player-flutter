package com.svgagifts.gift_player_flutter

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.mockito.Mockito
import kotlin.test.Test

/*
 * JVM unit test of the dispatcher. The libpag calls themselves need a device (native library, GL), so they are covered by the
 * example app's integration test; here we check the parts that do not.
 *
 * Run: `./gradlew testDebugUnitTest` in `example/android/`.
 */
internal class GiftPlayerFlutterPluginTest {
    @Test
    fun unknownMethod_isNotImplemented() {
        val plugin = GiftPlayerFlutterPlugin()
        val result: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(MethodCall("definitelyNotAMethod", null), result)
        Mockito.verify(result).notImplemented()
    }

    @Test
    fun disposeOfUnknownInstance_succeedsQuietly() {
        val plugin = GiftPlayerFlutterPlugin()
        val result: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(MethodCall("pagDispose", mapOf("id" to 12345)), result)
        Mockito.verify(result).success(null)
    }

    @Test
    fun calls_beforeAttach_reportEngineUnavailable() {
        val plugin = GiftPlayerFlutterPlugin()
        val result: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(MethodCall("pagInit", null), result)
        Mockito.verify(result).error(
            Mockito.eq("engine-load-failed"),
            Mockito.anyString(),
            Mockito.isNull(),
        )
    }
}
