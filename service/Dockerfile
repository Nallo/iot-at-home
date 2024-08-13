FROM swift:5.10

ADD DataSyncService /tmp/src/DataSyncService

ADD Miele /tmp/src/Miele

WORKDIR /tmp/src/DataSyncService

RUN swift build --configuration release

# ENTRYPOINT ["ls", "-R"]
ENTRYPOINT [".build/release/DataSyncService"]
