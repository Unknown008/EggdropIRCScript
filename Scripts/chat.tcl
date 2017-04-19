if {"tcl_unknown" ni [info proc]} {
  rename unknown tcl_unknown
}

set botnick Marshtomp

proc unknown {args} {
  switch [lindex $args 0] {
    putquick {puts {*}[lrange $args 1 end]}
    puthelp {puts {*}[lrange $args 1 end]}
    putserv {puts {*}[lrange $args 1 end]}
    putlog {puts {*}[lrange $args 1 end]}
    bind {
      lassign [lrange $args 1 end] type flag command proc
      #puts "proc $command {nick args} {$proc \$nick host hand #channel \$args}"
      eval "proc $command {{nick TrainerB} args} {$proc \$nick host hand #channel \$args}"
    }
    unbind {
      lassign [lrange $args 1 end] type flag command proc
      catch {rename $command ""}
    }
    onchan {return 1}
    unixtime {}
    default {
      if {[regexp {poke:move:(\S*)} $args - move]} {
        global poke
        lassign $args proc trainer pokedet otrainer opokedet
        array set pokemon $pokedet
        putquick "PRIVMSG $poke(chan) :$pokemon(species) used $move!"
        return
      }
      tcl_unknown {*}$args
    }
  }
}
