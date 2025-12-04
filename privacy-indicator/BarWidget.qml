import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.UI
import qs.Widgets

// Bar Widget Component
Rectangle {
  id: root

  property var pluginApi: null

  // Required properties for bar widgets
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""

  readonly property string barPosition: Settings.data.bar.position
  readonly property bool isVertical: barPosition === "left" || barPosition === "right"

  // Privacy states
  property bool micActive: false
  property bool camActive: false
  property bool scrActive: false
  property var micApps: []
  property var camApps: []
  property var scrApps: []

  // Active indicator color
  readonly property color activeColor: Color.mPrimary
  readonly property color inactiveColor: Qt.alpha(Color.mOnSurfaceVariant, 0.3)
  readonly property color micColor: micActive ? activeColor : inactiveColor
  readonly property color camColor: camActive ? activeColor : inactiveColor
  readonly property color scrColor: scrActive ? activeColor : inactiveColor

  implicitWidth: isVertical ? Style.capsuleHeight : Math.round(layout.implicitWidth + Style.marginM * 2)
  implicitHeight: isVertical ? Math.round(layout.implicitHeight + Style.marginM * 2) : Style.capsuleHeight

  Layout.alignment: Qt.AlignVCenter
  radius: Style.radiusM
  color: Style.capsuleColor

  PwObjectTracker {
    objects: Pipewire.ready ? Pipewire.nodes.values : []
  }

  Timer {
    interval: 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: updatePrivacyState()
  }

  function hasNodeLinks(node, links) {
    for (var i = 0; i < links.length; i++) {
      var link = links[i];
      if (link && (link.source === node || link.target === node)) {
        return true;
      }
    }
    return false;
  }

  function getAppName(node) {
    return node.properties["application.name"] || node.nickname || node.name || "";
  }

  function updateMicrophoneState(nodes, links) {
    var appNames = [];
    var isActive = false;
    
    for (var i = 0; i < nodes.length; i++) {
      var node = nodes[i];
      if (!node || !node.isStream || !node.audio || node.isSink) continue;
      if (!hasNodeLinks(node, links) || !node.properties) continue;
      
      var mediaClass = node.properties["media.class"] || "";
      if (mediaClass === "Stream/Input/Audio") {
        isActive = true;
        var appName = getAppName(node);
        if (appName && appNames.indexOf(appName) === -1) {
          appNames.push(appName);
        }
      }
    }
    
    root.micActive = isActive;
    root.micApps = appNames;
  }

  function isCameraNode(node) {
    var mediaClass = node.properties["media.class"] || "";
    var mediaName = (node.properties["media.name"] || "").toLowerCase();
    
    // Check for video capture devices (cameras)
    if (mediaClass && (mediaClass === "Video/Source" || 
                       mediaClass.indexOf("Video/Source") !== -1 ||
                       mediaClass.indexOf("Camera") !== -1)) {
      return true;
    }
    
    // Check for camera-related patterns in media name
    if (mediaName.match(/camera|webcam|video[0-9]/i)) {
      return true;
    }
    
    return false;
  }

  function updateCameraState(nodes, links) {
    var appNames = [];
    var isActive = false;
    
    for (var i = 0; i < nodes.length; i++) {
      var node = nodes[i];
      if (!node || !hasNodeLinks(node, links) || !node.properties) continue;
      
      if (isCameraNode(node)) {
        isActive = true;
        var appName = getAppName(node);
        if (appName && appNames.indexOf(appName) === -1) {
          appNames.push(appName);
        }
      }
    }
    
    root.camActive = isActive;
    root.camApps = appNames;
  }

  function isScreenShareNode(node) {
    if (!node.properties) {
      return false;
    }
    
    var mediaClass = node.properties["media.class"] || "";
    
    // CRITICAL: Immediately reject ANY node with "Audio" in media class
    if (mediaClass.indexOf("Audio") >= 0) {
      return false;
    }
    
    // Must explicitly have "Video" in media class
    if (mediaClass.indexOf("Video") === -1) {
      return false;
    }
    
    // Now check for screen sharing patterns
    var mediaName = (node.properties["media.name"] || "").toLowerCase();
    
    // Check for screen sharing patterns in media name
    if (mediaName.match(/^(xdph-streaming|gsr-default|game capture|screen|desktop|display|cast|webrtc|v4l2)/) ||
        mediaName === "gsr-default_output" ||
        mediaName.match(/screen-cast|screen-capture|desktop-capture|monitor-capture|window-capture|game-capture/i)) {
      return true;
    }
    
    return false;
  }

  function updateScreenShareState(nodes, links) {
    var appNames = [];
    var isActive = false;
    
    for (var i = 0; i < nodes.length; i++) {
      var node = nodes[i];
      if (!node || !hasNodeLinks(node, links) || !node.properties) continue;
      
      if (isScreenShareNode(node)) {
        isActive = true;
        var appName = getAppName(node);
        if (appName && appNames.indexOf(appName) === -1) {
          appNames.push(appName);
        }
      }
    }
    
    root.scrActive = isActive;
    root.scrApps = appNames;
  }

  function updatePrivacyState() {
    if (!Pipewire.ready) return;
    
    var nodes = Pipewire.nodes.values || [];
    var links = Pipewire.links.values || [];
    
    updateMicrophoneState(nodes, links);
    updateCameraState(nodes, links);
    updateScreenShareState(nodes, links);
  }

  function buildTooltip() {
    var parts = [];
    
    if (micActive && micApps.length > 0) {
      parts.push("Mic: " + micApps.join(", "));
    }
    
    if (camActive && camApps.length > 0) {
      parts.push("Cam: " + camApps.join(", "));
    }
    
    if (scrActive && scrApps.length > 0) {
      parts.push("Screen sharing: " + scrApps.join(", "));
    }
    
    return parts.length > 0 ? parts.join("\n") : "";
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.RightButton
    hoverEnabled: true
    
    onClicked: mouse => {
      if (mouse.button === Qt.RightButton) {
        // Plugin widgets can use context menu if needed
        // For now, just show tooltip on hover
      }
    }
    
    onEntered: TooltipService.show(root, buildTooltip())
    onExited: TooltipService.hide()
  }

  Item {
    id: layout
    anchors.verticalCenter: parent.verticalCenter
    anchors.horizontalCenter: parent.horizontalCenter

    implicitWidth: rowLayout.visible ? rowLayout.implicitWidth : colLayout.implicitWidth
    implicitHeight: rowLayout.visible ? rowLayout.implicitHeight : colLayout.implicitHeight

    RowLayout {
      id: rowLayout
      visible: !root.isVertical
      spacing: Style.marginXS

      NIcon {
        icon: micActive ? "microphone" : "microphone-off"
        color: root.micColor
      }
      NIcon {
        icon: camActive ? "camera" : "camera-off"
        color: root.camColor
      }
      NIcon {
        icon: scrActive ? "screen-share" : "screen-share-off"
        color: root.scrColor
      }
    }

    ColumnLayout {
      id: colLayout
      visible: root.isVertical
      spacing: Style.marginXS

      NIcon {
        icon: micActive ? "microphone" : "microphone-off"
        color: root.micColor
      }
      NIcon {
        icon: camActive ? "camera" : "camera-off"
        color: root.camColor
      }
      NIcon {
        icon: scrActive ? "screen-share" : "screen-share-off"
        color: root.scrColor
      }
    }
  }
}

