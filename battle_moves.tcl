# Template for default moves
proc poke:movetemplate:default {move trainer pokedet otrainer opokedet} {
  global poke
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff contact]
  array set opokemon $opokedet
  array set pokemon $pokedet
  poke:trigger launch $otrainer $opokedet $trainer $pokedet
  lassign [poke:damage_calc $pokedet $opokedet $bp $acc $type $class $flags] dmgtype dmg crit
  if {$dmgtype in {"miss" "no effect"}} {
    poke:message $dmgtype $move $trainer $pokedet $otrainer $opokedet $dmg $crit
    return 2
  }
  poke:update_pokemon $otrainer $opokedet "cHP" -$dmg
  set ppdown 1
  if {$opokemon(ability) eq "Pressure"} {incr ppdown}
  poke:update_pokemon $trainer $pokedet "Move" "-$ppdown $move"
  poke:trigger damage $otrainer $opokedet $trainer $pokedet
  set faint [poke:message $dmgtype $move $trainer $pokedet $otrainer $opokedet $dmg $crit]
  if {$contact == 1} {poke:trigger contact $otrainer $opokedet $trainer $pokedet}
  return $faint
}

# Template for multihit moves
proc poke:movetemplate:multi {move trainer pokedet otrainer opokedet} {
  global poke
  set table moveDetails$poke(gen)
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff contact]
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
  poke:message multstart $move $trainer $pokedet $otrainer $opokedet - 0
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
        poke:trigger damage $otrainer $opokedet $trainer $pokedet
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
  poke:trigger "last damage" $otrainer $opokedet $trainer $pokedet
  poke:message multlast $move $trainer $pokedet $otrainer $opokedet - 0
  if {$faint} {poke:faint $otrainer}
  return $faint
}

# Template for moves with status ailments effects and damage
proc poke:movetemplate:dmgailment {move trainer pokedet otrainer opokedet immunetypes immuneabilities chance status} {
  global poke
  set faint [poke:movetemplate:default $move $trainer $pokedet $otrainer $opokedet]
  puts here
  array set opokemon $opokedet
  set immunity 0
  foreach type $immunetypes {
    if {[string match "*$type*" $opokemon(type)]} {
      incr immunity
      break
    }
  }
  if {!$immunity} {
    foreach ability $immuneabilities {
      if {$ability eq $opokemon(type)} {
        incr immunity
        break
      }
    }
  }
  
  if {!$faint && !$immunity} {
    poke:random
    set test [rand 100]
    if {$test < $chance} {
      poke:update_pokemon $otrainer $opokedet status [string toupper $status]
      lappend poke(prio-10) [list $opokemon(Spd) poke:status $status $otrainer $opokedet $trainer $pokedet]
      poke:message $status - $trainer $pokedet $otrainer $opokedet - -
    }
  }
  return $faint
}

# Template for moves that need charging
proc poke:movetemplate:charge {move trainer pokedet otrainer} {
  global poke
  array set pokemon $pokedet
  set trainerID [lsearch -index 0 $poke(team) $trainer]
  set pokeID [lsearch -regexp [lindex $poke(team) $trainerID 1] "\\yspecies \\{?$pokemon(species)\\y\\}?"]
  set opponentID [lsearch $poke(currentPoke) $otrainer]
  lappend poke(pending) [list 0 $pokemon(Spd) "poke:move:[string tolower [join $move {}]]" $trainer $pokemon(species) $trainerID $pokeID $opponentID 0]
  puts $poke(pending)
  putquick "PRIVMSG $poke(chan) :$trainer's $pokemon(species) is charging!"
  putquick "PRIVMSG $trainer :$pokemon(species) is charging!"
  putquick "PRIVMSG $otrainer :Foe $pokemon(species) is charging!"
  incr poke(battleready)
  lappend poke(ready) $trainer
  return 0
}

# Template for OHKO moves
proc poke:movetemplate:ohko {move trainer pokedet otrainer} {
  global poke
  set movedet [dex eval "SELECT * FROM $table WHERE name = '$move'"]
  set flags [lassign $movedet id name type class pp bp acc prio eff contact]
  set weak [poke:get_weakness $type $opokemon(type)]
  switch -regexp $weak {
    {^0$} {set dmgtype "no effect"}
    {^(?:2|4)$} {set dmgtype "super effective"}
    default {set dmgtype "normal"}
  }
  
  if {$opokemon(ability) eq "Sturdy"} {
    putquick "PRIVMSG $poke(chan) :$trainer's $pokemon(species) used $move! $trainer's $opokemon(species) is protected by Sturdy!"
    putquick "PRIVMSG $trainer :$pokemon(species) used $move! It's a OHKO! Foe $opokemon(species) is protected by Sturdy!"
    putquick "PRIVMSG $otrainer :$trainer's $pokemon(species) used $move! $opokemon(species) is protected by Sturdy!"
    return 0
  }
  
  poke:random
  set test [rand 100]
  if {$weak > 0 && $test < $acc} {
    set result "ohko"
    array set opokemon $opokedet
    poke:update_pokemon $otrainer $opokedet "cHP" -$opokemon(cHP)
    set result [poke:trigger damage $otrainer $opokedet $trainer $pokedet]
    set faint [poke:message $result $move $trainer $pokedet $otrainer $opokedet - 0]
    return $faint   
  } elseif {$weak > 0 && $test > $acc} {
    poke:message miss $move $trainer $pokedet $otrainer $opokedet - 0
  } else {
    poke:message "no effect" $move $trainer $pokedet $otrainer $opokedet - 0
  }
  return 0
}

# 1 Pound
proc poke:move:pound {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:default "Pound" $trainer $pokedet $otrainer $opokedet]
}

# 2 Karate Chop
proc poke:move:karatechop {trainer pokedet otrainer opokedet} {
  lassign [poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"] - pokedet
  set faint [poke:movetemplate:default "Karate Chop" $trainer $pokedet $otrainer $opokedet]
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
  return [poke:movetemplate:default "Mega Punch" $trainer $pokedet $otrainer $opokedet]
}

# 6 Pay Day
proc poke:move:payday {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:default "Pay Day" $trainer $pokedet $otrainer $opokedet]
}

# 7 Fire Punch
proc poke:move:firepunch {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:dmgailment "Fire Punch" $trainer $pokedet $otrainer $opokedet [list Fire] [list "Water Veil" "Comatose"] 10 brn]
}

# 8 Ice Punch
proc poke:move:icepunch {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:dmgailment "Ice Punch" $trainer $pokedet $otrainer $opokedet [list Ice] [list "Magma Armor" "Comatose"] 10 frz]
}

# 9 Thunder Punch
proc poke:move:thunderpunch {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:dmgailment "Thunder Punch" $trainer $pokedet $otrainer $opokedet [list Electric] [list "Limber" "Comatose"] 10 par]
}

# 10 Scratch
proc poke:move:scratch {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:default "Scratch" $trainer $pokedet $otrainer $opokedet]
}

# 11 Vice Grip
proc poke:move:vicegrip {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:default "Vice Grip" $trainer $pokedet $otrainer $opokedet]
}

# 15 Cut
proc poke:move:cut {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:default "Cut" $trainer $pokedet $otrainer $opokedet]
}

# 17 Wing Attack
proc poke:move:wingattack {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:default "Wing Attack" $trainer $pokedet $otrainer $opokedet]
}

# 21 Slam
proc poke:move:slam {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:default "Slam" $trainer $pokedet $otrainer $opokedet]
}

# 22 Vine Whip
proc poke:move:vinewhip {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:default "Vine Whip" $trainer $pokedet $otrainer $opokedet]
}

# 25 Mega Kick
proc poke:move:megakick {trainer pokedet otrainer opokedet} {
return [poke:movetemplate:default "Mega Kick" $trainer $pokedet $otrainer $opokedet]
}

# 30 Horn Attack
proc poke:move:hornattack {trainer pokedet otrainer opokedet} {
return [poke:movetemplate:default "Horn Attack" $trainer $pokedet $otrainer $opokedet]
}

# 31 Fury Attack
proc poke:move:furyattack {trainer pokedet otrainer opokedet} {
return [poke:movetemplate:multi "Fury Attack" $trainer $pokedet $otrainer $opokedet]
}

# 33 Tackle
proc poke:move:tackle {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:default "Tackle" $trainer $pokedet $otrainer $opokedet]
}

# 34 Body Slam
proc poke:move:bodyslam {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:dmgailment "Body Slam" $trainer $pokedet $otrainer $opokedet [list Electric] [list "Limber" "Comatose"] 30 par]
}

# 42 Pin Missle
proc poke:move:pinmissile {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:multi "Pin Missile" $trainer $pokedet $otrainer $opokedet]
}

# 52 Ember
proc poke:move:ember {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:dmgailment "Ember" $trainer $pokedet $otrainer $opokedet [list Fire] [list "Water Veil" "Comatose"] 10 brn]
}

# 53 Flamethrower
proc poke:move:flamethrower {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:dmgailment "Flamethrower" $trainer $pokedet $otrainer $opokedet [list Fire] [list "Water Veil" "Comatose"] 10 brn]
}

# 55 Water Gun
proc poke:move:watergun {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:default "Water Gun" $trainer $pokedet $otrainer $opokedet]
}

# 56 Hydro Pump
proc poke:move:hydropump {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:default "Hydro Pump" $trainer $pokedet $otrainer $opokedet]
}

# 58 Ice Beam
proc poke:move:icebeam {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:dmgailment "Ice Beam" $trainer $pokedet $otrainer $opokedet [list Ice] [list "Magma Armor" "Comatose"] 10 frz]
}

# 59 Blizzard
proc poke:move:blizzard {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:dmgailment "Blizzard" $trainer $pokedet $otrainer $opokedet [list Ice] [list "Magma Armor" "Comatose"] 10 frz]
}

# 64 Peck
proc poke:move:peck {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:default "Peck" $trainer $pokedet $otrainer $opokedet]
}

# 65 Drill Peck
proc poke:move:drillpeck {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:default "Drill Peck" $trainer $pokedet $otrainer $opokedet]
}

# 70 Strength
proc poke:move:strength {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:default "Strength" $trainer $pokedet $otrainer $opokedet]
}

# 75 Razor Leaf
proc poke:move:razorleaf {trainer pokedet otrainer opokedet} {
  lassign [poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"] - pokedet
  set faint [poke:movetemplate:default "Razor Leaf" $trainer $pokedet $otrainer $opokedet]
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
  return $faint
}

# 84 Thunder Shock
proc poke:move:thundershock {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:dmgailment "Thunder Shock" $trainer $pokedet $otrainer $opokedet [list Electric] [list "Limber" "Comatose"] 10 par]
}

# 85 Thunderbolt
proc poke:move:thunderbolt {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:dmgailment "Thunderbolt" $trainer $pokedet $otrainer $opokedet [list Electric] [list "Limber" "Comatose"] 10 par]
}

# 87 Thunder
proc poke:move:thunder {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:dmgailment "Thunder" $trainer $pokedet $otrainer $opokedet [list Electric] [list "Limber" "Comatose"] 30 par]
}

# 88 Rock Throw
proc poke:move:rockthrow {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:default "Rock Throw" $trainer $pokedet $otrainer $opokedet]
}

# 98 Quick Attack
proc poke:move:quickattack {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:default "Quick Attack" $trainer $pokedet $otrainer $opokedet]
}

# 121 Egg Bomb
proc poke:move:eggbomb {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:default "Egg Bomb" $trainer $pokedet $otrainer $opokedet]
}

# 122 Lick
proc poke:move:lick {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:dmgailment "Lick" $trainer $pokedet $otrainer $opokedet [list Electric] [list "Limber" "Comatose"] 30 par]
}

# 126 Fire Blast
proc poke:move:fireblast {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:dmgailment "Fire Blast" $trainer $pokedet $otrainer $opokedet [list Fire] [list "Water Veil" "Comatose"] 10 brn]
}

# 131 Spike Cannon
proc poke:move:spikecannon {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:multi "Spike Cannon" $trainer $pokedet $otrainer $opokedet]
}

# 140 Barrage
proc poke:move:barrage {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:multi "Barrage" $trainer $pokedet $otrainer $opokedet]
}

# 152 Crabhammer
proc poke:move:crabhammer {trainer pokedet otrainer opokedet} {
  lassign [poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"] - pokedet
  set faint [poke:movetemplate:default "Crabhammer" $trainer $pokedet $otrainer $opokedet]
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
  return $faint
}

# 154 Fury Swipes
proc poke:move:furyswipes {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:multi "Fury Swipes" $trainer $pokedet $otrainer $opokedet]
}

# 181 Powder Snow
proc poke:move:powdersnow {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:dmgailment "Powder Snow" $trainer $pokedet $otrainer $opokedet [list Ice] [list "Magma Armor" "Comatose"] 10 frz]
}

# 163 Slash
proc poke:move:slash {trainer pokedet otrainer opokedet} {
  lassign [poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"] - pokedet
  set faint [poke:movetemplate:default "Slash" $trainer $pokedet $otrainer $opokedet]
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
  return $faint
}

# 172 Flame Wheel
proc poke:move:flamewheel {trainer pokedet otrainer opokedet} {
  set faint [poke:movetemplate:dmgailment "Flame Wheel" $trainer $pokedet $otrainer $opokedet [list Fire] [list "Water Veil" "Comatose"] 10 brn]
  array set pokemon $pokedet
  if {"FRZ" in $pokemon(status)} {
    poke:update_pokemon $trainer $pokedet status "rem FRZ"
    poke:message thaw - $trainer $pokedet $otrainer $opokedet - 0
  }
  return $faint
}

# 177 Aeroblast
proc poke:move:aeroblast {trainer pokedet otrainer opokedet} {
  lassign [poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"] - pokedet
  set faint [poke:movetemplate:default "Aeroblast" $trainer $pokedet $otrainer $opokedet]
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
  return $faint
}

# 183 Mach Punch
proc poke:move:machpunch {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:default "Mach Punch" $trainer $pokedet $otrainer $opokedet]
}

# 192 Zap Cannon
proc poke:move:zapcannon {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:dmgailment "Zap Cannon" $trainer $pokedet $otrainer $opokedet [list Electric] [list "Limber" "Comatose"] 100 par]
}

# 198 Bone Rush
proc poke:move:bonerush {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:multi "Bone Rush" $trainer $pokedet $otrainer $opokedet]
}

# 209 Spark
proc poke:move:spark {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:dmgailment "Spark" $trainer $pokedet $otrainer $opokedet [list Electric] [list "Limber" "Comatose"] 30 par]
}

# 221 Sacred Fire
proc poke:move:sacredfire {trainer pokedet otrainer opokedet} {
  set faint [poke:movetemplate:dmgailment "Sacred Fire" $trainer $pokedet $otrainer $opokedet [list Fire] [list "Water Veil" "Comatose"] 50 brn]
  array set pokemon $pokedet
  if {"FRZ" in $pokemon(status)} {
    poke:update_pokemon $trainer $pokedet status "rem FRZ"
    poke:message thaw - $trainer $pokedet $otrainer $opokedet - 0
  }
  return $faint
}

# 224 Megahorn
proc poke:move:megahorn {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:default "Megahorn" $trainer $pokedet $otrainer $opokedet]
}

# 225 Dragon Breath
proc poke:move:dragonbreath {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:dmgailment "Dragon Breath" $trainer $pokedet $otrainer $opokedet [list Electric] [list "Limber" "Comatose"] 30 par]
}

# 238 Cross Chop
proc poke:move:crosschop {trainer pokedet otrainer opokedet} {
  lassign [poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"] - pokedet
  set faint [poke:movetemplate:default "Cross Chop" $trainer $pokedet $otrainer $opokedet]
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
  return $faint
}

# 245 Extreme Speed
proc poke:move:extremespeed {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:default "Extreme Speed" $trainer $pokedet $otrainer $opokedet]
}

# 257 Heat Wave
proc poke:move:heatwave {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:dmgailment "Heat Wave" $trainer $pokedet $otrainer $opokedet [list Fire] [list "Water Veil" "Comatose"] 10 brn]
}

# 292 Arm Thrust
proc poke:move:armthrust {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:multi "Arm Thrust" $trainer $pokedet $otrainer $opokedet]
}

# 299 Blaze Kick
proc poke:move:blazekick {trainer pokedet otrainer opokedet} {
  lassign [poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"] - pokedet
  set faint [poke:movetemplate:dmgailment "Blaze Kick" $trainer $pokedet $otrainer $opokedet [list Fire] [list "Water Veil" "Comatose"] 10 brn]
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
  return $faint
}

# 304 Hyper Voice
proc poke:move:hypervoice {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:default "Hyper Voice" $trainer $pokedet $otrainer $opokedet]
}

# 314 Air Cutter
proc poke:move:aircutter {trainer pokedet otrainer opokedet} {
  lassign [poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"] - pokedet
  set faint [poke:movetemplate:default "Air Cutter" $trainer $pokedet $otrainer $opokedet]
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
  return $faint
}

# 331 Bullet Seed
proc poke:move:bulletseed {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:multi "Bullet Seed" $trainer $pokedet $otrainer $opokedet]
}

# 333 Icicle Spear
proc poke:move:iciclespear {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:multi "Icicle Spear" $trainer $pokedet $otrainer $opokedet]
}

# 337 Dragon Claw
proc poke:move:dragonclaw {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:default "Dragon Claw" $trainer $pokedet $otrainer $opokedet]
}

# 348 Leaf Blade
proc poke:move:leafblade {trainer pokedet otrainer opokedet} {
  lassign [poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"] - pokedet
  set faint [poke:movetemplate:default "Leaf Blade" $trainer $pokedet $otrainer $opokedet]
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
  return $faint
}

# 350 Rock Blast
proc poke:move:rockblast {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:multi "Rock Blast" $trainer $pokedet $otrainer $opokedet]
}

# 392 Force Palm
proc poke:move:forcepalm {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:dmgailment "Force Palm" $trainer $pokedet $otrainer $opokedet [list Electric] [list "Limber" "Comatose"] 30 par]
}

# 400 Night Slash
proc poke:move:nightslash {trainer pokedet otrainer opokedet} {
  lassign [poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"] - pokedet
  set faint [poke:movetemplate:default "Night Slash" $trainer $pokedet $otrainer $opokedet]
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
  return $faint
}

# 401 Aqua Tail
proc poke:move:aquatail {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:default "Aqua Tail" $trainer $pokedet $otrainer $opokedet]
}

# 402 Seed Bomb
proc poke:move:seedbomb {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:default "Seed Bomb" $trainer $pokedet $otrainer $opokedet]
}

# 404 X-Scissor
proc poke:move:x-scissor {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:default "X-Scissor" $trainer $pokedet $otrainer $opokedet]
}

# 406 Dragon Pulse
proc poke:move:dragonpulse {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:default "Dragon Pulse" $trainer $pokedet $otrainer $opokedet]
}

# 408 Power Gem
proc poke:move:powergem {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:default "Power Gem" $trainer $pokedet $otrainer $opokedet]
}

# 410 Vacuum Wave
proc poke:move:vacuumwave {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:default "Vacuum Wave" $trainer $pokedet $otrainer $opokedet]
}

# 418 Bullet Punch
proc poke:move:bulletpunch {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:default "Bullet Punch" $trainer $pokedet $otrainer $opokedet]
}

# 420 Ice Shard
proc poke:move:iceshard {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:default "Ice Shard" $trainer $pokedet $otrainer $opokedet]
}

# 421 Shadow Claw
proc poke:move:shadowclaw {trainer pokedet otrainer opokedet} {
  lassign [poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"] - pokedet
  set faint [poke:movetemplate:default "Shadow Claw" $trainer $pokedet $otrainer $opokedet]
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
  return $faint
}

# 422 Thunder Fang
proc poke:move:lick {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:dmgailment "Thunder Fang" $trainer $pokedet $otrainer $opokedet [list Electric] [list "Limber" "Comatose"] 10 par]
  poke:random
  set test [rand 100]
  if {$rand < 10} {
    poke:flinch $otrainer $opokedet 0
  }
  return $faint
}

# 423 Ice Fang
proc poke:move:icefang {trainer pokedet otrainer opokedet} {
  set faint [poke:movetemplate:dmgailment "Ice Fang" $trainer $pokedet $otrainer $opokedet [list Ice] [list "Magma Armor" "Comatose"] 10 frz]
  poke:random
  set test [rand 100]
  if {$rand < 10} {
    poke:flinch $otrainer $opokedet 0
  }
  return $faint
}

# 424 Fire Fang
proc poke:move:firefang {trainer pokedet otrainer opokedet} {
  set faint [poke:movetemplate:dmgailment "Fire Fang" $trainer $pokedet $otrainer $opokedet [list Fire] [list "Water Veil" "Comatose"] 10 brn]
  poke:random
  set test [rand 100]
  if {$rand < 10} {
    poke:flinch $otrainer $opokedet 0
  }
  return $faint
}

# 425 Shadow Sneak
proc poke:move:shadowsneak {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:default "Shadow Sneak" $trainer $pokedet $otrainer $opokedet]
}

# 427 Psycho Cut
proc poke:move:psychocut {trainer pokedet otrainer opokedet} {
  lassign [poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"] - pokedet
  set faint [poke:movetemplate:default "Psycho Cut" $trainer $pokedet $otrainer $opokedet]
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
  return $faint
}

# 436 Lava Plume
proc poke:move:lavaplume {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:dmgailment "Lava Plume" $trainer $pokedet $otrainer $opokedet [list Fire] [list "Water Veil" "Comatose"] 30 brn]
}

# 438 Power Whip
proc poke:move:powerwhip {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:default "Power Whip" $trainer $pokedet $otrainer $opokedet]
}

# 444 Stone Edge
proc poke:move:stoneedge {trainer pokedet otrainer opokedet} {
  lassign [poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"] - pokedet
  set faint [poke:movetemplate:default "Stone Edge" $trainer $pokedet $otrainer $opokedet]
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
  return $faint
}

# 453 Aqua Jet
proc poke:move:aquajet {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:default "Aqua Jet" $trainer $pokedet $otrainer $opokedet]
}

# 454 Attack Order
proc poke:move:attackorder {trainer pokedet otrainer opokedet} {
  lassign [poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"] - pokedet
  set faint [poke:movetemplate:default "Attack Order" $trainer $pokedet $otrainer $opokedet]
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
  return $faint
}

# 460 Spacial Rend
proc poke:move:spacialrend {trainer pokedet otrainer opokedet} {
  lassign [poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"] - pokedet
  set faint [poke:movetemplate:default "Spacial Rend" $trainer $pokedet $otrainer $opokedet]
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
  return $faint
}

# 503 Scald
proc poke:move:scald {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:dmgailment "Scald" $trainer $pokedet $otrainer $opokedet [list Fire] [list "Water Veil" "Comatose"] 30 brn]
}

# 517 Inferno
proc poke:move:inferno {trainer pokedet otrainer opokedet} {
    return [poke:movetemplate:dmgailment "Ember" $trainer $pokedet $otrainer $opokedet [list Fire] [list "Water Veil" "Comatose"] 100 brn]
}

# 529 Drill Run
proc poke:move:drillrun {trainer pokedet otrainer opokedet} {
  lassign [poke:update_pokemon $trainer $pokedet "status" "add tempCrit 1"] - pokedet
  set faint [poke:movetemplate:default "Drill Run" $trainer $pokedet $otrainer $opokedet]
  poke:update_pokemon $trainer $pokedet "status" "rem tempCrit -1"
  return $faint
}

# 541 Tail Slap
proc poke:move:tailslap {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:multi "Tail Slap" $trainer $pokedet $otrainer $opokedet]
}

# 545 Searing Shot
proc poke:move:searingshot {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:dmgailment "Searing Shot" $trainer $pokedet $otrainer $opokedet [list Fire] [list "Water Veil" "Comatose"] 30 brn]
}

# 551 Blue Flare
proc poke:move:blueflare {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:dmgailment "Blue Flare" $trainer $pokedet $otrainer $opokedet [list Fire] [list "Water Veil" "Comatose"] 20 brn]
}

# 554 Ice Burn
proc poke:move:iceburn {trainer pokedet otrainer opokedet {charged 1}} {
  global poke
  set move "Ice Burn"
  if {$charged} {
    poke:movetemplate:charge $move $trainer $pokedet $otrainer
    return 0
  } else {
    return [poke:movetemplate:dmgailment $move $trainer $pokedet $otrainer $opokedet [list Fire] [list "Water Veil" "Comatose"] 30 brn]
  }
}

# 572 Petal Blizzard
proc poke:move:petalblizzard {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:default "Petal Blizzard" $trainer $pokedet $otrainer $opokedet]
}

# 586 Boomburst
proc poke:move:boomburst {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:default "Boomburst" $trainer $pokedet $otrainer $opokedet]
}

# 592 Steam Eruption
proc poke:move:steameruption {trainer pokedet otrainer opokedet} {
  set faint [poke:movetemplate:dmgailment "Steam Eruption" $trainer $pokedet $otrainer $opokedet [list Fire] [list "Water Veil" "Comatose"] 30 brn]
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
  return [poke:movetemplate:default "Dazzling Gleam" $trainer $pokedet $otrainer $opokedet]
}

# 616 Land's Wrath
proc poke:move:land'swrath {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:default "Land's Wrath" $trainer $pokedet $otrainer $opokedet]
}

# 618 Origin Pulse
proc poke:move:originpulse {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:default "Origin Pulse" $trainer $pokedet $otrainer $opokedet]
}

# 619 Precipice Blades
proc poke:move:precipiceblades {trainer pokedet otrainer opokedet} {
  return [poke:movetemplate:default "Precipice Blades" $trainer $pokedet $otrainer $opokedet]
}
