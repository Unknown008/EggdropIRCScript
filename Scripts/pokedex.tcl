##
# Pokedex Mode
##
set pokedex(version)  "0.3"
set pokedex(usage)    "Usage: !pokedex ?next|search? \[pokemon\]"
set pokedex(logo)     "\003-Pokédex-\003"
set pokedex(gen)      6
set pokedex(restrict) "#pro-support"

### Package
package require sqlite3
sqlite3 dex pokedexdb

### Binds
bind pub - "!pokedex" basic:pokedex
bind msg - "!pokedex" basic:pokedex

### Procedures
proc basic:pokedex {nick host hand args} {
  global pokedex
  if {[string index [lindex $args 0] 0] eq "#"} {
    set args [lindex [lassign $args dest] 0]
    if {$dest in $pokedex(restrict)} {return}
  } else {
    set dest $nick
  }
  switch [lindex $args 0] {
    search {
      set arg [lindex $args 1]
      set result [search:pokedex [join $arg { }]]
    }
    next {
      set arg [lassign $args type]
      set result [get:pokemon $type [join $arg { }]]
    }
    random {
      set flags [lassign $args cmd num]
      set result [random:pokemon $num {*}$flags]
    }
    query {
      set arg [lindex $args 1]
      set result [query:pokemon $nick $arg]
      return
    }
    default {
      if {[llength $args] == 0} {
        putquick "NOTICE $nick :$pokedex(usage)"
        return
      }
      set result [get:pokemon normal [join $args { }]]
    }
  }
  set result [lindex [lassign $result mode] 0]
  switch $mode {
    0 {
      putquick "PRIVMSG $dest :[join $result { }]."
    }
    1 {
      putquick "PRIVMSG $dest :$pokedex(logo) [join $result { }]."
    }
    2 {
      set prefix "$pokedex(logo) Results: "
      set suffix ","
      for {set i 0} {[llength $result] > $i} {incr i 40} {
        if {$i > 0} {set prefix ""}
        if {[expr {$i+40}] >= [llength $result]} {
          set idx end
          set suffix ""
        } else {
          set idx [expr {$i+39}]
        }
        set group [lrange $result $i $idx]
        putquick "PRIVMSG $dest :$prefix[join $group {, }]$suffix"
      }
    }
  }
}

proc get:pokemon {state arg} {
  global pokedex
  # modes
  # 0 - no results found
  # 1 - results obtained
  set mode 0
  set table pokeDetails$pokedex(gen)
  set result [dex eval "SELECT * FROM $table WHERE lower(formname) = lower('$arg')"]
  if {[llength $result] > 0} {
    set mode 1
    lassign $result id pokemon formname type genus ability ability2 hability gender \
      egggroup height weight legend evolve_cond hp atk def spatk spdef spd capture final \
      stage effort hatch_counter happiness exp forms colour base_exp

    if {$state eq "normal"} {
      if {$ability2 ne ""} {append ability "\003/\00302$ability2"}
      if {$hability ne ""} {append ability "\003/\00304$hability"}
      set total [expr {$hp+$atk+$def+$spatk+$spdef+$spd}]
      
      return [list $mode "$id: $formname, $type-type Pokémon with \00302$ability\003. \00303$hp\003\/\00310$atk\003\/\00310$def\003\/\00313$spatk\003\/\00313$spdef\003\/\00308$spd\003; total $total"]
    } elseif {$state eq "next"} {
      set quart ""
      
      while {$effort != 0} {
        set mod [expr {$effort%4}]
        set effort [expr {$effort/4}]
        set quart "$mod$quart"
      }
      set quart [string range [string reverse [format %06d $quart]] 0 5]
      lassign [split $quart ""] hp atk def spd satk sdef
      
      if {$gender ne "N/A"} {
        lassign [split $gender "/"] mr fr
        set gender "\00302$mr\003\/\00305$fr\003"
      }
      set grw [lindex {"Medium fast" "Slow then very fast" "Fast then very slow" "Medium slow" "Fast" "Slow"} $exp]
      set texp [lindex {"1,000,000" "600,000" "1,640,000" "1,059,860" "800,000" "1,250,000"} $exp]
      return [list $mode "$id: $formname \($genus Pokémon\), Egg Group: $egggroup, EV yield: \00303$hp\003\/\00310$atk\003\/\00310$def\003\/\00313$satk\003\/\00313$sdef\003\/\00308$spd\003; $height m, $weight kg, \00306Catch rate: $capture\003, \00302Base Happiness: $happiness\003, Gender ratio: $gender, Exp yield: $base_exp, \00303Growth Rate: $grw\003, Max Exp: $texp"]
    }
  } else {
    return [list 0 "No matched results found"]
  }
}

proc search:pokedex {arg} {
  global pokedex
  # modes
  # 0 - no results found
  # 1 - results obtained
  set mode 0
  set table "pokeDetails$pokedex(gen)"
  set fields {
    id pokemon formname type genus ability ability2 hability 
    gender egggroup height weight legend evolve_cond hp atk def
    spatk spdef spd capture final stage effort hatch_counter happiness exp forms colour base_exp
  }
  set query [dex eval "SELECT * FROM $table"]
  set result ""
  foreach $fields $query {
    if {[regexp -nocase -- $arg [join [lmap x $fields {set $x}] " "]]} {
      lappend result $formname
      set mode 2
    }
  }
  
  if {!$mode} {
    return [list $mode "No matched results found"]
  } else {
    return [list $mode $result]
  }
}

proc random:pokemon {{number 1} args} {
  global pokedex

  if {!($number > 0 && $number < 13)} {
    return [list 0 "The maximum random number of Pokémon that can be picked is 12"]
  }
  set condition [list]
  
  foreach {flag param} $args {
    switch -nocase -glob $flag {
      -region {
        set conds [list]
        set regions [regexp -all -inline -nocase -- {[a-z]+} $param]
        foreach reg $regions {
          switch -nocase -glob $reg {
            kan* {lappend conds "(id >= '#001' AND id < '#152')"}
            joh* {lappend conds "(id >= '#152' AND id < '#252')"}
            hoe* {lappend conds "(id >= '#252' AND id < '#387')"}
            sin* {lappend conds "(id >= '#387' AND id < '#495')"}
            uno* {lappend conds "(id >= '#495' AND id < '#650')"}
            kal* {lappend conds "(id >= '#650' AND id < '#722')"}
            alo* {lappend conds "(id >= '#722' AND id < '#999')"}
            default {return [list 0 "Invalid region parameter. Must be in the format \"Kanto\" or \"Kanto|Johto|etc\""]}
          }
        }
        lappend condition "([join $conds { OR }])"
      }
      -final {
        if {$param ni {0 1}} {return [list 0 "Invalid stage parameter. Must be 0 or 1"]}
        lappend condition "final = $param"
      }
      -legend* {
        if {$param ni {0 1}} {return [list 0 "Invalid legendary parameter. Must be 0 or 1"]}
        lappend condition "legend = $param"
      }
    }
  }
  if {[llength $condition] > 0} {
    set condition " WHERE [join $condition { AND }]"
  }
  set table pokeDetails$pokedex(gen)
  set query [dex eval "SELECT formname FROM $table$condition"]
  set result ""
  set size [llength $query]

  for {set i 1} {$i <= $number} {incr i; incr size -1} {
    set done 0
    while {!$done} {
      set rseed [rand 65535]
      if {$rseed} {set done 1}
    }
    set newrand [expr {srand($rseed)}]
  
    set pokemon [expr {[rand $size]+1}]
    lappend result [lindex $query $pokemon]
    set query [lreplace $query $pokemon $pokemon]
  }
  
  return [list 2 $result]
}

proc query:pokemon {nick query} {
  global pokedex
  if {[regexp -all -nocase -- {\y(?:ALTER|UPDATE|INTO|CREATE|INSERT)\y} $query]} {
    return [list 0 "Data manipulation queries are not supported"]
  }
  if {[catch {set res [dex eval $query]} err]} {
    putquick "NOTICE $nick :$err"
  } elseif {$res == ""} {
    putquick "NOTICE $nick :No results were obtained."
  } else {
    set results ""
    set cols [list]
    dex eval $query values {lappend cols $values(*); break}
    set top [lindex $cols 0]
    lappend results $top
    
    foreach $top $res {
      set vals [lmap x $top {set $x}]
      lappend results $vals
    }
    
    set limit 5
    set maxes [list]
    for {set col 0} {$col < [llength [lindex $results 0]]} {incr col} {
      set max 0
      for {set row 0} {$row < [llength $results]} {incr row} {
        set size [string length [lindex $results $row $col]]
        if {$size > $max} {set max $size}
        if {$row >= $limit} {break}
      }
      lappend maxes "%-[expr {$max+2}]s"
    }
    
    for {set row 0} {$row < [llength $results]} {incr row} {
      putquick "NOTICE $nick :[format [join $maxes { }] {*}[lindex $results $row]]"
      if {$row >= $limit} {break}
    }
    # Format results
    
  }
}

##
# Abilitydex Mode
##
set abilityfile     "pokedex/abilities"
set abilitydexver   "0.1"
set abilitydcccmd   "ability"
set abilityusage    "Usage: !ability \[ability\]"
set abilitylogo     "\00303-Abilitydex-\003"

### Binds
bind pub - "!ability" pub:ability
bind msg - "!ability" priv:ability

### Procedures
proc pub:ability {nick host hand chan arg} {
  global pokedex
  set args [split $arg]
  if {$chan in $pokedex(restrict)} {return}
  switch [lindex $args 0] {
      search {
      set arg [lindex $args 1]
      search:ability $nick $host $hand $chan $arg
    }
    default {
      pub:look:ability $nick $host $hand $chan $arg
    }
  }
}

proc priv:ability {nick host hand arg} {
  set args [split $arg]
  switch [lindex $args 0] {
      search {
      set arg [lindex $args 1]
      search:ability $nick $host $hand "" $arg
    }
    default {
      pub:look:ability $nick $host $hand "" $arg
    }
  }
}

proc pub:look:ability { nick host hand chan arg } {
  global abilityusage abilitylogo
  if {$chan == ""} {set chan $nick}
  if {[llength $arg]<1} {
    putquick "NOTICE $nick :$abilityusage"
    return
  } 
  set result [get:ability $arg]
  putquick "PRIVMSG $chan :$abilitylogo $result."
}


proc get:ability { arg } {
  global abilityerror abilityfile
  set value 0
  set ability [string tolower $arg]
  set data [open $abilityfile r]
  while { [gets $data line] != -1 } {
    if {([string tolower [lindex [split $line "@"] 0]] == $ability)} {
      set ability [lindex [split $line "@"] 0]
      set description [lindex [split $line "@"] 1]
      set value 1
      break
    }
  }
  close $data
  if {!$value} {return [format $abilityerror "No matched results found"]}
  return "\002$ability\002: $description"
}

proc search:ability {nick host hand chan arg} {
  global abilityerror 
  if {$chan == ""} {set chan $nick}
  set value 0
  set result ""
  set data [open $abilityfile r]
  while { [gets $data line] != -1 } {
    if {[regexp -all -nocase -- $arg $line]} {
      lappend result [lindex [split $line "@"] 0]
      set value 1
    }
  }
  close $data
  if {!$value} {return [format $abilityerror "No matched results found."]}
    if {[llength $result] >= 120} {
    set result1 [join [lrange $result 0 39] ", "]
    set result2 [join [lrange $result 40 79] ", "]
    set result3 [join [lrange $result 80 119] ", "]
    set result4 [join [lrange $result 120 159] ", "]
    putquick "PRIVMSG $chan :$abilitylogo Results: $result1,"
    putquick "PRIVMSG $chan :$result2,"
    putquick "PRIVMSG $chan :$result3,"
    putquick "PRIVMSG $chan :$result4"
  } elseif {[llength $result] >= 80} {
    set result1 [join [lrange $result 0 39] ", "]
    set result2 [join [lrange $result 40 79] ", "]
    set result3 [join [lrange $result 80 119] ", "]
    putquick "PRIVMSG $chan :$abilitylogo Results: $result1,"
    putquick "PRIVMSG $chan :$result2,"
    putquick "PRIVMSG $chan :$result3"
  } elseif {[llength $result] >= 40} {
    set result1 [join [lrange $result 0 39] ", "]
    set result2 [join [lrange $result 40 79] ", "]
    putquick "PRIVMSG $chan :$abilitylogo Results: $result1,"
    putquick "PRIVMSG $chan :$result2"
  } else {
    set result [join $result ", "]
    putquick "PRIVMSG $chan :$abilitylogo Results: $result"
  }
}

##
# Moves, Berries and Items
##
### Settings
set movesfile  "pokedex/Moves"
set berryfile  "pokedex/Berries"
set itemfile  "pokedex/Items"
set searchlist ""


### Binds
bind pub - "!move"  do:move
bind pub - "!berry" do:berry
bind pub - "!item"  do:item
bind msg - "!move"  priv:move
bind msg - "!berry" priv:berry
bind msg - "!item"  priv:item


### Procedures

proc do:move {nick host hand chan arg} {
  global movesfile searchlist pokedex
  if {$chan in $pokedex(restrict)} {return}
  set args [split $arg]

  switch [lindex $args 0] {

    search {
      set file [open $movesfile r]
      set arg [lindex $args 1]
      while {[gets $file line] != -1} {

        if {[regexp -all -nocase -- $arg $line]} {

          lappend searchlist [lindex [split $line "@"] 0]

        }

      }

      close $file
      if {$searchlist == ""} {

        putquick "PRIVMSG $chan :Sorry, no matched results found."
        return
      }
      if {[llength $searchlist] >= 120} {
        set result1 [join [lrange $searchlist 0 39] ", "]
        set result2 [join [lrange $searchlist 40 79] ", "]
        set result3 [join [lrange $searchlist 80 119] ", "]
        set result4 [join [lrange $searchlist 120 159] ", "]
        putquick "PRIVMSG $chan :Results: $result1,"
        putquick "PRIVMSG $chan :$result2,"
        putquick "PRIVMSG $chan :$result3,"
        putquick "PRIVMSG $chan :$result4"
      } elseif {[llength $searchlist] >= 80} {
        set result1 [join [lrange $searchlist 0 39] ", "]
        set result2 [join [lrange $searchlist 40 79] ", "]
        set result3 [join [lrange $searchlist 80 119] ", "]
        putquick "PRIVMSG $chan :Results: $result1,"
        putquick "PRIVMSG $chan :$result2,"
        putquick "PRIVMSG $chan :$result3"
      } elseif {[llength $searchlist] >= 40} {
        set result1 [join [lrange $searchlist 0 39] ", "]
        set result2 [join [lrange $searchlist 40 79] ", "]
        putquick "PRIVMSG $chan :Results: $result1,"
        putquick "PRIVMSG $chan :$result2"
      } else {
        set result [join $searchlist ", "]
        putquick "PRIVMSG $chan :Results: $result"
      }
      set searchlist ""

      return  

    } default {

      do:movedesc $nick $host $hand $chan $arg

    }
  }

  return
}



proc do:berry {nick host hand chan arg} {
  global berryfile searchlist pokedex
  if {$chan in $pokedex(restrict)} {return}
  set args [split $arg]

  switch [lindex $args 0] {

    search {
      set file [open $berryfile r]
      set arg [lindex $args 1]
      while {[gets $file line] != -1} {

        if {[regexp -all -nocase -- $arg $line]} {

          lappend searchlist [lindex [split $line "@"] 1]

        }

      }

      close $file
      if {$searchlist == ""} {

        putquick "PRIVMSG $chan :Sorry, no matched results found."
        return
      }
      if {[llength $searchlist] >= 120} {
        set result1 [join [lrange $searchlist 0 39] ", "]
        set result2 [join [lrange $searchlist 40 79] ", "]
        set result3 [join [lrange $searchlist 80 119] ", "]
        set result4 [join [lrange $searchlist 120 159] ", "]
        putquick "PRIVMSG $chan :Results: $result1,"
        putquick "PRIVMSG $chan :$result2,"
        putquick "PRIVMSG $chan :$result3,"
        putquick "PRIVMSG $chan :$result4"
      } elseif {[llength $searchlist] >= 80} {
        set result1 [join [lrange $searchlist 0 39] ", "]
        set result2 [join [lrange $searchlist 40 79] ", "]
        set result3 [join [lrange $searchlist 80 119] ", "]
        putquick "PRIVMSG $chan :Results: $result1,"
        putquick "PRIVMSG $chan :$result2,"
        putquick "PRIVMSG $chan :$result3"
      } elseif {[llength $searchlist] >= 40} {
        set result1 [join [lrange $searchlist 0 39] ", "]
        set result2 [join [lrange $searchlist 40 79] ", "]
        putquick "PRIVMSG $chan :Results: $result1,"
        putquick "PRIVMSG $chan :$result2"
      } else {
        set result [join $searchlist ", "]
        putquick "PRIVMSG $chan :Results: $result"
      }
      set searchlist ""

      return  

    } default {

      do:berrydesc $nick $host $hand $chan $arg

    }
  }

  return

}



proc do:item {nick host hand chan arg} {
  global itemfile searchlist pokedex
  if {$chan in $pokedex(restrict)} {return}
  set args [split $arg]

  switch [lindex [split $arg] 0] {
    search {

      set file [open $itemfile r]
      set arg [lindex $args 1]
      while {[gets $file line] != -1} {

        if {[regexp -all -nocase -- $arg $line]} {

          lappend searchlist [lindex [split $line "@"] 0]

        }

      }

      close $file
      if {$searchlist == ""} {

        putquick "PRIVMSG $chan :Sorry, no matched results found."
        return
      }
      if {[llength $searchlist] >= 120} {
        set result1 [join [lrange $searchlist 0 39] ", "]
        set result2 [join [lrange $searchlist 40 79] ", "]
        set result3 [join [lrange $searchlist 80 119] ", "]
        set result4 [join [lrange $searchlist 120 159] ", "]
        putquick "PRIVMSG $chan :Results: $result1,"
        putquick "PRIVMSG $chan :$result2,"
        putquick "PRIVMSG $chan :$result3,"
        putquick "PRIVMSG $chan :$result4"
      } elseif {[llength $searchlist] >= 80} {
        set result1 [join [lrange $searchlist 0 39] ", "]
        set result2 [join [lrange $searchlist 40 79] ", "]
        set result3 [join [lrange $searchlist 80 119] ", "]
        putquick "PRIVMSG $chan :Results: $result1,"
        putquick "PRIVMSG $chan :$result2,"
        putquick "PRIVMSG $chan :$result3"
      } elseif {[llength $searchlist] >= 40} {
        set result1 [join [lrange $searchlist 0 39] ", "]
        set result2 [join [lrange $searchlist 40 79] ", "]
        putquick "PRIVMSG $chan :Results: $result1,"
        putquick "PRIVMSG $chan :$result2"
      } else {
        set result [join $searchlist ", "]
        putquick "PRIVMSG $chan :Results: $result"
      }
      set searchlist ""

      return  
    } default {

      do:itemdesc $nick $host $hand $chan $arg

    }
  }

  return

}



proc do:movedesc {nick host hand chan arg} {
  global movesfile pokedex
  if {$chan in $pokedex(restrict)} {return}
  set result 0
  set file [open $movesfile r]
  while {[gets $file line] != -1} {
    if {[string tolower [lindex [split $line "@"] 0]] == [string tolower $arg]} {
      set move [lindex [split $line "@"] 0]
      set category [lindex [split $line "@"] 1]
      set PP [lindex [split $line "@"] 2]
      set power [lindex [split $line "@"] 3]
      set accuracy [lindex [split $line "@"] 4]
      set desc [lindex [split $line "@"] 5]
      set type [lindex [split $line "@"] 6]
      set result 1
      break
    }
  }

  close $file
  if {!$result} {
    putquick "PRIVMSG $chan :Sorry, no matched results found."
    return
  }
  putquick "PRIVMSG $chan :\002\00303-Movedex-\003\002 Move: \002$move\002 \[\00303Type: $type\003, \00305Cat: $category\003, \00302PP: $PP\003, Pow: $power, \00306Acc: $accuracy\003\] $desc"

  return

}



proc do:berrydesc {nick host hand chan arg} {
  global berryfile pokedex
  if {$chan in $pokedex(restrict)} {return}
  set file [open $berryfile r]
  set result 0
  while {[gets $file line] != -1} {
    if {[string tolower [lindex [split $line "@"] 1]] == [string tolower $arg]} {
      set number [lindex [split $line "@"] 0]
      set berry [lindex [split $line "@"] 1]
      set desc [lindex [split $line "@"] 2]
      set result 1
      break
    }
  }
  close $file
  if {!$result} {
    putquick "PRIVMSG $chan :Sorry, no matched results found."
    return
  }
  putquick "PRIVMSG $chan :\002\00303-Berrydex-\003\002 $number: \002$berry\002 ~$desc."
  return

}



proc do:itemdesc {nick host hand chan arg} {
  global itemfile pokedex
  if {$chan in $pokedex(restrict)} {return}
  set file [open $itemfile r]
  set result 0
  while {[gets $file line] != -1} {
    if {[string tolower [lindex [split $line "@"] 0]] == [string tolower $arg]} {
      set item [lindex [split $line "@"] 0]
      set desc [lindex [split $line "@"] 1]
      set result 1
      break
    }
  }

  close $file
  if {!$result} {
    putquick "PRIVMSG $chan :Sorry, no matched results found."
    return
  }
  putquick "PRIVMSG $chan :\002\00303-Itemdex-\003\002 \002$item\002 ~$desc."

  return

}

proc priv:move {nick host hand arg} {
  do:move $nick $host $hand $nick $arg
}

proc priv:berry {nick host hand arg} {
  do:berry $nick $host $hand $nick $arg
}

proc priv:item {nick host hand arg} {
  do:item $nick $host $hand $nick $arg
}

### Loaded
putlog "Pokedex $pokedex(version), Abilitydesc $abilitydexver loaded"
