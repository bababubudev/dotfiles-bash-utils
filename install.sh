#!/bin/bash

echo "Setting custom bash utilities"

UTILS_DIR="$HOME/.local/bin"
mkdir -p "$UTILS_DIR"

if ! echo "$PATH" | grep -q "$UTILS_DIR"; then
	echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >>~/.bashrc
fi

cat <<'EOF' >~/.bash_functions

cdup() {
	if [ $# -eq 0 ]; then
		echo "Usage: cdup <directory>"
		echo "Navigate up the directory tree for a given directory"
		return 1
	fi

	local target="$1"
	local current_dir="$(pwd)"
	local search_dir="$current_dir"

	while [ "$search_dir" != "/" ]; do
		if [ "$(basename "$search_dir")" = "$target" ]; then
			cd "$search_dir"
			return 0;
		fi
		search_dir="$(dirname "$search_dir")"
	done

	echo "Directory '$target' not found in parent hierarchy"
	return 1
}


cddown() {
	if [ $# -eq 0 ]; then
        	echo "Usage: cddown <directory>"
        	echo "Navigate down the directory tree for a given directory"
        	return 1
    	fi

	local target="$1"
	local found_dir

	found_dir=$(find . -type d -name "$target" -print -quit 2>/dev/null)

	if [ -n "$found_dir" ]; then
		cd "$found_dir"
		return 0
	else
		echo "Directory '$target' not found in subdirectories"
		return 1
	fi
}
EOF

cat <<'EOF' >"$UTILS_DIR/table"
#!/bin/bash

# For displaying CSV in tabular format
table() {
	if [ $# -eq 0 ]; then
		echo "Usage: table <csv_file> [delimiter]"
		echo "Display CSV file in a neat tabular format"
        	echo "Default delimiter is comma (,)"
        	return 1
	fi

	local file="$1"
	local delimiter="${2:-,}"

	if [ ! -f "$file" ]; then
		echo "Error: File '$file' not found"
		return 1;
	fi

	# If column command is available
	if command -v column >/dev/null 2>&1; then
		if [ "$delimiter" = "," ]; then
			column -t -s ',' "$file"
		else
			column -t -s "$delimiter" "$file"
		fi

	else
		# Awk based table formatter
		awk -F"$delimiter" '
		{
			# Store rows
			for(i=1; i<=NF; i++) {
				row[NR,i] = $i
				if(length($i) > width[i]) width[i] = length($i)
			}

			cols = (NF > cols) ? NF : cols
			rows = NR
		}
		END {
			# Print formatted table
			for(r=1; r<=rows; r++) {
				for(c=1; c<=cols; c++) {
					printf "%-*s ", width[c], row[r,c]
				}
				print ""
			}
		}' "$file"
	fi
}

# If called directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
	table "$@"
fi
EOF

cat <<'EOF' >"$UTILS_DIR/lookport"
#!/bin/bash

lookport() {
	if [ $# -eq 0 ]; then
        	echo "Usage: lookport <port_number>"
        	echo "Show processes running on the specified port"
        	return 1
    	fi

    	local port="$1"

	# Validate port number
    	if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        	echo "Error: Invalid port number. Please provide a number between 1-65535"
        	return 1
    	fi

    	echo "Checking port $port..."
    	echo "===================="

    	# Check with netstat
    	if command -v netstat >/dev/null 2>&1; then
        	echo "Netstat results:"
        	netstat -tulpn 2>/dev/null | grep ":$port " || echo "No processes found with netstat"
        	echo ""
    	fi

	# Check with ss
    	if command -v ss >/dev/null 2>&1; then
        	echo "ss results:"
        	ss -tulpn | grep ":$port " || echo "No processes found with ss"
        	echo ""
    	fi

	# Check with lsof if available
    	if command -v lsof >/dev/null 2>&1; then
        	echo "lsof results:"
        	lsof -i ":$port" 2>/dev/null || echo "No processes found with lsof"
    	fi

	# If no tools found processes, check if port is in use differently
    	if ! netstat -tulpn 2>/dev/null | grep -q ":$port " && \
       	! ss -tulpn 2>/dev/null | grep -q ":$port " && \
       	! lsof -i ":$port" >/dev/null 2>&1; then
        	echo "Port $port appears to be free"
    	fi
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    lookport "$@"
fi
EOF

cat <<'EOF' >"$UTILS_DIR/killport"
#!/bin/bash

killport() {
    	if [ $# -eq 0 ]; then
        	echo "Usage: killport <port_number>"
        	echo "Kill processes running on the specified port"
        	return 1
    	fi

	local port="$1"

    	# Validate port number
    	if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        	echo "Error: Invalid port number. Please provide a number between 1-65535"
        	return 1
    	fi

    	echo "Looking for processes on port $port..."

    	# Find PIDs using the port
    	local pids=""

    	# lsof first
    	if command -v lsof >/dev/null 2>&1; then
        	pids=$(lsof -t -i ":$port" 2>/dev/null)
    	fi

    	# If lsof didn't work, netstat
    	if [ -z "$pids" ] && command -v netstat >/dev/null 2>&1; then
        	pids=$(netstat -tulpn 2>/dev/null | grep ":$port " | awk '{print $7}' | cut -d'/' -f1 | grep -E '^[0-9]+$')
    	fi

    	# If still no PIDs, ss
    	if [ -z "$pids" ] && command -v ss >/dev/null 2>&1; then
        	pids=$(ss -tulpn | grep ":$port " | grep -oE 'pid=[0-9]+' | cut -d'=' -f2)
    	fi

    	if [ -z "$pids" ]; then
        	echo "No processes found running on port $port"
        	return 1
    	fi

    	echo "Found processes with PIDs: $pids"

   	# Ask for confirmation
    	read -p "Kill these processes? (y/N): " -n 1 -r
    	echo

    	if [[ $REPLY =~ ^[Yy]$ ]]; then
        	for pid in $pids; do
            		if kill -0 "$pid" 2>/dev/null; then
                		echo "Killing process $pid..."
                		if kill "$pid" 2>/dev/null; then
                    			echo "Successfully killed process $pid"
                		else
                    			echo "Failed to kill process $pid, trying with SIGKILL..."
                    			kill -9 "$pid" 2>/dev/null && echo "Force killed process $pid" || echo "Failed to force kill process $pid"
                		fi
            		else
                		echo "Process $pid is no longer running"
            		fi
        	done
    	else
        	echo "Operation cancelled"
    	fi
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    killport "$@"
fi
EOF

cat <<'EOF' >"$UTILS_DIR/tzone"
#!/bin/bash

show_help() {
  echo "Usage:"
  echo "  tzone <time> <from_tz>                 Convert to local timezone"
  echo "  tzone --to <time> <from_tz> <to_tz>    Convert time from one timezone to another"
  echo "  tzone --to <time> <from_tz>            Convert time from given timezone to local time"
  echo "  tzone --to <to_tz>                     Convert current local time to another timezone"
  echo ""
  echo "Time formats: HH:MM or YYYY-MM-DD HH:MM"
  echo "Timezone examples: UTC, PST, EST, EEST, Europe/Helsinki, America/New_York"
}


normalize_timezone() {
  local tz="$1"
  case "$tz" in
    # US Timezones
    "PST") echo "America/Los_Angeles" ;;
    "PDT") echo "America/Los_Angeles" ;;
    "MST") echo "America/Denver" ;;
    "MDT") echo "America/Denver" ;;
    "CST") echo "America/Chicago" ;;
    "CDT") echo "America/Chicago" ;;
    "EST") echo "America/New_York" ;;
    "EDT") echo "America/New_York" ;;
    "AKST") echo "America/Anchorage" ;;
    "AKDT") echo "America/Anchorage" ;;
    "HST") echo "Pacific/Honolulu" ;;

    # European Timezones
    "GMT") echo "Europe/London" ;;
    "BST") echo "Europe/London" ;;
    "CET") echo "Europe/Berlin" ;;
    "CEST") echo "Europe/Berlin" ;;
    "EET") echo "Europe/Helsinki" ;;
    "EEST") echo "Europe/Helsinki" ;;
    "WET") echo "Europe/Lisbon" ;;
    "WEST") echo "Europe/Lisbon" ;;
    "MSK") echo "Europe/Moscow" ;;

    # Asian Timezones
    "JST") echo "Asia/Tokyo" ;;
    "KST") echo "Asia/Seoul" ;;
    "CCST") echo "Asia/Shanghai" ;; # !!Conflicted with US CST
    "IST") echo "Asia/Kolkata" ;;
    "SGT") echo "Asia/Singapore" ;;
    "HKT") echo "Asia/Hong_Kong" ;;
    "PHT") echo "Asia/Manila" ;;
    "WIB") echo "Asia/Jakarta" ;;
    "ICT") echo "Asia/Bangkok" ;;

    # Australian Timezones
    "AEST") echo "Australia/Sydney" ;;
    "AEDT") echo "Australia/Sydney" ;;
    "AWST") echo "Australia/Perth" ;;
    "ACST") echo "Australia/Adelaide" ;;
    "ACDT") echo "Australia/Adelaide" ;;

    # Other Common Timezones
    "UTC") echo "UTC" ;;
    "NZST") echo "Pacific/Auckland" ;;
    "NZDT") echo "Pacific/Auckland" ;;
    "CAT") echo "Africa/Johannesburg" ;;
    "WAT") echo "Africa/Lagos" ;;
    "EAT") echo "Africa/Nairobi" ;;
    "BRT") echo "America/Sao_Paulo" ;;
    "ART") echo "America/Argentina/Buenos_Aires" ;;
    "CLT") echo "America/Santiago" ;;
    "PET") echo "America/Lima" ;;

    # Middle East
    "GST") echo "Asia/Dubai" ;;
    "AST") echo "Asia/Riyadh" ;;

    *) echo "$tz" ;;
  esac
}

get_current_date() {
  date "+%Y-%m-%d"
}

parse_time_with_date() {
  local time="$1"

  if [[ "$time" =~ ^[0-9]{1,2}:[0-9]{2}$ ]]; then
    # Just time given, add today's date
    echo "$(get_current_date) $time:00"
  elif [[ "$time" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]]+[0-9]{1,2}:[0-9]{2}$ ]]; then
    # Full date-time given
    echo "$time:00"
  else
    echo "$time"
  fi
}


convert_to_local() {
  local time="$1"
  local from_tz="$2"

	local normalized_from=$(normalize_timezone "$from_tz")
  local full_time=$(parse_time_with_date "$time")

	local epoch_time
  if ! epoch_time=$(TZ="$normalized_from" date -d "$full_time" "+%s" 2>/dev/null); then
    echo "Error: Invalid time format or timezone '$from_tz'"
    return 1
  fi

	local result
  if ! result=$(date -d "@$epoch_time" "+%Y-%m-%d %H:%M (%Z)" 2>/dev/null); then
    echo "Error: Failed to convert to local time"
    return 1
  fi

  echo "$time $from_tz is $result in your local time"
}

convert_from_to() {
  local time="$1"
  local from_tz="$2"
  local to_tz="$3"

	local normalized_from=$(normalize_timezone "$from_tz")
  local normalized_to=$(normalize_timezone "$to_tz")

	local full_time=$(parse_time_with_date "$time")

	local epoch_time
  if ! epoch_time=$(TZ="$normalized_from" date -d "$full_time" "+%s" 2>/dev/null); then
    echo "Error: Invalid time format or source timezone '$from_tz'"
    return 1
  fi

  local result
  if ! result=$(TZ="$normalized_to" date -d "@$epoch_time" "+%Y-%m-%d %H:%M (%Z)" 2>/dev/null); then
    echo "Error: Invalid target timezone '$to_tz'"
    return 1
  fi

	echo "$time $from_tz is $result"
}

convert_now_to_target() {
   local to_tz="$1"
  local normalized_to=$(normalize_timezone "$to_tz")

  local now_epoch=$(date "+%s")

  local result
  if ! result=$(TZ="$normalized_to" date -d "@$now_epoch" "+%Y-%m-%d %H:%M (%Z)" 2>/dev/null); then
    echo "Error: Invalid target timezone '$to_tz'"
    return 1
  fi

  local local_time=$(date "+%Y-%m-%d %H:%M (%Z)")
  echo "Local time $local_time is $result"
}

if [[ "$1" == "--to" ]]; then
  if [[ $# -eq 4 ]]; then
    convert_from_to "$2" "$3" "$4"
  elif [[ $# -eq 3 ]]; then
    convert_to_local "$2" "$3"
  elif [[ $# -eq 2 ]]; then
    convert_now_to_target "$2"
  else
    show_help
    exit 1
  fi
elif [[ $# -eq 2 ]]; then
  convert_to_local "$1" "$2"
elif [[ $# -eq 0 ]]; then
  show_help
  exit 1
else
  echo "Error: Invalid number of arguments"
  show_help
  exit 1
fi
EOF

chmod +x "$UTILS_DIR/table"
chmod +x "$UTILS_DIR/lookport"
chmod +x "$UTILS_DIR/killport"
chmod +x "$UTILS_DIR/tzone"

if ! grep -q 'source ~/.bash_functions' ~/.bashrc; then
	echo "" >>~/.bashrc
	echo "# CUSTOM UTILITIES" >>~/.bashrc
	echo "source ~/.bash_functions" >>~/.bashrc
fi

echo "Installing required packages..."
sudo apt update
sudo apt install -y net-tools lsof

echo ""
echo "Setup complete! Run 'source ~/.bashrc' or restart your terminal."
echo ""
echo "Available commands"
echo "  ll                          - Alias for 'ls -la' (detailed list)"
echo "  cdup <dir_name>             - Navigate up to find directory"
echo "  cddown <dir_name>           - Navigate down to find directory"
echo "  table <csv_file>            - Display CSV in table format"
echo "  lookport <port>             - Show processes on port"
echo "  killport <port>             - Kill processes on port"
echo "  tzone <time> <timezone>     - Timezone conversion"
