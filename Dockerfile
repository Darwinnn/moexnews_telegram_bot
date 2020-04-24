FROM crystallang/crystal:0.34.0
COPY . /src
WORKDIR ./src
RUN shards build --production --release --verbose -s -p -t
CMD bin/moex_publications_bot

