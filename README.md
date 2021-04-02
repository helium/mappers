# Mappers

To start your Phoenix server:

Edit your environment variables
* Open the .sample.env file located at the root of the project
* Create a Mapbox account and copy your public access token
* Paste it in place of <replace me> for the PUBLIC_MAPBOX_KEY variable. That line should now look like this:

`PUBLIC_MAPBOX_KEY=pk.ey[...the rest of your access token...]`

Rename the file ".env" (delete ".sample" from the file name)

  * Install dependencies with `mix deps.get`
  * Create and migrate your database with `mix ecto.setup`
  * Install Node.js dependencies with `cd assets && yarn` 
  * Start Phoenix endpoint with `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

To Reset Database

  * Run `mix ecto.reset`

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix

## Importing Mappers V1 Database

### Download Database Export CSV 
`wget link`
### Split Database Export CSV

Split amount based on total cpu cores available

```
mkdir split-database
split -d -l 250000 merged.csv ./split-database
mix load_merged_mappers_csv
```
