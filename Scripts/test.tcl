proc rand {num} {
  return [expr {int(rand()*$num)}]
}

source chat.tcl
source pokemon.tcl

set poke(chan) "#channel"
!challenge
poke:accept TrainerA host hand "#channel" ""
poke:battleprep TrainerA host hand "Gengar/100/Levitate/Pecha Berry/Timid/M/255/31/31/31/31/31/31/4/252/0/0/0/252/Sludge Bomb/Disable/Substitute/Shadow Ball"
poke:battleprep TrainerA host hand "Charizard/100/Blaze/Pecha Berry/Gentle/M/255/31/31/31/31/31/31/4/0/252/0/0/252/Ember/Flamethrower/Scratch/Dragon Rage"
poke:battleprep TrainerA host hand "Beedrill/100/Swarm/Pecha Berry/Gentle/M/255/31/31/31/31/31/31/4/0/252/0/0/252/Harden/Poison Sting/Focus Energy/Twineedle"

poke:battleprep TrainerB host hand "Breloom/100/Poison Heal/Sky Gem/Hasty/M/255/31/31/31/31/31/31/4/252/0/0/0/252/Seed Bomb/Spore/Sky Uppercut/Leech Seed"
poke:battleprep TrainerB host hand "Lucario/100/Justified/Pecha Berry/Gentle/M/255/31/31/31/31/31/31/4/252/0/0/0/252/Metal Claw/Metal Sound/Close Combat/Force Palm"
poke:battleprep TrainerB host hand "Blastoise/100/Torrent/Pecha Berry/Gentle/M/255/31/31/31/31/31/31/4/0/252/0/0/252/Water Gun/Surf/Skull Bash/Hydro Pump"

poke:battleprep TrainerA host hand done
poke:battleprep TrainerA host hand Y
poke:battleprep TrainerB host hand done
poke:battleprep TrainerB host hand Y
    
poke:battle TrainerA host hand "move Substitute"
poke:battle TrainerB host hand "move Leech Seed"

# full moves testing
if {1} {return}
set trainer [lindex $poke(team) 0 0]
set otrainer [lindex $poke(team) 1 0]
set pokedet [lindex $poke(team) 0 1 0]
set opokedet [lindex $poke(team) 1 1 0]

poke:move:followme $trainer $pokedet $otrainer $opokedet

if {1} {return}
set moves [lsearch -all -inline [info procs] poke:move:*]
foreach move $moves {
  if {[catch {$move $trainer $pokedet $otrainer $opokedet} err msg]} {break}
}
