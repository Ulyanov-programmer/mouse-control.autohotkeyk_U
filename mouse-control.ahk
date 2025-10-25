#Requires AutoHotkey v2.0
#SingleInstance
InstallKeybdHook

; vim_mouse_2.ahk
; vim (and now also WASD!) bindings to control the mouse with the keyboard
;
; Astrid Ivy
; 2019-04-14

; ; TODO: When we have more monitors, set up H and L to use current screen as basis
; ; hard to test when I only have the one

Thread("Priority", 150)

CONTROL_TYPES := {
    VIM: {
        UP: "SC025",
        LEFT: "SC023",
        DOWN: "SC024",
        RIGHT: "SC026",
        NAME: "VIM"
    },
    WASD: {
        UP: "SC011",
        LEFT: "SC01E",
        DOWN: "SC01F",
        RIGHT: "SC020",
        NAME: "WASD"
    },
    NUMPAD: {
        UP: "Numpad5",
        LEFT: "Numpad1",
        DOWN: "Numpad2",
        RIGHT: "Numpad3",
        NAME: "NUMPAD"
    },
}

INPUT := {
    modeName: "NUMPAD",
    quick: false,
}

MOUSE_FORCE := 1.2
MOUSE_RESISTANCE := 0.892

VELOCITY := { X: 0, Y: 0 }

DRAGGING := false
DOUBLE_PRESS_ACTION_IS_ACTIVE := false

CapsLock:: GetKeyState("CapsLock", "T")
    ? SetCapsLockState("Off")
    : SetCapsLockState("On")

; Insert Mode by default
EnterInsertMode()

Accelerate(velocity, pos, neg) {
    if (pos == 0 && neg == 0) {
        return 0
    }
    ; smooth deceleration
    else if (pos + neg == 0) {
        return velocity * 0.666
    }
    ; physics
    else {
        return velocity * MOUSE_RESISTANCE + MOUSE_FORCE * (pos + neg)
    }
}

MoveCursor() {
    if (
        INPUT.modeName &&
        INPUT.quick &&
        !GetKeyState("Capslock", "P")
    ) {
        ; If the fast mode is active, it switches back when release the key.
        EnterInsertMode()
    }

    ; if (!INPUT.modeName) {
    ;     VELOCITY.X := 0
    ;     VELOCITY.Y := 0

    ;     SetTimer(, 0)
    ; }

    VELOCITY.X := Accelerate(
        VELOCITY.X,
        0 - GetKeyState(CONTROL_TYPES.%INPUT.modeName%.LEFT, "P"),
        0 + GetKeyState(CONTROL_TYPES.%INPUT.modeName%.RIGHT, "P")
    )
    VELOCITY.Y := Accelerate(
        VELOCITY.Y,
        0 - GetKeyState(CONTROL_TYPES.%INPUT.modeName%.UP, "P"),
        0 + GetKeyState(CONTROL_TYPES.%INPUT.modeName%.DOWN, "P")
    )

    ; enable per-monitor DPI awareness
    RestoreDPI := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")

    MouseMove(VELOCITY.X, VELOCITY.Y, 0, "R")
}

EnterNormalMode(quick := false, mode := "VIM") {
    if (INPUT.quick) {
        INPUT.modeName := previousInputType
    }
    else {
        INPUT.modeName := mode
    }

    INPUT.quick := quick
    msg := "MOUSE"

    msg := msg . " (" . INPUT.modeName . ")"

    msg := INPUT.quick
        ? msg . " QUICK" : msg . ""

    ShowModePopup(msg)
    SetTimer(MoveCursor, 5)
}

EnterInsertMode(quick := false) {
    msg := quick ? "INSERT (QUICK)" : "INSERT"

    ShowModePopup(msg)

    if (quick) {
        global previousInputType := INPUT.modeName
    }

    INPUT.modeName := "NUMPAD"
    INPUT.quick := quick
}

ClickInsert(quick := true) {
    Click
    EnterInsertMode(quick)
}

DoubleClickInsert(quick := true) {
    Click
    Sleep(100)
    Click
    EnterInsertMode(quick)
}

ShowModePopup(msg) {
    HideTrayTip()
    TrayTip(msg, "Mouse control", "Mute")
    SetTimer(HideTrayTip, -2000) ; Let it display for 2 seconds.
}

HideTrayTip() {
    TrayTip  ; Attempt to hide it the normal way.

    if SubStr(A_OSVersion, 1, 3) = "10." {
        A_IconHidden := true
        Sleep 200  ; It may be necessary to adjust this sleep.
        A_IconHidden := false
    }
}

Drag(mouseButton := "L") {
    global

    if (DRAGGING) {
        Click(mouseButton " Up")
        DRAGGING := false

        return
    }

    Click(mouseButton " Down")
    DRAGGING := true
}

Yank() {
    wx := 0, wy := 0, width := 0
    WinGetPos(&wx, &wy, &width, , "A")
    center := wx + width - 180
    y := wy + 12
    MouseMove(center, y)
    Drag()
}

EmulateMouseButton(button := "L") {
    global DRAGGING := false

    if (button != "L") {
        Click(button)
        return
    }

    Click(button " Down")

    ; Waits until the key is released, then sends a signal to stop holding the key.
    KeyWait(A_ThisHotkey)
    Click(button " Up")
}

JumpMiddle() {
    CoordMode("Mouse", "Screen")
    MouseMove(A_ScreenWidth // 2, A_ScreenHeight // 2)

    ; JumpMiddle2() {
    ;     CoordMode("Mouse", "Screen")
    ;     MouseMove(A_ScreenWidth + A_ScreenWidth // 2, A_ScreenHeight // 2)
    ; }
    ; JumpMiddle3() {
    ;     CoordMode("Mouse", "Screen")
    ;     MouseMove(A_ScreenWidth * 2 + A_ScreenWidth // 2, A_ScreenHeight // 2)
    ; }
}

GetMonitorLeftEdge() {
    mx := 0

    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx)

    return mx // A_ScreenWidth * A_ScreenWidth
}

JumpToEdge(direction) {
    x := 0, y := 0

    switch direction {
        case "left":
            x := GetMonitorLeftEdge() + 2

            CoordMode("Mouse", "Screen")
            MouseGetPos(, &y)

        case "bottom":
            y := A_ScreenHeight

            CoordMode("Mouse", "Screen")
            MouseGetPos(&x)

        case "top":
            CoordMode("Mouse", "Screen")
            MouseGetPos(&x)

        case "right":
            x := GetMonitorLeftEdge() + A_ScreenWidth - 2

            CoordMode("Mouse", "Screen")
            MouseGetPos(, &y)
    }

    MouseMove(x, y)
}

MouseBrowserNavigate(to) {
    if (to == "back") {
        Click("X1")
    }
    else if (to == "forward") {
        Click("X2")
    }
}

ScrollTo(direction) {
    switch direction {
        case "up":
            Click("WheelUp")
        case "down":
            Click("WheelDown")
    }

    DoByDoublePress(ScrollTo.Bind(direction), 5)
}

DoByDoublePress(callback, repeatFor := 1) {
    global

    if (DOUBLE_PRESS_ACTION_IS_ACTIVE) {
        return
    }

    ;* Implements an action for N-times with a double tap.
    ; Initially, A_TimeSincePriorHotkey and A_PriorHotkey are empty strings.
    ; Using an empty string in a comparison is an error.
    ; Try prevents this initial inevitable error.
    try {
        ; Check if it's been 250 ms or less since the prior hotkey was fired
        ; And check if the current fired hotkey matches the prior hotkey.
        if (A_TimeSincePriorHotkey < 250 && A_ThisHotkey = A_PriorHotkey) {
            DOUBLE_PRESS_ACTION_IS_ACTIVE := true

            loop repeatFor {
                callback()
            }

            DOUBLE_PRESS_ACTION_IS_ACTIVE := false
        }
    }
}

#HotIf (INPUT.modeName != "NUMPAD")
+SC029:: ClickInsert(false) ; shift + tilde, focus window and enter Insert
SC029:: ClickInsert(true) ; tilde, path to Quick Insert
~SC021:: EnterInsertMode(true) ; f, passthrough for Vimium hotlinks
~^SC021:: EnterInsertMode(true) ; Ctrl + f, passthrough to common "search" hotkey
~^SC014:: EnterInsertMode(true) ; Ctrl + t, passthrough for new tab
~Delete:: EnterInsertMode(true) ; passthrough for quick edits
+SC027:: EnterInsertMode(true) ; the ; symbol with shift, do not pass through
; * commands
SC039:: EmulateMouseButton() ; Space
+SC039:: EmulateMouseButton("R") ; Shift + Space
!SC039:: EmulateMouseButton("M") ; Alt + Space
+SC015:: Yank() ; shift + y, do not conflict with y as in  "scroll up"
SC02E:: Drag("M") ; c
SC032:: JumpMiddle() ; m
SC031:: MouseBrowserNavigate("forward") ; n
SC030:: MouseBrowserNavigate("back") ; b
; TODO allow for modifier keys (or more importantly a lack of them) by lifting ctrl requirement for these hotkeys
;? fixed?
*SC00A:: ScrollTo("up") ; 9
*SC00B:: ScrollTo("down") ; 0
SC01A:: ScrollTo("up") ; [
SC01B:: ScrollTo("down") ; ]

;* Add Vim hotkeys that conflict with WASD mode
#HotIf (INPUT.modeName == "VIM")
>^SC039:: EnterInsertMode() ; Right Alt + Space
SC015:: ScrollTo("up") ; y
SC012:: ScrollTo("down") ; e
; +SC01F:: DoubleClickInsert() ; shift + s ; TODO doesn't really work well?
; * intercept movement keys
SC023:: return ; h
+SC023:: JumpToEdge("left")
SC024:: return ; j
+SC024:: JumpToEdge("bottom")
SC025:: return ; k
+SC025:: JumpToEdge("top")
SC026:: return ; l
+SC026:: JumpToEdge("right")

;* for windows explorer
#HotIf (INPUT.modeName != "NUMPAD" && WinActive("ahk_class CabinetWClass"))
^SC023:: Send("{ Left }") ; ctrl + h
^SC024:: Send("{ Down }") ; ctrl + j
^SC025:: Send("{ Up }") ; ctrl + k
^SC026:: Send("{ Right }") ; ctrl + l

#HotIf (INPUT.modeName == "NUMPAD" && !INPUT.quick)
<^SC039:: EnterNormalMode(, "WASD") ; Left Alt + Space
>^SC039:: EnterNormalMode() ; Right Alt + Space

#HotIf (INPUT.modeName == "NUMPAD" && INPUT.quick)
~Enter:: EnterNormalMode()
~^SC02E:: EnterNormalMode() ; ctrl + c, copy and return to Normal Mode
Escape:: EnterNormalMode()

#HotIf (INPUT.modeName == "WASD")
<^SC039:: EnterInsertMode() ; Left Alt + Space
;* Intercept movement keys
SC011:: return ; w
SC01E:: return ; a
SC01F:: return ; s
SC020:: return ; d
+SC02E:: JumpMiddle() ; shift + c
+SC011:: JumpToEdge("top") ; shift + w
+SC01E:: JumpToEdge("left") ; shift + a
+SC01F:: JumpToEdge("bottom") ; shift + s
+SC020:: JumpToEdge("right") ; shift + d
SC012:: ScrollTo("down") ; e
*SC010:: ScrollTo("up") ; q
~BackSpace:: EnterInsertMode(true) ; passthrough for quick edits

;* NUMPAD, Intercept movement keys
Numpad5:: return ; up
Numpad1:: return ; left
Numpad2:: return ; down
Numpad3:: return ; right
Numpad6:: ScrollTo("down")
Numpad4:: ScrollTo("up")
Numpad0:: EmulateMouseButton()
NumpadEnter:: EmulateMouseButton("R")
NumpadDot:: EmulateMouseButton("M")