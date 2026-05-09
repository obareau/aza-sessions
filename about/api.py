from flask import Blueprint, render_template, current_app
from core.oblique import rand_oblique as _rand_oblique

bp = Blueprint("about", __name__)


@bp.route("/about")
def about():
    db_path = current_app.config["DB_PATH"]
    version = current_app.config.get("VERSION", "")
    return render_template("about.html", version=version,
                           oblique=_rand_oblique(db_path))
