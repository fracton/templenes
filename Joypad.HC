// vim: set ft=c:

class Joypad {
U8 pointer;
U8 button_status[8];
U8 previous_write;
};

Joypad NES_Joypad;

U0 initJoypad(Joypad *joypad) {
	joypad->pointer = 0;
	I64 i;
	for(i=0; i<8; ++i) {
		joypad->button_status[i] = 0;
	}
	joypad->previous_write = 0;
}

U0 handleInput(Joypad *joypad) {
	I64 i;
	for(i=0; i<8; ++i) {
		joypad->button_status[i] = 0;
	}
	if (TG_KeyDown(SC_ALT))
	{
		joypad->button_status[0] = 1; //A
	}
	if (TG_KeyDown(SC_CTRL))
	{
		joypad->button_status[1] = 1; //B
	}
	if (TG_KeyDown(SC_TAB))
	{
		joypad->button_status[2] = 1; //SELECT
	}
	if (TG_KeyDown(SC_ENTER))
	{
		joypad->button_status[3] = 1; //START
	}
	if (TG_KeyDown(SC_CURSOR_UP))
	{
		joypad->button_status[4] = 1; //UP
	}
	if (TG_KeyDown(SC_CURSOR_DOWN))
	{
		joypad->button_status[5] = 1; //DOWN
	}
	if (TG_KeyDown(SC_CURSOR_LEFT))
	{
		joypad->button_status[6] = 1; //LEFT
	}
	if (TG_KeyDown(SC_CURSOR_RIGHT))
	{
		joypad->button_status[7] = 1; //RIGHT
	}
}

U0 writeJoypad(Joypad *joypad, U8 data) {
	if( joypad->previous_write == 1 && data == 0) {
		joypad->pointer = 0;
	}
	joypad->previous_write = data;
}

U8 getNextButton(Joypad *joypad) {
	U8 retval = joypad->button_status[ joypad->pointer++ ];
	joypad->pointer = joypad->pointer % 8;
	return retval;
}