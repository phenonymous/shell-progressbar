#!/usr/bin/env bash

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

# The following terms are used for maintainment
# FIXME  :   Code that needs to improved or does not work
# DEBUG  :   Code that needs to be debugged
# TEST   :   Code that needs to be tested for alternatives 
# TODO   :   Reminder for code that needs to be added or changed
# FUTURE :   For future changes, this must be considered
# IDEA   :   Ideas for future improvement or added features

#-- Error handling
set -euo pipefail

#-- TODO: Write functions for debugging and logging
#-- TODO: Write unit tests
#-- IDEA: Use Bash Infinity

#-- TODO: Port to POSIX - this breaks the above idea
#-- \___  Associative arrays are non-standard

typeset -gA FUNCTION_OUTPUT

#-- Static global variables
typeset -g background foreground reset_color 

#-- Dynamic global variables
typeset -g progress_str percentage
typeset -gi LINES COLUMNS last_reported_progress reporting_steps

percentage="0.0"
last_reported_progress=-1

#-- In which rate reporting should be done
reporting_steps=${reporting_steps:-1}     # reporting_step can be set by the caller, defaults to 1

foreground="${foreground:-$(tput setaf 0)}" # Foreground can be set by the caller, defaults to black
background="${background:-$(tput setab 2)}" # Background can be set by the caller, defaults to green
reset_color="$(tput sgr0)"

#-- Command aliases for readability
save_cursor='tput sc'
restore_cursor='tput rc'
disable_cursor='tput civis'
enable_cursor='tput cnorm'
scroll_area='tput csr'
move_to='tput cup'
move_up='tput cuu 2'
flush='tput ed'


# Bash does not handle floats
# This section defines some math functions using awk
# ==================================================

#-- IDEA: Use large numbers to simulate floating points
#-- That might not be efficient - research needs to be done
#-- FUTURE: [[ is non-standard, replace with [

math::floor() {
  #-- This function takes a pseudo-floating point as argument
  #-- and rounds down to nearest integer
  [[ -n "${FUNCTION_OUTPUT[floor]:-}" ]] && FUNCTION_OUTPUT[floor]=''
  FUNCTION_OUTPUT[floor]="$(awk -v f="$1" 'BEGIN{f=int(f); print f}')"
}

math::ceiling() {
  #-- This function takes a pseudo-floating point as argument
  #-- and rounds up to nearest integer
  [[ -n "${FUNCTION_OUTPUT[ceiling]:-}" ]] && FUNCTION_OUTPUT[ceiling]=''
  FUNCTION_OUTPUT[ceiling]="$(awk -v f="$1" 'BEGIN{f=int(f)+1; print f}')"
}

math::round() {
  #-- This function takes a pseudo-floating point as argument
  #-- and rounds to nearest integer
  [[ -n "${FUNCTION_OUTPUT[round]:-}" ]] && FUNCTION_OUTPUT[round]=''
  FUNCTION_OUTPUT[round]="$(awk -v f="$1" 'BEGIN {printf "%.0f\n", f}')"
}

math::min() {
  #-- Takes two values as arguments and compare them
  [[ -n "${FUNCTION_OUTPUT[min]:-}" ]] && FUNCTION_OUTPUT[min]=''
  FUNCTION_OUTPUT[min]="$(awk -v f1="$1" -v f2="$2" 'BEGIN{if (f1<=f2) min=f1; else min=f2; printf min "\n"}')"
}

math::max() {
  #-- Takes two values as arguments and compare them
  [[ -n "${FUNCTION_OUTPUT[max]:-}" ]] && FUNCTION_OUTPUT[max]=''
  FUNCTION_OUTPUT[max]="$(awk -v f1="$1" -v f2="$2" 'BEGIN{if (f1>f2) max=f1; else max=f2; printf max "\n"}')"
}

#-- TODO: Change name?
math::float_multiplication() {
  #-- Takes two floats and multiply them
  [[ -n "${FUNCTION_OUTPUT[multiplication]:-}" ]] && FUNCTION_OUTPUT[multiplication]=''
  FUNCTION_OUTPUT[multiplication]="$(awk -v f1="$1" -v f2="$2" 'BEGIN{print f1 * f2}')  "
}

#-- TODO: Change name?
math::float_division() {
  #-- Takes two floats and divide them
  [[ -n "${FUNCTION_OUTPUT[division]:-}" ]] && FUNCTION_OUTPUT[division]=''
  FUNCTION_OUTPUT[division]="$(awk -v f1="$1" -v f2="$2" 'BEGIN{print f1 / f2}')"
}


####################################################



# The main function stack
# ==================================================


__status_changed() {
  typeset -i StepsDone TotalSteps __int_percentage
  
  ((StepsDone=$1))
  ((TotalSteps=$2))
  
  #-- FIXME
  #-- Sanity check reporting_steps, if this value is too big no progress will be written
  #-- Should that really be checked here?

  math::float_division $StepsDone $TotalSteps
  math::float_multiplication "${FUNCTION_OUTPUT[division]}" "100.00"
  percentage="${FUNCTION_OUTPUT[multiplication]}"
  
  math::round "$percentage"

  ((__int_percentage=FUNCTION_OUTPUT[round]))

  #-- FUTURE: printf -v is non-standard, for POSIX replace with subshell
  builtin printf -v progress_str "Progress: [%3li%%]" $__int_percentage

  if (( __int_percentage < (last_reported_progress + reporting_steps) )); then
    return 1
  else
    return 0
  fi
}

__tty_size(){
  LINES=${LINES:-$(tput lines)}
  COLUMNS=${COLUMNS:-$(tput cols)}
}

__change_scroll_area() {
  typeset -i n_rows=$1
  #-- Return if number of lines is 1
  if (( n_rows <= 1)); then
    return 1
  fi

  ((n_rows=n_rows-2))

  #-- Go down one line to avoid visual glitch 
  #-- when terminal scroll region shrinks by 1
  builtin echo

  #-- Save cursor position
  ${save_cursor}

  #-- Set scroll region
  ${scroll_area} 0 $n_rows

  #-- Restore cursor
  ${restore_cursor}

  #-- Move up 1 line in case cursor was saved outside scroll region
  ${move_up}
  builtin echo

  #-- Set tty size to reflect changes to scroll region
  #-- this is to avoid i.e pagers to override the progress bar
  ((++n_rows))
  
  #-- Temporarily disabling SIGWINCH to avoid a loop caused by stty sending SIGWINCH whenever theres a change in size
  trap '' WINCH
  stty rows $n_rows
  trap handle_sigwinch WINCH
}

bar::start() {
  #-- TODO: Track process that called this function
  # proc...
  __tty_size
  __change_scroll_area $LINES
}

bar::stop() {
  __tty_size
  if ((LINES > 0)); then
    #-- Passing +2 here because we changed tty size to 1 less than it actually is
    __change_scroll_area $((LINES+1))

    #-- Flush progress bar
    ${flush}
  fi
  #-- Restore original (if any) handler
  trap - WINCH
}

__progress_string() {
  [[ -n ${FUNCTION_OUTPUT[progress]:-} ]] && FUNCTION_OUTPUT[progress]=''
  
  local output Percent
  typeset -i OutputSize BarSize BarDone it
  
  output=""
  Percent="$1"
  ((OutputSize=$2))

  #-- Return an empty string if OutputSize is less than 3
  if ((OutputSize < 3)); then
    FUNCTION_OUTPUT[progress]="$output"
    return 1
  fi

  ((BarSize=OutputSize-2))
  
  math::float_multiplication "$Percent" $BarSize
  math::floor "${FUNCTION_OUTPUT[multiplication]}"
  math::min $BarSize "${FUNCTION_OUTPUT[floor]}"
  math::max 0 "${FUNCTION_OUTPUT[min]}"
  
  ((BarDone=FUNCTION_OUTPUT[max]))
  
  output+="["
  for (( it = 0; it < BarDone; it++ )); do
    output+="#"
  done
  for (( it = 0; it < BarSize - BarDone; it++ )); do
    output+="."
  done
  output+="]"
  FUNCTION_OUTPUT[progress]="$output"
  return 0
}

#-- FIXME: Pass worker pid?
bar::status_changed() {
  typeset -i StepsDone TotalSteps

  ((StepsDone=$1))
  ((TotalSteps=$2))

  if ! __status_changed $StepsDone $TotalSteps; then
    return 1
  fi
  
  DrawStatusLine
  return $?
}

__draw_status_line(){
  __tty_size
  if (( LINES < 1 || COLUMNS< 1 )); then
    return 1
  fi

  local current_percent
  typeset -i padding __int_percentage progressbar_size
  ((padding=4))

  #-- Save the cursor
  ${save_cursor}
  ${disable_cursor}

  #-- Move to last row
  ${move_to} $((LINES-1)) 0
  builtin printf '%s' "${background}${foreground}${progress_str}${reset_color}"

  ((progressbar_size=COLUMNS-padding-${#progress_str}))
  math::float_division "$percentage" "100.00"
  current_percent="${FUNCTION_OUTPUT[division]}"
  
  __progress_string ${current_percent} ${progressbar_size}

  builtin builtin printf '%s' " ${FUNCTION_OUTPUT[progress]} "

  #-- Restore the cursor
  ${restore_cursor}
  ${enable_cursor}

  math::round "$percentage"
  ((__int_percentage=FUNCTION_OUTPUT[round]))

  ((last_reported_progress=__int_percentage))

  return 0
}


####################################################



# This section defines some functions that should be
# triggered for traps
# ==================================================


handle_sigwinch(){
  __tty_size
  typeset -i n_rows
  ((n_rows=LINES))
  __change_scroll_area $n_rows
  __draw_status_line
}

#-- TODO: Trap this with SIGCHLD and let child fire this signal to parent
handle_worker_done(){
  echo 
}


####################################################

trap handle_sigwinch WINCH
trap 'Stop; trap - EXIT' EXIT HUP INT QUIT PIPE TERM