"""Download a Hugging Face model once and copy it to S3.

Idempotent: a `.complete` marker under the prefix means the upload already
happened, so a re-run of the Job does nothing and costs nothing.
"""

import os
import pathlib

import boto3
from botocore.exceptions import ClientError
from huggingface_hub import snapshot_download

bucket = os.environ["BUCKET"]
prefix = os.environ["PREFIX"]
model_id = os.environ["MODEL_ID"]
marker = f"{prefix}/.complete"

s3 = boto3.client("s3")

try:
    s3.head_object(Bucket=bucket, Key=marker)
    print(f"s3://{bucket}/{prefix} is already complete, nothing to do")
    raise SystemExit(0)
except ClientError as e:
    if e.response["Error"]["Code"] not in ("404", "NoSuchKey", "NotFound"):
        raise

local = pathlib.Path(
    snapshot_download(
        model_id,
        local_dir="/data/model",
        allow_patterns=["*.json", "*.safetensors", "*.txt", "*.model", "*.tiktoken", "*.jinja"],
    )
)

for path in sorted(p for p in local.rglob("*") if p.is_file() and ".cache" not in p.parts):
    key = f"{prefix}/{path.relative_to(local)}"
    print(f"upload {path.stat().st_size / 2**20:.0f} MiB -> s3://{bucket}/{key}")
    s3.upload_file(str(path), bucket, key)

s3.put_object(Bucket=bucket, Key=marker, Body=b"")
print("done")
