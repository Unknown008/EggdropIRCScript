######################
### Configurations ###
######################
### Defaults
set poke(chan)         "#Jerry"
set poke(stats)        "pokemon/stats"
set poke(ver)          "pre 0.0.1"

### Global Variables
set poke(running)      0
set poke(prepList)     [list]
set poke(trainerList)  [list]
set poke(team)         [list]
set poke(currentPoke)  [list]
set poke(rules)        6
set poke(crules)       6
set poke(forfeit)      [list]

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
  incr poke(running)
  bind pub - accept poke:accept
  lappend poke(prepList) $nick
  if {$target eq ""} {
    putquick "PRIVMSG $chan :$nick issued a challenge! Trainers can accept by typing \"accept\" in the chat (only the first trainer who accepts will be able to accept)."
  } else {
    putquick "PRIVMSG $chan :$nick issued a challenge against $target!"
    putquick "NOTICE $target :Type \"accept\" to accept the challenge or \"decline\" to decline."
    bind pub - accept poke:decline
    lappend poke(prepList) $target
  }
}

proc poke:accept {nick host hand chan arg} {
  global poke
  if {!$poke(running) || $chan ne $poke(chan)} {return}
  set trainerCount [llength $poke(prepList)]
  if {$trainerCount == 2 && $nick ne [lindex $poke(prepList) 1]} {return}
  unbind pub - accept poke:accept
  lassign $poke(prepList) challenger target
  if {$target eq ""} {
    set target $nick
  }
  putquick "PRIVMSG $chan :Battle between the challenger $nick and trainer $target is about to begin!"
  putquick "PRIVMSG $challenger :Tell me your team details (you can link pastebin.com). Say \"help\" if you don't know the syntax."
  putquick "PRIVMSG $target :Tell me your team details (you can link pastebin.com). Say \"help\" if you don't know the syntax."
  bind msgm - *!*@* poke:battleprep
}

proc poke:decline {nick host hand chan arg} {
  global poke
  if {!$poke(running) || $chan ne $poke(chan)} {return}
  if {[llength $poke(prepList)] == 2 && $nick ne [lindex $poke(prepList) 1]} {return}
  unbind pub - accept poke:accept
  unbind pub - decline poke:decline
  putquick "NOTICE $nick :Challenge declined."
  putquick "NOTICE [lindex $poke(prepList) 0] :Your challenge has been declined."
  poke:stop $nick $host $hand $chan $arg
}

proc poke:stop {nick host hand chan arg} {
  global poke
  if {!$poke(running) || $poke(chan) ne $chan} {return}
  set poke(running)      0
  set poke(forfeit)      [list]
  set poke(prepList)     [list]
  set poke(trainerList)  [list]
  set poke(crules)       6
  set poke(team)         [list]
  set poke(currentPoke)  [list]
  unbind msgm - *!*@* poke:battleprep
}

proc poke:battleprep {nick host hand arg} {
  global poke
  if {$nick ni $poke(prepList)} {return}
  if {$nick in $poke(forfeit)} {
    switch -nocase -regexp -- $arg {
      y(es?)? {
        if {$nick ni $poke(forfeit)} {return}
        set id [lsearch $nick $poke(prepList)]
        set oID [lindex $poke(prepList) [expr {abs($id-3)}]]
        putquick "PRIVMSG $nick :You have forfeited the battle."
        putquick "PRIVMSG $poke(chan) :$nick has forfeited the battle."
        putquick "PRIVMSG [lindex $poke(prepList) $oID] :$nick has forfeited the battle."
        poke:stop
      }
      no? {
        if {$nick ni $poke(forfeit)} {return}
        set id [lsearch $nick $poke(forfeit)]
        set poke(forfeit) [lreplace $poke(forfeit) $id $id]
        putquick "PRIVMSG $nick :Please continue with your team editing."
      }
    }
  } else {
    switch -nocase -glob -- $arg {
      help {
        putquick "PRIVMSG $nick :See this pastebin for the syntax: http://pastebin.com/Ym1amdKE"
        putquick "PRIVMSG $nick :Use "forfeit" to give up."
        putquick "PRIVMSG $nick :Use "cancel #" to remove the Pokemon in the #th slot."
        putquick "PRIVMSG $nick :Use "reorder # # # # # # > # # # # # #" to reorder your Pokemon order."
        putquick "PRIVMSG $nick :Use "done" to finalize and submit your team."
        putquick "PRIVMSG $nick :Use "pastebin linktopastebin" to submit a team from pastebin (it should also follow the required format)"        
      }
      forfeit {
        putquick "PRIVMSG $nick :Are you sure you want to forfeit? (Y/N)"
        lappend poke(forfeit) $nick
      }
      cancel* {
        set param [lreplace $arg 0 0]
        if {$param > 0 && $param <= $poke(crule)} {
          
        } else {
          putquick "PRIVMSG $nick :Use "cancel #" to remove the Pokemon in the #th slot."
        }
      }
      reorder* {
        
      }
      pastebin* {
      
      }
      done {
        if {$nick in $poke(trainerList)} {return}
        putquick "PRIVMSG $chan :$nick's team is ready!"
        lappend poke(trainerList) $nick
      }
      default {poke:register $arg}
    }
  }
}

proc poke:register {arg} {
  global poke
  set elem [split $arg "/"]
  set len [llength $elem]
  if {$len == 19} {
    lassign $elem pokemon item nature IHP IAtk IDef ISpA ISpD ISpd EHP EAtk EDef ESpA ESpD ESpd Move1 Move2 Move3 Move4
    
  }
}

putlog "Pokemon Battle $poke(ver) loaded."
