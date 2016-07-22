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

### Modules
package require http
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
  putquick "PRIVMSG $challenger :Tell me your team details (you can link pastebin.com). Say \"teamhelp\" if you don't know the syntax."
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
        if {[string tolower $param] eq "all"} {
          lset poke(team) $id 1 {}
          putquick "PRIVMSG $nick :All your Pokemon have been removed."
        } elseif {[regexp -- {^\s*\d(?:\s*\d)+\s*$} $param]} {
          set ids [regexp -all -inline -- {\d} $param]
          set ids [lsort -integer -unique -decreasing $ids]
          set removed [list]
          foreach nid $ids {
            if {$nid > 0 && $nid < 7} {
              lappend removed $nid
              set nteam [lreplace $nteam $nid-1 $nid-1]
              lset poke(team) $id 1 $nteam
            } else {
              putquick "PRIVMSG $nick :Use \"cancel #\" to remove the Pokemon in the #th slot. # has to be between 1 and $len."
              break
            }
          }
          if {[llength $removed] > 0} {
            set removed [join [lsort -increasing $removed] ", "]
            putquick "PRIVMSG $nick :Pokemon at slots $removed have successfully been removed."
          }
        } elseif {($param > 0 && $param <= $len && [string is integer $param]) || $len == 1} {
          set remove [lindex $nteam $param-1]
          set pokename [lindex $remove [lsearch $remove species]+1]
          set nteam [lreplace $nteam $param-1 $param-1]
          lset poke(team) $id 1 $nteam
          switch $param {
            1 {set ord st}
            2 {set ord nd}
            3 {set ord rd}
            default {set ord th}
          }
          putquick "PRIVMSG $nick :The Pokemon at the $param$ord slot ($pokename) has been removed."
        } else {
          putquick "PRIVMSG $nick :Use \"cancel #\" to remove the Pokemon in the #th slot. # has to be between 1 and $len."
        }
      }
      reorder* {
        
      }
      pastebin* {
        set link [lreplace $arg 0 0]
        if {[regexp -- {pastebin\.com/([a-zA-Z0-9]+)} $link - id]} {
          set url "http://pastebin.com/raw/$id"
          set token [::http::geturl $link]
          set file [::http::data $token]
          ::http::cleanup $token
          poke:pastebin $nick $file
        } else {
          putquick "PRIVMSG $nick :Link could not be resolved. Make sure it is a pastebin.com link."
        }
        
      }
      done {
        if {$nick in $poke(trainerList)} {return}
        putquick "PRIVMSG $poke(chan) :$nick's team is ready!"
        lappend poke(trainerList) $nick
      }
      default {
        set id [lsearch -index 0 -nocase $poke(team) $nick]
        set nteam [lindex $poke(team) $id]
        set len [llength [lindex $nteam 1]]
        set crules [lindex [split $poke(crules) "v"] $id]
        if {$len < $crules} {
          set res [poke:parse $nick $arg]
          if {[llength [split $res "/"]] == 21} {
            if {[info exist poke(buffer,$nick)]} {unset poke(buffer,$nick)}
            set registered [poke:register $nick $res $id]
            putquick "PRIVMSG $nick :$registered has successfully been registered! You now have $len Pokemon of $poke(crules) allowed."
            incr len
          }
        }
        set nteam [lindex $poke(team) $id]
        set len [llength [lindex $nteam 1]]
        if {$len == $crules} {
          set lineup [list]
          foreach ind $nteam {
            set id [lsearch -index 0 $ind "species"]
            lappend lineup [lindex $ind $id+1]
          }
          putquick "PRIVMSG $nick :Your current line up is [join $lineup ", "]. Are you satisfied with your line up? (Y/N)"
          lappend poke(ready) $nick
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
    return 0
  }
  
  lappend cteam [array get pokemon]
  lset poke(team) $id [list $nick $cteam]

  return $pokemon(species)
}

proc poke:pastebin {text} {
  set registered
  foreach line [split $text "\r\n"] {
    if {$line == ""} {continue}
    set res [poke:parse $nick $line]
    if {[llength [split $res "/"]] == 21} {
      if {[info exist poke(buffer,$nick)]} {unset poke(buffer,$nick)}
      if {[poke:register $nick $res $id] != 0} {
        putquick "PRIVMSG $nick :$registered has successfully been registered!"
      } else {
        putquick "PRIVMSG $nick :The Pokemon could not be registered. See this pastebin for the syntax: http://pastebin.com/Ym1amdKE."
        break
      }
    } elseif {$res eq "err"} {
      break
    }
  }
}

proc poke:parse {nick arg} {
  global poke
  set group [split $arg "/"]
  if {[llength $group] == 21} {
    return $arg
  } elseif {[llength $group] < 21} {
    if {![info exist poke(buffer,$nick)]} {
      set poke(buffer,$nick) $arg
    } else {
      set poke(buffer,$nick) [regsub -all {//+} "$poke(buffer,$nick)/$arg" ""]
    }
  } else {
    putquick "PRIVMSG $nick :Invalid format. See this pastebin for the syntax: http://pastebin.com/Ym1amdKE"
    if {[info exist poke(buffer,$nick)]} {unset poke(buffer,$nick)}
    return "err"
  }
  return $poke(buffer,$nick)
} 

proc poke:check {arg} {
  array set pokemon $arg
  set errors [list]
  set poketable pokeDetails6
  set itemtable itemDetails6
  set movetable moveDetails6
  set leartable learDetails6
  set natutable nature
  if {[dex eval "SELECT 1 FROM $poketable WHERE formname = '$pokemon(species)'"] != 1} {
    lappend errors "Pokemon name is invalid."
  }
  if {!($pokemon(level) > 0 && $pokemon(level) <= 100)} {
    lappend errors "Pokemon level has to be between 1 and 100 inclusive."
  }
  # if {[dex eval "SELECT 1 FROM $itemtable WHERE name = '$pokemon(item)'"] != 1} {
    # lappend errors [list "Held item is invalid."]
  # }
  if {[dex eval "SELECT 1 FROM $natutable WHERE name = '$pokemon(nature)'"] != 1} {
    lappend errors "Pokemon nature is invalid."
  }
  if {$pokemon(gender) ni {M F NA}} {
    lappend errors "Pokemon gender is invalid."
  }
  set totalEV 0
  foreach stat {HP Atk Def SpA SpD Spd} {
    if {!($pokemon(I$stat) >= 0 && $pokemon(I$stat) <= 31)} {
      lappend errors "IV for $stat stat as to be between 0 and 31 inclusive."
    }
    if {!($pokemon(E$stat) >= 0 && $pokemon(E$stat) <= 255)} {
      lappend errors "EV for $stat stat as to be between 0 and 255 inclusive."
    }
    incr totalEV $pokemon(E$stat)
  }
  if {$totalEV > 510} {
    lappend errors "Total EVs for the Pokemon exceed the maximum of 510."
  }
  set moveset [list]
  # foreach i {1 2 3 4} {
    # set move $pokemon(Move$i)
    # set moveid [dex eval "SELECT id FROM $movetable WHERE name = '$move'"]
    # set movelist [dex eval "SELECT moves FROM $leartable WHERE name = '$pokemon(species)'"]
    # if {$moveid ni $movelist} {
      # lappend errors [list "The Pokemon cannot learn the move $move."]
    # }
    # lappend moveset $move
  # }
  if {[llength $moveset] != [llength [lsort -unique $moveset]]} {
    lappend errors "The Pokemon's moveset contains duplicate moves."
  }
  
  if {[llength $errors] > 0} {
    return [list 0 $errors]
  } else {
    return 1
  }
}

putlog "Pokemon Battle $poke(ver) loaded."
