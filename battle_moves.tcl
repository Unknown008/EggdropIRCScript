# Template for default moves
proc poke:movetemplate:default {move trainer pokedet otrainer opokedet} {
  global poke
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff contact]
  array set opokemon $opokedet
  array set pokemon $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] dmgtype dmg crit
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  if {$dmgtype in {"miss" "no effect"}} {
    poke:message $dmgtype $move $trainer $pokedet $otrainer $opokedet - 0
    return [list 2 $dmg]
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
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
  if {$faint} {poke:faint $otrainer}
  return $faint
}

# Template for moves that need charging
proc poke:movetemplate:charge {move trainer pokedet otrainer {msg "is charging!"}} {
  global poke
  array set pokemon $pokedet
  set trainerID [lsearch -index 0 $poke(team) $trainer]
  set pokeID [lsearch -regexp [lindex $poke(team) $trainerID 1] "\\yspecies \\{?$pokemon(species)\\y\\}?"]
  set opponentID [lsearch $poke(currentPoke) $otrainer]
  lappend poke(pending) [list 0 $pokemon(Spd) "poke:move:[string tolower [join $move {}]]" $trainer $pokemon(species) $trainerID $pokeID $opponentID 0]
  poke:message custom - $trainer $pokedet $otrainer $opokedet - 0 $msg
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
  array set opokemon $opokedet
  poke:message use $move $trainer $pokedet $otrainer $opokedet - 0
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:statustrigger $trainer $pokedet $otrainer $opokedet "" "" $stat 100 $target 1
  return
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
        if {$pokemon(cHP) > 0} {lappend available_list $i}
      }
      poke:random
      if {[llength $available_list] == 0} {
        poke:message fail $move $trainer $pokedet $otrainer $opokedet - 0
      } else {
        poke:message use "Whirlwind" $trainer $pokedet $otrainer $opokedet - 0
        set nID [lindex $available_list [rand [llength $available_list]]]
        poke:switch $otrainer $cID $nID -
        poke:message custom - $otrainer "species $pokemon(species)" $trainer $pokedet - 0 "was dragged out!"
      }
    } else {
      poke:message forceswitch $move $trainer $pokedet $otrainer $opokedet - 0
      putquick "PRIVMSG $trainer :Please pick a Pokemon (use \"switch pokemonname\" or \"switch pokemonnumber\"): [join $available_list {, }]"
      bind msgm - "*" poke:force_switch
    }
  } else {
    poke:message fail $move $trainer $pokedet $otrainer $opokedet - 0
  }
  return 0
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
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list Fire] [list "Water Veil" "Comatose"] [list BRN] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Fire Punch" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 8 Ice Punch
proc poke:move:icepunch {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list Ice] [list "Magma Armor" "Comatose"] [list FRZ] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Ice Punch" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 9 Thunder Punch
proc poke:move:thunderpunch {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list Electric] [list "Limber" "Comatose"] [list PAR] 10 op 0]
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
    return [poke:movetemplate:default $move $trainer $pokedet $otrainer $opokedet]
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
    return [poke:movetemplate:default $move $trainer $pokedet $otrainer $opokedet]
  }
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
    poke:damagetemplate:recoil $trainer $pokedet $otrainer $opokedet $dmg "went crashing and suffered $dmg damage"
  }
  return $faint
}

# 27 Rolling Kick
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
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list Electric] [list "Limber" "Comatose"] [list PAR] 30 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Body Slam" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
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

# 38 Double-Edge
proc poke:move:double-edge {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Double-Edge" $trainer $pokedet $otrainer $opokedet] faint dmg
  if {$faint != 2} {
    set dmg [expr {int($dmg/3.0)}]
    poke:movetemplate:recoil $trainer $pokedet $otrainer $opokedet $dmg "suffers $dmg of recoil"
  }
  return $faint
}

# 41 Twineedle
proc poke:move:twineedle {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list "mid damage" poke:statustrigger $trainer $pokedet $otrainer $opokedet [list Poison Steel] [list "Immunity" "Comatose"] [list PSN] 30 op 0]
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

# 51 Acid
proc poke:move:acid {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet "" [list "Clear Body" "White Smoke"] [list "SpD -1"] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Acid" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 52 Ember
proc poke:move:ember {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list Fire] [list "Water Veil" "Comatose"] [list BRN] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Ember" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 53 Flamethrower
proc poke:move:flamethrower {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list Fire] [list "Water Veil" "Comatose"] [list BRN] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Flamethrower" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
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
  # add dive hit
  return $faint
}

# 58 Ice Beam
proc poke:move:icebeam {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger FRZ $otrainer $opokedet $trainer $pokedet [list Ice] [list "Magma Armor" "Comatose"] 10]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Ice Beam" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 59 Blizzard
proc poke:move:blizzard {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list Ice] [list "Magma Armor" "Comatose"] [list FRZ] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Blizzard" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 61 Bubble Beam
proc poke:move:bubblebeam {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet "" [list "Clear Body" "White Smoke"] [list "Spd -1"] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Bubble Beam" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 62 Aurora Beam
proc poke:move:aurorabeam {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet "" [list "Clear Body" "White Smoke" "Hyper Cutter"] [list "Atk -1"] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Aurora Beam" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
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

# 70 Strength
proc poke:move:strength {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Strength" $trainer $pokedet $otrainer $opokedet] faint dmg
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
    return [poke:movetemplate:default $move $trainer $pokedet $otrainer $opokedet]
  }
}

# 81 String Shot
proc poke:move:stringshot {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "String Shot" $trainer $pokedet $otrainer $opokedet [list "Spd -1"] op
  return 0
}

# 84 Thunder Shock
proc poke:move:thundershock {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list Electric] [list "Limber" "Comatose"] [list PAR] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Thunder Shock" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 85 Thunderbolt
proc poke:move:thunderbolt {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list Electric] [list "Limber" "Comatose"] [list PAR] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Thunderbolt" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 87 Thunder
proc poke:move:thunder {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list Electric] [list "Limber" "Comatose"] [list PAR] 30 op 0]
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
    return [poke:movetemplate:default $move $trainer $pokedet $otrainer $opokedet]
  }
}

# 94 Psychic
proc poke:move:psychic {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet "" [list "Clear Body" "White Smoke"] [list "SpD -1"] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Psychic" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
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

# 100 Teleport
proc poke:move:teleport {trainer pokedet otrainer opokedet} {
  poke:message fail "Teleport" $trainer $pokedet $otrainer $opokedet - 0
  return 0
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

# 110 Withdraw
proc poke:move:withdraw {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Withdraw" $trainer $pokedet $otrainer $opokedet [list "Def +1"] self
  return 0
}

# 111 Defense Curl
proc poke:move:defensecurl {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Defense Curl" $trainer $pokedet $otrainer $opokedet [list "Def +1"] self
  # Add Rollout boost
  return 0
}

# 112 Barrier
proc poke:move:barrier {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Barrier" $trainer $pokedet $otrainer $opokedet [list "Def +2"] self
  return 0
}

# 121 Egg Bomb
proc poke:move:eggbomb {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Egg Bomb" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 122 Lick
proc poke:move:lick {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list Electric] [list "Limber" "Comatose"] [list PAR] 30 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Lick" $trainer $pokedet $otrainer $opokedet] faint dmg
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
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list Fire] [list "Water Veil" "Comatose"] [list BRN] 10 op 0]
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

# 130 Skull Bash
proc poke:move:skullbash {trainer pokedet otrainer opokedet {charged 1}} {
  global poke
  set move "Skull Bash"
  if {$charged} {
    poke:movetemplate:charge $move $trainer $pokedet $otrainer $opokedet "lowers its head"
    poke:update_pokemon $trainer $pokedet status "add Def 1"
    return 0
  } else {
    return [poke:movetemplate:default $move $trainer $pokedet $otrainer $opokedet]
  }
}

# 131 Spike Cannon
proc poke:move:spikecannon {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:multi "Spike Cannon" $trainer $pokedet $otrainer $opokedet]
}

# 132 Constrict
proc poke:move:constrict {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet "" [list "Clear Body" "White Smoke"] [list "Spd -1"] 10 op 0]
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

# 136 Hi Jump Kick
proc poke:move:hijumpkick {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Hi Jump Kick" $trainer $pokedet $otrainer $opokedet] faint dmg
  if {$faint == 2} {
    set dmg [expr {int($dmg*0.5)}]
    poke:damagetemplate:recoil $trainer $pokedet $otrainer $opokedet $dmg "went crashing and suffered $dmg damage"
  }
  return $faint
}

# 140 Barrage
proc poke:move:barrage {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:multi "Barrage" $trainer $pokedet $otrainer $opokedet]
}

# 143 Sky Attack
proc poke:move:skyattack {trainer pokedet otrainer opokedet {charged 1}} {
  global poke
  set move "Sky Attack"
  if {$charged} {
    poke:movetemplate:charge $move $trainer $pokedet $otrainer $opokedet "is glowing"
    return 0
  } else {
    return [poke:movetemplate:default $move $trainer $pokedet $otrainer $opokedet]
  }
}

# 145 Bubble
proc poke:move:bubble {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet "" [list "Clear Body" "White Smoke"] [list "Spd -1"] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Bubble" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 148 Flash
proc poke:move:flash {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Flash" $trainer $pokedet $otrainer $opokedet [list "Acc -1"] op
  return 0
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

# 154 Fury Swipes
proc poke:move:furyswipes {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:multi "Fury Swipes" $trainer $pokedet $otrainer $opokedet]
}

# 155 Bonemerang
proc poke:move:bonemerang {trainer pokedet otrainer opokedet} {
  set faint [poke:movetemplate:multi "Bonemerang" $trainer $pokedet $otrainer $opokedet 2]
  return $faint 
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

# 165 Struggle
proc poke:move:struggle {trainer pokedet otrainer opokedet} {
  set faint [poke:movetemplate:default "Struggle" $trainer $pokedet $otrainer $opokedet]
  array set pokemon $pokedet
  set recoil [expr {int($pokemon(HP)*0.25)}]
  poke:damagetemplate:recoil $trainer $pokedet $otrainer $opokedet $dmg "suffers $dmg of recoil"
  return $faint
}

# 178 Cotton Spore
proc poke:move:cottonspore {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Cotton Spore" $trainer $pokedet $otrainer $opokedet [list "Spd -2"] op
  return 0
}

# 163 Slash
proc poke:move:slash {trainer pokedet otrainer opokedet} {
  lassign [poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"] - pokedet
  lassign [poke:movetemplate:default "Slash" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
  return $faint
}

# 172 Flame Wheel
proc poke:move:flamewheel {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list Fire] [list "Water Veil" "Comatose"] [list BRN] 10 op 0]
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

# 177 Aeroblast
proc poke:move:aeroblast {trainer pokedet otrainer opokedet} {
  lassign [poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"] - pokedet
  lassign [poke:movetemplate:default "Aeroblast" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
  return $faint
}

# 181 Powder Snow
proc poke:move:powdersnow {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list Ice] [list "Magma Armor" "Comatose"] [list FRZ] 10 op 0]
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

# 189 Mud-Slap
proc poke:move:mud-slap {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet "" [list "Clear Body" "White Smoke"] [list "Acc -1"] 100 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Mud-Slap" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 190 Octazooka
proc poke:move:octazooka {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet "" [list "Clear Body" "White Smoke"] [list "Acc -1"] 50 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Octazooka" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 192 Zap Cannon
proc poke:move:zapcannon {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list Electric] [list "Limber" "Comatose"] [list PAR] 100 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Zap Cannon" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 196 Icy Wind
proc poke:move:icywind {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet "" [list "Clear Body" "White Smoke"] [list "Spd -1"] 100 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Icy Wind" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 198 Bone Rush
proc poke:move:bonerush {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:multi "Bone Rush" $trainer $pokedet $otrainer $opokedet]
}

# 204 Charm
proc poke:move:charm {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Charm" $trainer $pokedet $otrainer $opokedet [list "Atk -2"] op
  return 0
}

# 207 Swagger
proc poke:move:swagger {trainer pokedet otrainer opokedet} {
  global poke
  poke:movetemplate:stats "Swagger" $trainer $pokedet $otrainer $opokedet [list "Atk +2"] op
  poke:statustrigger CON $otrainer $opokedet $trainer $pokedet "" [list "Own Tempo"] 100]
  #lappend poke(triggers) [list launch ]
  return 0
}

# 209 Spark
proc poke:move:spark {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list Electric] [list "Limber" "Comatose"] [list PAR] 30 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Spark" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 211 Steel Wing
proc poke:move:steelwing {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet "" "" [list "Def +1"] 10 self 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Steel Wing" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 221 Sacred Fire
proc poke:move:sacredfire {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list Fire] [list "Water Veil" "Comatose"] [list BRN] 50 op 0]
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

# 224 Megahorn
proc poke:move:megahorn {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Megahorn" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 225 Dragon Breath
proc poke:move:dragonbreath {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list Electric] [list "Limber" "Comatose"] [list PAR] 30 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Dragon Breath" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
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
  set effect [list damage poke:statustrigger $otrainer $opokedet $trainer $pokedet "" [list "Clear Body" "White Smoke"] [list "Def -1"] 30 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Iron Tail" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 232 Metal Claw
proc poke:move:metalclaw {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet "" "" [list "Atk +1"] 10 self 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Metal Claw" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
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
  set effect [list damage poke:statustrigger $otrainer $opokedet $trainer $pokedet "" [list "Clear Body" "White Smoke"] [list "Def -1"] 20 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Crunch" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 245 Extreme Speed
proc poke:move:extremespeed {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Extreme Speed" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 246 Ancient Power
proc poke:move:ancientpower {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet "" "" [list "Atk +1" "Def +1" "SpA +1" "SpD +1" "Spd +1"] 10 self 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Ancient Power" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 247 Shadow Ball
proc poke:move:shadowball {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet "" [list "Clear Body" "White Smoke"] [list "SpD -1"] 20 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Shadow Ball" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 249 Rock Smash
proc poke:move:rocksmash {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet "" [list "Clear Body" "White Smoke"] [list "Def -1"] 50 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Rock Smash" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 257 Heat Wave
proc poke:move:heatwave {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list Fire] [list "Water Veil" "Comatose"] [list BRN] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Heat Wave" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 260 Flatter
proc poke:move:flatter {trainer pokedet otrainer opokedet} {
  global poke
  poke:movetemplate:stats "Flatter" $trainer $pokedet $otrainer $opokedet [list "SpA +2"] op
  poke:statustrigger CON $otrainer $opokedet $trainer $pokedet "" [list "Own Tempo"] 100]
  #lappend poke(triggers) [list launch ]
  return 0
}

# 262 Memento
proc poke:move:memento {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Memento" $trainer $pokedet $otrainer $opokedet [list "Atk -2" "SpA -2"] op
  # self faint
  return 0
}

# 268 Charge
proc poke:move:charge {trainer pokedet otrainer opokedet} {
  global poke
  poke:movetemplate:stats "Charge" $trainer $pokedet $otrainer $opokedet [list "SpD +1"] self
  #lappend poke(trigger) [list launch electric move]
  return 0
}

# 276 Superpower
proc poke:move:superpower {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet "" [list "Clear Body" "White Smoke"] [list "Atk -1" "Def -1"] 100 self 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Super Power" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
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
    return [poke:movetemplate:default $move $trainer $pokedet $otrainer $opokedet]
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

# 297 Feather Dance
proc poke:move:featherdance {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Feather Dance" $trainer $pokedet $otrainer $opokedet [list "Atk -2"] op
  return 0
}

# 299 Blaze Kick
proc poke:move:blazekick {trainer pokedet otrainer opokedet} {
  global poke
  lassign [poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"] - pokedet
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list Fire] [list "Water Veil" "Comatose"] [list BRN] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Blaze Kick" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
  return $faint
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

# 304 Hyper Voice
proc poke:move:hypervoice {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Hyper Voice" $trainer $pokedet $otrainer $opokedet] faint dmg
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

# 319 Metal Sound
proc poke:move:metalsound {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Metal Sound" $trainer $pokedet $otrainer $opokedet [list "SpD -2"] op
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

# 329 Sheer Cold
proc poke:move:sheercold {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:ohko "Sheer Cold" $trainer $pokedet $otrainer $opokedet]
}

# 331 Bullet Seed
proc poke:move:bulletseed {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:multi "Bullet Seed" $trainer $pokedet $otrainer $opokedet]
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
    return [poke:movetemplate:default $move $trainer $pokedet $otrainer $opokedet]
  }
}

# 344 Volt Tackle
proc poke:move:volttackle {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list Electric] [list "Limber" "Comatose"] [list PAR] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Volt Tackle" $trainer $pokedet $otrainer $opokedet] faint dmg
  if {$faint != 2} {
    set dmg [expr {int($dmg/3.0)}]
    poke:movetemplate:recoil $trainer $pokedet $otrainer $opokedet $dmg "suffers $dmg of recoil"
  }
  set poke(triggers) [lreplace $poke(triggers) end end]
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
  poke:movetemplate:stats "Dragon Dance" $trainer $pokedet $otrainer $opokedet [list "Atk +1" "Spd +1" self
  return 0
}

# 350 Rock Blast
proc poke:move:rockblast {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:multi "Rock Blast" $trainer $pokedet $otrainer $opokedet]
}

# 367 Acupressure
proc poke:move:acupressure {trainer pokedet otrainer opokedet} {
  set stats [list Atk Def SpA SpD Spd Acc Eva]
  poke:random
  set stat [lindex $stats [rand 7]]
  poke:movetemplate:stats "Acupressure" $trainer $pokedet $otrainer $opokedet [list "Atk +2"] self
  return 0
}

# 392 Force Palm
proc poke:move:forcepalm {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list Electric] [list "Limber" "Comatose"] [list PAR] 30 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Force Palm" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 394 Flare Blitz
proc poke:move:flareblitz {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list Electric] [list "Water Veil" "Comatose"] [list BRN] 10 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Flare Blitz" $trainer $pokedet $otrainer $opokedet] faint dmg
  if {$faint != 2} {
    set dmg [expr {int($dmg/3.0)}]
    poke:movetemplate:recoil $trainer $pokedet $otrainer $opokedet $dmg "suffers $dmg of recoil"
  }
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 397 Rock Polish
proc poke:move:rockpolish {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Rock Polish" $trainer $pokedet $otrainer $opokedet [list "Spd +2"] self
  return 0
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
  lassign [poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"] - pokedet
  lassign [poke:movetemplate:default "Night Slash" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
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

# 410 Vacuum Wave
proc poke:move:vacuumwave {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Vacuum Wave" $trainer $pokedet $otrainer $opokedet] faint dmg
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
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list Electric] [list "Limber" "Comatose"] [list PAR] 10 op 0]
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
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list Ice] [list "Magma Armor" "Comatose"] [list FRZ] 10 op 0]
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
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list Fire] [list "Water Veil" "Comatose"] [list BRN] 10 op 0]
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

# 432 Defog
proc poke:move:defog {trainer pokedet otrainer opokedet} {
  global poke
  poke:movetemplate:stats "Defog" $trainer $pokedet $otrainer $opokedet [list "Eva -1"] op
  #remove hazards & opponent field stuff
  return 0
}

# 436 Lava Plume
proc poke:move:lavaplume {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list Fire] [list "Water Veil" "Comatose"] [list BRN] 30 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Lava Plume" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 438 Power Whip
proc poke:move:powerwhip {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Power Whip" $trainer $pokedet $otrainer $opokedet] faint dmg
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
    poke:message fail $move $trainer $pokedet $otrainer $opokedet - 0
  }
  return 0
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

# 460 Spacial Rend
proc poke:move:spacialrend {trainer pokedet otrainer opokedet} {
  lassign [poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"] - pokedet
  lassign [poke:movetemplate:default "Spacial Rend" $trainer $pokedet $otrainer $opokedet] faint dmg
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
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
    return [poke:movetemplate:default $move $trainer $pokedet $otrainer $opokedet]
  }
}

# 468 Hone Claws
proc poke:move:honeclaws {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Hone Claws" $trainer $pokedet $otrainer $opokedet [list "Atk +1" "Acc +1"] self
  return 0
}

# 475 Autotomize
proc poke:move:autotomize {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Autotomize" $trainer $pokedet $otrainer $opokedet [list "Spd +1"] self
  # poke:update_pokemon half weight
  return 0
}

# 483 Quiver Dance
proc poke:move:quiverdance {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Quiver Dance" $trainer $pokedet $otrainer $opokedet [list "SpA +1" "SpD +1" "Spd +1"] self
  return 0
}

# 489 Coil
proc poke:move:coil {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Coil" $trainer $pokedet $otrainer $opokedet [list "Atk +1" "Def +1" "Acc +1" self
  return 0
}

# 503 Scald
proc poke:move:scald {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list Fire] [list "Water Veil" "Comatose"] [list BRN] 30 op 0]
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

# 508 Shift Gear
proc poke:move:shiftgear {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Shift Gear" $trainer $pokedet $otrainer $opokedet [list "Atk +1" "Spd +2"] self
  return 0
}

# 517 Inferno
proc poke:move:inferno {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list Fire] [list "Water Veil" "Comatose"] [list BRN] 100 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Inferno" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 526 Work Up
proc poke:move:workup {trainer pokedet otrainer opokedet} {
  poke:movetemplate:stats "Work Up" $trainer $pokedet $otrainer $opokedet [list "Atk +1" "SpA +1"] self
  return 0
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

# 537 Steamroller
proc poke:move:steamroller {trainer pokedet otrainer opokedet} {
  global poke
  lassign [poke:movetemplate:default "Steam Roller" $trainer $pokedet $otrainer $opokedet] faint dmg
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

# 541 Tail Slap
proc poke:move:tailslap {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:multi "Tail Slap" $trainer $pokedet $otrainer $opokedet]
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
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list Fire] [list "Water Veil" "Comatose"] [list BRN] 30 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Searing Shot" $trainer $pokedet $otrainer $opokedet] faint dmg
  set poke(triggers) [lreplace $poke(triggers) end end]
  return $faint
}

# 551 Blue Flare
proc poke:move:blueflare {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list Fire] [list "Water Veil" "Comatose"] [list BRN] 20 op 0]
  lappend poke(triggers) $effect
  lassign [poke:movetemplate:default "Blue Flare" $trainer $pokedet $otrainer $opokedet] faint dmg
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
    set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list Fire] [list "Water Veil" "Comatose"] [list BRN] 30 op 0]
    lappend poke(triggers) $effect
    lassign [poke:movetemplate:default "Ice Burn" $trainer $pokedet $otrainer $opokedet] faint dmg
    set poke(triggers) [lreplace $poke(triggers) end end]
    return $faint
  }
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

# 566 Phantom Force
proc poke:move:phantomforce {trainer pokedet otrainer opokedet {charged 1}} {
  global poke
  set move "Phantom Force"
  if {$charged} {
    poke:update_pokemon $trainer $pokedet add "dimensionbound"
    poke:movetemplate:charge $move $trainer $pokedet $otrainer $opokedet "vanished"
    return 0
  } else {
    return [poke:movetemplate:default $move $trainer $pokedet $otrainer $opokedet]
  }
}

# 572 Petal Blizzard
proc poke:move:petalblizzard {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Petal Blizzard" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 586 Boomburst
proc poke:move:boomburst {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Boomburst" $trainer $pokedet $otrainer $opokedet] faint dmg
  return $faint
}

# 592 Steam Eruption
proc poke:move:steameruption {trainer pokedet otrainer opokedet} {
  global poke
  set effect [list damage poke:statustrigger $trainer $pokedet $otrainer $opokedet [list Fire] [list "Water Veil" "Comatose"] [list BRN] 30 op 0]
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

# 605 Dazzling Gleam
proc poke:move:dazzlinggleam {trainer pokedet otrainer opokedet} {
  lassign [poke:movetemplate:default "Dazzling Gleam" $trainer $pokedet $otrainer $opokedet] faint dmg
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
