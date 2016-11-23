# Template for default moves
proc poke:movetemplate:default {move trainer pokedet otrainer opokedet {extra ""}} {
  global poke
  set table moveDetails$poke(gen)
  regsub {'} $move "''" move
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff contact]
  if {$extra != ""} {
    for {set i 0} {[expr {$i+1}] < [llength $extra]} {} {
      if {[info exists [lindex $extra $i]]} {
        set [lindex $extra $i] [subst [lindex $extra $i+1]]
        set extra [lreplace $extra $i $i+1]
      } else {
        incr i 2
      }
    }
  }
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  if {$bp eq "*"} {set bp 1}
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] dmgtype dmg crit
  if {$extra != ""} {
    foreach {setting value} $extra {
      if {[info exists $setting]} {
        set $setting [subst $value]
        if {$setting eq "dmg" && $dmgtype ni {miss "no effect"}} {lassign {normal 0} dmgtype crit}
      }
    }
  }
  if {$dmgtype in {"miss" "no effect"}} {
    poke:message $dmgtype $move $trainer $pokedet $otrainer $opokedet - 0
    return [list 0 $dmg]
  }
  if {$dmg < 1} {set dmg 1}
  puts dmg:$dmgtype
  lassign [poke:update_pokemon $otrainer $opokedet "cHP" -$dmg] - opokedet
  set ppdown 1
  array set opokemon $opokedet
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  set faint [poke:message $dmgtype $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  if {$contact == 1} {poke:trigger contact $otrainer $opokedet $trainer $pokedet}
  return [list $faint $dmg]
}

# Template for multihit moves
proc poke:movetemplate:multi {move trainer pokedet otrainer opokedet {counter ""}} {
  global poke
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff contact]
  array set opokemon $opokedet
  array set pokemon $pokedet
  set faint 0
  set fnt ""
  
  if {$counter == ""} {
    poke:random
    set test [rand 1000]
    if {$test < 125} {
      set counter 5
    } elseif {$test < 250} {
      set counter 4
    } elseif {$test < 625} {
      set counter 3
    } else {
      set counter 2
    }
  }
  poke:message use $move $trainer $pokedet $otrainer $opokedet - 0
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  for {set i 1} {$i <= $counter} {incr i} {
    poke:trigger "mid launch" $otrainer $opokedet $trainer $pokedet
    lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] dmgtype dmg crit
    switch $dmgtype {
      miss {
        poke:message multmiss $move $trainer $pokedet $otrainer $opokedet $dmg $crit
      }
      "no effect" {
        poke:message multnoeff $move $trainer $pokedet $otrainer $opokedet $dmg $crit
        return 0
      }
      default {
        switch $dmgtype {
          "super effective" {set eff "It's super effective! "}
          "not effective" {set eff "It's not very effective. "}
          default {set eff ""}
        }
        if {$dmg > $opokemon(cHP)} {set fnt " $otrainer's $opokemon(species) fainted!"}
        set faint [poke:message multhit $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
        lassign [poke:update_pokemon $otrainer $opokedet "cHP" -$dmg] result det
        poke:trigger "mid damage" $otrainer $opokedet $trainer $pokedet
        if {$det != ""} {
          set opokedet $det
          array set opokemon $opokedet
        }
        if {$faint} {break}
        if {$contact == 1 && [poke:trigger contact $otrainer $opokedet $trainer $pokedet]} {
          break
        }
      }
    }
  }
  incr i -1
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  poke:message multlast $move $trainer $pokedet $otrainer $opokedet - 0
  return $faint
}

# Template for moves that need charging
proc poke:movetemplate:charge {move trainer pokedet otrainer opokedet {msg "is charging"}} {
  global poke
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  array set pokemon $pokedet
  set trainerID [lsearch -index 0 $poke(team) $trainer]
  set pokeID [lsearch -regexp [lindex $poke(team) $trainerID 1] "\\yspecies \\{?$pokemon(species)\\y\\}?"]
  set opponentID [lsearch $poke(currentPoke) $otrainer]
  lappend poke(pending) [list 0 $pokemon(Spd) "poke:move:[string tolower [join $move {}]]" $trainer $pokemon(species) $trainerID $pokeID $opponentID 0]
  poke:message custom - $otrainer $opokedet $trainer $pokedet - 0 $msg
  incr poke(battleready)
  lappend poke(ready) $trainer
  return 0
}

# Template for moves that need recharge
proc poke:movetemplate:recharge {trainer pokedet otrainer opokedet {msg "must recharge"}} {
  global poke
  array set pokemon $pokedet
  lappend poke(pending) [list 0 $pokemon(Spd) poke:message custom $trainer $pokedet $otrainer $opokedet - 0 $msg]
  incr poke(battleready)
  lappend poke(ready) $trainer
  return 0
}

# Template for OHKO moves
proc poke:movetemplate:ohko {move trainer pokedet otrainer opokedet} {
  global poke
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff contact]
  array set opokemon $opokedet
  set weak [poke:get_weakness $type $opokemon(type)]
  switch -regexp $weak {
    {^0$} {set dmgtype "no effect"}
    {^(?:2|4)$} {set dmgtype "super effective"}
    default {set dmgtype "normal"}
  }
  set dmg $opokemon(cHP)
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:random
  set test [rand 100]
  if {($weak > 0 && $test < $acc) || $acc eq "-"} {
    set result "ohko"
    poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
    poke:trigger damage $otrainer $opokedet $trainer $pokedet
    set faint [poke:message $result $move $trainer $pokedet $otrainer $opokedet $dmg 0]
    return $faint   
  } elseif {$weak > 0 && $test > $acc} {
    poke:message miss $move $trainer $pokedet $otrainer $opokedet - 0
  } else {
    poke:message "no effect" $move $trainer $pokedet $otrainer $opokedet - 0
  }
  return 0
}

# Template for stat changes
proc poke:movetemplate:stats {move trainer pokedet otrainer opokedet stat target} {
  global poke
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  array set opokemon $opokedet
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff contact]
  if {$acc eq "-"} {set acc 100}
  poke:message use $move $trainer $pokedet $otrainer $opokedet - 0
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  return [poke:statustrigger $trainer $pokedet $otrainer $opokedet $stat $acc $target 1]
}

# Template for recoil
proc poke:movetemplate:recoil {trainer pokedet otrainer opokedet dmg msg} {
  global poke
  array set pokemon $pokedet
  if {$dmg > $pokemon(cHP)} {set dmg $pokemon(cHP)}
  poke:update_pokemon $trainer $pokedet "cHP" -$dmg
  set faint [poke:message custom - $otrainer $opokedet $trainer $pokedet $dmg 0 $msg]
  if {$faint} {
    lappend poke(prio-10) [list 0 poke:faint $trainer]
    lappend poke(switch) [list $trainer $pokemon(species)]
  }
  return
}

# Template for forced switches
proc poke:movetemplate:forceswitch {move trainer pokedet otrainer opokedet {dmg 0} {rand 1}} {
  global poke
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff contact]
  poke:random
  set test [rand 100]
  if {$test < $acc || $acc eq "-"} {
    if {$rand} {
      array set opokemon $opokedet
      set cPoke $opokemon(species)
      set id [lsearch $poke(currentPoke) $otrainer]
      set trainerID [lsearch -index 0 $poke(team) $otrainer]
      set cteam [lindex $poke(team) $trainerID 1]
      set available_list [list]
      for {set i 0} {$i < [llength $cteam]} {incr i} {
        array set pokemon [lindex $cteam $i]
        if {$pokemon(species) eq $cPoke} {
          set cID $i
          continue
        }
        if {$pokemon(cHP) > 0} {
          lappend available_ids $i
          lappend available_list $pokemon(species)
        }
      }
      poke:random
      if {[llength $available_ids] == 0} {
        if {$dmg == 0} {
          poke:message fail $move $trainer $pokedet $otrainer $opokedet - 0
        }
      } else {
        if {$dmg == 0} {
          poke:message use $move $trainer $pokedet $otrainer $opokedet - 0
        }
        set nID [lindex $available_ids [rand [llength $available_ids]]]
        poke:switch $otrainer $cID $nID -
        poke:message custom - $trainer $pokedet $otrainer "species $pokemon(species)" - 0 "was dragged out"
      }
    } else {
      array set pokemon $pokedet
      set cPoke $pokemon(species)
      set id [lsearch $poke(currentPoke) $trainer]
      set trainerID [lsearch -index 0 $poke(team) $trainer]
      set cteam [lindex $poke(team) $trainerID 1]
      set available_list [list]
      for {set i 0} {$i < [llength $cteam]} {incr i} {
        array set pokemon [lindex $cteam $i]
        if {$pokemon(species) eq $cPoke} {
          set cID $i
          continue
        }
        if {$pokemon(cHP) > 0} {
          lappend available_ids $i
          lappend available_list $pokemon(species)
        }
      }
      putquick "PRIVMSG $trainer :Please pick a Pokemon (use \"switch pokemonname\" or \"switch pokemonnumber\"): [join $available_list {, }]"
      bind msgm - "*" poke:force_switch
    }
  } else {
    poke:message fail $move $trainer $pokedet $otrainer $opokedet - 0
  }
  return 0
}

# Template for healing moves
proc poke:movetemplate:heal {move trainer pokedet otrainer opokedet exp force {self 1}} {
  global poke
  if {$self} {
    set utrainer $otrainer
    set upokedet $opokedet
    set ttrainer $trainer
    set tpokedet $pokedet
  } else {
    set utrainer $trainer
    set upokedet $pokedet
    set ttrainer $otrainer
    set tpokedet $opokedet
  }
  array set pokemon $tpokedet
  if {$force} {
    set ppdown 1
    if {!$self && $pokemon(ability) eq "Pressure"} {incr ppdown}
    poke:update_pokemon $trainer $pokedet "Move" "-1 $move"
  }
  
  set cHP $pokemon(cHP)
  set heal [expr int([subst $exp])]
  lassign [poke:update_pokemon $ttrainer $tpokedet "cHP" "+$heal"] result tpokedet
  array set pokemon $tpokedet
  set heal [expr {$pokemon(cHP)-$cHP}]
  if {$heal > 0} {
    poke:message heal - $ttrainer $tpokedet $utrainer $upokedet $heal 0
  } elseif {$force && $heal == 0} {
    poke:message fail $move $utrainer $upokedet $ttrainer $tpokedet $heal 0
  }
  return 0
}

# Template for trap moves
proc poke:movetemplate:trap {move trainer pokedet otrainer opokedet {trap 0} {trigger 0}} {
  global poke
  if {$trigger} {
    poke:random
    set test [rand 8]
    if {$test < 3} {
      set turns 2
    } elseif {$test < 6} {
      set turns 3
    } elseif {$test < 7} {
      set turns 4
    } else {
      set turns 5
    }
    poke:update_pokemon $otrainer $opokedet stats "add trapped $turns"
    array set opokemon $opokedet
    poke:message custom - $trainer $pokedet $otrainer $opokedet - 0 "has been trapped"
    lappend poke(prio-9) [list $opokemon(Spd) poke:movetemplate:trap $move $trainer $pokedet $otrainer $opokedet 1]
    return
  }
  if {!$trap} {
    array set opokemon $opokedet
    if {[lsearch -index 0 $opokemon(status) "trapped"] > -1} {
      lassign [poke:movetemplate:default $move $trainer $pokedet $otrainer $opokedet] faint
    } else {
      set effect [list damage poke:movetemplate:trap $move $trainer $pokedet $otrainer $opokedet 0 1]
      lappend poke(triggers) $effect
      lassign [poke:movetemplate:default $move $trainer $pokedet $otrainer $opokedet] faint dmg
      set poke(triggers) [lreplace $poke(triggers) end end]
      return $faint
    }
  } else {
    set faint 0
    lassign [poke:update_pokemon $otrainer $opokedet stats "add trapped -1"] result $opokedet
    array set opokemon $opokedet
    array set pokemon $pokedet
    set dmg [expr {int($opokemon(HP)*0.0625)}]
    poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
    poke:message custom - $trainer $pokedet $otrainer $opokedet - 0 "suffered $dmg damage from $move"
    if {[lsearch -index 0 $opokemon(status) "trapped"] > -1 && $pokemon(species) in $poke(currentPoke)} {
      lappend poke(prio-9) [list $opokemon(Spd) poke:movetemplate:trap $move $trainer $pokedet $otrainer $opokedet 1]
    }
    if {$opokemon(cHP) < $dmg} {set faint 1}
    return $faint
  }
}

# Template for multiturn moves
proc poke:movetemplate:multiturn {move trainer pokedet otrainer opokedet count} {
  global poke
  lassign [poke:movetemplate:default $move $trainer $pokedet $otrainer $opokedet] faint dmg
  incr count -1
  if {$count == 0} {    
    poke:message customself - $trainer $pokedet $otrainer $opokedet - 0 "became confused"
    poke:update_pokemon $trainer $pokedet status "add conf"
  } else {
    array set pokemon $pokedet
    set trainerID [lsearch -index 0 $poke(team) $trainer]
    set pokeID [lsearch -regexp [lindex $poke(team) $trainerID 1] "\\yspecies \\{?$pokemon(species)\\y\\}?"]
    set opponentID [lsearch $poke(currentPoke) $otrainer]
    lappend poke(pending) [list 0 $pokemon(Spd) poke:movetemplate:multiturn $move $trainer $pokedet $otrainer $opokedet $count]
    lappend poke(ready) $trainer
    incr poke(battleready)
  }
  return $faint
}

# Template for multiturn moves
proc poke:movetemplate:multiturnincr {move trainer pokedet otrainer opokedet count {bp 1}} {
  global poke
  set exp "\[expr {\$bp*$bp*(2**(5-$count))}\]"
  lassign [poke:movetemplate:default $move $trainer $pokedet $otrainer $opokedet [list bp $exp]] faint dmg
  incr count -1
  if {$faint == 2 || $count == 0} {    
    return 0
  } else {
    array set pokemon $pokedet
    set trainerID [lsearch -index 0 $poke(team) $trainer]
    set pokeID [lsearch -regexp [lindex $poke(team) $trainerID 1] "\\yspecies \\{?$pokemon(species)\\y\\}?"]
    set opponentID [lsearch $poke(currentPoke) $otrainer]
    lappend poke(pending) [list 0 $pokemon(Spd) poke:movetemplate:multiturnincr $move $trainer $pokedet $otrainer $opokedet $count $bp]
    lappend poke(ready) $trainer
    incr poke(battleready)
  }
  return $faint
}

# 1 Pound
proc poke:move:pound {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Pound" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 2 Karate Chop
proc poke:move:karatechop {trainer pokedet otrainer opokedet} {
  lassign [poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"] - pokedet
  lassign [poke:movetemplate:default "Karate Chop" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
  return $faint
}

# 3 Double Slap
proc poke:move:doubleslap {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:multi "Double Slap" $trainer $pokedet $otrainer $opokedet]
}

# 4 Comet Punch
proc poke:move:cometpunch {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:multi "Comet Punch" $trainer $pokedet $otrainer $opokedet]
}

# 5 Mega Punch
proc poke:move:megapunch {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Mega Punch" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 6 Pay Day
proc poke:move:payday {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Pay Day" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 7 Fire Punch
proc poke:move:firepunch {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list BRN] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Fire Punch" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 8 Ice Punch
proc poke:move:icepunch {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list FRZ] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Ice Punch" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 9 Thunder Punch
proc poke:move:thunderpunch {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list PAR] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Thunder Punch" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 10 Scratch
proc poke:move:scratch {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Scratch" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 11 Vice Grip
proc poke:move:vicegrip {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Vice Grip" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 12 Guillotine
proc poke:move:guillotine {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:ohko "Guillotine" $trainer $pokedet $otrainer $opokedet]
}

# 13 Razor Wind
proc poke:move:razorwind {trainer pokedet otrainer opokedet {charged 1}} {
  global poke
  set move "Razor Wind"
  if {$charged} {
    poke:movetemplate:charge $move $trainer $pokedet $otrainer $opokedet "whipped up a whirlwind"
    return 0
  } else {
    lassign [poke:movetemplate:default $move $trainer $pokedet $otrainer $opokedet] faint dmg
    return $faint
  }
}

# 14 Swords Dance
proc poke:move:swordsdance {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Swords Dance" $trainer $pokedet $otrainer $opokedet [list "Atk +2"] self
  return 0
}

# 15 Cut
proc poke:move:cut {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Cut" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 16 Gust
proc poke:move:gust {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Gust" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 17 Wing Attack
proc poke:move:wingattack {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Wing Attack" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 18 Whirlwind
proc poke:move:whirlwind {trainer pokedet otrainer opokedet} {
  poke:movetemplate:forceswitch "Whirlwind" $trainer $pokedet $otrainer $opokedet
  return 0
}

# 19 Fly
proc poke:move:fly {trainer pokedet otrainer opokedet {charged 1}} {
  global poke
  set move "Fly"
  if {$charged} {
    poke:update_pokemon $trainer $pokedet add "skybound"
    poke:movetemplate:charge $move $trainer $pokedet $otrainer $opokedet "flew up!"
    return 0
  } else {
    lassign [poke:movetemplate:default $move $trainer $pokedet $otrainer $opokedet] faint dmg
    return $faint
  }
}

# 20 Bind
proc poke:move:bind {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:trap "Bind" $trainer $pokedet $otrainer $opokedet]
}

# 21 Slam
proc poke:move:slam {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Slam" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 22 Vine Whip
proc poke:move:vinewhip {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Vine Whip" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 23 Stomp
proc poke:move:stomp {trainer pokedet otrainer opokedet} {
  global poke
  lassign [poke:movetemplate:default "Stomp" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:random
  set test [rand 100]
  if {$test < 30} {
    poke:flinch $otrainer $opokedet 0
  }
  return $faint
}

# 24 Double Kick
proc poke:move:doublekick {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:multi "Double Kick" $trainer $pokedet $otrainer $opokedet 2]
}

# 25 Mega Kick
proc poke:move:megakick {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Mega Kick" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 26 Jump Kick
proc poke:move:jumpkick {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Jump Kick" $trainer $pokedet $otrainer $opokedet] faint dmg
  if {$faint == 2} {
    set dmg [expr {int($dmg*0.5)}]
    poke:movetemplate:recoil $trainer $pokedet $otrainer $opokedet $dmg "went crashing and suffered $dmg damage"
  }
  return $faint
}

# 27 Rolling Kick
proc poke:move:stomp {trainer pokedet otrainer opokedet} {
  global poke
  lassign [poke:movetemplate:default "Rolling Kick" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:random
  set test [rand 100]
  if {$test < 30} {
    poke:flinch $otrainer $opokedet 0
  }
  return $faint
}

# 28 Sand Attack
proc poke:move:sandattack {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Sand Attack" $trainer $pokedet $otrainer $opokedet [list "Acc -1"] op
  return 0
}

# 29 Headbutt
proc poke:move:headbutt {trainer pokedet otrainer opokedet} {
  global poke
  lassign [poke:movetemplate:default "Headbutt" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:random
  set test [rand 100]
  if {$test < 30} {
    poke:flinch $otrainer $opokedet 0
  }
  return $faint
}

# 30 Horn Attack
proc poke:move:hornattack {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Horn Attack" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 31 Fury Attack
proc poke:move:furyattack {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:multi "Fury Attack" $trainer $pokedet $otrainer $opokedet]
}

# 32 Horn Drill
proc poke:move:horndrill {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:ohko "Horn Drill" $trainer $pokedet $otrainer $opokedet]
}

# 33 Tackle
proc poke:move:tackle {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Tackle" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 34 Body Slam
proc poke:move:bodyslam {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list PAR] 30 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Body Slam" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 35 Wrap
proc poke:move:wrap {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:trap "Wrap" $trainer $pokedet $otrainer $opokedet]
}

# 36 Take Down
proc poke:move:takedown {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Take Down" $trainer $pokedet $otrainer $opokedet] faint dmg
  if {$faint != 2} {
    set dmg [expr {int($dmg*0.25)}]
    poke:movetemplate:recoil $trainer $pokedet $otrainer $opokedet $dmg "suffers $dmg of recoil"
  }
  return $faint
}

# 37 Thrash
proc poke:move:thrash {trainer pokedet otrainer opokedet} {
  poke:random
  set count [expr {[rand 2]+2}]
  return [poke:movetemplate:multiturn "Thrash" $trainer $pokedet $otrainer $opokedet $count]
}

# 38 Double-Edge
proc poke:move:double-edge {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Double-Edge" $trainer $pokedet $otrainer $opokedet] faint dmg
  if {$faint != 2} {
    set dmg [expr {int($dmg/3.0)}]
    poke:movetemplate:recoil $trainer $pokedet $otrainer $opokedet $dmg "suffers $dmg of recoil"
  }
  return $faint
}

# 40 Poison Sting
proc poke:move:poisonsting {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list PSN] 30 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Poison Sting" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 41 Twineedle
proc poke:move:twineedle {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list "mid damage" poke:statustrigger $trainer $pokedet $otrainer $opokedet [list PSN] 30 op 0]
  lappend poke(triggers) $effect
  set faint [poke:movetemplate:multi "Twineedle" $trainer $pokedet $otrainer $opokedet 2]
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint 
}

# 42 Pin Missle
proc poke:move:pinmissile {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:multi "Pin Missile" $trainer $pokedet $otrainer $opokedet]
}

# 43 Leer
proc poke:move:leer {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Leer" $trainer $pokedet $otrainer $opokedet [list "Def -1"] op
  return 0
}

# 44 Bite
proc poke:move:bite {trainer pokedet otrainer opokedet} {
  global poke
  lassign [poke:movetemplate:default "Bite" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:random
  set test [rand 100]
  if {$test < 30} {
    poke:flinch $otrainer $opokedet 0
  }
  return $faint
}

# 45 Growl
proc poke:move:growl {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Growl" $trainer $pokedet $otrainer $opokedet [list "Atk -1"] op
  return 0
}

# 46 Roar
proc poke:move:roar {trainer pokedet otrainer opokedet} {
  poke:movetemplate:forceswitch "Roar" $trainer $pokedet $otrainer $opokedet
  return 0
}

# 47 Sing
proc poke:move:sing {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Sing" $trainer $pokedet $otrainer $opokedet [list SLP] op
  return 0
}

# 48 Supersonic
proc poke:move:supersonic {trainer pokedet otrainer opokedet} {
  poke:random
  set test [rand 4]
  poke:movetemplate:stats "Supersonic" $trainer $pokedet $otrainer $opokedet [list "conf $test"] op
  return 0
}

# 49 Sonic Boom
proc poke:move:sonicboom {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Sonic Boom" $trainer $pokedet $otrainer $opokedet [list dmg 20]] faint dmg
  return $faint
}

# 50 Disable
proc poke:move:disable {trainer pokedet otrainer opokedet} {
  global poke
  set move "Disable"
  array set opokemon $opokedet
  set oID [lsearch $poke(currentPoke) $otrainer]
  set cPoke [lindex $poke(currentPoke) $oID+1]
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  set ppdown 1
  array set opokemon $opokedet
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  if {$cPoke ne $opokemon(species) || [lsearch -glob $opokemon(status) "disable*"] > -1} {
    poke:message fail $move $trainer $pokedet $otrainer $opokedet - 0
    return 0
  }
  set used [lsearch -inline -index 1 -regexp [lreverse $poke(log)] "$otrainer's \\S+ used .*?!"]
  if {$used eq "" || ($used ne "" && [string first $opokemon(species) $used] < 0)} {
    poke:message fail $move $trainer $pokedet $otrainer $opokedet - 0
    return 0
  }
  regexp {\S+?'s \S+ used (.+)!} $used - used_move
  poke:update_pokemon $otrainer $opokedet status "add disable $used_move 4"
  poke:message use $move $trainer $pokedet $otrainer $opokedet - 0
  poke:message custom - $trainer $pokedet $otrainer $opokedet - 0 "got its $used_move disabled"
  lappend poke(prio-9) [list 0 poke:status disable $trainer $pokedet $otrainer $opokedet]
  return 0
}

# 51 Acid
proc poke:move:acid {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "SpD -1"] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Acid" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 52 Ember
proc poke:move:ember {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list BRN] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Ember" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 53 Flamethrower
proc poke:move:flamethrower {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list BRN] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Flamethrower" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 54 Mist
proc poke:move:mist {trainer pokedet otrainer opokedet {count 5}} {
  global poke
  incr count -1
  if {$count == 4} {
    poke:message use "Mist" $trainer $pokedet $otrainer $opokedet - 0
    poke:message customself - $trainer $pokedet $otrainer $opokedet - 0 "became shrouded in a mist"
    poke:update_pokemon $trainer $pokedet status "add mist 4"
    lappend poke(prio-9) [list 0 poke:move:mist $trainer $pokedet $otrainer $opokedet 4]
  } elseif {$count > 0} {
    lappend poke(prio-9) [list 0 poke:move:mist $trainer $pokedet $otrainer $opokedet $count]
    poke:update_pokemon $trainer $pokedet status "add mist -1"
  }
  return $faint
}

# 55 Water Gun
proc poke:move:watergun {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Water Gun" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 56 Hydro Pump
proc poke:move:hydropump {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Hydro Pump" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 57 Surf
proc poke:move:surf {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Surf" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 58 Ice Beam
proc poke:move:icebeam {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list FRZ] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Ice Beam" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 59 Blizzard
proc poke:move:blizzard {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list FRZ] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Blizzard" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 60 Psybeam
proc poke:move:psybeam {trainer pokedet otrainer opokedet} {
  global poke
  poke:random
  set test [rand 4]
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "conf $test"] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Psybeam" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 61 Bubble Beam
proc poke:move:bubblebeam {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "Spd -1"] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Bubble Beam" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 62 Aurora Beam
proc poke:move:aurorabeam {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "Atk -1"] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Aurora Beam" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 63 Hyper Beam
proc poke:move:hyperbeam {trainer pokedet otrainer opokedet} {
  global poke
  lassign [poke:movetemplate:default "Hyper Beam" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:movetemplate:recharge $trainer $pokedet $otrainer $opokedet
  return $faint
}

# 64 Peck
proc poke:move:peck {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Peck" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 65 Drill Peck
proc poke:move:drillpeck {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Drill Peck" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 66 Submission
proc poke:move:submission {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Submission" $trainer $pokedet $otrainer $opokedet] faint dmg
  if {$faint != 2} {
    set dmg [expr {int($dmg*0.25)}]
    poke:movetemplate:recoil $trainer $pokedet $otrainer $opokedet $dmg "suffers $dmg of recoil"
  }
  return $faint
}

# 67 Low Kick
proc poke:move:lowkick {trainer pokedet otrainer opokedet} {
  global poke
  array set opokemon $opokedet
  set table pokeDetails $poke(gen)
  set weight [dex eval "SELECT weight FROM $table WHERE formname = '$opokemon(species)'"]
  if {$weight <= 10} {
    set bp 20
  } elseif {$weight <= 25} {
    set bp 40
  } elseif {$weight <= 50} {
    set bp 60
  } elseif {$weight <= 100} {
    set bp 80
  } elseif {$weight <= 200} {
    set bp 100
  } else {
    set bp 120
  }
  lassign [poke:movetemplate:default "Low Kick" $trainer $pokedet $otrainer $opokedet [list dp $bp]] faint dmg
  return $faint
}

# 68 Counter
proc poke:move:counter {trainer pokedet otrainer opokedet} {
  global poke
  array set pokemon $pokedet
  set msgs [lsearch -all -inline -index 0 $poke(log) $poke(turn)]
  set dmg [lsearch -inline -index 1 -regexp $msgs "\\S+?'s \\S+ used .*! $trainer's $pokemon(species) suffered \\d+ damage!"]
  if {$dmg eq ""} {
    poke:message fail "Counter" $trainer $pokedet $otrainer $opokedet - 0
    return 0
  }
  regexp {\S+?'s \S+ used (.*?)! .* suffered (\d+) damage!} $dmg - move dmg
  set table movedetails$poke(gen)
  set res [dex eval "SELECT class FROM $table WHERE name = '$move'"]
  if {$res eq "Physical"} {
    set dmg [expr {$dmg*2}]
    lassign [poke:movetemplate:default "Counter" $trainer $pokedet $otrainer $opokedet [list dmg $dmg]] faint dmg
    return $faint
  } else {
    poke:message fail "Counter" $trainer $pokedet $otrainer $opokedet - 0
    return 0
  }
}

# 69 Seismic Toss
proc poke:move:seismictoss {trainer pokedet otrainer opokedet} {
  array set pokemon $pokedet
  lassign [poke:movetemplate:default "Seismic Toss" $trainer $pokedet $otrainer $opokedet [list dmg $pokemon(level)]] faint dmg
  return $faint
}

# 70 Strength
proc poke:move:strength {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Strength" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 71 Absorb
proc poke:move:absorb {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Absorb" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:movetemplate:heal "" $trainer $pokedet $otrainer $opokedet "$dmg/2" 0
  return $faint
}

# 72 Mega Drain
proc poke:move:megadrain {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Mega Drain" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:movetemplate:heal "" $trainer $pokedet $otrainer $opokedet "$dmg/2" 0
  return $faint
}

# 74 Growth
proc poke:move:growth {trainer pokedet otrainer opokedet} {
  global poke
  set boost [list "Atk +1" "SpA +1"]
  if {"sun" in $poke(field)} {
    set boost [list "Atk +2" "SpA +2"]
  }
  poke:movetemplate:stats "Growth" $trainer $pokedet $otrainer $opokedet $boost self
  return 0
}

# 75 Razor Leaf
proc poke:move:razorleaf {trainer pokedet otrainer opokedet} {
  lassign [poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"] - pokedet
  lassign [poke:movetemplate:default "Razor Leaf" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
  return $faint
}

# 76 Solar Beam
proc poke:move:solarbeam {trainer pokedet otrainer opokedet {charged 1}} {
  global poke
  set move "Solar Beam"
  if {$charged} {
    poke:movetemplate:charge $move $trainer $pokedet $otrainer $opokedet "absorbed sunlight"
    return 0
  } else {
    lassign [poke:movetemplate:default $move $trainer $pokedet $otrainer $opokedet] faint dmg
    return $faint
  }
}

# 77 Poison Powder
proc poke:move:poisonpowder {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Poison Powder" $trainer $pokedet $otrainer $opokedet [list PSN] op
  return 0
}

# 78 Stun Spore
proc poke:move:stunspore {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Stun Spore" $trainer $pokedet $otrainer $opokedet [list PAR] op
  return 0
}

# 79 Sleep Powder
proc poke:move:sleeppowder {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Sleep Powder" $trainer $pokedet $otrainer $opokedet [list SLP] op
  return 0
}

# 80 Petal Dance
proc poke:move:petaldance {trainer pokedet otrainer opokedet} {
  poke:random
  set count [expr {[rand 2]+2}]
  return [poke:movetemplate:multiturn "Petal Dance" $trainer $pokedet $otrainer $opokedet $count]
}

# 81 String Shot
proc poke:move:stringshot {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "String Shot" $trainer $pokedet $otrainer $opokedet [list "Spd -1"] op
  return 0
}

# 82 Dragon Rage
proc poke:move:sonicboom {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Dragon Rage" $trainer $pokedet $otrainer $opokedet [list dmg 40]] faint dmg
  return $faint
}

# 83 Fire Spin
proc poke:move:firespin {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:trap "Fire Spin" $trainer $pokedet $otrainer $opokedet]
}

# 84 Thunder Shock
proc poke:move:thundershock {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list PAR] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Thunder Shock" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 85 Thunderbolt
proc poke:move:thunderbolt {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list PAR] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Thunderbolt" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 86 Thunder Wave
proc poke:move:thunderwave {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Thunder Wave" $trainer $pokedet $otrainer $opokedet [list PAR] op
  return 0
}

# 87 Thunder
proc poke:move:thunder {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list PAR] 30 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Thunder" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 88 Rock Throw
proc poke:move:rockthrow {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Rock Throw" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 89 Earthquake
proc poke:move:earthquake {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Earthquake" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 90 Fissure
proc poke:move:fissure {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:ohko "Fissure" $trainer $pokedet $otrainer $opokedet]
}

# 91 Dig
proc poke:move:dig {trainer pokedet otrainer opokedet {charged 1}} {
  global poke
  set move "Dig"
  if {$charged} {
    poke:update_pokemon $trainer $pokedet add "earthbound"
    poke:movetemplate:charge $move $trainer $pokedet $otrainer $opokedet "burrowed underground"
    return 0
  } else {
    lassign [poke:movetemplate:default $move $trainer $pokedet $otrainer $opokedet] faint dmg
    return $faint
  }
}

# 92 Toxic
proc poke:move:toxic {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Toxic" $trainer $pokedet $otrainer $opokedet [list BPSN] op
  return 0
}

# 93 Confusion
proc poke:move:confusion {trainer pokedet otrainer opokedet} {
  global poke
  poke:random
  set test [rand 4]
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "conf $test"] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Confusion" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 94 Psychic
proc poke:move:psychic {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "SpD -1"] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Psychic" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 95 Hypnosis
proc poke:move:hypnosis {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Hypnosis" $trainer $pokedet $otrainer $opokedet [list SLP] op
  return 0
}

# 96 Meditate
proc poke:move:meditate {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Meditate" $trainer $pokedet $otrainer $opokedet [list "Atk +1"] self
  return 0
}

# 97 Agility
proc poke:move:agility {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Agility" $trainer $pokedet $otrainer $opokedet [list "Spd +2"] self
  return 0
}

# 98 Quick Attack
proc poke:move:quickattack {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Quick Attack" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 99 Rage
proc poke:move:rage {trainer pokedet otrainer opokedet {type "activate"}} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "Atk +1"] 100 self 0]
  if {$type eq "activate"} {
    lappend poke(triggers) $effect
    lassign [poke:movetemplate:default "Rage" $trainer $pokedet $otrainer $opokedet] faint dmg
    lappend poke(prio-10) [list 0 poke:move:rage $trainer $pokedet $otrainer $opokedet "deactivate"]
    return $faint
  } else {
    set idx [lsearch $poke(triggers) $effect]
    set poke(triggers) [lreplace $poke(triggers) $idx $idx]
  }
}

# 100 Teleport
proc poke:move:teleport {trainer pokedet otrainer opokedet} {
  poke:message fail "Teleport" $trainer $pokedet $otrainer $opokedet - 0
  return 0
}

# 101 Night Shade
proc poke:move:nightshade {trainer pokedet otrainer opokedet} {
  array set pokemon $pokedet
  lassign [poke:movetemplate:default "Night Shade" $trainer $pokedet $otrainer $opokedet [list dmg $pokemon(level)]] faint dmg
  return $faint
}

# 103 Screech
proc poke:move:screech {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Screech" $trainer $pokedet $otrainer $opokedet [list "Def -2"] op
  return 0
}

# 104 Double Team
proc poke:move:doubleteam {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Double Team" $trainer $pokedet $otrainer $opokedet [list "Eva +1"] self
  return 0
}

# 105 Recover
proc poke:move:recover {trainer pokedet otrainer opokedet} {
  poke:message use "Recover" $trainer $pokedet $otrainer $opokedet - 0
  poke:movetemplate:heal "Recover" $trainer $pokedet $otrainer $opokedet {$pokemon(HP)/2} 1
  return 0
}

# 106 Harden
proc poke:move:harden {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Harden" $trainer $pokedet $otrainer $opokedet [list "Def +1"] self
  return 0
}

# 107 Minimize
proc poke:move:minimize {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Minimize" $trainer $pokedet $otrainer $opokedet [list "Eva +1"] self
  return 0
}

# 108 Smokescreen
proc poke:move:smokescreen {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Smokescreen" $trainer $pokedet $otrainer $opokedet [list "Acc -1"] op
  return 0
}

# 109 Confuse Ray
proc poke:move:confuseray {trainer pokedet otrainer opokedet} {
  poke:random
  set test [rand 4]
  poke:movetemplate:stats "Confuse Ray" $trainer $pokedet $otrainer $opokedet [list "conf $test"] op
  return 0
}

# 110 Withdraw
proc poke:move:withdraw {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Withdraw" $trainer $pokedet $otrainer $opokedet [list "Def +1"] self
  return 0
}

# 111 Defense Curl
proc poke:move:defensecurl {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Defense Curl" $trainer $pokedet $otrainer $opokedet [list "Def +1"] self
  return 0
}

# 112 Barrier
proc poke:move:barrier {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Barrier" $trainer $pokedet $otrainer $opokedet [list "Def +2"] self
  return 0
}

# 114 Haze
proc poke:move:haze {trainer pokedet otrainer opokedet} {
  poke:message use "Haze" $trainer $pokedet $otrainer $opokedet - 0
  array set opokemon $opokedet
  set stats [list]
  foreach stat $opokedet(status) {
    if {[regexp {(?:Atk|Def|Sp[ADd])} $stat]} {
      continue
    } else {
      lappend stats $stat
    }
  }
  poke:update_pokemon $otrainer $opokedet status $stats
  
  array set pokemon $pokedet
  set stats [list]
  foreach stat $pokedet(status) {
    if {[regexp {(?:Atk|Def|Sp[ADd])} $stat]} {
      continue
    } else {
      lappend stats $stat
    }
  }
  poke:update_pokemon $trainer $pokedet status $stats
  poke:message fullcustom - $trainer $pokedet $otrainer $opokedet - 0 "All stat changes were eliminated"
  return 0
}

# 116 Focus Energy
proc poke:move:focusenergy {trainer pokedet otrainer opokedet} {
  array set pokemon $pokedet
  if {[lsearch $pokemon(status) "focusenergy"] == -1} {
    lassign [poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"] - pokedet
    lassign [poke:update_pokemon $trainer $pokedet "status" "add focusenergy"] - pokedet
    poke:message use "Focus Energy" $trainer $pokedet $otrainer $opokedet - 0
    poke:message customself - $trainer $pokedet $otrainer $opokedet - 0 "is getting pumped"
  } else {
    poke:message fail "Focus Energy" $trainer $pokedet $otrainer $opokedet - 0
  }
  return $faint
}

# 117 Bide
proc poke:move:bide {trainer pokedet otrainer opokedet {state 0} {dmg 0}} {
  global poke
  array set pokemon $pokedet
  switch -regexp $state {
    0 {
      set ppdown 1
      array set opokemon $opokedet
      if {$opokemon(ability) eq "Pressure"} {incr ppdown}
      poke:update_pokemon $trainer $pokedet "Move" "-$ppdown Bide"
      
      poke:trigger launch $otrainer $opokedet $trainer $pokedet
     
      set trainerID [lsearch -index 0 $poke(team) $trainer]
      set pokeID [lsearch -regexp [lindex $poke(team) $trainerID 1] "\\yspecies \\{?$pokemon(species)\\y\\}?"]
      set opponentID [lsearch $poke(currentPoke) $otrainer]
      
      lappend poke(prio-7) [list $pokemon(Spd) poke:move:bide $trainer $pokemon(species) $trainerID $pokeID $opponentID 1 $dmg]
      lappend poke(triggers) [list damage poke:move:bide $trainer $pokedet $otrainer $opokedet 1 $dmg]
      lappend poke(pending) [list -7 $pokemon(Spd) poke:move:bide $trainer $pokemon(species) $trainerID $pokeID $opponentID 2 $dmg]
      poke:message use "Bide" $trainer $pokedet $otrainer $opokedet - 0
      poke:message customself - $trainer $pokedet $otrainer $opokedet - 0 "is storing energy"
    }
    1 {
      if {$poke(currentPrio) == -7} {
        incr poke(battleready)
        lappend poke(ready) $trainer      
        
        poke:message customself - $trainer $pokedet $otrainer $opokedet - 0 "is storing energy"
      } else {
        if {$poke(currentPrio) == -9} {return}
        set msgs [lsearch -all -inline -index 0 $poke(log) $poke(turn)]
        set action [lsearch -inline -index 1 -regexp $msgs "$trainer's $pokemon(species) suffered \\d+ damage!"]
        if {$action eq ""} {return}
        regexp {\S+?'s \S+ used (.*)! .* suffered (\d+) damage!} [lindex $action 1] - move damage
        set trainerID [lsearch -index 0 $poke(team) $trainer]
        set pokeID [lsearch -regexp [lindex $poke(team) $trainerID 1] "\\yspecies \\{?$pokemon(species)\\y\\}?"]
        set opponentID [lsearch $poke(currentPoke) $otrainer]
        set dmg [expr {$damage+$dmg}]
        set id1 [lsearch -glob $poke(prio-7) "$pokemon(Spd) poke:move:bide $trainer $pokemon(species)*"]
        set id2 [lsearch -glob $poke(pending) [list -7 $pokemon(Spd) poke:move:bide $trainer $pokemon(species) $trainerID $pokeID $opponentID * $dmg]]

        if {$id1 > -1} {lset poke(prio-7) $id1 end $dmg}
        if {$id2 > -1} {lset poke(pending) $id2 end $dmg}
      }
    }
    2 {
      incr poke(battleready)
      lappend poke(ready) $trainer
     
      set trainerID [lsearch -index 0 $poke(team) $trainer]
      set pokeID [lsearch -regexp [lindex $poke(team) $trainerID 1] "\\yspecies \\{?$pokemon(species)\\y\\}?"]
      set opponentID [lsearch $poke(currentPoke) $otrainer]
  
      lappend poke(pending) [list 0 $pokemon(Spd) poke:move:bide $trainer $pokemon(species) $trainerID $pokeID $opponentID 3 $dmg]
      
      poke:message customself - $trainer $pokedet $otrainer $opokedet - 0 "is storing energy"
    }
    3 {
      set opponentID [lsearch $poke(currentPoke) $otrainer]
      set opponentPoke [lindex $poke(currentPoke) $opponentID+1]
      set trainerID [lsearch -index 0 $poke(team) $trainer]
      set opTeam [lindex $poke(team) [expr {1-$trainerID}] 1]
      set opPokeID [lsearch -regexp $opTeam "\\yspecies \\{?$opponentPoke\\y\\}?"]
      set opokedet [lindex $opTeam $opPokeID]
      
      array set opokemon $opokedet
      poke:trigger launch $otrainer $opokedet $trainer $pokedet
      set weakness [poke:get_weakness "Normal" $opokemon(type) $opokemon(status)]
      if {[string match "*Ghost*" $opokemon(type)] && $pokemon(ability) eq "Scrappy"} {
        regsub {Ghost} $opokemon(type) "Normal" type
        set weakness [poke:get_weakness "Normal" $type $opokemon(status)]
      }
      set dmg [expr {int($dmg*2*$weakness)}]
      poke:message customself - $trainer $pokedet $otrainer $opokedet - 0 "unleashed energy"
      if {$dmg == 0} {
        poke:message fullcustom - $trainer $pokedet $otrainer $opokedet - 0 "But it failed"
      } else {
        poke:update_pokemon $otrainer $opokedet "cHP" "-$dmg"
        poke:message custom - $trainer $pokedet $otrainer $opokedet - 0 "suffered $dmg damage"
      }
    }
  }
}

# 118 Metronome
proc poke:move:metronome {trainer pokedet otrainer opokedet} {
  global poke
  poke:message use "Metronome" $trainer $pokedet $otrainer $opokedet
  
  set ppdown 1
  array set opokemon $opokedet
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown Metronome"
  
  set table moveDetails$poke(gen)
  set movelist [list]
  array set pokemon $pokedet
  set moveset [lmap {a b} [array get pokemon Move*] {set b [lindex $b 0]}]
  set exceptions [list "Assist" "Chatter" "Copycat" "Counter" "Covet" "Destiny Bond" "Detect" "Endure" "Feint" "Focus Punch" "Follow Me" "Helping Hand" "Me First" "Metronome" "Mimic" "Mirror Coat" "Mirror Move" "Protect" "Quick Guard" "Sketch" "Sleep Talk" "Snatch" "Struggle" "Switcheroo" "Thief" "Trick" "Wide Guard"]
  foreach move [dex eval "SELECT name FROM $table"] {
    if {$move in $moveset || $move in $exceptions} {continue}
    lappend movelist $move
  }
  poke:random
  set test [rand [llength $movelist]]
  poke:move:[join [string tolower [lindex $movelist $test]] ""] $trainer $pokedet $otrainer $opokedet
}

# 120 Self-Destruct
proc poke:move:self-destruct {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Self-Destruct" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:update_pokemon $trainer $pokedet cHP 0
  poke:message kamikaze "" $trainer $pokedet $otrainer $opokedet - 0
  lappend poke(prio-10) [list 0 poke:faint $trainer]
  lappend poke(switch) [list $trainer $pokemon(species)]
  return $faint
}

# 121 Egg Bomb
proc poke:move:eggbomb {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Egg Bomb" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 122 Lick
proc poke:move:lick {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list PAR] 30 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Lick" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 123 Smog
proc poke:move:smog {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list PSN] 40 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Smog" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 124 Sludge
proc poke:move:sludge {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list PSN] 30 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Sludge" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 125 Bone Club
proc poke:move:boneclub {trainer pokedet otrainer opokedet} {
  global poke
  lassign [poke:movetemplate:default "Bone Club" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:random
  set test [rand 100]
  if {$test < 10} {
    poke:flinch $otrainer $opokedet 0
  }
  return $faint
}

# 126 Fire Blast
proc poke:move:fireblast {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list BRN] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Fire Blast" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 127 Waterfall
proc poke:move:waterfall {trainer pokedet otrainer opokedet} {
  global poke
  lassign [poke:movetemplate:default "Waterfall" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:random
  set test [rand 100]
  if {$test < 20} {
    poke:flinch $otrainer $opokedet 0
  }
  return $faint
}

# 128 Clamp
proc poke:move:clamp {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:trap "Clamp" $trainer $pokedet $otrainer $opokedet]
}

# 129 Swift
proc poke:move:swift {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Swift" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 130 Skull Bash
proc poke:move:skullbash {trainer pokedet otrainer opokedet {charged 1}} {
  global poke
  set move "Skull Bash"
  if {$charged} {
    poke:movetemplate:charge $move $trainer $pokedet $otrainer $opokedet "lowers its head"
    poke:update_pokemon $trainer $pokedet status "add Def 1"
    return 0
  } else {
    lassign [poke:movetemplate:default $move $trainer $pokedet $otrainer $opokedet] faint dmg
    return $faint
  }
}

# 131 Spike Cannon
proc poke:move:spikecannon {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:multi "Spike Cannon" $trainer $pokedet $otrainer $opokedet]
}

# 132 Constrict
proc poke:move:constrict {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "Spd -1"] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Constrict" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 133 Amnesia
proc poke:move:amnesia {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Amnesia" $trainer $pokedet $otrainer $opokedet [list "SpD +2"] self
  return 0
}

# 134 Kinesis
proc poke:move:kinesis {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Kinesis" $trainer $pokedet $otrainer $opokedet [list "Acc -1"] op
  return 0
}

# 135 Soft-Boiled
proc poke:move:soft-boiled {trainer pokedet otrainer opokedet} {
  poke:message use "Soft-Boiled" $trainer $pokedet $otrainer $opokedet - 0
  poke:movetemplate:heal "Soft-Boiled" $trainer $pokedet $otrainer $opokedet {$pokemon(HP)/2} 1
  return 0
}

# 136 High Jump Kick
proc poke:move:highjumpkick {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "High Jump Kick" $trainer $pokedet $otrainer $opokedet] faint dmg
  if {$faint == 2} {
    set dmg [expr {int($dmg*0.5)}]
    poke:movetemplate:recoil $trainer $pokedet $otrainer $opokedet $dmg "went crashing and suffered $dmg damage"
  }
  return $faint
}

# 137 Glare
proc poke:move:glare {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Glare" $trainer $pokedet $otrainer $opokedet [list PAR] op
  return 0
}

# 138 Dream Eater
proc poke:move:dreameater {trainer pokedet otrainer opokedet} {
  array set opokemon $opokedet
  if {"SLP" ni $opokemon(status)} {
    poke:message fail "Dream Eater" $trainer $pokedet $otrainer $opokedet - 0
    return 0
  }
  lassign [poke:movetemplate:default "Dream Eater" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:movetemplate:heal "" $trainer $pokedet $otrainer $opokedet "$dmg/2" 0
  return $faint
}

# 139 Poison Gas
proc poke:move:poisongas {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Poison Gas" $trainer $pokedet $otrainer $opokedet [list PSN] op
  return 0
}

# 140 Barrage
proc poke:move:barrage {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:multi "Barrage" $trainer $pokedet $otrainer $opokedet]
}

# 141 Leech Life
proc poke:move:leechlife {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Leech Life" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:movetemplate:heal "" $trainer $pokedet $otrainer $opokedet "$dmg/2" 0
  return $faint
}

# 142 Lovely Kiss
proc poke:move:lovelykiss {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Lovely Kiss" $trainer $pokedet $otrainer $opokedet [list SLP] op
  return 0
}

# 143 Sky Attack
proc poke:move:skyattack {trainer pokedet otrainer opokedet {charged 1}} {
  global poke
  set move "Sky Attack"
  if {$charged} {
    poke:movetemplate:charge $move $trainer $pokedet $otrainer $opokedet "is glowing"
    return 0
  } else {
    lassign [poke:movetemplate:default $move $trainer $pokedet $otrainer $opokedet] faint dmg
    return $faint
  }
}

# 145 Bubble
proc poke:move:bubble {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "Spd -1"] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Bubble" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 146 Dizzy Punch
proc poke:move:dizzypunch {trainer pokedet otrainer opokedet} {
  global poke
  poke:random
  set test [rand 4]
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "conf $test"] 20 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Dizzy Punch" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 147 Spore
proc poke:move:spore {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Spore" $trainer $pokedet $otrainer $opokedet [list SLP] op
  return 0
}

# 148 Flash
proc poke:move:flash {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Flash" $trainer $pokedet $otrainer $opokedet [list "Acc -1"] op
  return 0
}

# 149 Psywave
proc poke:move:psywave {trainer pokedet otrainer opokedet} {
  array set pokemon $pokedet
  poke:random
  set test [rand 10]
  set value [expr {($test+50.0)/10)*$pokemon(HP)}]
  lassign [poke:movetemplate:default "Psywave" $trainer $pokedet $otrainer $opokedet [list dmg $value]] faint dmg
  return $faint
}

# 150 Splash
proc poke:move:splash {trainer pokedet otrainer opokedet} {
  poke:message nothing "Splash" $trainer $pokedet $otrainer $opokedet - 0
  return 0
}

# 151 Acid Armor
proc poke:move:acidarmor {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Acid Armor" $trainer $pokedet $otrainer $opokedet [list "Def +2"] self
  return 0
}

# 152 Crabhammer
proc poke:move:crabhammer {trainer pokedet otrainer opokedet} {
  lassign [poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"] - pokedet
  lassign [poke:movetemplate:default "Crabhammer" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
  return $faint
}

# 152 Explosion
proc poke:move:explosion {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Explosion" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:update_pokemon $trainer $pokedet cHP 0
  poke:message kamikaze "" $trainer $pokedet $otrainer $opokedet - 0
  lappend poke(prio-10) [list 0 poke:faint $trainer]
  lappend poke(switch) [list $trainer $pokemon(species)]
  return $faint
}

# 154 Fury Swipes
proc poke:move:furyswipes {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:multi "Fury Swipes" $trainer $pokedet $otrainer $opokedet]
}

# 155 Bonemerang
proc poke:move:bonemerang {trainer pokedet otrainer opokedet} {
  set faint [poke:movetemplate:multi "Bonemerang" $trainer $pokedet $otrainer $opokedet 2]
  return $faint 
}

# 156 Rest
proc poke:move:rest {trainer pokedet otrainer opokedet} {
  array set pokemon $pokedet
  set ailment [lsearch -inline -regexp $pokemon(status) {(?:BRN|B?PSN|PAR)}]
  if {$ailment != ""} {
    poke:update_pokemon $trainer $pokedet status "rem $ailment"
  }
  poke:movetemplate:stats "Rest" $trainer $pokedet $otrainer $opokedet [list SLP] self
  poke:update_pokemon $trainer $pokedet "cHP" +$pokemon(HP)
  poke:message use "Rest" $trainer $pokedet $otrainer $opokedet - 0
  poke:message customself - $trainer $pokedet $otrainer $opokedet - 0 "slept and became healthy"
  return 0
}

# 157 Rock Slide
proc poke:move:rockslide {trainer pokedet otrainer opokedet} {
  global poke
  lassign [poke:movetemplate:default "Rock Slide" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:random
  set test [rand 100]
  if {$test < 30} {
    poke:flinch $otrainer $opokedet 0
  }
  return $faint
}

# 158 Hyper Fang
proc poke:move:hyperfang {trainer pokedet otrainer opokedet} {
  global poke
  lassign [poke:movetemplate:default "Hyper Fang" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:random
  set test [rand 100]
  if {$test < 30} {
    poke:flinch $otrainer $opokedet 0
  }
  return $faint
}

# 159 Sharpen
proc poke:move:sharpen {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Sharpen" $trainer $pokedet $otrainer $opokedet [list "Atk +1"] self
  return 0
}

# 160 Conversion
proc poke:move:conversion {trainer pokedet otrainer opokedet} {
  global poke
  array set pokemon $pokedet
  set moveset [lmap {a b} [array get pokemon Move*] {set b [lindex $b 0]}]
  set table moveDetails$poke(gen)
  set typelist [list]
  foreach move $moveset {
    if {$move eq "Curse"} {continue}
    set type [dex eval "SELECT type FROM $table WHERE name = '$move'"]
    if {$pokemon(type) ne $type} {lappend typelist $type}
  }
  if {[llength $typelist] == 0} {
    poke:message fail "Conversion" $trainer $pokedet $otrainer $opokedet - 0
  } else {
    poke:random
    set test [rand [llength $typelist]]
    poke:update_pokemon $trainer $pokedet type [lindex $typelist $test]
    poke:message use "Conversion" $trainer $pokedet $otrainer $opokedet - 0
    poke:message customself - $trainer $pokedet $otrainer $opokedet - 0 "turned into [lindex $typelist $test] type"
  }
  return 0
}

# 161 Tri Attack
proc poke:move:triattack {trainer pokedet otrainer opokedet} {
  poke:random
  set test [rand 3]
  switch $test {
    0 {set stat [list BRN]}
    1 {set stat [list PAR]}
    2 {set stat [list FRZ]}
  }
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet $stat 30 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Tri Attack" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 162 Super Fang
proc poke:move:superfang {trainer pokedet otrainer opokedet} {
  array set opokemon $opokedet
  lassign [poke:movetemplate:default "Super Fang" $trainer $pokedet $otrainer $opokedet [list dmg [expr {$opokemon(cHP)/2}]]] faint dmg
  return $faint
}

# 163 Slash
proc poke:move:slash {trainer pokedet otrainer opokedet} {
  lassign [poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"] - pokedet
  lassign [poke:movetemplate:default "Slash" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
  return $faint
}

# 164 Substitute
proc poke:move:substitute {trainer pokedet otrainer opokedet} {
  array set pokemon $pokedet
  set price [expr {int(ceil($pokemon(HP)*0.25))}]
  if {$pokemon(cHP) < $price} {
    
  } else {
    poke:update_pokemon $trainer $pokedet "cHP" "-$price"
  }
  return 0
}

# 165 Struggle
proc poke:move:struggle {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Struggle" $trainer $pokedet $otrainer $opokedet] faint dmg
  array set pokemon $pokedet
  set recoil [expr {int($pokemon(HP)*0.25)}]
  poke:movetemplate:recoil $trainer $pokedet $otrainer $opokedet $dmg "suffers $dmg of recoil"
  return $faint
}

# 167 Triple Kick
proc poke:move:triplekick {trainer pokedet otrainer opokedet} {
  global poke
  set move "Triple Kick"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff contact]
  array set opokemon $opokedet
  array set pokemon $pokedet
  set faint 0
  set fnt ""
  
  poke:message use $move $trainer $pokedet $otrainer $opokedet - 0
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  foreach i {1 2 3} {
    lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] dmgtype dmg crit
    switch $dmgtype {
      miss {
        poke:message multmiss $move $trainer $pokedet $otrainer $opokedet $dmg $crit
        break
      }
      "no effect" {
        poke:message multnoeff $move $trainer $pokedet $otrainer $opokedet $dmg $crit
        return 0
      }
      default {
        switch $dmgtype {
          "super effective" {set eff "It's super effective! "}
          "not effective" {set eff "It's not very effective. "}
          default {set eff ""}
        }
        if {$dmg > $opokemon(cHP)} {set fnt " $otrainer's $opokemon(species) fainted!"}
        set faint [poke:message multhit $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
        lassign [poke:update_pokemon $otrainer $opokedet "cHP" -$dmg] result det
        poke:trigger "mid damage" $otrainer $opokedet $trainer $pokedet
        if {$det != ""} {
          set opokedet $det
          array set opokemon $opokedet
        }
        if {$faint} {break}
        if {[poke:trigger contact $otrainer $opokedet $trainer $pokedet]} {break}
        incr bp 10
      }
    }
  }
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  poke:message multlast $move $trainer $pokedet $otrainer $opokedet - 0
  if {$faint} {poke:faint $otrainer}
  return $faint
}

# 168 Thief
proc poke:move:thief {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Thief" $trainer $pokedet $otrainer $opokedet] faint dmg
  array set pokemon $pokedet
  array set opokemon $opokedet
  
  if {$pokemon(item) eq "" && $opokemon(item) ne "" && $opokemon(ability) ne "Sticky Hold"} {
    foreach a [split $opokemon(item) ""] b [split $opokemon(species) ""] {
      if {$a eq $b} {incr match} else {break}
    }
    if {($opokemon(ability) eq "Multitype" && [string match {*Plate} $opokemon(item)]) || 
      ([string match "Giratina*" $opokemon(species)] && $opokemon(item) eq "Griseous Orb") ||
      ([regexp -- {\S+ite} $item] && $match > 4)
    } {
      # Cannot be stolen
    } else {
      poke:update_pokemon $trainer $pokedet item $opokemon(item)
      poke:update_pokemon $trainer $pokedet oitem $opokemon(item)
      poke:update_pokemon $otrainer $opokedet item ""
      poke:update_pokemon $otrainer $opokedet oitem ""
      poke:message customself - $trainer $pokedet $otrainer $opokedet - 0 "stole $opokemon(item) from its opponent"
    }
  }
  return $faint
}

# 172 Flame Wheel
proc poke:move:flamewheel {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list BRN] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Flame Wheel" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]

  array set pokemon $pokedet
  if {"FRZ" in $pokemon(status)} {
    poke:update_pokemon $trainer $pokedet status "rem FRZ"
    poke:message thaw - $trainer $pokedet $otrainer $opokedet - 0
  }
  return $faint
}

# 173 Snore
proc poke:move:snore {trainer pokedet otrainer opokedet} {
  global poke
  array set pokemon $pokedet
  if {"SLP" ni $pokemon(status)} {
    poke:message fail "Snore" $trainer $pokedet $otrainer $opokedet - 0
    return 0
  }
  lassign [poke:movetemplate:default "Snore" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:random
  set test [rand 100]
  if {$test < 30} {
    poke:flinch $otrainer $opokedet 0
  }
  return $faint
}

# 175 Flail
proc poke:move:flail {trainer pokedet otrainer opokedet} {
  array set pokemon $pokedet
  set factor [expr {64*$pokemon(cHP)/$pokemon(HP)}]
  if {$factor <= 1} {
    set bp 200
  } elseif {$factor <= 5} {
    set bp 150
  } elseif {$factor <= 12} {
    set bp 100
  } elseif {$factor <= 21} {
    set bp 80
  } elseif {$factor <= 42} {
    set bp 40
  } else {
    set bp 20
  }
  lassign [poke:movetemplate:default "Flail" $trainer $pokedet $otrainer $opokedet [list bp $bp]] faint dmg
  return $faint
}

# 177 Aeroblast
proc poke:move:aeroblast {trainer pokedet otrainer opokedet} {
  lassign [poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"] - pokedet
  lassign [poke:movetemplate:default "Aeroblast" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
  return $faint
}

# 178 Cotton Spore
proc poke:move:cottonspore {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Cotton Spore" $trainer $pokedet $otrainer $opokedet [list "Spd -2"] op
  return 0
}

# 179 Reversal
proc poke:move:reversal {trainer pokedet otrainer opokedet} {
  array set pokemon $pokedet
  set factor [expr {64*$pokemon(cHP)/$pokemon(HP)}]
  if {$factor <= 1} {
    set bp 200
  } elseif {$factor <= 5} {
    set bp 150
  } elseif {$factor <= 12} {
    set bp 100
  } elseif {$factor <= 21} {
    set bp 80
  } elseif {$factor <= 42} {
    set bp 40
  } else {
    set bp 20
  }
  lassign [poke:movetemplate:default "Reversal" $trainer $pokedet $otrainer $opokedet [list bp $bp]] faint dmg
  return $faint
}

# 181 Powder Snow
proc poke:move:powdersnow {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list FRZ] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Powder Snow" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 183 Mach Punch
proc poke:move:machpunch {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Mach Punch" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 184 Scary Face
proc poke:move:scaryface {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Scary Face" $trainer $pokedet $otrainer $opokedet [list "Spd -1"] op
  return 0
}

# 185 Feint Attack
proc poke:move:feintattack {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Feint Attack" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 186 Sweet Kiss
proc poke:move:sweetkiss {trainer pokedet otrainer opokedet} {
  poke:random
  set test [rand 4]
  poke:movetemplate:stats "Sweet Kiss" $trainer $pokedet $otrainer $opokedet [list "conf $test"] op
  return 0
}

# 188 Sludge Bomb
proc poke:move:sludgebomb {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list PSN] 30 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Sludge Bomb" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 189 Mud-Slap
proc poke:move:mud-slap {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "Acc -1"] 100 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Mud-Slap" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 190 Octazooka
proc poke:move:octazooka {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "Acc -1"] 50 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Octazooka" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 192 Zap Cannon
proc poke:move:zapcannon {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list PAR] 100 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Zap Cannon" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 196 Icy Wind
proc poke:move:icywind {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "Spd -1"] 100 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Icy Wind" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 198 Bone Rush
proc poke:move:bonerush {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:multi "Bone Rush" $trainer $pokedet $otrainer $opokedet]
}

# 200 Outrage
proc poke:move:outrage {trainer pokedet otrainer opokedet} {
  poke:random
  set count [expr {[rand 2]+2}]
  return [poke:movetemplate:multiturn "Outrage" $trainer $pokedet $otrainer $opokedet $count]
}

# 202 Giga Drain
proc poke:move:gigadrain {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Giga Drain" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:movetemplate:heal "" $trainer $pokedet $otrainer $opokedet "$dmg/2" 0
  return $faint
}

# 204 Charm
proc poke:move:charm {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Charm" $trainer $pokedet $otrainer $opokedet [list "Atk -2"] op
  return 0
}

# 205 Rollout
proc poke:move:rollout {trainer pokedet otrainer opokedet} {
  global poke
  set factor 1
  array set pokemon $pokedet
  set msgs [lsearch -all -inline -index 0 $poke(log) [expr {$poke(turn)-1}]]
  set defensecurl [lsearch -glob -index 1 $msgs "*$pokemon(species) used Defense Curl!"]
  if {$defensecurl > -1} {incr factor}
  return [poke:movetemplate:multiturnincr "Rollout" $trainer $pokedet $otrainer $opokedet 5 $factor]
}

# 206 False Swipe
proc poke:move:falseswipe {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "False Swipe" $trainer $pokedet $otrainer $opokedet [list dmg {[incr dmg -1]}]] faint dmg
  return $faint
}

# 207 Swagger
proc poke:move:swagger {trainer pokedet otrainer opokedet} {
  global poke
  set result [poke:movetemplate:stats "Swagger" $trainer $pokedet $otrainer $opokedet [list "Atk +2"] op]
  if {$result} {
    poke:random
    set test [rand 4]
    poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "conf $test"] 100 op 0
  }
  return 0
}

# 208 Milk Drink
proc poke:move:milkdrink {trainer pokedet otrainer opokedet} {
  poke:message use "Milk Drink" $trainer $pokedet $otrainer $opokedet - 0
  poke:movetemplate:heal "Milk Drink" $trainer $pokedet $otrainer $opokedet {$pokemon(HP)/2} 1
  return 0
}

# 209 Spark
proc poke:move:spark {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list PAR] 30 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Spark" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 211 Steel Wing
proc poke:move:steelwing {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "Def +1"] 10 self 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Steel Wing" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 216 Return
proc poke:move:return {trainer pokedet otrainer opokedet} {
  poke:random
  array set pokemon $pokedet
  set bp [expr {int($pokemon(happiness)*2/5)}]
  if {$bp == 0} {set bp 1}
  lassign [poke:movetemplate:default "Return" $trainer $pokedet $otrainer $opokedet [list bp $bp]] faint dmg
  return $faint
}

# 217 Present
proc poke:move:present {trainer pokedet otrainer opokedet} {
  poke:random
  set test [rand 100]
  if {$test < 40} {
    lassign [poke:movetemplate:default "Present" $trainer $pokedet $otrainer $opokedet [list bp 40]] faint dmg
  } elseif {$test < 70} {
    lassign [poke:movetemplate:default "Present" $trainer $pokedet $otrainer $opokedet [list bp 80]] faint dmg
  } elseif {$test < 80} {
    lassign [poke:movetemplate:default "Present" $trainer $pokedet $otrainer $opokedet [list bp 120]] faint dmg
  } else {
    poke:message use "Present" $trainer $pokedet $otrainer $opokedet - 0
    poke:movetemplate:heal "Present" $trainer $pokedet $otrainer $opokedet {$pokemon(HP)/4} 1 0
    set faint 0
  }
  return $faint
}

# 218 Frustration
proc poke:move:frustration {trainer pokedet otrainer opokedet} {
  poke:random
  array set pokemon $pokedet
  set bp [expr {int((255-$pokemon(happiness))*2/5)}]
  if {$bp == 0} {set bp 1}
  lassign [poke:movetemplate:default "Frustration" $trainer $pokedet $otrainer $opokedet [list bp $bp]] faint dmg
  return $faint
}

# 221 Sacred Fire
proc poke:move:sacredfire {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list BRN] 50 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Sacred Fire" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]

  array set pokemon $pokedet
  if {"FRZ" in $pokemon(status)} {
    poke:update_pokemon $trainer $pokedet status "rem FRZ"
    poke:message thaw - $trainer $pokedet $otrainer $opokedet - 0
  }
  return $faint
}

# 222 Magnitude
proc poke:move:magnitude {trainer pokedet otrainer opokedet} {
  poke:random
  set test [rand 100]
  if {$test < 5} {
    lassign {4 10} mg bp
  } elseif {$test < 15} {
    lassign {5 30} mg bp
  } elseif {$test < 35} {
    lassign {6 50} mg bp
  } elseif {$test < 65} {
    lassign {7 70} mg bp
  } elseif {$test < 85} {
    lassign {8 90} mg bp
  } elseif {$test < 95} {
    lassign {9 110} mg bp
  } else {
    lassign {10 150} mg bp
  }
  lassign [poke:movetemplate:default "Magnitude" $trainer $pokedet $otrainer $opokedet [list bp $bp]] faint dmg
  return $faint
}

# 223 Dynamic Punch
proc poke:move:dymanicpunch {trainer pokedet otrainer opokedet} {
  global poke
  poke:random
  set test [rand 4]
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "conf $test"] 100 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Dynamic Punch" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 224 Megahorn
proc poke:move:megahorn {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Megahorn" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 225 Dragon Breath
proc poke:move:dragonbreath {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list PAR] 30 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Dragon Breath" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 226 Baton Pass
proc poke:move:batonpass {trainer pokedet otrainer opokedet} {
  global poke
  array set pokemon $pokedet
  set status $pokemon(status)
  lappend poke(switch) [list $trainer $pokemon(species) "Baton Pass"]
  poke:message use "Baton Pass" $trainer $pokedet $otrainer $opokedet - 0
  poke:movetemplate:forceswitch "Baton Pass" $trainer $pokedet $otrainer $opokedet 0 0
  return 2
}

# 228 Pursuit
proc poke:move:pursuit {trainer pokedet otrainer opokedet {factor 1}} {
  lassign [poke:movetemplate:default "Pursuit" $trainer $pokedet $otrainer $opokedet[list bp "\[expr {\$bp*$factor}\]"]] faint dmg
  return $faint
}

# 229 Rapid Spin
proc poke:move:rapidspin {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Rapid Spin" $trainer $pokedet $otrainer $opokedet] faint dmg
  # Remove hazards, traps, etc
  return $faint
}

# 230 Sweet Scent
proc poke:move:sweetscent {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Sweet Scent" $trainer $pokedet $otrainer $opokedet [list "Eva -1"] op
  return 0
}

# 231 Iron Tail
proc poke:move:irontail {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "Def -1"] 30 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Iron Tail" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 232 Metal Claw
proc poke:move:metalclaw {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "Atk +1"] 10 self 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Metal Claw" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 233 Vital Throw
proc poke:move:vitalthrow {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Vital Throw" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 234 Morning Sun
proc poke:move:morningsun {trainer pokedet otrainer opokedet} {
  global poke
  # field
  poke:message use "Morning Sun" $trainer $pokedet $otrainer $opokedet - 0
  poke:movetemplate:heal "Morning Sun" $trainer $pokedet $otrainer $opokedet {$pokemon(HP)/2} 1
  return 0
}

# 235 Synthesis
proc poke:move:synthesis {trainer pokedet otrainer opokedet} {
  global poke
  # field
  poke:message use "Synthesis" $trainer $pokedet $otrainer $opokedet - 0
  poke:movetemplate:heal "Synthesis" $trainer $pokedet $otrainer $opokedet {$pokemon(HP)/2} 1
  return 0
}

# 236 Moonlight
proc poke:move:moonlight {trainer pokedet otrainer opokedet} {
  global poke
  # field
  poke:message use "Moonlight" $trainer $pokedet $otrainer $opokedet - 0
  poke:movetemplate:heal "Moonlight" $trainer $pokedet $otrainer $opokedet {$pokemon(HP)/2} 1
  return 0
}

# 237 Hidden Power
proc poke:move:hiddenpower {trainer pokedet otrainer opokedet} {
  array set pokemon $pokedet
  lassign [poke:hidden_power_calc $pokemon(IHP) $pokemon(IAtk) $pokemon(IDef) $pokemon(ISpd) $pokemon(ISpA) $pokemon(ISpD)] type bp
  lassign [poke:movetemplate:default "Hidden Power" $trainer $pokedet $otrainer $opokedet [list type $type bp $bp]] faint dmg
  return $faint
}

# 238 Cross Chop
proc poke:move:crosschop {trainer pokedet otrainer opokedet} {
  lassign [poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"] - pokedet
  lassign [poke:movetemplate:default "Cross Chop" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
  return $faint
}

# 239 Twister
proc poke:move:twister {trainer pokedet otrainer opokedet} {
  global poke
  lassign [poke:movetemplate:default "Twister" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:random
  set test [rand 100]
  if {$test < 20} {
    poke:flinch $otrainer $opokedet 0
  }
  return $faint
}

# 242 Crunch
proc poke:move:crunch {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "Def -1"] 20 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Crunch" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 243 Mirror Coat
proc poke:move:mirrorcoat {trainer pokedet otrainer opokedet} {
  global poke
  array set pokemon $pokedet
  set msgs [lsearch -all -inline -index 0 $poke(log) $poke(turn)]
  set dmg [lsearch -inline -index 1 -regexp $msgs "\\S+?'s \\S+ used .*?! $trainer's $pokemon(species) suffered \\d+ damage!"]
  if {$dmg eq ""} {
    poke:message fail "Mirror Coat" $trainer $pokedet $otrainer $opokedet - 0
    return 0
  }
  regexp {\S+?'s \S+ used (.*?)! .* suffered (\d+) damage!} $dmg - move dmg
  set table movedetails$poke(gen)
  set res [dex eval "SELECT class FROM $table WHERE name = '$move'"]
  if {$res eq "Special"} {
    set dmg [expr {$dmg*2}]
    lassign [poke:movetemplate:default "Mirror Coat" $trainer $pokedet $otrainer $opokedet [list dmg $dmg]] faint dmg
    return $faint
  } else {
    poke:message fail "Mirror Coat" $trainer $pokedet $otrainer $opokedet - 0
    return 0
  }
}

# 245 Extreme Speed
proc poke:move:extremespeed {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Extreme Speed" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 246 Ancient Power
proc poke:move:ancientpower {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "Atk +1" "Def +1" "SpA +1" "SpD +1" "Spd +1"] 10 self 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Ancient Power" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 247 Shadow Ball
proc poke:move:shadowball {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "SpD -1"] 20 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Shadow Ball" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 248 Future Sight
proc poke:move:futuresight {trainer pokedet otrainer opokedet {charged 0}} {
  global poke
  set move "Future Sight"
  if {$charged == 2} {
    poke:update_pokemon $trainer $pokedet status "add Crit -1"
    set table moveDetails$poke(gen)
    set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
    set flags [lassign $movedet id name type class pp bp acc prio eff contact]
    lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] dmgtype dmg crit
    if {$dmgtype in {"miss" "no effect"}} {
      poke:message timedfail $move $trainer $pokedet $otrainer $opokedet - 0
      return [list 2 $dmg]
    }
    set dmgtype [string map {{ } {}} $dmgtype]
    set faint [poke:message timed$dmgtype $move $trainer $pokedet $otrainer $opokedet $dmg 0]
    poke:update_pokemon $trainer $pokedet status "rem Crit"
    poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
    poke:trigger damage $otrainer $opokedet $trainer $pokedet
    return [list $faint $dmg]
  } else {
    array set pokemon $pokedet
    set trainerID [lsearch -index 0 $poke(team) $trainer]
    set pokeID [lsearch -regexp [lindex $poke(team) $trainerID 1] "\\yspecies \\{?$pokemon(species)\\y\\}?"]
    set opponentID [lsearch $poke(currentPoke) $otrainer]
    if {[lsearch -glob $poke(prio-9) "*poke:move:doomdesire $trainer*"] > -1} {
      poke:message fail $move $trainer $pokedet $otrainer $opokedet - 0
      return 0
    }
    if {$charged == 0} {
      poke:message use $move $trainer $pokedet $otrainer $opokedet - 0
      poke:message customself - $trainer $pokedet $otrainer $opokedet - 0 "foresaw an attack"
      poke:trigger launch $otrainer $opokedet $trainer $pokedet
      set ppdown 1
      array set opokemon $opokedet
      if {$opokemon(ability) eq "Pressure"} {incr ppdown}
      poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
    }
    incr charged
    lappend poke(pending) [list -9 $pokemon(Spd) "poke:move:[string tolower [join $move {}]]" $trainer $pokemon(species) $trainerID $pokeID $opponentID $charged]
  }
}

# 249 Rock Smash
proc poke:move:rocksmash {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "Def -1"] 50 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Rock Smash" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 250 Whirlpool
proc poke:move:whirlpool {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:trap "Whirlpool" $trainer $pokedet $otrainer $opokedet]
}

# 252 Fake Out
proc poke:move:fakeout {trainer pokedet otrainer opokedet} {
  global poke
  lassign [poke:movetemplate:default "Cross Chop" $trainer $pokedet $otrainer $opokedet] faint dmg
  # Add flinch if on turn pokemon was switched in
  return $faint
}

# 254 Stockpile
proc poke:move:stockpile {trainer pokedet otrainer opokedet} {
  array set pokemon $pokedet
  set stockpile [lsearch -inline -index 0 $pokemon(status) "stockpile"]
  if {[regexp {\y3$} $stockpile]} {
    poke:message fail "Stockpile" $trainer $pokedet $otrainer $opokedet - 0
    return 0
  }
  poke:movetemplate:stats "Stockpile" $trainer $pokedet $otrainer $opokedet [list "Def +1" "SpD +1"] self
  poke:update_pokemon $trainer $pokedet status "add stockpile +1"
  return 0
}

# 255 Spit Up
proc poke:move:spitup {trainer pokedet otrainer opokedet} {
  array set pokemon $pokedet
  set stockpile [lsearch -inline -index 0 $pokemon(status) "stockpile"]
  if {$stockpile eq ""} {
    poke:message fail "Spit Up" $trainer $pokedet $otrainer $opokedet - 0
    return 0
  }
  set bp [expr {[lindex $stockpile 1]*100}]
  lassign [poke:movetemplate:default "Spit Up" $trainer $pokedet $otrainer $opokedet [list bp $bp]] faint dmg
  poke:update_pokemon $trainer $pokedet status "rem stockpile"
  poke:update_pokemon $trainer $pokedet status "add Def -[lindex $stockpile 1]"
  poke:update_pokemon $trainer $pokedet status "add SpD -[lindex $stockpile 1]"
  return 0
}

# 255 Swallow
proc poke:move:swallow {trainer pokedet otrainer opokedet} {
  array set pokemon $pokedet
  set stockpile [lsearch -inline -index 0 $pokemon(status) "stockpile"]
  if {$stockpile eq ""} {
    poke:message fail "Swallow" $trainer $pokedet $otrainer $opokedet - 0
    return 0
  }
  switch [lindex $stockpile 1] {
    1 {set factor 0.25}
    2 {set factor 0.5}
    3 {set factor 1}
  }
  poke:movetemplate:heal "Swallow" $trainer $pokedet $otrainer $opokedet "$pokemon(HP)*$factor" 1
  poke:update_pokemon $trainer $pokedet status "rem stockpile"
  poke:update_pokemon $trainer $pokedet status "add Def -[lindex $stockpile 1]"
  poke:update_pokemon $trainer $pokedet status "add SpD -[lindex $stockpile 1]"
  return 0
}

# 257 Heat Wave
proc poke:move:heatwave {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list BRN] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Heat Wave" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 260 Flatter
proc poke:move:flatter {trainer pokedet otrainer opokedet} {
  global poke
  poke:movetemplate:stats "Flatter" $trainer $pokedet $otrainer $opokedet [list "SpA +2"] op
  poke:random
  set test [rand 4]
  poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "conf $test"] 100 op 0
  return 0
}

# 261 Will-O-Wisp
proc poke:move:will-o-wisp {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Will-O-Wisp" $trainer $pokedet $otrainer $opokedet [list BRN] op
  return 0
}

# 262 Memento
proc poke:move:memento {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Memento" $trainer $pokedet $otrainer $opokedet [list "Atk -2" "SpA -2"] op
  poke:update_pokemon $trainer $pokedet cHP 0
  poke:message kamikaze "" $trainer $pokedet $otrainer $opokedet - 0
  lappend poke(prio-10) [list 0 poke:faint $trainer]
  lappend poke(switch) [list $trainer $pokemon(species)]
  return 0
}

# 263 Facade
proc poke:move:facade {trainer pokedet otrainer opokedet} {
  array set pokemon $pokedet
  set add ""
  if {[regexp {\y(?:BRN|B?PSN|PAR|SLP)\y} $pokemon(status)]} {
    set add [list bp 140]
  }
  lassign [poke:movetemplate:default "Facade" $trainer $pokedet $otrainer $opokedet $add] faint dmg
  return $faint
}

# 264 Focus Punch
proc poke:move:focuspunch {trainer pokedet otrainer opokedet {focused 1}} {
  global poke
  if {$focused} { 
    array set pokemon $pokedet
    set trainerID [lsearch -index 0 $poke(team) $trainer]
    set pokeID [lsearch -regexp [lindex $poke(team) $trainerID 1] "\\yspecies \\{?$pokemon(species)\\y\\}?"]
    set opponentID [lsearch $poke(currentPoke) $otrainer]
    poke:message customself - $trainer $pokedet $otrainer $opokedet - 0 "is tightening its focus"
    lappend poke(prio-3) [list $pokemon(Spd) "poke:move:focuspunch" $trainer $pokemon(species) $trainerID $pokeID $opponentID 0]
    lappend poke(triggers) [list damage poke:flinch $trainer $pokedet 1]
    return 0
  } else {
    lassign [poke:movetemplate:default "Focus Punch" $trainer $pokedet $otrainer $opokedet] faint dmg
    set idx [lsearch -regexp $poke(triggers) "poke:flinch $trainer $pokemon(species)"]
    if {$idx > -1} {
      set poke(triggers) [lreplace $poke(triggers) $idx $idx]
    }
    return $faint
  }
}

# 265 Smelling Salts
proc poke:move:smellingsalts {trainer pokedet otrainer opokedet {focused ""}} {
  global poke
  array set opokemon $opokedet
  set add ""
  if {"PAR" in $opokemon(status)} {
    set add [list bp 140]
  }
  lassign [poke:movetemplate:default "Smelling Salts" $trainer $pokedet $otrainer $opokedet $add] faint dmg
  if {$faint == 0 && $add != ""} {
    poke:update_pokemon $otrainer $opokedet status "rem PAR"
    poke:message custom - $trainer $pokedet $otrainer $opokedet - 0 "was cured from paralysis!"
  }
  return $faint
}

# 266 Follow Me
proc poke:move:followme {trainer pokedet otrainer opokedet} {
  global poke
  poke:message use "Follow Me" $trainer $pokedet $otrainer $opokedet - 0
  poke:message customself - $trainer $pokedet $otrainer $opokedet - 0 "became the center of attention"
  return 0
}

# 268 Charge
proc poke:move:charge {trainer pokedet otrainer opokedet} {
  global poke
  poke:movetemplate:stats "Charge" $trainer $pokedet $otrainer $opokedet [list "SpD +1"] self
  #lappend poke(trigger) [list launch electric move]
  return 0
}

# 270 Helping Hand
proc poke:move:helpinghand {trainer pokedet otrainer opokedet {focused ""}} {
  poke:message fail "Helping Hand" $trainer $pokedet $otrainer $opokedet - 0
  return 0
}

# 271 Trick
proc poke:move:trick {trainer pokedet otrainer opokedet {focused ""}} {
  array set pokemon $pokedet
  array set opokemon $opokedet
  if {($pokemon(item) ne "" && $opokemon(item) ne "") && $opokemon(ability) ne "Sticky Hold"} {
    foreach a [split $opokemon(item) ""] b [split $opokemon(species) ""] {
      if {$a eq $b} {incr match} else {break}
    }
    if {($opokemon(ability) eq "Multitype" && [string match {*Plate} $opokemon(item)]) || 
      ([string match "Giratina*" $opokemon(species)] && $opokemon(item) eq "Griseous Orb") ||
      ([regexp -- {\S+ite} $item] && $match > 4)
    } {
      # Cannot be stolen
    } else {
      poke:update_pokemon $trainer $pokedet item $opokemon(item)
      poke:update_pokemon $otrainer $opokedet item $pokemon(item)
      poke:update_pokemon $trainer $pokedet oitem $opokemon(item)
      poke:update_pokemon $otrainer $opokedet oitem $pokemon(item)
      poke:message use "Trick" $trainer $pokedet $otrainer $opokedet - 0
      poke:message customself - $trainer $pokedet $otrainer $opokedet - 0 "swapped items with its opponent"
    }
  } else {
    poke:message fail "Trick" $trainer $pokedet $otrainer $opokedet - 0
  }
  return 0
}

# 276 Superpower
proc poke:move:superpower {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "Atk -1" "Def -1"] 100 self 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Superpower" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 279 Revenge
proc poke:move:revenge {trainer pokedet otrainer opokedet} {
  set extra ""
  # if received damage, double calculated damage
  lassign [poke:movetemplate:default "Revenge" $trainer $pokedet $otrainer $opokedet $extra] faint dmg
  return $faint
}

# 280 Brick Break
proc poke:move:brickbreak {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Brick Break" $trainer $pokedet $otrainer $opokedet] faint dmg
  # remove screens
  return $faint
}

# 282 Knock Off
proc poke:move:knockoff {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Knock Off" $trainer $pokedet $otrainer $opokedet] faint dmg
  # remove target's item
  return $faint
}

# 283 Endeavour
proc poke:move:endeavour {trainer pokedet otrainer opokedet} {
  array set pokemon $pokedet
  array set opokemon $opokedet
  if {$opokemon(cHP) > $pokemon(cHP)} {
    lassign [poke:movetemplate:default "Endeavour" $trainer $pokedet $otrainer $opokedet [list dmg [expr {$opokemon(cHP)-$pokemon(cHP)}]]] faint dmg
  } else {
    poke:message fail "Endeavour" $trainer $pokedet $otrainer $opokedet - 0
  }
  return $faint
}

# 284 Eruption
proc poke:move:eruption {trainer pokedet otrainer opokedet} {
  array set pokemon $pokedet
  set bp [expr {150*$pokemon(cHP)/$pokemon(HP)}]
  lassign [poke:movetemplate:default "Eruption" $trainer $pokedet $otrainer $opokedet [list bp $bp]] faint dmg
  return $faint
}

# 291 Dive
proc poke:move:dive {trainer pokedet otrainer opokedet {charged 1}} {
  global poke
  set move "Dive"
  if {$charged} {
    poke:update_pokemon $trainer $pokedet add "waterbound"
    poke:movetemplate:charge $move $trainer $pokedet $otrainer $opokedet "dove underwater!"
    return 0
  } else {
    lassign [poke:movetemplate:default $move $trainer $pokedet $otrainer $opokedet] faint dmg
    return $faint
  }
}

# 292 Arm Thrust
proc poke:move:armthrust {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:multi "Arm Thrust" $trainer $pokedet $otrainer $opokedet]
}

# 294 Tail Glow
proc poke:move:tailglow {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Tail Glow" $trainer $pokedet $otrainer $opokedet [list "SpA +3"] self
  return 0
}

# 295 Luster Purge
proc poke:move:lusterpurge {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "SpD -1"] 50 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Luster Purge" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 296 Mist Ball
proc poke:move:mistball {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "SpA -1"] 50 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Mist Ball" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 297 Feather Dance
proc poke:move:featherdance {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Feather Dance" $trainer $pokedet $otrainer $opokedet [list "Atk -2"] op
  return 0
}

# 298 Teeter Dance
proc poke:move:teeterdance {trainer pokedet otrainer opokedet} {
  poke:random
  set test [rand 4]
  poke:movetemplate:stats "Teeter Dance" $trainer $pokedet $otrainer $opokedet [list "conf $test"] op
  return 0
}

# 299 Blaze Kick
proc poke:move:blazekick {trainer pokedet otrainer opokedet} {
  global poke
  lassign [poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"] - pokedet
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list BRN] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Blaze Kick" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
  return $faint
}

# 301 Ice Ball
proc poke:move:iceball {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:multiturnincr "Ice Ball" $trainer $pokedet $otrainer $opokedet 5 $factor]
}

# 302 Needle Arm
proc poke:move:needlearm {trainer pokedet otrainer opokedet} {
  global poke
  lassign [poke:movetemplate:default "Needle Arm" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:random
  set test [rand 100]
  if {$test < 30} {
    poke:flinch $otrainer $opokedet 0
  }
  return $faint
}

# 303 Slack Off
proc poke:move:slackoff {trainer pokedet otrainer opokedet} {
  poke:message use "Slack Off" $trainer $pokedet $otrainer $opokedet - 0
  poke:movetemplate:heal "Slack Off" $trainer $pokedet $otrainer $opokedet {$pokemon(HP)/2} 1
  return 0
}

# 304 Hyper Voice
proc poke:move:hypervoice {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Hyper Voice" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 305 Poison Fang
proc poke:move:poisonfang {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list BPSN] 30 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Poison Fang" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 306 Crush Claw
proc poke:move:crushclaw {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "Def -1"] 50 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Crush Claw" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 307 Blast Burn
proc poke:move:blastburn {trainer pokedet otrainer opokedet} {
  global poke
  lassign [poke:movetemplate:default "Blast Burn" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:movetemplate:recharge $trainer $pokedet $otrainer $opokedet
  return $faint
}

# 308 Hydro Cannon
proc poke:move:hydrocannon {trainer pokedet otrainer opokedet {recharging 0}} {
  global poke
  lassign [poke:movetemplate:default "Hydro Cannon" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:movetemplate:recharge $trainer $pokedet $otrainer $opokedet
  return $faint
}

# 309 Meteor Mash
proc poke:move:meteormash {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "Atk +1"] 20 self 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Meteor Mash" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 310 Astonish
proc poke:move:astonish {trainer pokedet otrainer opokedet} {
  global poke
  lassign [poke:movetemplate:default "Astonish" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:random
  set test [rand 100]
  if {$test < 30} {
    poke:flinch $otrainer $opokedet 0
  }
  return $faint
}

# 311 Weather Ball
proc poke:move:wewatherball {trainer pokedet otrainer opokedet} {
  global poke
  set extra ""
  if {[regexp -- {\y(?:sun|rain|sand|hail)\y} $poke(field) match]} {
    switch $match {
      sun {lappend extra type Fire}
      rain {lappend extra type Water}
      sand {lappend extra type Rock}
      hail {lappend extra type Ice}
    }
    lappend extra bp 100
  }
  # if received damage, double calculated damage
  lassign [poke:movetemplate:default "Revenge" $trainer $pokedet $otrainer $opokedet $extra] faint dmg
  return $faint
}


# 313 Fake Tears
proc poke:move:faketears {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Fake Tears" $trainer $pokedet $otrainer $opokedet [list "SpD -2"] op
  return 0
}

# 314 Air Cutter
proc poke:move:aircutter {trainer pokedet otrainer opokedet} {
  lassign [poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"] - pokedet
  lassign [poke:movetemplate:default "Air Cutter" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
  return $faint
}

# 315 Overheat
proc poke:move:overheat {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "SpA -2"] 100 self 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Overheat" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 317 Rock Tomb
proc poke:move:rocktomb {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "Spd -1"] 100 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Rock Tomb" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 318 Silver Wind
proc poke:move:silverwind {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "Atk +1" "Def +1" "SpA +1" "SpD +1" "Spd +1"] 10 self 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Silver Wind" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 319 Metal Sound
proc poke:move:metalsound {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Metal Sound" $trainer $pokedet $otrainer $opokedet [list "SpD -2"] op
  return 0
}

# 320 Grass Whistle
proc poke:move:grasswhistle {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Grass Whistle" $trainer $pokedet $otrainer $opokedet [list SLP] op
  return 0
}

# 321 Tickle
proc poke:move:tickle {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Tickle" $trainer $pokedet $otrainer $opokedet [list "Atk -1 Def -1"] op
  return 0
}

# 322 Cosmic Power
proc poke:move:cosmicpower {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Cosmic Power" $trainer $pokedet $otrainer $opokedet [list "Def +1" "SpD +1"] self
  return 0
}

# 323 Water Spout
proc poke:move:waterspout {trainer pokedet otrainer opokedet} {
  array set pokemon $pokedet
  set bp [expr {150*$pokemon(cHP)/$pokemon(HP)}]
  lassign [poke:movetemplate:default "Water Spout" $trainer $pokedet $otrainer $opokedet [list bp $bp]] faint dmg
  return $faint
}

# 324 Signal Beam
proc poke:move:signalbeam {trainer pokedet otrainer opokedet} {
  global poke
  poke:random
  set test [rand 4]
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "conf $test"] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Signal Beam" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 325 Shadow Punch
proc poke:move:shadowpunch {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Shadow Punch" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 326 Extrasensory
proc poke:move:extrasensory {trainer pokedet otrainer opokedet} {
  global poke
  lassign [poke:movetemplate:default "Extrasensory" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:random
  set test [rand 100]
  if {$test < 30} {
    poke:flinch $otrainer $opokedet 0
  }
  return $faint
}

# 327 Sky Uppercut
proc poke:move:skyuppercut {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Sky Uppercut" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 238 Sand Tomb
proc poke:move:sandtomb {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:trap "Sand Tomb" $trainer $pokedet $otrainer $opokedet]
}

# 329 Sheer Cold
proc poke:move:sheercold {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:ohko "Sheer Cold" $trainer $pokedet $otrainer $opokedet]
}

# 330 Muddy Water
proc poke:move:muddywater {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "Acc -1"] 30 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Muddy Water" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 331 Bullet Seed
proc poke:move:bulletseed {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:multi "Bullet Seed" $trainer $pokedet $otrainer $opokedet]
}

# 332 Aerial Ace
proc poke:move:aerialace {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Aerial Ace" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 333 Icicle Spear
proc poke:move:iciclespear {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:multi "Icicle Spear" $trainer $pokedet $otrainer $opokedet]
}

# 334 Iron Defense
proc poke:move:irondefense {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Iron Defense" $trainer $pokedet $otrainer $opokedet [list "Def +2"] self
  return 0
}

# 336 Howl
proc poke:move:howl {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Howl" $trainer $pokedet $otrainer $opokedet [list "Atk +1"] self
  return 0
}

# 337 Dragon Claw
proc poke:move:dragonclaw {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Dragon Claw" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 338 Frenzy Plant
proc poke:move:frenzyplant {trainer pokedet otrainer opokedet {recharging 0}} {
  global poke
  lassign [poke:movetemplate:default "Frenzy Plant" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:movetemplate:recharge $trainer $pokedet $otrainer $opokedet
  return $faint
}

# 339 Bulk Up
proc poke:move:bulkup {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Bulk Up" $trainer $pokedet $otrainer $opokedet [list "Atk +1" "Def +1"] self
  return 0
}

# 340 Bounce
proc poke:move:bounce {trainer pokedet otrainer opokedet {charged 1}} {
  global poke
  set move "Bounce"
  if {$charged} {
    poke:update_pokemon $trainer $pokedet add "skybound"
    poke:movetemplate:charge $move $trainer $pokedet $otrainer $opokedet "bounced up!"
    return 0
  } else {
    lassign [poke:movetemplate:default $move $trainer $pokedet $otrainer $opokedet] faint dmg
    return $faint
  }
}

# 341 Mud Shot
proc poke:move:mudshot {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "Spd -1"] 100 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Mud Shot" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 342 Poison Tail
proc poke:move:poisontail {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list PSN] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"] - pokedet
  lassign [poke:movetemplate:default "Poison Tail" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
  return $faint
}

# 343 Covet
proc poke:move:covet {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Covet" $trainer $pokedet $otrainer $opokedet] faint dmg
  array set pokemon $pokedet
  array set opokemon $opokedet
  
  if {$pokemon(item) eq "" && $opokemon(item) ne "" && $opokemon(ability) ne "Sticky Hold"} {
    foreach a [split $opokemon(item) ""] b [split $opokemon(species) ""] {
      if {$a eq $b} {incr match} else {break}
    }
    if {($opokemon(ability) eq "Multitype" && [string match {*Plate} $opokemon(item)]) || 
      ([string match "Giratina*" $opokemon(species)] && $opokemon(item) eq "Griseous Orb") ||
      ([regexp -- {\S+ite} $item] && $match > 4)
    } {
      # Cannot be stolen
    } else {
      poke:update_pokemon $trainer $pokedet item $opokemon(item)
      poke:update_pokemon $trainer $pokedet oitem $opokemon(item)
      poke:update_pokemon $otrainer $opokedet item ""
      poke:update_pokemon $otrainer $opokedet oitem ""
      poke:message customself - $trainer $pokedet $otrainer $opokedet - 0 "stole $opokemon(item) from its opponent"
    }
  }
  return $faint
}

# 344 Volt Tackle
proc poke:move:volttackle {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list PAR] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Volt Tackle" $trainer $pokedet $otrainer $opokedet] faint dmg
  if {$faint != 2} {
    set dmg [expr {int($dmg/3.0)}]
    poke:movetemplate:recoil $trainer $pokedet $otrainer $opokedet $dmg "suffers $dmg of recoil"
  }
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 345 Magical Leaf
proc poke:move:magicalleaf {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Magical Leaf" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 347 Calm Mind
proc poke:move:calmmind {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Calm Mind" $trainer $pokedet $otrainer $opokedet [list "SpA +1" "SpD +1"] self
  return 0
}

# 348 Leaf Blade
proc poke:move:leafblade {trainer pokedet otrainer opokedet} {
  lassign [poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"] - pokedet
  lassign [poke:movetemplate:default "Leaf Blade" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
  return $faint
}

# 349 Dragon Dance
proc poke:move:dragondance {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Dragon Dance" $trainer $pokedet $otrainer $opokedet [list "Atk +1" "Spd +1"] self
  return 0
}

# 350 Rock Blast
proc poke:move:rockblast {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:multi "Rock Blast" $trainer $pokedet $otrainer $opokedet]
}

# 351 Shock Wave
proc poke:move:shockwave {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Shock Wave" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 352 Water Pulse
proc poke:move:waterpulse {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "conf $test"] 20 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Water Pulse" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 353 Doom Desire
proc poke:move:doomdesire {trainer pokedet otrainer opokedet {charged 0}} {
  global poke
  set move "Doom Desire"
  if {$charged == 2} {
    poke:update_pokemon $trainer $pokedet status "add Crit -1"
    
    set table moveDetails$poke(gen)
    set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
    set flags [lassign $movedet id name type class pp bp acc prio eff contact]
    lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] dmgtype dmg crit
    if {$dmgtype in {"miss" "no effect"}} {
      poke:message timedfail $move $trainer $pokedet $otrainer $opokedet - 0
      return [list 2 $dmg]
    }
    set dmgtype [string map {{ } {}} $dmgtype]
    set faint [poke:message timed$dmgtype $move $trainer $pokedet $otrainer $opokedet $dmg 0]
    poke:update_pokemon $trainer $pokedet status "rem Crit"
    poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
    poke:trigger damage $otrainer $opokedet $trainer $pokedet
    return [list $faint $dmg]
  } else {
    array set pokemon $pokedet
    set trainerID [lsearch -index 0 $poke(team) $trainer]
    set pokeID [lsearch -regexp [lindex $poke(team) $trainerID 1] "\\yspecies \\{?$pokemon(species)\\y\\}?"]
    set opponentID [lsearch $poke(currentPoke) $otrainer]
    if {[lsearch -glob $poke(prio-9) "*poke:move:doomdesire $trainer*"] > -1} {
      poke:message fail $move $trainer $pokedet $otrainer $opokedet - 0
      return 0
    }
    if {$charged == 0} {
      poke:message use $move $trainer $pokedet $otrainer $opokedet - 0
      poke:message customself - $trainer $pokedet $otrainer $opokedet - 0 "foresaw an attack"
      poke:trigger launch $otrainer $opokedet $trainer $pokedet
      set ppdown 1
      array set opokemon $opokedet
      if {$opokemon(ability) eq "Pressure"} {incr ppdown}
      poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
    }
    incr charged
    lappend poke(pending) [list -9 $pokemon(Spd) "poke:move:[string tolower [join $move {}]]" $trainer $pokemon(species) $trainerID $pokeID $opponentID $charged]
  }
}

# 354 Psycho Boost
proc poke:move:psychoboost {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "SpA -2"] 100 self 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Psycho Boost" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 355 Roost
proc poke:move:roost {trainer pokedet otrainer opokedet} {
  global poke
  poke:message use "Roost" $trainer $pokedet $otrainer $opokedet - 0
  poke:movetemplate:heal "Roost" $trainer $pokedet $otrainer $opokedet {$pokemon(HP)/2} 1
  array set pokemon $pokedet
  regsub {/Flying|Flying/?} $pokemon(type) "" type
  if {$type eq ""} {set type "Normal"}
  poke:update_pokemon $trainer $pokedet type $type
  lappend poke(prio-8) [list 0 poke:update_pokemon $trainer $pokedet type $pokemon(otype)]
  return 0
}

# 358 Wake-Up Slap
proc poke:move:wake-upslap {trainer pokedet otrainer opokedet {focused ""}} {
  global poke
  array set opokemon $opokedet
  set add ""
  if {"SLP" in $opokemon(status)} {
    set add [list bp 140]
  }
  lassign [poke:movetemplate:default "Wake-Up Slap" $trainer $pokedet $otrainer $opokedet $add] faint dmg
  if {$faint == 0 && $add != ""} {
    poke:update_pokemon $otrainer $opokedet status "rem SLP"
    poke:message custom - $trainer $pokedet $otrainer $opokedet - 0 "woke up!"
  }
  return $faint
}

# 359 Hammer Arm
proc poke:move:hammerarm {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "Spd -1"] 100 self 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Hammer Arm" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 360 Gyro Ball
proc poke:move:gyroball {trainer pokedet otrainer opokedet} {
  array set pokemon $pokedet
  array set opokemon $opokedet
  # To add Spd modifiers such as paralysis, iron ball, tail wind, etc
  set ofinalspd [expr {$opokemon(Spd)*[poke:boost $opokemon(status) "Spd"]}]
  set finalspd [expr {$pokemon(Spd)*[poke:boost $pokemon(status) "Spd"]}]
  set bp [expr {1+25*($ofinalspd/$finalspd)}]
  if {$bp > 150} {set bp 150}
  lassign [poke:movetemplate:default "Gyro Ball" $trainer $pokedet $otrainer $opokedet [list bp $bp]] faint dmg
  return $faint
}

# 362 Brine
proc poke:move:hammerarm {trainer pokedet otrainer opokedet} {
  set extra [list]
  array set opokemon $opokedet
  if {$opokemon(cHP) < [expr {int($opokemon(HP)/2)}]} {
    lappend extra bp 130
  }
  lassign [poke:movetemplate:default "Brine" $trainer $pokedet $otrainer $opokedet $extra] faint dmg
  return $faint
}

# 364 Feint
proc poke:move:feint {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Feint" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 365 Pluck
proc poke:move:pluck {trainer pokedet otrainer opokedet} {
  array set opokemon $opokedet
  set extra ""
  if {[string match "* Berry" $opokemon(item)]} {
    lappend extra bp 120
    # poke:berry ;# use the berry
  }
  lassign [poke:movetemplate:default "Pluck" $trainer $pokedet $otrainer $opokedet $extra] faint dmg
  return $faint
}

# 367 Acupressure
proc poke:move:acupressure {trainer pokedet otrainer opokedet} {
  set stats [list Atk Def SpA SpD Spd Acc Eva]
  poke:random
  set stat [lindex $stats [rand 7]]
  poke:movetemplate:stats "Acupressure" $trainer $pokedet $otrainer $opokedet [list "Atk +2"] self
  return 0
}

# 368 Metal Burst
proc poke:move:metalburst {trainer pokedet otrainer opokedet} {
  global poke
  set msgs [lsearch -all -inline -index 0 $poke(log) $poke(turn)]
  set dmg [lsearch -inline -index 1 -regexp $msgs {\S+?'s \S+ used .*?! .* suffered \d+ damage!}]
  if {$dmg eq ""} {
    poke:message fail "Metal Burst" $trainer $pokedet $otrainer $opokedet - 0
    return 0
  }
  regexp {\S+?'s \S+ used (.*?)! .* suffered (\d+) damage!} $dmg - move dmg
  
  set dmg [expr {int($dmg*1.5)}]
  lassign [poke:movetemplate:default "Metal Burst" $trainer $pokedet $otrainer $opokedet [list dmg $dmg]] faint dmg
  return $faint
}

# 369 U-Turn
proc poke:move:u-turn {trainer pokedet otrainer opokedet} {
  global poke
  array set pokemon $pokedet
  set status $pokemon(status)
  lappend poke(switch) [list $trainer $pokemon(species) battle]
  lassign [poke:movetemplate:default "U-Turn" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:movetemplate:forceswitch "U-Turn" $trainer $pokedet $otrainer $opokedet 0 0
  if {$faint} {lappend poke(prio0) [list 9999 poke:faint $otrainer]}
  return 2
}

# 370 Close Combat
proc poke:move:closecombat {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "Def -1" "SpD -1"] 100 self 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Close Combat" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 371 Payback
proc poke:move:payback {trainer pokedet otrainer opokedet} {
  global poke
  set priorities [lsort -integer -decreasing [lmap x [array names poke -glob prio*] {set x [string map {prio {}} $x]}]]
  set extra ""
  set found 0
  foreach i $priorities {
    lassign $i procedure nick pokemon
    if {$otrainer eq $nick && [string match "proc:move:*" $procedure]} {
      set found 1
      break
    }
  }
  if {!$found} {
    lappend extra bp 100
  }
  lassign [poke:movetemplate:default "Payback" $trainer $pokedet $otrainer $opokedet $extra] faint dmg
  return $faint
}

# 372 Assurance
proc poke:move:assurance {trainer pokedet otrainer opokedet} {
  global poke
  set extra ""
  if {0} {
    lappend extra bp 100
  }
  lassign [poke:movetemplate:default "Assurance" $trainer $pokedet $otrainer $opokedet $extra] faint dmg
  return $faint
}

# 376 Trump Card
proc poke:move:trumpcard {trainer pokedet otrainer opokedet} {
  array set pokemon $pokedet
  array set opokemon $opokedet
  foreach i {1 2 3 4} {
    if {$pokemon(Move$i) eq "Trump Card"} {
      set pp [lindex $pokemon(Move$i) 1]
      break
    }
  }
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  set left [expr {$pp-$ppdown}]
  switch $left {
    0 {set bp 200}
    1 {set bp 80}
    2 {set bp 60}
    3 {set bp 50}
    default {set bp 40}
  }
  lassign [poke:movetemplate:default "Trump Card" $trainer $pokedet $otrainer $opokedet [list bp $bp]] faint dmg
  return $faint
}

# 378 Wring Out
proc poke:move:wringout {trainer pokedet otrainer opokedet} {
  array set opokemon $opokedet
  set bp [expr {1+120*($opokemon(cHP)/$opokemon(HP))}]
  lassign [poke:movetemplate:default "Wring Out" $trainer $pokedet $otrainer $opokedet [list bp $bp]] faint dmg
  return $faint
}

# 386 Punishment
proc poke:move:punishment {trainer pokedet otrainer opokedet} {
  array set opokemon $opokedet
  set ups 0
  foreach stat $opokemon(status) {
    if {[regexp {(?:Atk|Def|Sp[dAD]) \+(\d)} $stat - amt]} {
      incr ups $amt
    }
  }
  set bp [expr {60+20*$ups}]
  if {$bp > 200} {set bp 200}
  lassign [poke:movetemplate:default "Punishment" $trainer $pokedet $otrainer $opokedet [list bp $bp]] faint dmg
  return $faint
}

# 387 Last Resort
proc poke:move:lastresort {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Last Resort" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 389 Sucker Punch
proc poke:move:suckerpunch {trainer pokedet otrainer opokedet} {
  global poke
  set priorities [lsort -integer -decreasing [lmap x [array names poke -glob prio*] {set x [string map {prio {}} $x]}]]
  set extra ""
  set found 0
  foreach i $priorities {
    lassign $i procedure nick pokemon
    if {$otrainer eq $nick && [string match "proc:move:*" $procedure]} {
      set found 1
      set table moveDetails$poke(gen)
      set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
      lassign $movedet - - - - - bp
      break
    }
  }
  if {$found && $bp ne "-"} {
    lassign [poke:movetemplate:default "Sucker Punch" $trainer $pokedet $otrainer $opokedet] faint dmg
    return $faint
  } else {
    poke:message fail "Sucker Punch" $trainer $pokedet $otrainer $opokedet - 0
    return 0
  }
  
}

# 392 Force Palm
proc poke:move:forcepalm {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list PAR] 30 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Force Palm" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 394 Flare Blitz
proc poke:move:flareblitz {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list BRN] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Flare Blitz" $trainer $pokedet $otrainer $opokedet] faint dmg
  if {$faint != 2} {
    set dmg [expr {int($dmg/3.0)}]
    poke:movetemplate:recoil $trainer $pokedet $otrainer $opokedet $dmg "suffers $dmg of recoil"
  }
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 396 Aura Sphere
proc poke:move:aurasphere {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Aura Sphere" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 397 Rock Polish
proc poke:move:rockpolish {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Rock Polish" $trainer $pokedet $otrainer $opokedet [list "Spd +2"] self
  return 0
}

# 398 Poison Jab
proc poke:move:poisonjab {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "PSN"] 30 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Poison Jab" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 399 Dark Pulse
proc poke:move:darkpulse {trainer pokedet otrainer opokedet} {
  global poke
  lassign [poke:movetemplate:default "Dark Pulse" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:random
  set test [rand 100]
  if {$test < 20} {
    poke:flinch $otrainer $opokedet 0
  }
  return $faint
}

# 400 Night Slash
proc poke:move:nightslash {trainer pokedet otrainer opokedet} {
  lassign [poke:update_pokemon $trainer $pokedet status "add tempCrit 1"] - pokedet
  lassign [poke:movetemplate:default "Night Slash" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:update_pokemon $trainer $pokedet status "rem tempCrit -1"
  return $faint
}

# 401 Aqua Tail
proc poke:move:aquatail {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Aqua Tail" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 402 Seed Bomb
proc poke:move:seedbomb {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Seed Bomb" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 403 Air Slash
proc poke:move:airslash {trainer pokedet otrainer opokedet} {
  global poke
  lassign [poke:movetemplate:default "Air Slash" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:random
  set test [rand 100]
  if {$test < 30} {
    poke:flinch $otrainer $opokedet 0
  }
  return $faint
}

# 404 X-Scissor
proc poke:move:x-scissor {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "X-Scissor" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 405 Bug Buzz
proc poke:move:bugbuzz {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "SpD -1"] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Bug Buzz" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 406 Dragon Pulse
proc poke:move:dragonpulse {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Dragon Pulse" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 407 Dragon Rush
proc poke:move:dragonrush {trainer pokedet otrainer opokedet} {
  global poke
  lassign [poke:movetemplate:default "Dragon Rush" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:random
  set test [rand 100]
  if {$test < 20} {
    poke:flinch $otrainer $opokedet 0
  }
  return $faint
}

# 408 Power Gem
proc poke:move:powergem {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Power Gem" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 409 Drain Punch
proc poke:move:drainpunch {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Drain Punch" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:movetemplate:heal "" $trainer $pokedet $otrainer $opokedet "$dmg/2" 0
  return $faint
}

# 410 Vacuum Wave
proc poke:move:vacuumwave {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Vacuum Wave" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 411 Focus Blast
proc poke:move:focusblast {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "SpD -1"] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Focus Blast" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 412 Energy Ball
proc poke:move:energyball {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "SpD -1"] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Energy Ball" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 413 Brave Bird
proc poke:move:bravebird {trainer pokedet otrainer opokedet} {
  global poke
  lassign [poke:movetemplate:default "Brave Bird" $trainer $pokedet $otrainer $opokedet] faint dmg
  if {$faint != 2} {
    set dmg [expr {int($dmg/3.0)}]
    poke:movetemplate:recoil $trainer $pokedet $otrainer $opokedet $dmg "suffers $dmg of recoil"
  }
  return $faint
}

# 414 Earth Power
proc poke:move:earthpower {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "SpD -1"] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Earth Power" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 415 Switcheroo
proc poke:move:switcheroo {trainer pokedet otrainer opokedet {focused ""}} {
  array set pokemon $pokedet
  array set opokemon $opokedet
  if {($pokemon(item) ne "" && $opokemon(item) ne "") && $opokemon(ability) ne "Sticky Hold"} {
    foreach a [split $opokemon(item) ""] b [split $opokemon(species) ""] {
      if {$a eq $b} {incr match} else {break}
    }
    if {($opokemon(ability) eq "Multitype" && [string match {*Plate} $opokemon(item)]) || 
      ([string match "Giratina*" $opokemon(species)] && $opokemon(item) eq "Griseous Orb") ||
      ([regexp -- {\S+ite} $item] && $match > 4)
    } {
      # Cannot be stolen
    } else {
      poke:update_pokemon $trainer $pokedet item $opokemon(item)
      poke:update_pokemon $otrainer $opokedet item $pokemon(item)
      poke:update_pokemon $trainer $pokedet oitem $opokemon(item)
      poke:update_pokemon $otrainer $opokedet oitem $pokemon(item)
      poke:message use "Switcheroo" $trainer $pokedet $otrainer $opokedet - 0
      poke:message customself - $trainer $pokedet $otrainer $opokedet - 0 "swapped items with its opponent"
    }
  } else {
    poke:message fail "Switcheroo" $trainer $pokedet $otrainer $opokedet - 0
  }
  return 0
}

# 416 Giga Impact
proc poke:move:gigaimpact {trainer pokedet otrainer opokedet {recharging 0}} {
  global poke
  lassign [poke:movetemplate:default "Giga Impact" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:movetemplate:recharge $trainer $pokedet $otrainer $opokedet
  return $faint
}

# 417 Nasty Plot
proc poke:move:natyplot {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Nasty Plot" $trainer $pokedet $otrainer $opokedet [list "SpA +2"] self
  return 0
}

# 418 Bullet Punch
proc poke:move:bulletpunch {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Bullet Punch" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 419 Avalanche
proc poke:move:metalburst {trainer pokedet otrainer opokedet} {
  global poke
  set msgs [lsearch -all -inline -index 0 $poke(log) $poke(turn)]
  set dmg [lsearch -inline -index 1 -regexp $msgs {\S+?'s \S+ used .*?! .* suffered \d+ damage!}]
  if {$dmg eq ""} {
    poke:message fail "Avalanche" $trainer $pokedet $otrainer $opokedet - 0
    return 0
  }
  regexp {\S+?'s \S+ used (.*?)! .* suffered (\d+) damage!} $dmg - move dmg
  
  set dmg [expr {$dmg*2}]
  lassign [poke:movetemplate:default "Avalanche" $trainer $pokedet $otrainer $opokedet [list dmg $dmg]] faint dmg
  return $faint
}

# 420 Ice Shard
proc poke:move:iceshard {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Ice Shard" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 421 Shadow Claw
proc poke:move:shadowclaw {trainer pokedet otrainer opokedet} {
  lassign [poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"] - pokedet
  lassign [poke:movetemplate:default "Shadow Claw" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
  return $faint
}

# 422 Thunder Fang
proc poke:move:lick {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list PAR] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Thunder Fang" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]

  poke:random
  set test [rand 100]
  if {$test < 10} {
    poke:flinch $otrainer $opokedet 0
  }
  return $faint
}

# 423 Ice Fang
proc poke:move:icefang {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list FRZ] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Ice Fang" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
 
  poke:random
  set test [rand 100]
  if {$test < 10} {
    poke:flinch $otrainer $opokedet 0
  }
  return $faint
}

# 424 Fire Fang
proc poke:move:firefang {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list BRN] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Fire Fang" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  poke:random
  set test [rand 100]
  if {$test < 10} {
    poke:flinch $otrainer $opokedet 0
  }
  return $faint
}

# 425 Shadow Sneak
proc poke:move:shadowsneak {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Shadow Sneak" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 427 Psycho Cut
proc poke:move:psychocut {trainer pokedet otrainer opokedet} {
  lassign [poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"] - pokedet
  lassign [poke:movetemplate:default "Psycho Cut" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
  return $faint
}

# 426 Mud Bomb
proc poke:move:mudbomb {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "Acc -1"] 30 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Mud Bomb" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 428 Zen Headbutt
proc poke:move:zenheadbutt {trainer pokedet otrainer opokedet} {
  global poke
  lassign [poke:movetemplate:default "Zen Headbutt" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:random
  set test [rand 100]
  if {$test < 20} {
    poke:flinch $otrainer $opokedet 0
  }
  return $faint
}

# 429 Mirror Shot
proc poke:move:mirrorshot {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "Acc -1"] 30 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Mirror Shot" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 430 Flash Cannon
proc poke:move:flashcannon {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "SpD -1"] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Flash Cannon" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 431 Rock Climb
proc poke:move:rockclimb {trainer pokedet otrainer opokedet} {
  global poke
  poke:random
  set test [rand 4]
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "conf $test"] 20 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Rock Climb" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 432 Defog
proc poke:move:defog {trainer pokedet otrainer opokedet} {
  global poke
  poke:movetemplate:stats "Defog" $trainer $pokedet $otrainer $opokedet [list "Eva -1"] op
  #remove hazards & opponent field stuff
  return 0
}

# 434 Draco Meteor
proc poke:move:dracometeor {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "SpA -2"] 100 self 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Draco Meteor" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 436 Lava Plume
proc poke:move:lavaplume {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list BRN] 30 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Lava Plume" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 437 Leaf Storm
proc poke:move:leafstorm {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "SpA -2"] 100 self 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Leaf Storm" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 438 Power Whip
proc poke:move:powerwhip {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Power Whip" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 439 Rock Wrecker
proc poke:move:rockwrecker {trainer pokedet otrainer opokedet {recharging 0}} {
  global poke
  lassign [poke:movetemplate:default "Rock Wrecker" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:movetemplate:recharge $trainer $pokedet $otrainer $opokedet
  return $faint
}

# 440 Cross Poison
proc poke:move:crosspoison {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list PSN] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"] - pokedet
  lassign [poke:movetemplate:default "Cross Poison" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
  return $faint
}

# 441 Gunk Shot
proc poke:move:gunkshot {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list PSN] 30 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Gunk Shot" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 442 Iron Head
proc poke:move:ironhead {trainer pokedet otrainer opokedet} {
  global poke
  lassign [poke:movetemplate:default "Iron Head" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:random
  set test [rand 100]
  if {$test < 30} {
    poke:flinch $otrainer $opokedet 0
  }
  return $faint
}

# 443 Magnet Bomb
proc poke:move:magnetbomb {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Magnet Bomb" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 444 Stone Edge
proc poke:move:stoneedge {trainer pokedet otrainer opokedet} {
  lassign [poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"] - pokedet
  lassign [poke:movetemplate:default "Stone Edge" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
  return $faint
}

# 445 Captivate
proc poke:move:captivate {trainer pokedet otrainer opokedet} {
  array set pokemon $pokedet
  array set opokemon $opokedet
  set idx [lsearch {NA M F} $pokemon(gender)]
  set oidx [lsearch {NA M F} $opokemon(gender)]
  if {[expr {$idx + $oidx}] == 3} {
    poke:movetemplate:stats "Captivate" $trainer $pokedet $otrainer $opokedet [list "SpA -2"] op
  } else {
    poke:message fail "Captivate" $trainer $pokedet $otrainer $opokedet - 0
  }
  return 0
}

# 447 Grass Knot
proc poke:move:grassknot {trainer pokedet otrainer opokedet} {
  global poke
  array set opokemon $opokedet
  set table pokeDetails $poke(gen)
  set weight [dex eval "SELECT weight FROM $table WHERE formname = '$opokemon(species)'"]
  if {$weight <= 10} {
    set bp 20
  } elseif {$weight <= 25} {
    set bp 40
  } elseif {$weight <= 50} {
    set bp 60
  } elseif {$weight <= 100} {
    set bp 80
  } elseif {$weight <= 200} {
    set bp 100
  } else {
    set bp 120
  }
  lassign [poke:movetemplate:default "Grass Knot" $trainer $pokedet $otrainer $opokedet [list dp $bp] faint dmg
  return $faint
}

# 448 Chatter
proc poke:move:chatter {trainer pokedet otrainer opokedet} {
  global poke
  poke:random
  set test [rand 4]
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "conf $test"] 30 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Chatter" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 450 Bug Bite
proc poke:move:bugbite {trainer pokedet otrainer opokedet} {
  global poke
  array set opokemon $opokedet
  set bp 60
  if {[string match -nocase "* Berry" $opokemon(item)]} {
    set effect [list damage poke:update_pokemon $otrainer $opokedet item ""]
    lappend poke(triggers) $effect
    set bp 120
    # use berry
  }
  lassign [poke:movetemplate:default "Bug Bite" $trainer $pokedet $otrainer $opokedet [list bp $bp]] faint dmg
  if {[string match -nocase "" $opokemon(item)]} {
    set poke(triggers) [lreplace $poke(triggers) end end]
  }
  return $faint
}

# 451 Charge Beam
proc poke:move:chargebeam {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "SpA +1"] 70 self 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Charge Beam" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 452 Wood Hammer
proc poke:move:woodhammer {trainer pokedet otrainer opokedet} {
  global poke
  lassign [poke:movetemplate:default "Wood Hammer" $trainer $pokedet $otrainer $opokedet] faint dmg
  if {$faint != 2} {
    set dmg [expr {int($dmg/3.0)}]
    poke:movetemplate:recoil $trainer $pokedet $otrainer $opokedet $dmg "suffers $dmg of recoil"
  }
  return $faint
}

# 453 Aqua Jet
proc poke:move:aquajet {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Aqua Jet" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 454 Attack Order
proc poke:move:attackorder {trainer pokedet otrainer opokedet} {
  lassign [poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"] - pokedet
  lassign [poke:movetemplate:default "Attack Order" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
  return $faint
}

# 455 Defend Order
proc poke:move:defendorder {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Defend Order" $trainer $pokedet $otrainer $opokedet [list "Def +1" "SpD +1"] self
  return 0
}

# 456 Heal Order
proc poke:move:healorder {trainer pokedet otrainer opokedet} {
  poke:message use "Heal Order" $trainer $pokedet $otrainer $opokedet - 0
  poke:movetemplate:heal "Heal Order" $trainer $pokedet $otrainer $opokedet {$pokemon(HP)/2} 1
  return 0
}

# 457 Head Smash
proc poke:move:headsmash {trainer pokedet otrainer opokedet} {
  global poke
  lassign [poke:movetemplate:default "Head Smash" $trainer $pokedet $otrainer $opokedet] faint dmg
  if {$faint != 2} {
    set dmg [expr {int($dmg/2.0)}]
    poke:movetemplate:recoil $trainer $pokedet $otrainer $opokedet $dmg "suffers $dmg of recoil"
  }
  return $faint
}

# 458 Double Hit
proc poke:move:doublehjit {trainer pokedet otrainer opokedet} {
  global poke
  set faint [poke:movetemplate:multi "Double Hit" $trainer $pokedet $otrainer $opokedet 2]
  return $faint 
}

# 459 Roar of Time
proc poke:move:roaroftime {trainer pokedet otrainer opokedet {recharging 0}} {
  global poke
  lassign [poke:movetemplate:default "Roar of Time" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:movetemplate:recharge $trainer $pokedet $otrainer $opokedet
  return $faint
}

# 460 Spacial Rend
proc poke:move:spacialrend {trainer pokedet otrainer opokedet} {
  lassign [poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"] - pokedet
  lassign [poke:movetemplate:default "Spacial Rend" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
  return $faint
}

# 462 Crush Grip
proc poke:move:crushgrip {trainer pokedet otrainer opokedet} {
  array set opokemon $opokedet
  set bp [expr {1+120*($opokemon(cHP)/$opokemon(HP))}]
  lassign [poke:movetemplate:default "Crush Grip" $trainer $pokedet $otrainer $opokedet [list bp $bp]] faint dmg
  return $faint
}

# 463 Magma Storm
proc poke:move:magmastorm {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:trap "Magma Storm" $trainer $pokedet $otrainer $opokedet]
}

# 464 Dark Void
proc poke:move:darkvoid {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Dark Void" $trainer $pokedet $otrainer $opokedet [list SLP] op
  return 0
}

# 465 Seed Flare
proc poke:move:seedflare {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "SpD -2"] 40 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Seed Flare" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 466 Ominous Wind
proc poke:move:ominouswind {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "Atk +1" "Def +1" "SpA +1" "SpD +1" "Spd +1"] 10 self 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Ominous Wind" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 467 Shadow Force
proc poke:move:shadowforce {trainer pokedet otrainer opokedet {charged 1}} {
  global poke
  set move "Shadow Force"
  if {$charged} {
    poke:update_pokemon $trainer $pokedet add "dimensionbound"
    poke:movetemplate:charge $move $trainer $pokedet $otrainer $opokedet "vanished"
    return 0
  } else {
    lassign [poke:movetemplate:default $move $trainer $pokedet $otrainer $opokedet] faint dmg
    return $faint
  }
}

# 468 Hone Claws
proc poke:move:honeclaws {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Hone Claws" $trainer $pokedet $otrainer $opokedet [list "Atk +1" "Acc +1"] self
  return 0
}

# 474 Venoshock
proc poke:move:venoshock {trainer pokedet otrainer opokedet} {
  array set opokemon $opokedet
  if {PSN in $opokemon(status) || BPSN in $opokemon(status)} {
    set bp 130
  } else {
    set bp 65
  }
  lassign [poke:movetemplate:default "Venoshock" $trainer $pokedet $otrainer $opokedet [list bp $bp] faint dmg
  return $faint
}

# 475 Autotomize
proc poke:move:autotomize {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Autotomize" $trainer $pokedet $otrainer $opokedet [list "Spd +1"] self
  # poke:update_pokemon half weight
  return 0
}

# 479 Smack Down
proc poke:move:smackdown {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Smack Down" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:update_status $otrainer $opokemon status "add grounded"
  return $faint
}

# 481 Flame Burst
proc poke:move:flameburst {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Flame Burst" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 482 Sludge Wave
proc poke:move:sludgewave {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list PSN] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Sludge Wave" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 483 Quiver Dance
proc poke:move:quiverdance {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Quiver Dance" $trainer $pokedet $otrainer $opokedet [list "SpA +1" "SpD +1" "Spd +1"] self
  return 0
}

# 484 Heavy Slam
proc poke:move:heavyslam {trainer pokedet otrainer opokedet} {
  global poke
  array set pokemon $pokedet
  array set opokemon $opokedet
  set table pokeDetails $poke(gen)
  set weight [dex eval "SELECT weight FROM $table WHERE formname = '$pokemon(species)'"]
  set oweight [dex eval "SELECT weight FROM $table WHERE formname = '$opokemon(species)'"]
  set multiple [expr {$weight/double($oweight)}]
  if {$multiple <= 2} {
    set bp 40
  } elseif {$weight <= 3} {
    set bp 60
  } elseif {$weight <= 4} {
    set bp 80
  } elseif {$weight <= 5} {
    set bp 100
  } else {
    set bp 120
  }
  lassign [poke:movetemplate:default "Heavy Slam" $trainer $pokedet $otrainer $opokedet [list dp $bp] faint dmg
  return $faint
}

# 486 Electro Ball
proc poke:move:electroball {trainer pokedet otrainer opokedet} {
  array set pokemon $pokedet
  array set opokemon $opokedet
  # To add Spd modifiers such as paralysis, iron ball, tail wind, etc
  set ofinalspd [expr {$opokemon(Spd)*[poke:boost $opokemon(status) "Spd"]}]
  set finalspd [expr {$pokemon(Spd)*[poke:boost $pokemon(status) "Spd"]}]
  set factor [expr {$finalspd/$ofinalspd}]
  if {$factor <= 2} {
    set bp 60
  } elseif {$factor <= 3} {
    set bp 80
  } elseif {$factor <= 4} {
    set bp 120
  } else {
    set bp 150
  }
  lassign [poke:movetemplate:default "Electro Ball" $trainer $pokedet $otrainer $opokedet [list bp $bp]] faint dmg
  return $faint
}

# 488 Flame Charge
proc poke:move:flamecharge {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "Spd +1"] 100 self 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Flame Charge" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 489 Coil
proc poke:move:coil {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Coil" $trainer $pokedet $otrainer $opokedet [list "Atk +1" "Def +1" "Acc +1"] self
  return 0
}

# 490 Low Sweep
proc poke:move:lowsweep {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "Spd -1"] 100 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Low Sweep" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 491 Acid Spray
proc poke:move:acidspray {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "SpD -2"] 100 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Acid Spray" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 492 Foul Play
proc poke:move:foulplay {trainer pokedet otrainer opokedet} {
  array set opokemon $opokedet
  array set pokemon $pokedet
  set pokemon(Atk) $opokemon(Atk)
  foreach stat $opokedet(status) {
    if {[string match "Atk *" $stat]} {
      set idx [lsearch -index 0 $pokemon(status) "Atk"]
      if {$idx == -1} {
        lappend pokemon(status) $stat
      } else {
        set pokemon(status) [lreplace $pokemon(status) $idx $idx $stat]
      }
      break
    }
  }
  lassign [poke:movetemplate:default "Foul Play" $trainer [array get pokemon] $otrainer $opokedet] faint dmg
  return $faint
}

# 498 Chip Away
proc poke:move:chipaway {trainer pokedet otrainer opokedet} {
  array set opokemon $opokedet
  set stats [list]
  foreach stat $opokedet(status) {
    if {[string match "Def *" $stat] || [string match "Eva *" $stat]} {
      continue
    } else {
      lappend stats $stat
    }
  }
  set opokemon(status) $stats
  lassign [poke:movetemplate:default "Chip Away" $trainer $pokedet $otrainer [array get $opokemon] faint dmg
  return $faint
}

# 499 Clear Smog
proc poke:move:clearsmog {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Clear Smog" $trainer $pokedet $otrainer $opokedet faint dmg
  array set opokemon $opokedet
  set stats [list]
  foreach stat $opokedet(status) {
    if {[regexp {(?:Atk|Def|Sp[ADd])} $stat]} {
      continue
    } else {
      lappend stats $stat
    }
  }
  poke:update_pokemon $otrainer $opokedet status $stats
  return $faint
}

# 503 Scald
proc poke:move:scald {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list BRN] 30 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Scald" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 504 Shell Smash
proc poke:move:shellsmash {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Shell Smash" $trainer $pokedet $otrainer $opokedet [list "Atk +2" "SpA +2" "Spd +2" "Def -2" "SpD -2"] self
  return 0
}

# 505 Heal Pulse
proc poke:move:healpulse {trainer pokedet otrainer opokedet} {
  poke:message use "Heal Pulse" $trainer $pokedet $otrainer $opokedet - 0
  poke:movetemplate:heal "Heal Pulse" $trainer $pokedet $otrainer $opokedet {$pokemon(HP)*0.75} 1 0
  return 0
}

# 508 Shift Gear
proc poke:move:shiftgear {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Shift Gear" $trainer $pokedet $otrainer $opokedet [list "Atk +1" "Spd +2"] self
  return 0
}

# 509 Circle Throw
proc poke:move:circlethrow {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Circle Throw" $trainer $pokedet $otrainer $opokedet] faint dmg
  if {$faint != 2} {
    poke:movetemplate:forceswitch "Circle Throw" $trainer $pokedet $otrainer $opokedet $dmg
  }
  return $faint
}

# 510 Incinerate
proc poke:move:incinerate {trainer pokedet otrainer opokedet} {
  global poke
  array set opokemon $opokedet
  if {[string match -nocase "* Berry" $opokemon(item)]} {
    set effect [list damage poke:update_pokemon $otrainer $opokedet item ""]
    lappend poke(triggers) $effect
  }
  lassign [poke:movetemplate:default "Incinerate" $trainer $pokedet $otrainer $opokedet] faint dmg
  if {[string match -nocase "" $opokemon(item)]} {
    set poke(triggers) [lreplace $poke(triggers) end end]
  }
  return $faint
}

# 512 Acrobatics
proc poke:move:acrobatics {trainer pokedet otrainer opokedet} {
  global poke
  array set pokemon $pokedet
  set table itemDetails$poke(gen)
  #set trigger [dex eval "SELECT trigger FROM $table WHERE name"]
  set trigger ""
  set bp 55
  if {$trigger eq "flying move" || $pokemon(item) eq ""} {
    set bp 110
  }
  lassign [poke:movetemplate:default "Acrobatics" $trainer $pokedet $otrainer $opokedet [list bp $bp]] faint dmg
  return $faint
}

# 515 Final Gambit
proc poke:move:finalgambit {trainer pokedet otrainer opokedet} {
  global poke
  array set pokemon $pokedet
  lassign [poke:movetemplate:default "Final Gambit" $trainer $pokedet $otrainer $opokedet [list dmg $pokemon(cHP)]] faint dmg
  set double 0
  if {$dmg > 0} {
    poke:update_pokemon $trainer $pokedet cHP 0
    poke:message kamikaze "" $trainer $pokedet $otrainer $opokedet - 0
    lappend poke(prio-10) [list 0 poke:faint $trainer]
    lappend poke(switch) [list $trainer $pokemon(species)]
  }
  return $faint
}

# 517 Inferno
proc poke:move:inferno {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list BRN] 100 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Inferno" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 521 Volt Switch
proc poke:move:voltswitch {trainer pokedet otrainer opokedet} {
  global poke
  array set pokemon $pokedet
  set status $pokemon(status)
  lappend poke(switch) [list $trainer $pokemon(species) battle]
  lassign [poke:movetemplate:default "Volt Switch" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:movetemplate:forceswitch "Volt Switch" $trainer $pokedet $otrainer $opokedet 0 0
  if {$faint} {lappend poke(prio0) [list 9999 poke:faint $otrainer]}
  return 2
}

# 522 Struggle Bug
proc poke:move:strugglebug {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "SpA -1"] 100 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Struggle Bug" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 523 Bulldoze
proc poke:move:bulldoze {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "Spd -1"] 100 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Bulldoze" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 525 Dragon Tail
proc poke:move:dragontail {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Dragon Tail" $trainer $pokedet $otrainer $opokedet] faint dmg
  if {$faint != 2} {
    poke:movetemplate:forceswitch "Dragon Tail" $trainer $pokedet $otrainer $opokedet $dmg
  }
  return $faint
}

# 526 Work Up
proc poke:move:workup {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Work Up" $trainer $pokedet $otrainer $opokedet [list "Atk +1" "SpA +1"] self
  return 0
}

# 527 Electroweb
proc poke:move:electroweb {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "Spd -1"] 100 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Electroweb" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 528 Wild Charge
proc poke:move:wildcharge {trainer pokedet otrainer opokedet} {
  global poke
  lassign [poke:movetemplate:default "Wild Charge" $trainer $pokedet $otrainer $opokedet] faint dmg
  if {$faint != 2} {
    set dmg [expr {int($dmg/4.0)}]
    poke:movetemplate:recoil $trainer $pokedet $otrainer $opokedet $dmg "suffers $dmg of recoil"
  }
  return $faint
}

# 529 Drill Run
proc poke:move:drillrun {trainer pokedet otrainer opokedet} {
  lassign [poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"] - pokedet
  lassign [poke:movetemplate:default "Drill Run" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
  return $faint
}

# 530 Dual Chop
proc poke:move:dualchop {trainer pokedet otrainer opokedet} {
  global poke
  set faint [poke:movetemplate:multi "Dual Chop" $trainer $pokedet $otrainer $opokedet 2]
  return $faint 
}

# 531 Heart Stamp
proc poke:move:heartstamp {trainer pokedet otrainer opokedet} {
  global poke
  lassign [poke:movetemplate:default "Heart Stamp" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:random
  set test [rand 100]
  if {$test < 30} {
    poke:flinch $otrainer $opokedet 0
  }
  return $faint
}

# 532 Horn Leech
proc poke:move:hornleech {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Horn Leech" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:movetemplate:heal "" $trainer $pokedet $otrainer $opokedet "$dmg/2" 0
  return $faint
}

# 533 Sacred Sword
proc poke:move:sacredsword {trainer pokedet otrainer opokedet} {
  array set opokemon $opokedet
  set stats [list]
  foreach stat $opokedet(status) {
    if {[string match "Def *" $stat] || [string match "Eva *" $stat]} {
      continue
    } else {
      lappend stats $stat
    }
  }
  set opokemon(status) $stats
  lassign [poke:movetemplate:default "Sacred Sword" $trainer $pokedet $otrainer [array get $opokemon] faint dmg
  return $faint
}

# 534 Razor Shell
proc poke:move:razorshell {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "Def -1"] 50 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Razor Shell" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 535 Heat Crash
proc poke:move:heatcrash {trainer pokedet otrainer opokedet} {
  global poke
  array set pokemon $pokedet
  array set opokemon $opokedet
  set table pokeDetails $poke(gen)
  set weight [dex eval "SELECT weight FROM $table WHERE formname = '$pokemon(species)'"]
  set oweight [dex eval "SELECT weight FROM $table WHERE formname = '$opokemon(species)'"]
  set multiple [expr {$weight/double($oweight)}]
  if {$multiple <= 2} {
    set bp 40
  } elseif {$weight <= 3} {
    set bp 60
  } elseif {$weight <= 4} {
    set bp 80
  } elseif {$weight <= 5} {
    set bp 100
  } else {
    set bp 120
  }
  lassign [poke:movetemplate:default "Heat Crash" $trainer $pokedet $otrainer $opokedet [list dp $bp] faint dmg
  return $faint
}

# 536 Leaf Tornado
proc poke:move:leaftornado {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "Acc -1"] 50 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Leaf Tornado" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 537 Steamroller
proc poke:move:steamroller {trainer pokedet otrainer opokedet} {
  global poke
  lassign [poke:movetemplate:default "Steamroller" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:random
  set test [rand 100]
  if {$test < 30} {
    poke:flinch $otrainer $opokedet 0
  }
  return $faint
}

# 538 Cotton Guard
proc poke:move:cottonguard {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Cotton Guard" $trainer $pokedet $otrainer $opokedet [list "Def +3"] self
  return 0
}

# 539 Night Daze
proc poke:move:nightdaze {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "Acc -1"] 40 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Night Daze" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 541 Tail Slap
proc poke:move:tailslap {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:multi "Tail Slap" $trainer $pokedet $otrainer $opokedet]
}

# 542 Hurricane
proc poke:move:hurricane {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list PSN] 30 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Hurricane" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 543 Head Charge
proc poke:move:headcharge {trainer pokedet otrainer opokedet} {
  global poke
  lassign [poke:movetemplate:default "Head Charge" $trainer $pokedet $otrainer $opokedet] faint dmg
  if {$faint != 2} {
    set dmg [expr {int($dmg/4.0)}]
    poke:movetemplate:recoil $trainer $pokedet $otrainer $opokedet $dmg "suffers $dmg of recoil"
  }
  return $faint
}

# 544 Gear Grind
proc poke:move:geargrind {trainer pokedet otrainer opokedet} {
  set faint [poke:movetemplate:multi "Gear Grind" $trainer $pokedet $otrainer $opokedet 2]
  return $faint 
}

# 545 Searing Shot
proc poke:move:searingshot {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list BRN] 30 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Searing Shot" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 547 Relic Song
proc poke:move:relicsong {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list SLP] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Relic Song" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 549 Glaciate
proc poke:move:glaciate {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "Spd -1"] 100 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Glaciate" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 551 Blue Flare
proc poke:move:blueflare {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list BRN] 20 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Blue Flare" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 552 Fiery Dance
proc poke:move:fierydance {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "SpA +1"] 50 self 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Fiery Dance" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 554 Ice Burn
proc poke:move:iceburn {trainer pokedet otrainer opokedet {charged 1}} {
  global poke
  set move "Ice Burn"
  if {$charged} {
    poke:movetemplate:charge $move $trainer $pokedet $otrainer $opokedet
    return 0
  } else {
    set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list BRN] 30 op 0]
    lappend poke(triggers) $effect
    lassign [poke:movetemplate:default "Ice Burn" $trainer $pokedet $otrainer $opokedet] faint dmg
    set poke(triggers) [lreplace $poke(triggers) end end]
    return $faint
  }
}

# 555 Snarl
proc poke:move:snarl {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "SpA -1"] 100 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Snarl" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 556 Icicle Crash
proc poke:move:iciclecrash {trainer pokedet otrainer opokedet} {
  global poke
  lassign [poke:movetemplate:default "Icicle Crash" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:random
  set test [rand 100]
  if {$test < 30} {
    poke:flinch $otrainer $opokedet 0
  }
  return $faint
}

# 557 V-Create
proc poke:move:v-create {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "Def -1" "SpD -1" "Spd -1"] 100 self 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "V-Create" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 560 Flying Press
proc poke:move:flyingpress {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Flying Press" $trainer $pokedet $otrainer $opokedet [list type "Fighting/Flying"]] faint dmg
  return $faint
}

# 565 Fell Stinger
proc poke:move:fellstinger {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Fell Stinger" $trainer $pokedet $otrainer $opokedet] faint dmg
  if {$faint} {
    poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "Atk +2"] 100 self 0
  }
  return $faint
}

# 566 Phantom Force
proc poke:move:phantomforce {trainer pokedet otrainer opokedet {charged 1}} {
  global poke
  set move "Phantom Force"
  if {$charged} {
    poke:update_pokemon $trainer $pokedet add "dimensionbound"
    poke:movetemplate:charge $move $trainer $pokedet $otrainer $opokedet "vanished"
    return 0
  } else {
    lassign [poke:movetemplate:default $move $trainer $pokedet $otrainer $opokedet] faint dmg
    return $faint
  }
}

# 570 Parabolic Charge
proc poke:move:paraboliccharge {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Parabolic Charge" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:movetemplate:heal "" $trainer $pokedet $otrainer $opokedet "$dmg/2" 0
  return $faint
}

# 572 Petal Blizzard
proc poke:move:petalblizzard {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Petal Blizzard" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 574 Disarming Voice
proc poke:move:disarmingvoice {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Disarming Voice" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 575 Parting Shot
proc poke:move:partingshot {trainer pokedet otrainer opokedet} {
  global poke
  array set pokemon $pokedet
  set status $pokemon(status)
  lappend poke(switch) [list $trainer $pokemon(species) battle]
  poke:movetemplate:stats "Parting Shot" $trainer $pokedet $otrainer $opokedet [list "Atk -1" "SpA -1"] op
  poke:movetemplate:forceswitch "Parting Shot" $trainer $pokedet $otrainer $opokedet 0 0
  if {$faint} {lappend poke(prio0) [list 9999 poke:faint $otrainer]}
  return 2
}

# 577 Draining Kiss
proc poke:move:drainingkiss {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Draining Kiss" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:movetemplate:heal "" $trainer $pokedet $otrainer $opokedet "$dmg/2" 0
  return $faint
}

# 583 Play Rough
proc poke:move:playrough {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "Atk -1"] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Play Rough" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 584 Fairy Wind
proc poke:move:fairywind {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Fairy Wind" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 585 Moonblast
proc poke:move:moonblast {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "SpA -1"] 30 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Moonblast" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 586 Boomburst
proc poke:move:boomburst {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Boomburst" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 589 Play Nice
proc poke:move:playnice {trainer pokedet otrainer opokedet {charged 0}} {
  poke:movetemplate:stats "Play Nice" $trainer $pokedet $otrainer $opokedet [list "Atk -1"] op
  return 0
}

# 590 Confide
proc poke:move:confide {trainer pokedet otrainer opokedet {charged 0}} {
  poke:movetemplate:stats "Confide" $trainer $pokedet $otrainer $opokedet [list "SpA -1"] op
  return 0
}

# 591 Diamond Storm
proc poke:move:diamondstorm {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "Def +1"] 50 self 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Diamond Storm" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 592 Steam Eruption
proc poke:move:steameruption {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list BRN] 30 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Steam Eruption" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  
  array set pokemon $pokedet
  if {"FRZ" in $pokemon(status)} {
    poke:update_pokemon $trainer $pokedet status "rem FRZ"
    poke:message thaw - $trainer $pokedet $otrainer $opokedet - 0
  }
  return $faint
}

# 594 Water Shuriken
proc poke:move:watershuriken {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:multi "Water Shuriken" $trainer $pokedet $otrainer $opokedet]
}

# 595 Mystical Fire
proc poke:move:mysticalfire {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "SpA -1"] 100 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Mystical Fire" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 597 Aromatic Mist
proc poke:move:aromaticmist {trainer pokedet otrainer opokedet {charged 0}} {
  poke:movetemplate:stats "Aromatic Mist" $trainer $pokedet $otrainer $opokedet [list "SpA -2"] op
  return 0
}

# 598 Eerie Impulse
proc poke:move:eerieimpulse {trainer pokedet otrainer opokedet {charged 0}} {
  poke:movetemplate:stats "Eerie Impulse" $trainer $pokedet $otrainer $opokedet [list "SpA -2"] op
  return 0
}

# 599 Venom Drench
proc poke:move:venomdrench {trainer pokedet otrainer opokedet {charged 0}} {
  array set opokemon $opokedet
  set move "Venom Drench"
  if {PSN ni $opokemon(status) || BPSN ni $opokemon(status)} {
    poke:message fail $move $trainer $pokedet $otrainer $opokedet - 0
  } else {
    poke:movetemplate:stats $move $trainer $pokedet $otrainer $opokedet [list "Atk -1" "SpA -1" "Spd -1"] op
  }
  return 0
}

# 601 Geomancy
proc poke:move:geomancy {trainer pokedet otrainer opokedet {charged 0}} {
  poke:movetemplate:stats "Geomancy" $trainer $pokedet $otrainer $opokedet [list "SpA +2" "SpD +2" "Spd +2"] self
  poke:movetemplate:recharge $trainer $pokedet $otrainer $opokedet
}

# 603 Happy Hour
proc poke:move:happyhour {trainer pokedet otrainer opokedet} {
  poke:message use "Happy Hour" $trainer $pokedet $otrainer $opokedet - 0
  return 0
}

# 605 Dazzling Gleam
proc poke:move:dazzlinggleam {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Dazzling Gleam" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 606 Celebrate
proc poke:move:celebrate {trainer pokedet otrainer opokedet} {
  poke:message use "Celebrate" $trainer $pokedet $otrainer $opokedet - 0
  putquick "PRIVMSG $poke(chan) :Congratulations $trainer!"
  putquick "PRIVMSG $trainer :Congratulations $trainer!"
  putquick "PRIVMSG $otrainer :Congratulations $trainer!"
  return 0
}

# 607 Hold Hands
proc poke:move:holdhands {trainer pokedet otrainer opokedet} {
  poke:message fail "Hold Hands" $trainer $pokedet $otrainer $opokedet - 0
  return 0
}

# 608 Baby-Doll Eyes
proc poke:move:baby-dolleyes {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Baby-Doll Eyes" $trainer $pokedet $otrainer $opokedet [list "Atk -1"] op
  return 0
}

# 609 Nuzzle
proc poke:move:nuzzle {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list PAR] 100 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Nuzzle" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 610 Hold Back
proc poke:move:holdback {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Hold Back" $trainer $pokedet $otrainer $opokedet [list dmg {[incr dmg -1]}]] faint dmg
  return $faint
}

# 611 Infestation
proc poke:move:infestation {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:trap "Infestation" $trainer $pokedet $otrainer $opokedet]
}

# 612 Power-Up Punch
proc poke:move:power-uppunch {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "Atk +1"] 100 self 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Power-Up Punch" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 613 Oblivion Wing
proc poke:move:oblivionwing {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Oblivion Wing" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:movetemplate:heal "" $trainer $pokedet $otrainer $opokedet "$dmg*0.75" 0
  return $faint
}

# 616 Land's Wrath
proc poke:move:land'swrath {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Land's Wrath" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 617 Light of Ruin
proc poke:move:lightofruin {trainer pokedet otrainer opokedet} {
  global poke
  lassign [poke:movetemplate:default "Light of Ruin" $trainer $pokedet $otrainer $opokedet] faint dmg
  if {$faint != 2} {
    set dmg [expr {int($dmg/2.0)}]
    poke:movetemplate:recoil $trainer $pokedet $otrainer $opokedet $dmg "suffers $dmg of recoil"
  }
  return $faint
}

# 618 Origin Pulse
proc poke:move:originpulse {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Origin Pulse" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 619 Precipice Blades
proc poke:move:precipiceblades {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Precipice Blades" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 620 Dragon Ascent
proc poke:move:dragonascent {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "Def -1" "SpD -1"] 100 self 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Dragon Ascent" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 621 Hyperspace Fury
proc poke:move:hyperspacefury {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list "Def -1"] 100 self 0]
  lappend poke(triggers) $effect
  # Remove protect, detect, etc
  lassign [poke:movetemplate:default "Hyperspace Fury" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}
