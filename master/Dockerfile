FROM postgres:16

# Install dependencies for building pgvector and TimescaleDB
RUN apt-get update \
    && apt-get install -y git build-essential postgresql-server-dev-16 curl ca-certificates gnupg lsb-release \
    && rm -rf /var/lib/apt/lists/*

# Clone and install pgvector
RUN cd /tmp \
    && git clone --branch v0.8.0 https://github.com/pgvector/pgvector.git \
    && cd pgvector \
    && make \
    && make install \
    && cd / \
    && rm -rf /tmp/pgvector

# Install TimescaleDB
RUN curl -s https://packagecloud.io/install/repositories/timescale/timescaledb/script.deb.sh | bash \
    && apt-get update \
    && apt-get install -y timescaledb-2-postgresql-16 \
    && rm -rf /var/lib/apt/lists/*

# Install Rust and pgvectorscale
RUN apt-get update \
    && apt-get install -y curl jq pkg-config libssl-dev \
    && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    && . $HOME/.cargo/env \
    && cd /tmp \
    && git clone https://github.com/timescale/pgvectorscale \
    && cd pgvectorscale/pgvectorscale \
    && export PATH="$HOME/.cargo/bin:$PATH" \
    && cargo install --locked cargo-pgrx --version $(cargo metadata --format-version 1 | jq -r '.packages[] | select(.name == "pgrx") | .version') \
    && cargo pgrx init --pg16 pg_config \
    && cargo pgrx install --release \
    && cd / \
    && rm -rf /tmp/pgvectorscale \
    && apt-get remove -y jq \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

COPY config/postgresql.conf /config/postgresql.conf
COPY config/init.sql /docker-entrypoint-initdb.d/init.sql
COPY config/pg_hba.conf /config/pg_hba.conf

# Create and copy the entrypoint script
COPY master-entrypoint.sh /usr/local/bin/master-entrypoint.sh
RUN chmod +x /usr/local/bin/master-entrypoint.sh

# Set the entrypoint to use our custom script
ENTRYPOINT ["/usr/local/bin/master-entrypoint.sh"]

CMD ["postgres", "-c", "config_file=/config/postgresql.conf"]