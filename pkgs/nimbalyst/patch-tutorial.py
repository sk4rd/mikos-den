# The tutorial copies its template out of the read-only store with fs.cp, which keeps the
# store's permissions, so writing into the copy fails. Make the copy writable.
#
# The replacement has the same length as the original, so no offset in the asar moves;
# only the integrity hashes in the header change, and those are fixed-length hex.
import hashlib
import json
import struct
import sys

src, dst = sys.argv[1], sys.argv[2]
data = bytearray(open(src, "rb").read())

old = b"""await fs__namespace$1.cp(templateDirectory, temporaryProject, {
        recursive: true,
        filter: (sourcePath) => !TEMPLATE_ONLY_METADATA_FILES.has(path__namespace.basename(sourcePath))
      });
      await fs__namespace$1.writeFile(
        path__namespace.join(temporaryProject, TUTORIAL_MARKER_FILE),
        `${JSON.stringify(
          { templateVersion: TUTORIAL_TEMPLATE_VERSION },
          null,
          2
        )}
`,
        "utf8"
      );"""
new = (
    b"await fs__namespace$1.cp(templateDirectory,temporaryProject,{recursive:true,"
    b"filter:s=>!TEMPLATE_ONLY_METADATA_FILES.has(path__namespace.basename(s))});"
    b'require$$0$4.execFileSync("chmod",["-R","u+w",temporaryProject]);'
    b"await fs__namespace$1.writeFile(path__namespace.join(temporaryProject,TUTORIAL_MARKER_FILE),"
    b'JSON.stringify({templateVersion:TUTORIAL_TEMPLATE_VERSION},null,2)+"\\n","utf8");'
)
if data.count(old) != 1:
    sys.exit("patch-tutorial: the tutorial copy code changed; update the patch")
if len(new) > len(old):
    sys.exit("patch-tutorial: replacement is longer than the original")
at = data.find(old)
data[at : at + len(old)] = new.ljust(len(old))

_, header_size, _, json_size = struct.unpack("<4I", data[:16])
header = json.loads(data[16 : 16 + json_size])
base = 8 + header_size

entry = header
for part in ["out", "main", "index.js"]:
    entry = entry["files"][part]
start = base + int(entry["offset"])
if not start <= at < start + entry["size"]:
    sys.exit("patch-tutorial: the copy code is not in out/main/index.js")

content = bytes(data[start : start + entry["size"]])
integrity = entry["integrity"]
block = integrity["blockSize"]
integrity["hash"] = hashlib.sha256(content).hexdigest()
integrity["blocks"] = [
    hashlib.sha256(content[i : i + block]).hexdigest()
    for i in range(0, len(content), block)
]

new_json = json.dumps(header, separators=(",", ":"), ensure_ascii=False).encode()
if len(new_json) != json_size:
    sys.exit("patch-tutorial: the asar header changed length")
data[16 : 16 + json_size] = new_json

open(dst, "wb").write(data)
