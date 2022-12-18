# Snek - A simple Linux console mode snake game in X86-64 Assembler

## Overview

A small project to learn assembler. A retro snake game like on the old Nokia phones, implemented in Linux terminal without any libraries, just plain ´syscall´ and terminal escape codes (I know that you are not supposed to do it like this). The score table is memory mapped in and conyains 3 characters per player for initials and 1 byte for the score for extra retro feel. The initial score table was just written in hexeditor, so no initialization routine neccessary. The whole thing runs in a Docker container.   

## Instructions
./run_container.sh

WASD steers, collect the red apple, avoid snake and walls

## Status
- The score table is still read only
- Otherwise the game is playable
- There is some bug that corrupts the first letter of the score table sometimes
- It is a known limitation that after the score goes past 99 the score counter will be funky. This is a lovely retro throwback and will probably not be fixed (doesn't add any value to the project)


