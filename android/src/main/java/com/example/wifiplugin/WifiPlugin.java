package com.example.wifiplugin;

import android.content.Context;
import android.net.wifi.WifiManager;
import android.net.wifi.WifiInfo;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

import java.util.Set;
import java.util.Arrays;

public class WifiPlugin extends GodotPlugin {
    private final WifiManager wifiManager;

    public WifiPlugin(Godot godot) {
        super(godot);
        wifiManager = (WifiManager) getActivity().getApplicationContext().getSystemService(Context.WIFI_SERVICE);
    }

    @Override
    public String getPluginName() {
        return "WifiPlugin";
    }

    @UsedByGodot
    public float getWifiStrength() {
        if (wifiManager == null) return 0.0f;

        WifiInfo wifiInfo = wifiManager.getConnectionInfo();
        if (wifiInfo == null) return 0.0f;

        int rssi = wifiInfo.getRssi();
        int level = WifiManager.calculateSignalLevel(rssi, 5);
        return level / 4.0f; // 转换为0-1范围
    }

    @Override
    public Set<String> getPluginMethods() {
        return new Set<String>(Arrays.asList("getWifiStrength"));
    }
}
