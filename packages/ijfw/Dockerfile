FROM agentstrator-core

# File tracking (before)
RUN find / -xdev -type f | sort > /before-files.txt
RUN find / -xdev -type l | sort > /before-symlinks.txt

# Install IJFW
RUN apt update && apt install -y shellcheck
RUN IJFW_VERSION="$(curl --retry 10 \
    --retry-delay 5 \
    --retry-all-errors \
    --connect-timeout 10 \
    --max-time 60 \
    -fsSL https://api.github.com/repos/gitleaks/gitleaks/releases/latest \
    | jq -r '.tag_name | ltrimstr("v")')" && \
    curl --retry 10 \
         --retry-delay 5 \
         --retry-all-errors \
         --connect-timeout 10 \
         --max-time 120 \
         -fsSL "https://github.com/gitleaks/gitleaks/releases/download/v${IJFW_VERSION}/gitleaks_${IJFW_VERSION}_linux_x64.tar.gz" \
    | tar xz -C /usr/local/bin gitleaks && \
    chmod +x /usr/local/bin/gitleaks
RUN npm install -g @ijfw/install@latest

# File tracking (after)
RUN find / -xdev -type f | sort > /after-files.txt
RUN comm -13 /before-files.txt /after-files.txt > /new-files.txt

RUN find / -xdev -type l | sort > /all-symlinks.txt
RUN comm -13 /before-symlinks.txt /all-symlinks.txt > /new-symlinks.txt
RUN while read link; do echo "$link:$(readlink "$link")"; done < /new-symlinks.txt > /new-symlinks-with-targets.txt

# Verify install
RUN ijfw --help >/dev/null 2>&1 && echo "IJFW OK" || echo "IJFW FAIL"