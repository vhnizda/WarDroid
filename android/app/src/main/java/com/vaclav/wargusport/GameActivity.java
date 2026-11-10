package com.vaclav.wargusport;

import java.io.File;

import android.content.Context;
import android.net.wifi.WifiManager;
import android.os.Bundle;

import org.libsdl.app.SDLActivity;

public class GameActivity extends SDLActivity {

    // Wi-Fi drivers drop multicast and broadcast packets to save power unless
    // an app holds this lock. LAN game discovery needs them.
    private WifiManager.MulticastLock multicastLock;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        WifiManager wifi = (WifiManager) getApplicationContext().getSystemService(Context.WIFI_SERVICE);
        if (wifi != null) {
            multicastLock = wifi.createMulticastLock("WarDroid LAN discovery");
            multicastLock.setReferenceCounted(false);
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (multicastLock != null) {
            multicastLock.acquire();
        }
    }

    @Override
    protected void onPause() {
        // Release while in the background so the phone's Wi-Fi can sleep.
        if (multicastLock != null) {
            multicastLock.release();
        }
        super.onPause();
    }

    @Override
    protected String[] getLibraries() {
        // SDL is linked statically into libmain.so.
        return new String[] { "main" };
    }

    @Override
    protected String[] getArguments() {
        // The player copies data.Wargus here, for example with adb push.
        // No storage permission is needed for the app's own external directory.
        File data = new File(getExternalFilesDir(null), "data.Wargus");
        return new String[] {
            "-d", data.getAbsolutePath(),
            "-u", getFilesDir().getAbsolutePath(),
            "-F"
        };
    }
}
