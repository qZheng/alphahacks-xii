from flask import Blueprint, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from extensions import db
from models import User

user_bp = Blueprint("user", __name__, url_prefix="/api")

@user_bp.get("/me")
@jwt_required()
def me():
    user_id = int(get_jwt_identity())
    user = db.session.get(User, user_id)
    if user is None:
        return jsonify(error="User not found"), 404
    return jsonify(id=user.id, username=user.username)
