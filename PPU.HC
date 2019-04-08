// vim: set ft=c:

#define FRAME_RATE 60

U32 pixelWidth = 2;
U32 pixelHeight = 2;
U32 ppu_colors[64] =
{
	0x757575, 0x271B8F, 0x0000AB, 0x47009F, 0x8F0077, 0xAB0013, 0xA70000, 0x7F0B00, 0x432F00, 0x004700, 0x005100, 0x003F17, 0x1B3F5F, 0x000000, 0x000000, 0x000000,
	0xBCBCBC, 0x0073EF, 0x233BEF, 0x8300F3, 0xBF00BF, 0xE7005B, 0xDB2B00, 0xCB4F0F, 0x8B7300, 0x009700, 0x00AB00, 0x00933B, 0x00838B, 0x000000, 0x000000, 0x000000,
	0xFFFFFF, 0x3FBFFF, 0x5F97FF, 0xA78BFD, 0xF77BFF, 0xFF77B7, 0xFF7763, 0xFF9B3B, 0xF3BF3F, 0x83D313, 0x4FDF4B, 0x58F898, 0x00EBDB, 0x000000, 0x000000, 0x000000,
	0xFFFFFF, 0xABE7FF, 0xC7D7FF, 0xD7CBFF, 0xFFC7FF, 0xFFC7DB, 0xFFBFB3, 0xFFDBAB, 0xFFE7A3, 0xE3FFA3, 0xABF3BF, 0xB3FFCF, 0x9FFFF3, 0x000000, 0x000000, 0x000000
};

U0 PPU_InitPalette()
{
	I64 i;
	for (i=0; i<64; i++)
	{
		TG_ColorSet(16+i, ppu_colors[i].u8[2], ppu_colors[i].u8[1], ppu_colors[i].u8[0]);
	}
}

U8 rendering_enabled() {
	return MMU.RAM[0x2001] & ((1<<3)|(1<<4));
}

U0 horinc() {
	if ((MMU.VRAM_address & 0x001F) == 0x001F) {
		MMU.VRAM_address &= ~0x001F;
		MMU.VRAM_address ^= 0x0400;
	}
	else {
		MMU.VRAM_address += 1;
	}
}

U0 verinc() {
	if ((MMU.VRAM_address & 0x7000) != 0x7000) {
		MMU.VRAM_address += 0x1000;
	}
	else {
		MMU.VRAM_address &= ~0x7000;
		U16 y = ((MMU.VRAM_address & 0x03E0) >> 5);
		if (y == 29) {
			y = 0;
			MMU.VRAM_address ^= 0x0800;
		}
		else if (y == 31) {
			y = 0;
		}
		else {
			y += 1;
		}
		MMU.VRAM_address = ((MMU.VRAM_address & ~0x03E0) | (y << 5));
	}
}

U0 setPixelColor(I64 x, I64 y, I64 color) {
	U8 *pixel=TG_Canvas->body;
	I64 dx = 0, dy=0;
	for(dx=0; dx<pixelWidth; ++dx) {
		for(dy=0; dy<pixelHeight; ++dy) {
			if (fit_screen)
			{
				gameCanvas->color = 16+color.u8[0];
				GrPlot(gameCanvas, x+32, y);
			}
			else
			{
				gameCanvas->color = 16+color.u8[0];
				GrPlot(gameCanvas, x+32, y-24);
			}
		}
	}
}

I64 getActiveSpriteIndex(PPU2C02state *state) {
	U8 i;
	for(i=0; i<state->num_sprites; ++i) {
		if( state->sprites[i].x == 0 && state->sprites[i].shifts_remaining > 0 ) {
			U8 bit_0 = (state->sprites[i].shift_register_0 & (1 << 7)) >> 7;
			U8 bit_1 = (state->sprites[i].shift_register_1 & (1 << 7)) >> 7;
			U8 bg_color_index = (bit_1 << 1) | bit_0;
			if( bg_color_index > 0 ) {
				return i;
			}
		}
	}
	return -1;
}

/******************
* fetching values
******************/

U16 getSpritePaletteBase(U8 attribute_value) {
	switch(attribute_value) {
	case 0:
		return 0x3F10;
	case 1:
		return 0x3F14;
	case 2:
		return 0x3F18;
	case 3:
		return 0x3F1C;
	}
}

U16 getBackgroundPaletteBase(U16 attribute_value) {
	switch(attribute_value) {
	case 0:
		return 0x3F00;
	case 1:
		return 0x3F04;
	case 2:
		return 0x3F08;
	case 3:
		return 0x3F0C;
	}
}

U0 renderPixel(PPU2C02state *state) {
	//get bg color index
	U8 shift = 15-(MMU.x & 7);
	U8 bit_0 = (state->bitmap_shift_0 & (1 << shift)) >> shift;
	U8 bit_1 = (state->bitmap_shift_1 & (1 << shift)) >> shift;
	U8 bg_color_index = (bit_1 << 1) | bit_0;
	bit_0 = (state->AT_shift_0 & (1 << shift)) >> shift;
	bit_1 = (state->AT_shift_1 & (1 << shift)) >> shift;
	U8 bg_at_index = (bit_1 << 1) | bit_0;

	//get sprite color index and active sprite
	U8 sprite_color_index = 0;
	I64 active_sprite_index = getActiveSpriteIndex(state);
	if( active_sprite_index != -1 ) {
		bit_0 = (state->sprites[active_sprite_index].shift_register_0 & (1 << 7)) >> 7;
		bit_1 = (state->sprites[active_sprite_index].shift_register_1 & (1 << 7)) >> 7;
		sprite_color_index = (bit_1 << 1) | bit_0;
	}

	U16 palette_base;
	U8 color_value;
	U32 color;

	//draw the pixel on the screen, depending on color and priority
	if( bg_color_index == 0 && sprite_color_index == 0 ) {
		//setPixelColor(state->dot, state->scanline, ppu_colors[MMU.VRAM[0x3F00]]);
		setPixelColor(state->dot, state->scanline, MMU.VRAM[0x3F00]);
	}
	else if( (sprite_color_index != 0 && bg_color_index == 0) ||
	         (sprite_color_index != 0 && bg_color_index != 0 && (state->sprites[active_sprite_index].byte2 & (1<<5)) == 0) ) {
		//assert( active_sprite_index != -1 );
		palette_base = getSpritePaletteBase(state->sprites[active_sprite_index].attribute);
		color_value = readVRAM(palette_base + sprite_color_index);
		//color = ppu_colors[color_value];
		setPixelColor(state->dot, state->scanline, color_value);
	}
	else {
		palette_base = getBackgroundPaletteBase(bg_at_index);
		color_value = readVRAM(palette_base + bg_color_index);
		//color = ppu_colors[color_value];
		setPixelColor(state->dot, state->scanline, color_value);
	}

	//handle sprite zero hit
	if( active_sprite_index != -1 && state->sprites[active_sprite_index].sprite_index == 0 && sprite_color_index != 0 && bg_color_index == 0 ) {
		state->sprite_zero_hit = 1;
	}
}

/******************
* loading
******************/

U0 loadScanlineSprites(PPU2C02state *state) {
	state->num_sprites = 0;
	I64 i=0;
	for(i=0; i<8; ++i) {
		state->sprites[i].shift_register_0 = 0;
		state->sprites[i].shift_register_1 = 0;
	}

	for(i=0x00; i<0xFF; i+=4) {
		//assert( (MMU.RAM[0x2000] & (1 << 5)) == 0 ); //only allow 8x8 sprites

		U8 y = readSPRRAM(i+0)+1;
		U8 pattern_index = readSPRRAM(i+1);
		U8 byte2 = readSPRRAM(i+2);
		U8 x = readSPRRAM(i+3);

		if( y <= state->scanline && y+8 > state->scanline ) {

			U16 pattern_base = 0x0000;
			if( (MMU.RAM[0x2000] & (1 << 3)) ) {
				pattern_base = 0x1000;
			}

			U16 palette_base = getSpritePaletteBase(byte2 & 3);

			I64 row = state->scanline-y;
			U8 pattern_0 = MMU.VRAM[pattern_base + (pattern_index*16+row)];
			U8 pattern_1 = MMU.VRAM[pattern_base + (pattern_index*16+row+8)];

			//flip y
			if( byte2 & (1 << 7) ) {
				pattern_0 = MMU.VRAM[pattern_base + (pattern_index*16+(7-row))];
				pattern_1 = MMU.VRAM[pattern_base + (pattern_index*16+(7-row)+8)];
			}

			//flip x, reverse the bits in the patterns
			if(byte2 & (1 << 6) ) {
				U8 new_pattern_0 = 0;
				U8 new_pattern_1 = 0;
				I64 bit;
				for(bit=0; bit<8; ++bit) {
					new_pattern_0 <<= 1;
					new_pattern_0 |= (pattern_0&1);
					pattern_0 >>= 1;
					new_pattern_1 <<= 1;
					new_pattern_1 |= (pattern_1&1);
					pattern_1 >>= 1;
				}
				pattern_0 = new_pattern_0;
				pattern_1 = new_pattern_1;
			}

			state->sprites[state->num_sprites].sprite_index = i;
			state->sprites[state->num_sprites].x = x;
			state->sprites[state->num_sprites].attribute = (byte2 & 3);
			state->sprites[state->num_sprites].shift_register_0 = pattern_0;
			state->sprites[state->num_sprites].shift_register_1 = pattern_1;
			state->sprites[state->num_sprites].shifts_remaining = 8;
			state->sprites[state->num_sprites].byte2 = byte2;

			state->num_sprites += 1;
			if(state->num_sprites == 8) {
				break;
			}
		}
	}

}

U0 updatePPUrenderingData(PPU2C02state *state) {
	state->bitmap_shift_0 <<= 1;
	state->bitmap_shift_1 <<= 1;
	state->bitmap_shift_0 &= ~1;
	state->bitmap_shift_1 &= ~1;

	state->AT_shift_0 <<= 1;
	state->AT_shift_1 <<= 1;
	state->AT_shift_0 &= ~1;
	state->AT_shift_1 &= ~1;

	I64 i;
	for(i=0; i<state->num_sprites; ++i) {
		if( state->sprites[i].x == 0 && state->sprites[i].shifts_remaining > 0) {
			state->sprites[i].shift_register_0 <<= 1;
			state->sprites[i].shift_register_1 <<= 1;
			state->sprites[i].shifts_remaining -= 1;
		}
		else {
			state->sprites[i].x -= 1;
		}
	}
}

U8 getAttributeTableValue(U16 attribute_address, U8 x, U8 y) {
	U8 attribute_value = readVRAM(attribute_address);

	U8 bottom = 1;
	U8 right = 1;
	if( (y/32)*32 == (y/16)*16 ) {
		//top
		bottom = 0;
	}
	if( (x/32)*32 == (x/16)*16 ) {
		//left
		right = 0;
	}

	U8 mask = 0;
	if( bottom == 0 && right == 0 ) {
		mask = (1 << 1) | (1 << 0);
		attribute_value = (attribute_value & mask);
	}
	if( bottom == 0 && right == 1 ) {
		mask = (1 << 3) | (1 << 2);
		attribute_value = (attribute_value & mask) >> 2;
	}
	else if( bottom == 1 && right == 0 ) {
		mask = (1 << 5) | (1 << 4);
		attribute_value = (attribute_value & mask) >> 4;
	}
	else if( bottom == 1 && right == 1 ) {
		mask = (1 << 7) | (1 << 6);
		attribute_value = (attribute_value & mask) >> 6;
	}

	return attribute_value;
}

U0 fetchAttribute(PPU2C02state *state) {
	U16 attribute_address = (0x23C0 | (MMU.VRAM_address & 0x0C00) | ((MMU.VRAM_address >> 4) & 0x38) | ((MMU.VRAM_address >> 2) & 0x07));
	U8 at = getAttributeTableValue(attribute_address, (MMU.VRAM_address & 0x001F)*8, ((MMU.VRAM_address & (0x001F << 5)) >> 5)*8);
	if(at & 1) {
		state->AT_shift_0_latch = 0xFF;
	}
	else {
		state->AT_shift_0_latch = 0x00;
	}
	if(at & 2) {
		state->AT_shift_1_latch = 0xFF;
	}
	else {
		state->AT_shift_1_latch = 0x00;
	}
}

I64 initPPU2C02(PPU2C02state *state) {
	state->scanline = 241;
	state->dot = 0;
	state->odd_frame = 0;
	state->nmi_occurred = 0;
	state->nmi_output = 0;

	return 1;
}

U0 handleVisibleScanline(PPU2C02state *state) {

	if( state->dot == 0 ) {
		loadScanlineSprites(state);
		return;
	}
	if( !rendering_enabled() ) {
		return;
	}

	//shift the shift registers
	if( state->dot <= 255 || (state->dot > 320 && state->dot <= 336) ) {
		updatePPUrenderingData(state);
	}

	U16 pattern_base = 0x0000;
	if( MMU.RAM[0x2000] & (1 << 4) ) {
		pattern_base = 0x1000;
	}
	U16 pattern_index = MMU.VRAM[state->nametable_base];
	U8 row = ((MMU.VRAM_address&0x7000) >> 12);

	if( state->dot < 256 || (state->dot > 320 && state->dot <= 336) ) {

		//update the latches, depending on the cycle
		switch( state->dot % 8 ) {
		case 0:
			state->bitmap_shift_0 |= state->bitmap_shift_0_latch;
			state->bitmap_shift_1 |= state->bitmap_shift_1_latch;

			state->AT_shift_0 |= state->AT_shift_0_latch;
			state->AT_shift_1 |= state->AT_shift_1_latch;

			horinc();
			break;
		case 1:
			state->nametable_base = (0x2000 | (MMU.VRAM_address & 0x0FFF));
			break;
		case 3:
			fetchAttribute(state);
			break;
		case 5:
			state->bitmap_shift_0_latch = MMU.VRAM[pattern_base + pattern_index*16+row];
			break;
		case 7:
			state->bitmap_shift_1_latch = MMU.VRAM[pattern_base + pattern_index*16+row+8];
			break;
		}

	}

	if( state->dot == 256 ) {
		verinc();
	}

	if( state->dot == 257 ) {
		//v: ....F.. ...EDCBA = t: ....F.. ...EDCBA
		MMU.VRAM_address &= 31712; //31712 = 0111101111100000b
		MMU.VRAM_address |= (MMU.t & ~31712);
	}

}

U8 PPUcycle(PPU2C02state *state) {

	if( state->nmi_output && state->nmi_occurred ) {
		state->nmi_occurred = 0;
		//NMI(&CPU_state);
		nmi6502;
	}

	//update cycles/scanlines
	state->dot += 1;
	if(state->dot == 341) {
		state->scanline += 1;
		state->dot = 0;
	}
	state->scanline %= 262;
	//skip first cycle on odd frames
	if(state->scanline == 0 && state->dot == 0 && state->odd_frame == 1 && rendering_enabled()) {
		state->dot = 1;
	}

	//visible scanlines
	if( state->scanline < 240 && rendering_enabled() ) {
		handleVisibleScanline(state);

		//visible cycles
		if( state->dot < 256 ) {
			renderPixel(state);
		}
	}

	//Post-screen scanline
	else if(state->scanline == 241) {
		if(state->dot == 1) {
			state->nmi_occurred = 1;
			state->odd_frame ^= 1;

			return 1;
		}
	}

	//Pre-screen scanline
	else if(state->scanline == 261) {

		handleVisibleScanline(state);

		if(state->dot == 2) {
			state->sprite_zero_hit = 0;
			state->nmi_occurred = 0;
		}

		else if(state->dot >= 280 && state->dot <= 304 && rendering_enabled()) {
			//v: IHGF.ED CBA..... = t: IHGF.ED CBA.....
			MMU.VRAM_address &= 1055; //1055 = 0000010000011111b
			MMU.VRAM_address |= (MMU.t & ~1055 & ~(1<<15) );
		}
	}

	return 0;
}

