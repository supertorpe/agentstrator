FROM agentstrator-core

RUN find / -xdev -type f | sort > /before-files.txt
RUN find / -xdev -type l | sort > /before-symlinks.txt

RUN LEANKG_VERSION="$(curl --retry 10 \
    --retry-delay 5 \
    --retry-all-errors \
    --connect-timeout 10 \
    --max-time 60 \
    -fsSL https://api.github.com/repos/FreePeak/LeanKG/releases/latest \
    | jq -r '.tag_name | ltrimstr("v")')" && \
    curl --retry 10 \
         --retry-delay 5 \
         --retry-all-errors \
         --connect-timeout 10 \
         --max-time 120 \
         -fsSL "https://github.com/FreePeak/LeanKG/releases/download/v${LEANKG_VERSION}/leankg-linux-x64.tar.gz" \
    | tar xz -C /usr/local/bin leankg && \
    chmod +x /usr/local/bin/leankg

RUN find / -xdev -type f | sort > /after-files.txt
RUN comm -13 /before-files.txt /after-files.txt > /new-files.txt

RUN find / -xdev -type l | sort > /all-symlinks.txt
RUN comm -13 /before-symlinks.txt /all-symlinks.txt > /new-symlinks.txt
RUN while read link; do echo "$link:$(readlink "$link")"; done < /new-symlinks.txt > /new-symlinks-with-targets.txt

RUN leankg --version >/dev/null 2>&1 && echo "leankg OK" || echo "leankg FAIL"