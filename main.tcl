######################
### Configurations ###
######################
### Defaults
set poke(chan)         "#Jerry"
set poke(stats)        "pokemon/stats"
set poke(ver)          "pre 0.0.1"

### Global Variables
set poke(running)      0
set poke(gen)          6
set poke(prepList)     [list] ;# challenger trainer
set poke(trainerList)  [list] ;# nick1 nick2
set poke(team)         [list] ;# {challener {{species pokemon ...} {species pokemon ...}}} {trainer }
set poke(currentPoke)  [list] ;# nick1 poke1 nick2 poke2
set poke(rules)        "6v6"
set poke(crules)       "6v6"
set poke(forfeit)      [list] ;# nick1 nick2
set poke(ready)        [list] ;# nick1 nick2
set poke(battleready)  0
set poke(prio10)       [list] ;# action1 action2 ...
set poke(prio5)        [list]
set poke(prio4)        [list]
set poke(prio3)        [list]
set poke(prio2)        [list]
set poke(prio1)        [list]
set poke(prio0)        [list]
set poke(prio-1)       [list]
set poke(prio-2)       [list]
set poke(prio-3)       [list]
set poke(prio-4)       [list]
set poke(prio-5)       [list]
set poke(prio-6)       [list]
set poke(prio-7)       [list]

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

proc poke:challenge {nick host hand chan arg} {
  global poke
  if {$poke(chan) ne $chan} {return}
  if {$poke(running) > 0} {
    putquick "NOTICE $nick :A battle is already under way!"
    return
  }
  if {[llength $arg] > 3} {
    putquick "NOTICE $nick :Incorrect number of parameters. Use: !challenge \[nick\] \[rules\]"
    return
  }
  set ruleid [lsearch $arg "-rule"]
  if {$ruleid > -1} {
    set rule [lindex $arg end]
    if {[regexp -nocase {^([1-6])v([1-6])$} $rule - ch ta]} {
      set poke(crules) [string tolower $rule]
    } else {
      putquick "NOTICE $nick :Invalid rule format. Numbers must be between 1-6 an in the format #v#."
      return
    }
    set arg [lreplace $arg $ruleid $ruleid+1]
  }
  set target [string trim [lindex $arg 0]]
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
  set poke(gen)          6
  set poke(prepList)     [list]
  set poke(trainerList)  [list]
  set poke(team)         [list]
  set poke(currentPoke)  [list]
  set poke(crules)       "6v6"
  set poke(forfeit)      [list]
  set poke(ready)        [list]
  set poke(battleready)  0
  set poke(prio10)       [list]
  set poke(prio5)        [list]
  set poke(prio4)        [list]
  set poke(prio3)        [list]
  set poke(prio2)        [list]
  set poke(prio1)        [list]
  set poke(prio0)        [list]
  set poke(prio-1)       [list]
  set poke(prio-2)       [list]
  set poke(prio-3)       [list]
  set poke(prio-4)       [list]
  set poke(prio-5)       [list]
  set poke(prio-6)       [list]
  set poke(prio-7)       [list]
  catch {unbind pub - accept poke:accept}
  catch {unbind pub - decline poke:decline}
  catch {unbind msgm - "*" poke:battleprep}
  catch {unbind msgm - "*" poke:battle}
  
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
        set id [lsearch $poke(forfeit) $nick]
        set poke(forfeit) [lreplace $poke(forfeit) $id $id]
        putquick "PRIVMSG $nick :Please continue with your team editing."
      }
    }
  } elseif {$nick in $poke(ready)} {
    switch -nocase -regexp -- $arg {
      y(es?)? {
        if {$nick in $poke(trainerList)} {return}
        putquick "PRIVMSG $poke(chan) :$nick's team is ready!"
        lappend poke(trainerList) $nick
        if {[llength $poke(trainerList)] == 2} {
          lassign $poke(trainerList) trainer1 trainer2
          set poke1 [lindex $poke(team) 0 1 0]
          set poke2 [lindex $poke(team) 1 1 0]
          array set pokemon1 $poke1
          array set pokemon2 $poke2
          set tpoke1 $pokemon1(species)
          set tpoke2 $pokemon2(species)
          lappend poke(currentPoke) $trainer1 $poke1 $trainer2 $poke2
          unbind msgm - "*" poke:battleprep
          bind msgm - "*" poke:battle
          
          putquick "PRIVMSG $poke(chan) :Now that both trainer's teams are ready, the match will begin!"
          putquick "PRIVMSG $poke(chan) :$trainer1 sends out $tpoke1!"
          putquick "PRIVMSG $poke(chan) :$trainer2 sends out $tpoke2!"
          
          putquick "PRIVMSG $tpoke1 :Your Pokemon is awaiting your orders. What will you do? (attack | switch | forfeit)"
          putquick "PRIVMSG $tpoke2 :Your Pokemon is awaiting your orders. What will you do? (attack | switch | forfeit)"
        }
      }
      no? {
        if {$nick ni $poke(ready)} {return}
        set id [lsearch $poke(ready) $nick]
        set poke(ready) [lreplace $poke(ready) $id $id]
        putquick "PRIVMSG $nick :Finalize your team and type \"done\" when you are ready."
      }
    }
  } else {
    set id [lsearch -index 0 -nocase $poke(team) $nick]
    switch -nocase -glob -- $arg {
      teamhelp {
        putquick "PRIVMSG $nick :See this pastebin for the syntax: http://pastebin.com/Ym1amdKE"
        putquick "PRIVMSG $nick :Use \"forfeit\" to give up."
        putquick "PRIVMSG $nick :Use \"cancel #\" to remove the Pokemon in the #th slot."
        putquick "PRIVMSG $nick :Use \"reorder # # # # # #\" to reorder your Pokemon order."
        putquick "PRIVMSG $nick :Use \"done\" to finalize and submit your team."
        putquick "PRIVMSG $nick :Use \"pastebin linktopastebin\" to submit a team from pastebin (it should also follow the required format)"        
      }
      forfeit {
        putquick "PRIVMSG $nick :Are you sure you want to forfeit? (Y/N)"
        lappend poke(forfeit) $nick
      }
      cancel* {
        set param [lreplace $arg 0 0]
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
        set new [lreplace $arg 0 0]
        set new [regexp -all -inline -- {\d} $new]
        set crules [lindex [split $poke(crules) "v"] $id]
        set len [llength $new]
        set cteam [lindex $poke(team) $id 1]
        if {$len == 1} {
          putquick "PRIVMSG $nick :You cannot reorder your team when you have only one Pokemon!"
          return
        }
        if {$len != [llength $cteam]} {
          putquick "PRIVMSG $nick :Unequal indices to reorder from. Use \"reorder [join [lrepeat $len #]]\" to reorder your Pokemon order."
          return
        }
        set minA [lindex [lsort -integer -increasing $new] 0]
        set maxA [lindex [lsort -integer -decreasing $new] 0]
        if {$minA < 0 || $maxA > $crules} {
          putquick "PRIVMSG $nick :Invalid index detected. Indices must be between 1 and $crules inclusive."
          return
        }
        if {[llength [lsort -unique $new]] != $len} {
          putquick "PRIVMSG $nick :Duplicate indices detected. Indicies must tbe unique."
          return
        }
        set lineup [poke:reorder $nick $id $new $crules]
        set note ""
        if {$len = $crules} {
          lappend poke(ready) $nick
          set note " Are you satisfied with your line up? (Y/N)"
        }
        putquick "PRIVMSG $nick :Your current line up is [join $lineup ", "].$note"
      }
      pastebin* {
        set link [lreplace $arg 0 0]
        if {[regexp -- {pastebin\.com/([a-zA-Z0-9]+)} $link - hash]} {
          set url "http://pastebin.com/raw/$hash"
          set token [::http::geturl $url]
          set file [::http::data $token]
          ::http::cleanup $token
          poke:pastebin $nick $file $id
        } else {
          putquick "PRIVMSG $nick :Link could not be resolved. Make sure it is a pastebin.com link."
        }
      }
      done {
        if {$nick in $poke(trainerList)} {return}
        putquick "PRIVMSG $nick :Are you sure you want to submit your team? (Y/N)"
        lappend poke(ready) $nick
      }
      default {
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
  
  lassign $elem pokemon(species) pokemon(level) pokemon(ability) pokemon(item) pokemon(nature) \
    pokemon(gender) pokemon(IHP) pokemon(IAtk) pokemon(IDef) pokemon(ISpA) pokemon(ISpD) \
    pokemon(ISpd) pokemon(EHP) pokemon(EAtk) pokemon(EDef) pokemon(ESpA) pokemon(ESpD) \
    pokemon(ESpd) pokemon(Move1) pokemon(Move2) pokemon(Move3) pokemon(Move4)
  
  set pass [poke:check [array get pokemon]]
  lassign $pass team status reason
  if {!$status} {
    putquick "PRIVMSG $nick :The was a problem with your Pokemon; it could not be registered."
    foreach sentence $reason {
      putquick "PRIVMSG $nick :Error: $sentence"
    }
    return 0
  }
  lappend cteam $team
  lset poke(team) $id 1 $cteam
  return $pokemon(species)
}

proc poke:reorder {nick id new crules} {
  global poke
  set cteam [lindex $poke(team) $id 1]
  set lineup [list]
  set pokelist [list]
  for oID $new {
    lappend lineup [lindex $cteam $oID]
    array set pokemon [lindex $cteam $oID]
    lappend pokelist $pokemon(species)
    array unset pokemon
  }
  lset poke(team) $id 1 $lineup
  return $pokelist
}

proc poke:pastebin {nick text id} {
  global poke
  set register [llength [lindex $poke(team) $id 1]]
  set lines [split $text "\r\n"]
  set count 0
  foreach line $lines {
    incr count
    if {$line == ""} {continue}
    set res [poke:parse $nick $line]
    if {[llength [split $res "/"]] == 22} {
      if {[info exist poke(buffer,$nick)]} {unset poke(buffer,$nick)}
      set registered [poke:register $nick $res $id]
      if {$registered != 0} {
        putquick "PRIVMSG $nick :$registered has successfully been registered!"
        incr register
        if {$register == $poke(crules)} {
          set lineup [list]
          foreach ind [lindex $poke(team) $id 1] {
            set id [lsearch -index 0 $ind "species"]
            lappend lineup [lindex $ind $id+1]
          }
          set note ""
          if {$count < [llength $lines] && [string trim [join [lrange $lines $count end] ""]] == ""} {
            set note " (Note: additional lines were detected, but won't be recorded because you already reached the limit of Pokemon in your team)"
          }
          putquick "PRIVMSG $nick :Your current line up is [join $lineup ", "]. Are you satisfied with your line up? (Y/N)$note"
          lappend poke(ready) $nick
          break
        }
      } else {
        putquick "PRIVMSG $nick :The Pokemon could not be registered. See this pastebin for the syntax: http://pastebin.com/Ym1amdKE."
        break
      }
    } elseif {$res eq "err"} {
      putquick "PRIVMSG $nick :The Pokemon could not be registered. See this pastebin for the syntax: http://pastebin.com/Ym1amdKE."
      break
    }
  }
}

proc poke:parse {nick arg} {
  global poke
  set group [split $arg "/"]
  if {[llength $group] == 22} {
    return $arg
  } elseif {[llength $group] < 22} {
    if {![info exist poke(buffer,$nick)]} {
      set poke(buffer,$nick) $arg
    } else {
      set poke(buffer,$nick) [regsub -all {//+} "$poke(buffer,$nick)/$arg" ""]
    }
  } else {
    putlog $group
    putquick "PRIVMSG $nick :Invalid format. See this pastebin for the syntax: http://pastebin.com/Ym1amdKE"
    if {[info exist poke(buffer,$nick)]} {unset poke(buffer,$nick)}
    return "err"
  }
  return $poke(buffer,$nick)
} 

proc poke:check {arg} {
  array set pokemon $arg
  set errors [list]
  set poketable pokeDetails$poke(gen)
  set itemtable itemDetails$poke(gen)
  set movetable moveDetails$poke(gen)
  set leartable learDetails$poke(gen)
  set natutable nature
  # TO DO: Replace current values with database values for presentation
  set pokedetails [dex eval "SELECT * FROM $poketable WHERE lower(formname) = lower('$pokemon(species)')"]
  lassign $pokedetails id species formname type genus ability1 ability2 hability gender egggroup \
    height weight legend evolve_cond hp atk def spatk spdef spd etc
  if {$pokedetails == ""} {
    lappend errors "Pokemon name is invalid."
  } else {
    set pokemon(species) $formname
  }
  if {!($pokemon(level) > 0 && $pokemon(level) <= 100)} {
    lappend errors "Pokemon level has to be between 1 and 100 inclusive."
  }
  set mID [lsearch -nocase [list $ability1 $ability2 $hability] $pokemon(ability)]
  if {$mID == -1} {
    lappend errors "Pokemon ability is invalid."
  } else {
    set pokemon(ability) [lindex [list $ability1 $ability2 $hability] $mID]
  }
  # if {[dex eval "SELECT 1 FROM $itemtable WHERE name = '$pokemon(item)'"] != 1} {
    # lappend errors [list "Held item is invalid."]
  # }
  set nature [dex eval "SELECT * FROM $natutable WHERE lower(name) = lower('$pokemon(nature)')"]
  if {$nature != ""} {
    lappend errors "Pokemon nature is invalid."
  } else {
    lassign $nature nat boost nerf 
    set pokemon(nature) $nat
  }
  if {[string toupper $pokemon(gender)] ni {M F NA}} {
    lappend errors "Pokemon gender is invalid."
  } else {
    set pokemon(gender) [string toupper $pokemon(gender)]
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
    if {$stat eq "HP"} {
      set pokemon($stat) [expr {(($pokemon(I$stat)+(2*$hp)+($pokemon(E$stat)/4))*$pokemon(level))/100+$pokemon(level)+10}]
    } else {
      set nat 1
      if {$boost ne $nerf} {
        if {$boost eq $stat} {set nat 1.1}
        if {$nerf eq $stat} {set nat 0.9}
      }
      set pokemon($stat) [expr {((($pokemon(I$stat)+(2*$hp)+($pokemon(E$stat)/4))*$pokemon(level))/100+5)*$nat}]
    }
  }
  if {$totalEV > 510} {
    lappend errors "Total EVs for the Pokemon exceed the maximum of 510."
  }
  set moveset [list]
  # TO DO: Add PP
  # TO DO: Add learnable moves and method of learning
  # foreach i {1 2 3 4} {
    # set move $pokemon(Move$i)
    # set moveid [dex eval "SELECT id FROM $movetable WHERE name = '$move'"]
    # if {$moveid == ""} {
      # lappend errors "$pokemon(Move$i) is an invalid move."
      # continue
    # }
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
    return [list [array get pokemon] 0 $errors]
  } else {
    return [array get pokemon] 1
  }
}

proc poke:battle {nick host hand arg} {
  global poke
  if {$nick ni $poke(trainerList)} {return}
  if {$nick in $poke(forfeit)} {
    switch -nocase -regexp -- $arg {
      y(es?)? {
        if {$nick ni $poke(forfeit)} {return}
        set id [lsearch $nick $poke(trainerList)]
        set oID [lindex $poke(trainerList) [expr {abs($id-3)}]]
        putquick "PRIVMSG $nick :You have forfeited the battle."
        putquick "PRIVMSG $poke(chan) :$nick has forfeited the battle."
        putquick "PRIVMSG [lindex $poke(trainerList) $oID] :$nick has forfeited the battle."
        poke:stop
      }
      no? {
        if {$nick ni $poke(forfeit)} {return}
        set id [lsearch $poke(forfeit) $nick]
        set poke(forfeit) [lreplace $poke(forfeit) $id $id]
        putquick "PRIVMSG $nick :Your Pokemon is awaiting your orders. What will you do? (attack | switch | forfeit)"
      }
    }
    return
  } else {
    set id [lsearch $poke(currentPoke) $nick]
    set challenger [lsearch -index 0 $poke(team) $nick]
    set currentPoke [lindex $poke(currentPoke) $id+1]
    switch -nocase -regexp -var param -- $arg {
      battlehelp {
        putquick "PRIVMSG $nick :Use \"attack movename\" to use a move."
        putquick "PRIVMSG $nick :Use \"switch #\" to switch your current Pokemon to one from the #th slot."
        putquick "PRIVMSG $nick :Use \"forfeit\" to give up this Pokemon battle."
        return
      }
      {^(?:at(?:tack)?|move) *(.*)$} {
        set movetable moveDetails$poke(gen)
        set details [dex eval "SELECT * FROM $movetable WHERE name = '$param'"]
        lassign $details mid name type class pp basepower accuracy priority etc
        lappend poke(prio$priority) [list "pokemove:$name" $nick $currentPoke]
        incr poke(battleready)
      }
      {^switch *(.*)$} {
        set crules [lindex [split $poke(crules) "v"] $challenger]
        if {[string is integer $param] && $crules <= $poke(crules) && $crules > 0} {
          lappend poke(prio10) "poke:switch $currentPoke"
          incr poke(battleready)
        } else {
          putquick "PRIVMSG $nick :Invalid number"
          return
        }
      }
      mega {
        
      }
      forfeit {
        putquick "PRIVMSG $nick :Are you sure you want to forfeit? (Y/N)"
        lappend poke(forfeit) $nick
        return
      }
    }
    if {$poke(battleready) == 2} {
      poke:battleresolve
    }
  }
}

proc poke:battleresolve {} {
  global poke
}

putlog "Pokemon Battle $poke(ver) loaded."
