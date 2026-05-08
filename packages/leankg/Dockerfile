FROM agentstrator-core

RUN find / -xdev -type f | sort > /before-files.txt
RUN find / -xdev -type l | sort > /before-symlinks.txt

RUN LEANKG_VERSION=$(curl -fsSL https://api.github.com/repos/FreePeak/LeanKG/releases/latest | python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'].lstrip('v'))") && \
    curl -fsSL "https://github.com/FreePeak/LeanKG/releases/download/v${LEANKG_VERSION}/leankg-linux-x64.tar.gz" | \
    tar xz -C /usr/local/bin leankg && \
    chmod +x /usr/local/bin/leankg

RUN find / -xdev -type f | sort > /after-files.txt
RUN comm -13 /before-files.txt /after-files.txt > /new-files.txt

RUN find / -xdev -type l | sort > /all-symlinks.txt
RUN comm -13 /before-symlinks.txt /all-symlinks.txt > /new-symlinks.txt
RUN while read link; do echo "$link:$(readlink "$link")"; done < /new-symlinks.txt > /new-symlinks-with-targets.txt

RUN leankg --version >/dev/null 2>&1 && echo "leankg OK" || echo "leankg FAIL"