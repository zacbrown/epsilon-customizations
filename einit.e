#include "eel.h"  /* Load standard definitions. */

when_loading()    /* Execute this file when loaded. */
{
    /* setup our color schemes */
    if (is_win32)
    {
        int scheme = find_index("bisque-background");
        _our_gui_scheme = scheme;

        draw_focus_rectangle = 1;
        sprintf(draw_column_markers, "90");
    }
    else
    {
        int scheme = find_index("borlandc");
        _our_gui_scheme = scheme;

        scheme = find_index("night-light");
        _our_color_scheme = scheme;
    }

    if (is_gui)
    {
        /* Show tabs and spaces, no newlines. */
        show_spaces = 9;
        show_spaces.default = 9;
        when_setting_show_spaces();
    }

    when_setting_want_code_coloring();
    when_setting_new_c_comments();

    //do_save_state("epsilon");   /* Save these changes. */
}