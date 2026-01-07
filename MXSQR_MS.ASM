; ===========================================================================
; VGA Mode X Demo: MASM Compatible Version
; 320x240 Square with Abrash-Style Hardware Page Flipping
; ===========================================================================

.MODEL SMALL
.STACK 200h

.DATA
    SC_INDEX     EQU 03C4h   
    CRTC_INDEX   EQU 03D4h   
    MISC_OUT     EQU 03C2h   
    INPUT_STATUS EQU 03DAh  

    ; CRTC Timing for 320x240 (Abrash Standard)
    crtc_vals   db 06h, 00Dh    ; Vertical Total
                db 07h, 03Eh    ; Overflow
                db 09h, 041h    ; Max Scan (Cell Height=2, Split Screen Fixed)
                db 10h, 0EAh    ; VSync Start
                db 11h, 0ACh    ; VSync End
                db 12h, 0DFh    ; VDisplay End
                db 14h, 000h    ; Underline
                db 15h, 0E7h    ; VBlank Start
                db 16h, 006h    ; VBlank End
                db 17h, 0E3h    ; Mode Control
    
    SCREEN_SEG  EQU 0A000h
    PAGE_SIZE   EQU 19200   

    CurrentPage db 0        

.CODE
Start:
    mov ax, @data
    mov ds, ax

    ; --- Step 1: Set Mode 13h ---
    mov ax, 0013h
    int 10h

    ; --- Step 2: Unchain VGA ---
    mov dx, SC_INDEX
    mov ax, 0604h
    out dx, ax

    ; --- Step 3: Unlock CRTC ---
    mov dx, CRTC_INDEX
    mov al, 11h
    out dx, al
    inc dx
    in  al, dx
    and al, 7Fh
    out dx, al
    dec dx

    ; --- Step 4: Load 320x240 Timing ---
    cld
    mov si, offset crtc_vals
    mov cx, 10
LoadCRTC:
    lodsw
    out dx, ax
    loop LoadCRTC

    ; --- Step 5: Select 25MHz Clock ---
    mov dx, MISC_OUT
    mov al, 0E3h
    out dx, al

    ; --- Step 6: Clear VRAM ---
    mov dx, SC_INDEX
    mov ax, 0F02h
    out dx, ax
    mov ax, SCREEN_SEG
    mov es, ax
    xor di, di
    xor ax, ax
    mov cx, 8000h
    rep stosw

; ===========================================================================
; MAIN LOOP
; ===========================================================================
MainLoop:
    cmp CurrentPage, 0      ; MASM syntax: no brackets needed for scalar checks usually, but [] is fine too
    je  DrawToPage1
    
DrawToPage0:
    mov di, 0
    jmp StartDraw

DrawToPage1:
    mov di, PAGE_SIZE

StartDraw:
    ; Clear Hidden Page
    push di
    mov dx, SC_INDEX
    mov ax, 0F02h
    out dx, ax
    xor ax, ax
    mov cx, PAGE_SIZE
    rep stosb
    pop di

    ; Draw Square
    push di
    add di, 5627
    mov bx, 100
    mov al, 01h
    
DrawSquareLoop:
    push di
    mov cx, 25
    rep stosb
    pop di
    add di, 80
    dec bx
    jnz DrawSquareLoop
    pop di

    ; --- FLIP PAGES ---
    cmp CurrentPage, 0
    je  ShowPage1

ShowPage0:
    mov bx, 0000h
    mov CurrentPage, 0
    jmp DoFlip

ShowPage1:
    mov bx, 4B00h
    mov CurrentPage, 1

DoFlip:
    ; Wait for Display Enable (Active Low)
    mov dx, INPUT_STATUS
WaitDE:
    in al, dx
    test al, 01h
    jnz WaitDE

    ; Set Registers
    mov dx, CRTC_INDEX
    mov al, 0Ch
    mov ah, bh
    out dx, ax
    mov al, 0Dh
    mov ah, bl
    out dx, ax

    ; Wait for VSync
    mov dx, INPUT_STATUS
WaitVS:
    in al, dx
    test al, 08h
    jz WaitVS

    ; Exit Check
    mov ah, 01h
    int 16h
    jz MainLoop

    mov ah, 00h
    int 16h
    mov ax, 0003h
    int 10h
    mov ax, 4C00h
    int 21h

END Start