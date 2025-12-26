import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    property int updateInterval: 300
    property bool showGenerations: pluginData.showGenerations !== undefined ? pluginData.showGenerations : true
    property bool showStoreSize: pluginData.showStoreSize !== undefined ? pluginData.showStoreSize : true
    property int gcThresholdGB: pluginData.gcThresholdGB || 50
    property bool checkUpdates: pluginData.checkUpdates !== undefined ? pluginData.checkUpdates : true
    property int updateCheckInterval: pluginData.updateCheckInterval || 3600
    property string nixpkgsChannel: pluginData.nixpkgsChannel || "nixos-unstable"

    property int generationCount: 0
    property string storeSize: "..."
    property real storeSizeGB: 0
    property bool isLoading: true
    property string lastUpdate: ""
    property bool operationRunning: false
    property string consoleOutput: ""
    property bool showConsole: false
    property string runningOperation: ""
    property string sudoPassword: ""
    property bool showPasswordDialog: false
    property string localRevision: "..."
    property string remoteRevision: "..."
    property bool isUpToDate: true
    property bool canCompareVersions: false
    property bool isCheckingUpdates: false

    property var config: null
    property var generationsCommand: ["sh", "-c", "echo 0"]
    property var storeSizeCommand: ["sh", "-c", "echo ..."]
    property var rebuildCommand: ["sh", "-c", "echo 'No rebuild command configured'"]
    property var homeManagerCommand: ["sh", "-c", "echo 'No home-manager command configured'"]
    property var gcCommand: ["sh", "-c", "echo 'No GC command configured'"]
    property var localRevisionCommand: ["sh", "-c", "nixos-version --hash 2>/dev/null | cut -c 1-7 || echo 'N/A'"]
    property var remoteRevisionCommand: ["sh", "-c", "git ls-remote https://github.com/NixOS/nixpkgs.git nixos-unstable 2>/dev/null | cut -c 1-7 || echo 'N/A'"]

    property string configJsonContent: ""

    Process {
        id: configLoader
        command: ["cat", Quickshell.env("HOME") + "/.config/DankMaterialShell/plugins/NixMonitor/config.json"]
        running: false

        stdout: SplitParser {
            onRead: function(line) {
                root.configJsonContent += line
            }
        }

        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0 && root.configJsonContent) {
                try {
                    var configData = JSON.parse(root.configJsonContent)
                    if (configData.generationsCommand) {
                        root.generationsCommand = configData.generationsCommand
                    }
                    if (configData.storeSizeCommand) {
                        root.storeSizeCommand = configData.storeSizeCommand
                    }
                    if (configData.rebuildCommand) {
                        root.rebuildCommand = configData.rebuildCommand
                    }
                    if (configData.homeManagerCommand) {
                        root.homeManagerCommand = configData.homeManagerCommand
                    }
                    if (configData.gcCommand) {
                        root.gcCommand = configData.gcCommand
                    }
                    if (configData.updateInterval) {
                        root.updateInterval = configData.updateInterval
                        updateTimer.interval = configData.updateInterval * 1000
                    }
                    if (configData.localRevisionCommand) {
                        root.localRevisionCommand = configData.localRevisionCommand
                    }
                    if (configData.remoteRevisionCommand) {
                        root.remoteRevisionCommand = configData.remoteRevisionCommand
                    }
                    if (configData.nixpkgsChannel) {
                        root.nixpkgsChannel = configData.nixpkgsChannel
                        // Update remote command with the configured channel
                        root.remoteRevisionCommand = ["sh", "-c", "git ls-remote https://github.com/NixOS/nixpkgs.git " + configData.nixpkgsChannel + " 2>/dev/null | cut -c 1-7 || echo 'N/A'"]
                    }
                    console.info("Loaded custom config:", JSON.stringify(configData))
                } catch (e) {
                    console.warn("Failed to parse config.json:", e)
                }
            } else if (exitCode !== 0) {
                console.warn("Failed to load config.json, using defaults")
            }
            root.refreshData()
        }
    }

    Component.onCompleted: {
        console.info("Nix Monitor plugin loaded")
        configLoader.running = true
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            DankIcon {
                name: "inventory_2"
                size: root.iconSize
                color: root.storeSizeGB > root.gcThresholdGB ? Theme.error : Theme.primary
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: root.isLoading ? "..." : root.generationCount.toString()
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
                visible: root.showGenerations
            }

            StyledText {
                text: "gen"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                anchors.verticalCenter: parent.verticalCenter
                visible: root.showGenerations
            }

            Rectangle {
                width: 1
                height: Theme.iconSize
                color: Theme.outlineVariant
                anchors.verticalCenter: parent.verticalCenter
                visible: root.showGenerations && root.showStoreSize
            }

            StyledText {
                text: root.storeSize
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: root.storeSizeGB > root.gcThresholdGB ? Theme.error : Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
                visible: root.showStoreSize
            }

            DankIcon {
                name: "check"
                size: root.iconSize * 0.8
                color: root.canCompareVersions ? (root.isUpToDate ? Theme.success : Theme.warning) : Theme.error
                anchors.verticalCenter: parent.verticalCenter
                visible: root.checkUpdates && !root.isCheckingUpdates
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS

            DankIcon {
                name: "inventory_2"
                size: root.iconSize
                color: root.storeSizeGB > root.gcThresholdGB ? Theme.error : Theme.primary
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: root.isLoading ? "..." : root.generationCount.toString()
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.showGenerations
            }

            StyledText {
                text: root.storeSize
                font.pixelSize: Theme.fontSizeSmall
                color: root.storeSizeGB > root.gcThresholdGB ? Theme.error : Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.showStoreSize
            }

            DankIcon {
                name: "check"
                size: root.iconSize * 0.8
                color: root.canCompareVersions ? (root.isUpToDate ? Theme.success : Theme.warning) : Theme.error
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.checkUpdates && !root.isCheckingUpdates
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            id: popout
            headerText: "Nix Store Monitor"
            detailsText: root.lastUpdate ? "Updated: " + root.lastUpdate : "Loading..."
            showCloseButton: true

            Item {
                width: parent.width
                implicitHeight: mainColumn.implicitHeight + Theme.spacingL

                Column {
                    id: mainColumn
                    width: parent.width
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingM

                        StyledRect {
                            width: (parent.width - Theme.spacingM) / 2
                            height: 100
                            radius: Theme.cornerRadius
                            color: Theme.surfaceContainerHigh

                            Column {
                                anchors.centerIn: parent
                                spacing: Theme.spacingXS

                                DankIcon {
                                    name: "history"
                                    size: 32
                                    color: Theme.primary
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                StyledText {
                                    text: root.generationCount.toString()
                                    font.pixelSize: Theme.fontSizeXLarge
                                    font.weight: Font.Bold
                                    color: Theme.surfaceText
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                StyledText {
                                    text: "Generations"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                        }

                        StyledRect {
                            width: (parent.width - Theme.spacingM) / 2
                            height: 100
                            radius: Theme.cornerRadius
                            color: Theme.surfaceContainerHigh

                            Column {
                                anchors.centerIn: parent
                                spacing: Theme.spacingXS

                                DankIcon {
                                    name: "storage"
                                    size: 32
                                    color: root.storeSizeGB > root.gcThresholdGB ? Theme.error : Theme.primary
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                StyledText {
                                    text: root.storeSize
                                    font.pixelSize: Theme.fontSizeXLarge
                                    font.weight: Font.Bold
                                    color: root.storeSizeGB > root.gcThresholdGB ? Theme.error : Theme.surfaceText
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                StyledText {
                                    text: "Store Size"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                        }
                    }

                    StyledRect {
                        width: parent.width
                        height: nixpkgsUpdateContent.implicitHeight + Theme.spacingM * 2
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHigh
                        visible: root.checkUpdates && !root.isCheckingUpdates

                        Column {
                            id: nixpkgsUpdateContent
                            width: parent.width - Theme.spacingM * 2
                            anchors.centerIn: parent
                            spacing: Theme.spacingXS

                            Row {
                                width: parent.width
                                spacing: Theme.spacingS

                                DankIcon {
                                    name: root.canCompareVersions ? (root.isUpToDate ? "check_circle" : "update") : "error"
                                    size: Theme.iconSize
                                    color: root.canCompareVersions ? (root.isUpToDate ? Theme.success : Theme.warning) : Theme.error
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    text: root.canCompareVersions ? (root.isUpToDate ? "Nixpkgs is up to date" : "Nixpkgs update available") : "Could not fetch version info"
                                    font.pixelSize: Theme.fontSizeMedium
                                    font.weight: Font.Bold
                                    color: Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Row {
                                width: parent.width
                                spacing: Theme.spacingM

                                Column {
                                    spacing: Theme.spacingXXS

                                    StyledText {
                                        text: "Local:"
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                    }

                                    StyledText {
                                        text: root.localRevision
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.family: "monospace"
                                        color: Theme.surfaceText
                                    }
                                }

                                Column {
                                    spacing: Theme.spacingXXS

                                    StyledText {
                                        text: "Remote (" + root.nixpkgsChannel + "):"
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                    }

                                    StyledText {
                                        text: root.remoteRevision
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.family: "monospace"
                                        color: Theme.surfaceText
                                    }
                                }
                            }
                        }
                    }

                    StyledRect {
                        width: parent.width
                        height: warningContent.implicitHeight + Theme.spacingM * 2
                        radius: Theme.cornerRadius
                        color: Theme.errorContainer
                        visible: root.storeSizeGB > root.gcThresholdGB

                        Row {
                            id: warningContent
                            width: parent.width - Theme.spacingM * 2
                            anchors.centerIn: parent
                            spacing: Theme.spacingS

                            DankIcon {
                                name: "warning"
                                size: Theme.iconSize
                                color: Theme.onErrorContainer
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: "Store size exceeds " + root.gcThresholdGB + " GB threshold"
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.onErrorContainer
                                wrapMode: Text.WordWrap
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    StyledRect {
                        width: parent.width
                        height: passwordColumn.implicitHeight + Theme.spacingM * 2
                        radius: Theme.cornerRadius
                        color: Theme.surfaceContainerHigh

                        Column {
                            id: passwordColumn
                            width: parent.width - Theme.spacingM * 2
                            anchors.centerIn: parent
                            spacing: Theme.spacingS

                            StyledText {
                                text: "Sudo Password"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Bold
                                color: Theme.surfaceText
                            }

                            Row {
                                width: parent.width
                                spacing: Theme.spacingS

                                StyledRect {
                                    width: parent.width - unlockButton.width - Theme.spacingS
                                    height: 36
                                    radius: Theme.cornerRadius / 2
                                    color: Theme.surfaceContainer

                                    TextInput {
                                        id: passwordInput
                                        anchors.fill: parent
                                        anchors.margins: Theme.spacingS
                                        echoMode: TextInput.Password
                                        color: Theme.surfaceText
                                        font.pixelSize: Theme.fontSizeSmall
                                        verticalAlignment: TextInput.AlignVCenter
                                        onAccepted: {
                                            root.sudoPassword = text
                                        }
                                    }
                                }

                                DankButton {
                                    id: unlockButton
                                    text: root.sudoPassword ? "Locked" : "Set"
                                    iconName: root.sudoPassword ? "lock" : "lock_open"
                                    buttonHeight: 36
                                    backgroundColor: root.sudoPassword ? Theme.success : Theme.surfaceContainerHighest
                                    textColor: root.sudoPassword ? Theme.onSuccess : Theme.surfaceText
                                    onClicked: {
                                        if (root.sudoPassword) {
                                            root.sudoPassword = ""
                                            passwordInput.text = ""
                                        } else {
                                            root.sudoPassword = passwordInput.text
                                        }
                                    }
                                }
                            }

                            StyledText {
                                text: "Password is stored in memory only and cleared when locked"
                                font.pixelSize: Theme.fontSizeXSmall
                                color: Theme.surfaceVariantText
                                wrapMode: Text.WordWrap
                                width: parent.width
                            }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS

                        StyledText {
                            text: "Actions"
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                        }

                        Column {
                            width: parent.width
                            spacing: Theme.spacingS

                            Row {
                                width: parent.width
                                spacing: Theme.spacingS

                                DankButton {
                                    width: (parent.width - Theme.spacingS * 3) / 4
                                    text: "Refresh"
                                    iconName: "refresh"
                                    enabled: !root.isLoading && !root.operationRunning
                                    onClicked: {
                                        root.refreshData()
                                    }
                                }

                                DankButton {
                                    width: (parent.width - Theme.spacingS * 3) / 4
                                    text: root.operationRunning && root.runningOperation === "rebuild" ? "Building..." : "Rebuild"
                                    iconName: "build"
                                    backgroundColor: Theme.secondary
                                    textColor: Theme.onSecondary
                                    enabled: !root.operationRunning && root.sudoPassword !== ""
                                    onClicked: {
                                        root.rebuildSystem()
                                    }
                                }

                                DankButton {
                                    width: (parent.width - Theme.spacingS * 3) / 4
                                    text: root.operationRunning && root.runningOperation === "home" ? "Switching..." : "Home"
                                    iconName: "home"
                                    enabled: !root.operationRunning
                                    onClicked: {
                                        root.switchHomeManager()
                                    }
                                }

                                DankButton {
                                    width: (parent.width - Theme.spacingS * 3) / 4
                                    text: root.operationRunning && root.runningOperation === "gc" ? "Running..." : "GC"
                                    iconName: "cleaning_services"
                                    backgroundColor: Theme.error
                                    textColor: Theme.onError
                                    enabled: !root.operationRunning && root.sudoPassword !== ""
                                    onClicked: {
                                        root.runGarbageCollect()
                                    }
                                }
                            }


                        }
                    }

                    Column {
                        width: parent.width
                        spacing: Theme.spacingS
                        visible: root.showConsole

                        StyledText {
                            text: "Console Output"
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Font.Bold
                            color: Theme.surfaceText
                        }

                        StyledRect {
                            width: parent.width
                            height: 200
                            radius: Theme.cornerRadius
                            color: Theme.surfaceContainerLow

                            Flickable {
                                id: outputFlickable
                                anchors.fill: parent
                                anchors.margins: Theme.spacingS
                                contentHeight: outputText.implicitHeight
                                clip: true

                                TextEdit {
                                    id: outputText
                                    width: parent.width
                                    text: root.consoleOutput || "Waiting for output..."
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: "monospace"
                                    color: Theme.surfaceText
                                    wrapMode: TextEdit.Wrap
                                    readOnly: true
                                    selectByMouse: true
                                    selectByKeyboard: true
                                }

                                onContentHeightChanged: {
                                    if (contentHeight > height) {
                                        contentY = contentHeight - height
                                    }
                                }
                            }
                        }

                        Row {
                            width: parent.width
                            spacing: Theme.spacingS

                            Item {
                                width: parent.width - clearButton.width - cancelButton.width - Theme.spacingS * 2
                                height: 1
                            }

                            DankButton {
                                id: cancelButton
                                text: "Cancel"
                                iconName: "cancel"
                                buttonHeight: 30
                                backgroundColor: Theme.error
                                textColor: Theme.onError
                                opacity: root.operationRunning ? 1 : 0
                                enabled: root.operationRunning
                                onClicked: {
                                    root.cancelOperation()
                                }
                            }

                            DankButton {
                                id: clearButton
                                text: "Clear"
                                iconName: "close"
                                buttonHeight: 30
                                enabled: !root.operationRunning
                                onClicked: {
                                    root.showConsole = false
                                    root.consoleOutput = ""
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    popoutWidth: 450
    popoutHeight: 500

    Timer {
        id: updateTimer
        interval: root.updateInterval * 1000
        running: true
        repeat: true
        onTriggered: root.refreshData()
    }

    Timer {
        id: updateCheckTimer
        interval: root.updateCheckInterval * 1000
        running: root.checkUpdates
        repeat: true
        onTriggered: root.checkNixpkgsUpdates()
    }

    Process {
        id: generationCountProcess
        command: root.generationsCommand
        running: false

        stdout: SplitParser {
            onRead: function(line) {
                var count = parseInt(line.trim())
                if (!isNaN(count)) {
                    root.generationCount = count
                }
            }
        }

        onExited: function(exitCode, exitStatus) {
            root.isLoading = false
        }
    }

    Process {
        id: storeSizeProcess
        command: root.storeSizeCommand
        running: false

        stdout: SplitParser {
            onRead: function(line) {
                var output = line.trim()
                if (output) {
                    root.storeSize = output
                    var match = output.match(/([0-9.]+)G/)
                    if (match) {
                        root.storeSizeGB = parseFloat(match[1])
                    }
                }
            }
        }

        onExited: function(exitCode, exitStatus) {
            root.isLoading = false
            var now = new Date()
            root.lastUpdate = Qt.formatTime(now, "HH:mm:ss")
        }
    }

    Process {
        id: rebuildProcess
        command: []
        running: false

        stdout: SplitParser {
            onRead: function(line) {
                root.consoleOutput += line + "\n"
            }
        }

        stderr: SplitParser {
            onRead: function(line) {
                root.consoleOutput += line + "\n"
            }
        }

        onExited: function(exitCode, exitStatus) {
            root.operationRunning = false
            root.runningOperation = ""
            if (exitCode === 0) {
                root.consoleOutput += "\n✓ System rebuilt successfully\n"
                ToastService.showInfo("System rebuilt successfully")
                root.refreshData()
            } else if (exitCode === 143 || exitCode === 130) {
                root.consoleOutput += "\n✗ Rebuild cancelled by user\n"
                ToastService.showInfo("Rebuild cancelled")
            } else {
                root.consoleOutput += "\n✗ Rebuild failed (exit code: " + exitCode + ")\n"
                ToastService.showError("Rebuild failed")
            }
        }
    }

    Process {
        id: homeManagerProcess
        command: root.homeManagerCommand
        running: false

        stdout: SplitParser {
            onRead: function(line) {
                root.consoleOutput += line + "\n"
            }
        }

        stderr: SplitParser {
            onRead: function(line) {
                root.consoleOutput += line + "\n"
            }
        }

        onExited: function(exitCode, exitStatus) {
            root.operationRunning = false
            root.runningOperation = ""
            if (exitCode === 0) {
                root.consoleOutput += "\n✓ Home-manager switched successfully\n"
                ToastService.showInfo("Home-manager switched successfully")
                root.refreshData()
            } else if (exitCode === 143 || exitCode === 130) {
                root.consoleOutput += "\n✗ Home-manager switch cancelled by user\n"
                ToastService.showInfo("Home-manager switch cancelled")
            } else {
                root.consoleOutput += "\n✗ Home-manager switch failed (exit code: " + exitCode + ")\n"
                ToastService.showError("Home-manager switch failed")
            }
        }
    }

    Process {
        id: garbageCollectProcess
        command: []
        running: false

        stdout: SplitParser {
            onRead: function(line) {
                root.consoleOutput += line + "\n"
            }
        }

        stderr: SplitParser {
            onRead: function(line) {
                root.consoleOutput += line + "\n"
            }
        }

        onExited: function(exitCode, exitStatus) {
            root.operationRunning = false
            root.runningOperation = ""
            if (exitCode === 0) {
                root.consoleOutput += "\n✓ Garbage collection completed\n"
                ToastService.showInfo("Garbage collection completed")
                root.refreshData()
            } else if (exitCode === 143 || exitCode === 130) {
                root.consoleOutput += "\n✗ GC cancelled by user\n"
                ToastService.showInfo("GC cancelled")
            } else {
                root.consoleOutput += "\n✗ GC failed (exit code: " + exitCode + ")\n"
                ToastService.showError("GC failed")
            }
        }
    }

    Process {
        id: localRevisionProcess
        command: root.localRevisionCommand
        running: false

        stdout: SplitParser {
            onRead: function(line) {
                var revision = line.trim()
                if (revision && revision !== "N/A") {
                    root.localRevision = revision
                } else {
                    root.localRevision = "N/A"
                }
            }
        }

        onExited: function(exitCode, exitStatus) {
            root.isCheckingUpdates = false
            root.updateUpToDateStatus()
        }
    }

    Process {
        id: remoteRevisionProcess
        command: root.remoteRevisionCommand
        running: false

        stdout: SplitParser {
            onRead: function(line) {
                var revision = line.trim()
                if (revision && revision !== "N/A") {
                    root.remoteRevision = revision
                } else {
                    root.remoteRevision = "N/A"
                }
            }
        }

        onExited: function(exitCode, exitStatus) {
            root.isCheckingUpdates = false
            root.updateUpToDateStatus()
        }
    }



    function refreshData() {
        root.isLoading = true
        generationCountProcess.running = true
        storeSizeProcess.running = true
        if (root.checkUpdates) {
            root.checkNixpkgsUpdates()
        }
    }

    function checkNixpkgsUpdates() {
        if (!root.isCheckingUpdates) {
            root.isCheckingUpdates = true
            localRevisionProcess.running = true
            remoteRevisionProcess.running = true
        }
    }

    function updateUpToDateStatus() {
        if (root.localRevision !== "..." && root.remoteRevision !== "..." &&
            root.localRevision !== "N/A" && root.remoteRevision !== "N/A") {
            root.canCompareVersions = true
            root.isUpToDate = (root.localRevision === root.remoteRevision)
        } else {
            root.canCompareVersions = false
            root.isUpToDate = false
        }
    }

    function rebuildSystem() {
        root.operationRunning = true
        root.runningOperation = "rebuild"
        root.showConsole = true
        root.consoleOutput = "Starting system rebuild...\n"
        ToastService.showInfo("Starting system rebuild...")

        // Construct command with password piped in
        var baseCommand = root.rebuildCommand[root.rebuildCommand.length - 1]
        var cmdWithPassword = "echo '" + root.sudoPassword + "' | " + baseCommand
        rebuildProcess.command = ["bash", "-c", cmdWithPassword]
        rebuildProcess.running = true
    }

    function switchHomeManager() {
        root.operationRunning = true
        root.runningOperation = "home"
        root.showConsole = true
        root.consoleOutput = "Starting home-manager switch...\n"
        ToastService.showInfo("Starting home-manager switch...")
        homeManagerProcess.running = true
    }

    function runGarbageCollect() {
        root.operationRunning = true
        root.runningOperation = "gc"
        root.showConsole = true
        root.consoleOutput = "Starting garbage collection...\n"
        ToastService.showInfo("Starting garbage collection...")

        // Construct command with password piped in
        var baseCommand = root.gcCommand[root.gcCommand.length - 1]
        var cmdWithPassword = "echo '" + root.sudoPassword + "' | " + baseCommand
        garbageCollectProcess.command = ["bash", "-c", cmdWithPassword]
        garbageCollectProcess.running = true
    }

    function cancelOperation() {
        if (root.runningOperation === "rebuild" && rebuildProcess.running) {
            rebuildProcess.running = false
            root.consoleOutput += "\n✗ Cancelling rebuild...\n"
        } else if (root.runningOperation === "home" && homeManagerProcess.running) {
            homeManagerProcess.running = false
            root.consoleOutput += "\n✗ Cancelling home-manager switch...\n"
        } else if (root.runningOperation === "gc" && garbageCollectProcess.running) {
            garbageCollectProcess.running = false
            root.consoleOutput += "\n✗ Cancelling garbage collection...\n"
        }
        ToastService.showInfo("Cancelling operation...")
    }
}
