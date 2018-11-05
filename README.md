## shell-progressbar
An asynchronous progressbar for bash shell scripts inspired by APT

### Installation:

Put this anywhere in your script by using cURL

```sh
. <(curl -so- "https://github.com/phenonymous/shell-progressbar/blob/master/progress.sh")
```
or by using wget

```sh
. <(wget -qO- "https://github.com/phenonymous/shell-progressbar/blob/master/progress.sh")
```

### Usage:

Make a call to

```sh
Start
```
before any progress should be reported. This will setup the status line by shrinking the terminal scroll area by one row.
Then determine the total steps to be reported - either you're using this in a loop or do manual reporting in your script. What ever way suits your needs, make a call to

```sh
StatusChanged <steps done> <total steps>
```
whenever progress is made. This function will then determine if the status line should be updated.

Finally make a call to

```sh
Stop
```
when you're done and this function will restore the terminal size.

#### Example

```sh
#!/usr/bin/env bash

. <(curl -so- "https://github.com/phenonymous/shell-progressbar/blob/master/progress.sh")

Start

StuffToDo=("Stuff1" "Stuff2" "Stuff3")

TotalSteps=${#StuffToDo[@]}

for Stuff in ${StuffToDo[@]}; do
  # Do stuff
  StepsDone=$((${StepsDone:-0}+1))
  StatusChanged $StepsDone $TotalSteps
done

Stop
```
