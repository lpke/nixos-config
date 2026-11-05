"""SSH-specific identity for the shared T3 connection tray."""

from t3_connection_tray import ConnectionTray, run
from .runtime import ASSETS


class Tray(ConnectionTray):
    def __init__(self, app):
        super().__init__(app, title="T3 SSH", program="t3-ssh", assets=ASSETS)


def main():
    run(Tray, name="t3-ssh", title="T3 SSH")


if __name__ == "__main__":
    main()
