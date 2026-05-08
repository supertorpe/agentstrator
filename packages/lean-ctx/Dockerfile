FROM agentstrator-core

RUN find / -xdev -type f | sort > /before-files.txt
RUN find / -xdev -type l | sort > /before-symlinks.txt

# Install lean-ctx from GitHub releases (pre-built binary)
RUN curl -fsSL https://leanctx.com/install.sh | bash -s -- --download && \
    cp /root/.local/bin/lean-ctx /usr/local/bin/lean-ctx && \
    chmod +x /usr/local/bin/lean-ctx

RUN find / -xdev -type f | sort > /after-files.txt
RUN comm -13 /before-files.txt /after-files.txt > /new-files.txt

RUN find / -xdev -type l | sort > /all-symlinks.txt
RUN comm -13 /before-symlinks.txt /all-symlinks.txt > /new-symlinks.txt
RUN while read link; do echo "$link:$(readlink "$link")"; done < /new-symlinks.txt > /new-symlinks-with-targets.txt

RUN lean-ctx --version
