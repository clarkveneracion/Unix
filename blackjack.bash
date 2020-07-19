#!/bin/bash
clear
toilet -f smblock -F metal '		  	   BLACKJACK'
function ProgressBar {
	let _progress=(${1}*100/${2}*100)/100
	let _done=(${_progress}*4)/10
	let _left=40-$_done
	_fill=$(printf "%${_done}s")
	_empty=$(printf "%${_left}s")

printf "\rLOADING : [${_fill// /\#}${_empty// /-}] ${_progress}%%"
}

_start=1
_end=100
for number in $(seq ${_start} ${_end})
do
	sleep 0.1
	ProgressBar ${number} ${_end}
done
clear
printf '\nLets Play BLACKJACK!\n'


function display-helper() {
	sed -e 's/./&,/g; s/0/10/g; s/,$//'
}

function display-hand() {
	local hand card type
	hand=$1
	type=$2
	case $type in
	dealer) echo ${hand:0:1}? | display-helper;;
	player) echo "$(echo ${hand} | display-helper) [$(count-value $hand)]";;
	full) echo "$(echo ${hand} | display-helper) [$(count-value $hand)]";;
	esac
}

function clear-used() {
	>$USEDCARDS
}

function add-used() {
	local hand
	hand=$1
	echo $USEDCARDS | shuf >> $CARDFILE
	clear-used
}

function shuffle-cards() {
	local line array
	array=(A 2 3 4 5 6 7 8 9 0 J Q K)
	seq 0 52 | while true; do
		read line || break
		echo ${array[$(($line / 4))]}
	done | head -n 52 | shuf > $CARDFILE
}

function draw-card() {
	if [ $(wc -l <$CARDFILE) -lt 5 ]; then
		reshuffle-cards
	fi
	head -n 1 $CARDFILE
	sed -e '1d' $CARDFILE -i
}

function count-value() {
	local hand aces value card i
	hand=$1
	aces=0
	value=0
	for ((i=0; i<${#hand}; i++)); do
		card=${hand:i:1}
		((value += $(echo $card | sed -e '/[1-9]/q; s/[0JQK]/10/; s/A/11/')))
		if [ $card = A ]; then
			((aces ++))
		fi
	done
	while [ $value -gt 21 -a $aces -gt 0 ]; do
		((value -=10))
		((aces --))
	done
	echo $value
}

function play-dealer() {
	local hand
	if [ -n "$1" ]; then
		hand=$1
	else
		hand=$(draw-card)$(draw-card)
	fi
	while [ $(count-value $hand) -lt 17 ]; do
		hand=$hand$(draw-card)
	done
	echo $hand
}

function get-char() {
	local line
	read line 
	echo ${line:0:1}
}

function get-my-input() {
	echo -n "What to do? [H]hit, [S]stand: " >&2
	case $(get-char) in
		[hH]) echo hit;;
		[sS]) echo stand;;
		*) echo $(get-my-input);;
	esac
}

function play-again() {
	echo -n "Play again!?   [Y]yes [N]no:" >&2
	case $(get-char) in
		[yY]) echo yes;;
		"") echo yes;;
		[nN]) echo no;;
		*) play-again;;
	esac
}

function get-a-bet() {
	local mabet bet
	maxbet=$1
	echo -n "You have $maxbet dollars, BET: " >&2
	read bet
	bet=${bet//[^0-9]/}
	if [ -z "$bet" ]; then
		get-a-bet $maxbet
	elif [ "$bet" -gt $maxbet -o "$bet" -lt 1 ]; then
		get-a-bet $maxbet
	else
		echo $bet
	fi
}

function play-round() {
	local dealer player dcount pcount pmoney pbet
	pmoney=$1
	pbet=$(get-a-bet $pmoney)
	dealer=$(draw-card)
	player=$(draw-card)
	dealer=$dealer$(draw-card)
	player=$player$(draw-card)
	while true;do
		echo Dealer: $(display-hand $dealer dealer)
		echo YOU: $(display-hand $player player)
		case $(get-my-input) in
			hit)
				echo HIT!
				player=$player$(draw-card)
				if [ $(count-value $player) -gt 21 ]; then
					break
				fi;;
			stand)
				echo STAND!
				break;;
		esac
	done
	pcount=$(count-value $player)
	if [ $pcount -gt 21 ]; then
		echo "You bust!"
		((pmoney -= $pbet))
	else
		dealer=$(play-dealer $dealer)
		dcount=$(count-value $dealer)
		echo Dealer: $(display-hand $dealer full)
		echo You: $(display-hand $player full)
		if [ $dcount -gt 21 ]; then
			echo "Dealer bust! you win!"
			((pmoney += $pbet))
		elif [ $pcount -gt $dcount ]; then
			echo "You win!"
			((pmoney += $pbet))
		elif [ $dcount -gt $pcount ]; then
			echo "You lose!"
			((pmoney -= $pbet))
		else
			echo "DRAW!"
		fi
	fi
	add-used $dealer
	add-used $player
	case $(play-again) in
		yes)
			if [ $pmoney -gt 0 ]; then
				play-round $pmoney
			else
				echo "Insufficient funds!"
			fi;;
		no) ;;
	esac
}

function main() {
	clear-used
	shuffle-cards
	play-round 10
}

PREFIX=$PWD
if [ -L "$0" ]; then
	PREFIX=$(ls -l "$0" | sed -e 's/.*-> \(.*\)/\1/')
	PREFIX=${PREFIX%/*}
fi
CARDFILE=$PREFIX/cards
USEDCARDS=$PREFIX/usedcards
main "$@"
