package com.tokyonasu.tekkyakudraft;

import android.app.Activity;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.graphics.Typeface;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.view.Gravity;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.Locale;

public class MainActivity extends Activity {
    private static final String DATA_URL = "https://raw.githubusercontent.com/snarfnet/KeirinPredictor/main/generated/tekkyaku/latest.json";
    private static final int NAVY = 0xFF07101A;
    private static final int NAVY_2 = 0xFF0E1721;
    private static final int GOLD = 0xFFC99A2E;
    private static final int PAPER = 0xFFF6E8C8;
    private static final int RED = 0xFF9F2119;
    private static final int GREEN = 0xFF2F9F64;

    private final Handler main = new Handler(Looper.getMainLooper());
    private LinearLayout content;
    private ProgressBar progress;
    private Button copyButton;
    private TextView statusText;
    private String noteMarkdown = "";

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        getWindow().setStatusBarColor(NAVY);
        setContentView(buildLayout());
        loadPredictions();
    }

    private View buildLayout() {
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(NAVY);

        LinearLayout header = new LinearLayout(this);
        header.setOrientation(LinearLayout.VERTICAL);
        header.setPadding(dp(18), dp(18), dp(18), dp(12));
        header.setBackgroundColor(NAVY);

        TextView title = text("鉄脚先生", 30, GOLD, Typeface.BOLD);
        title.setTypeface(Typeface.create(Typeface.SERIF, Typeface.BOLD));
        header.addView(title);

        statusText = text("予想データを読み込み中", 14, PAPER, Typeface.BOLD);
        statusText.setAlpha(0.82f);
        header.addView(statusText);

        LinearLayout actions = new LinearLayout(this);
        actions.setOrientation(LinearLayout.HORIZONTAL);
        actions.setGravity(Gravity.CENTER_VERTICAL);
        actions.setPadding(0, dp(12), 0, 0);

        copyButton = actionButton("note文面をコピー", RED);
        copyButton.setEnabled(false);
        copyButton.setOnClickListener(v -> copyNote());
        actions.addView(copyButton, new LinearLayout.LayoutParams(0, dp(48), 1));

        Button refresh = actionButton("更新", GOLD);
        refresh.setOnClickListener(v -> loadPredictions());
        LinearLayout.LayoutParams refreshParams = new LinearLayout.LayoutParams(dp(84), dp(48));
        refreshParams.leftMargin = dp(10);
        actions.addView(refresh, refreshParams);
        header.addView(actions);

        root.addView(header);

        progress = new ProgressBar(this);
        progress.setIndeterminate(true);
        root.addView(progress, new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(4)));

        ScrollView scroll = new ScrollView(this);
        content = new LinearLayout(this);
        content.setOrientation(LinearLayout.VERTICAL);
        content.setPadding(dp(14), dp(14), dp(14), dp(24));
        scroll.addView(content);
        root.addView(scroll, new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1));
        return root;
    }

    private void loadPredictions() {
        progress.setVisibility(View.VISIBLE);
        copyButton.setEnabled(false);
        statusText.setText("予想データを読み込み中");
        content.removeAllViews();

        new Thread(() -> {
            try {
                URL url = new URL(DATA_URL + "?v=" + System.currentTimeMillis());
                HttpURLConnection conn = (HttpURLConnection) url.openConnection();
                conn.setConnectTimeout(15000);
                conn.setReadTimeout(20000);
                conn.setRequestProperty("Accept", "application/json");
                int code = conn.getResponseCode();
                if (code != 200) {
                    throw new IllegalStateException("HTTP " + code);
                }
                BufferedReader reader = new BufferedReader(new InputStreamReader(conn.getInputStream(), StandardCharsets.UTF_8));
                StringBuilder builder = new StringBuilder();
                String line;
                while ((line = reader.readLine()) != null) {
                    builder.append(line);
                }
                JSONObject json = new JSONObject(builder.toString());
                main.post(() -> render(json));
            } catch (Exception e) {
                main.post(() -> renderError(e));
            }
        }).start();
    }

    private void render(JSONObject json) {
        progress.setVisibility(View.GONE);
        content.removeAllViews();
        noteMarkdown = json.optString("note_markdown", "");
        copyButton.setEnabled(!noteMarkdown.isEmpty());

        String dateLabel = json.optString("date_label", "本日");
        JSONArray picks = json.optJSONArray("predictions");
        int count = picks == null ? 0 : picks.length();
        statusText.setText(dateLabel + " / 一押し " + count + "本");

        JSONObject stats = json.optJSONObject("stats");
        if (stats != null) {
            addStats(stats);
        }

        JSONObject previous = json.optJSONObject("previous");
        if (previous != null) {
            addPrevious(previous);
        }

        sectionTitle("今日の一押し");
        if (picks == null || picks.length() == 0) {
            content.addView(card("予想がまだありません", "GitHub Actionsの生成後に表示されます。"));
            return;
        }

        for (int i = 0; i < picks.length(); i++) {
            JSONObject pick = picks.optJSONObject(i);
            if (pick != null) {
                content.addView(pickCard(pick));
            }
        }

        sectionTitle("note文面プレビュー");
        TextView preview = text(noteMarkdown.length() > 900 ? noteMarkdown.substring(0, 900) + "\n..." : noteMarkdown, 14, 0xFF241B12, Typeface.NORMAL);
        preview.setLineSpacing(0, 1.18f);
        LinearLayout box = panel(PAPER);
        box.addView(preview);
        content.addView(box);
    }

    private void addStats(JSONObject stats) {
        String body = "集計対象 " + stats.optInt("completed") + "レース\n"
            + "1着 " + stats.optInt("win_count") + "/" + stats.optInt("completed") + "（" + one(stats.optDouble("win_rate")) + "%）\n"
            + "3連単 " + stats.optInt("trifecta_count") + "/" + stats.optInt("completed") + "（" + one(stats.optDouble("trifecta_rate")) + "%）\n"
            + "2車単 " + stats.optInt("exacta_count") + "/" + stats.optInt("completed") + "（" + one(stats.optDouble("exacta_rate")) + "%）\n"
            + "ワイド " + stats.optInt("wide_count") + "/" + stats.optInt("completed") + "（" + one(stats.optDouble("wide_rate")) + "%）";
        content.addView(card("現在の的中率", body));
    }

    private void addPrevious(JSONObject previous) {
        JSONArray hits = previous.optJSONArray("hits");
        int total = previous.optInt("total");
        StringBuilder body = new StringBuilder();
        if (total == 0) {
            body.append("前日分はまだ集計中です。");
        } else if (hits == null || hits.length() == 0) {
            body.append("前日は的中なし。外れも隠さず見ます。");
        } else {
            body.append("的中 ").append(hits.length()).append("/").append(total);
            for (int i = 0; i < Math.min(4, hits.length()); i++) {
                JSONObject hit = hits.optJSONObject(i);
                if (hit != null) {
                    body.append("\n").append(hit.optString("venue")).append(" ")
                        .append(hit.optInt("race_no")).append("R ")
                        .append(hit.optString("label"));
                }
            }
        }
        content.addView(card("前日的中実績", body.toString()));
    }

    private View pickCard(JSONObject pick) {
        LinearLayout box = panel(PAPER);
        LinearLayout top = new LinearLayout(this);
        top.setGravity(Gravity.CENTER_VERTICAL);
        top.setOrientation(LinearLayout.HORIZONTAL);

        TextView rank = text(String.valueOf(pick.optInt("rank")), 28, 0xFFFFFFFF, Typeface.BOLD);
        rank.setGravity(Gravity.CENTER);
        rank.setBackgroundColor(RED);
        top.addView(rank, new LinearLayout.LayoutParams(dp(44), dp(44)));

        LinearLayout names = new LinearLayout(this);
        names.setOrientation(LinearLayout.VERTICAL);
        names.setPadding(dp(10), 0, 0, 0);
        TextView title = text(pick.optString("venue") + " " + pick.optInt("race_no") + "R", 21, 0xFF151515, Typeface.BOLD);
        title.setTypeface(Typeface.create(Typeface.SERIF, Typeface.BOLD));
        names.addView(title);
        String meta = pick.optString("start_time");
        String schedule = pick.optString("schedule_label");
        if (!schedule.isEmpty()) {
            meta += meta.isEmpty() ? schedule : " / " + schedule;
        }
        names.addView(text(meta, 13, 0xFF594A2D, Typeface.BOLD));
        top.addView(names, new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1));

        TextView grade = text(pick.optString("action_label") + " " + pick.optString("grade"), 13, 0xFFFFFFFF, Typeface.BOLD);
        grade.setGravity(Gravity.CENTER);
        grade.setPadding(dp(8), dp(5), dp(8), dp(5));
        grade.setBackgroundColor("買い".equals(pick.optString("action_label")) ? GREEN : GOLD);
        top.addView(grade);
        box.addView(top);

        String prediction = arrayCombo(pick.optJSONArray("prediction"));
        TextView pred = text("予想 " + prediction, 26, RED, Typeface.BOLD);
        pred.setPadding(0, dp(10), 0, dp(4));
        box.addView(pred);

        String storyValue = pick.optString("story");
        if (!storyValue.isEmpty()) {
            TextView story = text(storyValue, 15, 0xFF2B241A, Typeface.BOLD);
            story.setLineSpacing(0, 1.18f);
            story.setPadding(0, dp(4), 0, dp(6));
            box.addView(story);
        }

        JSONArray reasons = pick.optJSONArray("reasons");
        StringBuilder reasonText = new StringBuilder();
        if (reasons != null) {
            for (int i = 0; i < Math.min(3, reasons.length()); i++) {
                reasonText.append("・").append(reasons.optString(i)).append("\n");
            }
        }
        TextView reason = text(reasonText.toString().trim(), 14, 0xFF2B241A, Typeface.BOLD);
        reason.setLineSpacing(0, 1.15f);
        box.addView(reason);
        return box;
    }

    private void sectionTitle(String value) {
        TextView tv = text(value, 21, GOLD, Typeface.BOLD);
        tv.setTypeface(Typeface.create(Typeface.SERIF, Typeface.BOLD));
        tv.setPadding(0, dp(16), 0, dp(8));
        content.addView(tv);
    }

    private LinearLayout panel(int color) {
        LinearLayout box = new LinearLayout(this);
        box.setOrientation(LinearLayout.VERTICAL);
        box.setPadding(dp(14), dp(12), dp(14), dp(12));
        box.setBackgroundColor(color);
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        params.bottomMargin = dp(10);
        box.setLayoutParams(params);
        return box;
    }

    private View card(String title, String body) {
        LinearLayout box = panel(NAVY_2);
        box.addView(text(title, 18, GOLD, Typeface.BOLD));
        TextView bodyText = text(body, 15, PAPER, Typeface.BOLD);
        bodyText.setPadding(0, dp(6), 0, 0);
        bodyText.setLineSpacing(0, 1.18f);
        box.addView(bodyText);
        return box;
    }

    private TextView text(String value, int sp, int color, int style) {
        TextView tv = new TextView(this);
        tv.setText(value);
        tv.setTextSize(sp);
        tv.setTextColor(color);
        tv.setTypeface(Typeface.DEFAULT, style);
        tv.setIncludeFontPadding(true);
        return tv;
    }

    private Button actionButton(String label, int color) {
        Button button = new Button(this);
        button.setText(label);
        button.setTextSize(15);
        button.setTextColor(0xFFFFFFFF);
        button.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        button.setBackgroundColor(color);
        return button;
    }

    private void copyNote() {
        ClipboardManager clipboard = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
        clipboard.setPrimaryClip(ClipData.newPlainText("鉄脚先生 note文面", noteMarkdown));
        Toast.makeText(this, "note文面をコピーしました", Toast.LENGTH_SHORT).show();
    }

    private void renderError(Exception e) {
        progress.setVisibility(View.GONE);
        statusText.setText("読み込みに失敗しました");
        content.removeAllViews();
        content.addView(card("データ取得失敗", "時間を置いて更新してください。\n" + e.getMessage()));
    }

    private String arrayCombo(JSONArray arr) {
        if (arr == null) {
            return "-";
        }
        StringBuilder out = new StringBuilder();
        for (int i = 0; i < arr.length(); i++) {
            if (i > 0) out.append("-");
            out.append(arr.optInt(i));
        }
        return out.toString();
    }

    private String one(double value) {
        return String.format(Locale.JAPAN, "%.1f", value);
    }

    private int dp(int value) {
        return (int) (value * getResources().getDisplayMetrics().density + 0.5f);
    }
}
