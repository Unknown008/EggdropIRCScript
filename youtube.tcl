##
# Configuration
##
package require http

set youtube(timeout)      "30000"
set youtube(output)       "\00301,0\002You\00300,04Tube\002\003 Title: \002%title%\002"
set youtube(pattern)      {http://.*youtube.*/watch\?(.*)v=([A-Za-z0-9_\-]+)}
set youtube(maxredirects) 2
set youtube(maxtitlelen)  256
set youtube(oembedloc)    "http://www.youtube.com/oembed"
set YouTubeVer            "0.5"

bind pubm - * public_youtube

### Allow only users who want to get notified
if {![file exists youtubeusers.conf]} {
  set f [open youtubeusers.conf w]
  close $f
} else {
  set f [open youtubeusers.conf r]
  set ytusers [split [read $f]]
  close $f
}

bind pub - "!youtube" youtube:addremove

proc youtube:addremove {nick host hand chan args} {
  global ytusers
  lassign $args option user
  switch -regexp -- $option {
    ^add$ {
      lappend ytusers $user
    }
    ^(?:rem|del) {
      set id [lsearch $ytusers $user]
      if {$id == -1} {
        putquick "NOTICE $nick :No such user found"
        return
      } else {
        set ytusers [lreplace $ytusers $id $id]
      }
    }
    default {
      putquick "NOTICE $nick :Unknown parameter. Usage: !youtube [add|del] nick"
      return
    }
  }  
  set f [open youtubeusers.conf w]
  puts $f $ytusers
  close $f
}

##
# Procedures
##
proc flat_json_decoder {info_array_name json_blob} {
  upvar 1 $info_array_name info_array
  set kvmode 0
  set cl 0
  set i 1 
  set length [string length $json_blob]
  while { $i < $length } {
    set c [string index $json_blob $i]
    if { [string equal $c "\""] && [string equal $cl "\\"] == 0 } {
      if { $kvmode == 0 } {
        set kvmode 1
        set start [expr $i + 1]
      } elseif { $kvmode == 1 } {
        set kvmode 2
        set name [string range $json_blob $start [expr $i - 1]]
      } elseif { $kvmode == 2 } {
        set kvmode 3
        set start [expr $i + 1]
      } elseif { $kvmode == 3 } {
        set kvmode 0
        set info_array($name) [string range $json_blob $start [expr $i - 1]]
      }
    }
    set cl $c
    incr i 1
  }
}

proc filter_title {blob} {
  set blob [subst -nocommands -novariables $blob]
  set blob [string trim $blob]
  set blob
}

proc extract_title {json_blob} {
  global youtube
  array set info_array {}
  flat_json_decoder info_array $json_blob
  if { [info exists info_array(title)] } {
    set title [filter_title $info_array(title)]
  } else {error "Failed to find title. JSON decoding failure?"}
  if { [string length $title] > $youtube(maxtitlelen) - 1 } {
    set title [string range $title 0 $youtube(maxtitlelen)]"..."
  } elseif { [string length $title] == 0 } {set title "No usable title."}
  return $title
}

proc fetch_title {youtube_uri {recursion_count 0}} {
  global youtube
  if { $recursion_count > $youtube(maxredirects) } {error "maximum recursion met."}
  set query [http::formatQuery url $youtube_uri]
   set response [http::geturl "$youtube(oembedloc)?$query" -timeout $youtube(timeout)]
  upvar #0 $response state
  foreach {name value} $state(meta) {
    if {[regexp -nocase ^location$ $name]} {return [fetch_title $value [incr recursion_count]]}
  }
  if [expr [http::ncode $response] == 401] {
    error "Location contained restricted embed data."
  } else {
    set response_body [http::data $response]
    http::cleanup $response
    return [extract_title $response_body]
  }
}

proc public_youtube {nick userhost handle channel args} {
  global youtube botnick ytusers
  
  if {[regexp -nocase -- $youtube(pattern) $args match fluff video_id]} {
    if {[catch {set title [fetch_title $match]} error]} {
      note "Failed to fetch title: $error"
    } else {
      set tokens [list %botnick% $botnick %post_nickname% $nick %title% "$title" %youtube_url%]
      set result [string map $tokens $youtube(output)]
      foreach user $ytusers {
        putserv "NOTICE $user :$result"
      }
    }
  }
}

putlog "Youtube $YouTubeVer loaded"
