# 1 Pound
proc poke:move:pound {trainer pokedet otrainer opokedet} {
  global poke
  set move "Pound"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$type eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  poke:trigger contact $otrainer $opokedet $trainer $pokedet
  return $faint
}

# 2 Karate Chop
proc poke:move:karatechop {trainer pokedet otrainer opokedet} {
  global poke
  set move "Karate Chop"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
  if {$type eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  poke:trigger contact $otrainer $opokedet $trainer $pokedet
  return $faint
}

# 3 Double Slap
proc poke:move:doubleslap {trainer pokedet otrainer opokedet {counter ""}} {
  global poke
  set move "Double Slap"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  set faint 0
  set fnt ""
  
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
  putquick "PRIVMSG $poke(chan) :$trainer's $pokemon(species) used $move on $otrainer's $opokemon(species)!"
  
  for {set i 1} {$i <= $counter} {incr i} {
    poke:trigger launch $otrainer $opokedet $trainer $pokedet
    set critmsg ""
    lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] dmgtype dmg crit
    if {$crit} {set critmsg "Critical hit! "}
    switch $dmgtype {
      miss {
        putquick "PRIVMSG $poke(chan) :Attack missed!"
      }
      "no effect" {
        putquick "PRIVMSG $poke(chan) :It doesn't affect $trainer's $pokemon(species)!"
        return 0
      }
      default {
        switch $dmgtype {
          "super effective" {set eff "It's super effective! "}
          "not effective" {set eff "It's not very effective. "}
          default {set eff ""}
        }
        if {$dmg > $opokemon(cHP)} {set fnt " $otrainer's $opokemon(species) fainted!"}
        putquick "PRIVMSG $poke(chan) :$critmsg$eff$otrainer's $opokemon(species) suffered $dmg damage!"
        lassign [poke:update_pokemon $otrainer $opokedet "cHP" -$dmg] result det
        poke:trigger damage $otrainer $opokedet $trainer $pokedet
        if {$det != ""} {
          set opokedet $det
          array set opokemon $opokedet
        }
        if {$opokemon(cHP) == 0} {
          set faint 1
          break
        }
        if {[poke:trigger contact $otrainer $opokedet $trainer $pokedet]} {break}
      }
    }
  }
  incr i -1
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger "last damage" $otrainer $opokedet $trainer $pokedet
  putquick "PRIVMSG $poke(chan) :Hit $i time(s)!$fnt"
  if {$faint} {poke:faint $otrainer}
  return $faint
}

# 4 Comet Punch
proc poke:move:cometpunch {trainer pokedet otrainer opokedet {counter ""}} {
  global poke
  set move "Comet Punch"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  set faint 0
  set fnt ""
  
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
  putquick "PRIVMSG $poke(chan) :$trainer's $pokemon(species) used $move on $otrainer's $opokemon(species)!"
  
  for {set i 1} {$i <= $counter} {incr i} {
    poke:trigger launch $otrainer $opokedet $trainer $pokedet
    set critmsg ""
    lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] dmgtype dmg crit
    if {$crit} {set critmsg "Critical hit! "}
    switch $dmgtype {
      miss {
        putquick "PRIVMSG $poke(chan) :Attack missed!"
      }
      "no effect" {
        putquick "PRIVMSG $poke(chan) :It doesn't affect $trainer's $pokemon(species)!"
        return 0
      }
      default {
        switch $dmgtype {
          "super effective" {set eff "It's super effective! "}
          "not effective" {set eff "It's not very effective. "}
          default {set eff ""}
        }
        if {$dmg > $opokemon(cHP)} {set fnt " $otrainer's $opokemon(species) fainted!"}
        putquick "PRIVMSG $poke(chan) :$critmsg$eff$otrainer's $opokemon(species) suffered $dmg damage!"
        lassign [poke:update_pokemon $otrainer $opokedet "cHP" -$dmg] result det
        poke:trigger damage $otrainer $opokedet $trainer $pokedet
        if {$det != ""} {
          set opokedet $det
          array set opokemon $opokedet
        }
        if {$opokemon(cHP) == 0} {
          set faint 1
          break
        }
        if {[poke:trigger contact $otrainer $opokedet $trainer $pokedet]} {break}
      }
    }
  }
  incr i -1
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger "last damage" $otrainer $opokedet $trainer $pokedet
  putquick "PRIVMSG $poke(chan) :Hit $i time(s)!$fnt"
  if {$faint} {poke:faint $otrainer}
  return $faint
}

# 5 Mega Punch
proc poke:move:megapunch {trainer pokedet otrainer opokedet} {
  global poke
  set move "Mega Punch"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$dmg eq "Miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  poke:trigger contact $otrainer $opokedet $trainer $pokedet
  return $faint
}

# 6 Pay day
proc poke:move:payday {trainer pokedet otrainer opokedet} {
  global poke
  set move "Pay Day"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$type eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  poke:trigger contact $otrainer $opokedet $trainer $pokedet
  return $faint
}

# 7 Fire Punch
proc poke:move:firepunch {trainer pokedet otrainer opokedet} {
  global poke
  set move "Fire Punch"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$type eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  if {!$faint && ![string match "*Fire*" $opokemon(type)] && $opokemon(ability) ne "Water Veil"} {
    poke:random
    set test [rand 100]
    if {$test < 10} {
      poke:update_pokemon $otrainer $opokedet "status" "BRN"
      lappend poke(prio-10) [list $opokemon(Spd) "poke:status:burn" $otrainer $opokedet $trainer $pokedet]
      poke:message brn - $trainer $pokedet $otrainer $opokedet - -
    }
  }
  poke:trigger contact $otrainer $opokedet $trainer $pokedet
  return $faint
}

# 10 Scratch
proc poke:move:scratch {trainer pokedet otrainer opokedet} {
  global poke
  set move "Scratch"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$dmg eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  poke:trigger contact $otrainer $opokedet $trainer $pokedet
  return $faint
}

# 11 Vice Grip
proc poke:move:vicegrip {trainer pokedet otrainer opokedet} {
  global poke
  set move "Vice Grip"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$dmg eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  poke:trigger contact $otrainer $opokedet $trainer $pokedet
  return $faint
}

# 15 Cut
proc poke:move:cut {trainer pokedet otrainer opokedet} {
  global poke
  set move "Cut"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$dmg eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"]
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  poke:trigger contact $otrainer $opokedet $trainer $pokedet
  return $faint
}

# 17 Wing Attack
proc poke:move:wingattack {trainer pokedet otrainer opokedet} {
  global poke
  set move "Wing Attack"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$dmg eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"]
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  poke:trigger contact $otrainer $opokedet $trainer $pokedet
  return $faint
}

# 21 Slam
proc poke:move:slam {trainer pokedet otrainer opokedet} {
  global poke
  set move "Slam"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$dmg eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  poke:trigger contact $otrainer $opokedet $trainer $pokedet
  return $faint
}

# 22 Vine Whip
proc poke:move:vinewhip {trainer pokedet otrainer opokedet} {
  global poke
  set move "Vine Whip"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$dmg eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  poke:trigger contact $otrainer $opokedet $trainer $pokedet
  return $faint
}

# 25 Mega Kick
proc poke:move:megakick {trainer pokedet otrainer opokedet} {
  global poke
  set move "Mega Kick"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$dmg eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  poke:trigger contact $otrainer $opokedet $trainer $pokedet
  return $faint
}

# 30 Horn Attack
proc poke:move:hornattack {trainer pokedet otrainer opokedet} {
  global poke
  set move "Horn Attack"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$dmg eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  poke:trigger contact $otrainer $opokedet $trainer $pokedet
  return $faint
}

# 31 Fury Attack
proc poke:move:furyattack {trainer pokedet otrainer opokedet {counter ""}} {
  global poke
  set move "Fury Attack"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  set faint 0
  set fnt ""
  
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
  putquick "PRIVMSG $poke(chan) :$trainer's $pokemon(species) used $move on $otrainer's $opokemon(species)!"
  
  for {set i 1} {$i <= $counter} {incr i} {
    poke:trigger launch $otrainer $opokedet $trainer $pokedet
    set critmsg ""
    lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] dmgtype dmg crit
    if {$crit} {set critmsg "Critical hit! "}
    switch $dmgtype {
      miss {
        putquick "PRIVMSG $poke(chan) :Attack missed!"
      }
      "no effect" {
        putquick "PRIVMSG $poke(chan) :It doesn't affect $trainer's $pokemon(species)!"
        return 0
      }
      default {
        switch $dmgtype {
          "super effective" {set eff "It's super effective! "}
          "not effective" {set eff "It's not very effective. "}
          default {set eff ""}
        }
        if {$dmg > $opokemon(cHP)} {set fnt " $otrainer's $opokemon(species) fainted!"}
        putquick "PRIVMSG $poke(chan) :$critmsg$eff$otrainer's $opokemon(species) suffered $dmg damage!"
        lassign [poke:update_pokemon $otrainer $opokedet "cHP" -$dmg] result det
        poke:trigger damage $otrainer $opokedet $trainer $pokedet
        if {$det != ""} {
          set opokedet $det
          array set opokemon $opokedet
        }
        if {$opokemon(cHP) == 0} {
          set faint 1
          break
        }
        if {[poke:trigger contact $otrainer $opokedet $trainer $pokedet]} {break}
      }
    }
  }
  incr i -1
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger "last damage" $otrainer $opokedet $trainer $pokedet
  putquick "PRIVMSG $poke(chan) :Hit $i time(s)!$fnt"
  if {$faint} {poke:faint $otrainer}
  return $faint
}

# 33 Tackle
proc poke:move:tackle {trainer pokedet otrainer opokedet} {
  global poke
  set move "Tackle"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$dmg eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  poke:trigger contact $otrainer $opokedet $trainer $pokedet
  return $faint
}

# 42 Pin Missle
proc poke:move:pinmissile {trainer pokedet otrainer opokedet {counter ""}} {
  global poke
  set move "Pin Missile"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  set faint 0
  set fnt ""
  
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
  putquick "PRIVMSG $poke(chan) :$trainer's $pokemon(species) used $move on $otrainer's $opokemon(species)!"
  
  for {set i 1} {$i <= $counter} {incr i} {
    poke:trigger launch $otrainer $opokedet $trainer $pokedet
    set critmsg ""
    lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] dmgtype dmg crit
    if {$crit} {set critmsg "Critical hit! "}
    switch $dmgtype {
      miss {
        putquick "PRIVMSG $poke(chan) :Attack missed!"
      }
      "no effect" {
        putquick "PRIVMSG $poke(chan) :It doesn't affect $trainer's $pokemon(species)!"
        return 0
      }
      default {
        switch $dmgtype {
          "super effective" {set eff "It's super effective! "}
          "not effective" {set eff "It's not very effective. "}
          default {set eff ""}
        }
        if {$dmg > $opokemon(cHP)} {set fnt " $otrainer's $opokemon(species) fainted!"}
        putquick "PRIVMSG $poke(chan) :$critmsg$eff$otrainer's $opokemon(species) suffered $dmg damage!"
        lassign [poke:update_pokemon $otrainer $opokedet "cHP" -$dmg] result det
        poke:trigger damage $otrainer $opokedet $trainer $pokedet
        if {$det != ""} {
          set opokedet $det
          array set opokemon $opokedet
        }
        if {$opokemon(cHP) == 0} {
          set faint 1
          break
        }
      }
    }
  }
  incr i -1
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger "last damage" $otrainer $opokedet $trainer $pokedet
  putquick "PRIVMSG $poke(chan) :Hit $i time(s)!$fnt"
  if {$faint} {poke:faint $otrainer}
  return $faint
}

# 52 Ember
proc poke:move:ember {trainer pokedet otrainer opokedet} {
  global poke
  set move "Ember"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$type eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  if {!$faint && ![string match "*Fire*" $opokemon(type)] && $opokemon(ability) ne "Water Veil"} {
    poke:random
    set test [rand 100]
    if {$test < 10} {
      poke:update_pokemon $otrainer $opokedet "status" "BRN"
      lappend poke(prio-10) [list $opokemon(Spd) "poke:status:burn" $otrainer $opokedet $trainer $pokedet]
      poke:message brn - $trainer $pokedet $otrainer $opokedet - -
    }
  }
  return $faint
}

# 53 Flamethrower
proc poke:move:flamethrower {trainer pokedet otrainer opokedet} {
  global poke
  set move "Flamethrower"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$type eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  if {!$faint && ![string match "*Fire*" $opokemon(type)] && $opokemon(ability) ne "Water Veil"} {
    poke:random
    set test [rand 100]
    if {$test < 10} {
      poke:update_pokemon $otrainer $opokedet "status" "BRN"
      lappend poke(prio-10) [list $opokemon(Spd) "poke:status:burn" $otrainer $opokedet $trainer $pokedet]
      poke:message brn - $trainer $pokedet $otrainer $opokedet - -
    }
  }
  return $faint
}

# 55 Water Gun
proc poke:move:watergun {trainer pokedet otrainer opokedet} {
  global poke
  set move "Water Gun"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$dmg eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  return $faint
}

# 56 Hydro Pump
proc poke:move:hydropump {trainer pokedet otrainer opokedet} {
  global poke
  set move "Hydro Pump"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$dmg eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  return $faint
}

# 64 Peck
proc poke:move:peck {trainer pokedet otrainer opokedet} {
  global poke
  set move "Peck"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$dmg eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  poke:trigger contact $otrainer $opokedet $trainer $pokedet
  return $faint
}

# 65 Drill Peck
proc poke:move:drillpeck {trainer pokedet otrainer opokedet} {
  global poke
  set move "Drill Peck"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$dmg eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  poke:trigger contact $otrainer $opokedet $trainer $pokedet
  return $faint
}

# 70 Strength
proc poke:move:strength {trainer pokedet otrainer opokedet} {
  global poke
  set move "Strength"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$dmg eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  poke:trigger contact $otrainer $opokedet $trainer $pokedet
  return $faint
}

# 75 Razor Leaf
proc poke:move:razorleaf {trainer pokedet otrainer opokedet} {
  global poke
  set move "Razor Leaf"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
  if {$type eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  return $faint
}

# 88 Rock Throw
proc poke:move:rockthrow {trainer pokedet otrainer opokedet} {
  global poke
  set move "Rock Throw"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$dmg eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  return $faint
}

# 98 Quick Attack
proc poke:move:quickattack {trainer pokedet otrainer opokedet} {
  global poke
  set move "Quick Attack"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$dmg eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  poke:trigger contact $otrainer $opokedet $trainer $pokedet
  return $faint
}

# 121 Egg Bomb
proc poke:move:eggbomb {trainer pokedet otrainer opokedet} {
  global poke
  set move "Egg Bomb"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$dmg eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  return $faint
}

# 126 Fire Blast
proc poke:move:fireblast {trainer pokedet otrainer opokedet} {
  global poke
  set move "Fire Blast"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$type eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  if {!$faint && ![string match "*Fire*" $opokemon(type)] && $opokemon(ability) ne "Water Veil"} {
    poke:random
    set test [rand 100]
    if {$test < 10} {
      poke:update_pokemon $otrainer $opokedet "status" "BRN"
      lappend poke(prio-10) [list $opokemon(Spd) "poke:status:burn" $otrainer $opokedet $trainer $pokedet]
      poke:message brn - $trainer $pokedet $otrainer $opokedet - -
    }
  }
  return $faint
}

# 131 Spike Cannon
proc poke:move:spikecannon {trainer pokedet otrainer opokedet {counter ""}} {
  global poke
  set move "Spike Cannon"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  set faint 0
  set fnt ""
  
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
  putquick "PRIVMSG $poke(chan) :$trainer's $pokemon(species) used $move on $otrainer's $opokemon(species)!"
  
  for {set i 1} {$i <= $counter} {incr i} {
    poke:trigger launch $otrainer $opokedet $trainer $pokedet
    set critmsg ""
    lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] dmgtype dmg crit
    if {$crit} {set critmsg "Critical hit! "}
    switch $dmgtype {
      miss {
        putquick "PRIVMSG $poke(chan) :Attack missed!"
      }
      "no effect" {
        putquick "PRIVMSG $poke(chan) :It doesn't affect $trainer's $pokemon(species)!"
        return 0
      }
      default {
        switch $dmgtype {
          "super effective" {set eff "It's super effective! "}
          "not effective" {set eff "It's not very effective. "}
          default {set eff ""}
        }
        if {$dmg > $opokemon(cHP)} {set fnt " $otrainer's $opokemon(species) fainted!"}
        putquick "PRIVMSG $poke(chan) :$critmsg$eff$otrainer's $opokemon(species) suffered $dmg damage!"
        lassign [poke:update_pokemon $otrainer $opokedet "cHP" -$dmg] result det
        poke:trigger damage $otrainer $opokedet $trainer $pokedet
        if {$det != ""} {
          set opokedet $det
          array set opokemon $opokedet
        }
        if {$opokemon(cHP) == 0} {
          set faint 1
          break
        }
      }
    }
  }
  incr i -1
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger "last damage" $otrainer $opokedet $trainer $pokedet
  putquick "PRIVMSG $poke(chan) :Hit $i time(s)!$fnt"
  if {$faint} {poke:faint $otrainer}
  return $faint
}

# 140 Barrage
proc poke:move:barrage {trainer pokedet otrainer opokedet {counter ""}} {
  global poke
  set move "Barrage"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  set faint 0
  set fnt ""
  
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
  putquick "PRIVMSG $poke(chan) :$trainer's $pokemon(species) used $move on $otrainer's $opokemon(species)!"
  
  for {set i 1} {$i <= $counter} {incr i} {
    poke:trigger launch $otrainer $opokedet $trainer $pokedet
    set critmsg ""
    lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] dmgtype dmg crit
    if {$crit} {set critmsg "Critical hit! "}
    switch $dmgtype {
      miss {
        putquick "PRIVMSG $poke(chan) :Attack missed!"
      }
      "no effect" {
        putquick "PRIVMSG $poke(chan) :It doesn't affect $trainer's $pokemon(species)!"
        return 0
      }
      default {
        switch $dmgtype {
          "super effective" {set eff "It's super effective! "}
          "not effective" {set eff "It's not very effective. "}
          default {set eff ""}
        }
        if {$dmg > $opokemon(cHP)} {set fnt " $otrainer's $opokemon(species) fainted!"}
        putquick "PRIVMSG $poke(chan) :$critmsg$eff$otrainer's $opokemon(species) suffered $dmg damage!"
        lassign [poke:update_pokemon $otrainer $opokedet "cHP" -$dmg] result det
        poke:trigger damage $otrainer $opokedet $trainer $pokedet
        if {$det != ""} {
          set opokedet $det
          array set opokemon $opokedet
        }
        if {$opokemon(cHP) == 0} {
          set faint 1
          break
        }
        if {[poke:trigger contact $otrainer $opokedet $trainer $pokedet]} {break}
      }
    }
  }
  incr i -1
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger "last damage" $otrainer $opokedet $trainer $pokedet
  putquick "PRIVMSG $poke(chan) :Hit $i time(s)!$fnt"
  if {$faint} {poke:faint $otrainer}
  return $faint
}

# 152 Crabhammer
proc poke:move:crabhammer {trainer pokedet otrainer opokedet} {
  global poke
  set move "Crabhammer"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
  if {$type eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  poke:trigger contact $otrainer $opokedet $trainer $pokedet
  return $faint
}

# 154 Fury Swipes
proc poke:move:furyswipes {trainer pokedet otrainer opokedet {counter ""}} {
  global poke
  set move "Fury Swipes"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  set faint 0
  set fnt ""
  
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
  putquick "PRIVMSG $poke(chan) :$trainer's $pokemon(species) used $move on $otrainer's $opokemon(species)!"
  
  for {set i 1} {$i <= $counter} {incr i} {
    poke:trigger launch $otrainer $opokedet $trainer $pokedet
    set critmsg ""
    lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] dmgtype dmg crit
    if {$crit} {set critmsg "Critical hit! "}
    switch $dmgtype {
      miss {
        putquick "PRIVMSG $poke(chan) :Attack missed!"
      }
      "no effect" {
        putquick "PRIVMSG $poke(chan) :It doesn't affect $trainer's $pokemon(species)!"
        return 0
      }
      default {
        switch $dmgtype {
          "super effective" {set eff "It's super effective! "}
          "not effective" {set eff "It's not very effective. "}
          default {set eff ""}
        }
        if {$dmg > $opokemon(cHP)} {set fnt " $otrainer's $opokemon(species) fainted!"}
        putquick "PRIVMSG $poke(chan) :$critmsg$eff$otrainer's $opokemon(species) suffered $dmg damage!"
        lassign [poke:update_pokemon $otrainer $opokedet "cHP" -$dmg] result det
        poke:trigger damage $otrainer $opokedet $trainer $pokedet
        if {$det != ""} {
          set opokedet $det
          array set opokemon $opokedet
        }
        if {$opokemon(cHP) == 0} {
          set faint 1
          break
        }
        if {[poke:trigger contact $otrainer $opokedet $trainer $pokedet]} {break}
      }
    }
  }
  incr i -1
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger "last damage" $otrainer $opokedet $trainer $pokedet
  putquick "PRIVMSG $poke(chan) :Hit $i time(s)!$fnt"
  if {$faint} {poke:faint $otrainer}
  return $faint
}

# 163 Slash
proc poke:move:slash {trainer pokedet otrainer opokedet} {
  global poke
  set move "Slash"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
  if {$type eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  poke:trigger contact $otrainer $opokedet $trainer $pokedet
  return $faint
}

# 177 Aeroblast
proc poke:move:aeroblast {trainer pokedet otrainer opokedet} {
  global poke
  set move "Aeroblast"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
  if {$type eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  return $faint
}

# 183 Mach Punch
proc poke:move:machpunch {trainer pokedet otrainer opokedet} {
  global poke
  set move "Mach Punch"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$dmg eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  poke:trigger contact $otrainer $opokedet $trainer $pokedet
  return $faint
}

# 198 Bone Rush
proc poke:move:bonerush {trainer pokedet otrainer opokedet {counter ""}} {
  global poke
  set move "Bone Rush"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  set faint 0
  set fnt ""
  
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
  putquick "PRIVMSG $poke(chan) :$trainer's $pokemon(species) used $move on $otrainer's $opokemon(species)!"
  
  for {set i 1} {$i <= $counter} {incr i} {
    poke:trigger launch $otrainer $opokedet $trainer $pokedet
    set critmsg ""
    lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] dmgtype dmg crit
    if {$crit} {set critmsg "Critical hit! "}
    switch $dmgtype {
      miss {
        putquick "PRIVMSG $poke(chan) :Attack missed!"
      }
      "no effect" {
        putquick "PRIVMSG $poke(chan) :It doesn't affect $trainer's $pokemon(species)!"
        return 0
      }
      default {
        switch $dmgtype {
          "super effective" {set eff "It's super effective! "}
          "not effective" {set eff "It's not very effective. "}
          default {set eff ""}
        }
        if {$dmg > $opokemon(cHP)} {set fnt " $otrainer's $opokemon(species) fainted!"}
        putquick "PRIVMSG $poke(chan) :$critmsg$eff$otrainer's $opokemon(species) suffered $dmg damage!"
        lassign [poke:update_pokemon $otrainer $opokedet "cHP" -$dmg] result det
        poke:trigger damage $otrainer $opokedet $trainer $pokedet
        if {$det != ""} {
          set opokedet $det
          array set opokemon $opokedet
        }
        if {$opokemon(cHP) == 0} {
          set faint 1
          break
        }
      }
    }
  }
  incr i -1
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger "last damage" $otrainer $opokedet $trainer $pokedet
  putquick "PRIVMSG $poke(chan) :Hit $i time(s)!$fnt"
  if {$faint} {poke:faint $otrainer}
  return $faint
}

# 224 Megahorn
proc poke:move:megahorn {trainer pokedet otrainer opokedet} {
  global poke
  set move "Megahorn"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$dmg eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  poke:trigger contact $otrainer $opokedet $trainer $pokedet
  return $faint
}

# 238 Cross Chop
proc poke:move:crosschop {trainer pokedet otrainer opokedet} {
  global poke
  set move "Cross Chop"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
  if {$type eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  poke:trigger contact $otrainer $opokedet $trainer $pokedet
  return $faint
}

# 245 Extreme Speed
proc poke:move:extremespeed {trainer pokedet otrainer opokedet} {
  global poke
  set move "Extreme Speed"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$dmg eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  poke:trigger contact $otrainer $opokedet $trainer $pokedet
  return $faint
}

# 257 Heat Wave
proc poke:move:heatwave {trainer pokedet otrainer opokedet} {
  global poke
  set move "Heat Wave"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$type eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  if {!$faint && ![string match "*Fire*" $opokemon(type)] && $opokemon(ability) ne "Water Veil"} {
    poke:random
    set test [rand 100]
    if {$test < 10} {
      poke:update_pokemon $otrainer $opokedet "status" "BRN"
      lappend poke(prio-10) [list $opokemon(Spd) "poke:status:burn" $otrainer $opokedet $trainer $pokedet]
      poke:message brn - $trainer $pokedet $otrainer $opokedet - -
    }
  }
  return $faint
}

# 292 Arm Thrust
proc poke:move:armthrust {trainer pokedet otrainer opokedet {counter ""}} {
  global poke
  set move "Arm Thrust"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  set faint 0
  set fnt ""
  
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
  putquick "PRIVMSG $poke(chan) :$trainer's $pokemon(species) used $move on $otrainer's $opokemon(species)!"
  
  for {set i 1} {$i <= $counter} {incr i} {
    poke:trigger launch $otrainer $opokedet $trainer $pokedet
    set critmsg ""
    lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] dmgtype dmg crit
    if {$crit} {set critmsg "Critical hit! "}
    switch $dmgtype {
      miss {
        putquick "PRIVMSG $poke(chan) :Attack missed!"
      }
      "no effect" {
        putquick "PRIVMSG $poke(chan) :It doesn't affect $trainer's $pokemon(species)!"
        return 0
      }
      default {
        switch $dmgtype {
          "super effective" {set eff "It's super effective! "}
          "not effective" {set eff "It's not very effective. "}
          default {set eff ""}
        }
        if {$dmg > $opokemon(cHP)} {set fnt " $otrainer's $opokemon(species) fainted!"}
        putquick "PRIVMSG $poke(chan) :$critmsg$eff$otrainer's $opokemon(species) suffered $dmg damage!"
        lassign [poke:update_pokemon $otrainer $opokedet "cHP" -$dmg] result det
        poke:trigger damage $otrainer $opokedet $trainer $pokedet
        if {$det != ""} {
          set opokedet $det
          array set opokemon $opokedet
        }
        if {$opokemon(cHP) == 0} {
          set faint 1
          break
        }
        if {[poke:trigger contact $otrainer $opokedet $trainer $pokedet]} {break}
      }
    }
  }
  incr i -1
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger "last damage" $otrainer $opokedet $trainer $pokedet
  putquick "PRIVMSG $poke(chan) :Hit $i time(s)!$fnt"
  if {$faint} {poke:faint $otrainer}
  return $faint
}

# 304 Hyper Voice
proc poke:move:hypervoice {trainer pokedet otrainer opokedet} {
  global poke
  set move "Hyper Voice"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$dmg eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  return $faint
}

# 314 Air Cutter
proc poke:move:aircutter {trainer pokedet otrainer opokedet} {
  global poke
  set move "Air Cutter"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
  if {$type eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  return $faint
}

# 331 Bullet Seed
proc poke:move:bulletseed {trainer pokedet otrainer opokedet {counter ""}} {
  global poke
  set move "Bullet Seed"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  set faint 0
  set fnt ""
  
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
  putquick "PRIVMSG $poke(chan) :$trainer's $pokemon(species) used $move on $otrainer's $opokemon(species)!"
  
  for {set i 1} {$i <= $counter} {incr i} {
    poke:trigger launch $otrainer $opokedet $trainer $pokedet
    set critmsg ""
    lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] dmgtype dmg crit
    if {$crit} {set critmsg "Critical hit! "}
    switch $dmgtype {
      miss {
        putquick "PRIVMSG $poke(chan) :Attack missed!"
      }
      "no effect" {
        putquick "PRIVMSG $poke(chan) :It doesn't affect $trainer's $pokemon(species)!"
        return 0
      }
      default {
        switch $dmgtype {
          "super effective" {set eff "It's super effective! "}
          "not effective" {set eff "It's not very effective. "}
          default {set eff ""}
        }
        if {$dmg > $opokemon(cHP)} {set fnt " $otrainer's $opokemon(species) fainted!"}
        putquick "PRIVMSG $poke(chan) :$critmsg$eff$otrainer's $opokemon(species) suffered $dmg damage!"
        lassign [poke:update_pokemon $otrainer $opokedet "cHP" -$dmg] result det
        poke:trigger damage $otrainer $opokedet $trainer $pokedet
        if {$det != ""} {
          set opokedet $det
          array set opokemon $opokedet
        }
        if {$opokemon(cHP) == 0} {
          set faint 1
          break
        }
      }
    }
  }
  incr i -1
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger "last damage" $otrainer $opokedet $trainer $pokedet
  putquick "PRIVMSG $poke(chan) :Hit $i time(s)!$fnt"
  if {$faint} {poke:faint $otrainer}
  return $faint
}

# 333 Icicle Spear
proc poke:move:iciclespear {trainer pokedet otrainer opokedet {counter ""}} {
  global poke
  set move "Icicle Spear"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  set faint 0
  set fnt ""
  
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
  putquick "PRIVMSG $poke(chan) :$trainer's $pokemon(species) used $move on $otrainer's $opokemon(species)!"
  
  for {set i 1} {$i <= $counter} {incr i} {
    poke:trigger launch $otrainer $opokedet $trainer $pokedet
    set critmsg ""
    lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] dmgtype dmg crit
    if {$crit} {set critmsg "Critical hit! "}
    switch $dmgtype {
      miss {
        putquick "PRIVMSG $poke(chan) :Attack missed!"
      }
      "no effect" {
        putquick "PRIVMSG $poke(chan) :It doesn't affect $trainer's $pokemon(species)!"
        return 0
      }
      default {
        switch $dmgtype {
          "super effective" {set eff "It's super effective! "}
          "not effective" {set eff "It's not very effective. "}
          default {set eff ""}
        }
        if {$dmg > $opokemon(cHP)} {set fnt " $otrainer's $opokemon(species) fainted!"}
        putquick "PRIVMSG $poke(chan) :$critmsg$eff$otrainer's $opokemon(species) suffered $dmg damage!"
        lassign [poke:update_pokemon $otrainer $opokedet "cHP" -$dmg] result det
        poke:trigger damage $otrainer $opokedet $trainer $pokedet
        if {$det != ""} {
          set opokedet $det
          array set opokemon $opokedet
        }
        if {$opokemon(cHP) == 0} {
          set faint 1
          break
        }
      }
    }
  }
  incr i -1
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger "last damage" $otrainer $opokedet $trainer $pokedet
  putquick "PRIVMSG $poke(chan) :Hit $i time(s)!$fnt"
  if {$faint} {poke:faint $otrainer}
  return $faint
}

# 337 Dragon Claw
proc poke:move:dragonclaw {trainer pokedet otrainer opokedet} {
  global poke
  set move "Dragon Claw"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$dmg eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  poke:trigger contact $otrainer $opokedet $trainer $pokedet
  return $faint
}

# 348 Leaf Blade
proc poke:move:leafblade {trainer pokedet otrainer opokedet} {
  global poke
  set move "Leaf Blade"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
  if {$type eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  poke:trigger contact $otrainer $opokedet $trainer $pokedet
  return $faint
}

# 350 Rock Blast
proc poke:move:rockblast {trainer pokedet otrainer opokedet {counter ""}} {
  global poke
  set move "Rock Blast"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  set faint 0
  set fnt ""
  
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
  putquick "PRIVMSG $poke(chan) :$trainer's $pokemon(species) used $move on $otrainer's $opokemon(species)!"
  
  for {set i 1} {$i <= $counter} {incr i} {
    poke:trigger launch $otrainer $opokedet $trainer $pokedet
    set critmsg ""
    lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] dmgtype dmg crit
    if {$crit} {set critmsg "Critical hit! "}
    switch $dmgtype {
      miss {
        putquick "PRIVMSG $poke(chan) :Attack missed!"
      }
      "no effect" {
        putquick "PRIVMSG $poke(chan) :It doesn't affect $trainer's $pokemon(species)!"
        return 0
      }
      default {
        switch $dmgtype {
          "super effective" {set eff "It's super effective! "}
          "not effective" {set eff "It's not very effective. "}
          default {set eff ""}
        }
        if {$dmg > $opokemon(cHP)} {set fnt " $otrainer's $opokemon(species) fainted!"}
        putquick "PRIVMSG $poke(chan) :$critmsg$eff$otrainer's $opokemon(species) suffered $dmg damage!"
        lassign [poke:update_pokemon $otrainer $opokedet "cHP" -$dmg] result det
        poke:trigger damage $otrainer $opokedet $trainer $pokedet
        if {$det != ""} {
          set opokedet $det
          array set opokemon $opokedet
        }
        if {$opokemon(cHP) == 0} {
          set faint 1
          break
        }
      }
    }
  }
  incr i -1
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger "last damage" $otrainer $opokedet $trainer $pokedet
  putquick "PRIVMSG $poke(chan) :Hit $i time(s)!$fnt"
  if {$faint} {poke:faint $otrainer}
  return $faint
}

# 400 Night Slash
proc poke:move:nightslash {trainer pokedet otrainer opokedet} {
  global poke
  set move "Night Slash"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
  if {$type eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  poke:trigger contact $otrainer $opokedet $trainer $pokedet
  return $faint
}

# 401 Aqua Tail
proc poke:move:aquatail {trainer pokedet otrainer opokedet} {
  global poke
  set move "Aqua Tail"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$dmg eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  poke:trigger contact $otrainer $opokedet $trainer $pokedet
  return $faint
}

# 402 Seed Bomb
proc poke:move:seedbomb {trainer pokedet otrainer opokedet} {
  global poke
  set move "Seed Bomb"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$dmg eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  return $faint
}

# 404 X-Scissor
proc poke:move:x-scissor {trainer pokedet otrainer opokedet} {
  global poke
  set move "X-Scissor"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$dmg eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  poke:trigger contact $otrainer $opokedet $trainer $pokedet
  return $faint
}

# 406 Dragon Pulse
proc poke:move:dragonpulse {trainer pokedet otrainer opokedet} {
  global poke
  set move "Dragon Pulse"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$dmg eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  return $faint
}

# 408 Power Gem
proc poke:move:powergem {trainer pokedet otrainer opokedet} {
  global poke
  set move "Power Gem"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$dmg eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  return $faint
}

# 410 Vacuum Wave
proc poke:move:vacuumwave {trainer pokedet otrainer opokedet} {
  global poke
  set move "Vacuum Wave"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$dmg eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  return $faint
}

# 418 Bullet Punch
proc poke:move:bulletpunch {trainer pokedet otrainer opokedet} {
  global poke
  set move "Bullet Punch"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$dmg eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  poke:trigger contact $otrainer $opokedet $trainer $pokedet
  return $faint
}

# 420 Ice Shard
proc poke:move:iceshard {trainer pokedet otrainer opokedet} {
  global poke
  set move "Ice Shard"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$dmg eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  return $faint
}

# 421 Shadow Claw
proc poke:move:shadowclaw {trainer pokedet otrainer opokedet} {
  global poke
  set move "Shadow Claw"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
  if {$type eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  poke:trigger contact $otrainer $opokedet $trainer $pokedet
  return $faint
}

# 425 Shadow Sneak
proc poke:move:shadowsneak {trainer pokedet otrainer opokedet} {
  global poke
  set move "Shadow Sneak"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$dmg eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  poke:trigger contact $otrainer $opokedet $trainer $pokedet
  return $faint
}

# 427 Psycho Cut
proc poke:move:psychocut {trainer pokedet otrainer opokedet} {
  global poke
  set move "Psycho Cut"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
  if {$type eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  return $faint
}

# 436 Lava Plume
proc poke:move:lavaplume {trainer pokedet otrainer opokedet} {
  global poke
  set move "Lava Plume"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$type eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  if {!$faint && ![string match "*Fire*" $opokemon(type)] && $opokemon(ability) ne "Water Veil"} {
    poke:random
    set test [rand 100]
    if {$test < 30} {
      poke:update_pokemon $otrainer $opokedet "status" "BRN"
      lappend poke(prio-10) [list $opokemon(Spd) "poke:status:burn" $otrainer $opokedet $trainer $pokedet]
      poke:message brn - $trainer $pokedet $otrainer $opokedet - -
    }
  }
  return $faint
}

# 438 Power Whip
proc poke:move:powerwhip {trainer pokedet otrainer opokedet} {
  global poke
  set move "Power Whip"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$dmg eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  poke:trigger contact $otrainer $opokedet $trainer $pokedet
  return $faint
}

# 444 Stone Edge
proc poke:move:stoneedge {trainer pokedet otrainer opokedet} {
  global poke
  set move "Stone Edge"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
  if {$type eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  return $faint
}

# 453 Aqua Jet
proc poke:move:aquajet {trainer pokedet otrainer opokedet} {
  global poke
  set move "Aqua Jet"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$dmg eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  poke:trigger contact $otrainer $opokedet $trainer $pokedet
  return $faint
}

# 454 Attack Order
proc poke:move:attackorder {trainer pokedet otrainer opokedet} {
  global poke
  set move "Attack Order"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
  if {$type eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  return $faint
}

# 460 Spacial Rend
proc poke:move:spacialrend {trainer pokedet otrainer opokedet} {
  global poke
  set move "Spacial Rend"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
  if {$type eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  return $faint
}

# 503 Scald
proc poke:move:scald {trainer pokedet otrainer opokedet} {
  global poke
  set move "Scald"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$type eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  if {!$faint && ![string match "*Fire*" $opokemon(type)] && $opokemon(ability) ne "Water Veil"} {
    poke:random
    set test [rand 100]
    if {$test < 10} {
      poke:update_pokemon $otrainer $opokedet "status" "BRN"
      lappend poke(prio-10) [list $opokemon(Spd) "poke:status:burn" $otrainer $opokedet $trainer $pokedet]
      poke:message brn - $trainer $pokedet $otrainer $opokedet - -
    }
  }
  return $faint
}

# 517 Inferno
proc poke:move:inferno {trainer pokedet otrainer opokedet} {
  global poke
  set move "Inferno"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$type eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  if {!$faint && ![string match "*Fire*" $opokemon(type)] && $opokemon(ability) ne "Water Veil"} {
    poke:update_pokemon $otrainer $opokedet "status" "BRN"
    lappend poke(prio-10) [list $opokemon(Spd) "poke:status:burn" $otrainer $opokedet $trainer $pokedet]
    poke:message brn - $trainer $pokedet $otrainer $opokedet - -
  }
  return $faint
}

# 529 Drill Run
proc poke:move:drillrun {trainer pokedet otrainer opokedet} {
  global poke
  set move "Drill Run"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
  if {$type eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  poke:trigger contact $otrainer $opokedet $trainer $pokedet
  return $faint
}

# 541 Tail Slap
proc poke:move:tailslap {trainer pokedet otrainer opokedet {counter ""}} {
  global poke
  set move "Tail Slap"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  set faint 0
  set fnt ""
  
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
  putquick "PRIVMSG $poke(chan) :$trainer's $pokemon(species) used $move on $otrainer's $opokemon(species)!"
  
  for {set i 1} {$i <= $counter} {incr i} {
    poke:trigger launch $otrainer $opokedet $trainer $pokedet
    set critmsg ""
    lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] dmgtype dmg crit
    if {$crit} {set critmsg "Critical hit! "}
    switch $dmgtype {
      miss {
        putquick "PRIVMSG $poke(chan) :Attack missed!"
      }
      "no effect" {
        putquick "PRIVMSG $poke(chan) :It doesn't affect $trainer's $pokemon(species)!"
        return 0
      }
      default {
        switch $dmgtype {
          "super effective" {set eff "It's super effective! "}
          "not effective" {set eff "It's not very effective. "}
          default {set eff ""}
        }
        if {$dmg > $opokemon(cHP)} {set fnt " $otrainer's $opokemon(species) fainted!"}
        putquick "PRIVMSG $poke(chan) :$critmsg$eff$otrainer's $opokemon(species) suffered $dmg damage!"
        lassign [poke:update_pokemon $otrainer $opokedet "cHP" -$dmg] result det
        poke:trigger damage $otrainer $opokedet $trainer $pokedet
        if {$det != ""} {
          set opokedet $det
          array set opokemon $opokedet
        }
        if {$opokemon(cHP) == 0} {
          set faint 1
          break
        }
        if {[poke:trigger contact $otrainer $opokedet $trainer $pokedet]} {break}
      }
    }
  }
  incr i -1
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger "last damage" $otrainer $opokedet $trainer $pokedet
  putquick "PRIVMSG $poke(chan) :Hit $i time(s)!$fnt"
  if {$faint} {poke:faint $otrainer}
  return $faint
}

# 545 Searing Shot
proc poke:move:searingshot {trainer pokedet otrainer opokedet} {
  global poke
  set move "Searing Shot"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$type eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  if {!$faint && ![string match "*Fire*" $opokemon(type)] && $opokemon(ability) ne "Water Veil"} {
    poke:random
    set test [rand 100]
    if {$test < 30} {
      poke:update_pokemon $otrainer $opokedet "status" "BRN"
      lappend poke(prio-10) [list $opokemon(Spd) "poke:status:burn" $otrainer $opokedet $trainer $pokedet]
      poke:message brn - $trainer $pokedet $otrainer $opokedet - -
    }
  }
  return $faint
}

# 551 Blue Flare
proc poke:move:blueflare {trainer pokedet otrainer opokedet} {
  global poke
  set move "Blue Flare"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$type eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  if {!$faint && ![string match "*Fire*" $opokemon(type)] && $opokemon(ability) ne "Water Veil"} {
    poke:random
    set test [rand 100]
    if {$test < 20} {
      poke:update_pokemon $otrainer $opokedet "status" "BRN"
      lappend poke(prio-10) [list $opokemon(Spd) "poke:status:burn" $otrainer $opokedet $trainer $pokedet]
      poke:message brn - $trainer $pokedet $otrainer $opokedet - -
    }
  }
  return $faint
}

# 572 Petal Blizzard
proc poke:move:petalblizzard {trainer pokedet otrainer opokedet} {
  global poke
  set move "Petal Blizzard"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$dmg eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  return $faint
}

# 586 Boomburst
proc poke:move:boomburst {trainer pokedet otrainer opokedet} {
  global poke
  set move "Boom Burst"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$dmg eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  return $faint
}

# 592 Steam Eruption
proc poke:move:steameruption {trainer pokedet otrainer opokedet} {
  global poke
  set move "Steam Eruption"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$type eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  if {!$faint && ![string match "*Fire*" $opokemon(type)] && $opokemon(ability) ne "Water Veil"} {
    poke:random
    set test [rand 100]
    if {$test < 30} {
      poke:update_pokemon $otrainer $opokedet "status" "BRN"
      lappend poke(prio-10) [list $opokemon(Spd) "poke:status:burn" $otrainer $opokedet $trainer $pokedet]
      poke:message brn - $trainer $pokedet $otrainer $opokedet - -
    }
  }
  return $faint
}

# 594 Water Shuriken
proc poke:move:watershuriken {trainer pokedet otrainer opokedet {counter ""}} {
  global poke
  set move "Water Shuriken"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  set faint 0
  set fnt ""
  
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
  putquick "PRIVMSG $poke(chan) :$trainer's $pokemon(species) used $move on $otrainer's $opokemon(species)!"
  
  for {set i 1} {$i <= $counter} {incr i} {
    poke:trigger launch $otrainer $opokedet $trainer $pokedet
    set critmsg ""
    lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] dmgtype dmg crit
    if {$crit} {set critmsg "Critical hit! "}
    switch $dmgtype {
      miss {
        putquick "PRIVMSG $poke(chan) :Attack missed!"
      }
      "no effect" {
        putquick "PRIVMSG $poke(chan) :It doesn't affect $trainer's $pokemon(species)!"
        return 0
      }
      default {
        switch $dmgtype {
          "super effective" {set eff "It's super effective! "}
          "not effective" {set eff "It's not very effective. "}
          default {set eff ""}
        }
        if {$dmg > $opokemon(cHP)} {set fnt " $otrainer's $opokemon(species) fainted!"}
        putquick "PRIVMSG $poke(chan) :$critmsg$eff$otrainer's $opokemon(species) suffered $dmg damage!"
        lassign [poke:update_pokemon $otrainer $opokedet "cHP" -$dmg] result det
        poke:trigger damage $otrainer $opokedet $trainer $pokedet
        if {$det != ""} {
          set opokedet $det
          array set opokemon $opokedet
        }
        if {$opokemon(cHP) == 0} {
          set faint 1
          break
        }
      }
    }
  }
  incr i -1
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger "last damage" $otrainer $opokedet $trainer $pokedet
  putquick "PRIVMSG $poke(chan) :Hit $i time(s)!$fnt"
  if {$faint} {poke:faint $otrainer}
  return $faint
}

# 605 Dazzling Gleam
proc poke:move:dazzlinggleam {trainer pokedet otrainer opokedet} {
  global poke
  set move "Dazzling Gleam"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$dmg eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  return $faint
}

# 616 Land's Wrath
proc poke:move:land'swrath {trainer pokedet otrainer opokedet} {
  global poke
  set move "Land's Wrath"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$dmg eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  return $faint
}

# 618 Origin Pulse
proc poke:move:originpulse {trainer pokedet otrainer opokedet} {
  global poke
  set move "Origin Pulse"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$dmg eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  return $faint
}

# 619 Precipice Blades
proc poke:move:precipiceblades {trainer pokedet otrainer opokedet} {
  global poke
  set move "Precipice Blades"
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] type dmg crit
  if {$dmg eq "miss" || $type eq "no effect"} {
    poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 0
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $type $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  poke:trigger contact $otrainer $opokedet $trainer $pokedet
  return $faint
}
