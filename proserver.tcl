### PRO FAQ ###
### Triggers
bind pub  - !email         pro:regemail
bind pub  - !android       pro:android
bind pub  - !client        pro:clientlogin
bind pub  - !loveisland    pro:loveisland
bind pub  - !trainervalley pro:trainervalley
bind pub  - !ceruleancave  pro:ceruleancave
#bind pub  - !topic         pro:topic
bind pub  - !link          pro:link
bind pub  - !updatemirror  pro:updatemirror
bind pub  - !prohelp       pro:commands
bind msg  - !prohelp       pro:commands
bind pub  - !bothelp       pro:commands
bind msg  - !bothelp       pro:commands
bind pub  - !status        pro:status
bind msg  - !status        pro:status
bind pub  - !protime       pro:time
bind join - "*!*@*"        pro:newbtest
bind pubm - *              pro:filter

### Variables
set unixtime 0
set ignore [list bluebisket Creator Lilly Jerry]
set trigger [list]
set promailmsg "If you have not received the registration email to activate your account, please try to register another account with hotmail or gmail.com (https://accounts.google.com/SignUp). You will unfortunately have to pick a new username. Don't forget to check your spam/junk folders!"
set proconnectmsg "If 'Logging in' disappears after you click on 'Log in' and nothing happens, you need to wait for around 5-10 minutes before the system puts you in queue or brings you ingame."
set proandroidmsg "PROAndroid: Download here: http://tiny.cc/PRODroid For any issues, try http://pokemon-revolution-online.net/Forum/viewtopic.php?f=89&t=16180"
set prousers ""

### Procs
proc pro:filter {nick host hand chan arg} {
  global unixtime promailmsg proconnectmsg prousers trigger ignore proandroidmsg
  if {$nick ni $prousers} {
    lappend prousers $nick
  } elseif {$nick in $ignore} {
    return
  } else {
    return
  }
  if {$nick ni $trigger} {return}
  if {
    [regexp {e?-?mail}        $arg] &&
    [regexp {receive|g[eo]t}  $arg] &&
    [regexp {n[o']?t\y|never} $arg]
  } {
    if {$unixtime != 0} {return}
    
    putquick "PRIVMSG $chan :$nick: $promailmsg"
    set unixtime [clock scan now]
    lappend trigger email
    after 10000 pro:resettime
  } elseif {
    [regexp {can(?:'|no)t} $arg] &&
    [regexp {connect|log[ g]?in|queue}      $arg] &&
    [regexp {disappears|nothing|fades}   $arg]
  } {
    if {$unixtime != 0} {return}
     
    putquick "PRIVMSG $chan :$nick: $proconnectmsg"
    set unixtime [clock scan now]
    lappend trigger client
    after 10000 pro:resettime
  } elseif {
    [regexp -nocase {andr[oi]{2}d} $arg] &&
    [regexp -nocase {download|get|release|come|maint|link|client|version|update|fix} $arg]
  } {
    # if {$unixtime != 0} {return}
        
    # putquick "PRIVMSG $chan :$nick: $proandroidmsg"
    # set unixtime [clock scan now]
    # lappend trigger android
    # after 10000 pro:resettime
  }
}

proc pro:regemail {nick host hand chan arg} {
  global promailmsg ignore unixtime trigger
  if {$nick in $ignore && $nick != "Jerry"} {return}
  set arg [string trim $arg]
  if {$arg == "" && $nick == "Jerry"} {
    if {$unixtime != 0} {return}
     
    putquick "PRIVMSG $chan :$promailmsg"
    set unixtime [clock scan now]
    after 10000 pro:resettime
  } else {
    if {[onchan $arg $chan]} {
      putquick "NOTICE $arg :$promailmsg"
      putquick "NOTICE $nick :Message sent to $arg!"
    } else {
      putquick "NOTICE $nick :$arg is not a valid username!"
    }
  }
}

proc pro:android {nick host hand chan arg} {
  global proandroidmsg ignore unixtime trigger
  if {$nick in $ignore && $nick != "Jerry"} {return}
  set arg [string trim $arg]
  if {$arg == "" && $nick == "Jerry"} {
    if {$unixtime != 0} {return}
    
    putquick "PRIVMSG $chan :$proandroidmsg"
    set unixtime [clock scan now]
    after 10000 pro:resettime
  } else {
    if {[onchan $arg $chan]} {
      putquick "NOTICE $arg :$proandroidmsg"
      putquick "NOTICE $nick :Message sent to $arg!"
    } else {
      putquick "NOTICE $nick :$arg is not a valid username!"
    }
  }
}

proc pro:clientlogin {nick host hand chan arg} {
  global proconnectmsg ignore unixtime trigger
  if {$nick in $ignore && $nick != "Jerry"} {return}
  set arg [string trim $arg]
  if {$arg == ""} {
    if {$unixtime != 0} {return}
    
    putquick "PRIVMSG $chan :$proconnectmsg"
    set unixtime [clock scan now]
    after 10000 pro:resettime
  } else {
    if {[onchan [string trim $arg] $chan]} {
      putquick "NOTICE $arg :$proconnectmsg"
      putquick "NOTICE $nick :Message sent to $arg!"
    } else {
      putquick "NOTICE $nick :$arg is not a valid username!"
    }
  }
}

proc pro:loveisland {nick host hand chan arg} { 
  global unixtime trigger ignore
  if {$nick in $ignore && $nick != "Jerry"} {return}
  set arg [string trim $arg]
  if {$arg == ""} {
    if {$unixtime != 0} {return}
     
    putquick "PRIVMSG $chan :Requirements for Love Island: 1. Have 120 caught data for Kanto Pokémon 2. Have 38 evolutions."
    set unixtime [clock scan now]
    after 10000 pro:resettime
  } else {
    if {[onchan $arg $chan]} {
      putquick "NOTICE $arg :Requirements for Love Island: 1. Have 120 caught data for Kanto Pokémon 2. Have 38 evolutions."
      putquick "NOTICE $nick :Message sent to $arg!"
    } else {
      putquick "NOTICE $nick :$arg is not a valid username!"
    }
  }
}

proc pro:trainervalley {nick host hand chan arg} {
  global unixtime trigger ignore
  if {$nick in $ignore && $nick != "Jerry"} {return}
  set arg [string trim $arg]
  if {$arg == ""} {
    if {$unixtime != 0} {return}
      
    putquick "PRIVMSG $chan :Requirements for Trainer Valley: 1. 34 evolutions 2. Beat both Kanto and Johto Elite 4 3. Have 120 caught data for Kanto Pokémon. 5. Battled Red in Mt. Silver."
    set unixtime [clock scan now]
    after 10000 pro:resettime

  } else {
    if {[onchan $arg $chan]} {
      putquick "NOTICE $arg :Requirements for Trainer Valley: 1. 34 evolutions 2. Beat both Kanto and Johto Elite 4 3. Have 120 caught data for Kanto Pokémon. 5. Battled Red in Mt. Silver."
      putquick "NOTICE $nick :Message sent to $arg!"
    } else {
      putquick "NOTICE $nick :$arg is not a valid username!"
    }
  }
}

proc pro:ceruleancave {nick host hand chan arg} {
  global unixtime trigger ignore
  if {$nick in $ignore && $nick != "Jerry"} {return}
  set arg [string trim $arg]
  if {$arg == ""} {
    if {$unixtime != 0} {return}
    
    putquick "PRIVMSG $chan :Requirements for Cerulean Cave: 1. Beat both Kanto and Johto Elite 4 2. Beat Lance boss 3. Have Dragon Membership. 4. 240 caught data and 38 evolved Pokémon."
    set unixtime [clock scan now]
    after 10000 pro:resettime
  } else {
    if {[onchan $arg $chan]} {
      putquick "NOTICE $arg :Requirements for Cerulean Cave: 1. Beat both Kanto and Johto Elite 4 2. Beat Lance boss 3. Have Dragon Membership. 4. 240 caught data and 38 evolved Pokémon."
      putquick "NOTICE $nick :Message sent to $arg!"
    } else {
      putquick "NOTICE $nick :$arg is not a valid username!"
    }
  }
}

proc pro:resettime {} {
  global unixtime
  putquick "NOTICE Jerry :resetting"
  set unixtime 0
}

# proc pro:topic {nick host hand chan arg} {
  # putquick "PRIVMSG $chan :[topic $chan]"
# }

proc pro:updatemirror {nick host hand chan args} {
  if {[isop $nick] || [ishalfop $nick] || [isadmin $nick $chan] || [isowner $nick $chan]} {
    set args [regexp -all -inline -- {(-\S*) +([^- ]\S+(?: [^- ]\S+)*)(?= |$)} [lindex $args 0]]
    if {[file exists pro_mirror_versions]} {
      set f [open pro_mirror_versions r]
      lassign [read $f] mirrordate mirrorversion
      close $f
    }
    foreach {main flag value} $args {
      switch -glob $flag {
        -date {
          if {[catch {set time [clock scan $value]} err]} {
            putquick "NOTICE $nick :Invalid date format. Please use dd-mmm-YYYY"
          } else {
            set mirrordate [clock format $time -format "%d-%b-%Y"]
          }
          set date 1
        }
        -ver* {
          set mirrorversion $value
          set ver 1
        }
        default {
          putquick "NOTICE $nick :Invalid flag. Valid flags include -date and -version"
          return
        }
      }
    }
    set f [open pro_mirror_versions w]
    puts $f "$mirrordate $mirrorversion"
    close $f
    if {$date && !$ver} {
      putquick "NOTICE $nick :Date has been changed to $mirrordate!"
    } elseif {!$date && $ver} {
      putquick "NOTICE $nick :Version has been changed to $mirrorversion!"
    } else {
      putquick "NOTICE $nick :Date has been changed to $mirrordate and version has been changed to $mirrorversion!"
    }
  } else {
    putquick "NOTICE $nick :You need to be at least a halfop of the channel to do that!"
  }
}

proc pro:link {nick host hand chan arg} {
  lassign $arg type target
  set target [string trim $target]
  
  if {$target eq ""} {
    if {$type eq "help"} {
      putquick "NOTICE $nick :Available options:"
      putquick "NOTICE $nick :win10                   Link to windows 10 crash resolution threads"
      putquick "NOTICE $nick :forum                   Link to forum"
      putquick "NOTICE $nick :appeal                  Link to appeals"
      putquick "NOTICE $nick :account                 Link to player dashboard"
      putquick "NOTICE $nick :report                  Link to report players"
      putquick "NOTICE $nick :bug                     Link to bug section"
      putquick "NOTICE $nick :spawnbug                Link to spawn bug section"
      putquick "NOTICE $nick :battlebug               Link to battle bug section"
      putquick "NOTICE $nick :generalbug              Link to general bugs section"
      putquick "NOTICE $nick :mappingbug              Link to mapping bugs section"
      putquick "NOTICE $nick :npcbug                  Link to NPC bugs section"
      putquick "NOTICE $nick :clientbug               Link to client bugs section"
      putquick "NOTICE $nick :forumbug                Link to forum bugs section"
      putquick "NOTICE $nick :support                 Link to general support section"
      putquick "NOTICE $nick :donations               Link to donation issues section"
      putquick "NOTICE $nick :guide                   Link to player guides section"
      putquick "NOTICE $nick :home                    Link to PRO home page"
      putquick "NOTICE $nick :announcements           Link to announcements section"
      putquick "NOTICE $nick :updates|download|dl     Link to official and mirror download links"
      putquick "NOTICE $nick :pp|punishmentpolicy     Link to punishment policy"
      putquick "NOTICE $nick :cut                     Link to cut guide"
      putquick "NOTICE $nick :fly                     Link to fly guide"
      putquick "NOTICE $nick :discord                 Link to unofficial PRO discord"
      putquick "NOTICE $nick :rules                   Link to chat rules"
      putquick "NOTICE $nick :reg|registration        Link to registration"
      return
    } elseif {$type eq ""} {
      putquick "NOTICE nick :Please specify a target user. Syntax: !link $type username"
      return
    } else {
      pro:link $nick $host $hand $chan "$type $nick"
    }
  } else {
    if {[onchan $target $chan]} {
      switch -nocase -regexp -- $type {
        win10 {set link [list "Try this first: http://pokemon-revolution-online.net/Forum/viewtopic.php?f=52&t=14688" "If it doesn't work, try this next: http://pokemon-revolution-online.net/Forum/viewtopic.php?f=16&t=14738"]}
        forums? {set link [list "Link to forums: http://pokemon-revolution-online.net/Forum/index.php"]}
        appeal|ban {set link [list "See account status: http://pokemon-revolution-online.net/dashboard/" "Appeal section: http://pokemon-revolution-online.net/Forum/viewforum.php?f=32"]}
        account {set link [list "See account status: http://pokemon-revolution-online.net/dashboard/"]}
        report {set link [list "Report section: http://pokemon-revolution-online.net/Forum/viewforum.php?f=70"]}
        bug {set link [list "Bug resolution center: http://pokemon-revolution-online.net/Forum/viewforum.php?f=6"]}
        spawnbug {set link [list "Spawn bugs section: http://pokemon-revolution-online.net/Forum/viewforum.php?f=85"]}
        battlebug {set link [list "Battle bugs ssection: http://pokemon-revolution-online.net/Forum/viewforum.php?f=84"]}
        generalbug {set link [list "General bugs section: http://pokemon-revolution-online.net/Forum/viewforum.php?f=88"]}
        mappingbug {set link [list "Mapping bugs section: http://pokemon-revolution-online.net/Forum/viewforum.php?f=81"]}
        npcbug {set link [list "NPC & Scripting bugs section: http://pokemon-revolution-online.net/Forum/viewforum.php?f=82"]}
        clientbug {set link [list "Client bugs section: http://pokemon-revolution-online.net/Forum/viewforum.php?f=83"]}
        forumbug {set link [list "Forum bugs section: http://pokemon-revolution-online.net/Forum/viewforum.php?f=87"]}
        support {set link [list "General support: http://pokemon-revolution-online.net/Forum/viewforum.php?f=87"]}
        donations? {set link [list "Donation issues report center: http://pokemon-revolution-online.net/Forum/viewforum.php?f=71"]}
        guides? {set link [list "Player guides: http://pokemon-revolution-online.net/Forum/viewforum.php?f=89"]}
        home {set link [list "PRO Homepage: http://pokemon-revolution-online.net/"]}
        announcements? {set link [list "PRO Announcements: http://pokemon-revolution-online.net/Forum/viewforum.php?f=14"]}
        updates?|downloads?|dl {
          if {[file exists pro_mirror_versions]} {
            set f [open pro_mirror_versions r]
            lassign [read $f] mirrordate mirrorversion
            close $f
          } else {
            lassign {N/A N/A} mirrordate mirrorversion
          }
          set link [list "http://pokemon-revolution-online.net/Downloads.php" "Mega-NZ mirror: https://mega.nz/fm/o4EWBQhT (Last checked: $mirrordate Version: $mirrorversion)"]
        }
        pp|punishmentpolicy {set link [list "Punishment Policy: http://pokemon-revolution-online.net/Forum/viewtopic.php?f=14&t=31228"]}
        cut|surf {set link [list "Guide for Cut and Surf: http://pokemon-revolution-online.net/Forum/viewtopic.php?f=119&t=7078"]}
        fly {set link [list "Guide for Fly: http://pokemon-revolution-online.net/Forum/viewtopic.php?f=119&t=6146"]}
        discord {set link [list "Unofficial PRO Discord: https://discord.gg/5BUfz4j"]}
        rules {set link [list "Chat rules: http://tinyurl.com/PROIRCRules"]}
        reg* {set link [list "Registration page: http://pokemon-revolution-online.net/Register.php"]}
        default {set link [list "No such option. Please use !link help for available options or visit http://pastebin.com/9vR9bqG2."]}
      }   
      foreach elem $link {
        putquick "NOTICE $target :$elem"
      }
      if {$nick ne $target} {
        putquick "NOTICE $nick :Link sent to $target!"
      }
    } else {
      putquick "NOTICE $nick :$target is not a valid username!"
    }
  }
}

proc pro:newbtest {nick host hand chan} {
  global trigger
  lappend trigger $nick
  after 200000 [list pro:removenick $nick]
}

proc pro:removenick {nick} {
  global trigger
  set idx [lsearch $trigger $nick]
  set trigger [lreplace $trigger $idx $idx]
}

proc pro:commands {nick host hand args} {
  if {[string index [lindex $args 0] 0] eq "#"} {
    set arg [lindex [lassign $args chan] 0]
  } else {
    set arg $nick
  }
  if {$arg != ""} {
    set nick [string trim $arg]
  }
  putquick "NOTICE $nick :Pastebin for commands: http://pastebin.com/9vR9bqG2"
  putquick "NOTICE $nick :!email user                      Displays email registration help to user"
  putquick "NOTICE $nick :!android user                    Displays android help topic and download link"
  putquick "NOTICE $nick :!client user                     Displays help for ghost queue"
  putquick "NOTICE $nick :!loveisland user                 Displays requirements to access Love Island"
  putquick "NOTICE $nick :!trainervalley user              Displays requirements to access Trainer Valley"
  putquick "NOTICE $nick :!ceruleancave user               Displays requirements to access Cerulean Cave"
  putquick "NOTICE $nick :!topic                           Displays current channel topic"
  putquick "NOTICE $nick :!link option user                Displays various links to the user. Use !link help for more info"
  putquick "NOTICE $nick :!updatemirror opts               Displays sets specific info to the download links"
  putquick "NOTICE $nick :!status \[red|blue|yellow] \[user] Displays status of PRO server(s)"
}

proc pro:status {nick host hand args} {
  putlog "$args"
  if {[string index [lindex $args 0] 0] eq "#"} {
    set args [lindex [lassign $args chan] 0]
  }
  putlog "$args"
  set links [list]
  switch -regexp [lindex $args 0] {
    {^(?:r|red)$} {
      lappend links Red "http://pokemon-revolution-online.net/ServerStatus.php"
      set dest [lindex $args 1]
    }
    {^(?:b|blue)} {
      lappend links Blue "http://pokemon-revolution-online.net/ServerStatusB.php"
      set dest [lindex $args 1]
    }
    {^(?:y|yellow)} {
      lappend links Yellow "http://pokemon-revolution-online.net/ServerStatusY.php"
      set dest [lindex $args 1]
    }
    default {
      lappend links Red "http://pokemon-revolution-online.net/ServerStatus.php"
      lappend links Blue "http://pokemon-revolution-online.net/ServerStatusB.php"
      lappend links Yellow "http://pokemon-revolution-online.net/ServerStatusY.php"
      set dest [lindex $args 1]
    }
  }
  
  if {$dest eq ""} {
    if {[lindex $args 0] eq "" || [lindex $args 0] in {r b y red blue yellow}} {
      set dest $nick
    } else {
      putlog "$args $chan"
      set dest [string trim [lindex $args 0 0]]
      if {![onchan $dest $chan]} {
        putquick "NOTICE $nick :$dest is not a valid username!"
        return
      }
    }
  }
  
  set res [list]
  foreach {server link} $links {
    set token [::http::geturl $link]
    set file [::http::data $token]
    ::http::cleanup $token
    regexp {<[^>]+>([^<>]+)<[^>]+>} $file - data
    lappend res "$server server status: $data"
  }
  
  foreach result $res {
    putquick "NOTICE $dest :$result"
  }
}

proc pro:time {nick hand host chan arg} {
  set time [clock format [clock scan now] -format "%H:%M"]
  lassign [split $time :] h m
  set m [expr {$h*60+$m}]
  set res [expr {5*$m+180}]
  set h [expr {($res/60)%24}]
  set m [expr {$res%60}]
  putquick "NOTICE $nick :Time in PRO is [format %02d:%02d $h $m]"
}

putlog "loaded proserver.tcl"