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

# Install gosu for running PostgreSQL as non-root
# (gosu should already be included in the official postgres image)

# Copy the entrypoint script
COPY slave-entrypoint.sh /usr/local/bin/slave-entrypoint.sh

# Make the entrypoint script executable
RUN chmod +x /usr/local/bin/slave-entrypoint.sh

# Set the entrypoint to run the script
ENTRYPOINT ["/usr/local/bin/slave-entrypoint.sh"]
