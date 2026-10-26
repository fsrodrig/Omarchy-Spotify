import QtQuick
import Quickshell
import "plugin" as Plugin

ShellRoot {
  QtObject {
    id: scopedShell
    property var barConfig: ({ layout: { left: [], right: [], center: [{
      id: "quickshell.spotify",
      clientId: "3af5793fd7d748d18d4a8aa50ba11230",
      shortcutPlayer: "Full player"
    }] } })
  }
  property int identityResets: 0
  Plugin.Service { id: spotifyService; shell: scopedShell }
  Connections {
    target: spotifyService.auth
    function onLoggedOut() { identityResets++ }
  }
  Plugin.Panel { id: panel; service: spotifyService; width: 1280; height: 800 }
  Plugin.BarWidget { id: widget }
  Timer {
    interval: 20
    running: true
    onTriggered: {
      if (spotifyService.settings.clientId !== "3af5793fd7d748d18d4a8aa50ba11230"
          || spotifyService.settings.shortcutPlayer !== "Full player")
        throw new Error("Scoped shell barConfig settings did not reach the service")
      if (!spotifyService.settingsReady || !spotifyService.auth.initialized)
        throw new Error("Auth stayed gated after settings loaded")
      if (spotifyService.auth.resolvedClientId !== "3af5793fd7d748d18d4a8aa50ba11230")
        throw new Error("Auth did not use the configured client ID")
      if (identityResets !== 0)
        throw new Error("Loading the saved client ID was treated as an identity change")
      scopedShell.barConfig = ({ layout: { center: [{
        id: "quickshell.spotify",
        clientId: "3af5793fd7d748d18d4a8aa50ba11230",
        shortcutPlayer: "Mini player"
      }] } })
      if (spotifyService.settings.shortcutPlayer !== "Mini player")
        throw new Error("Live barConfig changes did not re-sync settings")
      spotifyService.auth.customClientId = "invalid"
      spotifyService.search("smoke-test", "track")
      if (spotifyService.searchLoading || !spotifyService.searchError)
        throw new Error("Search service did not return the authorization error")
      if (!panel.primaryNavigationItems().some(function(item) { return item.id === "search" }))
        throw new Error("Search navigation is missing")
      spotifyService.clearSearch()
      if (spotifyService.searchQuery !== "") throw new Error("Search state did not clear")
      console.log("APP_SMOKE_PASS")
      Qt.quit()
    }
  }
}
