FROM ubuntu:latest

RUN apt-get update && \
    apt-get install -y \
      git curl jq bash grep \
      git-merge-changelog \
      ruby rubygems

RUN gem install git-merge-structure-sql merge_db_schema

ADD entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
