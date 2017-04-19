##
# The help for the pub commands for the bot
##
set command "!command"; # Command to trigger commands
set heading [format "%-20s %+7s " "Function:" "Command:"]
set conversioncmd [format "%-20s %+10s " "Conversion" "!con \[amount\] \[from\] \[to\]"]
set pokedexcmd [format "%-20s %+10s " "Pokedex" "!pokedex \[pokemon\]"]
set abilitycmd [format "%-20s %+10s " "Pokemon Abilitydex" "!ability \[ability\]"]
set berrycmd [format "%-20s %+10s " "Pokemon Abilitydex" "!berry \[berry\]"]
set movecmd [format "%-20s %+10s " "Pokemon Abilitydex" "!move \[move\]"]
set cmds "!cmds"
set cmdver "0.0.1"

bind pub - $command pub:command
bind pub - $cmds pub:cmds

proc pub:command {nick host handle channel txt} {
  global command heading weathercmd timecmd currencycmd conversioncmd pokedexcmd 8ballcmd quotecmd abilitycmd movecmd berrycmd
  putquick "NOTICE $nick :Currently available commands are:"
  putquick "NOTICE $nick :$heading"
  putquick "NOTICE $nick :$conversioncmd"
  putquick "NOTICE $nick :$pokedexcmd"
  putquick "NOTICE $nick :$abilitycmd"
  putquick "NOTICE $nick :$berrycmd"
  putquick "NOTICE $nick :$movecmd"
  return
}

proc pub:cmds {nick host handle channel txt} {
  global command heading weather time currency conversion
  putquick "NOTICE $nick :Currently available commands are: !con !pokedex !ability !berry !move"
  putquick "NOTICE $nick :Use !command for more detail."
  return
}

putlog "Commands $cmdver loaded"
