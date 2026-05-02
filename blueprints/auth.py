from flask import Blueprint, flash, redirect, render_template, request, url_for
from flask_login import current_user, login_required, login_user, logout_user
from werkzeug.security import check_password_hash, generate_password_hash

from db import get_db
from models import User

bp = Blueprint("auth", __name__)


@bp.route("/login", methods=["GET", "POST"])
def login():
    if current_user.is_authenticated:
        return redirect(url_for("sessions.index"))

    if request.method == "POST":
        username = request.form.get("username", "").strip()
        password = request.form.get("password", "")
        user = User.get_by_username(username)
        if user and check_password_hash(user.password_hash, password):
            login_user(user, remember=bool(request.form.get("remember")))
            next_page = request.args.get("next")
            return redirect(next_page or url_for("sessions.index"))
        flash("Identifiant ou mot de passe incorrect.", "error")

    return render_template("login.html")


@bp.route("/logout")
@login_required
def logout():
    logout_user()
    return redirect(url_for("auth.login"))


@bp.route("/setup", methods=["GET", "POST"])
def setup():
    """Création du premier compte admin — accessible uniquement si aucun user n'existe."""
    conn = get_db()
    count = conn.execute("SELECT COUNT(*) FROM users").fetchone()[0]
    conn.close()
    if count > 0:
        return redirect(url_for("auth.login"))

    if request.method == "POST":
        username = request.form.get("username", "").strip()
        email    = request.form.get("email", "").strip()
        password = request.form.get("password", "")
        confirm  = request.form.get("confirm", "")

        error = None
        if not username:
            error = "Nom d'utilisateur requis."
        elif not email:
            error = "Email requis."
        elif len(password) < 8:
            error = "Mot de passe trop court (8 caractères minimum)."
        elif password != confirm:
            error = "Les mots de passe ne correspondent pas."

        if error:
            flash(error, "error")
        else:
            conn = get_db()
            conn.execute(
                "INSERT INTO users (username, email, password_hash, is_admin) VALUES (?,?,?,1)",
                (username, email, generate_password_hash(password))
            )
            conn.commit()
            conn.close()
            flash(f"Compte admin « {username} » créé. Bienvenue.", "success")
            user = User.get_by_username(username)
            login_user(user)
            return redirect(url_for("sessions.index"))

    return render_template("setup.html")
