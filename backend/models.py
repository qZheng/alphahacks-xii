from werkzeug.security import generate_password_hash, check_password_hash
from extensions import db

group_members = db.Table(
    "group_members",
    db.Column("group_id", db.Integer, db.ForeignKey("group.id"), primary_key=True),
    db.Column("user_id", db.Integer, db.ForeignKey("user.id"), primary_key=True),
)

class Group(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(64), unique=True, nullable=False)

    members = db.relationship(
        "User",
        secondary=group_members,
        back_populates="groups"
    )

    def has_member(self, user):
        return user in self.members
    
    def add_member(self, user):
        if not self.has_member(user):
            self.members.append(user)

    def remove_member(self, user):
        if self.has_member(user):
            self.members.remove(user)

class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(64), unique=True, index=True, nullable=False)
    password_hash = db.Column(db.String(256), nullable=False)
    score = db.Column(db.Integer, default=0, nullable=False)

    groups = db.relationship(
        "Group",
        secondary=group_members,
        back_populates="members"
    )

    events = db.relationship(
        "TimedEvent",
        back_populates="user",
        cascade="all, delete-orphan"
    )
    
    def set_password(self, password: str):
        self.password_hash = generate_password_hash(password)

    def check_password(self, password: str) -> bool:
        return check_password_hash(self.password_hash, password)
    
    def is_in_group(self, group):
        return group in self.groups
    
    def join_group(self, group):
        if not self.is_in_group(group):
            self.groups.append(group)

    def leave_group(self, group):
        if self.is_in_group(group):
            self.groups.remove(group)

    def add_timed_event(self, title, weekday, hour, minute):
        e = TimedEvent(title=title, weekday=weekday, hour=hour, minute=minute, user=self)
        db.session.add(e)
        return e

    def __repr__(self):
        return '<User {}>'.format(self.username)
    

class TimedEvent(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(64), nullable=False)
    weekday = db.Column(db.Integer, nullable=False) # 0-6
    hour = db.Column(db.Integer, nullable=False) # 0-23
    minute = db.Column(db.Integer, nullable=False) # 0-59

    user_id = db.Column(db.Integer, db.ForeignKey("user.id"), index=True, nullable=False)
    user = db.relationship("User", back_populates="events")

    def __repr__(self):
        return f"<TimedEvent {self.title} {self.weekday} {self.hour:02d}:{self.minute:02d}>"
