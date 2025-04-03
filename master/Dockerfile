FROM postgres:16

# Install dependencies for building pgvector
RUN apt-get update \
    && apt-get install -y git build-essential postgresql-server-dev-16 \
    && rm -rf /var/lib/apt/lists/*

# Clone and install pgvector
RUN cd /tmp \
    && git clone --branch v0.8.0 https://github.com/pgvector/pgvector.git \
    && cd pgvector \
    && make \
    && make install \
    && cd / \
    && rm -rf /tmp/pgvector

COPY config/postgresql.conf /config/postgresql.conf
COPY config/init.sql /docker-entrypoint-initdb.d/init.sql
COPY config/pg_hba.conf /config/pg_hba.conf

# Create and copy the entrypoint script
COPY master-entrypoint.sh /usr/local/bin/master-entrypoint.sh
RUN chmod +x /usr/local/bin/master-entrypoint.sh

# Set the entrypoint to use our custom script
ENTRYPOINT ["/usr/local/bin/master-entrypoint.sh"]

CMD ["postgres", "-c", "config_file=/config/postgresql.conf"]