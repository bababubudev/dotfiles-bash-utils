#!/bin/bash

echo "Setting custom bash utilities"

UTILS_DIR="$HOME/.local/bin"
mkdir -p "$UTILS_DIR"

if ! echo "$PATH" | grep -q "$UTILS_DIR"; then
	echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> ~/.bashrc
fi

cat << 'EOF' > ~/.bash_functions

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

cat << 'EOF' > "$UTILS_DIR/table"
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

cat << 'EOF' > "$UTILS_DIR/lookport"
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

cat << 'EOF' > "$UTILS_DIR/killport"
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

chmod +x "$UTILS_DIR/table"
chmod +x "$UTILS_DIR/lookport"
chmod +x "$UTILS_DIR/killport"

echo "" >> ~/.bashrc
echo "# CUSTOM UTILITIES" >> ~/.bashrc
echo "source ~/.bash_functions" >> ~/.bashrc
echo "" >> ~/.bashrc
echo "# Custom aliases" >> ~/.bashrc
echo "alias ll='ls -la'" >> ~/.bashrc

echo "Installing required packages..."
sudo apt update
sudo apt install -y net-tools lsof

echo ""
echo "Setup complete! Run 'source ~/.bashrc' or restart your terminal."
echo ""
echo "Available commands"
echo "  ll                  - Alias for 'ls -la' (detailed list)"
echo "  cdup <dir_name>     - Navigate up to find directory"
echo "  cddown <dir_name>   - Navigate down to find directory"
echo "  table <csv_file>    - Display CSV in table format"
echo "  lookport <port>     - Show processes on port"
echo "  killport <port>     - Kill processes on port"
