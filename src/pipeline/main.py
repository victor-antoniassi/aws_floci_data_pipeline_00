import os
import sys

from pipeline.pipeline import pipeline, coingecko_source

os.environ.setdefault("DLT_DATA_DIR", "/tmp/dlt_data")

if __name__ == "__main__":
    try:
        pipeline.run(coingecko_source(), loader_file_format="parquet")
    except Exception as exc:
        print(f"Pipeline failed: {exc}", file=sys.stderr)
        sys.exit(1)
