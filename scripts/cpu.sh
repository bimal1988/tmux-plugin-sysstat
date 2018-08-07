#!/usr/bin/env bash

set -u
set -e

LC_NUMERIC=C

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$CURRENT_DIR/helpers.sh"

cpu_tmp_dir=$(tmux show-option -gqv "@sysstat_cpu_tmp_dir")

cpu_view_tmpl=$(get_tmux_option "@sysstat_cpu_view_tmpl" 'CPU:#[fg=#{cpu.color}]#{cpu.pused}#[default]')

cpu_medium_threshold=$(get_tmux_option "@sysstat_cpu_medium_threshold" "30")
cpu_stress_threshold=$(get_tmux_option "@sysstat_cpu_stress_threshold" "80")

cpu_color_low=$(get_tmux_option "@sysstat_cpu_color_low" "green")
cpu_color_medium=$(get_tmux_option "@sysstat_cpu_color_medium" "yellow")
cpu_color_stress=$(get_tmux_option "@sysstat_cpu_color_stress" "red")

get_cpu_color(){
  local cpu_used=$1

  if fcomp "$cpu_stress_threshold" "$cpu_used"; then
    echo "$cpu_color_stress";
  elif fcomp "$cpu_medium_threshold" "$cpu_used"; then
    echo "$cpu_color_medium";
  else
    echo "$cpu_color_low";
  fi
}

print_cpu_usage() {
  local cpu_pused=$(get_cpu_usage_or_collect)
  local cpu_color=$(get_cpu_color "$cpu_pused")
  
  local cpu_view="$cpu_view_tmpl"
  cpu_view="${cpu_view//'#{cpu.pused}'/$(printf "%.1f%%" "$cpu_pused")}"
  cpu_view="${cpu_view//'#{cpu.color}'/$(echo "$cpu_color" | awk '{ print $1 }')}"
  cpu_view="${cpu_view//'#{cpu.color2}'/$(echo "$cpu_color" | awk '{ print $2 }')}"
  cpu_view="${cpu_view//'#{cpu.color3}'/$(echo "$cpu_color" | awk '{ print $3 }')}"

  echo "$cpu_view"
}

get_cpu_usage() {
  local sysstat_cpu_started=$(get_tmux_option "@sysstat_cpu_started" "0")
  
  if [ $sysstat_cpu_started -eq 0 ]; then
    set_tmux_option "@sysstat_cpu_started" "1"
    echo "0"
  elif command_exists "iostat"; then
 		if is_linux_iostat; then
 			iostat -c 1 2 | sed '/^\s*$/d' | tail -n 1 | awk '{usage=100-$NF} END {printf("%5.1f", usage)}' | sed 's/,/./'
 		elif is_osx; then
 			iostat -c 2 disk0 | sed '/^\s*$/d' | tail -n 1 | awk '{usage=100-$6} END {printf("%5.1f", usage)}' | sed 's/,/./'
 		elif is_freebsd || is_openbsd; then
 			iostat -c 2 | sed '/^\s*$/d' | tail -n 1 | awk '{usage=100-$NF} END {printf("%5.1f", usage)}' | sed 's/,/./'
 		else
 			echo "Unknown iostat version please create an issue"
 		fi
 	elif command_exists "sar"; then
 		sar -u 1 1 | sed '/^\s*$/d' | tail -n 1 | awk '{usage=100-$NF} END {printf("%5.1f", usage)}' | sed 's/,/./'
 	else
 		if is_cygwin; then
 			usage="$(WMIC cpu get LoadPercentage | grep -Eo '^[0-9]+')"
 			printf "%5.1f" $usage
 		else
 			load=`ps -aux | awk '{print $3}' | tail -n+2 | awk '{s+=$1} END {print s}'`
 			cpus=$(cpus_number)
 			echo "$load $cpus" | awk '{printf "%5.2f", $1/$2}'
 		fi
  fi
}

main(){
  print_cpu_usage
}

main
