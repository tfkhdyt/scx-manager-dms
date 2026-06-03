import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import "ScxUtils.js" as ScxUtils

PluginComponent {
    id: root

    layerNamespacePlugin: "scx-manager"

    visibilityCommand: "command -v scxctl >/dev/null"
    visibilityInterval: 60000

    property bool isRunning: false
    property string currentSched: ""
    property string currentMode: "Auto"
    property bool hasCustomArgs: false
    property string customArgs: ""
    property var availableSchedulers: []
    property bool loading: false
    property bool serviceAvailable: true
    property string lastError: ""
    property string selectedSched: ""
    property string selectedMode: "Auto"
    property int selectedModeIndex: 0

    property int refreshIntervalSec: 5
    property string _procScope: ""

    function computeRefreshInterval() {
        const raw = pluginData?.refreshInterval
        if (raw === undefined || raw === null || raw === "")
            return 5
        const parsed = parseInt(raw, 10)
        if (isNaN(parsed))
            return 5
        return Math.max(2, Math.min(60, parsed))
    }

    onPluginDataChanged: refreshIntervalSec = computeRefreshInterval()

    readonly property var schedulerOptions: ScxUtils.schedDisplayOptions(availableSchedulers)
    readonly property var modeOptions: ScxUtils.modeLabels()
    readonly property string selectedSchedDisplay: ScxUtils.formatSchedDisplay(selectedSched)
    readonly property string currentSchedDisplay: ScxUtils.formatSchedDisplay(currentSched)
    readonly property bool modeSelectionEnabled: serviceAvailable && !hasCustomArgs && !loading
    readonly property bool canApply: serviceAvailable && selectedSched !== "" && !loading && !hasCustomArgs

    ccWidgetIsToggle: false
    ccWidgetIcon: "speed"
    ccWidgetPrimaryText: I18n.tr("Scheduler", "Scx Manager Control Center tile title")
    ccWidgetSecondaryText: {
        if (!serviceAvailable)
            return I18n.tr("Unavailable", "Scx Manager CC subtitle when scx_loader unavailable")
        if (!isRunning)
            return I18n.tr("Kernel default", "Scx Manager CC subtitle when no sched-ext scheduler is running")
        if (hasCustomArgs)
            return currentSchedDisplay + " · " + I18n.tr("Custom", "Scx Manager CC subtitle for custom args")
        return currentSchedDisplay + " · " + currentMode
    }
    ccWidgetIsActive: isRunning && serviceAvailable
    ccDetailHeight: 240

    onCcWidgetToggled: {}

    function runScxctl(action, args, callback) {
        var command = ["scxctl"].concat(args)
        Proc.runCommand(_procScope + "." + action, ["sh", "-c", command.map(function (part) {
            return "'" + String(part).replace(/'/g, "'\\''") + "'"
        }).join(" ") + " 2>&1"], callback, 0)
    }

    function applyStatusOutput(output, exitCode) {
        if (ScxUtils.isServiceError(output, exitCode)) {
            serviceAvailable = false
            lastError = (output || "").trim()
            isRunning = false
            currentSched = ""
            return
        }

        serviceAvailable = true
        lastError = ""
        var parsed = ScxUtils.parseGetOutput(output)
        isRunning = parsed.running
        currentSched = parsed.sched
        currentMode = parsed.mode
        hasCustomArgs = parsed.hasCustomArgs
        customArgs = parsed.customArgs
    }

    function finalizeSelectionFromStatus() {
        syncSelectionFromCurrent()
    }

    function refreshStatus() {
        runScxctl("scxManager.get", ["get"], function (output, exitCode) {
            applyStatusOutput(output, exitCode)
            if (selectedSched === "" && currentSched !== "")
                selectedSched = currentSched
            if (selectedSched === "" && !hasCustomArgs && currentMode !== "")
                selectedMode = currentMode
            selectedModeIndex = ScxUtils.modeLabelToIndex(selectedMode)
        })
    }

    function refreshList() {
        runScxctl("scxManager.list", ["list"], function (output, exitCode) {
            if (ScxUtils.isServiceError(output, exitCode)) {
                serviceAvailable = false
                lastError = (output || "").trim()
                return
            }

            serviceAvailable = true
            var schedulers = ScxUtils.parseListOutput(output)
            if (schedulers.length > 0)
                availableSchedulers = schedulers
        })
    }

    function refreshAll() {
        runScxctl("scxManager.list", ["list"], function (output, exitCode) {
            if (ScxUtils.isServiceError(output, exitCode)) {
                serviceAvailable = false
                lastError = (output || "").trim()
                return
            }

            serviceAvailable = true
            var schedulers = ScxUtils.parseListOutput(output)
            if (schedulers.length > 0)
                availableSchedulers = schedulers

            runScxctl("scxManager.get", ["get"], function (statusOutput, statusExitCode) {
                applyStatusOutput(statusOutput, statusExitCode)
                finalizeSelectionFromStatus()
            })
        })
    }

    function syncSelectionFromCurrent() {
        if (currentSched !== "")
            selectedSched = currentSched
        else if (selectedSched === "" && availableSchedulers.length > 0)
            selectedSched = availableSchedulers[0]
        if (!hasCustomArgs && currentMode !== "")
            selectedMode = currentMode
        selectedModeIndex = ScxUtils.modeLabelToIndex(selectedMode)
    }

    function handleMutationResult(output, exitCode, successMessage) {
        loading = false
        var message = (output || "").trim()
        if (exitCode !== 0 || message.toLowerCase().indexOf("error:") >= 0) {
            ToastService.showError(I18n.tr("Scheduler", "Scx Manager toast title for errors"), message || I18n.tr("Command failed", "Scx Manager generic command failure"))
            return false
        }
        ToastService.showInfo(I18n.tr("Scheduler", "Scx Manager toast title for success"), successMessage || message)
        refreshStatus()
        return true
    }

    function applySelection() {
        if (!canApply || hasCustomArgs)
            return

        var modeCli = ScxUtils.modeToCli(selectedMode)
        loading = true

        if (!isRunning) {
            runScxctl("scxManager.start", ["start", "--sched", selectedSched, "--mode", modeCli], function (output, exitCode) {
                handleMutationResult(output, exitCode, I18n.tr("Scheduler started", "Scx Manager success after start"))
            })
            return
        }

        var schedChanged = selectedSched !== currentSched
        var args = schedChanged
            ? ["switch", "--sched", selectedSched, "--mode", modeCli]
            : ["switch", "--mode", modeCli]

        runScxctl("scxManager.switch", args, function (output, exitCode) {
            handleMutationResult(output, exitCode, I18n.tr("Scheduler updated", "Scx Manager success after switch"))
        })
    }

    function stopScheduler() {
        loading = true
        runScxctl("scxManager.stop", ["stop"], function (output, exitCode) {
            handleMutationResult(output, exitCode, I18n.tr("Scheduler stopped", "Scx Manager success after stop"))
        })
    }

    function restartScheduler() {
        loading = true
        runScxctl("scxManager.restart", ["restart"], function (output, exitCode) {
            handleMutationResult(output, exitCode, I18n.tr("Scheduler restarted", "Scx Manager success after restart"))
        })
    }

    Timer {
        id: refreshTimer
        interval: Math.max(2, root.refreshIntervalSec) * 1000
        running: true
        repeat: true
        onTriggered: root.refreshStatus()
    }

    Component.onCompleted: {
        _procScope = "scxManager." + Math.floor(Math.random() * 1e9)
        refreshIntervalSec = computeRefreshInterval()
        refreshAll()
    }

    onRefreshIntervalSecChanged: refreshTimer.interval = Math.max(2, refreshIntervalSec) * 1000

    Component {
        id: controlsPanel

        Column {
            id: controlsRoot

            width: parent ? parent.width : 320
            spacing: Theme.spacingM

            RowLayout {
                width: parent.width
                spacing: Theme.spacingS

                StyledText {
                    Layout.fillWidth: true
                    text: {
                        if (!root.serviceAvailable)
                            return I18n.tr("scx_loader not available", "Scx Manager status when dbus service is down")
                        if (root.loading)
                            return I18n.tr("Working…", "Scx Manager status while command is running")
                        if (!root.isRunning)
                            return I18n.tr("Kernel default scheduler (EEVDF)", "Scx Manager status when idle")
                        if (root.hasCustomArgs)
                            return root.currentSchedDisplay + " · " + I18n.tr("Custom args", "Scx Manager status for custom scheduler flags")
                        return root.currentSchedDisplay + " · " + root.currentMode
                    }
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    wrapMode: Text.WordWrap
                }

                DankActionButton {
                    iconName: "sync"
                    buttonSize: 28
                    iconSize: 16
                    iconColor: Theme.surfaceVariantText
                    tooltipText: I18n.tr("Refresh", "Scx Manager refresh button tooltip")
                    enabled: !root.loading
                    onClicked: root.refreshAll()
                }
            }

            StyledText {
                width: parent.width
                visible: !root.serviceAvailable
                text: I18n.tr("Start scx_loader with: systemctl start scx_loader", "Scx Manager hint when service is unavailable")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.error
                wrapMode: Text.WordWrap
            }

            StyledText {
                width: parent.width
                visible: root.hasCustomArgs && root.customArgs !== ""
                text: I18n.tr("Custom flags: %1", "Scx Manager custom scheduler arguments note").arg(root.customArgs)
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
            }

            Column {
                width: parent.width
                spacing: Theme.spacingXS
                visible: root.serviceAvailable

                StyledText {
                    text: I18n.tr("Scheduler", "Scx Manager scheduler dropdown label")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

                DankDropdown {
                    width: parent.width
                    dropdownWidth: parent.width
                    maxPopupHeight: 360
                    openUpwards: true
                    currentValue: root.selectedSchedDisplay
                    options: root.schedulerOptions
                    enabled: root.serviceAvailable && !root.loading && root.schedulerOptions.length > 0
                    onValueChanged: function (value) {
                        root.selectedSched = ScxUtils.schedFromDisplay(value, root.availableSchedulers)
                    }
                }
            }

            Column {
                width: parent.width
                spacing: Theme.spacingXS
                visible: root.serviceAvailable

                StyledText {
                    text: I18n.tr("Profile", "Scx Manager scheduler profile/mode label")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                }

                DankFilterChips {
                    width: parent.width
                    model: root.modeOptions
                    currentIndex: root.selectedModeIndex
                    showCheck: true
                    showCounts: false
                    chipHeight: 30
                    opacity: root.modeSelectionEnabled ? 1 : 0.45
                    onSelectionChanged: function (index) {
                        if (!root.modeSelectionEnabled)
                            return
                        root.selectedModeIndex = index
                        root.selectedMode = root.modeOptions[index]
                    }
                }
            }

            GridLayout {
                width: parent.width
                columns: 3
                columnSpacing: Theme.spacingS
                rowSpacing: Theme.spacingS
                visible: root.serviceAvailable

                StyledRect {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: Theme.cornerRadius
                    color: Theme.primary
                    opacity: root.canApply && !root.hasCustomArgs ? 1 : 0.45

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: {
                            if (applyMouse.pressed)
                                return Theme.withAlpha(Theme.primaryText, 0.20)
                            if (applyMouse.containsMouse)
                                return Theme.withAlpha(Theme.primaryText, 0.12)
                            return "transparent"
                        }
                    }

                    StyledText {
                        anchors.centerIn: parent
                        text: root.isRunning
                            ? I18n.tr("Apply", "Scx Manager apply scheduler change button")
                            : I18n.tr("Start", "Scx Manager start scheduler button")
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: Theme.primaryText
                    }

                    MouseArea {
                        id: applyMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: root.canApply && !root.hasCustomArgs
                        onClicked: root.applySelection()
                    }
                }

                StyledRect {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: Theme.cornerRadius
                    color: stopMouse.containsMouse ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.18) : Theme.floatingSurface
                    border.color: stopMouse.containsMouse ? Theme.error : Theme.outlineStrong
                    border.width: 1
                    opacity: root.isRunning && !root.loading ? 1 : 0.45

                    StyledText {
                        anchors.centerIn: parent
                        text: I18n.tr("Stop", "Scx Manager stop scheduler button")
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: stopMouse.containsMouse ? Theme.error : Theme.surfaceText
                    }

                    MouseArea {
                        id: stopMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: root.isRunning && !root.loading
                        onClicked: root.stopScheduler()
                    }
                }

                StyledRect {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: Theme.cornerRadius
                    color: restartMouse.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16) : Theme.floatingSurface
                    border.color: Theme.outlineStrong
                    border.width: 1
                    opacity: root.isRunning && !root.loading ? 1 : 0.45

                    StyledText {
                        anchors.centerIn: parent
                        text: I18n.tr("Restart", "Scx Manager restart scheduler button")
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }

                    MouseArea {
                        id: restartMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: root.isRunning && !root.loading
                        onClicked: root.restartScheduler()
                    }
                }

            }

        }
    }

    ccDetailContent: Component {
        Rectangle {
            implicitHeight: (detailControls.item ? detailControls.item.implicitHeight : 0) + Theme.spacingM * 2
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerHigh

            Loader {
                id: detailControls
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.spacingM
                sourceComponent: controlsPanel
            }
        }
    }
}
