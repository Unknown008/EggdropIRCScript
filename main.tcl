######################
### Configurations ###
######################
### Defaults
set poke(chan)         "#Jerry"
set poke(stats)        "pokemon/stats"
set poke(ver)          "pre 0.0.1"

### Global Variables
set poke(running)      0
set poke(trainerList)  [list]
set poke(team)         [list]
set poke(currentPoke)  [list]
set poke(rules)        6

######################
###    Bindings    ###
######################
### Command binds
bind evnt - "prerehash"  poke:prestart
bind evnt - "prerestart" poke:prestart
bind pub - !pokecmd      poke:chancommands
bind pub - !challenge    poke:challenge
bind pub - !endbattle    poke:stop

######################
###   Procedures   ###
######################
proc poke:prestart {type} {
  global botnick poke
  poke:stop $botnick console $botnick $poke(chan) "" 
}

proc poke:chancommands {nick host hand chan arg} {
  global poke
  set header [format "%-30s %+7s " "Function:" "Command:"]
  set challenge [format "%-30s %+7s " "!challenge \[nick\] \[rules\]" "Issues a challenge to nick with 6v6 rule default"]
  set endbattle [format "%-30s %+7s " "!endbattle" "Ends the current battle"]
  putquick "NOTICE $nick :$header"
  putquick "NOTICE $nick :$challenge"
  putquick "NOTICE $nick :$endbattle"
}

proc poke:challenge {nick host hand chan arg} {
  global poke
  if {$poke(chan) ne $chan} {return}
  if {$poke(running) > 0} {
    putquick "NOTICE $nick :A battle is already underway!"
    return
  }
  set target [string trim $arg]
  if {$target ne "" && ![onchan $target]} {
    putquick "NOTICE $nick :$target is not on the channel!"
    return
  }
  bind pub - accept poke:accept
  lappend poke(trainerList) $nick
  if {$target eq ""} {
    putquick "PRIVMSG $chan :$nick issued a challenge! Trainers can accept by typing \"accept\" in the chat (first to accept only)."
  } else {
    putquick "PRIVMSG $chan :$nick issued a challenge against $target!"
    putquick "NOTICE $target :Type \"accept\" to accept the challenge or \"decline\" to decline."
    bind pub - accept poke:decline
    lappend poke(trainerList) $target
  }
}

proc poke:accept {nick host hand chan arg} {
  global poke
  if {!$poke(running) || $chan ne $poke(channel)} {return}
  set trainerCount [llength $poke(trainerList)]
  if {$trainerCount == 2 && $nick ne [lindex $poke(trainerList) 1]} {return}
  unbind pub - accept poke:accept
  lassign $poke(trainerList) challenger target
  if {$target = ""} {
    set target $nick
  }
  putquick "PRIVMSG $chan :Battle between the challenger $nick and trainer $target is about to begin!"
  putquick "PRIVMSG $challenger :Tell me your team details"
  putquick "PRIVMSG $target :Tell me your team details"
  bind msgm - $host poke:battleprep
}

proc poke:decline {nick host hand chan arg} {
  global poke
  if {!$poke(running) || $chan ne $poke(channel)} {return}
  if {[llength $poke(trainerList)] == 2 && $nick ne [lindex $poke(trainerList) 1]} {return}
  unbind pub - accept poke:accept
  unbind pub - decline poke:decline
  putquick "NOTICE $nick :Challenge declined."
  putquick "NOTICE [lindex $poke(trainerList) 0] :Your challenge has been declined."
  poke:stop $nick $host $hand $chan $arg
}

proc poke:stop {nick host hand chan arg} {
  global poke
  if {!$poke(running) || $poke(chan) ne $chan} {return}
  set poke(running)      0
  set poke(trainerList)  [list]
  set poke(team)         [list]
  set poke(currentPoke)  [list]
}

proc poke:battleprep {nick host hand arg} {
  global poke
  if {$nick ni $poke(trainerList)} {return}
  ##############
}

putlog "Pokemon Battle $poke(ver) loaded."
