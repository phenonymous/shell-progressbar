#!/usr/bin/env sh

#    An asynchronous progress bar inspired by APT PackageManagerFancy Progress
#    Copyright (C) 2018  Kristoffer Minya
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <https://www.gnu.org/licenses/>
set -a

percentage="0.0"
last_reported_progress=-1

#-- In which rate reporting should be done
reporting_steps=${reporting_steps:-1}       # reporting_step can be set by the user, defaults to 1

#-- Options to change progressbar look
LEFT_BRACKET="${LEFT_BRACKET:-[}"
RIGHT_BRACKET="${RIGHT_BRACKET:-]}"
FILL="${FILL:-#}"
REMAIN="${REMAIN:-.}"
OS="$(uname)"

#-- Solaris uses an old version of awk as standard
if [ "$OS" = "SunOS" ]; then
  PATH="/usr/xpg4/bin:$PATH"
fi

#-- FreeBSD uses termcap names instead of terminfo
if [ "$OS" = "FreeBSD" ]; then
  foreground="${foreground:-$(tput AF 0)}" # Foreground can be set by the user, defaults to black
  background="${background:-$(tput AB 2)}" # Background can be set by the user, defaults to green
  reset_color="$(tput me)"

  #-- Command aliases for readability
  save_cursor='tput sc'
  restore_cursor='tput rc'
  disable_cursor='tput vi'
  enable_cursor='tput ve'
  scroll_area='tput cs'
  move_to='tput cm'
  move_up='tput UP'
  flush='tput cd'
else
  foreground="${foreground:-$(tput -T xterm setaf 0)}" # Foreground can be set by the user, defaults to black
  background="${background:-$(tput -T xterm setab 2)}" # Background can be set by the user, defaults to green
  reset_color="$(tput sgr0)"

  #-- Command aliases for readability
  save_cursor='tput sc'
  restore_cursor='tput rc'
  disable_cursor='tput civis'
  enable_cursor='tput cnorm'
  scroll_area='tput csr'
  move_to='tput cup'
  move_up='tput cuu'
  flush='tput ed'
fi

# Bash does not handle floats
# This section defines some math functions using awk
# ==================================================


math__floor() {
  #-- This function takes a pseudo-floating point as argument
  #-- and rounds down to nearest integer
  awk -v f="$1" 'BEGIN{f=int(f); print f}'
}

math__round() {
  #-- This function takes a pseudo-floating point as argument
  #-- and rounds to nearest integer
  awk -v f="$1" 'BEGIN {printf "%.0f\n", f}'
}

math__min() {
  #-- Takes two values as arguments and compare them
  awk -v f1="$1" -v f2="$2" 'BEGIN{if (f1<=f2) min=f1; else min=f2; printf min "\n"}'
}

math__max() {
  #-- Takes two values as arguments and compare them
  awk -v f1="$1" -v f2="$2" 'BEGIN{if (f1>f2) max=f1; else max=f2; printf max "\n"}'
}

math__calc() {
  #-- Normal calculator
  awk "BEGIN{print $*}"
}


####################################################



# The main function stack
# ==================================================


__tty_size(){
  HEIGHT=${LINES:-$(tput lines)}
  WIDTH=${COLUMNS:-$(tput cols)}
}

__change_scroll_area() {
  n_rows=$1
  #-- Return if number of lines is 1
  if [ $n_rows -lt 1 ]; then
    return 1
  fi

  n_rows=$((n_rows-2))

  #-- Go down one line to avoid visual glitch 
  #-- when terminal scroll region shrinks by 1
  echo

  #-- Save cursor position
  eval "${save_cursor}"

  #-- Set scroll region
  if [ "$OS" = "FreeBSD" ]; then 
    eval "${scroll_area} $n_rows 0"
  else
    eval "${scroll_area} 0 $n_rows"
  fi

  #-- Restore cursor
  eval "${restore_cursor}"

  #-- Move up 1 line in case cursor was saved outside scroll region
  eval "${move_up} 2"
  
  echo

  #-- Set tty size to reflect changes to scroll region
  #-- this is to avoid i.e pagers to override the progress bar
  n_rows=$((n_rows+1))

  #-- Temporarily disabling SIGWINCH to avoid a loop caused by stty sending SIGWINCH whenever theres a change in size
  trap '' WINCH
  stty rows $n_rows
  trap handle_sigwinch WINCH
}

__status_changed() {
  StepsDone=$1
  TotalSteps=$2
  
  #-- FIXME
  #-- Sanity check reporting_steps, if this value is too big no progress will be written
  #-- Should that really be checked here?

  percentage=$(math__calc "$(math__calc "$StepsDone/$TotalSteps")*100.00")

  __int_percentage=$(math__round "$percentage")

  #-- Note: Below string is not POSIX compliant
  #progress_str="$(printf "Progress: [%3li%%]" $__int_percentage)"
  it=0
  gaps=""
  if [ ${#__int_percentage} -lt 3 ]; then
    while [ $it -lt $((3-(${#__int_percentage}%3))) ]; do
      gaps="${gaps} "
      it=$((it+1))
    done
  fi
  progress_str="Progress: [${gaps}${__int_percentage}%]"

  if [ $__int_percentage -lt $((last_reported_progress + reporting_steps)) ]; then
    return 1
  else
    return 0
  fi
}

__progress_string() {
  output=""
  Percent="$1"
  OutputSize=$2

  #-- Return an empty string if OutputSize is less than 3
  if [ $OutputSize -lt 3 ]; then
    echo "$output"
    return 1
  fi

  BarSize=$((OutputSize-2))
  
  BarDone=$(math__max 0 "$(math__min $BarSize "$(math__floor "$(math__calc "$Percent*$BarSize")")")")
  
  output="${LEFT_BRACKET}"
  it=0
  while [ $it -lt $BarDone ]; do
    output="${output}${FILL}"
    it=$((it+1))
  done
  it=0
  while [ $it -lt $((BarSize-BarDone)) ]; do
    output="${output}${REMAIN}"
    it=$((it+1))
  done
  output="${output}${RIGHT_BRACKET}"
  echo "$output"
  return 0
}

__draw_status_line(){
  __tty_size
  if [ $HEIGHT -lt 1 ] || [ $WIDTH -lt 1 ]; then
    return 1
  fi

  padding=4
  progress_bar=""

  #-- Save the cursor
  eval "${save_cursor}"
  #-- Make cursor invisible
  eval "${disable_cursor}"

  #-- Move to last row
  if [ "$OS" = "FreeBSD" ]; then
    eval "${move_to} 0 $((HEIGHT))"
  else
    eval "${move_to} $((HEIGHT)) 0"
  fi
  printf '%s' "${background}${foreground}${progress_str}${reset_color}"

  progressbar_size=$((WIDTH-padding-${#progress_str}))
  current_percent=$(math__calc "$percentage/100.00")
  
  progress_bar="$(__progress_string "${current_percent}" ${progressbar_size})"

  printf '%s' " ${progress_bar} "

  #-- Restore the cursor
  eval "${restore_cursor}"
  eval "${enable_cursor}"

  last_reported_progress=$(math__round "$percentage")

  return 0
}

bar__start() {
  E_START_INVOKED=-1
  __tty_size
  __change_scroll_area $HEIGHT
}

bar__stop() {
  E_STOP_INVOKED=-1
  if [ ! ${E_START_INVOKED:-0} -lt 0 ]; then
    echo "Warn: bar__stop called but bar__start was not invoked" >&2 
    echo "Returning.." # Exit or return?
    return 1
  fi
  #-- Reset bar__start check
  E_START_INVOKED=0

  __tty_size
  if [ $HEIGHT -gt 0 ]; then
    #-- Passing +2 here because we changed tty size to 1 less than it actually is
    __change_scroll_area $((HEIGHT+2))
    echo "test"
    #-- tput ed might fail (OS X) in which case we force clear
    #-- POSIX sh don't specify ERR, this is a work around
    set -e
    trap 'printf "\033[J"; trap handle_exit EXIT HUP INT QUIT PIPE TERM' EXIT
    set +e

    #-- Flush progress bar
    eval "${flush}"

    #-- Go up one row after flush
    echo
    eval "${move_up} 1"
  fi
  #-- Restore original (if any) handler
  trap - WINCH
  return 0
}

bar__status_changed() {
  if [ ! ${E_START_INVOKED:-0} -lt 0 ]; then
    echo "ERR: bar__start not called" >&2
    echo "Exiting.."
    exit 1
  fi

  StepsDone=$1
  TotalSteps=$2

  if ! __status_changed $StepsDone $TotalSteps; then
    return 1
  fi
  
  __draw_status_line
  return $?
}


####################################################


# This section defines some functions that should be
# triggered for traps
# ==================================================


handle_sigwinch(){
  __tty_size
  n_rows=$HEIGHT
  __change_scroll_area $n_rows
  __draw_status_line
}

handle_exit(){
  #-- if stop_exit doesn't have value it means it wasn't invoked
  if [ ! ${E_STOP_INVOKED:-0} -lt 0 ]; then 
    bar__stop
  fi
  trap - EXIT
}


####################################################

trap handle_sigwinch WINCH
trap handle_exit EXIT HUP INT QUIT PIPE TERM
