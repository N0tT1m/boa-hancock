# state.py

class State:
    def __init__(self):
        self.conversation = []
        self.calendar_event_info = {}
        self.event_creation_stage = None

global_state = State()