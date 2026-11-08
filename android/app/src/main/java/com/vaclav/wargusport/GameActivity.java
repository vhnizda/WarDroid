package com.vaclav.wargusport;

import java.io.File;

import org.libsdl.app.SDLActivity;

public class GameActivity extends SDLActivity {

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
