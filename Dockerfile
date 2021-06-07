FROM ubuntu:latest

RUN apt-get update && \
    apt-get install -y \
      locales \
      git curl jq bash grep \
      git-merge-changelog \
      ruby rubygems \
      && rm -rf /var/lib/apt/lists/*

RUN localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.UTF-8

RUN gem install --no-document git-merge-structure-sql merge_db_schema

ADD entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
