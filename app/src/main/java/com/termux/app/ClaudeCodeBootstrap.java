package com.termux.app;

import android.app.Activity;
import android.app.ProgressDialog;
import android.content.Context;
import android.os.Handler;
import android.os.Looper;

import com.termux.shared.logger.Logger;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;

/**
 * Post-bootstrap hook that sets up the Claude Code Android environment
 * after the Termux base bootstrap completes.
 *
 * Runs bootstrap.sh from APK assets, which installs Node.js, Claude Code CLI,
 * tmux, code-server, and all configuration files.
 */
public final class ClaudeCodeBootstrap {

    private static final String LOG_TAG = "ClaudeCodeBootstrap";
    private static final String BOOTSTRAP_MARKER = ".claude-code-bootstrap-done";
    private static final String BOOTSTRAP_DIR = "claude_code_bootstrap";

    private ClaudeCodeBootstrap() {}

    /**
     * Run post-bootstrap setup if this is the first launch.
     *
     * @param activity  The hosting Activity (for UI thread access)
     * @param homeDir   Termux home directory
     */
    public static void runIfNeeded(final Activity activity, final File homeDir) {
        final File markerFile = new File(homeDir, BOOTSTRAP_MARKER);

        if (markerFile.exists()) {
            Logger.logInfo(LOG_TAG, "Claude Code bootstrap already completed. Skipping.");
            return;
        }

        Logger.logInfo(LOG_TAG, "First launch detected. Starting Claude Code bootstrap...");

        final File stagingDir = new File(homeDir, ".claude-code-staging");
        if (!stagingDir.exists()) {
            stagingDir.mkdirs();
        }

        try {
            copyAssets(activity, BOOTSTRAP_DIR, stagingDir);
        } catch (IOException e) {
            Logger.logError(LOG_TAG, "Failed to copy bootstrap assets: " + e.getMessage());
            return;
        }

        final ProgressDialog progress = new ProgressDialog(activity);
        progress.setTitle("Claude Code Setup");
        progress.setMessage("Installing packages... (may take 5-10 minutes on first run)");
        progress.setCancelable(false);
        progress.show();

        new Thread(() -> {
            try {
                runBootstrapScript(stagingDir, homeDir);
            } catch (Exception e) {
                Logger.logError(LOG_TAG, "Bootstrap script failed: " + e.getMessage());
            }

            try {
                markerFile.createNewFile();
            } catch (IOException ignored) {}

            deleteRecursive(stagingDir);

            new Handler(Looper.getMainLooper()).post(progress::dismiss);
        }).start();
    }

    private static void copyAssets(Context context, String assetPath, File destDir) throws IOException {
        String[] files = context.getAssets().list(assetPath);
        if (files == null) return;

        for (String filename : files) {
            File outFile = new File(destDir, filename);
            try (InputStream in = context.getAssets().open(assetPath + "/" + filename);
                 FileOutputStream out = new FileOutputStream(outFile)) {
                byte[] buf = new byte[8192];
                int len;
                while ((len = in.read(buf)) > 0) {
                    out.write(buf, 0, len);
                }
            }
            if (filename.endsWith(".sh") || !filename.contains(".")) {
                outFile.setExecutable(true);
            }
        }
    }

    private static void runBootstrapScript(File stagingDir, File homeDir) throws IOException, InterruptedException {
        File bootstrapScript = new File(stagingDir, "bootstrap.sh");
        if (!bootstrapScript.exists()) {
            Logger.logError(LOG_TAG, "bootstrap.sh not found in staging directory");
            return;
        }

        ProcessBuilder pb = new ProcessBuilder(
            "/data/data/com.termux/files/usr/bin/bash",
            bootstrapScript.getAbsolutePath()
        );
        pb.directory(homeDir);
        pb.environment().put("HOME", homeDir.getAbsolutePath());
        pb.environment().put("PATH",
            "/data/data/com.termux/files/usr/bin:" +
            "/data/data/com.termux/files/usr/bin/applets");
        pb.redirectErrorStream(true);

        Process process = pb.start();
        try (BufferedReader reader = new BufferedReader(
                new InputStreamReader(process.getInputStream()))) {
            String line;
            while ((line = reader.readLine()) != null) {
                Logger.logInfo(LOG_TAG, "[bootstrap] " + line);
            }
        }

        int exitCode = process.waitFor();
        if (exitCode != 0) {
            Logger.logError(LOG_TAG, "bootstrap.sh exited with code " + exitCode);
        }
    }

    private static void deleteRecursive(File file) {
        if (file.isDirectory()) {
            File[] children = file.listFiles();
            if (children != null) {
                for (File child : children) {
                    deleteRecursive(child);
                }
            }
        }
        file.delete();
    }
}
