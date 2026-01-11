# app/routes/groups_routes.py

from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity

from extensions import db
from models import User, Group  # adjust import path if needed

groups_bp = Blueprint("groups", __name__, url_prefix="/api/groups")


def get_current_user():
    """
    Gets the current user from the JWT identity.
    Assumes identity stored in JWT is the user's integer id.
    """
    user_id = get_jwt_identity()
    if user_id is None:
        return None
    return db.session.get(User, int(user_id))


@groups_bp.post("")
@jwt_required()
def create_group():
    """
    POST /api/groups
    Body: { "name": "Team 4" }
    """
    user = get_current_user()
    if user is None:
        return jsonify({"error": "Unauthorized"}), 401

    data = request.get_json(silent=True) or {}
    name = (data.get("name") or "").strip()

    if not name:
        return jsonify({"error": "Group name is required"}), 400

    # Optional: enforce unique group names
    existing = db.session.scalar(db.select(Group).where(Group.name == name))
    if existing is not None:
        return jsonify({"error": "Group name already exists"}), 400

    group = Group(name=name)
    db.session.add(group)

    # creator automatically joins
    group.members.append(user)

    db.session.commit()
    return jsonify({"id": group.id, "name": group.name}), 201


@groups_bp.get("")
@jwt_required()
def list_my_groups():
    """
    GET /api/groups
    Returns groups that the current user belongs to.
    """
    user = get_current_user()
    if user is None:
        return jsonify({"error": "Unauthorized"}), 401

    # If you used lazy="dynamic", do user.groups.all()
    groups = user.groups
    return jsonify([
        {"id": g.id, "name": g.name}
        for g in groups
    ]), 200


@groups_bp.get("/<int:group_id>")
@jwt_required()
def get_group(group_id):
    """
    GET /api/groups/<group_id>
    Basic group info + members (only if requester is a member).
    """
    user = get_current_user()
    if user is None:
        return jsonify({"error": "Unauthorized"}), 401

    group = db.session.get(Group, group_id)
    if group is None:
        return jsonify({"error": "Group not found"}), 404

    if user not in group.members:
        return jsonify({"error": "Forbidden (not a member)"}), 403

    return jsonify({
        "id": group.id,
        "name": group.name,
        "members": [{"id": m.id, "username": m.username, "score": m.score} for m in group.members],
    }), 200


@groups_bp.post("/<int:group_id>/join")
@jwt_required()
def join_group(group_id):
    """
    POST /api/groups/<group_id>/join
    """
    user = get_current_user()
    if user is None:
        return jsonify({"error": "Unauthorized"}), 401

    group = db.session.get(Group, group_id)
    if group is None:
        return jsonify({"error": "Group not found"}), 404

    if user in group.members:
        return jsonify({"ok": True, "message": "Already a member"}), 200

    group.members.append(user)
    db.session.commit()
    return jsonify({"ok": True}), 200


@groups_bp.post("/<int:group_id>/leave")
@jwt_required()
def leave_group(group_id):
    """
    POST /api/groups/<group_id>/leave
    """
    user = get_current_user()
    if user is None:
        return jsonify({"error": "Unauthorized"}), 401

    group = db.session.get(Group, group_id)
    if group is None:
        return jsonify({"error": "Group not found"}), 404

    if user not in group.members:
        return jsonify({"error": "Not a member"}), 400

    group.members.remove(user)
    db.session.commit()
    return jsonify({"ok": True}), 200
