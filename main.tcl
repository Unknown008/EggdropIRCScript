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
set poke(ready)        [list]

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
    bind pub - decline poke:decline
    lappend poke(prepList) $target
  }
}

proc poke:accept {nick host hand chan arg} {
  global poke
  if {!$poke(running) || $chan ne $poke(chan) || $nick eq [lindex $poke(prepList) 0]} {return}
  set trainerCount [llength $poke(prepList)]
  if {$trainerCount == 2 && [string trim $nick] ne [lindex $poke(prepList) 1]} {return}
  unbind pub - accept poke:accept
  lappend poke(prepList) $nick
  lassign $poke(prepList) challenger target
  if {$target eq ""} {
    set target $nick
  }
  putquick "PRIVMSG $chan :Battle between the challenger $challenger and trainer $target is about to begin!"
  putquick "PRIVMSG $challenger :Tell me your team details (you can link pastebin.com). Say \"help\" if you don't know the syntax."
  putquick "PRIVMSG $target :Tell me your team details (you can link pastebin.com). Say \"teamhelp\" if you don't know the syntax."
  bind msgm - "*" poke:battleprep
  lappend poke(team) [list $challenger {}] [list $target {}]
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
  set poke(ready)        [list]
  unbind msgm - "*" poke:battleprep
  putquick "PRIVMSG $chan :The current battle has been stopped."
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
  } elseif {$nick in $poke(ready)} {
    switch -nocase -regexp -- $arg {
      y(es?)? {
        
      }
      no? {
        
      }
    }
  } else {
    switch -nocase -glob -- $arg {
      teamhelp {
        putquick "PRIVMSG $nick :See this pastebin for the syntax: http://pastebin.com/Ym1amdKE"
        putquick "PRIVMSG $nick :Use \"forfeit\" to give up."
        putquick "PRIVMSG $nick :Use \"cancel #\" to remove the Pokemon in the #th slot."
        putquick "PRIVMSG $nick :Use \"reorder # # # # # # > # # # # # #\" to reorder your Pokemon order."
        putquick "PRIVMSG $nick :Use \"done\" to finalize and submit your team."
        putquick "PRIVMSG $nick :Use \"pastebin linktopastebin\" to submit a team from pastebin (it should also follow the required format)"        
      }
      forfeit {
        putquick "PRIVMSG $nick :Are you sure you want to forfeit? (Y/N)"
        lappend poke(forfeit) $nick
      }
      cancel* {
        set param [lreplace $arg 0 0]
        if {$param > 0 && $param <= $poke(crule)} {
          
        } else {
          putquick "PRIVMSG $nick :Use \"cancel #\" to remove the Pokemon in the #th slot."
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
      default {
        set id [lsearch -index 0 -nocase $poke(team) $nick]
        set nteam [lindex $poke(team) $id]
        set len [llength [lindex $nteam 1]]
        if {$len < $poke(crules)} {
          poke:register $nick $arg
        }
      }
    }
  }
}

proc poke:register {nick arg} {
  global poke
  set id [lsearch -index 0 $poke(team) $nick]
  set cteam [lindex $poke(team) $id 1]

  set elem [split $arg "/"]
  set len [llength $elem]

  set elem [lassign $elem pokemon(species)]
  set species $pokemon(species)
  lassign $elem pokemon($species,item) pokemon($species,nature) pokemon($species,IHP) pokemon($species,IAtk) pokemon($species,IDef) pokemon($species,ISpA) pokemon($species,ISpD) pokemon($species,ISpd) pokemon($species,EHP) pokemon($species,EAtk) pokemon($species,EDef) pokemon($species,ESpA) pokemon($species,ESpD) pokemon($species,ESpd) pokemon($species,Move1) pokemon($species,Move2) pokemon($species,Move3) pokemon($species,Move4)
  
  lappend cteam [array get pokemon]
  lset poke(team) $id [list $nick $cteam]
  set teamsize [llength $cteam]
  if {$teamsize == $poke(crules)} {
    set lineup [list]
    foreach ind $cteam {
      set id [lsearch -index 0 $ind species]
      lappend lineup [lindex $ind $id+1]
    }
    putquick "PRIVMSG $nick :Your current line up is [join $lineup ", "]. Are you satisfied with your line up? (Y/N)"
    lappend poke(ready) $nick
  } else {
    putquick "PRIVMSG $nick :$species has successfully been registered! You now have $teamsize Pokemon of $poke(crules) allowed."
  }
}

putlog "Pokemon Battle $poke(ver) loaded."
