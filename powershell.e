/** -*- tab-width:4 -*- */

#include "eel.h"
#include "proc.h"
#include "colcode.h"
#include "c.h"
#include "perl.h"
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

    // positive numbers
    if (index("0123456789%.", buf[1]))
    {
        return c_number_color(buf + 1);
    }

    // negative numbers
    if (buf[1] == '-' && index("0123456789%.", buf[2]))
    {
        return c_number_color(buf + 1);
    }

    // Check if this is a variable.
    if (buf[1] == '$' && isalnum(buf[2]))
    {
        return color_class powershell_identifier;
    }

    strcpy(buf + point - from + 1, "|");

    // Check if this is an operator.
    if (is_powershell_operator(buf))
    {
        return color_class powershell_keyword;
    }

    // Check if this is a keyword.
    if (is_powershell_keyword(buf))
    {
        return color_class powershell_keyword;
    }

    // Must not be a number, operator, or keyword so assume identifier.
    return color_class powershell_identifier;
}

powershell_here_string_color(int c)
{
    char pat[20];
    int start = point - 2;

    if (character(point - 2) == c
          && character(point - 2) == '@'
          && character(point - 1) == '\"')
    {
        // here-string
        // https://technet.microsoft.com/en-us/library/ee692792.aspx
        sprintf(pat, "<DQuote>@|\n");
    }

    while (re_search(1, pat))
    {
        if (character(matchstart) != '\n') break;
    }

    set_character_color(start, point, color_class powershell_string);
}

// Found a " or """ or ', make it purdy.
powershell_string_color(int c)
{
    char pat[20];
    int start = point -1;

    if (character(point) == c
          && character(point + 1) == c
          && character(point + 2) == c)
    {
        // Quoted string - """My sweet string."""
        point += 2;
        sprintf(pat, "%c%c%c|\n", c, c, c);
    }
    else
    {
        // Normal string
        sprintf(pat, "%c|\n", c);
    }

    while (re_search(1, pat))
    {
        if (character(matchstart) != '\n' || character(matchstart) != c) break;
    }

    set_character_color(start, point, color_class powershell_string);
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
                       "|-[A-Za-z_][A-Za-z]*"               // operators
                       "|-?%.?[0-9]([A-Za-z0-9._]|[Ee]-)*"  // numbers
                       "|@<DQuote>.*<DQuote>@"                               // here-strings
                       "|[\"'#]"))                          // comments, strings
        {
            t = size();
            break;
        }

        t = matchstart;
        switch (character(point - 1)) // check last char
        {
            case '#': // found comment
                nl_forward();
                set_character_color(t, point, color_class powershell_comment);
                break;
            /*
            case '<': // example comment... <# #>
                break;
            */
            case '"': // found a string literal
                if (character(point - 2) == '@')
                {
                    powershell_here_string_color('@');
                    if (get_character_color(point, (int *) 0, &s) ==
                          color_class powershell_string && s > to) // fix up after
                        if (point < (to = s)) // quoted "'s
                            set_character_color(point, to, -1);
                }
                else
                {
                    powershell_string_color('"');
                    if (get_character_color(point, (int *) 0, &s) == 
                          color_class powershell_string && s > to)  // fix up after
                        if (point < (to = s))   // quoted "'s
                            set_character_color(point, to, -1);
                }
                break;
            case '\'':
                powershell_string_color('\'');
                if (get_character_color(point, (int *) 0, &s) == 
                      color_class powershell_string && s > to)  // fix up after
                    if (point < (to = s))	 // quoted "'s
                        set_character_color(point, to, -1);
                break;
            default:    // found identifier, kywd, or number
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

suffix_ps1()
{
    powershell_mode();
}

suffix_psd1()
{
    powershell_mode();
}

suffix_psm1()
{
    powershell_mode();
}

command powershell_mode()
{
    mode_default_settings();
    mode_keys = powershell_tab;
    major_mode = powershell_mode_name;
    compile_buffer_cmd = compile_powershell_cmd;

    if (powershell_tab_override > 0) tab_size = powershell_tab_override;
    indent_with_tabs = powershell_indent_with_tabs;
    //indenter = do_powershell_indent;
    auto_indent = 1;
    indenter = c_indenter;
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
    mode_move_level = c_move_level;

    buffer_maybe_break_line = generic_maybe_break_line;
    fill_mode = (misc_language_fill_mode & 16) != 0;

    drop_all_colored_regions();
    make_mode();
}