## shell-progressbar
An asynchronous progressbar for bash shell scripts inspired by APT for bash4 and zsh

For a POSIX compliant version see instructions in branch POSIX, this includes mac users

![bar](https://raw.githubusercontent.com/phenonymous/shell-progressbar/master/images/progressbar.gif)

### Installation:

Put this anywhere in your script by using cURL

```sh
. <(curl -sLo- "https://git.io/progressbar")
```
or by using wget

```sh
. <(wget -qO- "https://git.io/progressbar")
```

### Usage:

<shadow>see customize for more options</shadow>

Make a call to

```sh
bar::start
```
before any progress should be reported. This will setup the status line by shrinking the terminal scroll area by one row.
Then determine the total steps to be reported - either you're using this in a loop or do manual reporting in your script. What ever way suits your needs, make a call to

```sh
bar::status_changed <steps done> <total steps>
```
whenever progress is made. This function will then determine if the status line should be updated.

Finally make a call to

```sh
bar::stop
```
when you're done and this function will restore the terminal size.

#### Example

```sh
#!/usr/bin/env bash

. <(curl -sLo- "https://git.io/progressbar")

bar::start

StuffToDo=("Stuff1" "Stuff2" "Stuff3")

TotalSteps=${#StuffToDo[@]}

for Stuff in ${StuffToDo[@]}; do
  # Do stuff
  echo "Invoking ${Stuff} to do some stuffs..."
  StepsDone=$((${StepsDone:-0}+1))
  bar::status_changed $StepsDone $TotalSteps
  sleep 1
done

bar::stop
```

### Customization

If you want to customize your progress string then change the following variables, shown below with defaults

```sh
LEFT_BRACKET=${[:-YOURSTRING]
RIGHT_BRACKET=${]:-YOURSTRING}
FILL=${#:-YOURSTRING}
REMAIN=${.:-YOURSTRING}
```