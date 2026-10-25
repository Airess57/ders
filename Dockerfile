# Stage 1: Compile the C application (GCC is only needed during build).
FROM gcc:14.2 AS builder
WORKDIR /app
COPY monitor.c ./
RUN gcc -std=c11 -Wall -Wextra -Werror -O2 monitor.c -o monitor

# Stage 2: Run the C executable and the small Python web server.
# GCC and the C source are not copied into this final image.
FROM python:3.15-slim
WORKDIR /app
COPY --from=builder /app/monitor ./monitor
COPY server.py index.html ./

# Use an unprivileged account, matching Kubernetes runAsUser: 65534.
USER 65534:65534

# The web server listens on 8000 in Deployment mode.
# Job and CronJob override CMD to run /app/monitor instead.
EXPOSE 8000
CMD ["python3", "server.py"]
