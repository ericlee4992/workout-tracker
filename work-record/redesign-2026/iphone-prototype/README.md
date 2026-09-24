# Throwaway interactive design preview

Preferred deliverable: [interactive iPhone preview](../visuals/iphone-interactive.html).
Open directly in a browser. It is real DOM, not a screenshot: click app controls, scroll inside
the phone, type weights/reps, complete sets, navigate tabs. The screen menu is an optional shortcut.
All data is in memory and resets on reload. Some secondary actions remain labeled exemplars.

Regenerate: `python3 work-record/redesign-2026/iphone-prototype/export_phone.py`.
The export reuses `visuals/workout-redesign.html` and includes the same Lucide version used by
the visualizer (its copyright/license header is retained in the export). This dependency is
prototype-only; nothing was added to the production app target.

## Simulator experiment — not the working delivery

`python3 work-record/redesign-2026/iphone-prototype/build.py` builds a separate WKWebView shell
at `/tmp/wt-design-preview/DesignPreview.app`, identifier
`com.ericlee4992.workouttracker.designpreview`. It has no access to the production data container.
Swift compiler and ad-hoc signing exited 0; vtool confirms IOSSIMULATOR / SDK 27.0 / minimum 26.0.
The compiler printed a macOS-sysroot linker warning; successful simulator launch was confirmed.

Installed/launched on dedicated iOS 27 device `WT-DesignPreview`
(`5E7DDE99-11C4-4BE4-BE95-F70F1BFCCCEE`, launch PID 9829), and as a compatibility attempt on the
already-running `WT-iPhone` / iOS 26.5 (`432F2F5D-E694-4140-99C2-B398DE9D360F`, PID 18236).
Both rendered the prototype; **native touch delivery was not verified and repeatedly failed**.

Orca 1.4.209's serve-sim helper expects SimulatorKit in the old Developer/Library location;
Xcode 27 places it in `Contents/SharedFrameworks`. A process-local
`DYLD_FRAMEWORK_PATH=/Applications/Xcode.app/Contents/SharedFrameworks` let the bundled helper
stream and attach, without changing installed tool files. However AX returned 503
`No frontmost application returned`, and CLI / browser gestures did not change the simulator UI.
Do not claim native interaction works. Apple's old Simulator.app path is absent in this Xcode;
Device Hub launched but exposed no window. Further host-tool debugging is outside the design task.

The temporary viewer on localhost:3200 and helpers on 3100/3101 were stopped; preview apps were
terminated and the newly created simulator was shut down. Existing WT-iPhone remains booted.
No phone connection, real AI requests, data migration or production app installation.

## Working-browser evidence

Opened `iphone-interactive.html` in Orca page `f38c6604-3c84-4fa8-add1-cd18cfcc6fad`.
Actual browser clicks: Start Lifting → set log; entered 65 in set 2 weight; completed set 2.
Post-action accessibility snapshot reads 65, `Uncomplete set 2`, and `Rest · next set` / Skip.
Returned to home for the user. Pinned tabs and independently scrollable phone viewport are active.
This is a design prototype, not native SwiftUI accessibility/keyboard/haptic acceptance.
