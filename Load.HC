// vim: set ft=c:

CDoc *doc_tmp=DocNew;
CDoc *doc_prev=Fs->put_doc;

CTask *draw_task=NULL;
CSprite *vid;
CDC *gameCanvas=DCNew(320,240);
DCFill(gameCanvas,0);

CDC *scr_pillar = DCNew(32,200);
DCFill(scr_pillar,0);

Bool fit_screen = FALSE;

I64 RoundUp(I64 numToRound, I64 multiple)
{
	if (multiple == 0)
	{
		return numToRound;
	}
	I64 remainder = numToRound % multiple;
	if (remainder == 0)
	{
		return numToRound;
	}
	return numToRound + multiple - remainder;
}

Bool reset = FALSE;
Bool quit = FALSE;
Bool paused = FALSE;
U8 cycles=0;
U8 loop=0;
U8 frame_finished=0;
U8 tmp_str[256];

#include "TOSGame";
#include "GUI";

//Hide 64-bit reg var compiler warnings.
Fs->put_doc=doc_tmp;

U8 *cartridgebuffer;

I64 numPRGROM;
I64 numCHRROM;
I64 controlByte1;
I64 controlByte2;
I64 numRAM;
I64 trainer;
I64 mapper;

#include "Joypad";
#include "MMU";
#include "CPU";
#include "PPU";

U0 handleResetButton()
{
	if (TG_KeyDown(Char2ScanCode('r')))
	{
		frame_count=0;
		reset6502;

		//initalize the PPU
		initPPU2C02(&PPU_state);

		//initalize the Joypad
		initJoypad(&NES_Joypad);
	}
	if (TG_KeyDown(Char2ScanCode('d')))
	{
		TG_Exit;
		Dbg;
	}
}

U0 resetSystem()
{
	frame_count=0;
	reset6502;
	//initalize the PPU
	initPPU2C02(&PPU_state);
	//initalize the Joypad
	initJoypad(&NES_Joypad);
}

U0 doScreenUpdate()
{
	if (fit_screen)
	{
		vid=DC2Sprite(gameCanvas);
		Sprite3XB(TG_Canvas, 0, 0, 0, vid, .58);
		Free(vid);
	}
	else
	{
		GrBlot(TG_Canvas, 0, 0, gameCanvas);
		GrBlot(TG_Canvas,0,0,scr_pillar);
		GrBlot(TG_Canvas,288,0,scr_pillar);
	}
	UpdateGUI;
	TG_Flip;
}

U0 drawScreen()
{
	while (1)
	{
		if( frame_finished ) {
			frame_count += 1;
			doScreenUpdate;
		}
		if ( paused )
		{
			doScreenUpdate;
		}
	}
}

I64 TempleNES(U8 *rom_filename)
{
	CDirEntry *chk_file=FilesFind(rom_filename);
	if( !chk_file ) {
		PrintErr("iNES ROM file not found.\n");
		return 1;
	}
	DirTreeDel(chk_file);

	cartridgebuffer = FileRead(rom_filename);

	//if the file is not an iNES-file, abort
	if(cartridgebuffer[0] != 'N' || cartridgebuffer[1] != 'E' || cartridgebuffer[2] != 'S' || cartridgebuffer[3] != 0x1a) {
		PrintErr("File is not an iNES-file.\n");
	}

	numPRGROM = cartridgebuffer[4];
	numCHRROM = cartridgebuffer[5];
	controlByte1 = cartridgebuffer[6];
	controlByte2 = cartridgebuffer[7];
	numRAM = cartridgebuffer[8];

	trainer = (controlByte1 & (1 << 2));

	mapper = ( (controlByte2 & 0xF0) | ((controlByte1 & 0xF0) >> 4));

	initMMU();

	switch (mapper)
	{
	case 0:
		//Copy the ROM into the CPU's memory
		MemCpy(MMU.RAM+0x8000, cartridgebuffer+0x10, numPRGROM*0x4000);
		if(numPRGROM == 1) {
			MemCpy(MMU.RAM+0xC000, cartridgebuffer+0x10, numPRGROM*0x4000);
		}
		//Copy the ROM into the PPU's memory
		MemCpy(MMU.VRAM, cartridgebuffer+0x10+0x4000*numPRGROM, 0x2000*numCHRROM);
		break;
	case 1:
		//Load first PRG ROM bank
		MemCpy(MMU.RAM+0x8000, cartridgebuffer+0x10, 0x4000);
		//and last PRG ROM bank
		MemCpy(MMU.RAM+0xC000, cartridgebuffer+0x10+0x4000*(numPRGROM-1), 0x4000);
		//Copy the ROM into the PPU's memory
		MemCpy(MMU.VRAM, cartridgebuffer+0x10+0x4000*numPRGROM, 0x2000*numCHRROM);
		break;
	default:
		break;
	}

	//initalize the CPU
	reset6502;

	//initalize the PPU
	initPPU2C02(&PPU_state);

	//initalize the Joypad
	initJoypad(&NES_Joypad);

	//Initalize TOSGame
	TG_Start;

	//Initialize palette
	PPU_InitPalette;

	draw_task = Spawn(&drawScreen,,,1);

	while(!quit) {
		WinMsUpdate;
		KbdMsHndlr(FALSE, FALSE);

		//emulate CPU and PPU
		frame_finished = 0;

		if( paused == 0 ) {
			exec6502(1);
			cycles = ticktable[opcode];
			loop = cycles*3;
			while( loop != 0 )
			{
				frame_finished |= PPUcycle(&PPU_state);
				loop -= 1;
			}
		}

		if (reset)
		{
			resetSystem;
			reset = FALSE;
		}
		handleResetButton;
		handleInput(&NES_Joypad);
	}
	quit = FALSE;
	Kill(draw_task);
	DocClear;
	Free(cartridgebuffer);
	TG_Exit;
	return 0;
}

Fs->put_doc=doc_prev;