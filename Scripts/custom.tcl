##
# Kick on order
##
bind pub "o|o" "!kill" do:killnick
bind pub "o|o" "!terminate" do:terminatenick

set persobanlist   ""
set bantimer      ""
set banduration    30

proc do:killnick {nick uhost hand chan arg} {
  if {$chan == "#pokemon-universe"} {return}

  if {[regexp {^[\#]} [lindex $arg 0]]} {
    set chan [lindex $arg 0]
    regsub {[\w\d\|\#-]* } $arg "" arg
  }
  set kicked [lindex $arg 0]
  regsub {[\w\d\|\_\^\[\]`\{\}-]* } $arg "" txt
  putquick "KICK $chan $kicked :$txt"
  return
}

proc do:terminatenick {nick uhost hand chan arg} {
  global persobanlist banduration
  if {$chan == "#pokemon-universe"} {return}
  set banned [lindex [split $arg] 0]
  putquick "MODE $chan +b $banned"
  do:killnick $nick $uhost $hand $chan $arg

  set bancount 0
  set nickfound 0
  while {[lindex $persobanlist $bancount] != ""} {
    if {[lindex $persobanlist $bancount] == $banned} {
      set banduration [expr {$banduration+30}]
      catch {killtimer $bantimer}
      set nickfound 1
    }
    incr bancount
  }

  if {!$nickfound} {
    set banduration 30
    lappend persobanlist $banned
  }

  set unbantimer [utimer $banduration "unbannick $chan $banned"]
  set removeban [timer 2 "removebanlist $banned"]
}

proc removebanlist {banned} {
  global persobanlist
  set bancount 0
  set nickfound 0
  while {[lindex $persobanlist $bancount] != ""} {
    if {[lindex $persobanlist $bancount] == $banned} {
      set nickfound 1
      break
    }
    incr bancount
  }
  set persobanlist [lreplace $persobanlist $bancount $bancount]
}

proc unbannick {chan banned} {
  putserv "MODE $chan -b $banned"
}

##
# Give topic of channel
##
bind pub - !topic do:puttopic

proc do:puttopic {nick host hand chan arg} {
  putquick "PRIVMSG $chan :The current topic is [topic $chan]"
  catch {unbind pub - "!topic" do:puttopic}
  after 200000 [list bind pub - "!topic" do:puttopic]
}

##
# Join/Quit notification
##
# bind join - "*!*@*" do:noticejoin
# bind sign - "*!*@*" do:noticequit

# proc do:noticejoin {nick host hand chan} {
  # putquick "NOTICE Jerry :$nick joined $chan."
# }

# proc do:noticequit {nick host hand chan arg} {
  # putserv "NOTICE Jerry :$nick quit $chan."
# }

##
# Waving
##
bind pub - "o/" do:wave

proc do:wave {nick host hand chan arg} {
  if {$nick == "Jerry"} {
    putquick "PRIVMSG $chan :\001ACTION waves \\o\001"
  }
}

##
# Script to safely die the bot upon quit of owner
##
bind sign - "*!*@quake.earth.stillwaters" do:ownerout
bind pub "o|o" !autoquit do:autoquit
set autoquit 0

proc do:ownerout {nick host hand chan arg} {
  global botnick autoquit
  if {!$autoquit} {return}
  die "$botnick gets back into its Pokeball."
  putlog "died - requested - $nick"
}

proc do:autoquit {nick host hand chan arg} {
  global autoquit
  switch -regexp $arg {
    {on|1} {set autoquit 1}
    {off|0} {set autoquit 0}
  }
  putquick "PRIVMSG $chan :autoquit set to $arg."
}


##
# Script for auto op on channel
##
set NBOpers [list loudskies]

bind join - * do:op

proc do:op {nick host hand chan} {
  global NBOpers
  if {$chan == "#Jerry"} {
    if {[lsearch $NBOpers $nick] == -1} {return}
    putquick "MODE $chan +h $nick"
    return
  }
}

##
# Script for easy rehash and die
##

bind pub "o|o" ..rehash do:rehash
bind msg "o|o" ..rehash do:rehash
bind pub "o|o" ..sleep do:die

proc do:rehash { nick host hand args} {
  rehash
  putlog "rehashed - requested - $nick"
  putquick "NOTICE $nick :Rehash complete"
}

proc do:die { nick host hand chan arg } {
  die "$arg"
  putlog "died - requested - $nick"
}

##
# Script for cloning
##

bind pub "m|m" ..clone do:startclone
bind pub "m|m" ..declone do:stopclone
bind pub "m|m" ..chaninfo do:chantest

proc do:chantest { nick host hand chan arg } {
  set chantest [channel info $chan]
  putquick "PRIVMSG $chan :$chantest"
}

proc do:startclone { nick host hand chan arg } {
  global clonefrom cloneto clonefor
  set cloneto $arg
  set clonefrom $chan
  set clonefor $nick
  bind pubm "m|m" "*" do:clone
  putquick "NOTICE $nick :Now cloning $clonefrom to $cloneto for $clonefor"
  return
}

proc do:clone { nick host hand chan arg } {
  global clonefrom cloneto clonefor
  if { ($nick != $clonefor) || ($chan != $clonefrom) || ($arg == "..declone") || ($arg == "..declone $cloneto") } { return }
  putquick "PRIVMSG $cloneto :$arg"
  return
}

proc do:stopclone { nick host hand chan arg } {
  global cloneto clonefrom clonefor
  unbind pubm "m|m" "*" do:clone
  putquick "NOTICE $nick :Stopped cloning $clonefrom to $cloneto for $clonefor"
  set cloneto ""
  set clonefrom ""
  set clonefor ""
  return
}

##
# Channel management
##

bind pub "o|o" .+chan do:addchan
bind pub "o|o" .-chan do:delchan

proc do:addchan { nick host hand chan arg } {
  global botnick
  if {![botonchan $arg]} {
    channel add $arg
  } else {
    putquick "NOTICE $nick :$botnick is already on $arg!"
  }
}

proc do:delchan { nick host hand chan arg } {
  global botnick
  if {[botonchan $arg]} {
    channel remove $arg
  } else {
    putquick "NOTICE $nick :$botnick is not on $arg!"
  }
}

##
# Manual unbind
##
bind pub "o|o" !unbind do:unbind

proc do:unbind {nick host hand chan arg} {
  unbind {*}$arg
}

##
# Reboot discord bot
##
bind pub - !botreboot discord:autoreboot
set autoreboot "off"

proc discord:autoreboot {nick host hand chan arg} {
  global autoreboot
  if {[lsearch -nocase {Jerry Jerry|BNC Jerry| Solo Qhinn Nostazz Daedra Shamac} $nick] == -1} {return}
  if {$arg ni {on off}} {
    putquick "NOTICE $nick :Invalid option; only on and off are acceptable"
  }
  set autoreboot $arg
  putquick "NOTICE $nick :Autoreboot for discord bot switched $arg."
  if {$autoreboot eq "on"} {
    discord:check
  }
}

proc discord:check {} {
  global autoreboot
  if {$autoreboot eq "off"} {return}
  set res [exec ps aux | grep Marshtomp.js]
  if {![regexp {node (?:\.\./)?Marshtomp\.js} $res]} {
    putquick "PRIVMSG #Jerry :Discord bot rebooted."
    exec node ../Marshtomp.js &
  }
  after 30000 discord:check
}
discord:check

##
# Remote updates
##
bind pub - !wget server:wget

# !wget destination url time
proc server:wget {nick hand host chan arg} {
  if {$chan ne "#Jerry" && ![isowner $nick]} {return}
  lassign $arg destination url time
  set fname [file tail $url]
  set dest [file join $destination $fname]
  if {[file exists $dest]} {
    file delete $dest
  }
  exec wget $url >>& dlhistory
  after [expr {$time*1000}]
  file copy $fname $dest
  file delete $fname
  putquick "NOTICE $nick :$fname successfully downloaded to $dest."
}

##
# Tests
##
#bind chat - "*" msgtest
#bind msgm - "*" msgtest2
bind pub o|o !test msgtest3

proc msgtest {hand chan arg} {
  putquick "PRIVMSG #Jerry :chat - $hand $chan said $arg"
}

proc msgtest2 {nick host hand arg} {
  putquick "PRIVMSG #Jerry :msgm - $nick $host $hand said $arg"
}

proc msgtest3 {nick host hand chan arg} {
  putquick "PRIVMSG $chan :[eval $arg]"
}

proc lmap args {
  set body [lindex $args end]
  set args [lrange $args 0 end-1]
  set n 0
  set pairs [list]
  foreach {varnames listval} $args {
    set varlist [list]
    foreach varname $varnames {
      upvar 1 $varname var$n
      lappend varlist var$n
      incr n
    }
    lappend pairs $varlist $listval
  }
  set temp [list]
  foreach {*}$pairs {
    lappend temp [uplevel 1 $body]
  }
  set temp
}

### Loaded
putlog "Custom Script loaded"
