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
      #puts "proc $command {nick args} {$proc \$nick host hand #Jerry \$args}"
      eval "proc $command {{nick Jerry} args} {$proc \$nick host hand #Jerry \$args}"
    }
    unbind {
      lassign [lrange $args 1 end] type flag command proc
      rename $command ""
    }
    onchan {return 1}
    unixtime {}
    default {tcl_unknown $args}
  }
}
