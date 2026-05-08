FROM agentstrator-core

RUN find / -xdev -type f | sort > /before-files.txt
RUN find / -xdev -type l | sort > /before-symlinks.txt

RUN curl -fsSL https://raw.githubusercontent.com/Gentleman-Programming/gentle-ai/main/scripts/install.sh | bash

RUN find / -xdev -type f | sort > /after-files.txt
RUN comm -13 /before-files.txt /after-files.txt > /new-files.txt

RUN find / -xdev -type l | sort > /all-symlinks.txt
RUN comm -13 /before-symlinks.txt /all-symlinks.txt > /new-symlinks.txt
RUN while read link; do echo "$link:$(readlink "$link")"; done < /new-symlinks.txt > /new-symlinks-with-targets.txt

RUN gentle-ai version >/dev/null 2>&1 && echo "gentle-ai OK" || echo "gentle-ai FAIL"