/** -*- tab-width:4 -*- */

#include "eel.h"
#include "proc.h"
#include "colcode.h"
#include "powershell.h"


is_powershell_keyword(char *p)
{
    char *keywords =
                    "|begin|break|catch|continue|data|do|default|dynamicparam|else"
                    "|elseif|end|exit|filter|finally|for|foreach|from|function"
                    "|if|in|param|process|return|switch|throw|trap|try|until"
                    "|where|while|";

    if (strstr(keywords, p)) return 1;
    return 0;
}

is_powershell_operator(char *p)
{
    char *operators =
                      // case sensitive
                     "|-eq|-ne|-gt|-ge|-lt|-le|-ceq|-cne|-cgt|-cge|-clt|-cle"
                     // explicitly case insensitive
                     "|-ieq|-ine|-igt|-ige|-ilt|-ile"
                     "|-band|-bor|-bxor"
                     "|-and|-or|-xor"
                     "|-like|-notlike|-clike|-cnotlike|-ilike|-inotlike"
                     "|-match|-notmatch|-cmatch|-cnotmatch|-imatch|-inotmatch"
                     "|-contains|-notcontains|-ccontains|-cnotcontains|-icontains|-inotcontains"
                     "|-replace|-creplace|-ireplace"
                     "|-is|-as|-f"
                     // Questionable --> specific to certain contexts
                     // specific to case
                     "|-casesensitive|-wildcard|-regex|-exact"
                     // specific to scriptblock
                     "|-begin|-process|-end"
                     // short hands
                     "|?|%|";

    if (strstr(operators, p)) return 1;
    return 0;
}

powershell_keyword_color(from)
{
    char buf[100];

    if (point - from > sizeof(buf) / sizeof(*buf) - 10)
    {
        save_var point = from + sizeof(buf) / sizeof(*buf) - 10;
    }

    buf[0] = '|';
    grab(from, point, buf + 1);

    // Check if this is a number.
    // TODO: This probably doesn't handle numbers like -.4
    if (index("0123456789-", buf[1]) || buf[1] == '.' && isdigit(buf[2]))
    {
        buffer_printf("#messages#", "number: %s\n", buf);
        return c_number_color(buf + 1);
    }

    // Check if this is a variable.
    if (buf[1] == '$' && isalnum(buf[2]))
    {
        buffer_printf("#messages#", "identifier: %s\n", buf);
        return color_class powershell_identifier;
    }

    strcpy(buf + point - from + 1, "|");

    // Check if this is an operator.
    if (is_powershell_operator(buf))
    {
        buffer_printf("#messages#", "operator: %s\n", buf);
        return color_class powershell_keyword;
    }

    // Check if this is a keyword.
    if (is_powershell_keyword(buf))
    {
        buffer_printf("#messages#", "keyword: %s\n", buf);
        return color_class powershell_keyword;
    }

    // Must not be a number, operator, or keyword so assume identifier.
    buffer_printf("#messages#", "identifier: %s\n", buf);
    return color_class powershell_identifier;
}


// Found a " or """ or ', make it purdy.
powershell_string_color(int c)
{
    
}

color_powershell_range(from, to) // recolor just this section
{   // last colored region may go past to
    int t = -1, talk, s, talk_at = 0;
    TIMER talk_now;

    if (from >= to) return to;

    save_var point, matchstart, matchend;
    if (from < to) set_character_color(from, to, -1);
    point = from;

    if (talk = (to - from > 30000))	// Show status during long delays.
        time_begin(&talk_now, 50);		// Wait a bit before chatter.

    while (point < to)
    {
        // Does the buffer look like it has PowerShell identifiers,
        // functions, numbers, or comments?
        if (!re_search(1,
                       "%$[A-Za-z_][A-Za-z0-9_]*"           // variables
                       "|[A-Za-z_](-|[A-Za-z0-9_])*"        // function names
                       "|-?%.?[0-9]([A-Za-z0-9._]|[Ee]-)*"  // numbers
                       "|[\"'#]"))                          // comments
        {
            buffer_printf("#messages#", "derp! ");
            t = size();
            break;
        }

        t = matchstart;
        switch (character(point - 1)) // check last char
        {
            case '#': // found comment
                buffer_printf("#messages#", "comment!\n");
                nl_forward();
                set_character_color(t, point, color_class powershell_comment);
                break;
            /*
            case '"': // found a string literal
                //powershell_string_color('"');
                if (get_character_color(point, (int *) 0, &s) == 
                      color_class powershell_string && s > to)  // fix up after
                    if (point < (to = s))   // quoted "'s
                        set_character_color(point, to, -1);
                break;
            case '\'':
                // powershell_string_color('\'');
                if (get_character_color(point, (int *) 0, &s) == 
                      color_class powershell_string && s > to)  // fix up after
                    if (point < (to = s))	 // quoted "'s
                        set_character_color(point, to, -1);
                break;
            */
            default:    // found identifier, kywd, or number
                buffer_printf("#messages#", "herp derp\n");
                set_character_color(t, point, powershell_keyword_color(t));
                break;
        }

        if (talk && point > talk_at + 2000 && time_done(&talk_now))
        {
            note("Coloring PowerShell program: %d%% complete...",
                 muldiv(point - from, 100, to - from));
            talk_at = point;
        }
    }

    if (to < t) set_character_color(to, t, -1);
    if (talk_at) note("");

    return point;
}

command powershell_mode()
{
    mode_default_settings();
    mode_keys = powershell_tab;
    major_mode = powershell_mode_name;
    compile_buffer_cmd = compile_powershell_cmd;

    auto_indent = 1;
    if (powershell_tab_override > 0) tab_size = powershell_tab_override;
    indent_with_tabs = powershell_indent_with_tabs;
    //indenter = do_powershell_indent;
    soft_tab_size = powershell_indent;

    strcpy(comment_start, "#[ \t]*");
    strcpy(comment_pattern, "# *$");
    strcpy(comment_begin, "# ");
    strcpy(comment_end, "");
    recolor_range = color_powershell_range;
    recolor_from_here = recolor_from_top;
    when_setting_want_code_coloring();

    if (auto_show_powershell_delimiters)
        auto_show_matching_characters = powershell_auto_show_delim_chars;

    buffer_maybe_break_line = generic_maybe_break_line;
    fill_mode = (misc_language_fill_mode & 16) != 0;

    drop_all_colored_regions();
    make_mode();
}