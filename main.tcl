######################
### Configurations ###
######################
### Defaults
set poke(chan)         "#Jerry"
set poke(stats)        "pokemon/stats"
set poke(ver)          "pre 0.0.3"

### Global Variables
set poke(running)      0
set poke(gen)          6
set poke(prepList)     [list] ;# challenger trainer
set poke(trainerList)  [list] ;# nick1 nick2
set poke(team)         [list] ;# {challenger {{species pokemon ...} {species pokemon ...}}} {trainer }
set poke(currentPoke)  [list] ;# nick1 poke1 nick2 poke2
set poke(rules)        "6v6"
set poke(crules)       "6v6"
set poke(forfeit)      [list] ;# nick1 nick2
set poke(ready)        [list] ;# nick1 nick2
set poke(battleready)  0
set poke(prio10)       [list] ;# speed {action1} {action2} ... -> switches
set poke(prio9)        [list]                               ;# -> mega evos
set poke(prio5)        [list]                               ;# -> moves
set poke(prio4)        [list]                               ;# -> moves
set poke(prio3)        [list]                               ;# -> moves
set poke(prio2)        [list]                               ;# -> moves
set poke(prio1)        [list]                               ;# -> moves
set poke(prio0)        [list]                               ;# -> moves
set poke(prio-1)       [list]                               ;# -> moves
set poke(prio-2)       [list]                               ;# -> moves
set poke(prio-3)       [list]                               ;# -> moves
set poke(prio-4)       [list]                               ;# -> moves
set poke(prio-5)       [list]                               ;# -> moves
set poke(prio-6)       [list]                               ;# -> moves
set poke(prio-7)       [list]                               ;# -> moves
set poke(prio-9)       [list]                               ;# -> other heal; leftovers, wish, etc
set poke(prio-10)      [list]                               ;# -> other dmg; burn, poison, sandstorm, etc
set poke(field)        [list] ;# nick1 {condition1 param condition2 param ...} nick2 {}
set poke(triggers)     [list] ;# {contact {pokemon effect pokemon effect} faint {} snatch {} 
                               #  substitute {}}
set poke(fainted)      [list]
set poke(currentPrio)  ""
                               
### poke(team)
#{
#  Jerry
#  {
#    {
#      species Bulbasaur
#      level 100
#      ability Overgrow
#      item "Miracle Seed"
#      nature Adamant
#      gender M
#      IHP 31
#      IAtk 31
#      IDef 31
#      ISpA 31
#      ISpD 31
#      ISpd 31
#      EHP 31
#      EAtk 31
#      EDef 31
#      ESpA 31
#      ESpD 31
#      ESpd 31
#      Move1 {Tackle 45}
#      Move2 {Growl 45}
#      Move3 {"Leech Seed" 10}
#      Move4 {"Vine Whip" 10}
#      HP 100
#      Atk 100
#      Def 100
#      SpA 100
#      SpD 100
#      Spd 100
#      cHP 100
#      status {BPOI CON "Atk -2" "Eva +2"}
#       # Possible values:
#         POI
#         SLP
#         PAR
#         FRZ
#         Atk +-#
#         Def +-#
#         SpA +-#
#         Spd +-#
#         Eva +-#
#         Acc +-#
#         Crit +#
#    }
#    {
#      species
#    }
#  }
#}
#{
#  trainer
#}

### Modules
package require http
package require sqlite3
sqlite3 dex pokedexdb
source battle_moves.tcl

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
### poke:restart - bound to event
# Stop everywhing before a restart or rehash
proc poke:prestart {type} {
  global botnick poke
  poke:stop $botnick console $botnick $poke(chan) "" 
}

### poke:chancommands - bound to public command !pokecmd
# Commands for pokemon battles
proc poke:chancommands {nick host hand chan arg} {
  global poke
  if {$chan ne $poke(chan)} {return}
  set header [format "%-30s %+7s " "Function:" "Command:"]
  set challenge [format "%-30s %+7s " "!challenge \[nick\] -rule \[rules\]" "Issues a challenge to nick with 6v6 rule default"]
  set endbattle [format "%-30s %+7s " "!endbattle" "Ends the current battle"]
  putquick "NOTICE $nick :$header"
  putquick "NOTICE $nick :$challenge"
  putquick "NOTICE $nick :$endbattle"
}

### poke:challenge - bound to public command !challenge user rules
# Challenge a player to a battle
#  Does not start a new battle if one already underway
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

### poke: - bound to public command accept
# Accepts a challenge placed earlier. Does not work if no challenge was placed.
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

### poke:decline - bound to public command !decline
# Declines a challenge placed earlier against the user. Does not work if no challenge targetting the
# user was placed.
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

### poke:stop - bound to public command !endbattle
# Ends a currently ongoing battle
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
  set poke(prio-10)      [list]
  set poke(field)        [list]
  set poke(triggers)     [list]
  set poke(fainter)      [list]
  catch {unbind pub - accept poke:accept}
  catch {unbind pub - decline poke:decline}
  catch {unbind msgm - "*" poke:battleprep}
  catch {unbind msgm - "*" poke:battle}
  
  if {$arg eq ""} {
    putquick "PRIVMSG $chan :The current battle has been stopped."
  }
}

### poke:battleprep - bound to private message
# Commands to set up team before the battle. Available commands:
# teamhelp                 - displays available commands
# forfeit                  - forfeits the challenge and stop the battle
# cancel 1 2 3 4 5 6 all   - cancel the registration of pokemon at positions
# reorder 1 2 > 2 1        - reorder pokemon from and to
# pastebin link            - register a pokemon from pastebin
# done                     - conclude pokemon registration
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
        poke:stop - - - $poke(chan) ""
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
        lappend poke(field) $nick {}
        if {[llength $poke(trainerList)] == 2} {
          lassign $poke(trainerList) trainer1 trainer2
          set poke1 [lindex $poke(team) 0 1 0]
          set poke2 [lindex $poke(team) 1 1 0]
          array set pokemon1 $poke1
          array set pokemon2 $poke2
          set tpoke1 $pokemon1(species)
          set tpoke2 $pokemon2(species)
          lappend poke(currentPoke) $trainer1 $tpoke1 $trainer2 $tpoke2
          unbind msgm - "*" poke:battleprep
          bind msgm - "*" poke:battle
          
          putquick "PRIVMSG $poke(chan) :Now that both trainer's teams are ready, the match will begin!"
          putquick "PRIVMSG $poke(chan) :$trainer1 sends out $tpoke1!"
          putquick "PRIVMSG $poke(chan) :$trainer2 sends out $tpoke2!"
          
          putquick "PRIVMSG $tpoke1 :Your Pokémon is awaiting your orders. What will you do? (attack | switch | forfeit)"
          putquick "PRIVMSG $tpoke2 :Your Pokémon is awaiting your orders. What will you do? (attack | switch | forfeit)"
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
        putquick "PRIVMSG $nick :Use \"cancel #\" to remove the Pokémon in the #th slot."
        putquick "PRIVMSG $nick :Use \"reorder # # # # # #\" to reorder your Pokémon order."
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
          putquick "PRIVMSG $nick :All your Pokémon have been removed."
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
              putquick "PRIVMSG $nick :Use \"cancel #\" to remove the Pokémon in the #th slot. # has to be between 1 and $len."
              break
            }
          }
          if {[llength $removed] > 0} {
            set removed [join [lsort -increasing $removed] ", "]
            putquick "PRIVMSG $nick :Pokémon at slots $removed have successfully been removed."
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
          putquick "PRIVMSG $nick :The Pokémon at the $param$ord slot ($pokename) has been removed."
        } else {
          putquick "PRIVMSG $nick :Use \"cancel #\" to remove the Pokémon in the #th slot. # has to be between 1 and $len."
        }
      }
      reorder* {
        set new [lreplace $arg 0 0]
        set new [regexp -all -inline -- {\d} $new]
        set crules [lindex [split $poke(crules) "v"] $id]
        set len [llength $new]
        set cteam [lindex $poke(team) $id 1]
        if {$len == 1} {
          putquick "PRIVMSG $nick :You cannot reorder your team when you have only one Pokémon!"
          return
        }
        if {$len != [llength $cteam]} {
          putquick "PRIVMSG $nick :Unequal indices to reorder from. Use \"reorder [join [lrepeat $len #]]\" to reorder your Pokémon order."
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
          if {[llength [split $res "/"]] == 22} {
            if {[info exist poke(buffer,$nick)]} {unset poke(buffer,$nick)}
            set registered [poke:register $nick $res $id]
            if {$registered == 0} {return}
            incr len
            putquick "PRIVMSG $nick :$registered has successfully been registered! You now have $len Pokémon of $poke(crules) allowed."
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

### poke:register - called from poke:battleprep
# Register a pokemon and parse the data
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
    putquick "PRIVMSG $nick :The was a problem with your Pokémon; it could not be registered."
    foreach sentence $reason {
      putquick "PRIVMSG $nick :Error: $sentence"
    }
    return 0
  }
  lappend cteam $team
  lset poke(team) $id 1 $cteam
  return $pokemon(species)
}

### poke:reorder - called from poke:battleprep
# Reorders pokemon
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

### poke:pastebin - called from poke:battleprep
# Read the data from the link and parse it
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
            set note " (Note: additional lines were detected, but won't be recorded because you already reached the limit of Pokémon in your team)"
          }
          putquick "PRIVMSG $nick :Your current line up is [join $lineup ", "]. Are you satisfied with your line up? (Y/N)$note"
          lappend poke(ready) $nick
          break
        }
      } else {
        putquick "PRIVMSG $nick :The Pokémon could not be registered. See this pastebin for the syntax: http://pastebin.com/Ym1amdKE."
        break
      }
    } elseif {$res eq "err"} {
      putquick "PRIVMSG $nick :The Pokémon could not be registered. See this pastebin for the syntax: http://pastebin.com/Ym1amdKE."
      break
    }
  }
}

### poke:parse - called from poke:battleprep and poke:pastebin
# Parses information
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
    putquick "PRIVMSG $nick :Invalid format. See this pastebin for the syntax: http://pastebin.com/Ym1amdKE"
    if {[info exist poke(buffer,$nick)]} {unset poke(buffer,$nick)}
    return "err"
  }
  return $poke(buffer,$nick)
} 

### poke:check - called from poke:register
# Checks for validity of supplied information. Rejects the registration for invalid information
# such as invalid pokemon, moves, item, etc
proc poke:check {arg} {
  global poke
  array set pokemon $arg
  set errors [list]
  set poketable pokeDetails$poke(gen)
  set itemtable itemDetails$poke(gen)
  set movetable moveDetails$poke(gen)
  set natutable nature
  
  # TO DO: Replace current values with database values for presentation
  set pokedetails [dex eval "SELECT * FROM $poketable WHERE lower(formname) = lower('$pokemon(species)')"]
  lassign $pokedetails id species formname type genus ability1 ability2 hability gender egggroup \
    height weight legend evolve_cond hp atk def spatk spdef spd etc
  if {$pokedetails == ""} {
    lappend errors "Pokémon name is invalid."
  } else {
    set pokemon(species) $formname
  }
  if {!($pokemon(level) > 0 && $pokemon(level) <= 100)} {
    lappend errors "Pokémon level has to be between 1 and 100 inclusive."
  }
  set mID [lsearch -nocase [list $ability1 $ability2 $hability] $pokemon(ability)]
  if {$mID == -1} {
    lappend errors "Pokémon ability is invalid."
  } else {
    set pokemon(ability) [lindex [list $ability1 $ability2 $hability] $mID]
  }
  # Need to create item table
  # if {[dex eval "SELECT 1 FROM $itemtable WHERE name = '$pokemon(item)'"] != 1} {
    # lappend errors [list "Held item is invalid."]
  # }
  set nature [dex eval "SELECT * FROM $natutable WHERE lower(name) = lower('$pokemon(nature)')"]
  if {$nature == ""} {
    lappend errors "Pokémon nature is invalid."
  } else {
    lassign $nature nat boost nerf 
    set pokemon(nature) $nat
  }
  if {[string toupper $pokemon(gender)] ni {M F NA}} {
    lappend errors "Pokémon gender is invalid."
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
      set pokemon(cHP) $pokemon($stat)
      set pokemon(status) ""
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
    lappend errors "Total EVs for the Pokémon exceed the maximum of 510."
  }
  set moveset [list]

  set movetabs [dex eval "
    SELECT name FROM SQLITE_MASTER WHERE type = 'table' AND name LIKE 'moves%$poke(gen)'
  "]
  foreach tab $movetabs {
    set learnedmoves [split [lindex [dex eval "SELECT moves FROM $tab where id = '$id'"] 0] \t]
    set movedet [list]
    if {[string first "Levelup" $tab] > -1} {
      foreach {lvl moveid} $learnedmoves {
        set movedet [dex eval "SELECT id, name, pp FROM $movetable WHERE id = $moveid"]
        if {$movedet != ""} {lappend moveset $movedet}
      }
    } else {
      foreach moveid $learnedmoves {
        set movedet [dex eval "SELECT id, name, pp FROM $movetable WHERE id = $moveid"]
        if {$movedet != ""} {lappend moveset $movedet}
      }
    }
  }
  foreach i {1 2 3 4} {
    set move $pokemon(Move$i)
    lappend cmoves $move
    set movegroup [dex eval "SELECT id, name, pp FROM $movetable WHERE name = '$move'"]
    lassign $movegroup moveid movename movepp
    if {$moveid == ""} {
      lappend errors "$pokemon(Move$i) is an invalid move."
      continue
    }
    if {[set finid [lsearch -index 0 $moveset $moveid]] == -1} {
      lappend errors [list "The Pokémon cannot learn the move $move."]
      continue
    }
    set pokemon(Move$i) [list $movename $movepp]
  }
  
  if {[llength $cmoves] != [llength [lsort -unique $cmoves]]} {
    lappend errors "The Pokémon's moveset contains duplicate moves."
  }
  
  if {[llength $errors] > 0} {
    return [list [array get pokemon] 0 $errors]
  } else {
    set pokemon(type) $type
    return [list [array get pokemon] 1]
  }
}

### poke:battle - called after battleprep complete
# Assigns new commands to PM for the battle.
# battlehelp                  - displays available commands
# attack|move movename        - select a move for the pokemon to do
# switch targetpokemonnumber  - switch to a pokemon
# mega attack|move movename   - mega evolve current pokemon and use a move
# checkteam                   - check own team
# check                       - check current field
# forfeit                     - forfeit the battle
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
        poke:stop - - - $poke(chan) ""
      }
      no? {
        if {$nick ni $poke(forfeit)} {return}
        set id [lsearch $poke(forfeit) $nick]
        set poke(forfeit) [lreplace $poke(forfeit) $id $id]
        putquick "PRIVMSG $nick :Your Pokémon is awaiting your orders. What will you do? (attack | switch | forfeit)"
      }
    }
    return
  } else {
    set id [lsearch $poke(currentPoke) $nick]
    set challenger [lsearch -index 0 $poke(team) $nick]
    set currentPoke [lindex $poke(currentPoke) $id+1]
    switch -nocase -regexp -matchvar param -- $arg {
      {^battlehelp$} {
        putquick "PRIVMSG $nick :Use \"attack movename\" to use a move."
        putquick "PRIVMSG $nick :Use \"switch #\" to switch your current Pokémon to one from the #th slot."
        putquick "PRIVMSG $nick :Use \"forfeit\" to give up this Pokémon battle."
        putquick "PRIVMSG $nick :Use \"checkteam\" to view your team."
        putquick "PRIVMSG $nick :Use \"check\" to view the current Pokémon status and field."
        
        return
      }
      {^(?:at(?:tack)?|move) *(.*)$} {
        set param [string trim [lindex $param 1]]
        set cteam [lindex $poke(team) $challenger 1]
        set cID [lsearch -regexp $cteam "\\yspecies $currentPoke\\y"]
        set cPokemon [lindex $cteam $cID]
        array set pokemon $cPokemon
        set moves [array get pokemon Move*]
        set cmoves [lmap {a b} $moves {set b}]
        
        set idx [lsearch -index 0 -nocase $cmoves $param]
        if {$idx > -1} {
          set move [lindex $cmoves $idx 0]
        } elseif {[string is integer $param] && $param > 0 && $param < 5} {
          set movedet $pokemon(Move$param)
          lassign $movedet move pp
        } else {
          putquick "PRIVMSG $nick : Your Pokémon doesn't know that move. Your Pokémon knows the following moves: $pokemon(Move1), $pokemon(Move2), $pokemon(Move3), $pokemon(Move4)"
          return
        }
        set movetable moveDetails$poke(gen)
        set details [dex eval "SELECT * FROM $movetable WHERE name = '$move'"]
        lassign $details mid name type class pp basepower accuracy priority etc
        if {$priority eq ""} {set priority 0}
        lappend poke(prio$priority) [list $pokemon(Spd) "poke:move:$name" $nick $currentPoke $challenger $cID [expr {2-$id}]]
        incr poke(battleready)
      }
      {^switch *(.*)$} {
        set param [string trim [lindex $param 1]]
        set crules [lindex [split $poke(crules) "v"] $challenger]
        set cteam [lindex $poke(team) $challenger 1]
        set cID [lsearch -regexp $cteam "\\yspecies $currentPoke\\y"]
        if {[string is integer $param] && $param >= 1 && $param < [llength $cteam]} {
          incr param -1
          if {$cID == $param} {
            putquick "PRIVMSG $nick :Pick a Pokémon other than your current Pokémon."
            return
          }
          set nID $param
        } elseif {![string is integer $param]} {
          # Add pokemon name choice
          set nID [lsearch -nocase -regexp $cteam "\\yspecies $param\\y"]
          if {$nID == -1} {
            putquick "PRIVMSG $nick :You don't have this Pokemon on your team."
            return
          }
        } else {
          putquick "PRIVMSG $nick :Invalid number"
          return
        }
        set tPokemon [lindex $cteam $nID]
        array set pokemon $tPokemon
        if {$pokemon(cHP) == 0} {
          putquick "PRIVMSG $nick :That Pokémon cannot battle anymore! Please pick another."
          return
        }
        poke:trigger block $nick - - -
        lappend poke(prio10) "0 poke:switch $nick $cID $nID"
        incr poke(battleready)
      }
      {^mega +(?:at(?:tack)?|move) *(.*)$} {
        set match 0
        foreach a [split $item ""] b [split $name ""] {
          if {$a eq $b} {incr match} else {break}
        }
        if {[regexp -- {\S+ite} $item] && $match > 4} {
          lappend poke(prio9) [list 0 poke:mega $currentPoke]
        } else {
          putquick "PRIVMSG $nick :Your Pokémon cannot mega evolve!"
          return
        }
        
        set param [string trim [lindex $param 1]]
        set cteam [lindex $poke(team) $challenger 1]
        set cID [lsearch -regexp $cteam "\\yspecies $currentPoke\\y"]
        set cPokemon [lindex $cteam $cID]
        array set pokemon $cPokemon
        set moves [array get pokemon Move*]
        set cmoves [lmap {a b} $moves {set b}]
        
        set idx [lsearch -index 0 -nocase $cmoves $param]
        if {$idx > -1} {
          set move [lindex $cmoves $idx 0]
        } elseif {[string is integer $param] && $param > 0 && $param < 5} {
          set movedet $pokemon(Move$param)
          lassign $movedet move pp
        } else {
          putquick "PRIVMSG $nick : Your Pokémon doesn't know that move. Your Pokémon knows the following moves: $pokemon(Move1), $pokemon(Move2), $pokemon(Move3), $pokemon(Move4)"
          return
        }
        set movetable moveDetails$poke(gen)
        set details [dex eval "SELECT * FROM $movetable WHERE name = '$move'"]
        lassign $details mid name type class pp basepower accuracy priority etc
        if {$priority eq ""} {set priority 0}
        lappend poke(prio$priority) [list $pokemon(Spd) "poke:move:$name" $nick $currentPoke $challenger $cID [expr {2-$id}]]
        incr poke(battleready)
      }
      {^checkteam$} {
        set cteam [lindex $poke(team) $challenger 1]
        foreach n $cteam {
          array set pokemon $n
          set status [format "%-11s %-5s %+3s/%+3s" $pokemon(species) $pokemon(status) $pokemon(cHP) $pokemon(HP)]
          putquick "PRIVMSG $nick :$status"
        }
        array unset pokemon
      }
      {^check$} {
        set cteam [lindex $poke(team) $challenger 1]
        set cID [lsearch -regexp $cteam "\\yspecies $currentPoke\\y"]
        set cPokemon [lindex $cteam $cID]
        array set pokemon $cPokemon
        set condition [array names pokemon Battle*]
        set condList [lmap x $condition {set $pokemon($x)}]
        array set field $poke(field)
        array set fieldstat $field($nick)
        set status [format "%s %s %s/%s Conditions: %s" $pokemon(species) $pokemon(status) $pokemon(cHP) $pokemon(HP) [join $condList ", "]]
        putquick "PRIVMSG $nick :Pokémon: $status"
        putquick "PRIVMSG $nick :Field: [join [array names fieldstat] {, }]"
        array unset pokemon
        array unset field
        array unset fieldstat
        
        set opponent [lindex $poke(team) 1-$challenger 0]
        set oteam [lindex $poke(team) 1-$challenger 1]
        set oID [lsearch -regexp $cteam "\\yspecies [lindex $poke(currentPoke) 3-$id]\\y"]
        set oPokemon [lindex $oteam $oID]
        array set pokemon $oPokemon
        set condition [array names pokemon Battle*]
        set condList [lmap x $condition {set $pokemon($x)}]
        array set field $poke(field)
        array set fieldstat $field($opponent)
        set status [format "%s %s %s/%s Conditions: %s" $pokemon(species) $pokemon(status) \
          $pokemon(cHP) $pokemon(HP) [join $condList ", "]]
        putquick "PRIVMSG $nick :Opponent: $status"
        putquick "PRIVMSG $nick :Field: [join [array names fieldstat] {, }]"
        array unset pokemon
        array unset field
        array unset fieldstat
      }
      {^forfeit$} {
        putquick "PRIVMSG $nick :Are you sure you want to forfeit? (Y/N)"
        lappend poke(forfeit) $nick
        return
      }
    }
    if {$poke(battleready) == 2} {
      unbind msgm - "*" poke:battle
      poke:battleresolve
      set poke(battleready) 0
      return
    }
  }
}

### poke:battleresolve
# Called after both players did their moves
proc poke:battleresolve {} {
  global poke
  foreach i {10 9 5 4 3 2 1 0 -1 -2 -3 -4 -5 -6 -7 -10} {
    if {$poke(currentPrio) != "" && $poke(currentPrio) < $i} {
      continue
    } else {
      set poke(currentPrio) $i
    }
      
    if {[llength $poke(prio$i)] != 0} {
      set shuffled [poke:shuffle $poke(prio$i)]
      foreach actionset [lsort -decreasing -index 0 -integer $shuffled] {
        set aID [lsearch $poke(prio$i) $actionset]
        set poke(prio$i) [lreplace $poke(prio$i) $aID $aID]
        set action [lreplace $actionset 0 0]
        if {[string match "poke:move:*" [lindex $action 0]]} {          
          lassign $action procedure nick pokemon trainerID pokeID opponentID
          if {[list $nick $pokemon] in $poke(fainted)} {continue}
          set pokedet [lindex $poke(team) $trainerID 1 $pokeID]
          set opponentPoke [lindex $poke(currentPoke) $opponentID+1]
          set opTeam [lindex $poke(team) [expr {1-$trainerID}] 1]
          set opPokeID [lsearch -regexp $opTeam "\\yspecies $opponentPoke\\y"]
          set opPokeDet [lindex $opTeam $opPokeID]
          set otrainer [lindex $poke(currentPoke) $opponentID]
          set stop [[string tolower [join $procedure ""]] $nick $pokedet $otrainer $opPokeDet]
          if {$stop} {break}
        } else {
          #####
        }
      }
    }    
  }
  if {$i == -10} {
    set poke(currentPrio) ""
    bind msgm - "*" poke:battle
  }
}

### poke:hidden_power_calc - called only for hidden power
proc poke:hidden_power_calc {hp atk def spd spA spD} {
  set sumT 0
  set sumD 0
  set i 0
  foreach s [list $hp $atk $def $spd $spA $spD] {
    if {$s % 2} {set sumT [expr {$sumT+(2**$i)}]}
    if {$s % 4 > 1} {set sumD [expr {$sumD+(2**$i)}]}
    incr i
  }
  set resT [expr {$sumT*15/63}]
  set types [list Fighting Flying Poison Ground Rock Bug Ghost Steel Fire Water Grass Electric \
    Psychic Ice Dragon Dark]
  set resD [expr {$sumD*40/63+30}]
  
  return [list [lindex $types $resT] $resD]
}

# http://wiki.tcl.tk/941 shuffle6 - for speed ties
proc poke:shuffle {list} {
  set n [llength $list]
  for {set i 1} {$i < $n} {incr i} {
    set j [expr { int( rand() * $n ) }]
    set temp [lindex $list $i]
    lset list $i [lindex $list $j]
    lset list $j $temp
  }
  return $list
}

### poke:damage_calc - Called when standard damage is to be calculated.
proc poke:damage_calc {pokedet oPokedet bp acc type class flags} {
  global poke
  array set pokemon $pokedet
  array set opokemon $oPokedet

  if {$class eq "Physical"} {
    set atk $pokemon(Atk)
    set def $pokemon(Def)
    set aboost [poke:boost $pokemon(status) "Atk"]
    set dboost [poke:boost $opokemon(status) "Def"]
  } elseif {$class eq "Special"} {
    set atk $pokemon(SpA)
    set def $pokemon(SpD)
    set aboost [poke:boost $pokemon(status) "SpA"]
    set dboost [poke:boost $opokemon(status) "SpD"]
  } else {}
   
  set stab [expr {$type in [split $pokemon(type) "/"] ? 1.5 : 1}]
  set weak [poke:get_weakness $type $opokemon(type)]
  
  poke:random
  
  set hit [rand 100]
  if {$hit > $acc} {
    return [list "miss" 0 0]
  } elseif {$weak == 0} {
    return "no effect"
  }
  
  poke:random
  
  set idx [lsearch -index 0 $pokemon(status) "Crit"]
  set tidx [lsearch -index 0 $pokemon(status) "tempCrit"]
  set crit 0
  
  set critChance [rand 10000]
  
  if {$idx == -1 && $tidx == -1} {
    set critRate 625
  } else {
    set value 0
    if {$idx > -1} {
      regexp {Crit (\d)} [lindex $pokemon(status) $idx] - value
    }
    set tvalue 0
    if {$idix > -1} {
      regexp {Crit (\d)} [lindex $pokemon(status) $tidx] - tvalue
    }
    if {$value == -1 || $tvalue == -1} {
      set value -1
    } else {
      set value [expr $value$tvalue]
    }
    
    switch $value {
      -1 {set critRate 0}
      0  {set critRate 625}
      1  {set critRate 1250}
      2  {set critRate [expr {$poke(gen) < 6 ? 2500 : 5000}]}
      3  {set critRate [expr {$poke(gen) < 6 ? 3333 : 10000}]}
      4  {set critRate [expr {$poke(gen) < 6 ? 3300 : 10000}]}
      default {set critRate [expr {$poke(gen) < 6 ? 3300 : 10000}]}
    }
  }
  
  if {$critChance < $critRate} {
    set critValue [expr {$poke(gen) > 5 ? 1.5 : 2}]
    if {$aboost < 1} {set aboost 1}
    if {$dboost > 1} {set dboost 1}
    set dmgBase [expr {((($pokemon(level)+5.0)*$bp*$aboost*$atk)/(125*$dboost*$def)+2)*$stab*$weak}]
    set dmgBase [expr {$dmgBase*$critValue}]
    incr crit
  } else {
    set dmgBase [expr {((($pokemon(level)+5.0)*$bp*$aboost*$atk)/(125*$dboost*$def)+2)*$stab*$weak}]
  }
  
  switch $poke(field) {
    sun {}
    rain {}
    sand {}
    hail {}
    gravity {}
    default {}
  }
  
  if {$weak == 0} {
    set type "no effect"
  } elseif {$weak > 0 && $weak < 1} {
    set type "not effective"
  } elseif {$weak == 1} {
    set type "normal"
  } else {
    set type "super effective"
  }
  return [list $type [expr {int($dmgBase)}] $crit]
}

proc poke:get_weakness {mType type} {
  global poke
  lassign [split $type "/"] type1 type2
  set eff [dex eval "
    SELECT effectiveness FROM matcDetails$poke(gen)
    WHERE (type1 = '$type1' AND type2 = '$mType') OR
          (type1 = '$type2' AND type2 = '$mType')
  "]
  if {[llength $eff] == 1} {
    return $eff
  } else {
    return [expr {[lindex $eff 0]*[lindex $eff 1]}]
  }
}

proc poke:random {} {
  set done 0
  while {!$done} {
    set rseed [rand 65535]
    if {$rseed} {set done 1}
  }
  set newrand [expr {srand($rseed)}]
}


proc poke:boost {status stat} {
  set idx [lsearch -index 0 $status $stat]
  if {[regexp "$stat (\[+-\]\\d)" [lindex $status $idx] - value]} {
    switch $value {
      +6 {set boost 4.0}
      +5 {set boost 3.5}
      +4 {set boost 3.0}
      +3 {set boost 2.5}
      +2 {set boost 2.0}
      +1 {set boost 1.5}
      -1 {set boost [expr {2/3}]}
      -2 {set boost [expr {1/2}]}
      -3 {set boost [expr {2/5}]}
      -4 {set boost [expr {1/3}]}
      -5 {set boost [expr {2/7}]}
      -6 {set boost [expr {1/4}]}
      default {set boost 1}
    }
  } else {
    set boost 1
  }
  return $boost 
}

### poke:update_pokemon - triggered by moves, abilities, counters
# name: array to be updated. Either cHP, PP or status
# if cHP, then value should be either +# or -#
# else it will be the status; e.g. ATK +1, PSN, SLP
proc poke:update_pokemon {trainer pokedet name {value ""}} {
  global poke
  array set pokemon $pokedet
  set tID [lsearch -index 0 $poke(team) $trainer]
  set cteam [lindex $poke(team) $tID 1]
  set pID [lsearch -regexp $cteam "\\yspecies $pokemon(species)\\y"]
  
  switch -regexp -matchvar param $value {
    {\+(.+)} {
      set param [lindex $param 1]
      if {$pokemon(cHP) == $pokemon(HP)} {return 0}
      incr pokemon(cHP) $param
      if {$pokemon(cHP) > $pokemon(HP)} {
        set pokemon(cHP) $pokemon(HP)
      }
    }
    {-(.+)} {
      set param [lindex $param 1]
      if {[llength $param] == 1} {
        incr pokemon(cHP) -$param
        if {$pokemon(cHP) < 0} {
          set pokemon(cHP) 0
        }
        if {$pokemon(ability) eq "Color Change"} {poke:trigger colorchange $trainer $pokedet - -}
      } else {
        lassign [split $param] param move
        foreach {moveno movedet} [array get pokemon "Move*"] {
          if {[lindex $movedet 0] eq $move} {
            set pokemon(moveno) "$move [expr {[lindex $movedet 1]-$param}]"
            break
          }
        }
      }
    }
    {add (.*)} {
      set param [lindex $param 1]
      set idx [lsearch -index 0 $pokemon(status) $param]
      # Status not set (yet)
      if {$idx == -1} {
        lappend pokemon(status) $param
      } else {
        # Stats update if anything other than status ailment
        if {[string len $value] > 3} {
          set cstat [lindex $poke(status) $idx]
          regexp {(...) ([+-]\d)} $cstat - stat val
          if {$val eq "+5"} {return 0}
          incr val [lindex $param 1]
          lset pokemon(status) $idx "$stat $val"
        } else {
          return 0
        }
      }
    }
    {rem (.+)} {
      set param [lindex $param 1]
      set idx [lsearch -index 0 $pokemon(status) [lindex $param 0]]
      # Status not set (yet)
      if {$idx == -1} {
        lappend pokemon(status) $param
      } else {
        # Stats update if anything other than status ailment
        if {[string len $value] > 3} {
          set cstat [lindex $poke(status) $idx]
          regexp {(...) ([+-]\d)} $cstat - stat val
          if {$val eq "-5"} {return 0}
          incr val [lindex $param 1]
          if {$val == 0} {
            set pokemon(status) [lreplace $pokemon(status) $idx $idx]
          } else {
            lset pokemon(status) $idx "$stat $val"
          }
        } else {
          return 0
        }
      }    
    }
    default {
      set pokemon($name) $value
    }
  }
  lset poke(team) $tID 1 $pID [array get pokemon]
  return [list 1 [array get pokemon]]
}

proc poke:trigger {type trainer pokedet otrainer opokedet} {
  global poke
  set idx [lsearch $poke(triggers) $type]
  if {$idx == -1} {return 0}
  ### Triggers
  # contact
  # block (prevents switching)
  # protect/detect
  # substitute
  # snatch
  return 0
  
}

proc poke:faint {nick} {
  global poke
  set tID [lsearch $poke(currentPoke) $nick]
  
  set trainer [lsearch -index 0 $poke(team) $nick]
  set cteam [lindex $poke(team) $trainer 1]
  
  set cPoke [lindex $poke(currentPoke) $tID+1]
  lappend poke(fainted) [list $nick $cPoke]
  
  set available 0
  set available_list [list]
  
  foreach pokedet $cteam {
    array set pokemon $pokedet
    if {$pokemon(cHP) > 0} {incr available}
    lappend available_list "$pokemon(species) \[$pokemon(cHP)/$pokemon(HP)\]"
  }
  if {$available == 0} {
    set op [lindex $poke(currentPoke) [expr {2-$tID}]]
    putquick "PRIVMSG $nick :You are out of usable Pokemon. $op has won the match!"
    putquick "PRIVMSG $op :$nick is out of usable Pokemon. You has won the match!"
    putquick "PRIVMSG $poke(chan) :$nick is out of usable Pokemon. $op has won the match!"
    poke:stop - - - $poke(chan) -
    return
  }
  bind msgm - "*" poke:faint_switch
  putquick "PRIVMSG $nick :Please pick a Pokemon (use \"switch pokemonname\" or \"switch pokemonnumber\"): [join $available_list {, }]"
}

proc poke:faint_switch {nick host hand arg} {
  global poke
  if {[lsearch -index 0 $poke(fainted) $nick]} {return}
  if {$nick in $poke(forfeit)} {
    switch -nocase -regexp -- $arg {
      y(es?)? {
        if {$nick ni $poke(forfeit)} {return}
        set id [lsearch $nick $poke(trainerList)]
        set oID [lindex $poke(trainerList) [expr {abs($id-3)}]]
        putquick "PRIVMSG $nick :You have forfeited the battle."
        putquick "PRIVMSG $poke(chan) :$nick has forfeited the battle."
        putquick "PRIVMSG [lindex $poke(trainerList) $oID] :$nick has forfeited the battle."
        poke:stop - - - $poke(chan) -
      }
      no? {
        if {$nick ni $poke(forfeit)} {return}
        set id [lsearch $poke(forfeit) $nick]
        set poke(forfeit) [lreplace $poke(forfeit) $id $id]
        putquick "PRIVMSG $nick :Please pick a Pokemon."
      }
    }
    return
  } else {
    set id [lsearch $poke(currentPoke) $nick]
    set challenger [lsearch -index 0 $poke(team) $nick]
    set currentPoke [lindex $poke(currentPoke) $id+1]
    switch -nocase -regexp -matchvar param -- $arg {
      {^switch *(.*)$} {
        set param [string trim [lindex $param 1]]
        set crules [lindex [split $poke(crules) "v"] $challenger]
        set cteam [lindex $poke(team) $challenger 1]
        set cID [lsearch -regexp $cteam "\\yspecies $currentPoke\\y"]
        if {[string is integer $param] && $param >= 1 && $param <= [llength $cteam]} {
          incr param -1
          if {$cID == $param} {
            putquick "PRIVMSG $nick :Pick a Pokémon other than your current Pokémon."
            return
          }
          set nID $param
        } elseif {![string is integer $param]} {
          # Add pokemon name choice
          set nID [lsearch -nocase -regexp $cteam "\\yspecies $param\\y"]
          if {$nID == -1} {
            putquick "PRIVMSG $nick :You don't have this Pokemon on your team."
            return
          }
        } else {
          putquick "PRIVMSG $nick :Invalid number"
          return
        }
        set tPokemon [lindex $cteam $nID]
        array set pokemon $tPokemon
        if {$pokemon(cHP) == 0} {
          putquick "PRIVMSG $nick :That Pokémon cannot battle anymore! Please pick another."
          return
        }
        poke:switch $nick $cID $nID
        bind msgm - "*" poke:faint_switch
      }
      {^checkteam$} {
        set cteam [lindex $poke(team) $challenger 1]
        foreach n $cteam {
          array set pokemon $n
          set status [format "%-11s %-5s %+3s/%+3s" $pokemon(species) $pokemon(status) $pokemon(cHP) $pokemon(HP)]
          putquick "PRIVMSG $nick :$status"
        }
        array unset pokemon
      }
      {^check$} {
        set cteam [lindex $poke(team) $challenger 1]
        set cID [lsearch -regexp $cteam "\\yspecies $currentPoke\\y"]
        set cPokemon [lindex $cteam $cID]
        array set pokemon $cPokemon
        set condition [array names pokemon Battle*]
        set condList [lmap x $condition {set $pokemon($x)}]
        array set field $poke(field)
        array set fieldstat $field($nick)
        set status [format "%s %s %s/%s Conditions: %s" $pokemon(species) $pokemon(status) $pokemon(cHP) $pokemon(HP) [join $condList ", "]]
        putquick "PRIVMSG $nick :Pokémon: $status"
        putquick "PRIVMSG $nick :Field: [join [array names fieldstat] {, }]"
        array unset pokemon
        array unset field
        array unset fieldstat
        
        set opponent [lindex $poke(team) 1-$challenger 0]
        set oteam [lindex $poke(team) 1-$challenger 1]
        set oID [lsearch -regexp $cteam "\\yspecies [lindex $poke(currentPoke) 3-$id]\\y"]
        set oPokemon [lindex $oteam $oID]
        array set pokemon $oPokemon
        set condition [array names pokemon Battle*]
        set condList [lmap x $condition {set $pokemon($x)}]
        array set field $poke(field)
        array set fieldstat $field($opponent)
        set status [format "%s %s %s/%s Conditions: %s" $pokemon(species) $pokemon(status) \
          $pokemon(cHP) $pokemon(HP) [join $condList ", "]]
        putquick "PRIVMSG $nick :Opponent: $status"
        putquick "PRIVMSG $nick :Field: [join [array names fieldstat] {, }]"
        array unset pokemon
        array unset field
        array unset fieldstat
      }
      {^forfeit$} {
        putquick "PRIVMSG $nick :Are you sure you want to forfeit? (Y/N)"
        lappend poke(forfeit) $nick
        return
      }
      default {
        set param $arg
        set crules [lindex [split $poke(crules) "v"] $challenger]
        set cteam [lindex $poke(team) $challenger 1]
        set cID [lsearch -regexp $cteam "\\yspecies $currentPoke\\y"]
        if {[string is integer $param] && $crules <= $poke(crules) && $crules > 1} {
          if {$cID == $param} {
            putquick "PRIVMSG $nick :Pick a Pokémon other than your current Pokémon."
            return
          }
          set nID $param
        } elseif {![string is integer $param]} {
          # Add pokemon name choice
          set nID [lsearch -nocase -regexp $cteam "\\yspecies $param\\y"]
          if {$nID == -1} {
            putquick "PRIVMSG $nick :You don't have this Pokemon on your team."
            return
          }
        } else {
          putquick "PRIVMSG $nick :Invalid number"
          return
        }
        set tPokemon [lindex $cteam $nID]
        array set pokemon $tPokemon
        if {$pokemon(cHP) == 0} {
          putquick "PRIVMSG $nick :That Pokémon cannot battle anymore! Please pick another."
          return
        }
        poke:switch $nick $cID $nID
      }
    }
  }
}

proc poke:switch {nick cID nID} {
  global poke
  
  set id [lsearch $poke(currentPoke) $nick]
  set cpoke [lindex $poke(currentPoke) $id+1]
  
  set trainer [lsearch -index 0 $poke(team) $nick]
  set cteam [lindex $poke(team) $trainer 1]
  set npokedet [lindex $cteam $nID]
  array set npoke $npokedet
  set newpoke $npoke(species)
  if {$npoke(cHP) <= 0} {
    putquick "PRIVMSG $nick :That Pokémon cannot battle anymore! Please pick another."
    return
  }
  
  lset poke(currentPoke) $id+1 $newpoke
  putquick "PRIVMSG $poke(chan) :$nick switched out $cpoke for $newpoke!"
  #poke:switch_trigger Trigger stuff like spikes
  poke:battleresolve
}

proc poke:message {type move trainer pokedet otrainer opokedet dmg crit} {
  global poke
  array set pokemon $pokedet
  array set opokemon $opokedet
  switch $type {
    "normal" {
      if {$crit} {
        set critmsg " Critical Hit!"
      } else {
        set critmsg ""
      }
      if {$opokemon(cHP) < $dmg} {
        putquick "PRIVMSG $poke(chan) :$trainer's $pokemon(species) used $move on $otrainer's $opokemon(species)!$critmsg $otrainer's $opokemon(species) fainted!"
        putquick "PRIVMSG $trainer :$pokemon(species) used $move!$critmsg Foe $otrainer's $opokemon(species) fainted!"
        putquick "PRIVMSG $otrainer :Foe $pokemon(species) used $move!$critmsg $opokemon(species) fainted!"
        poke:faint $otrainer
        return 1
      } else {
        putquick "PRIVMSG $poke(chan) :$trainer's $pokemon(species) used $move on $otrainer's $opokemon(species)!$critmsg $otrainer's $opokemon(species) suffered $dmg damage!"
        putquick "PRIVMSG $trainer :$pokemon(species) used $move!$critmsg Foe $opokemon(species) suffered $dmg damage!"
        putquick "PRIVMSG $otrainer :Foe $pokemon(species) used $move!$critmsg $opokemon(species) suffered $dmg damage!"
        return 0
      }
    }
    "miss" {
      putquick "PRIVMSG $poke(chan) :$trainer's $pokemon(species) used $move on $otrainer's $opokemon(species)! The attack missed!"
      putquick "PRIVMSG $trainer :$pokemon(species) used $move! The attack missed!"
      putquick "PRIVMSG $otrainer :Foe $pokemon(species) used $move! The attack missed!"
      return 0
    }
    "no effect" {
      putquick "PRIVMSG $poke(chan) :$trainer's $pokemon(species) used $move on $otrainer's $opokemon(species)! It doesn't affect $otrainer's $opokemon(species)!"
      putquick "PRIVMSG $trainer :$pokemon(species) used $move! It doesn't affect foe $otrainer's $opokemon(species)!"
      putquick "PRIVMSG $otrainer :Foe $pokemon(species) used $move! It doesn't affect $opokemon(species)!"
    }
    "super effective" {
      if {$opokemon(cHP) < $dmg} {
        putquick "PRIVMSG $poke(chan) :$trainer's $pokemon(species) used $move on $otrainer's $opokemon(species)! Super effective!$critmsg $otrainer's $opokemon(species) fainted!"
        putquick "PRIVMSG $trainer :$pokemon(species) used $move! Super effective!$critmsg Foe $otrainer's $opokemon(species) fainted!"
        putquick "PRIVMSG $otrainer :Foe $pokemon(species) used $move! Super effective!$critmsg $opokemon(species) fainted!"
        poke:faint $otrainer
        return 1
      } else {
        putquick "PRIVMSG $poke(chan) :$trainer's $pokemon(species) used $move on $otrainer's $opokemon(species)! Super effective!$critmsg $otrainer's $opokemon(species) suffered $dmg damage!"
        putquick "PRIVMSG $trainer :$pokemon(species) used $move! Super effective!$critmsg Foe $opokemon(species) suffered $dmg damage!"
        putquick "PRIVMSG $otrainer :Foe $pokemon(species) used $move! Super effective!$critmsg $opokemon(species) suffered $dmg damage!"
        return 0
      }
    }
    "not effective" {
      if {$opokemon(cHP) < $dmg} {
        putquick "PRIVMSG $poke(chan) :$trainer's $pokemon(species) used $move on $otrainer's $opokemon(species)! It's not very effective!$critmsg $otrainer's $opokemon(species) fainted!"
        putquick "PRIVMSG $trainer :$pokemon(species) used $move! It's not very effective!$critmsg Foe $otrainer's $opokemon(species) fainted!"
        putquick "PRIVMSG $otrainer :Foe $pokemon(species) used $move! It's not very effective!$critmsg $opokemon(species) fainted!"
        poke:faint $otrainer
        return 1
      } else {
        putquick "PRIVMSG $poke(chan) :$trainer's $pokemon(species) used $move on $otrainer's $opokemon(species)! It's not very effective.$critmsg $otrainer's $opokemon(species) suffered $dmg damage!"
        putquick "PRIVMSG $trainer :$pokemon(species) used $move! It's not very effective!$critmsg Foe $opokemon(species) suffered $dmg damage!"
        putquick "PRIVMSG $otrainer :Foe $pokemon(species) used $move! It's not very effective!$critmsg $opokemon(species) suffered $dmg damage!"
        return 0
      }
    }
    brn {
      putquick "PRIVMSG $poke(chan) :$otrainer's $opokemon(species) was burned!"
      putquick "PRIVMSG $trainer :Foe $opokemon(species) was burned!"
      putquick "PRIVMSG $otrainer :$opokemon(species) was burned!"
      return 0
    }
    brnmsg {
      if {$pokemon(cHP) < $dmg} {
        putquick "PRIVMSG $poke(chan) :$trainer's $pokemon(species) suffers $dmg damage from its burn! $pokemon(species) fainted!"
        putquick "PRIVMSG $trainer :$pokemon(species) suffers $dmg damage from its burn! $pokemon(species) fainted!"
        putquick "PRIVMSG $otrainer :Foe $pokemon(species) suffers $dmg damage from its burn! $pokemon(species) fainted!"
        poke:faint $trainer
        return 1
      } else {
        putquick "PRIVMSG $poke(chan) :$trainer's $pokemon(species) suffers $dmg damage from its burn!"
        putquick "PRIVMSG $trainer :$pokemon(species) suffers $dmg damage from its burn!"
        putquick "PRIVMSG $otrainer :Foe $pokemon(species) suffers $dmg damage from its burn!"
        return 0
      }
    }
  }
}

proc poke:status:burn {trainer pokedet otrainer opokedet} {
  global poke
  array set pokemon $pokedet
  set dmg [expr {$pokemon(HP)/8}]
  if {$pokemon(ability) eq "Heatproof"} {set dmg [expr {$dmg/2}]}
  poke:update_pokemon $trainer $pokedet "cHP" -$dmg
  poke:message brndmg - $trainer $pokedet $otrainer $opokedet $dmg -
}

putlog "Pokémon Battle $poke(ver) loaded."
