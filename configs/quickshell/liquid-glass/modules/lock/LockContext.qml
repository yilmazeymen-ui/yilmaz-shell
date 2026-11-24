import QtQuick
import Quickshell
import Quickshell.Services.Pam

// Shared lock authentication state across all monitor lock surfaces.
Scope {
    id: root

    signal unlocked()
    signal failed()

    property string currentText: ""
    property bool unlockInProgress: false
    property bool showFailure: false
    property bool pamError: false

    onCurrentTextChanged: {
        if (currentText.length > 0) {
            root.showFailure = false;
            root.pamError = false;
        }
    }

    function tryUnlock() {
        if (root.currentText === "" || root.unlockInProgress)
            return;
        root.unlockInProgress = true;
        root.showFailure = false;
        root.pamError = false;
        pamWatchdog.restart();
        pam.start();
    }

    function reset() {
        pamWatchdog.stop();
        root.currentText = "";
        root.showFailure = false;
        root.pamError = false;
        root.unlockInProgress = false;
    }

    Timer {
        id: pamWatchdog
        interval: 10000
        repeat: false
        onTriggered: {
            if (root.unlockInProgress) {
                root.unlockInProgress = false;
                root.currentText = "";
                root.pamError = true;
            }
        }
    }

    PamContext {
        id: pam
        configDirectory: "pam"
        config: "password.conf"

        onPamMessage: {
            if (this.responseRequired) {
                this.respond(root.currentText);
            }
        }

        onCompleted: result => {
            pamWatchdog.stop();
            if (result === PamResult.Success) {
                root.unlocked();
            } else {
                root.currentText = "";
                root.showFailure = true;
                root.failed();
            }
            root.unlockInProgress = false;
        }
    }
}
