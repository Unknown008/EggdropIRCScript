##
# Web scrapper
##
package require http

set scrapper(site) "http://www.gogoanime.to/"
set scrapper(delay) 5
set scrapper(channel) "#Jerry"
set scrapper(current) [list]

proc html_decode {data} {
  if {![regexp {&.+} $data]} {return $data}
  array set chars {
    nbsp     \x20  amp      \x26  quot     \x22  lt       \x3C
    gt       \x3E  iexcl    \xA1  cent     \xA2  pound    \xA3
    curren   \xA4  yen      \xA5  brvbar   \xA6  brkbar   \xA6
    sect     \xA7  uml      \xA8  die      \xA8  copy     \xA9
    ordf     \xAA  laquo    \xAB  not      \xAC  shy      \xAD
    reg      \xAE  hibar    \xAF  macr     \xAF  deg      \xB0
    plusmn   \xB1  sup2     \xB2  sup3     \xB3  acute    \xB4
    micro    \xB5  para     \xB6  middot   \xB7  cedil    \xB8
    sup1     \xB9  ordm     \xBA  raquo    \xBB  frac14   \xBC
    frac12   \xBD  frac34   \xBE  iquest   \xBF  Agrave   \xC0
    Aacute   \xC1  Acirc    \xC2  Atilde   \xC3  Auml     \xC4
    Aring    \xC5  AElig    \xC6  Ccedil   \xC7  Egrave   \xC8
    Eacute   \xC9  Ecirc    \xCA  Euml     \xCB  Igrave   \xCC
    Iacute   \xCD  Icirc    \xCE  Iuml     \xCF  ETH      \xD0
    Dstrok   \xD0  Ntilde   \xD1  Ograve   \xD2  Oacute   \xD3
    Ocirc    \xD4  Otilde   \xD5  Ouml     \xD6  times    \xD7
    Oslash   \xD8  Ugrave   \xD9  Uacute   \xDA  Ucirc    \xDB
    Uuml     \xDC  Yacute   \xDD  THORN    \xDE  szlig    \xDF
    agrave   \xE0  aacute   \xE1  acirc    \xE2  atilde   \xE3
    auml     \xE4  aring    \xE5  aelig    \xE6  ccedil   \xE7
    egrave   \xE8  eacute   \xE9  ecirc    \xEA  euml     \xEB
    igrave   \xEC  iacute   \xED  icirc    \xEE  iuml     \xEF
    eth      \xF0  ntilde   \xF1  ograve   \xF2  oacute   \xF3
    ocirc    \xF4  otilde   \xF5  ouml     \xF6  divide   \xF7
    oslash   \xF8  ugrave   \xF9  uacute   \xFA  ucirc    \xFB
    uuml     \xFC  yacute   \xFD  thorn    \xFE  yuml     \xFF
    ensp     \x20  emsp     \x20  thinsp   \x20  zwnj     \x20
    zwj      \x20  lrm      \x20  rlm      \x20  euro     \x80
    sbquo    \x82  bdquo    \x84  hellip   \x85  dagger   \x86
    Dagger   \x87  circ     \x88  permil   \x89  Scaron   \x8A
    lsaquo   \x8B  OElig    \x8C  oelig    \x8D  lsquo    \x91
    rsquo    \x92  ldquo    \x93  rdquo    \x94  ndash    \x96
    mdash    \x97  tilde    \x98  scaron   \x9A  rsaquo   \x9B
    Yuml     \x9F  apos     \x27  
  }

  regsub -all -- {&#(\d+);} $data  {[subst -nocomm -novar [format \\\u%04x [scan \1 %d]]]} data
  regsub -all -- {&#x(\w+);} $data {[format %c [scan \1 %x]]} data
  regsub -nocase -all -- {&([0-9A-Z#]*);} $data {[if {[catch {set tmp $chars(\1)} char] == 0} { set tmp }]} data
  regsub -nocase -all -- {&([0-9A-Z#]*);} $data {[if {[catch {set tmp [string tolower $chars(\1)]} char] == 0} { set tmp }]} data
  regsub -all -- {\s{2,}} $data " " data
  
  set data [subst $data]

  return $data
}

proc checksite {} {
  global scrapper
  
  set token [::http::geturl $scrapper(site)]
  set file [::http::data $token]
  ::http::cleanup $token
  regexp -- {<td class="redgr" width="369" valign="top">(.*?)</td>} $file - match
  set results [regexp -all -inline -- {<li>(.*?)</li>} $match]
  
  set new [list]
  foreach {main sub} $results {
    set epname [string trim [regsub -all -- {<[^>]+>} $sub ""]]
    regexp -- {<a href="(.*?)">} $sub - link
    lappend new [html_decode "$epname (link: $link)"]
  }
  
  if {$scrapper(current) != "" && $new != $scrapper(current)} {
    foreach ep $new {
      if {$ep ni $scrapper(current)} {
        putquick "PRIVMSG $scrapper(channel) :$ep"
      }
    }
  }
  set scrapper(current) $new
  
  after [expr {$scrapper(delay)*60*1000}] checksite
}

after 30000 checksite

putlog "Web scrapper loaded"
