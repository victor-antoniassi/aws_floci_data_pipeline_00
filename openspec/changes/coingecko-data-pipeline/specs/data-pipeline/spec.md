## ADDED Requirements

### Requirement: CoinGecko source extraction

The system SHALL fetch cryptocurrency market data from the CoinGecko public API endpoint `/coins/markets`.

- The system SHALL use dlt's `RESTClient.get()` for HTTP requests — the endpoint returns all results in a single page with `per_page=250`
- The system SHALL request `per_page=250` to fetch the top 250 coins by market cap in a single page
- The system SHALL use `vs_currency=usd` as the quote currency
- The system SHALL NOT require an API key (public endpoint)
- The system SHALL set `sparkline=false` to exclude sparkline 7d data

#### Scenario: Successful extraction

- **WHEN** the pipeline invokes the CoinGecko source
- **THEN** the system SHALL receive a 200 response with a JSON array of market data
- **THEN** each entry SHALL contain fields: id, symbol, name, current_price, market_cap, market_cap_rank, total_volume, price_change_percentage_24h, last_updated

### Requirement: HTTP retry and backoff

The system SHALL retry failed HTTP requests to the CoinGecko API with exponential backoff.

- The system SHALL attempt up to 5 retries before failing
- The system SHALL use a backoff factor of 1 (delays: 1s, 2s, 4s, 8s, 16s)
- The system SHALL cap the maximum retry delay at 30 seconds
- The system SHALL set a request timeout of 60 seconds

#### Scenario: Transient server error

- **WHEN** CoinGecko returns a 5xx status code
- **THEN** the system SHALL retry with exponential backoff
- **THEN** the system SHALL proceed normally on eventual success

#### Scenario: Persistent failure

- **WHEN** all retry attempts are exhausted
- **THEN** the system SHALL raise an exception and fail the pipeline run

### Requirement: Rate limiting

The system SHALL respect CoinGecko's free-tier rate limits (approximately 30 requests per minute).

- The system SHALL configure `request_max_requests_per_second` in dlt's config.toml to avoid exceeding rate limits

### Requirement: dlt pipeline with filesystem destination

The system SHALL define a dlt pipeline that loads data to an S3 filesystem destination.

- The pipeline name SHALL be `coingecko`
- The dataset name SHALL be `crypto_markets`
- The destination SHALL be `filesystem` with bucket URL pointing to an S3 bucket
- The output format SHALL be Parquet
- The `DLT_DATA_DIR` environment variable SHALL point to `/tmp/dlt_data`

#### Scenario: Pipeline execution

- **WHEN** the pipeline runs with the CoinGecko source
- **THEN** the data SHALL be written as Parquet files to the configured S3 bucket
- **THEN** dlt SHALL infer and apply a schema automatically

### Requirement: Container exit code on failure

The system SHALL exit with a non-zero code when the pipeline fails, so ECS can report task failure.

- The `main.py` entrypoint SHALL call `sys.exit(1)` when `pipeline.run()` raises an exception

#### Scenario: Successful run

- **WHEN** the pipeline completes successfully
- **THEN** the container SHALL exit with code 0

#### Scenario: Failed run

- **WHEN** the pipeline raises an exception
- **THEN** the container SHALL exit with code 1
- **THEN** ECS SHALL report the task as `STOPPED` with `exitCode=1`

### Requirement: S3 compatible storage configuration

The system SHALL support an `endpoint_url` for the S3 filesystem destination when using S3-compatible storage (Floci).

- The `endpoint_url` SHALL be configurable via the environment variable `DESTINATION__FILESYSTEM__CREDENTIALS__ENDPOINT_URL`
- The `bucket_url` SHALL default to `s3://coingecko-raw`

#### Scenario: Local Floci endpoint

- **WHEN** `DESTINATION__FILESYSTEM__CREDENTIALS__ENDPOINT_URL=http://floci:4566` is set
- **THEN** dlt SHALL write Parquet files to the Floci S3 endpoint at `s3://coingecko-raw`

#### Scenario: Production AWS endpoint

- **WHEN** `DESTINATION__FILESYSTEM__CREDENTIALS__ENDPOINT_URL` is not set
- **THEN** dlt SHALL write to real AWS S3 at `s3://coingecko-raw`
