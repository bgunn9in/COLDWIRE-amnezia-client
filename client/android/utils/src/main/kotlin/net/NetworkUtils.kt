package org.amnezia.vpn.util.net

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import androidx.core.content.getSystemService
import java.net.Inet4Address
import java.net.Inet6Address
import java.net.InetAddress

fun getLocalNetworks(context: Context, ipv6: Boolean): List<InetNetwork> {
    val connectivityManager = context.getSystemService<ConnectivityManager>()!!
    connectivityManager.activeNetwork?.let { network ->
        val netCapabilities = connectivityManager.getNetworkCapabilities(network)
        val linkProperties = connectivityManager.getLinkProperties(network)
        if (linkProperties == null ||
            netCapabilities == null ||
            netCapabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN) ||
            netCapabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)
        ) return emptyList()

        val addresses = mutableListOf<InetNetwork>()

        for (linkAddress in linkProperties.linkAddresses) {
            val address = linkAddress.address
            if ((!ipv6 && address is Inet4Address) || (ipv6 && address is Inet6Address)) {
                addresses += InetNetwork(address, linkAddress.prefixLength)
            }
        }
        return addresses
    }
    return emptyList()
}

fun parseInetAddress(address: String): InetAddress = InetAddress.getByName(address)

internal fun convertIpv6ToCanonicalForm(ipv6: String): String = ipv6
    .replace("((?:(?:^|:)0+\\b){2,}):?(?!\\S*\\b\\1:0+\\b)(\\S*)".toRegex(), "::$2")

val InetAddress.ip: String
    get() = if (this is Inet4Address) {
        hostAddress!!
    } else {
        convertIpv6ToCanonicalForm(hostAddress!!)
    }
