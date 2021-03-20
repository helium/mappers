defmodule Mappers.Ingest do
  alias Mappers.Uplinks
  alias Mappers.H3

  def ingest_uplink(message) do
    # validate that lat/lng actually make sense
    # validate device location with hotspot locations

    # create new h3_res9 record if it doesn't exist
    resp = H3.create(message)
    {_ , h3_res9} = resp
    h3_res9_id = h3_res9.id
    IO.puts(h3_res9_id)
    # {_, h3_res9} = resp
    # h3_res9_id = h3_res9.id
    # create uplink record
    resp = Uplinks.create(message)
    {_, uplink} = resp
    uplink_id = uplink.id
    IO.puts(uplink_id)
    # create uplinks_heard
    #UplinksHeard.create(message)
    # create h3/uplink link
    #Links.create(h3_res9_id, uplink_id)
    resp
  end
end
