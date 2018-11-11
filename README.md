# shell-progressbar
 > An asynchronous progressbar for bash shell scripts inspired by APT

## Table of contents
<!-- MarkdownTOC -->

- [Installation](#installation)
- [Usage](#usage)
  - [Example](#example)
- [Customization](#customization)

<!-- /MarkdownTOC -->

![bar](https://raw.githubusercontent.com/phenonymous/shell-progressbar/master/images/progressbar.gif)

This version is POSIX compliant and should work in most shells

### Installation:

Put this anywhere in your script by using curl

```sh
. <(curl -sLo- "https://git.io/progressbarposix")
```
or by using wget

```sh
. <(wget -qO- "https://git.io/progressbarposix")
```

Mac users can use the following instead, where sourcing directly from curl does not work
```sh
eval "$(curl -sLo- "https://git.io/progressbarposix")"
```

On Minix and NetBSD curl and wget might complain about certificates in which case you can use the following instead
```sh
eval "$(curl -ksLo- "https://git.io/progressbarposix")"

eval "$(wget --no-check-certificate -qO- "https://git.io/progressbarposix")"
```

You could also clone this repo and source it locally

### Usage:

Make a call to

```sh
bar__start
```
before any progress should be reported. This will setup the status line by shrinking the terminal scroll area by one row.
Then determine the total steps to be reported - either you're using this in a loop or do manual reporting in your script. What ever way suits your needs, make a call to

```sh
bar__status_changed <steps done> <total steps>
```
whenever progress is made. This function will then determine if the status line should be updated.

Finally make a call to

```sh
bar__stop
```
when you're done and this function will restore the terminal size.

#### Example

```sh
#!/usr/bin/env sh

eval "$(wget -qO- "https://git.io/progressbarposix")"

bar__start

i=1
while [ $i -le 10 ]; do
  # Do stuff
  echo "Invoking stuff${i} to do some stuffs..."
  bar__status_changed $i 10
  i=$((i+1))
  sleep 1
done

bar__stop
```

### Customization

If you want to customize your progress string then change the following variables, shown below with defaults

```sh
LEFT_BRACKET=${LEFT_BRACKET:-"["}
RIGHT_BRACKET=${RIGHT_BRACKET:-"]"}
FILL=${FILL:-"#"}
REMAIN=${REMAIN:-"."}
```
You can change foreground and background color by setting these variables
```sh
foreground="$(tput setaf 0)" # black
background="$(tput setab 2)" # green
```
you can also tweak how often reporting should be done (in case of great number of steps and quick progressing) by setting `reporting_steps` to a value bigger than 1
