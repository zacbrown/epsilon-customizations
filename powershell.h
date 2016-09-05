/** -*- tab-width:4 -*- */

char powershell_mode_name[] = "PowerShell";
keytable powershell_tab; /* key table for powershell mode */
user char compile_powershell_cmd[128] = "powershell -File \"%r\"";
user char powershell_indent = 2;
user int powershell_tab_override = 2;
user char powershell_indent_with_tabs = 0;
user char powershell_delete_hacking_tabs = 10; // What's a hacking tab...?

user char auto_show_powershell_delimiters = 1;
user char powershell_auto_show_delim_chars[20] = "{([])}";
user char powershell_indent_to_comment = 1;
//user char powershell_language_level = 3; // Not clear yet that we'd need this.

color_class powershell_comment = color_class perl_comment;
color_class powershell_string = color_class perl_string;
color_class powershell_keyword = color_class perl_keyword;
color_class powershell_identifier = color_class c_identifier;
color_class powershell_variable = color_class perl_variable;
color_class powershell_function = color_class perl_function;
color_class powershell_number = color_class perl_constant;

int color_powershell_range();



