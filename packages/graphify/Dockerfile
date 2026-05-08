FROM agentstrator-core

RUN find / -xdev -type f | sort > /before-files.txt
RUN find / -xdev -type l | sort > /before-symlinks.txt

RUN pip3 install --break-system-packages "graphifyy[mcp]"

RUN find / -xdev -type f | sort > /after-files.txt
RUN comm -13 /before-files.txt /after-files.txt > /new-files.txt

RUN find / -xdev -type l | sort > /all-symlinks.txt
RUN comm -13 /before-symlinks.txt /all-symlinks.txt > /new-symlinks.txt
RUN while read link; do echo "$link:$(readlink "$link")"; done < /new-symlinks.txt > /new-symlinks-with-targets.txt

RUN python3 -m graphify --help >/dev/null 2>&1 && echo "graphify CLI OK" || echo "graphify CLI: FAIL"
RUN python3 -c "import graphify.serve; print('MCP server module OK')" 2>&1