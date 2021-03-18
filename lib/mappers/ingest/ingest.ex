defmodule Mappers.Ingest do
  alias Mappers.Uplinks

  def ingest_uplink(message) do
    # validate that lat/lng actually make sense
    # validate device location with hotspot locations

    # create new h3_res9 record if it doesn't exist
    #H3.create(message)
    # create uplink record
    resp = Uplinks.create(message)
    {_, uplink} = resp
    IO.puts(uplink.id)
    # create uplinks_heard
    #UplinksHeard.create(message)
    # create h3/uplink link
    #Links.create(h3_res_id, uplink_id)
    resp
  end
end
