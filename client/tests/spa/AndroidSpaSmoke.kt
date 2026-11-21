package org.amnezia.vpn

import java.io.File
import org.json.JSONObject
import kotlin.system.exitProcess

fun main(args: Array<String>) {
    val port = args[1].toInt()
    val profile = JSONObject().put("hostName", args[0]).put("port", if (port == 32497) 32498 else 32497)
    check(SpaAdmission.fromAwgConfig(profile) == null)
    profile.put("coldwireSpa", JSONObject().put("version", 1)
        .put("key", File(args[2]).readText().trim()).put("port", port))
    val admission = checkNotNull(SpaAdmission.fromAwgConfig(profile))
    check(!admission.authorize { false })
    exitProcess(if (admission.authorize { true }) 0 else 2)
}
