#Requires AutoHotkey v2.0
#SingleInstance
InstallKeybdHook

; vim_mouse_2.ahk
; vim (and now also WASD!) bindings to control the mouse with the keyboard
;
; Astrid Ivy
; 2019-04-14

; Use these constants to specify the input type.
global CONTROL_TYPE_NAME_VIM := "vim"
global CONTROL_TYPE_NAME_WASD := "wasd"
global CONTROL_TYPE_NAME_INSERT := "none"

global INPUT_MODE := {
    type: CONTROL_TYPE_NAME_INSERT,
    quick: false,
}

global MOUSE_FORCE := 1.2
global MOUSE_RESISTANCE := 0.892

global VELOCITY_X := 0
global VELOCITY_Y := 0

global DRAGGING := false
global DOUBLE_PRESS_ACTION_IS_ACTIVE := false

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
    LEFT := INPUT_MODE.type == CONTROL_TYPE_NAME_WASD
        ? 0 - GetKeyState("SC01E", "P")
            : 0 - GetKeyState("SC023", "P")
    DOWN := INPUT_MODE.type == CONTROL_TYPE_NAME_WASD
        ? 0 + GetKeyState("SC01F", "P")
            : 0 + GetKeyState("SC024", "P")
    UP := INPUT_MODE.type == CONTROL_TYPE_NAME_WASD
        ? 0 - GetKeyState("SC011", "P")
            : 0 - GetKeyState("SC025", "P")
    RIGHT := INPUT_MODE.type == CONTROL_TYPE_NAME_WASD
        ? 0 + GetKeyState("SC020", "P")
            : 0 + GetKeyState("SC026", "P")

    if (
        INPUT_MODE.type != CONTROL_TYPE_NAME_INSERT &&
        INPUT_MODE.quick &&
        !GetKeyState("Capslock", "P")
    ) {
        ; If the fast mode is active, it switches back when release the key.
        EnterInsertMode()
    }

    if (INPUT_MODE.type == CONTROL_TYPE_NAME_INSERT) {
        global VELOCITY_X := 0
        global VELOCITY_Y := 0

        SetTimer(, 0)
    }

    global VELOCITY_X := Accelerate(VELOCITY_X, LEFT, RIGHT)
    global VELOCITY_Y := Accelerate(VELOCITY_Y, UP, DOWN)

    ; enable per-monitor DPI awareness
    RestoreDPI := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")

    MouseMove(VELOCITY_X, VELOCITY_Y, 0, "R")

    ;(humble beginnings)
    ;MsgBox, %INPUT_MODE.type != CONTROL_TYPE_NAME_INSERT%
    ;msg1 := "h " . LEFT . " j  " . DOWN . " k " . UP . " l " . RIGHT
    ;MsgBox, %msg1%
    ;msg2 := "Moving " . VELOCITY_X . " " . VELOCITY_Y
    ;MsgBox, %msg2%
}

EnterNormalMode(quick := false, mode := CONTROL_TYPE_NAME_VIM) {
    ;
    if (INPUT_MODE.quick) {
        INPUT_MODE.type := previousInputType
    }
    else {
        INPUT_MODE.type := mode
    }

    INPUT_MODE.quick := quick
    msg := "MOUSE"

    msg := INPUT_MODE.type == CONTROL_TYPE_NAME_VIM
        ? msg . " (VIM)" : msg . " (WASD)"

    msg := INPUT_MODE.quick
        ? msg . " QUICK" : msg . ""

    ShowModePopup(msg)
    SetTimer(MoveCursor, 5)
}

EnterInsertMode(quick := false) {
    msg := quick ? "INSERT (QUICK)" : "INSERT"

    ShowModePopup(msg)

    if (quick) {
        global previousInputType := INPUT_MODE.type
    }

    INPUT_MODE.type := CONTROL_TYPE_NAME_INSERT
    INPUT_MODE.quick := quick
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

; ; TODO: When we have more monitors, set up H and L to use current screen as basis
; ; hard to test when I only have the one

JumpMiddle() {
    CoordMode("Mouse", "Screen")
    MouseMove(A_ScreenWidth // 2, A_ScreenHeight // 2)
}

; JumpMiddle2() {
;     CoordMode("Mouse", "Screen")
;     MouseMove(A_ScreenWidth + A_ScreenWidth // 2, A_ScreenHeight // 2)
; }
; JumpMiddle3() {
;     CoordMode("Mouse", "Screen")
;     MouseMove(A_ScreenWidth * 2 + A_ScreenWidth // 2, A_ScreenHeight // 2)
; }

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

#HotIf (INPUT_MODE.type != CONTROL_TYPE_NAME_INSERT)
+SC029:: ClickInsert(false) ; shift + tilde, focus window and enter Insert
SC029:: ClickInsert(true) ; tilde, path to Quick Insert
~SC021:: EnterInsertMode(true) ; f, passthrough for Vimium hotlinks
~^SC021:: EnterInsertMode(true) ; f, passthrough to common "search" hotkey
~^SC014:: EnterInsertMode(true) ; t, passthrough for new tab
~Delete:: EnterInsertMode(true) ; passthrough for quick edits
+SC027:: EnterInsertMode(true) ; the ; symbol with shift, do not pass through
; * intercept movement keys
SC023:: return ; h
+SC023:: JumpToEdge("left")
SC024:: return ; j
+SC024:: JumpToEdge("bottom")
SC025:: return ; k
+SC025:: JumpToEdge("top")
SC026:: return ; l
+SC026:: JumpToEdge("right")
; * commands
SC039:: EmulateMouseButton()
!SC039:: EmulateMouseButton("R") ; Alt + Space
^SC039:: EmulateMouseButton("M") ; Ctrl + Space
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
#HotIf (INPUT_MODE.type == CONTROL_TYPE_NAME_VIM)
>+SC039:: EnterInsertMode() ; Right Shift + Space
SC015:: ScrollTo("up") ; y
SC012:: ScrollTo("down") ; e
; +SC01F:: DoubleClickInsert() ; shift + s ; TODO doesn't really work well?

;* for windows explorer
#HotIf (INPUT_MODE.type != CONTROL_TYPE_NAME_INSERT && WinActive("ahk_class CabinetWClass"))
^SC023:: Send("{ Left }") ; ctrl + h
^SC024:: Send("{ Down }") ; ctrl + j
^SC025:: Send("{ Up }") ; ctrl + k
^SC026:: Send("{ Right }") ; ctrl + l

#HotIf (INPUT_MODE.type == CONTROL_TYPE_NAME_INSERT && !INPUT_MODE.quick)
<+SC039:: EnterNormalMode(, CONTROL_TYPE_NAME_WASD) ; Left Shift + Space
>+SC039:: EnterNormalMode() ; Right Shift + Space

#HotIf (INPUT_MODE.type == CONTROL_TYPE_NAME_INSERT && INPUT_MODE.quick)
~Enter:: EnterNormalMode()
~^SC02E:: EnterNormalMode() ; ctrl + c, copy and return to Normal Mode
Escape:: EnterNormalMode()

#HotIf (INPUT_MODE.type == CONTROL_TYPE_NAME_WASD)
<+SC039:: EnterInsertMode() ; Left Shift + Space
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
SC039:: EmulateMouseButton()
!SC039:: EmulateMouseButton("R") ; Alt + Space
^SC039:: EmulateMouseButton("M") ; Ctrl + Space
SC02E:: Drag("M") ; c
~BackSpace:: EnterInsertMode(true) ; passthrough for quick edits
