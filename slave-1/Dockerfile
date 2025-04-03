FROM postgres:16

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
