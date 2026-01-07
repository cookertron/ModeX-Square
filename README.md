# VGA Mode X Page Flipping Demo

A bare-metal x86 assembly implementation of a VGA Mode X (320x240) rendering engine. This project demonstrates advanced VGA programming techniques, including planar memory management and hardware-based double buffering, providing a stable foundation for retro graphics development in Real Mode DOS.

## Features

* **High-Resolution Mode X:** Initializes the VGA into the undocumented 320x240 resolution with 256 colors.
* **Square Pixels:** Provides a 1:1 pixel aspect ratio (unlike standard Mode 13h), ideal for geometric drawing and sprite rotation.
* **Planar Memory Addressing:** Unchains video memory to access the full 256KB of VRAM, enabling 4-plane parallel writes for accelerated filling.
* **Hardware Page Flipping:** Implements true double buffering by manipulating the CRT Controller (CRTC) Start Address registers, allowing for instant, zero-copy frame switching.
* **Abrash-Style Synchronization:** Uses a robust "Display Enable + VSync" latching sequence to ensure tear-free animation and stable 60Hz vertical timing.
* **Full-Screen Buffering:** Correctly configures the 10-bit Line Compare registers to prevent split-screen artifacts, ensuring the entire 320x240 frame is double-buffered.
* **Dual Assembler Support:** Source code provided for both **Microsoft MASM** (`MXSQR_MS.ASM`) and **Borland TASM** (`MXSQR_BL.ASM`).

## Demo Functionality

The program performs the following operations:
1.  Enters Mode X (320x240).
2.  Allocates two video pages (Page 0 at offset `0`, Page 1 at offset `19200`).
3.  Draws a blue (Index 0x01) square in the center of the hidden page.
4.  Flips the visible page during the vertical blanking interval.
5.  Repeats the cycle to demonstrate flicker-free animation.

## Build Instructions

### Microsoft MASM (6.11 or later)
```cmd
ml /c MXSQR_MS.ASM
link MXSQR_MS.OBJ;

### Borland TASM (5.0 or later)
tasm /m MXSQR_BL.ASM
tlink MXSQR_BL.OBJ
```
