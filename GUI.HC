// vim: set ft=c:

#define GUI_IDLE_TIMEOUT 30

U32 frame_count = 0;

CDC *ms_pointer = GRRead("Pointer.GR");
DCColorChg(ms_pointer, LTPURPLE, 255);

Bool gui_focus = FALSE;

I64 menu_focus = -1;
I64 item_clicked = -1;
I64 mouse_old_x, mouse_old_y;
I64 mouse_new_x, mouse_new_y;
I64 idle_ctr = 0;

U8 **menu_bar=CAlloc(sizeof(U64)*6);
menu_bar[0] = "Game";
menu_bar[1] = "Config";
menu_bar[2] = "Cheats";
menu_bar[3] = "Misc";
menu_bar[4] = "Help";

U8 **menu_items=NULL;

U8 **menu_game=CAlloc(sizeof(U64)*10);
menu_game[0] = "Load ROM";
menu_game[1] = "Reset";
menu_game[2] = "";
menu_game[3] = "Load State";
menu_game[4] = "Save State";
menu_game[5] = "";
menu_game[6] = "Exit";

U8 **menu_config=CAlloc(sizeof(U64)*10);
menu_config[0] = "Joypad 1";
menu_config[1] = "Joypad 2";

U8 **menu_cheats=CAlloc(sizeof(U64)*10);
menu_cheats[0] = "Add";
menu_cheats[1] = "View/Edit";
menu_cheats[2] = "Toggle";

U8 **menu_misc=CAlloc(sizeof(U64)*10);
menu_misc[0] = "Scale2Fit";

U8 **menu_help=CAlloc(sizeof(U64)*10);
menu_help[0] = "About";

U0 GrPrintShadow(CDC *dc, I64 x, I64 y, I64 c1=15, I64 c2=0, U8 *str)
{
	dc->color=c2;
	GrPrint(dc, x+1, y+1, str);
	dc->color=c1;
	GrPrint(dc, x, y, str);
}

U0 GUIDrawMenuHeader()
{
	I64 i = 0;
	if (mouse_new_y<12 || gui_focus)
	{
		TG_Canvas->color=7;
		GrRect(TG_Canvas, 0, 0, 320, 12);

		while (menu_bar[i])
		{
			if (i+1==menu_focus)
			{
				GrPrintShadow(TG_Canvas, (64*i) - 64, 2, YELLOW, 0, menu_bar[i++]);
			}
			else
			{
				if (mouse_new_x > (64*i+1) && mouse_new_x < (64*i+1)+64 &&
				    mouse_new_y > -1 && mouse_new_y < 12)
				{
					GrPrintShadow(TG_Canvas, (64*i) - 64, 2, CYAN, 0, menu_bar[i++]);
				}
				else
				{
					GrPrintShadow(TG_Canvas, (64*i) - 64, 2, 15, 0, menu_bar[i++]);
				}
			}
		}
	}
}

U0 GUIGetMenuItems()
{
	switch (menu_focus)
	{
	case 1:
		menu_items = menu_game;
		break;
	case 2:
		menu_items = menu_config;
		break;
	case 3:
		menu_items = menu_cheats;
		break;
	case 4:
		menu_items = menu_misc;
		break;
	case 5:
		menu_items = menu_help;
		break;
	default:
		menu_items = NULL;
		break;
	}
}

U0 GUIDrawMenuFocused()
{
	I64 menu_size = 0;
	I64 i = 0;
	if (menu_focus)
	{
		GUIGetMenuItems;
		while (menu_items[i++])
		{
			menu_size++;
		}
		i = 0;
		TG_Canvas->color=LTGRAY;
		GrRect(TG_Canvas, (64*menu_focus)-64, 12, 96, 2+10*menu_size);
		TG_Canvas->color=WHITE;
		GrLine(TG_Canvas, (64*menu_focus)-64, 12, (64*menu_focus)-64, 14+10*menu_size);
		GrLine(TG_Canvas, (64*menu_focus)-64, 12, (64*menu_focus)+32, 12);
		TG_Canvas->color=DKGRAY;
		GrLine(TG_Canvas, (64*menu_focus)+32, 13, (64*menu_focus)+32, 14+10*menu_size);
		GrLine(TG_Canvas, (64*menu_focus)-63, 14+10*menu_size, (64*menu_focus)+32, 14+10*menu_size);
		while (menu_items && menu_items[i])
		{
			if (mouse_new_x > (64*menu_focus)-64 && mouse_new_x < (64*menu_focus) + 32 &&
			    mouse_new_y > 4+((i+1)*10) && mouse_new_y < 4+((i+1)*10)+10)
			{
				GrPrintShadow(TG_Canvas, (64*menu_focus)-62, 4+(i*10), CYAN, 0, menu_items[i++]);
			}
			else
			{
				GrPrintShadow(TG_Canvas, (64*menu_focus)-62, 4+(i*10), 15, 0, menu_items[i++]);
			}
		}
	}
}

U0 GUIDetectMenuItemClick()
{
	I64 i = 0;
	I64 menu_size = 0;
	GUIGetMenuItems;
	while (menu_items[i++])
	{
		menu_size++;
	}
	if ((mouse_new_x < (64*menu_focus)-64 || mouse_new_x > (64*menu_focus) + 32) ||
	    mouse_new_y > 4+((menu_size+1)*10)+10)
	{
		item_clicked = -1;
		gui_focus = FALSE;
		menu_focus = -1;
		return;
	}
	i = 0;
	while (menu_items && menu_items[i])
	{
		if (mouse_new_x > (64*menu_focus)-64 && mouse_new_x < (64*menu_focus) + 32 &&
		    mouse_new_y > 4+((i+1)*10) && mouse_new_y < 4+((i+1)*10)+10)
		{
			item_clicked = i;
			return;
		}
		i++;
	}
}

U0 GUIDrawPointer()
{
	GrBlot(TG_Canvas, mouse_new_x, mouse_new_y, ms_pointer);
}

U0 UpdateGUI()
{
	mouse_new_x = TG_MouseX;
	mouse_new_y = TG_MouseY;

	if (ms.lb && mouse_new_y<12)
	{
		gui_focus = TRUE;
		menu_focus = RoundUp(mouse_new_x, 64) / 64;
	}
	if (ms.lb && mouse_new_y>11 && menu_focus)
	{
		GUIDetectMenuItemClick;
		if (item_clicked > -1)
		{
			switch (item_clicked)
			{
			case 0:
				switch (menu_focus)
				{
				case 4:
					fit_screen = !fit_screen;
					if (fit_screen)
					{
						menu_misc[0] = "Scale2Fit +";
					}
					else
					{
						menu_misc[0] = "Scale2Fit";
					}
					break;
				default:
					break;
				}
				break;
			case 1:
				switch (menu_focus)
				{
				case 1:
					reset = TRUE;
					break;
				default:
					break;
				}
				break;
			case 6:
				switch (menu_focus)
				{
				case 1:
					quit = TRUE;
					break;
				default:
					break;
				}
				break;
			default:
				break;
			}
			item_clicked = -1;
			gui_focus = FALSE;
			menu_focus = -1;
		}
	}

	if (menu_focus<1)
	{
		gui_focus = FALSE;
	}

	if (menu_focus>0)
	{
		paused = TRUE;
	}
	else
	{
		paused = FALSE;
	}

	if ( mouse_old_x == mouse_new_x &&
	     mouse_old_y == mouse_new_y)
	{
		if (!idle_ctr)
		{
			idle_ctr = frame_count;
		}
	}
	else
	{
		idle_ctr = 0;
	}

	if (!idle_ctr || (frame_count < idle_ctr + GUI_IDLE_TIMEOUT) || gui_focus)
	{ //Draw mouse pointer
		GUIDrawMenuHeader;
		GUIDrawMenuFocused;
		GUIDrawPointer;
	}

	mouse_old_x = mouse_new_x;
	mouse_old_y = mouse_new_y;
}