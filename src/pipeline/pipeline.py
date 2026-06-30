import dlt
from dlt.sources.helpers.rest_client import RESTClient


@dlt.source
def coingecko_source():
    client = RESTClient(base_url="https://api.coingecko.com/api/v3")
    response = client.get(
        "/coins/markets",
        params={
            "vs_currency": "usd",
            "per_page": 250,
            "sparkline": False,
        },
    )
    data = response.json()
    yield dlt.resource(data, name="coins")


pipeline = dlt.pipeline(
    pipeline_name="coingecko",
    destination="filesystem",
    dataset_name="crypto_markets",
)
