from flask import Blueprint, request, jsonify
from flask_jwt_extended import create_access_token
from sqlalchemy import select
from extensions import db
from models import User

auth_bp = Blueprint("auth", __name__, url_prefix="/api/auth")

@auth_bp.post("/register")
def register():
    data = request.get_json() or {}
    username = (data.get("username") or "").strip()
    password = data.get("password") or ""

    if not username or not password:
        return jsonify(error="Missing fields"), 400

    if db.session.scalar(select(User).where(User.username == username)) is not None:
        return jsonify(error="Username taken"), 409
    
    u = User(username=username)
    u.set_password(password)
    db.session.add(u)
    db.session.commit()
    return jsonify(ok=True), 201

@auth_bp.post("/login")
def login():
    data = request.get_json() or {}
    username = (data.get("username") or "").strip()
    password = data.get("password") or ""

    user = db.session.scalar(select(User).where(User.username == username))
    if user is None or not user.check_password(password):
        return jsonify(error="Invalid credentials"), 401

    token = create_access_token(identity=str(user.id))
    return jsonify(access_token=token)
