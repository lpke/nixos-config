"""Qt local server: serialized requests, bounded framing and idle clients."""

import json

from PyQt6.QtCore import QObject, QTimer
from PyQt6.QtNetwork import QLocalServer


class Server(QObject):
    def __init__(self, path, dispatch):
        super().__init__()
        self.dispatch = dispatch
        self.clients = {}
        self.server = QLocalServer(self)
        self.server.setSocketOptions(QLocalServer.SocketOption.UserAccessOption)
        QLocalServer.removeServer(str(path))
        if not self.server.listen(str(path)):
            raise RuntimeError(self.server.errorString())
        self.server.newConnection.connect(self.accept)

    def accept(self):
        while self.server.hasPendingConnections():
            client = self.server.nextPendingConnection()
            if len(self.clients) >= 32:
                client.abort()
                client.deleteLater()
                continue
            self.clients[client] = b""
            client.readyRead.connect(lambda client=client: self.read(client))
            client.disconnected.connect(lambda client=client: self.remove(client))
            timer = QTimer(client)
            timer.setSingleShot(True)
            timer.timeout.connect(client.abort)
            timer.start(2000)

    def remove(self, client):
        self.clients.pop(client, None)
        client.deleteLater()

    def read(self, client):
        data = self.clients.get(client, b"") + bytes(client.readAll())
        self.clients[client] = data
        if len(data) > 16384:
            client.abort()
            return
        if b"\n" not in data:
            return
        try:
            message = json.loads(data.split(b"\n", 1)[0])
            if not isinstance(message, dict) or not isinstance(message.get("command"), str):
                raise ValueError("Expected a command")
            target = message.get("target")
            if target is not None and not isinstance(target, str):
                raise ValueError("Invalid monitor target")
            result = self.dispatch(message["command"], target)
        except (ValueError, OSError) as error:
            result = {"ok": False, "error": str(error)}
        client.write(json.dumps(result).encode() + b"\n")
        client.flush()
        client.disconnectFromServer()

    def close(self):
        self.server.close()
        for client in list(self.clients):
            client.abort()
