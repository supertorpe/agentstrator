FROM agentstrator-core

RUN find / -xdev -type f | sort > /before-files.txt
RUN find / -xdev -type l | sort > /before-symlinks.txt

RUN npm install -g agent-browser@latest

RUN apt-get update && apt-get install -y --no-install-recommends \
    libglib2.0-0  \
    libnspr4  \
    libnss3  \
    libatk1.0-0  \
    libatk-bridge2.0-0  \
    libcups2  \
    libxkbcommon0  \
    libasound2  \
    libgbm1  \
    libcairo2  \
    libpango-1.0-0  \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    && rm -rf /var/lib/apt/lists/*

RUN find / -xdev -type f | sort > /after-files.txt
RUN comm -13 /before-files.txt /after-files.txt > /new-files.txt

RUN find / -xdev -type l | sort > /all-symlinks.txt
RUN comm -13 /before-symlinks.txt /all-symlinks.txt > /new-symlinks.txt
RUN while read link; do echo "$link:$(readlink "$link")"; done < /new-symlinks.txt > /new-symlinks-with-targets.txt

RUN agent-browser --help >/dev/null 2>&1 && echo "agent-browser OK" || echo "agent-browser FAIL"
