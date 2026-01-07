; ===========================================================================
; VGA Mode X Demo: 320x240 Square with Abrash-Style Hardware Page Flipping
; Adapted from SQUARE.ASM and Michael Abrash's "Mode X Page Switch"
; ===========================================================================

IDEAL
MODEL small
STACK 200h

DATASEG
    SC_INDEX    EQU 03C4h   ; Sequencer Index
    CRTC_INDEX  EQU 03D4h   ; CRT Controller Index
    MISC_OUT    EQU 03C2h   ; Misc Output Port 
    INPUT_STATUS EQU 03DAh  ; Input Status #1 Register

    ; CRTC Timing for 320x240 (Abrash Standard)
    ; Format: Index, Value
    crtc_vals   db 06h, 00Dh    ; Vertical Total
                db 07h, 03Eh    ; Overflow
                db 09h, 041h    ; Max Scan (Cell Height=2, Split Screen Fixed)
                db 10h, 0EAh    ; VSync Start
                db 11h, 0ACh    ; VSync End (Locks Regs 0-7)
                db 12h, 0DFh    ; VDisplay End
                db 14h, 000h    ; Underline (Disable DWORD)
                db 15h, 0E7h    ; VBlank Start
                db 16h, 006h    ; VBlank End
                db 17h, 0E3h    ; Mode Control (Byte Mode)
    
    SCREEN_SEG  EQU 0A000h
    PAGE_SIZE   EQU 19200   ; 76,800 pixels / 4 planes = 19,200 bytes

    CurrentPage db 0        ; 0 = Displaying Page 0, 1 = Displaying Page 1

CODESEG
    ASSUME CS:@code, DS:@data

Start:
    mov ax, @data
    mov ds, ax

    ; --- Step 1: Set Mode 13h as Baseline ---
    mov ax, 0013h
    int 10h

    ; --- Step 2: Unchain VGA (Disable Chain-4) ---
    mov dx, SC_INDEX
    mov ax, 0604h       ; Index 04 (Memory Mode), Data 06
    out dx, ax

    ; --- Step 3: Disable CRTC Write Protect ---
    mov dx, CRTC_INDEX
    mov al, 11h
    out dx, al
    inc dx
    in  al, dx
    and al, 7Fh         ; Clear bit 7 to unlock registers
    out dx, al
    dec dx

    ; --- Step 4: Load 320x240 Timing Parameters ---
    cld
    mov si, offset crtc_vals
    mov cx, 10          ; Count = 10 registers
LoadCRTC:
    lodsw               ; AL=Index, AH=Value
    out dx, ax
    loop LoadCRTC

    ; --- Step 5: Select 25MHz Clock ---
    mov dx, MISC_OUT
    mov al, 0E3h        ; Bits 2-3 = 00 (25MHz)
    out dx, al

    ; --- Step 6: Clear VRAM (Full 64KB for both pages) ---
    mov dx, SC_INDEX
    mov ax, 0F02h       ; Map Mask: Enable all 4 planes
    out dx, ax
    mov ax, SCREEN_SEG
    mov es, ax
    xor di, di
    xor ax, ax
    mov cx, 8000h       ; Clear 32K words (64KB total)
    rep stosw

; ===========================================================================
; MAIN ANIMATION LOOP
; ===========================================================================
MainLoop:
    ; 1. Logic: If we are showing Page 0, we draw to Page 1 (Hidden)
    ;           If we are showing Page 1, we draw to Page 0 (Hidden)
    cmp [CurrentPage], 0
    je  DrawToPage1
    
DrawToPage0:
    mov di, 0               ; Offset 0
    jmp StartDraw

DrawToPage1:
    mov di, PAGE_SIZE       ; Offset 19200

StartDraw:
    ; 2. Clear the Hidden Page Background (Black)
    push di                 ; Save start of page
    mov dx, SC_INDEX
    mov ax, 0F02h           ; Ensure write to all planes
    out dx, ax
    xor ax, ax              ; Color 0
    mov cx, PAGE_SIZE       ; Clear 19,200 bytes
    rep stosb
    pop di                  ; Restore start of page

    ; 3. Draw Square on Hidden Page
    ;    Center (110, 70). Byte Offset = (70 * 80) + 27 = 5627 relative to page start
    push di
    add di, 5627            ; Move DI to top-left of square
    
    mov bx, 70              ; Y used for loop calc in original, but here used as counter?
                            ; Actually, let's use a simpler loop for the square
    mov bx, 100             ; Height = 100 lines
    mov al, 01h             ; Color 1 (Blue)
    
DrawSquareLoop:
    push di                 ; Save start of line
    mov cx, 25              ; 100 pixels / 4 planes = 25 bytes wide
    rep stosb               ; Draw line
    pop di                  ; Restore start of line
    add di, 80              ; Move down one scanline (80 bytes)
    dec bx
    jnz DrawSquareLoop
    
    pop di                  ; Clean up stack (pop the page start we pushed earlier)

    ; 4. FLIP PAGES (Michael Abrash Method)
    ;    We want to show the page we just drew to.
    
    cmp [CurrentPage], 0
    je  ShowPage1           ; If curr=0, we drew to 1, so show 1.

ShowPage0:
    mov bx, 0000h           ; High=00, Low=00
    mov [CurrentPage], 0
    jmp DoFlip

ShowPage1:
    mov bx, 4B00h           ; High=4B (19200 >> 8), Low=00
    mov [CurrentPage], 1

DoFlip:
    ; A. Wait for Display Enable (Active Low) 
    ;    This ensures we are in the active display area, not retrace.
    mov dx, INPUT_STATUS
WaitDE:
    in al, dx
    test al, 01h            ; Bit 0: 1=Display Disabled (Retrace), 0=Display Enabled
    jnz WaitDE              ; Wait until it is 0 (Active)

    ; B. Set Start Address Registers (Index 0Ch and 0Dh)
    mov dx, CRTC_INDEX
    
    ; Set High Byte
    mov al, 0Ch
    mov ah, bh              ; High byte of offset (00h or 4Bh)
    out dx, ax

    ; Set Low Byte
    mov al, 0Dh
    mov ah, bl              ; Low byte of offset (00h)
    out dx, ax

    ; C. Wait for VSync (Active High)
    ;    This ensures the flip happens cleanly at the next frame start.
    mov dx, INPUT_STATUS
WaitVS:
    in al, dx
    test al, 08h            ; Bit 3: 1=Vertical Retrace
    jz WaitVS               ; Wait until it is 1

    ; 5. Check for Keypress to Exit
    mov ah, 01h
    int 16h
    jz MainLoop

    ; Exit Cleanup
    mov ah, 00h             ; Consume key
    int 16h
    mov ax, 0003h           ; Return to text mode
    int 10h
    mov ax, 4C00h           ; Exit to DOS
    int 21h

END Start