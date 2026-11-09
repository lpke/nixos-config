# Legacy Hyper+D/CLI entrypoint. The controller serializes all requests and owns
# every overlay; there is no separate marker, PID, service or brightness state.
exec monitor-control toggle "$@"
