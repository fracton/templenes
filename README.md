# templenes
NES Emulator for TempleOS

This is a work in progress. Currently, only Mapper #0 games work, and things are buggy. Tested on bare-metal and VirtualBox 6.0, YMMV.

The emulator runs in 320x200 256 color video mode. Since NES display resolution exceeds these boundaries, there is an option to view 1:1 (topmost pixels not visible) or Scale2Fit, which scales the image to the 320x200 viewport, albeit with loss of quality.

[![templenes](https://raw.githubusercontent.com/obecebo/templenes/master/video_link.png "NES Emulator for TempleOS") ](https://www.youtube.com/watch?v=dx-fVPUeuYs)

CPU is a modified version of [fake6502](http://rubbermallet.org/fake6502.c) converted to HolyC.

PPU/MMU is a modified version of [NESlig](https://github.com/toblu302/NESlig) converted to HolyC; SDL function calls replaced with built-in or TOSGame Lib equivalents.
# Usage

```
	#include "Run";
	TempleNES("path_to_rom_file.nes");
```

# TODO

- Mappers

- Sound

- GUI Dialog boxes  and other menu options

- Everything else