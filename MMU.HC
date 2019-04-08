// vim: set ft=c:

//struct for sprites on the scanline (for secondary OAM)
class PPUsprite {
U8 shifts_remaining;
U8 sprite_index;
U8 byte2;

U8 shift_register_0;
U8 shift_register_1;
U8 attribute;
U8 x;
};

//struct to store the state of the PPU
class PPU2C02state {
U8 odd_frame;
U16 scanline;
U16 dot;

U8 nmi_occurred;

//PPU register values
U8 nmi_output;
U8 sprite_zero_hit;

//more accurate ppu
U16 nametable_base;

U16 bitmap_shift_0_latch;
U16 bitmap_shift_1_latch;

U16 bitmap_shift_0;
U16 bitmap_shift_1;


U16 AT_shift_0_latch;
U16 AT_shift_1_latch;
U16 AT_shift_0;
U16 AT_shift_1;

U8 num_sprites;
PPUsprite sprites[8];
};

PPU2C02state PPU_state;

class memory_manager {
U8 *RAM;
U8 *VRAM;
U8 *OAM;

U8 w;
U16 t;
U16 x;
U16 y;

U16 VRAM_address;
U8 internal_buffer;
};

memory_manager MMU;

// Mapper #1 [MMC1]

// 5-bit buffer:
I64 MMC1_regBuffer = 0;
I64 MMC1_regBufferCounter = 0;
// Register 0:
I64 MMC1_mirroring = 0;
I64 MMC1_oneScreenMirroring = 0;
I64 MMC1_prgSwitchingArea = 1;
I64 MMC1_prgSwitchingSize = 1;
I64 MMC1_vromSwitchingSize = 0;
// Register 1:
I64 MMC1_romSelectionReg0 = 0;
// Register 2:
I64 MMC1_romSelectionReg1 = 0;
// Register 3:
I64 MMC1_romBankSelect = 0;

I64 MMC1_getRegNumber(U16 address)
{
	if (address >= 0x8000 && address <= 0x9fff) {
		return 0;
	} else if (address >= 0xa000 && address <= 0xbfff) {
		return 1;
	} else if (address >= 0xc000 && address <= 0xdfff) {
		return 2;
	} else {
		return 3;
	}
}

U0 MMC1_loadRomBank(I64 bank, U16 address)
{

}

U0 MMC1_loadVromBank(I64 bank, U16 address)
{

}

U0 MMC1_load32kRomBank(I64 bank, U16 address)
{

}

U0 MMC1_load8kVromBank(I64 bank, U16 address)
{

}

U0 MMC1_setReg(I64 _reg, I64 value)
{
	I64 tmp;
	switch (_reg) {
	case 0:
		// Mirroring:
		tmp = value & 3;
		if (tmp != MMC1_mirroring) {
			// Set mirroring:
			MMC1_mirroring = tmp;
			/* TODO: mirroring
			   if ((MMC1_mirroring & 2) == 0) {
			   // SingleScreen mirroring overrides the other setting:
			   MMC1_nes.ppu.setMirroring(MMC1_nes.rom.SINGLESCREEN_MIRRORING);
			   } else if ((MMC1_mirroring & 1) != 0) {
			   // Not overridden by SingleScreen mirroring.
			   MMC1_nes.ppu.setMirroring(MMC1_nes.rom.HORIZONTAL_MIRRORING);
			   } else {
			   MMC1_nes.ppu.setMirroring(MMC1_nes.rom.VERTICAL_MIRRORING);
			   }
			 */
		}
		// PRG Switching Area;
		MMC1_prgSwitchingArea = (value >> 2) & 1;
		// PRG Switching Size:
		MMC1_prgSwitchingSize = (value >> 3) & 1;
		// VROM Switching Size:
		MMC1_vromSwitchingSize = (value >> 4) & 1;
		break;
	case 1:
		// ROM selection:
		MMC1_romSelectionReg0 = (value >> 4) & 1;
		// Check whether the cart has VROM:
		if (numCHRROM > 0) {
			// Select VROM bank at 0x0000:
			if (MMC1_vromSwitchingSize == 0) {
				// Swap 8kB VROM:
				if (MMC1_romSelectionReg0 == 0) {
					MMC1_load8kVromBank(value & 0xf, 0x0000);
				} else {
					MMC1_load8kVromBank(
					        Floor(numCHRROM / 2) + (value & 0xf),
					        0x0000
					        );
				}
			} else {
				// Swap 4kB VROM:
				if (MMC1_romSelectionReg0 == 0) {
					MMC1_loadVromBank(value & 0xf, 0x0000);
				} else {
					MMC1_loadVromBank(
					        Floor(numCHRROM / 2) + (value & 0xf),
					        0x0000
					        );
				}
			}
		}
		break;
	case 2:
		// ROM selection:
		MMC1_romSelectionReg1 = (value >> 4) & 1;
		// Check whether the cart has VROM:
		if (numCHRROM > 0) {
			// Select VROM bank at 0x1000:
			if (MMC1_vromSwitchingSize == 1) {
				// Swap 4kB of VROM:
				if (MMC1_romSelectionReg1 == 0) {
					MMC1_loadVromBank(value & 0xf, 0x1000);
				} else {
					MMC1_loadVromBank(
					        Floor(numCHRROM / 2) + (value & 0xf),
					        0x1000
					        );
				}
			}
		}
		break;
	default:
		// Select ROM bank:
		// -------------------------
		tmp = value & 0xf;
		I64 bank;
		I64 baseBank = 0;
		if (numPRGROM >= 32) {
			// 1024 kB cart
			if (MMC1_vromSwitchingSize == 0) {
				if (MMC1_romSelectionReg0 == 1) {
					baseBank = 16;
				}
			} else {
				baseBank =
				        (MMC1_romSelectionReg0 | (MMC1_romSelectionReg1 << 1)) << 3;
			}
		} else if (numPRGROM >= 16) {
			// 512 kB cart
			if (MMC1_romSelectionReg0 == 1) {
				baseBank = 8;
			}
		}
		if (MMC1_prgSwitchingSize == 0) {
			// 32kB
			bank = baseBank + (value & 0xf);
			MMC1_load32kRomBank(bank, 0x8000);
		} else {
			// 16kB
			bank = baseBank * 2 + (value & 0xf);
			if (MMC1_prgSwitchingArea == 0) {
				MMC1_loadRomBank(bank, 0xc000);
			} else {
				MMC1_loadRomBank(bank, 0x8000);
			}
		}
	}
}

U0 MMC1_Write(U16 address, U8 value)
{
	// See what should be done with the written value:
	if ((value & 128) != 0) {
		// Reset buffering:
		MMC1_regBufferCounter = 0;
		MMC1_regBuffer = 0;
		// Reset register:
		if (MMC1_getRegNumber(address) == 0) {
			MMC1_prgSwitchingArea = 1;
			MMC1_prgSwitchingSize = 1;
		}
	} else {
		// Continue buffering:
		//regBuffer = (regBuffer & (0xFF-(1<<regBufferCounter))) | ((value & (1<<regBufferCounter))<<regBufferCounter);
		MMC1_regBuffer =
		        (MMC1_regBuffer & (0xff - (1 << MMC1_regBufferCounter))) |
		        ((value & 1) << MMC1_regBufferCounter);
		MMC1_regBufferCounter++;
		if (MMC1_regBufferCounter == 5) {
			// Use the buffered value:
			MMC1_setReg(MMC1_getRegNumber(address), MMC1_regBuffer);
			// Reset buffer:
			MMC1_regBuffer = 0;
			MMC1_regBufferCounter = 0;
		}
	}
}

U0 initMMU() {
	MMU.RAM = MAlloc(0xFFFF);
	MMU.VRAM = MAlloc(0xFFFF);
	MMU.OAM = MAlloc(0xFF);

	MemSet( MMU.OAM, 0xFF, 0xFF );

	MMU.internal_buffer = 0;
	MMU.VRAM_address = 0;

	MMU.w = 0;
	MMU.t = 0;
}

U0 writeVRAM(U16 address, U8 value) {
	//assert(address <= 0x3F20);
	MMU.VRAM[address] = value;
	if( address == 0x3F10 || address == 0x3F14 || address == 0x3F18 || address == 0x3F1C ) {
		address -= 0x10;
	}
	address &= 0x3FFF;
	MMU.VRAM[address] = value;
}

U8 readVRAM(U16 address) {
	//assert(address <= 0x3F20);
	if( address == 0x3F10 || address == 0x3F14 || address == 0x3F18 || address == 0x3F1C ) {
		address -= 0x10;
	}
	address &= 0x3FFF;
	return MMU.VRAM[address];
}

U0 writeSPRRAM(U8 address, U8 value) {
	MMU.OAM[address] = value;
}
U8 readSPRRAM(U8 address) {
	return MMU.OAM[address];
}

U8 writeRAM(U16 address, U8 value) {
	U16 val;
	while(address >= 0x2008 && address < 0x4000) {
		address -= 8;
	}
	while(address >= 0x0800 && address < 0x2000) {
		address -= 0x0800;
	}

	if( (address >= 0x2000 && address <= 0x2007 && value != 0) || address == 0x4014 ) {
		if( address == 0x2003 ) {
			//assert(1 == 0);
		}
	}

	//PPUMASK
	if(address == 0x2000) {
		val = value&3;
		MMU.t &= 0xF3FF;
		MMU.t |= (val << 10);
		PPU_state.nmi_output = ((value & (1<<7)) >> 7);
	}

	//OAMDATA
	else if(address == 0x2004) {
		MMU.OAM[0x2003] = value;
		MMU.OAM[0x2003] += 1;
	}

	//PPUSCROLL
	else if(address == 0x2005) {
		if( MMU.w == 0 ) {
			MMU.t &= ~31; // 31 = 11111b
			MMU.t |= ((value&248) >> 3);
			MMU.x = (value & 7);
			//printf("setting coarse X to %d on scanline %d\n", ((value&248) >> 3), PPU_state.scanline);
		}
		else {
			//t: CBA..HG FED..... = d: HGFEDCBA
			MMU.t &= 3103; //3103 = 0000110000011111b
			val = value;
			MMU.t |= ((val & 7) << 12); //CBA
			MMU.t |= ((val & 248) << 2); //HGFED
		}
		MMU.w ^= 1;
	}

	//PPUADDR
	else if(address == 0x2006) {
		if( MMU.w == 0 ) {
			MMU.t &= 0x00FF;
			val = value;
			val <<= 8;
			MMU.t |= val;
		}
		else {
			MMU.t &= 0xFF00;
			MMU.t |= value;
			MMU.VRAM_address = MMU.t;
		}
		MMU.w ^= 1;
		//MMU.VRAM_address = ((MMU.VRAM_address << 8) | value);
	}

	//PPUDATA
	else if(address == 0x2007) {
		writeVRAM( (MMU.VRAM_address&0x3FFF), value );
		if( (MMU.RAM[0x2000] & 4) == 0 ) {
			MMU.VRAM_address += 1;
		}
		else {
			MMU.VRAM_address += 32;
		}
	}

	//OAMDMA
	else if(address == 0x4014) {
		I64 i;
		for(i=0; i<=0xFF; ++i) {
			writeSPRRAM(i, MMU.RAM[(value << 8)|i] );
		}
		return 513 + PPU_state.odd_frame; //I think?
	}

	//Joypad 1
	else if(address == 0x4016) {
		writeJoypad(&NES_Joypad, value);
	}

	else if(address > 0x7FFF) {
		switch (mapper)
		{
		case 1:
			MMC1_Write(address, value);
			return 0;
			break;
		default:
			break;
		}
	}

	MMU.RAM[address] = value;
	return 0;
}

U8 readRAM(U16 address) {
	while(address >= 0x2008 && address < 0x4000) {
		address -= 8; //handle mirroring
	}
	while(address >= 0x0800 && address < 0x2000) {
		address -= 0x0800; //handle mirroring
	}

	U8 retVal = MMU.RAM[address];

	//PPUSTATUS
	if(address == 0x2002) {
		MMU.w = 0;
		retVal = ((PPU_state.sprite_zero_hit << 6) | (PPU_state.nmi_occurred << 7));
		PPU_state.nmi_occurred = 0;
		if(PPU_state.scanline == 241 && PPU_state.dot == 1) {
			retVal = (PPU_state.sprite_zero_hit << 6);
		}
	}

	//OAMDATA
	if(address == 0x2004) {
		return MMU.OAM[0x2003];
	}

	//PPUDATA
	else if(address == 0x2007) {
		//emulate 1 byte delay
		if( MMU.VRAM_address <= 0x3EFF ) {
			retVal = MMU.internal_buffer;
			MMU.internal_buffer = readVRAM( MMU.VRAM_address&0x3FFF );
		}
		else{
			MMU.internal_buffer = readVRAM( MMU.VRAM_address&0x3FFF );
			retVal = MMU.internal_buffer;
		}
		//increment address
		if( (MMU.RAM[0x2000] & 4) == 0 ) {
			MMU.VRAM_address += 1;
		}
		else {
			MMU.VRAM_address += 32;
		}
	}

	//Joypad 1
	else if(address == 0x4016) {
		retVal = getNextButton(&NES_Joypad);
	}

	return retVal;
}

U0 dumpRAM() {
	U16 address = 0;
	U16 count = 0;
	"\nDump of RAM:\n";
	for( address=0x3F00; address<=0x3F20; ++address) {
		if( count % 16 == 0 ) {
			"\n%X: ", address;
		}
		"%X, ", MMU.VRAM[address];
		count += 1;
	}
	"\n";
}

U0 dumpSPRRAM() {
	U16 address = 0;
	U16 count = 0;
	"Dump of SPRRAM:\n";
	for( address=0; address<=0xFF; ++address) {
		if( count % 16 == 0 ) {
			"\n%X: ", address;
		}
		"%X, ", MMU.OAM[address];
		count += 1;
	}
	"\n";
}

U0 dumpVRAM() {
	"Dump of interesting VRAM:\n";
	U16 count = 0;
	U16 address = 0;
	for( address=0x2000; address<0x23FF; ++address) {
		if( count % 16 == 0 ) {
			"\n%X: ", address;
		}
		"%X, ", MMU.VRAM[address];
		count += 1;
	}
}
