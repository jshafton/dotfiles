[ -z "$SSH_AUTH_SOCK" ] && [ -S "$XDG_RUNTIME_DIR/ssh-agent.socket" ] && export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket" || true
