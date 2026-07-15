FROM docker.io/oven/bun:1-debian

# server-service.cjs is resolved at runtime from the read-only plugin mount
# (/plugin-cache), so the image only needs bun. Memory + observations persist
# on the /data volume (SQLite).
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
