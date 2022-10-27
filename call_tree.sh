#!/bin/bash
#$1 caller or callee ?
#$2 function name
#$3 it (iteractive) or maximum level
#$4 maximum caller list

FILE="/dev/shm/funcmem"
MY_EDITOR="qtcreator -client"

declare -Ag hmap

hmap_check_add(){
  #$1 func name
  
  if test -z ${hmap[$1]} ; then
    hmap[$1]=1
    return 0
  else
    return 1
  fi
}

print_func() {
  #$1 name
  #$2 level
  if test "$2" -gt "0"; then
    printf '\t%.s' $(seq 1 $2)
  fi
  echo $1
}

get_callers(){
  #$1 function name
  #$2 opt

  cscope -d -L3 $1 |cut -d' ' -f$2 |sort -u
}

get_callees(){
  #$1 function name
  #$2 opt
  
  cscope -d -L2 $1 |cut -d' ' -f$2 |sort -u
}

edit_file() {
  #$1 caller on get_caller or function on get_callee
  #$2 the oposite
  if test $1 == $2 ; then
    echo "Should not be called on the root function. Functions: \"$1\" and \"$2\" "
    return
  fi

  local myfile=""    
  if test "$GETTER" == "get_callers"; then
    myfile=$(cscope -d -L3 $2 |grep $1 | awk '{print $1":"$3}'|head -1) 
  else
    myfile=$(cscope -d -L3 $1 |grep $2 | awk '{print $1":"$3}'|head -1) 
  fi
  
  echo "Editing file ${myfile}"
  $MY_EDITOR $myfile 2>/dev/null
}

get_calle_s_iteractive(){
  #$1 root function name
  declare -a fname;
  rgx='^[0-9]+$'
  cmd=""
  local lvl=0
  a[${lvl}]=$1
  
  while true ; do
    flist=$(${GETTER} ${a[${lvl}]} "2,4-")
    farr=""
    
    clear
    echo "$GETTER for function  ${a[${lvl}]}:"
    while true ; do 
      local j=0
      
      while read -r f ; do
        farr[$j]="${f%% *}"
        printf '%-5s %-50s %-5s %s\n' "$j" ${farr[$j]} "$j" "${f#* }"
#        echo "$j: $f"
        j=$((j+1))
      done <<< "$flist"
      
      echo -ne "\nb: back\ne: edit\nx/q: exit\n\n Choose option: "
      read cmd1
      if ! test -z "$cmd1"; then
        cmd=$cmd1
      fi

      if [[ "$cmd" =~ [0-9]+ ]] && test ${cmd} -lt $j ; then
        lvl=$((lvl + 1))
        a["${lvl}"]="${farr[$cmd]}"
        break
      elif test "$cmd" == "b" ; then
        tmp=$((lvl - 1))
        if test "$tmp" -lt "0"; then
          echo -e "error: Attempting back on starting function\n"
        else
          lvl=$tmp
          break
        fi
      elif test "$cmd" == "e" ; then
        edit_file ${a["${lvl}"]} ${a[$((${lvl} - 1))]}
      elif test "$cmd" == "x" -o "$cmd" == "q" ; then
        exit
      fi
    done
  done
  
}


get_call_tree(){
  #$1 function name
  #$2 level

  print_func $1 $2
  
  local clvl=$(($2 + 1))
  
  if test $clvl -gt $MAXLVL ; then
    return
  fi
	
  callers=$(${GETTER} $1 2)
  if test -z "$callers"; then
    return
  fi
  
  i=0
  for c in $callers; do
    hmap_check_add $c
    ret=$?

    local i=$((i+1))
        
    if test $i -gt ${MAXCALLERS} ; then
      print_func "..." $clvl
      return
    fi
        
    if test $ret -eq 0; then
      get_call_tree $c $clvl 
    else
      print_func "$c <repeated>" $clvl
    fi
  done	
}

echo "" > $FILE

if test "$1" == "caller" -o "$1" == "callee" ; then
  GETTER="get_${1}s"
else
  echo "Invalid option on argument 2. Choose caller or callee"
  exit 1
fi

if test "$3" == "it"; then
 get_calle_s_iteractive $2
 exit
fi

hmap_check_add $2
MAXLVL=$3
MAXLVL=${MAXLVL:="9999999999"}
MAXCALLERS=$4
MAXCALLERS=${MAXCALLERS:="9999999999"}

get_call_tree $2 0
