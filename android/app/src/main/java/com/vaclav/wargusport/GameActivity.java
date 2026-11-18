package com.vaclav.wargusport;

import java.io.File;

import android.content.Context;
import android.net.wifi.WifiManager;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;

import org.libsdl.app.SDLActivity;

public class GameActivity extends SDLActivity {

    // Wi-Fi drivers drop multicast and broadcast packets to save power unless
    // an app holds this lock. LAN game discovery needs them.
    private WifiManager.MulticastLock multicastLock;

    // At startup the surface first leaves room for the status and navigation
    // bars, then grows to the full screen as they hide. If it grows while the
    // game is still creating its window, SDL drops that resize, and the game
    // keeps drawing at the smaller size in the top left corner. So shortly
    // after the game gets focus, SDL resends the surface's size; a size that
    // hasn't changed is ignored.
    private static final long[] RESIZE_RESEND_MS = { 300, 1000, 2500 };
    private final Handler resizeHandler = new Handler(Looper.getMainLooper());
    private final Runnable resendSize = () -> {
        if (!SDLActivity.mBrokenLibraries) {
            SDLActivity.onNativeResize();
        }
    };

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        resizeHandler.removeCallbacks(resendSize);
        if (hasFocus) {
            for (long delay : RESIZE_RESEND_MS) {
                resizeHandler.postDelayed(resendSize, delay);
            }
        }
    }

    @Override
    protected void onDestroy() {
        resizeHandler.removeCallbacks(resendSize);
        super.onDestroy();
    }

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
