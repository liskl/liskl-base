FROM docker:stable

LABEL "name"="Docker tag and push action"
LABEL "maintainer"="Loren Lisk <loren.lisk@liskl.com>"
LABEL "version"="0.0.1"

LABEL "com.github.actions.icon"="package"
LABEL "com.github.actions.color"="green"
LABEL "com.github.actions.name"="Docker Build"
LABEL "com.github.actions.description"="This is an Action to run docker commands."

RUN apk add --no-cache ca-certificates bash git curl \
  && rm -rf /var/cache/apk/*

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
