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
set poke(rules)        "6v6"
set poke(crules)       "6v6"
set poke(forfeit)      [list]
set poke(ready)        [list]

### Database settings
package require sqlite3
sqlite3 dex pokedexdb

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
  set challenge [format "%-30s %+7s " "!challenge \[nick\] -rule \[rules\]" "Issues a challenge to nick with 6v6 rule default"]
  set endbattle [format "%-30s %+7s " "!endbattle" "Ends the current battle"]
  putquick "NOTICE $nick :$header"
  putquick "NOTICE $nick :$challenge"
  putquick "NOTICE $nick :$endbattle"
}

proc poke:challenge {nick host hand chan args} {
  global poke
  if {$poke(chan) ne $chan} {return}
  if {$poke(running) > 0} {
    putquick "NOTICE $nick :A battle is already underway!"
    return
  }
  if {[llength $args] > 2} {
    putquick "NOTICE $nick :Incorrect number of parameters. Use: !challenge \[nick\] \[rules\]"
    return
  }
  set ruleid [lsearch $args "-rule"]
  if {$ruleid > -1} {
    set rule [lindex $args end]
    if {[regexp -nocase {^([1-6])v([1-6])$} $rule - ch ta]} {
      set poke(crules) [string lower $rule]
    } else {
      putquick "NOTICE $nick :Invalid rule format. Numbers must be between 1-6 an in the format #v#."
      return
    }
    set args [lreplace $args $ruleid $ruleid+1]
  }
  set target [lindex $args 0]
  if {$target ne "" && ![onchan $target]} {
    putquick "NOTICE $nick :$target is not on the channel!"
    return
  }
  incr poke(running)
  bind pub - accept poke:accept
  lappend poke(prepList) $nick
  if {$target eq ""} {
    putquick "PRIVMSG $chan :$nick issued a $poke(crules) challenge! Trainers can accept by typing \"accept\" in the chat (only the first trainer who accepts will be able to accept)."
  } else {
    putquick "PRIVMSG $chan :$nick issued a $poke(crules) challenge against $target!"
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
  set poke(crules)       "6v6"
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
        set id [lsearch -index 0 -nocase $poke(team) $nick]
        set nteam [lindex $poke(team) $id 1]
        set len [llength $nteam]
        if {($param > 0 && $param <= $len) || $len == 1} {
          set remove [lindex $nteam $param-1]
          set nteam [lreplace $nteam $param-1 $param-1]
          lset poke(team) $id 1 $nteam
          putquick "PRIVMSG $nick :The Pokemon at the ${param}th slot ($remove) has been removed."
        } else {
          putquick "PRIVMSG $nick :Use \"cancel #\" to remove the Pokemon in the #th slot. # has to be between 1 and $len."
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
        if {$len < [lindex [split $poke(crules) "v"] $id]} {
          set res [poke:parse $nick $arg]
          if {[llength [split $res "/"]] == 21} {
            if {[info exist poke(buffer,$nick)]} {unset poke(buffer,$nick)}
            poke:register $nick $res $id
          }
        }
      }
    }
  }
}

proc poke:register {nick arg id} {
  global poke

  set cteam [lindex $poke(team) $id 1]
  set elem [split $arg "/"]
  
  lassign $elem pokemon(species) pokemon(level) pokemon(item) pokemon(nature) pokemon(gender) pokemon(IHP) pokemon(IAtk) pokemon(IDef) pokemon(ISpA) pokemon(ISpD) pokemon(ISpd) pokemon(EHP) pokemon(EAtk) pokemon(EDef) pokemon(ESpA) pokemon(ESpD) pokemon(ESpd) pokemon(Move1) pokemon(Move2) pokemon(Move3) pokemon(Move4)
  
  # Check pokemon validity
  set pass [poke:check [array get pokemon]]
  lassign $pass status reason
  if {!$status} {
    putquick "PRIVMSG $nick :The was a problem with your Pokemon; it could not be registered."
    foreach sentence $reason {
      putquick "PRIVMSG $nick :Error: $sentence"
    }
    return
  }
  
  lappend cteam [array get pokemon]
  lset poke(team) $id [list $nick $cteam]
  set teamsize [llength $cteam]
  if {$teamsize == [lindex [split $poke(crules) "v"] $id]} {
    set lineup [list]
    foreach ind $cteam {
      set id [lsearch -index 0 $ind $pokemon(species)]
      lappend lineup [lindex $ind $id+1]
    }
    putquick "PRIVMSG $nick :Your current line up is [join $lineup ", "]. Are you satisfied with your line up? (Y/N)"
    lappend poke(ready) $nick
  } else {
    putquick "PRIVMSG $nick :$pokemon(species) has successfully been registered! You now have $teamsize Pokemon of $poke(crules) allowed."
  }
}

proc poke:parse {nick arg} {
  global poke
  set group [split $res "/"]
  if {[llength $group] == 21} {
    return $arg
  } elseif {[llength $group] < 21}
    if {![info exist poke(buffer,$nick)]} {
      set poke(buffer,$nick) $arg
    } else {
      set poke(buffer,$nick) [regsub -all {//+} "$poke(buffer,$nick)/$arg" ""]
    }
  } else {
    putquick "PRIVMSG $nick :Invalid format. See this pastebin for the syntax: http://pastebin.com/Ym1amdKE"
    if {[info exist poke(buffer,$nick)]} {unset poke(buffer,$nick)}
    return ""
  }
  return $poke(buffer)
} 

proc poke:check {arg} {
  array set pokemon $arg
  set errors [list]
  set poketable pokeDetails6
  set itemtable itemDetails6
  set movetable moveDetails6
  set leartable learDetails6
  set natutable natuDetails
  if {[dex eval "SELECT 1 FROM $poketable WHERE formname = '$pokemon(species)'"] != 1} {
    lappend errors [list "Pokemon name is invalid."]
  }
  if {!($pokemon(level) > 0 && $pokemon(level) <= 100)} {
    lappend errors [list "Pokemon level has to be between 1 and 100 inclusive."]
  }
  if {[dex eval "SELECT 1 FROM $itemtable WHERE name = '$pokemon(item)'"] != 1} {
    lappend errors [list "Held item is invalid."]
  }
  if {[dex eval "SELECT 1 FROM $natutable WHERE name = '$pokemon(nature)'"] != 1} {
    lappend errors [list "Pokemon nature is invalid."]
  }
  if {$pokemon(nature) ni {M F NA}} {
    lappend errors [list "Pokemon gender is invalid."]
  }
  set totalEV 0
  foreach stat {HP Atk Def SpA SpD Spd} {
    if {!($pokemon(I$stat) >= 0 && $pokemon(I$stat) <= 31)} {
      lappend errors [list "IV for $stat stat as to be between 0 and 31 inclusive."]
    }
    if {!($pokemon(E$stat) >= 0 && $pokemon(E$stat) <= 255)} {
      lappend errors [list "EV for $stat stat as to be between 0 and 255 inclusive."]
    }
    incr totalEV $pokemon(E$stat)
  }
  if {$totalEV > 510} {
    lappend errors [list "Total EVs for the Pokemon exceed the maximum of 510."]
  }
  foreach i {1 2 3 4} {
    set move $pokemon(Move$i)
    set moveid [dex eval "SELECT id FROM $movetable WHERE name = '$move'"]
    set movelist [dex eval "SELECT moves FROM $leartable WHERE name = '$pokemon(species)'"]
    if {$moveid ni $movelist} {
      lappend errors [list "The Pokemon cannot learn the move $move."]
    }
  }
  
  if {[llength $errors] > 0} {
    return [list 0 $errors]
  } else {
    return 1
  }
}
putlog "Pokemon Battle $poke(ver) loaded."
