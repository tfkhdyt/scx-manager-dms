.pragma library

var MODES = [
    { label: "Auto", cli: "auto" },
    { label: "Gaming", cli: "gaming" },
    { label: "Power Save", cli: "powersave" },
    { label: "Low Latency", cli: "lowlatency" },
    { label: "Server", cli: "server" }
]

function normalizeSched(name) {
    if (!name)
        return ""
    var trimmed = String(name).trim()
    if (trimmed.indexOf("scx_") === 0)
        trimmed = trimmed.substring(4)
    return trimmed.toLowerCase()
}

function formatSchedDisplay(name) {
    var sched = normalizeSched(name)
    if (!sched)
        return ""
    return sched.charAt(0).toUpperCase() + sched.slice(1)
}

function modeToCli(label) {
    for (var i = 0; i < MODES.length; i++) {
        if (MODES[i].label === label)
            return MODES[i].cli
    }
    return "auto"
}

function cliToModeLabel(cli) {
    if (!cli)
        return "Auto"
    var normalized = String(cli).toLowerCase()
    for (var i = 0; i < MODES.length; i++) {
        if (MODES[i].cli === normalized)
            return MODES[i].label
    }
    if (normalized === "lowlatency")
        return "Low Latency"
    if (normalized === "powersave")
        return "Power Save"
    return cli.charAt(0).toUpperCase() + cli.slice(1)
}

function modeLabels() {
    var labels = []
    for (var i = 0; i < MODES.length; i++)
        labels.push(MODES[i].label)
    return labels
}

function modeLabelToIndex(label) {
    for (var i = 0; i < MODES.length; i++) {
        if (MODES[i].label === label)
            return i
    }
    return 0
}

function parseGetOutput(stdout) {
    var text = (stdout || "").trim()
    var result = {
        running: false,
        sched: "",
        mode: "Auto",
        customArgs: "",
        hasCustomArgs: false
    }

    if (!text || text.indexOf("no scx scheduler running") >= 0)
        return result

    var modeMatch = text.match(/^running (\S+) in (\S+) mode$/)
    if (modeMatch) {
        result.running = true
        result.sched = normalizeSched(modeMatch[1])
        result.mode = cliToModeLabel(modeMatch[2])
        return result
    }

    var argsMatch = text.match(/^running (\S+) with arguments "(.*)"$/)
    if (argsMatch) {
        result.running = true
        result.sched = normalizeSched(argsMatch[1])
        result.hasCustomArgs = true
        result.customArgs = argsMatch[2]
        return result
    }

    return result
}

function parseListOutput(stdout) {
    var text = (stdout || "").trim()
    var match = text.match(/^supported schedulers:\s*(\[.*\])$/)
    if (!match)
        return []

    try {
        var parsed = JSON.parse(match[1])
        if (!Array.isArray(parsed))
            return []
        var schedulers = []
        for (var i = 0; i < parsed.length; i++) {
            var sched = normalizeSched(parsed[i])
            if (sched && schedulers.indexOf(sched) < 0)
                schedulers.push(sched)
        }
        schedulers.sort()
        return schedulers
    } catch (e) {
        return []
    }
}

function isServiceError(stdout, exitCode) {
    if (exitCode === 0)
        return false
    var text = (stdout || "").toLowerCase()
    return text.indexOf("error") >= 0
        || text.indexOf("notfound") >= 0
        || text.indexOf("scheduler list failed") >= 0
        || text.indexOf("connection") >= 0
}

function schedDisplayOptions(schedulers) {
    var options = []
    for (var i = 0; i < schedulers.length; i++)
        options.push(formatSchedDisplay(schedulers[i]))
    return options
}

function schedFromDisplay(displayName, schedulers) {
    var target = normalizeSched(displayName)
    for (var i = 0; i < schedulers.length; i++) {
        if (schedulers[i] === target)
            return schedulers[i]
    }
    return target
}
