from flask_login import UserMixin

from db import get_db


class User(UserMixin):
    def __init__(self, id, username, email, password_hash, is_admin):
        self.id = id
        self.username = username
        self.email = email
        self.password_hash = password_hash
        self.is_admin = bool(is_admin)

    def get_id(self):
        return str(self.id)

    @staticmethod
    def get(user_id):
        conn = get_db()
        row = conn.execute("SELECT * FROM users WHERE id=?", (user_id,)).fetchone()
        conn.close()
        if row:
            return User(row["id"], row["username"], row["email"],
                        row["password_hash"], row["is_admin"])
        return None

    @staticmethod
    def get_by_username(username):
        conn = get_db()
        row = conn.execute("SELECT * FROM users WHERE username=?", (username,)).fetchone()
        conn.close()
        if row:
            return User(row["id"], row["username"], row["email"],
                        row["password_hash"], row["is_admin"])
        return None
