##
# Evaluation
##
set eva(ver) "0.1"
set eva(cmd) "!eval"
set eva(usage) "Usage: $eva(cmd) <expression>"
set eva(prefix) "Calculator:"
set eva(output)  "%s = %s"

bind pub - $eva(cmd) pub:eva

proc pub:eva {nick host hand chan arg} {
  global eva
  if {$arg == ""} {
    putquick "PRIVMSG $chan :Usage: !eval <expression>"
  }
  set evaltemp $arg

  regsub -all -- {[\[\{]} $arg "(" arg
  regsub -all -- {[\]\}]} $arg ")" arg
  regsub -all -- {\^} $arg "**" arg
  regsub -all -- {F} $arg "NAe-" arg
  regsub -all -- {e-} $arg "0.000000000000000000160217656535" arg
  regsub -all -- {me} $arg "0.00000000000000000000000000000091093829140" arg
  regsub -all -- {mp} $arg "0.00000000000000000000000000167262177774" arg
  regsub -all -- {k} $arg "R/NA" arg
  regsub -all -- {NA|L} $arg "602214179300000000000000" arg
  regsub -all -- {R} $arg "8.314462175" arg
  regsub -all -- {epsilon} $arg "1/(mu*(c**2))" arg
  regsub -all -- {mu} $arg "0.0000004*pi" arg
  regsub -all -- {pi} $arg "3.1415926535897932384626433832795028841971693993751058209749445923078164062862089986280348253421170679" arg
  regsub -all -- {e} $arg "2.71828182845904523536028747135266249775724709369995" arg
  regsub -all -- {phi} $arg "1.6180339887498948482" arg
  regsub -all -- {G} $arg "0.000000000066738480" arg
  regsub -all -- {h} $arg "0.00000000000000000000000000000000066260695729" arg
  regsub -all -- {c_l} $arg "299792458" arg
  regsub -all -- {x} $arg "*" arg
  set result [expr $arg]
  putquick "PRIVMSG $chan :$evaltemp = $result"
}

##
# Conversion
##

### Settings
set con(ver) "0.1"
set con(cmd) "!con"
set con(dcccmd) "con"
set con(usage) "Usage: $con(cmd) <amount> <from> <to>"
set con(prefix) "Conversion:"
set con(output) "%s %s = %s %s."
set con(errorformat) "Error: %s"
set con(table) "scripts/Table"

### Binds
bind pub - $con(cmd) pub:con
bind dcc -|- $con(dcccmd) dcc:con

### Procedures
proc pub:con {nick uhost handle channel arg} {
  global con
  set arg [split $arg]
  if {[llength $arg]!=3} {
    putquick "NOTICE $nick :$con(usage)"
    return
  } 
  set result [con:get $arg]
  putquick "PRIVMSG $channel :$nick, $con(prefix) $result"
}

proc dcc:con {ha idx arg} {
  global con
  set arg [split $arg " "]
  if {[llength $arg]!=3} {
    putdcc $idx $con(usage)
    return
  }
  set result [con:get $arg]
  putdcc $idx $result
}

proc con:get {arg} {
  global con
  set init [lindex $arg 0]
  regsub -all -- {\"} $arg "\"" $arg
  if {[regexp -all {[\'\"]+} $arg]} {
    set amount [lindex [split $arg] 0]
    set amount [con:feet $amount]
  } else {
    set amount [lindex $arg 0]
  }
  regsub -all -- {[^0-9\.]+} $amount "" amount
  set from [lindex $arg 1]
  set to [lindex $arg 2]
  set value 1
  if {($from == "C") && ($to == "F")} {
    set result [expr {($amount*1.8)+32}]
    set from "°C"
    set to "°F"
  } elseif {($from == "F") && ($to == "C")} {
    set result [expr {($amount-32)*5.0/9}]
    set from "°F"
    set to "°C"
  } elseif {($from == "C") && ($to == "K")} {
    set result [expr {$amount-273.15}]
    set from "°C"
  } elseif {($from == "K") && ($to == "C")} {
    set result [expr {$amount+273.15}]
    set to "°C"
  } elseif {($from == "F") && ($to == "K")} {
    set result [expr {($amount+459.67)*5.0/9}]
    set from "°F"
  } elseif {($from == "K") && ($to == "F")} {
    set result [expr {($amount*1.8)-459.67}]
    set to "°F"
  } else {
    set value 0
    set data [open $con(table) r]
    while { [gets $data line] != -1 } {
      if {([lindex [split $line] 0] == $from) && ([lindex [split $line] 1] == $to)} {
        set value 1
        set factor [lindex [split $line] 2]
        break
      }
    }
    close $data
    if {!$value} {return [format $con(errorformat) "No matched results found"]}
    set result [expr {$factor*$amount}]
  }

  if {$result >= 0} {set result [format "%.2f" "$result"]}
  return [format $con(output) $init $from $result $to]
}

proc con:feet {amount} {
  set nick Jerry|
  regexp {([\d]+).*([\d]+).*} $amount match ft in
  set in [format "%.1f" "$in"]
  set amount [expr {$ft + ($in/12)}]
  return $amount
}

### Loaded
putlog "Conversion $con(ver) loaded"
