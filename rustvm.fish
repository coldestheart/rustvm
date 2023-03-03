#? NVM wrapper. Félix Saparelli. Public Domain
#> https://github.com/passcod/nvm-fish-wrapper
#v 1.1.0

function rustvm_set
  if test (count $argv) -gt 1
    #echo set: k: $argv[1] v: $argv[2..-1]
    set -gx $argv[1] $argv[2..-1]
  else
    #echo unset: k: $argv[1]
    set -egx $argv[1]
  end
end

function rustvm_split_env
  set k (echo $argv | cut -d\= -f1)
  set v (echo $argv | cut -d\= -f2-)
  echo $k
  echo $v
end

function rustvm_find_paths
  echo $argv | grep -oE '[^:]+' | grep -w '.rustvm'
end

function rustvm_set_path
  set k $argv[1]
  set r $argv[2..-1]

  set newpath
  for o in $$k
    if echo $o | grep -qvw '.rustvm'
      set newpath $newpath $o
    end
  end

  for p in (rustvm_find_paths $r)
    set newpath $p $newpath
  end
  rustvm_set $k $newpath
end

function rustvm_mod_env
  set tmpnew $tmpdir/newenv

  bash -c "source ~/.rustvm/rustvm.sh && source $tmpold && rustvm $argv && export status=\$? && env > $tmpnew && exit \$status"

  set rustvmstat $status
  if test $rustvmstat -gt 0
    return $rustvmstat
  end

  rustvm_set RUST_SRC_PATH

  for e in (cat $tmpnew)
    set p (rustvm_split_env $e)

    if test (echo $p[1] | cut -d_ -f1) = rustvm
      if test (count $p) -lt 2
        rustvm_set $p[1] ''
        continue
      end

      rustvm_set $p[1] $p[2..-1]
      continue
    end

    if test $p[1] = PATH
      rustvm_set_path PATH $p[2..-1]
    else if test $p[1] = LD_LIBRARY_PATH
      rustvm_set_path LD_LIBRARY_PATH $p[2..-1]
    else if test $p[1] = DYLD_LIBRARY_PATH
      rustvm_set_path DYLD_LIBRARY_PATH $p[2..-1]
    else if test $p[1] = MANPATH
      rustvm_set_path MANPATH $p[2..-1]
    else if test $p[1] = RUST_SRC_PATH
      rustvm_set RUST_SRC_PATH $p[2..-1]
    else if test $p[1] = CARGO_HOME
      rustvm_set CARGO_HOME $p[2..-1]
    else if test $p[1] = RUSTUP_HOME
      rustvm_set RUSTUP_HOME $p[2..-1]
    end
  end

  return $rustvmstat
end

function rustvm
  set -g tmpdir (mktemp -d 2>/dev/null; or mktemp -d -t 'rustvm-wrapper') # Linux || OS X
  set -g tmpold $tmpdir/oldenv
  env | grep -E '^((rustvm|RUST)_|(MAN)?PATH=)' | sed -E 's/\\\\?([ ()])/\\\\\\1/g' > $tmpold

  set -l arg1 $argv[1]
  if echo $arg1 | grep -qE '^(use|install|deactivate)$'
    rustvm_mod_env $argv
    set s $status
  else if test $arg1 = 'unload' 2>/dev/null
    functions -e (functions | grep -E '^rustvm(_|$)')
  else
    bash -c "source ~/.rustvm/rustvm.sh && source $tmpold && rustvm $argv"
    set s $status
  end

  rm -r $tmpdir
  return $s
end
