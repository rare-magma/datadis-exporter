FROM docker.io/library/alpine:latest
ENV RUNNING_IN_DOCKER=true
ENTRYPOINT ["/bin/bash"]
CMD ["/app/datadis_exporter.sh"]
RUN apk add --quiet --no-cache bash coreutils curl jq