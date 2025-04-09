#Requires AutoHotkey v2.0
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

global POP_UP := false

global DRAGGING := false

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
    LEFT := 0
    DOWN := 0
    UP := 0
    RIGHT := 0

    LEFT := LEFT - GetKeyState("h", "P")
    DOWN := DOWN + GetKeyState("j", "P")
    UP := UP - GetKeyState("k", "P")
    RIGHT := RIGHT + GetKeyState("l", "P")

    if (WASD) {
        UP := UP - GetKeyState("w", "P")
        LEFT := LEFT - GetKeyState("a", "P")
        DOWN := DOWN + GetKeyState("s", "P")
        RIGHT := RIGHT + GetKeyState("d", "P")
    }

    if (NORMAL_QUICK) {
        caps_down := GetKeyState("Capslock", "P")

        if (caps_down == 0) {
            EnterInsertMode()
        }
    }

    if (NORMAL_MODE == false) {
        VELOCITY_X := 0
        VELOCITY_Y := 0

        SetTimer(, Off)
    }

    VELOCITY_X := Accelerate(VELOCITY_X, LEFT, RIGHT)
    VELOCITY_Y := Accelerate(VELOCITY_Y, UP, DOWN)

    ; enable per-monitor DPI awareness
    RestoreDPI := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")

    MouseMove(%VELOCITY_X%, %VELOCITY_Y%, 0, R)

    ;(humble beginnings)
    ;MsgBox, %NORMAL_MODE%
    ;msg1 := "h " . LEFT . " j  " . DOWN . " k " . UP . " l " . RIGHT
    ;MsgBox, %msg1%
    ;msg2 := "Moving " . VELOCITY_X . " " . VELOCITY_Y
    ;MsgBox, %msg2%
}

EnterNormalMode(quick := false) {
    ;MsgBox, "Welcome to Normal Mode"
    NORMAL_QUICK := quick

    msg := "NORMAL"

    if (WASD == false) {
        msg := msg . " (VIM)"
    }

    if (quick) {
        msg := msg . " (QUICK)"
    }

    ShowModePopup(msg)

    if (NORMAL_MODE) {
        return
    }

    NORMAL_MODE := true
    INSERT_MODE := false
    INSERT_QUICK := false

    SetTimer(MoveCursor, 16)
}

EnterWASDMode(quick := false) {
    msg := "NORMAL"

    if (quick) {
        msg := msg . " (QUICK)"
    }

    ShowModePopup(msg)

    WASD := true

    EnterNormalMode(quick)
}

ExitWASDMode() {
    ShowModePopup("NORMAL (VIM)")
    WASD := false
}

EnterInsertMode(quick := false) {
    ;MsgBox, "Welcome to Insert Mode"
    msg := "INSERT"

    if (quick) {
        msg := msg . " (QUICK)"
    }

    ShowModePopup(msg)

    INSERT_MODE := true
    INSERT_QUICK := quick
    NORMAL_MODE := false
    NORMAL_QUICK := false
}

ClickInsert(quick := true) {
    Click
    EnterInsertMode(quick)
}

; TODO
; doesn't really work well
DoubleClickInsert(quick := true) {
    Click
    Sleep(100)
    Click
    EnterInsertMode(quick)
}

ShowModePopup(msg) {
    ; clean up any lingering popups
    ClosePopup()

    center := MonitorLeftEdge() + (A_ScreenWidth // 2)
    popX := center - 150
    popY := (A_ScreenHeight // 2) - 28

    Progress(b x%popX% y%popY% zh0 w300 h56 fm24, , %msg%, , SimSun)
    SetTimer(ClosePopup, -1600)

    POP_UP := true
}

ClosePopup() {
    Progress(Off)
    POP_UP := false
}

Drag() {
    if (DRAGGING) {
        Click(Left, Up)
        DRAGGING := false
    }
    else {
        Click(Left, Down)
        DRAGGING := true
    }
}

RightDrag() {
    if (DRAGGING) {
        Click(Right, Up)
        DRAGGING := false
    }
    else {
        Click(Right, Down)
        DRAGGING := true
    }
}

MiddleDrag() {
    if (DRAGGING) {
        Click(Middle, Up)
        DRAGGING := false
    }
    else {
        Send("{ MButton down }")
        DRAGGING := true
    }
}

ReleaseDrag(button) {
    Click(Middle, Up)
    Click(button)

    DRAGGING := false
}

Yank() {
    wx := 0
    wy := 0
    width := 0

    WinGetPos(wx, wy, width, , A)

    center := wx + width - 180
    y := wy + 12

    ;MsgBox, Hello %width% %center%
    MouseMove(center, y)
    Drag()
}

MouseLeft() {
    Click()
    DRAGGING := false
}

MouseRight() {
    Click(Right)
    DRAGGING := false
}

MouseMiddle() {
    Click(Middle)
    DRAGGING := false
}

; TODO: When we have more monitors, set up H and L to use current screen as basis
; hard to test when I only have the one

JumpMiddle() {
    CoordMode(Mouse, Screen)
    MouseMove(A_ScreenWidth // 2, A_ScreenHeight // 2)
}

JumpMiddle2() {
    CoordMode(Mouse, Screen)
    MouseMove(A_ScreenWidth + A_ScreenWidth // 2, A_ScreenHeight // 2)
}

JumpMiddle3() {
    CoordMode(Mouse, Screen)
    MouseMove(A_ScreenWidth * 2 + A_ScreenWidth // 2, A_ScreenHeight // 2)
}

MonitorLeftEdge() {
    mx := 0

    CoordMode(Mouse, Screen)
    MouseGetPos(mx)

    monitor := (mx // A_ScreenWidth)

    return monitor * A_ScreenWidth
}

JumpLeftEdge() {
    x := MonitorLeftEdge() + 2
    y := 0

    CoordMode(Mouse, Screen)
    MouseGetPos(, y)
    MouseMove(x, y)
}

JumpBottomEdge() {
    x := 0

    CoordMode(Mouse, Screen)
    MouseGetPos(x)
    MouseMove(x, A_ScreenHeight - 0)
}

JumpTopEdge() {
    x := 0

    CoordMode(Mouse, Screen)
    MouseGetPos(x)
    MouseMove(x, 0)
}

JumpRightEdge() {
    x := MonitorLeftEdge() + A_ScreenWidth - 2
    y := 0

    CoordMode(Mouse, Screen)
    MouseGetPos(, y)
    MouseMove(x, y)
}

MouseBack() {
    Click(X1)
}

MouseForward() {
    Click(X2)
}

ScrollUp() {
    Click(WheelUp)
}

ScrollDown() {
    Click(WheelDown)
}

ScrollUpMore() {
    Click(WheelUp)
    Click(WheelUp)
    Click(WheelUp)
    Click(WheelUp)

    return
}

ScrollDownMore() {
    Click(WheelDown)
    Click(WheelDown)
    Click(WheelDown)
    Click(WheelDown)

    return
}

; "FINAL" MODE SWITCH BINDINGS
Home:: EnterNormalMode()
Insert:: EnterInsertMode()
<#<!n:: EnterNormalMode()
<#<!i:: EnterInsertMode()

; escape hatches
+Home:: Send("{ Home }")
+Insert:: Send("{ Insert }")

; TODO doesn't turn capslock off.
; ^Capslock:: Send, { Capslock }
; meh. good enough.
; ^+Capslock:: SetCapsLockState, Off

#HotIf (NORMAL_MODE)
+`:: ClickInsert(false) ; focus window and enter Insert
`:: ClickInsert(true) ; path to Quick Insert
~f:: EnterInsertMode(true) ; passthru for Vimium hotlinks
~^f:: EnterInsertMode(true) ; passthru to common "search" hotkey
~^t:: EnterInsertMode(true) ; passthru for new tab
~Delete:: EnterInsertMode(true) ; passthru for quick edits
+;:: EnterInsertMode(true) ; do not pass thru
h:: return ; intercept movement keys
j:: return
k:: return
l:: return
+H:: JumpLeftEdge()
+J:: JumpBottomEdge()
+K:: JumpTopEdge()
+L:: JumpRightEdge()
*i:: MouseLeft() ; commands
*o:: MouseRight()
*p:: MouseMiddle()
+Y:: Yank() ; do not conflict with y as in "scroll up"
v:: Drag()
z:: RightDrag()
c:: MiddleDrag()
+M:: JumpMiddle()
+,:: JumpMiddle2()
+.:: JumpMiddle3()
m:: JumpMiddle() ; ahh what the heck, remove shift requirements for jump bindings
,:: JumpMiddle2() ; maybe take "m" back if we ever make marks
.:: JumpMiddle3()
n:: MouseForward()
b:: MouseBack()
u:: ScrollUpMore() ; allow for modifier keys (or more importantly a lack of them) by lifting ctrl requirement for these hotkeys
*0:: ScrollDown()
*9:: ScrollUp()
]:: ScrollDown()
[:: ScrollUp()
+]:: ScrollDownMore()
+[:: ScrollUpMore()
End:: Click(Up)

#HotIf (NORMAL_MODE && NORMAL_QUICK == false)
Capslock:: EnterInsertMode(true)
+Capslock:: EnterInsertMode()

; Add Vim hotkeys that conflict with WASD mode
#HotIf (NORMAL_MODE && WASD == false)
<#<!r:: EnterWASDMode()
e:: ScrollDown()
y:: ScrollUp()
d:: ScrollDownMore()
+S:: DoubleClickInsert()

; No shift requirements in normal quick mode
#HotIf (NORMAL_MODE && NORMAL_QUICK)
Capslock:: return
m:: JumpMiddle()
,:: JumpMiddle2()
.:: JumpMiddle3()
y:: Yank()

; for windows explorer
#HotIf (NORMAL_MODE && WinActive("ahk_class CabinetWClass"))
^h:: Send("{ Left }")
^j:: Send("{ Down }")
^k:: Send("{ Up }")
^l:: Send("{ Right }")

#HotIf (INSERT_MODE && INSERT_QUICK == false)
Capslock:: EnterNormalMode(true)
+Capslock:: EnterNormalMode()

#HotIf (INSERT_MODE && INSERT_QUICK)
~Enter:: EnterNormalMode()
~^c:: EnterNormalMode() ; Copy and return to Normal Mode
Escape:: EnterNormalMode()
Capslock:: EnterNormalMode()
+Capslock:: EnterNormalMode()

#HotIf (NORMAL_MODE && WASD)
<#<!r:: ExitWASDMode()
w:: return ; Intercept movement keys
a:: return
s:: return
d:: return
+C:: JumpMiddle()
+W:: JumpTopEdge()
+A:: JumpLeftEdge()
+S:: JumpBottomEdge()
+D:: JumpRightEdge()
*e:: ScrollDown()
*q:: ScrollUp()
*r:: MouseLeft()
t:: MouseRight()
+T:: MouseRight()
*y:: MouseMiddle()

#HotIf (DRAGGING)
LButton:: ReleaseDrag(1)
MButton:: ReleaseDrag(2)
RButton:: ReleaseDrag(3)

#HotIf (POP_UP)
Escape:: ClosePopup()

; Insert Mode by default
EnterInsertMode()

; FUTURE CONSIDERATIONS
; AwaitKey function for vimesque multi keystroke commands (gg, yy, 2M, etc)
; "Marks" for remembering and restoring mouse positions (needs AwaitKey)
; v to let go of mouse when mouse is down with v (lemme crop in Paint.exe)
; z for click and release middle mouse? this has historically not worked well
; c guess that leaves c for hold / release right mouse (x is useful in chromium)
; Whatever you can think of! Github issues and pull requests welcome

; РЕКОМЕНДАЦИИ НА БУДУЩЕЕ
; Функция AwaitKey для команд vimesque с несколькими нажатиями клавиш (gg, yy, 2M и т.д.)
; "Метки" для запоминания и восстановления положения мыши (требуется клавиша ожидания)
; v, чтобы отпустить мышь, когда она нажата с помощью клавиши v (давайте обрежем в Paint.exe)
; z для нажатия и отпускания средней кнопки мыши? исторически это не очень хорошо работало
; c, полагаю, остается c для удержания / отпускания правой кнопки мыши (x полезно в chromium)
