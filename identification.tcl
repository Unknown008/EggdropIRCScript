##
#	Auto-Identification of bot
##

set botpass "numakuroo"

bind notc - "*nickname is registered and protected*" do:ident
bind pub "m|m" .admin.-ident do:deident
bind pub "m|m" .admin.+ident do:ident
bind pub "m|m" ..-ident do:deident
bind pub "m|m" ..+ident do:ident

proc do:ident { nick host hand chan arg } {
	global botnick botpass
	putquick "PRIVMSG NickServ :IDENTIFY $botpass"
	putquick "PRIVMSG ChanServ :voice"
	putquick "PRIVMSG ChanServ :halfop"
	putquick "PRIVMSG ChanServ :op"
  putlog "\0030,1 \003Identifying as $botnick (requested, $nick)"
}

proc do:deident { nick host hand chan arg } {
	global botnick
	putmsg NickServ "logout"
  putlog "\0030,1 \003De-Identifying as $botnick (requested, $nick)"
}

putlog "Identification loaded"
