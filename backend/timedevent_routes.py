# timedevent_routes.py
from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity

from extensions import db
from models import User, TimedEvent, Group, group_members  # adjust if your names differ

events_bp = Blueprint("events", __name__, url_prefix="/api/events")


def current_user():
    user_id = get_jwt_identity()
    if user_id is None:
        return None
    return db.session.get(User, int(user_id))


def event_to_dict(e: TimedEvent):
    return {
        "id": e.id,
        "title": e.title,
        "weekday": e.weekday,
        "hour": e.hour,
        "minute": e.minute,
        "user_id": e.user_id,
    }


@events_bp.get("")
@jwt_required()
def list_my_events():
    """
    GET /api/events
    """
    user = current_user()
    if user is None:
        return jsonify({"error": "Unauthorized"}), 401

    events = (
        db.session.query(TimedEvent)
        .filter(TimedEvent.user_id == user.id)
        .order_by(TimedEvent.weekday, TimedEvent.hour, TimedEvent.minute)
        .all()
    )
    return jsonify([event_to_dict(e) for e in events]), 200


@events_bp.post("")
@jwt_required()
def create_event():
    """
    POST /api/events
    JSON: { "title": "...", "weekday": 0-6, "hour": 0-23, "minute": 0-59 }
    """
    user = current_user()
    if user is None:
        return jsonify({"error": "Unauthorized"}), 401

    data = request.get_json(silent=True) or {}

    title = (data.get("title") or "").strip()
    weekday = data.get("weekday")
    hour = data.get("hour")
    minute = data.get("minute")

    if not title:
        return jsonify({"error": "title is required"}), 400

    # basic validation
    if not isinstance(weekday, int) or not (0 <= weekday <= 6):
        return jsonify({"error": "weekday must be int 0-6"}), 400
    if not isinstance(hour, int) or not (0 <= hour <= 23):
        return jsonify({"error": "hour must be int 0-23"}), 400
    if not isinstance(minute, int) or not (0 <= minute <= 59):
        return jsonify({"error": "minute must be int 0-59"}), 400

    e = TimedEvent(
        title=title,
        weekday=weekday,
        hour=hour,
        minute=minute,
        user_id=user.id
    )
    db.session.add(e)
    db.session.commit()

    return jsonify(event_to_dict(e)), 201


@events_bp.delete("/<int:event_id>")
@jwt_required()
def delete_event(event_id):
    """
    DELETE /api/events/<event_id>
    """
    user = current_user()
    if user is None:
        return jsonify({"error": "Unauthorized"}), 401

    e = db.session.get(TimedEvent, event_id)
    if e is None:
        return jsonify({"error": "Event not found"}), 404

    if e.user_id != user.id:
        return jsonify({"error": "Forbidden"}), 403

    db.session.delete(e)
    db.session.commit()
    return jsonify({"ok": True}), 200


@events_bp.get("/group/<int:group_id>")
@jwt_required()
def list_group_events(group_id):
    """
    GET /api/events/group/<group_id>
    Returns all events for all members of a group.
    """
    user = current_user()
    if user is None:
        return jsonify({"error": "Unauthorized"}), 401

    group = db.session.get(Group, group_id)
    if group is None:
        return jsonify({"error": "Group not found"}), 404

    # only members can view
    if user not in group.members:
        return jsonify({"error": "Forbidden (not a member)"}), 403

    events = (
        db.session.query(TimedEvent)
        .join(User, TimedEvent.user_id == User.id)
        .join(group_members, group_members.c.user_id == User.id)
        .filter(group_members.c.group_id == group_id)
        .order_by(TimedEvent.weekday, TimedEvent.hour, TimedEvent.minute)
        .all()
    )
    return jsonify([event_to_dict(e) for e in events]), 200
