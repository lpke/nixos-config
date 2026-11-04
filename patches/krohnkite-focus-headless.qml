    Timer {
        interval: 200
        running: true
        repeat: true
        property int phase: 0
        property int attempts: 0
        property var initialLeft: null
        property var initialRight: null
        function check(ok, name) {
            console.log("FOCUS_CHECK", ok ? "PASS" : "FAIL", name);
            if (!ok) { stop(); throw new Error(name); }
        }
        onTriggered: {
            attempts++;
            if (attempts > 100) { check(false, "timed out"); return; }
            var clients = Workspace.stackingOrder.filter(function(w) {
                return w.normalWindow && ["Alacritty", "helium"].indexOf(String(w.resourceClass)) >= 0;
            }).sort(function(a,b) { return a.frameGeometry.x - b.frameGeometry.x; });
            if (clients.length !== 2) return;
            var left = clients[0], right = clients[1];
            if (phase === 0) {
                if (left.frameGeometry.x + left.frameGeometry.width > right.frameGeometry.x + 1) return;
                initialLeft = left; initialRight = right;
                Workspace.activeWindow = left;
                shortcutsLoader.item.getFocusRight().activated();
                check(Workspace.activeWindow === right, "right focuses the right-hand app");
            } else if (phase === 1) {
                shortcutsLoader.item.getFocusLeft().activated();
                check(Workspace.activeWindow === left, "left focuses the left-hand app");
            } else if (phase === 2) {
                shortcutsLoader.item.getFocusLeft().activated();
                check(Workspace.activeWindow === right, "left at the edge still wraps right");
            } else if (phase === 3) {
                shortcutsLoader.item.getFocusRight().activated();
                check(Workspace.activeWindow === left, "right at the edge still wraps left");
                shortcutsLoader.item.getShiftRight().activated();
            } else if (phase === 4) {
                check(left === initialRight && right === initialLeft, "arrow swap changes window positions");
                Workspace.activeWindow = left;
                shortcutsLoader.item.getFocusRight().activated();
                check(Workspace.activeWindow === right, "right follows the new positions after swap");
                shortcutsLoader.item.getFocusLeft().activated();
                check(Workspace.activeWindow === left, "left follows the new positions after swap");
                shortcutsLoader.item.getToggleFloat().activated();
            } else if (phase === 5) {
                check(!testDriver.windowMap.get(Workspace.activeWindow).tiled, "current app is floating");
                Workspace.activeWindow.frameGeometry = {x:0,y:100,width:400,height:500};
            } else if (phase === 6) {
                var floating = Workspace.activeWindow;
                shortcutsLoader.item.getFocusRight().activated();
                check(Workspace.activeWindow !== floating, "floating focus uses native geometry");
                Workspace.sendClientToScreen(Workspace.activeWindow, Workspace.screens[1]);
            } else if (phase === 7) {
                var source = Workspace.stackingOrder.filter(function(w) { return clients.indexOf(w)>=0 && w.output === Workspace.screens[0]; })[0];
                var target = clients.filter(function(w) { return w !== source; })[0];
                check(source && target.output === Workspace.screens[1], "apps span two virtual screens");
                Workspace.activeWindow = source;
                shortcutsLoader.item.getFocusRight().activated();
                check(Workspace.activeWindow === target, "native fallback focuses the other screen");
                console.log("FOCUS_CHECK DONE");
                stop();
            }
            phase++;
        }
    }
