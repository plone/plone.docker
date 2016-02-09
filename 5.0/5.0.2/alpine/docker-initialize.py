#!/plone/instance/bin/python

import re
import os

CONFIG = '/plone/instance/parts/instance/etc/zope.conf'
ZEO_TEMPLATE = """
    <zeoclient>
      read-only {read_only}
      read-only-fallback {zeo_client_read_only_fallback}
      blob-dir /data/blobstorage
      shared-blob-dir {shared_blob_dir}
      server {zeo_address}
      storage {zeo_storage}
      name zeostorage
      var /plone/instance/parts/instance/var
      cache-size {zeo_client_cache_size}
    </zeoclient>
""".strip()

def zeoclient(server, config):
    """ ZEO Client
    """
    zeo_conf = ZEO_TEMPLATE.format(
        zeo_address=server,
        read_only=os.environ.get('ZEO_READ_ONLY', 'false'),
        zeo_client_read_only_fallback=os.environ.get('ZEO_CLIENT_READ_ONLY_FALLBACK', 'false'),
        shared_blob_dir=os.environ.get('ZEO_SHARED_BLOB_DIR', 'off'),
        zeo_storage=os.environ.get('ZEO_STORAGE', '1'),
        zeo_client_cache_size=os.environ.get('ZEO_CLIENT_CACHE_SIZE', '128MB')
    )

    pattern = re.compile(r"<blobstorage>.+</blobstorage>", re.DOTALL)
    config = re.sub(pattern, zeo_conf, config)

    with open(CONFIG, 'w') as cfile:
        cfile.write(config)

def initialize():
    """ Configure Plone instance as ZEO Client
    """
    config = ''
    with open(CONFIG, 'r') as cfile:
        config = cfile.read()

    # Already initialized
    if "<blobstorage>" not in config:
        return

    server = os.environ.get("ZEO_ADDRESS", None)
    if server:
        return zeoclient(server, config)

if __name__ == "__main__":
    initialize()
