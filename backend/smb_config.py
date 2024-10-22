# Updated configuration to handle multiple shares
SMB_CONFIG = {
    "username": "timmy",
    "password": "B@bycakes15!",
    "server_name": "tims_porn_server",
    "server_ip": "192.168.1.66",
    "shares": [
        {
            "name": "plex",
            "path": "porn",
            "display_name": "Main Movies"
        },
        {
            "name": "plex2",
            "path": "porn",
            "display_name": "Additional Movies"
        }
    ],
    "client_name": "Python_Client",
    "domain": ""
}