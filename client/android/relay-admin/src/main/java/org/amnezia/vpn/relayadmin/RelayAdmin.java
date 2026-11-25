package org.amnezia.vpn.relayadmin;

import android.content.Context;

import com.chaquo.python.Python;
import com.chaquo.python.android.AndroidPlatform;

public final class RelayAdmin {
    private RelayAdmin() {}

    public static synchronized String run(Context context, String request, String statePath) {
        try {
            if (!Python.isStarted()) {
                Python.start(new AndroidPlatform(context.getApplicationContext()));
            }
            return Python.getInstance().getModule("coldwire_admin_bundle")
                .callAttr("invoke", request, statePath).toJava(String.class);
        } catch (RuntimeException | LinkageError error) {
            return "{\"ok\":false}";
        }
    }
}
