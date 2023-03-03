# Rust Version Manager
# ====================
#
# To use the rustvm command source this file from your bash profile.

rustvm_VERSION="0.5.1"
rustvm_NIGHTLY_PATTERN="nightly(\.[0-9]+)?"
rustvm_BETA_PATTERN="beta(\.[0-9]+)?"
rustvm_NORMAL_PATTERN="[0-9]+\.[0-9]+(\.[0-9]+)?(-(alpha|beta)(\.[0-9]*)?)?"
rustvm_RC_PATTERN="$rustvm_NORMAL_PATTERN-rc(\.[0-9]+)?"
rustvm_VERSION_PATTERN="($rustvm_NIGHTLY_PATTERN|$rustvm_NORMAL_PATTERN|$rustvm_RC_PATTERN|$rustvm_BETA_PATTERN)"
rustvm_LAST_INSTALLED_VERSION=

if [ -n "$ZSH_VERSION" ]
then
  rustvm_SCRIPT=${(%):-%N}
  rustvm_SCRIPT="$(cd -P "$(dirname "$rustvm_SCRIPT")" && pwd)/$(basename "$rustvm_SCRIPT")"
else
  rustvm_SCRIPT=${BASH_SOURCE[0]}
fi

rustvm_ARCH=`uname -m`
rustvm_OSTYPE=`uname -s`
case $rustvm_OSTYPE in
  Linux)
    rustvm_PLATFORM=$rustvm_ARCH-unknown-linux-gnu
    ;;
  Darwin)
    rustvm_PLATFORM=$rustvm_ARCH-apple-darwin
    ;;
  *)
    ;;
esac

# Auto detect the rustvm_DIR
if [ ! -d "$rustvm_DIR" ]
then
  export rustvm_DIR=$(cd $(dirname ${BASH_SOURCE[0]:-$0}) && pwd)
fi

rustvm_initialize()
{
  if [ ! -d "$rustvm_DIR/versions" ]
  then
    mkdir -p "$rustvm_DIR/versions"
  fi
  if [ ! -f "$rustvm_DIR/.rustvm_version" ]
  then
    touch "$rustvm_DIR/.rustvm_version"
  fi
  local rustvm_version=$(cat "$rustvm_DIR/.rustvm_version")
  if [ -z "$rustvm_version" ]
  then
    local DIRECTORIES=$(find "$rustvm_DIR" -maxdepth 1 -mindepth 1 -type d -exec basename '{}' \; \
      | sort \
      | egrep "^$rustvm_VERSION_PATTERN")

    mkdir -p "$rustvm_DIR/versions"
    for line in $(echo $DIRECTORIES | tr " " "\n")
    do
      mv "$rustvm_DIR/$line" "$rustvm_DIR/versions"
    done
  fi
  echo "1" > "$rustvm_DIR/.rustvm_version"
}


rustvm_check_etag()
{
  # Check which md5sum to use
  if [ -f "$(which md5sum)" ]; then
      MD5=md5sum
  elif [ -f "$(which md5)" ]; then
      MD5=md5
  else
      echo "md5sum not found!"
      exit 1
  fi

  if [ -f $2.etag ]
  then
    curl -s -I -H "If-None-Match:$(cat $2.etag)" $1 | grep 304 | wc -l
  elif [ -f $2 ]
  then
    local ETAG=$($MD5 $2 | awk '{print $1}')
    curl -s -I -H "If-None-Match:\"$ETAG\"" $1 | grep 304 | wc -l
  else
    echo 0
  fi
}

rustvm_file_download()
{
  local OPTS
  # download custom etag
  if [ "$3" = true ]
  then
    curl -I -s $1 | grep ETag | awk '{print $2}' > $2.etag
    OPTS='-#'
  else
    OPTS='-s'
  fi

  #echo $1 $2

  if [ $(rustvm_check_etag $1 $2) = 0 ]
  then
    # not match etag; new download
    curl $OPTS -o $2 $1
  else
    # match etag; resume download
    curl $OPTS -o $2 -C - $1
  fi

}

rustvm_append_path()
{
  local newpath
  if [[ ":$1:" != *":$2:"* ]];
  then
    newpath="${1:+"$1:"}$2"
  else
    newpath="$1"
  fi
  echo $newpath
}

export LD_LIBRARY_PATH=$(rustvm_append_path $LD_LIBRARY_PATH "$rustvm_DIR/current/dist/lib")
export DYLD_LIBRARY_PATH=$(rustvm_append_path $DYLD_LIBRARY_PATH "$rustvm_DIR/current/dist/lib")
export MANPATH=$(rustvm_append_path $MANPATH "$rustvm_DIR/current/dist/share/man")
export rustvm_SRC_PATH="$rustvm_DIR/current/src/rustc-source/src"
if [ -e "$rustvm_SRC_PATH" ]
then
  export RUST_SRC_PATH="$rustvm_SRC_PATH"
else
  unset RUST_SRC_PATH
fi
export CARGO_HOME="$rustvm_DIR/current/cargo"
export RUSTUP_HOME="$rustvm_DIR/current/rustup"

export PATH=$(rustvm_append_path $PATH "$rustvm_DIR/current/dist/bin")
export PATH=$(rustvm_append_path $PATH "$CARGO_HOME/bin")

rustvm_use()
{
  if [ -e "$rustvm_DIR/versions/$1" ]
  then
    echo -n "Activating rust $1 ... "

    rm -rf "$rustvm_DIR/current"
    ln -s "$rustvm_DIR/versions/$1" "$rustvm_DIR/current"
    source $rustvm_SCRIPT

    echo "done"
  else
    echo "The specified version $1 of rust is not installed..."
    echo "You might want to install it with the following command:"
    echo ""
    echo "rustvm install $1"
  fi
}

rustvm_current()
{
  if [ ! -e "$rustvm_DIR/current" ]
  then
    echo "N/A"
    return
  fi
  target=`echo $(readlink "$rustvm_DIR/current"|tr "/" "\n")`
  echo ${target[@]} | awk '{print$NF}'
}

rustvm_ls()
{
  DIRECTORIES=$(find "$rustvm_DIR/versions" -maxdepth 1 -mindepth 1 -type d -exec basename '{}' \; \
    | sort \
    | egrep "^$rustvm_VERSION_PATTERN")

  echo "Installed versions:"
  echo ""

  if [ $(egrep -o "^$rustvm_VERSION_PATTERN" <<< "$DIRECTORIES" | wc -l) = 0 ]
  then
    echo '  -  None';
  else
    for line in $(echo $DIRECTORIES | tr " " "\n")
    do
      if [ `rustvm_current` = "$line" ]
      then
        echo "  =>  $line"
      else
        echo "  -   $line"
      fi
    done
  fi
}

rustvm_init_folder_structure()
{
  echo -n "Creating the respective folders for rust $1 ... "

  mkdir -p "$rustvm_DIR/versions/$1/src"
  mkdir -p "$rustvm_DIR/versions/$1/dist"

  echo "done"
}

rustvm_install()
{
  local CURRENT_DIR=`pwd`
  local target=$1
  local with_rustc_source=$2
  local dirname
  local url_prefix
  local LAST_VERSION
  local RUSTUP_CHANNEL

  if [ ${1: -3} = '-rc' ]
  then
    url_prefix='/staging/dist'
    target=${1%%-rc}
  fi

  if [[ $1 = "nightly" ]] || [[ $1 = "beta" ]] || [ ${1: -3} = '-rc' ]
  then
    # if same version reuse directory
    LAST_VERSION=$(rustvm_ls|grep $1|tail -n 1|awk '{print $2}')
    if [ $(rustvm_check_etag \
             "https://static.rust-lang.org/dist$url_prfix/rust-$target-$rustvm_PLATFORM.tar.gz" \
             "$rustvm_DIR/versions/$LAST_VERSION/src/rust-$target-$rustvm_PLATFORM.tar.gz") = 1 ]
    then
      dirname=$LAST_VERSION
    else
      dirname=$1.`date "+%Y%m%d%H%M%S"`
    fi
    if [[ $1 = "nightly" ]]
    then
      RUSTUP_CHANNEL=$1
    else
      RUSTUP_CHANNEL="beta"
    fi
  else
    dirname=$1
    RUSTUP_CHANNEL=$1
  fi

  rustvm_init_folder_structure $dirname
  local SRC="$rustvm_DIR/versions/$dirname/src"
  local DIST="$rustvm_DIR/versions/$dirname/dist"
  local CARGO="$rustvm_DIR/versions/$dirname/cargo"
  local RUSTUP="$rustvm_DIR/versions/$dirname/rustup"

  cd $SRC

  if [ -z $rustvm_PLATFORM ]
  then
    echo "rustvm: Not support this platform, $rustvm_OSTYPE"
    return
  fi

  echo "Downloading sources for rust $dirname ... "
  rustvm_file_download \
    "https://static.rust-lang.org/dist$url_prfix/rust-$target-$rustvm_PLATFORM.tar.gz" \
    "rust-$target-$rustvm_PLATFORM.tar.gz" \
    true

  if [ -e "rust-$target" ]
  then
    echo "Sources for rust $dirname already extracted ..."
  else
    echo -n "Extracting source ... "
    tar -xzf "rust-$target-$rustvm_PLATFORM.tar.gz"
    mv "rust-$target-$rustvm_PLATFORM" "rust-$target"
    echo "done"
  fi

  if [ "$with_rustc_source" = true ]
  then
    echo "Downloading sources for rustc sourcecode $dirname ... "
    rustvm_file_download \
      "https://static.rust-lang.org/dist$url_prfix/rustc-$target-src.tar.gz" \
      "rustc-$target-src.tar.gz" \
      true
    if [ -e "rustc-source" ]
    then
      echo "Sources for rustc $dirname already extracted ..."
    else
      echo -n "Extracting source ... "
      tar -xzf "rustc-$target-src.tar.gz"
      mv "rustc-$target" "rustc-source"
    fi
  fi

  if [ ! -f $SRC/rust-$target/bin/cargo ] && [ ! -f $SRC/rust-$target/cargo/bin/cargo ]
  then
    echo "Downloading sources for cargo nightly ... "
    rustvm_file_download \
      "https://static.rust-lang.org/cargo-dist/cargo-nightly-$rustvm_PLATFORM.tar.gz" \
      "cargo-nightly-$rustvm_PLATFORM.tar.gz" \
      true

    echo -n "Extracting source ... "
    tar -xzf "cargo-nightly-$rustvm_PLATFORM.tar.gz"
    mv "cargo-nightly-$rustvm_PLATFORM" "cargo-nightly"
    echo "done"

    cd "$SRC/cargo-nightly"
    sh install.sh --prefix=$DIST
  fi

  cd "$SRC/rust-$target"
  sh install.sh --prefix=$DIST

  if [ ! -f $DIST/lib/rustlib/multirust-channel-manifest.toml ]
  then
    echo "Downloading channel manifest ... "
    rustvm_file_download \
      "https://static.rust-lang.org/dist/channel-rust-${RUSTUP_CHANNEL}.toml" \
      "multirust-channel-manifest.toml"
    echo "done"

    cp multirust-channel-manifest.toml $DIST/lib/rustlib/multirust-channel-manifest.toml
  fi

  if [ ! -f $DIST/lib/rustlib/multirust-config.toml ]
  then
    cat << EOF > $DIST/lib/rustlib/multirust-config.toml
config_version = "1"

[[components]]
pkg = "rustc"
target = "$rustvm_PLATFORM"

[[components]]
pkg = "rust-std"
target = "$rustvm_PLATFORM"

[[components]]
pkg = "cargo"
target = "$rustvm_PLATFORM"

[[components]]
pkg = "rust-docs"
target = "$rustvm_PLATFORM"
EOF
  fi

  if [ ! -f $DIST/bin/rustup ]
  then
    echo "Downloading rustup ... "
    rustvm_file_download \
      "https://static.rust-lang.org/rustup/dist/$rustvm_PLATFORM/rustup-init" \
      "rustup"
    echo "done"

    cp rustup $DIST/bin/rustup
    chmod +x $DIST/bin/rustup
  fi

  mkdir -p $RUSTUP/toolchains
  ln -s $DIST $RUSTUP/toolchains/${RUSTUP_CHANNEL}-${rustvm_PLATFORM}
  cat << EOF > $RUSTUP/settings.toml
default_host_triple = "x86_64-unknown-linux-gnu"
default_toolchain = "nightly-x86_64-unknown-linux-gnu"
telemetry = false
version = "12"

[overrides]
EOF

  echo ""
  echo "And we are done. Have fun using rust $dirname."

  cd $CURRENT_DIR
  rustvm_LAST_INSTALLED_VERSION=$dirname
}

rustvm_ls_remote()
{
  local VERSIONS
  local STABLE_VERSION

  if [ -z $rustvm_PLATFORM ]
  then
    echo "rustvm: Not support this platform, $rustvm_OSTYPE"
    return
  fi

  STABLE_VERSION=$(rustvm_ls_channel stable)
  rustvm_file_download https://static.rust-lang.org/dist/index.txt "$rustvm_DIR/cache/index.txt"
  VERSIONS=$(cat "$rustvm_DIR/cache/index.txt" \
    | command egrep -o "^/dist/rust-$rustvm_NORMAL_PATTERN-$rustvm_PLATFORM.tar.gz" \
    | command egrep -o "$rustvm_VERSION_PATTERN" \
    | command sort \
    | command uniq)
  for VERSION in $VERSIONS;
  do
    if [ "$STABLE_VERSION" = "$VERSION" ]
    then
      continue
    fi
    echo $VERSION
  done
  echo $STABLE_VERSION
  rustvm_ls_channel staging
  rustvm_ls_channel beta
  rustvm_ls_channel nightly
}

rustvm_ls_channel()
{
  local VERSIONS
  local POSTFIX

  if [ -z $rustvm_PLATFORM ]
  then
    echo "rustvm: Not support this platform, $rustvm_OSTYPE"
    return
  fi

  case $1 in
    staging|rc)
      POSTFIX='-rc'
      rustvm_file_download https://static.rust-lang.org/dist/staging/dist/channel-rust-stable "$rustvm_DIR/cache/channel-rust-staging"
      VERSIONS=$(cat "$rustvm_DIR/cache/channel-rust-staging" \
        | command egrep -o "rust-$rustvm_VERSION_PATTERN-$rustvm_PLATFORM.tar.gz" \
        | command egrep -o "$rustvm_VERSION_PATTERN" \
        | command sort \
        | command uniq)
      ;;
    stable|beta|nightly)
      rustvm_file_download https://static.rust-lang.org/dist/channel-rust-$1 "$rustvm_DIR/cache/channel-rust-$1"
      VERSIONS=$(cat "$rustvm_DIR/cache/channel-rust-$1" \
        | command egrep -o "rust-$rustvm_VERSION_PATTERN-$rustvm_PLATFORM.tar.gz" \
        | command egrep -o "$rustvm_VERSION_PATTERN" \
        | command sort \
        | command uniq)
      ;;
    *)
      echo "rustvm: Not support this channel, $1"
      return
      ;;
  esac

  for VERSION in $VERSIONS;
  do
    echo $VERSION$POSTFIX
  done
}

rustvm_uninstall()
{
  if [ `rustvm_current` = "$1" ]
  then
    echo "rustvm: Cannot uninstall currently-active version, $1"
    return
  fi
  if [ ! -d "$rustvm_DIR/versions/$1" ]
  then
    echo "$1 version is not installed yet..."
    return
  fi
  echo "uninstall $1 ..."

  case $rustvm_OSTYPE in
    Darwin)
      rm -ri "$rustvm_DIR/versions/$1"
      ;;
    *)
      rm -rI "$rustvm_DIR/versions/$1"
      ;;
  esac
}

rustvm()
{
  rustvm_initialize

  case $1 in
    ""|help|--help|-h)
      echo ''
      echo 'Rust Version Manager'
      echo '===================='
      echo ''
      echo 'Usage:'
      echo ''
      echo '  rustvm help | --help | -h       Show this message.'
      echo '  rustvm install <version>        Download and install a <version>.'
      echo '                                <version> could be for example "0.12.0".'
      echo '  rustvm uninstall <version>      Uninstall a <version>.'
      echo '  rustvm use <version>            Activate <version> for now and the future.'
      echo '  rustvm ls | list                List all installed versions of rust.'
      echo '  rustvm ls-remote                List remote versions available for install.'
      echo '  rustvm ls-channel               Print a channel version available for install.'
      echo ''
      echo "Current version: $rustvm_VERSION"
      ;;
    --version|-v)
      echo "v$rustvm_VERSION"
      ;;
    install)
      if [ -z "$2" ]
      then
        # whoops. no version found!
        echo "Please define a version of rust!"
        echo ""
        echo "Example:"
        echo "  rustvm install 0.12.0"
      elif ([[ "$2" =~ ^$rustvm_VERSION_PATTERN$ ]])
      then
        local version=$2
        local with_rustc_source=true
        for i in ${@:3:${#@}}
        do
          case $i in
            --dry)
              echo "Would install rust $version"
              rustvm_LAST_INSTALLED_VERSION=$version
              rustvm_use $rustvm_LAST_INSTALLED_VERSION
              exit
              ;;
            --without-rustc-source)
              with_rustc_source=false
              ;;
            *)
              ;;
          esac
        done
        rustvm_install "$version" "$with_rustc_source"
        rustvm_use $rustvm_LAST_INSTALLED_VERSION
      else
        # the version was defined in a the wrong format.
        echo "You defined a version of rust in a wrong format!"
        echo "Please use either <major>.<minor> or <major>.<minor>.<patch>."
        echo ""
        echo "Example:"
        echo "  rustvm install 0.12.0"
      fi
      ;;
    ls|list)
      rustvm_ls
      ;;
    ls-remote)
      rustvm_ls_remote
      ;;
    ls-channel)
      if [ -z "$2" ]
      then
        # whoops. no channel found!
        echo "Please define a channel of rust!"
        echo ""
        echo "Example:"
        echo "  rustvm ls-channel stable"
      else
        rustvm_ls_channel $2
      fi
      ;;
    use)
      if [ -z "$2" ]
      then
        # whoops. no version found!
        echo "Please define a version of rust!"
        echo ""
        echo "Example:"
        echo "  rustvm use 0.12.0"
      elif ([[ "$2" =~ ^$rustvm_VERSION_PATTERN$ ]])
      then
        rustvm_use "$2"
      else
        # the version was defined in a the wrong format.
        echo "You defined a version of rust in a wrong format!"
        echo "Please use either <major>.<minor> or <major>.<minor>.<patch>."
        echo ""
        echo "Example:"
        echo "  rustvm use 0.12.0"
      fi
      ;;
    uninstall)
      if [ -z "$2" ]
      then
        # whoops. no version found!
        echo "Please define a version of rust!"
        echo ""
        echo "Example:"
        echo "  rustvm use 0.12.0"
      elif ([[ "$2" =~ ^$rustvm_VERSION_PATTERN$ ]])
      then
        rustvm_uninstall "$2"
      else
        # the version was defined in a the wrong format.
        echo "You defined a version of rust in a wrong format!"
        echo "Please use either <major>.<minor> or <major>.<minor>.<patch>."
        echo ""
        echo "Example:"
        echo "  rustvm uninstall 0.12.0"
      fi
      ;;
    *)
      rustvm
  esac

  echo ''
}
# vim: et ts=2 sw=2
