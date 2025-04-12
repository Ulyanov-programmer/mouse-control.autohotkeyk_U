#Requires AutoHotkey v2.0
#SingleInstance
InstallKeybdHook

; vim_mouse_2.ahk
; vim (and now also WASD!) bindings to control the mouse with the keyboard
;
; Astrid Ivy
; 2019-04-14

global INSERT_MODE := false
global INSERT_QUICK := false
global NORMAL_MODE := false
global NORMAL_QUICK := false
global WASD := true

global MOUSE_FORCE := 1.8
global MOUSE_RESISTANCE := 0.982

global VELOCITY_X := 0
global VELOCITY_Y := 0

global DRAGGING := false
global DOUBLE_PRESS_ACTION_IS_ACTIVE := false

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
    LEFT := WASD
        ? 0 - GetKeyState("SC01E", "P") : 0 - GetKeyState("SC023", "P")
    DOWN := WASD
        ? 0 + GetKeyState("SC01F", "P") : 0 + GetKeyState("SC024", "P")
    UP := WASD
        ? 0 - GetKeyState("SC011", "P") : 0 - GetKeyState("SC025", "P")
    RIGHT := WASD
        ? 0 + GetKeyState("SC020", "P") : 0 + GetKeyState("SC026", "P")

    if (NORMAL_QUICK && !GetKeyState("Capslock", "P")) {
        EnterInsertMode()
    }

    if (!NORMAL_MODE) {
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
    ;MsgBox, %NORMAL_MODE%
    ;msg1 := "h " . LEFT . " j  " . DOWN . " k " . UP . " l " . RIGHT
    ;MsgBox, %msg1%
    ;msg2 := "Moving " . VELOCITY_X . " " . VELOCITY_Y
    ;MsgBox, %msg2%
}

EnterNormalMode(quick := false, mode := "vim") {
    global NORMAL_QUICK := quick
    global WASD := mode == "vim" ? false : true
    msg := "NORMAL"

    msg := mode == "vim"
        ? msg . " (VIM)" : msg . " (WASD)"
    msg := quick
        ? msg . " (QUICK)" : msg . ""

    ShowModePopup(msg)

    if (NORMAL_MODE) {
        return
    }

    global NORMAL_MODE := true
    global INSERT_MODE := false
    global INSERT_QUICK := false

    SetTimer(MoveCursor, 16)
}

EnterInsertMode(quick := false) {
    msg := quick ? "INSERT (QUICK)" : "INSERT"

    ShowModePopup(msg)

    global INSERT_MODE := true
    global INSERT_QUICK := quick

    global NORMAL_MODE := false
    global NORMAL_QUICK := false
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

; ReleaseDrag(button) {
;     Click("Middle Up")
;     Click(button)

;     DRAGGING := false
; }

; Yank() {
;     wx := 0, wy := 0, width := 0
;     WinGetPos(&wx, &wy, &width, , "A")
;     center := wx + width - 180
;     y := wy + 12
;     MouseMove(center, y)
;     Drag()
; }

EmulateMouseButton(button := "L") {
    ; If the key is held down, should simulate holding down the mouse key. Otherwise, it's letting up.
    if (InStr(A_ThisHotkey, "Up")) {
        Click(button " Up")
    }
    else {
        Click(button " Down")
    }

    global DRAGGING := false
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

    ;? Implements an action for N-times with a double tap.
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

;? "FINAL" MODE SWITCH BINDINGS
Home:: EnterNormalMode()
Insert:: EnterInsertMode()
<#<!n:: EnterNormalMode()
<#<!i:: EnterInsertMode()

;? escape hatches
+Home:: Send("{Home}")
+Insert:: Send("{Insert}")

; TODO doesn't turn capslock off.
^Capslock:: Send("{ Capslock }")
^+Capslock:: SetCapsLockState("Off")

#HotIf (NORMAL_MODE)
+SC029:: ClickInsert(false) ; shift + tilde, focus window and enter Insert
SC029:: ClickInsert(true) ; tilde, path to Quick Insert
~SC021:: EnterInsertMode(true) ; f, passthrough for Vimium hotlinks
~^SC021:: EnterInsertMode(true) ; f, passthrough to common "search" hotkey
~^SC014:: EnterInsertMode(true) ; t, passthrough for new tab
~Delete:: EnterInsertMode(true) ; passthrough for quick edits
+SC027:: EnterInsertMode(true) ; the ; symbol with shift, do not pass through
; ? intercept movement keys
SC023:: return ; h
+SC023:: JumpToEdge("left")
SC024:: return ; j
+SC024:: JumpToEdge("bottom")
SC025:: return ; k
+SC025:: JumpToEdge("top")
SC026:: return ; l
+SC026:: JumpToEdge("right")
; ? commands
*SC017:: EmulateMouseButton() ; i
*SC017 Up:: EmulateMouseButton() ; i
*SC018:: EmulateMouseButton("R") ; o
*SC018 Up:: EmulateMouseButton("R") ; o
*SC019:: EmulateMouseButton("M") ; p
*SC019 Up:: EmulateMouseButton("M") ; p
; shift + y, do not conflict with y as in  "scroll up"
; +SC015:: Yank()  ;! It is unclear why this is necessary.
SC02F:: Drag() ; v
SC02C:: Drag("R") ; z
SC02E:: Drag("M") ; c
SC032:: JumpMiddle() ; m
; SC033:: JumpMiddle2() ;! It is unclear why this is necessary.
; SC034:: JumpMiddle3() ;! It is unclear why this is necessary.
SC031:: MouseBrowserNavigate("forward") ; n
SC030:: MouseBrowserNavigate("back") ; b
; TODO allow for modifier keys (or more importantly a lack of them) by lifting ctrl requirement for these hotkeys
;? fixed?
*SC00A:: ScrollTo("up") ; 9
*SC00B:: ScrollTo("down") ; 0
SC01A:: ScrollTo("up") ; [
SC01B:: ScrollTo("down") ; ]
; End:: Click("Up") ;! What is this?

#HotIf (NORMAL_MODE && !NORMAL_QUICK)
Capslock:: EnterInsertMode(true)
+Capslock:: EnterInsertMode()

;? Add Vim hotkeys that conflict with WASD mode
#HotIf (NORMAL_MODE && !WASD)
; <#<!r:: EnterWASDMode() ;! Conflicts with the recording mode of Windows game bar
SC015:: ScrollTo("up") ; y
SC012:: ScrollTo("down") ; e
; +SC01F:: DoubleClickInsert() ; shift + s ; TODO doesn't really work well?

#HotIf (NORMAL_MODE && NORMAL_QUICK)
Capslock:: return
SC032:: JumpMiddle() ; m
; ,:: JumpMiddle2() ;! It is unclear why this is necessary.
; .:: JumpMiddle3() ;! It is unclear why this is necessary.
; y:: Yank() ;! It is unclear why this is necessary.

;? for windows explorer
#HotIf (NORMAL_MODE && WinActive("ahk_class CabinetWClass"))
^SC023:: Send("{ Left }") ; ctrl + h
^SC024:: Send("{ Down }") ; ctrl + j
^SC025:: Send("{ Up }") ; ctrl + k
^SC026:: Send("{ Right }") ; ctrl + l

#HotIf (INSERT_MODE && !INSERT_QUICK)
Capslock:: EnterNormalMode(true)
+Capslock:: EnterNormalMode()
<+Space:: EnterNormalMode(, "wasd")
>+Space:: EnterNormalMode()

#HotIf (INSERT_MODE && INSERT_QUICK)
~Enter:: EnterNormalMode()
~^SC02E:: EnterNormalMode() ; ctrl + c, copy and return to Normal Mode
Escape:: EnterNormalMode()
Capslock:: EnterNormalMode()
+Capslock:: EnterNormalMode()

#HotIf (NORMAL_MODE && WASD)
; <#<!r:: ExitWASDMode() ;! Conflicts with the recording mode of Windows game bar
;? Intercept movement keys
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
*SC013:: EmulateMouseButton() ; r
*SC013 Up:: EmulateMouseButton() ; r
SC014:: EmulateMouseButton("R") ; t
*SC014 Up:: EmulateMouseButton("R") ; t
*SC015:: EmulateMouseButton("M") ; y
*SC015 Up:: EmulateMouseButton("M") ; y
~BackSpace:: EnterInsertMode(true) ; passthrough for quick edits

; #HotIf (DRAGGING) ;! It looks like broken code.
; LButton:: ReleaseDrag(1)
; MButton:: ReleaseDrag(2)
; RButton:: ReleaseDrag(3)

; TODO: "Marks" for remembering and restoring mouse positions (needs AwaitKey)
; ?TODO: z for click and release middle mouse? this has historically not worked well
; ?TODO: c guess that leaves c for hold / release right mouse (x is useful in chromium)
;
; Github issues and pull requests welcome
