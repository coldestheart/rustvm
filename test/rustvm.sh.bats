#!/usr/bin/env bats

# load the rustvm
source ./rustvm.sh

# override the rustvm_DIR
export rustvm_DIR=`pwd`/bats_test

function cleanup()
{
  rm -rf $rustvm_DIR
}

@test "'rustvm' prints the help" {
  cleanup
  run rustvm
  [ "${lines[0]}" = "Rust Version Manager" ]
  [ "${lines[2]}" = "Usage:" ]
  [ "${lines[3]}" = "  rustvm help | --help | -h       Show this message." ]
  cleanup
}

@test "'rustvm help' prints the help" {
  cleanup
  run rustvm help
  [ "${lines[3]}" = "  rustvm help | --help | -h       Show this message." ]
  cleanup
}

@test "'rustvm --help' prints the help" {
  cleanup
  run rustvm --help
  [ "${lines[3]}" = "  rustvm help | --help | -h       Show this message." ]
  cleanup
}

@test "'rustvm -h' prints the help" {
  cleanup
  run rustvm -h
  [ "${lines[3]}" = "  rustvm help | --help | -h       Show this message." ]
  cleanup
}

@test "'rustvm install' prints a notice that no version was defined" {
  cleanup
  run rustvm install
  [ "${lines[0]}" = "Please define a version of rust!" ]
  cleanup
}

@test "'rustvm install 0.1.1.1.1' prints a notice that the format is wrong" {
  cleanup
  run rustvm install 0.1.1.1.1
  [ "${lines[0]}" = "You defined a version of rust in a wrong format!" ]
  cleanup
}

@test "'rustvm install v0.4' prints a notice that the format is wrong" {
  cleanup
  run rustvm install v0.4
  [ "${lines[0]}" = "You defined a version of rust in a wrong format!" ]
  cleanup
}

@test "'rustvm install 1' prints a notice that the format is wrong" {
  cleanup
  run rustvm install 1
  [ "${lines[0]}" = "You defined a version of rust in a wrong format!" ]
  cleanup
}

@test "'rustvm install 0.4' is not complaining" {
  cleanup
  run rustvm install 0.4 --dry
  [ "${lines[0]}" = "Would install rust 0.4" ]
  cleanup
}

@test "'rustvm install 0.4.1' is not complaining" {
  cleanup
  run rustvm install 0.4.1 --dry
  [ "${lines[0]}" = "Would install rust 0.4.1" ]
  cleanup
}

@test "'rustvm ls' will return an empty list if no versions have been installed" {
  cleanup
  run rustvm ls
  [ "${lines[0]}" = "Installed versions:" ]
  [ "${lines[1]}" = "  -  None" ]
  cleanup
}

@test "'rustvm list' will return an empty list if no versions have been installed" {
  cleanup
  run rustvm list
  [ "${lines[0]}" = "Installed versions:" ]
  [ "${lines[1]}" = "  -  None" ]
  cleanup
}

@test "'rustvm ls' will return the installed versions" {
  cleanup
  run rustvm_init_folder_structure 0.1
  run rustvm_init_folder_structure 0.5

  run rustvm ls
  [ "${lines[0]}" = "Installed versions:" ]
  [ "${lines[1]}" = "  -   0.1" ]
  [ "${lines[2]}" = "  -   0.5" ]

  cleanup
}

@test "'rustvm use' will notify the user about missing version" {
  cleanup
  run rustvm use
  [ "${lines[0]}" = "Please define a version of rust!" ]
  cleanup
}

@test "'rustvm use' will notify the user about a malformed version" {
  cleanup
  run rustvm use 1.1.1.1.1
  [ "${lines[0]}" = "You defined a version of rust in a wrong format!" ]
  cleanup
}

@test "'rustvm use 0.1' will notify the user about a not installed version" {
  cleanup
  run rustvm use 0.1
  [ "${lines[1]}" = "You might want to install it with the following command:" ]
  [ "${lines[2]}" = "rustvm install 0.1" ]
  cleanup
}

@test "'rustvm use 0.1' will activate the right version" {
  cleanup
  run rustvm_init_folder_structure 0.1
  run rustvm use 0.1
  [ "${lines[0]}" = "Activating rust 0.1 ... done" ]
  cleanup
}

@test "'rustvm use nightly' will activate the right version" {
  cleanup
  run rustvm_init_folder_structure nightly.1234
  run rustvm use nightly.1234
  [ "${lines[0]}" = "Activating rust nightly.1234 ... done" ]
  cleanup
}

@test "'rustvm install 0.5' will activate automatic" {
  cleanup
  # dry run not make directory
  run rustvm_init_folder_structure 0.5
  run rustvm install 0.5 --dry
  run rustvm ls
  [ "${lines[0]}" = "Installed versions:" ]
  [ "${lines[1]}" = "  =>  0.5" ]
  cleanup
}

@test "'rustvm uninstall 0.1' will notify the user about a not installed version" {
  cleanup
  run rustvm uninstall 0.1
  [ "${lines[0]}" = "0.1 version is not installed yet..." ]
  cleanup
}

@test "'rustvm uninstall 0.1' will notify the user about current using version" {
  cleanup
  run rustvm_init_folder_structure 0.1
  run rustvm use 0.1
  run rustvm uninstall 0.1
  [ "${lines[0]}" = "rustvm: Cannot uninstall currently-active version, 0.1" ]
  cleanup
}

function uninstall() {
  # FIXME: current bats not support stdin.
  echo "yes" | rustvm uninstall $1
}

@test "'rustvm uninstall 0.1' will remove installed version" {
  cleanup
  run rustvm_init_folder_structure 0.1
  uninstall 0.1
  run rustvm ls
  [ "${lines[0]}" = "Installed versions:" ]
  [ "${lines[1]}" = "  -  None" ]
  cleanup
}
