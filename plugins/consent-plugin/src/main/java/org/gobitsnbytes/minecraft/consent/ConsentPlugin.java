package org.gobitsnbytes.minecraft.consent;

import org.bukkit.ChatColor;
import org.bukkit.Location;
import org.bukkit.command.Command;
import org.bukkit.command.CommandSender;
import org.bukkit.configuration.file.FileConfiguration;
import org.bukkit.configuration.file.YamlConfiguration;
import org.bukkit.entity.Player;
import org.bukkit.event.EventHandler;
import org.bukkit.event.EventPriority;
import org.bukkit.event.Listener;
import org.bukkit.event.block.BlockBreakEvent;
import org.bukkit.event.block.BlockPlaceEvent;
import org.bukkit.event.entity.EntityDamageByEntityEvent;
import org.bukkit.event.player.AsyncPlayerChatEvent;
import org.bukkit.event.player.PlayerCommandPreprocessEvent;
import org.bukkit.event.player.PlayerJoinEvent;
import org.bukkit.event.player.PlayerMoveEvent;
import org.bukkit.plugin.java.JavaPlugin;

import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;

public final class ConsentPlugin extends JavaPlugin implements Listener {
    private final Set<UUID> accepted = new HashSet<>();
    private File acceptedFile;
    private boolean bypassOps;
    private String rulesHeader;
    private List<String> rulesLines;

    @Override
    public void onEnable() {
        saveDefaultConfig();
        loadState();
        getServer().getPluginManager().registerEvents(this, this);
        getCommand("accept").setExecutor(this::handleAccept);
        getCommand("rules").setExecutor(this::handleRules);
        getLogger().info("Consent gate enabled for " + accepted.size() + " accepted players.");
    }

    @Override
    public void onDisable() {
        saveState();
    }

    private void loadState() {
        acceptedFile = new File(getDataFolder(), "accepted.yml");
        bypassOps = getConfig().getBoolean("bypass-ops", true);
        rulesHeader = color(getConfig().getString("rules.header", "&6bits&bytes Minecraft Server"));
        rulesLines = getConfig().getStringList("rules.lines");
        if (rulesLines.isEmpty()) {
            rulesLines = List.of(
                "&fThis is an official digital fork of GOBITSNBYTES FOUNDATION.",
                "&fPlayer safety matters.",
                "&fPersonal payments to staff are prohibited.",
                "&fPolicies: https://gobitsnbytes.org/coc",
                "&fPrivacy: https://gobitsnbytes.org/privacy",
                "&fTerms: https://gobitsnbytes.org/terms",
                "&fType &a/accept &fto continue playing."
            );
        }

        if (!acceptedFile.exists()) {
            return;
        }

        FileConfiguration state = YamlConfiguration.loadConfiguration(acceptedFile);
        List<String> uuids = state.getStringList("accepted");
        for (String value : uuids) {
            try {
                accepted.add(UUID.fromString(value));
            } catch (IllegalArgumentException ignored) {
                getLogger().warning("Ignoring invalid UUID in accepted.yml: " + value);
            }
        }
    }

    private synchronized void saveState() {
        try {
            if (!getDataFolder().exists() && !getDataFolder().mkdirs()) {
                throw new IOException("Unable to create plugin data directory");
            }
            FileConfiguration state = new YamlConfiguration();
            List<String> uuids = new ArrayList<>();
            for (UUID uuid : accepted) {
                uuids.add(uuid.toString());
            }
            state.set("accepted", uuids);
            state.save(acceptedFile);
        } catch (IOException ex) {
            getLogger().severe("Failed to save consent state: " + ex.getMessage());
        }
    }

    private boolean isBypassed(Player player) {
        return player.hasPermission("bnb.consent.bypass") || (bypassOps && player.isOp());
    }

    private boolean hasAccepted(Player player) {
        return isBypassed(player) || accepted.contains(player.getUniqueId());
    }

    private void sendRules(Player player) {
        player.sendMessage(rulesHeader);
        for (String line : rulesLines) {
            player.sendMessage(color(line));
        }
    }

    private String color(String value) {
        return ChatColor.translateAlternateColorCodes('&', value == null ? "" : value);
    }

    private boolean handleAccept(CommandSender sender, Command command, String label, String[] args) {
        if (!(sender instanceof Player player)) {
            sender.sendMessage("This command can only be used in-game.");
            return true;
        }
        if (hasAccepted(player)) {
            player.sendMessage(color("&aYou have already accepted the rules."));
            return true;
        }
        accepted.add(player.getUniqueId());
        saveState();
        player.sendMessage(color("&aThank you. You may now play."));
        player.sendMessage(color("&fRemember: the Foundation policies remain in effect."));
        return true;
    }

    private boolean handleRules(CommandSender sender, Command command, String label, String[] args) {
        if (sender instanceof Player player) {
            sendRules(player);
        } else {
            sender.sendMessage("Foundation policies: https://gobitsnbytes.org/coc");
        }
        return true;
    }

    @EventHandler(priority = EventPriority.HIGHEST, ignoreCancelled = true)
    public void onJoin(PlayerJoinEvent event) {
        Player player = event.getPlayer();
        if (hasAccepted(player)) {
            return;
        }
        sendRules(player);
        player.sendMessage(color("&eYou must type &a/accept &eto continue."));
        player.teleport(player.getWorld().getSpawnLocation());
    }

    @EventHandler(priority = EventPriority.HIGHEST, ignoreCancelled = true)
    public void onMove(PlayerMoveEvent event) {
        if (hasAccepted(event.getPlayer())) {
            return;
        }
        Location from = event.getFrom();
        Location to = event.getTo();
        if (to == null) {
            return;
        }
        if (from.getWorld() != to.getWorld()
            || from.getX() != to.getX()
            || from.getY() != to.getY()
            || from.getZ() != to.getZ()) {
            event.setTo(from);
        }
    }

    @EventHandler(priority = EventPriority.HIGHEST, ignoreCancelled = true)
    public void onChat(AsyncPlayerChatEvent event) {
        if (!hasAccepted(event.getPlayer())) {
            event.setCancelled(true);
            event.getPlayer().sendMessage(color("&cPlease accept the rules first with /accept."));
        }
    }

    @EventHandler(priority = EventPriority.HIGHEST, ignoreCancelled = true)
    public void onCommand(PlayerCommandPreprocessEvent event) {
        if (hasAccepted(event.getPlayer())) {
            return;
        }
        String message = event.getMessage().trim().toLowerCase();
        String root = message.split("\\s+", 2)[0];
        if ("/accept".equals(root) || "/rules".equals(root) || "/login".equals(root) || "/register".equals(root) || "/reg".equals(root) || "/l".equals(root)) {
            return;
        }
        event.setCancelled(true);
        event.getPlayer().sendMessage(color("&cYou must accept the rules first. Use /accept or /rules."));
    }

    @EventHandler(priority = EventPriority.HIGHEST, ignoreCancelled = true)
    public void onBreak(BlockBreakEvent event) {
        if (!hasAccepted(event.getPlayer())) {
            event.setCancelled(true);
        }
    }

    @EventHandler(priority = EventPriority.HIGHEST, ignoreCancelled = true)
    public void onPlace(BlockPlaceEvent event) {
        if (!hasAccepted(event.getPlayer())) {
            event.setCancelled(true);
        }
    }

    @EventHandler(priority = EventPriority.HIGHEST, ignoreCancelled = true)
    public void onDamage(EntityDamageByEntityEvent event) {
        if (event.getDamager() instanceof Player player && !hasAccepted(player)) {
            event.setCancelled(true);
        }
    }
}
