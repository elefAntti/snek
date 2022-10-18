FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y \
    build-essential nasm
ENV TERM xterm-256color
COPY . .
RUN make snek
# CMD ["bash", "-i"]
CMD ["./snek"]
