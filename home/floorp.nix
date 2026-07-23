# Floorp browser — DECLARATIVE CONFIG LAYER ONLY.
#
# Two-layer split (READ THIS BEFORE EDITING):
#
#   * Declarative, here in git, identical on every host: the profile itself,
#     userChrome.css, and a small set of *stable* about:config prefs.
#
#   * Mutable, carried by Firefox Sync — NOT here: bookmarks, history, open
#     tabs, and EXTENSIONS. Do NOT add `profiles.<name>.extensions.*`.
#     Add-ons are installed from AMO at runtime and propagated by Sync's
#     Add-ons engine. The pinned home-manager mkFirefoxModule only writes to
#     ~/.floorp/<profile>/extensions/ when `extensions.packages` is non-empty
#     (it is `mkIf (packages != [])`), so leaving it unset keeps that directory
#     unmanaged and the Sync-installed add-ons intact. Declaring extensions
#     here would clobber them. This is deliberate — do not "improve" it.
#
# Prefs in `settings` are written to user.js and RE-APPLIED ON EVERY LAUNCH, so
# only genuinely stable prefs belong here; anything you want to toggle at
# runtime must stay OUT (it would silently revert on the next start). Floorp's
# own UI config (floorp.design.configs, workspaces, panel sidebar, etc.) and
# the toolbar layout are intentionally left to Floorp's own Sync, not frozen.
#
# The profile name is fixed to "default" so every host writes to the same path
# and Sync attaches to the same profile.
#
# Shared by both graphical hosts (home.nix is imported for connor on the desktop
# and the laptop), so this config is identical everywhere by construction.
{ ... }:

{
  programs.floorp = {
    enable = true;

    profiles.default = {
      id = 0;
      isDefault = true;

      settings = {
        # Required for userChrome.css to be read at all.
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;

        # Keep the window open when the last tab is closed.
        "browser.tabs.closeWindowWithLastTab" = false;

        # Force the built-in dark theme. Add-ons sync also carries the active
        # theme, but declaring it guarantees dark on a fresh profile before the
        # first Sync completes.
        "extensions.activeThemeID" = "firefox-compact-dark@mozilla.org";
        "browser.theme.content-theme" = 0;
        "browser.theme.toolbar-theme" = 0;

        # Bitwarden (browser extension + desktop app) is the password manager,
        # so Floorp's built-in password saving stays off. The Firefox Sync
        # Passwords engine is intentionally left disabled to match.
        "signon.rememberSignons" = false;
      };

      # userChrome is currently empty; the sibling file is a tracked hook for
      # future chrome tweaks. readFile keeps it out-of-line per repo convention.
      userChrome = builtins.readFile ./floorp-userChrome.css;
    };
  };
}
