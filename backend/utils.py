import re
from dateutil import parser
from pytz import timezone

def parse_date_time(input_string):
    # Remove any parentheses and their contents
    input_string = re.sub(r'\([^)]*\)', '', input_string)

    # Try to parse the date and time
    try:
        dt = parser.parse(input_string, fuzzy=True)
    except ValueError:
        return None, None

    # Extract time zone information
    tz_match = re.search(r'\b(?:EST|EDT|CST|CDT|MST|MDT|PST|PDT|[A-Z]{3})\b', input_string, re.IGNORECASE)
    if tz_match:
        tz_str = tz_match.group().upper()
        if tz_str in ['EST', 'EDT']:
            tz = timezone('US/Eastern')
        elif tz_str in ['CST', 'CDT']:
            tz = timezone('US/Central')
        elif tz_str in ['MST', 'MDT']:
            tz = timezone('US/Mountain')
        elif tz_str in ['PST', 'PDT']:
            tz = timezone('US/Pacific')
        else:
            tz = timezone('UTC')
    else:
        tz = timezone('UTC')

    # Localize the datetime
    dt = tz.localize(dt)

    return dt, tz.zone