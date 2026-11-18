package com.vaclav.wargusport;

import java.io.BufferedInputStream;
import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageInfo;
import android.graphics.Color;
import android.os.Bundle;
import android.os.StatFs;
import android.util.TypedValue;
import android.view.Gravity;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.TextView;

// The app's entry point. The offline build carries the game data inside the
// APK as assets/data.zip; on its first launch after an install or update this
// unpacks it into the folder the game reads, then starts the game. The normal
// build has no data.zip and goes straight to the game.
public class SetupActivity extends Activity {

    private static final String DATA_ZIP = "data.zip";
    private static final String DATA_SIZE = "data.size";
    private static final String STAMP = ".wardroid-unpacked";
    private static final long SPARE_BYTES = 50L * 1024 * 1024;

    private TextView message;
    private ProgressBar progress;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        long total = bundledDataSize();
        File data = new File(getExternalFilesDir(null), "data.Wargus");
        String stamp = installStamp();
        if (total < 0 || stamp.equals(readStamp(data))) {
            startGame();
            return;
        }

        showSetupScreen();
        long free = new StatFs(getExternalFilesDir(null).getPath()).getAvailableBytes();
        if (free < total + SPARE_BYTES) {
            showError("Not enough free space. WarDroid needs " + megabytes(total + SPARE_BYTES)
                + " MB free, and this phone has " + megabytes(free)
                + " MB. Free up some space, then open WarDroid again.");
            return;
        }

        new Thread(() -> {
            try {
                unpack(data, total, stamp);
                runOnUiThread(this::startGame);
            } catch (IOException e) {
                runOnUiThread(() -> showError("Setting up the game data failed: " + e.getMessage()
                    + "\n\nOpen WarDroid again to retry."));
            }
        }).start();
    }

    @Override
    public void onBackPressed() {
        // Leaving mid-unpack is harmless, it restarts next time, but stay put.
    }

    private void startGame() {
        startActivity(new Intent(this, GameActivity.class));
        finish();
    }

    // The unpacked size the build recorded next to data.zip, or -1 if this
    // APK carries no data.
    private long bundledDataSize() {
        try (BufferedReader r = new BufferedReader(new InputStreamReader(getAssets().open(DATA_SIZE)))) {
            return Long.parseLong(r.readLine().trim());
        } catch (IOException | NumberFormatException | NullPointerException e) {
            return -1;
        }
    }

    // Changes with every install or update, so new data in an update is
    // unpacked again.
    private String installStamp() {
        try {
            PackageInfo info = getPackageManager().getPackageInfo(getPackageName(), 0);
            return info.versionName + "/" + info.lastUpdateTime;
        } catch (Exception e) {
            return "unknown";
        }
    }

    private static String readStamp(File data) {
        File f = new File(data, STAMP);
        try (BufferedReader r = new BufferedReader(new InputStreamReader(new FileInputStream(f)))) {
            return r.readLine();
        } catch (IOException e) {
            return null;
        }
    }

    // Unpacks into a temporary folder and swaps it in at the end, so an
    // interrupted unpack never leaves half the data in place.
    private void unpack(File data, long total, String stamp) throws IOException {
        File parent = data.getParentFile();
        File tmp = new File(parent, "data.Wargus.unpacking");
        deleteTree(tmp);
        if (!tmp.mkdirs()) {
            throw new IOException("cannot create " + tmp);
        }

        String root = tmp.getCanonicalPath() + File.separator;
        byte[] buffer = new byte[256 * 1024];
        long done = 0;
        int lastPercent = -1;
        try (ZipInputStream zip = new ZipInputStream(new BufferedInputStream(getAssets().open(DATA_ZIP), 256 * 1024))) {
            ZipEntry entry;
            while ((entry = zip.getNextEntry()) != null) {
                File out = new File(tmp, entry.getName());
                if (!out.getCanonicalPath().startsWith(root)) {
                    throw new IOException("bad entry " + entry.getName());
                }
                if (entry.isDirectory()) {
                    out.mkdirs();
                    continue;
                }
                out.getParentFile().mkdirs();
                try (OutputStream os = new FileOutputStream(out)) {
                    int n;
                    while ((n = zip.read(buffer)) > 0) {
                        os.write(buffer, 0, n);
                        done += n;
                        int percent = (int) Math.min(100, done * 100 / Math.max(1, total));
                        if (percent != lastPercent) {
                            lastPercent = percent;
                            runOnUiThread(() -> showProgress(percent));
                        }
                    }
                }
            }
        }

        try (OutputStream os = new FileOutputStream(new File(tmp, STAMP))) {
            os.write((stamp + "\n").getBytes("UTF-8"));
        }
        deleteTree(data);
        if (!tmp.renameTo(data)) {
            throw new IOException("cannot move the data into place");
        }
    }

    private static void deleteTree(File f) {
        File[] children = f.listFiles();
        if (children != null) {
            for (File c : children) {
                deleteTree(c);
            }
        }
        f.delete();
    }

    private static long megabytes(long bytes) {
        return (bytes + 1024 * 1024 - 1) / (1024 * 1024);
    }

    private void showSetupScreen() {
        LinearLayout layout = new LinearLayout(this);
        layout.setOrientation(LinearLayout.VERTICAL);
        layout.setGravity(Gravity.CENTER);
        layout.setBackgroundColor(Color.rgb(24, 16, 8));
        int pad = dp(48);
        layout.setPadding(pad, pad, pad, pad);

        TextView title = new TextView(this);
        title.setText("WarDroid");
        title.setTextColor(Color.rgb(255, 214, 0));
        title.setTextSize(TypedValue.COMPLEX_UNIT_SP, 32);
        title.setGravity(Gravity.CENTER);
        layout.addView(title);

        message = new TextView(this);
        message.setText("Setting up the game data. This happens only once and takes about a minute.");
        message.setTextColor(Color.WHITE);
        message.setTextSize(TypedValue.COMPLEX_UNIT_SP, 18);
        message.setGravity(Gravity.CENTER);
        message.setPadding(0, dp(16), 0, dp(16));
        layout.addView(message);

        progress = new ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal);
        progress.setMax(100);
        layout.addView(progress, new LinearLayout.LayoutParams(dp(420), dp(24)));

        setContentView(layout);
    }

    private void showProgress(int percent) {
        progress.setProgress(percent);
        message.setText("Setting up the game data: " + percent + "%\nThis happens only once.");
    }

    private void showError(String text) {
        progress.setVisibility(ProgressBar.GONE);
        message.setText(text);
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }
}
