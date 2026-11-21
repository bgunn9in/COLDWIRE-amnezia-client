package org.amnezia.vpn

import java.io.IOException
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.nio.ByteBuffer
import java.security.MessageDigest
import java.security.SecureRandom
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.delay
import kotlinx.coroutines.ensureActive
import org.json.JSONObject

private const val BODY_SIZE = 72
private const val FRAME_SIZE = 104

internal class SpaAdmission private constructor(
    private val host: InetAddress,
    private val port: Int,
    private val key: ByteArray
) {
    fun authorize(protect: (DatagramSocket) -> Boolean): Boolean {
        return try {
            DatagramSocket().use { socket ->
                if (!protect(socket)) return false
                socket.connect(host, port)
                socket.soTimeout = 2000

                val nonce = ByteArray(16).also(random::nextBytes)
                val id = MessageDigest.getInstance("SHA-256").digest(key).copyOf(8)
                val discover = ByteBuffer.allocate(BODY_SIZE)
                    .put("CWQ1".toByteArray(Charsets.US_ASCII))
                    .put(id)
                    .putLong(System.currentTimeMillis() / 1000)
                    .put(nonce)
                    .array()
                socket.send(sign(discover).let { DatagramPacket(it, it.size) })

                val response = DatagramPacket(ByteArray(FRAME_SIZE + 1), FRAME_SIZE + 1)
                socket.receive(response)
                if (response.length != FRAME_SIZE) return false
                val challenge = response.data.copyOf(BODY_SIZE)
                if (String(challenge, 0, 4, Charsets.US_ASCII) != "CWC1" ||
                    !challenge.copyOfRange(4, 12).contentEquals(id) ||
                    !challenge.copyOfRange(20, 36).contentEquals(nonce) ||
                    !MessageDigest.isEqual(sign(challenge), response.data.copyOf(FRAME_SIZE))
                ) return false

                "CWA1".toByteArray(Charsets.US_ASCII).copyInto(challenge)
                socket.send(sign(challenge).let { DatagramPacket(it, it.size) })
                response.length = response.data.size
                socket.receive(response)
                "CWO1".toByteArray(Charsets.US_ASCII).copyInto(challenge)
                response.length == FRAME_SIZE &&
                    MessageDigest.isEqual(sign(challenge), response.data.copyOf(FRAME_SIZE))
            }
        } catch (_: IOException) {
            false
        }
    }

    suspend fun renew(protect: (DatagramSocket) -> Boolean, confirmed: Boolean, active: () -> Boolean) {
        var granted = confirmed
        while (active()) {
            delay(if (granted) 40_000L else 3_000L)
            currentCoroutineContext().ensureActive()
            if (!active()) return
            granted = authorize(protect)
        }
    }

    private fun sign(body: ByteArray): ByteArray {
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(SecretKeySpec(key, "HmacSHA256"))
        return body + mac.doFinal(body)
    }

    companion object {
        private val random = SecureRandom()
        private val hexKey = Regex("[0-9a-fA-F]{64}")
        private val ipv4 = Regex("[0-9]{1,3}(\\.[0-9]{1,3}){3}")

        fun fromAwgConfig(config: JSONObject): SpaAdmission? {
            if (!config.has("coldwireSpa")) return null
            val marker = config.optJSONObject("coldwireSpa")
            val host = config.optString("hostName")
            val port = marker?.opt("port") as? Int ?: 0
            val key = marker?.optString("key").orEmpty()
            require(marker?.opt("version") == 1 && port in 1..65535 &&
                port != config.optInt("port") && hexKey.matches(key) && ipv4.matches(host)
            ) { "Invalid SPA profile" }
            val octets = host.split('.').map(String::toInt)
            require(octets.all { it in 0..255 }) { "Invalid SPA endpoint IPv4" }
            return SpaAdmission(InetAddress.getByAddress(octets.map(Int::toByte).toByteArray()), port,
                ByteArray(32) { key.substring(it * 2, it * 2 + 2).toInt(16).toByte() })
        }
    }
}
