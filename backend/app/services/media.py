import os


def object_key_to_local_path(object_key: str) -> str:
    storage_dir = os.path.join(os.getcwd(), "storage")
    os.makedirs(storage_dir, exist_ok=True)
    return os.path.join(storage_dir, object_key.replace("/", "_"))

