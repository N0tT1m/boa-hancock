import os
from smb.SMBConnection import SMBConnection
from fastapi import FastAPI, HTTPException
from fastapi.responses import StreamingResponse
from typing import List, Dict
from pathlib import Path
import tempfile
from models import SmbConfig, FileItem, MovieMetadata
import logging
from datetime import datetime

logger = logging.getLogger(__name__)

def convert_timestamp(timestamp) -> str:
    """Convert SMB timestamp to ISO format string"""
    try:
        if isinstance(timestamp, (int, float)):
            # Convert Unix timestamp to datetime
            dt = datetime.fromtimestamp(timestamp)
            return dt.isoformat()
        elif hasattr(timestamp, 'isoformat'):
            return timestamp.isoformat()
        else:
            # Fallback to current time if timestamp is invalid
            return datetime.now().isoformat()
    except Exception as e:
        logger.warning(f"Error converting timestamp {timestamp}: {e}")
        return datetime.now().isoformat()


def get_smb_connection(config: SmbConfig) -> SMBConnection:
    """Create and return an SMB connection"""
    try:
        conn = SMBConnection(
            config.username,
            config.password,
            config.client_name,
            config.server_name,
            domain=config.domain,
            use_ntlm_v2=True
        )

        if not conn.connect(config.server_ip, 445):
            raise HTTPException(status_code=500, detail="Failed to connect to SMB server")

        return conn
    except Exception as e:
        logger.error(f"SMB connection error: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to connect to SMB server: {str(e)}")


async def list_directory(path: str = "/") -> List[FileItem]:
    """List contents of directories across all configured shares"""
    config = SmbConfig.get_instance()
    all_items = []

    try:
        conn = get_smb_connection(config)

        try:
            for share in config.shares:
                share_path = str(Path(share.path) / path.lstrip('/'))

                try:
                    files = conn.listPath(share.name, share_path)

                    # Filter out system files and non-video files
                    valid_extensions = {'.mp4', '.mkv', '.avi', '.mov', '.wmv'}

                    for file in files:
                        if file.filename in ['.', '..']:
                            continue

                        file_path = str(Path(path) / file.filename)
                        is_video = any(file.filename.lower().endswith(ext) for ext in valid_extensions)
                        is_dir = file.isDirectory

                        if is_dir or is_video:
                            # Convert timestamp using the new helper function
                            modified_time = convert_timestamp(file.last_write_time)

                            all_items.append(FileItem(
                                name=file.filename,
                                path=file_path,
                                is_directory=is_dir,
                                size=file.file_size,
                                modified_time=modified_time,
                                share_name=share.name,
                                display_name=share.display_name
                            ))
                except Exception as e:
                    logger.error(f"Error listing directory in share {share.name}: {e}")
                    continue

            return all_items

        finally:
            conn.close()

    except Exception as e:
        logger.error(f"Error listing directories: {e}")
        raise HTTPException(status_code=500, detail=str(e))


async def stream_movie(share_name: str, path: str) -> StreamingResponse:
    """Stream a movie file from the specified share"""
    config = SmbConfig.get_instance()

    # Verify the share exists
    share = next((s for s in config.shares if s.name == share_name), None)
    if not share:
        raise HTTPException(status_code=404, detail=f"Share {share_name} not found")

    try:
        conn = get_smb_connection(config)

        try:
            # Construct the full path within the share
            full_path = str(Path(share.path) / path.lstrip('/'))

            # Create a temporary file to store chunks
            with tempfile.NamedTemporaryFile(delete=False) as temp_file:
                # Get file info
                file_obj = conn.getAttributes(share_name, full_path)
                file_size = file_obj.file_size

                # Stream the file in chunks
                chunk_size = 8192
                offset = 0

                while offset < file_size:
                    chunk = conn.retrieveFileFromOffset(
                        share_name,
                        full_path,
                        temp_file,
                        offset,
                        chunk_size
                    )
                    if not chunk:
                        break
                    offset += chunk_size

                temp_file.flush()

            # Return the temporary file as a streaming response
            def iterfile():
                with open(temp_file.name, 'rb') as f:
                    while chunk := f.read(8192):
                        yield chunk
                os.unlink(temp_file.name)

            return StreamingResponse(
                iterfile(),
                media_type='video/mp4',
                headers={
                    'Content-Disposition': f'inline; filename="{Path(path).name}"',
                    'Accept-Ranges': 'bytes',
                    'Content-Length': str(file_size)
                }
            )

        finally:
            conn.close()

    except Exception as e:
        logger.error(f"Error streaming movie: {e}")
        raise HTTPException(status_code=500, detail=str(e))


async def get_movie_metadata(share_name: str, path: str) -> MovieMetadata:
    """Get metadata for a movie file from the specified share"""
    config = SmbConfig.get_instance()

    # Verify the share exists
    share = next((s for s in config.shares if s.name == share_name), None)
    if not share:
        raise HTTPException(status_code=404, detail=f"Share {share_name} not found")

    try:
        conn = get_smb_connection(config)

        try:
            # Construct the full path within the share
            full_path = str(Path(share.path) / path.lstrip('/'))
            file_obj = conn.getAttributes(share_name, full_path)

            # Convert timestamp using the new helper function
            modified_time = convert_timestamp(file_obj.last_write_time)

            metadata = MovieMetadata(
                title=Path(path).stem,
                path=path,
                size=file_obj.file_size,
                modified_time=modified_time,
                share_name=share_name,
                display_name=share.display_name
            )

            return metadata

        finally:
            conn.close()

    except Exception as e:
        logger.error(f"Error getting movie metadata: {e}")
        raise HTTPException(status_code=500, detail=str(e))